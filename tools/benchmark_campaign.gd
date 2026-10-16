extends SceneTree
## Developer measurement only: public rules, fixed policy, no forced drops or stats.
const RecruitmentPolicy = preload("res://tools/campaign_recruitment_policy.gd")
const CampPolicy = preload("res://tools/campaign_camp_policy.gd")
const BattleDiagnostics = preload("res://tools/campaign_battle_diagnostics.gd")
const CASES := {
    "kanto":[1,4,7],"johto":[152,155,158],"hoenn":[252,255,258],
    "bugs":[10,13,265],"babies":[172,173,174],"psychic":[63,280,360],
    "slow":[66,74,111],"ghost":[92,200,353],"water":[129,349,298],
    "mixed":[133,236,235],"sublegend":[144,4,7],"mythical":[151,4,7],
    "superlegend":[150,4,7],"solo":[1],"solo_fish":[129],
}
const STYLES := ["baseline","relay","ace","status","shield","supply"]
const HELD := {"relay":["relay_ribbon"],"ace":["ace_band","power_band"],"status":["seed_charm"],"shield":["guard_charm"],"supply":["healing_bell"]}
var options := {"seeds":"0,42,2026","parties":",".join(CASES.keys()),"styles":"baseline","camps":"rest","recruitment":"off","diagnostics":"off","max-turns":"100","output":"/tmp/pokemon-campaign-balance.json"}
func _initialize() -> void: call_deferred("run")
func rules_fingerprint() -> String:
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(JourneySave.fingerprint().to_utf8_buffer())
    var sources: Array[String] = ["res://tests/campaign_policy.gd","res://tests/tactical_policy.gd","res://tools/benchmark_campaign.gd","res://tools/campaign_camp_policy.gd","res://tools/campaign_recruitment_policy.gd","res://tools/campaign_battle_diagnostics.gd","res://scripts/content/encounter_preparation.gd","res://scripts/content/recruitment_preview.gd","res://scripts/content/visual_catalog.gd"]
    sources.append_array(["res://scripts/content/gym_leaders.gd","res://data/gym_leaders.json"])
    for directory: String in ["res://scripts/tactics","res://scripts/battle"]:
        for file: String in DirAccess.get_files_at(directory):
            if file.ends_with(".gd"): sources.append(directory+"/"+file)
    sources.sort()
    for source: String in sources:
        hash.update(source.to_utf8_buffer())
        hash.update(FileAccess.get_file_as_bytes(source))
    return hash.finish().hex_encode()
func affinity(option: Dictionary, style: String) -> bool:
    if option["kind"] == "relic": return style in TacticalContent.RELIC_THEMES.get(option["key"],[])
    if option["kind"] == "held": return option["key"] in HELD.get(style,[])
    return int(option.get("owner_uid",0)) == 0 and style in TacticalContent.CARD_THEMES.get(option["key"],[])
func reward(j: TacticalJourney, style: String) -> int:
    if style != "baseline":
        for i in j.reward_options.size():
            var offer := j.reward_options[i]
            if affinity(offer,style) and (offer["kind"] != "card" or j.deck.size() < 24): return i
    return CampaignPolicy.reward(j)
func camp(j: TacticalJourney, style: String, camp_policy: String) -> String:
    # Baseline is deliberately the existing policy, for comparisons to old checks.
    if camp_policy == "develop":
        var error: String = CampPolicy.apply(j,style)
        if not error.is_empty(): return error
    else: CampaignPolicy.camp(j)
    if style == "baseline": return ""
    if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty(): j.resolve_camp(0)
    if j.deck.size() >= 24: return ""
    for i in j.shop_cards().size():
        var offer: Dictionary = j.shop_cards()[i]
        if affinity(offer,style) and j.gold-int(offer["price"]) >= 100 and j.shop_card_reason(i).is_empty():
            return j.buy_shop_card(i)
    return ""
func measure(case_key: String, style: String, seed_value: int, camp_policy: String, recruitment_mode: String) -> Dictionary:
    var starters: Array[int] = []
    starters.assign(CASES[case_key])
    var j := TacticalJourney.new(seed_value,"field_kit",starters,true)
    var recruitment := RecruitmentPolicy.new()
    var actions := 0
    var error := ""
    var stop := ""
    var diagnostics: Array[Dictionary] = []
    var entry := {}
    while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and actions < 15000:
        actions += 1
        match j.phase:
            TacticalJourney.BATTLE:
                if options["diagnostics"] == "on" and entry.is_empty(): entry = BattleDiagnostics.begin(j)
                if j.battle.phase not in [TacticalBattle.WON,TacticalBattle.LOST] and j.battle.turn > int(options["max-turns"]):
                    stop = "battle_turn_limit"
                    break
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                    if options["diagnostics"] == "on":
                        diagnostics.append(BattleDiagnostics.finish(j,entry))
                        entry = {}
                    error = j.settle()
                elif recruitment_mode == "early": error = recruitment.apply(j,recruitment.action(j))
                else: error = CampaignPolicy.apply(j,CampaignPolicy.action(j))
            TacticalJourney.CAPTURE: error = recruitment.resolve(j)
            TacticalJourney.LEARN: error = j.resolve_learning(CampaignPolicy.learn(j))
            TacticalJourney.REWARD: error = j.choose_reward(reward(j,style))
            TacticalJourney.MAP: error = j.enter_next()
            TacticalJourney.REST:
                error = camp(j,style,camp_policy)
                if error.is_empty(): error = j.leave_camp()
            _: error = "Unexpected phase: "+j.phase
        if not error.is_empty(): break
    if actions >= 15000: stop = "action_limit"
    var combat: Dictionary = j.statistics["combat"]
    var row := {"party":case_key,"starters":starters,"style":style,"seed":seed_value,"phase":j.phase,"wins":j.wins,"badges":j.badges,"step":j.step,"last_place":j.current()["name"],"last_kind":j.current()["kind"],"last_type":j.biome()["type"],"turns":j.total_turns,"actions":actions,"error":error,"incomplete":stop,"damage_taken":combat["damage_taken"],"knockouts":combat["knockouts"],"auto_switches":combat["auto_switches"],"drawn":combat["drawn"],"gold_spent":RunStatistics.spent(j.statistics),"deck_size":j.deck.size(),"relics":j.relics.duplicate(),"cards":j.statistics["cards"].duplicate(),"levels":j.party.map(func(p: BattlePokemon): return p.level),"statistics_valid":RunStatistics.valid_run(j.statistics)}
    row["camp_policy"] = camp_policy
    row["economy"] = j.statistics["counts"].duplicate()
    row["final_species"] = j.party.map(func(p: BattlePokemon): return p.species_id)
    row["core_relic"] = CoreRelics.selected(j.relics)
    row["recruitment"] = recruitment_mode
    row["captures"] = recruitment.captures.duplicate(true)
    row["recruits"] = recruitment.decisions.duplicate(true)
    row["balls_remaining"] = j.balls
    if options["diagnostics"] == "on": row["battle_diagnostics"] = diagnostics
    print("BALANCE ",case_key,"/",style,"/",camp_policy,"/",recruitment_mode," seed=",seed_value," ",j.phase," wins=",j.wins," turns=",j.total_turns)
    return row
func run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size()%2 != 0:
        printerr("Expected paired --seeds, --parties, --styles, --camps, --recruitment, --diagnostics, --max-turns, --output options")
        quit(2)
        return
    for i in range(0,args.size(),2):
        var key: String = args[i].trim_prefix("--")
        if not options.has(key):
            printerr("Unknown option: ",args[i])
            quit(2)
            return
        options[key] = args[i+1]
    if options["diagnostics"] not in ["off","on"]:
        printerr("Choose diagnostics off or on")
        quit(2)
        return
    var parties: PackedStringArray = options["parties"].split(",",false)
    var styles: PackedStringArray = options["styles"].split(",",false)
    var seeds: PackedStringArray = options["seeds"].split(",",false)
    var camps: PackedStringArray = options["camps"].split(",",false)
    var recruit_modes: PackedStringArray = options["recruitment"].split(",",false)
    if recruit_modes.is_empty():
        printerr("Choose a recruitment policy")
        quit(2)
        return
    for mode: String in recruit_modes:
        if mode not in ["off","early"]:
            printerr("Unknown recruitment policy: ",mode)
            quit(2)
            return
    if not options["max-turns"].is_valid_int() or int(options["max-turns"]) < 1 or int(options["max-turns"]) > 1000:
        printerr("Choose a battle turn limit between 1 and 1000")
        quit(2)
        return
    if parties.is_empty() or styles.is_empty() or seeds.is_empty() or camps.is_empty() or parties.size()*styles.size()*seeds.size()*camps.size()*recruit_modes.size() > 1000:
        printerr("Choose 1–1000 measurements")
        quit(2)
        return
    for key: String in parties:
        if not CASES.has(key):
            printerr("Unknown party: ",key)
            quit(2)
            return
    for key: String in styles:
        if key not in STYLES:
            printerr("Unknown style: ",key)
            quit(2)
            return
    for value: String in seeds:
        if not value.is_valid_int():
            printerr("Invalid seed: ",value)
            quit(2)
            return
    for key: String in camps:
        if key not in ["rest","develop"]:
            printerr("Unknown camp policy: ",key)
            quit(2)
            return
    for values: Array in [Array(parties),Array(styles),Array(camps),Array(recruit_modes),Array(seeds).map(func(value: String): return int(value))]:
        var seen := {}
        for value: Variant in values:
            if seen.has(value):
                printerr("Duplicate selection: ",value)
                quit(2)
                return
            seen[value] = true
    var rows := []
    var failed := false
    for party_key: String in parties:
        for style: String in styles:
            for seed_value: String in seeds:
                for camp_policy: String in camps:
                    for recruitment_mode: String in recruit_modes:
                        var row := measure(party_key,style,int(seed_value),camp_policy,recruitment_mode)
                        failed = failed or not row["error"].is_empty() or not row["incomplete"].is_empty() or not row["statistics_valid"]
                        rows.append(row)
    var report := {"version":2,"engine":Engine.get_version_info()["string"],"ruleset":JourneySave.RULESET,"stat_basis":PokemonStats.BASIS,"rules_fingerprint":rules_fingerprint(),"policy":"CampaignPolicy + preferred reward/shop theme + rest/develop camps + exclusive core rewards + optional early recruitment v4","scope":"No rare hunts or stat/resource overrides. Early recruitment may catch at most two ordinary wild Pokemon in the first region, spending actual balls/energy and joining or replacing based on current stats and known moves. It abandons each capture attempt after three turns. Off does not capture. Rest preserves the original camp policy. Develop resolves encounters, purchases usable evolution items with a 100-gold reserve, rests below 75% HP or for friendship, otherwise upgrades; it removes low-rated or duplicate non-damaging techniques. Combat and learning policy stay the same. Preferred rewards include one exclusive core relic at a gym.","rows":rows}
    report["limits"] = {"battle_turns":int(options["max-turns"]),"actions":15000}
    var target: String = options["output"]
    if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
        printerr("Cannot create report directory: ",target)
        quit(2)
        return
    var file := FileAccess.open(target,FileAccess.WRITE)
    if file == null:
        printerr("Cannot write report: ",target)
        quit(2)
        return
    file.store_string(JSON.stringify(report,"  "))
    var error := file.get_error()
    file.close()
    print("BALANCE_REPORT ",target," rows=",rows.size())
    quit(1 if failed or error != OK else 0)
