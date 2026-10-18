extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func checkpoint(j: TacticalJourney) -> void:
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"Boss party snapshot validates")
    if JourneySnapshot.validate(data): check(JourneySnapshot.encode(JourneySnapshot.restore(data)) == data,"Snapshot preserves parties, RNG, cards and historical route")
func roster() -> Dictionary:
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    return {"gym":GymLeaders.all(),"elite":league["elite"]+BossExpansion.data()["elite"],"champion":league["champions"]+BossExpansion.data()["champions"]}
func run() -> void:
    var goldens := {1:"f361526dac5a2d5d7047110e8662b57609a109d969fc5dfa6e08cf45995d90be",712:"07925cc318559b2c66cb003c5ab4a4b2b984bab7a0d8dfe77a0836082015287e",2026:"ffd00f9af04a4f361cfdf45107b18e97f63d41d6accfe207d57e4922ca3f6b26"}
    for seed_value: int in goldens:
        var old := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true,4)
        check(old.route.signature == goldens[seed_value],"v4 golden captured from previous source commit unchanged")
        checkpoint(old)
    check(BossParties.entries().size() == 137,"All approved roles included; no unapproved Trace")
    check(BossParties.party("champion:cynthia") == [442,407,468,448,350,445],"Cynthia original Platinum party and last Garchomp")
    check(BossParties.party("champion:red") == [3,6,9,131,143,26],"Red uses approved final-evolution Raichu")
    check(BossParties.aces("gym:tate_liza") == [338,337],"Joint Tate/Liza keeps both Solrock and Lunatone")
    check(BossParties.aces("gym:blue") == [18] and BossParties.aces("champion:blue") == [18],"Gym and champion Blue remain distinct roles")
    var catalog := VisualCatalog.new()
    var route := CampaignRoute.new(2026,5)
    var helper := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var original_entries := var_to_bytes(BossParties.entries())
    var all_rosters := roster()
    var total := 0
    for role: String in all_rosters:
        for legacy: Dictionary in all_rosters[role]:
            var key := role+":"+str(legacy.get("leader_id",legacy.get("id")))
            var before := var_to_bytes(legacy)
            var trainer := BossParties.apply(role,legacy)
            var party := BossParties.party(key)
            var aces := BossParties.aces(key)
            check(var_to_bytes(legacy) == before and trainer["party"] == party,"Applying approved party leaves historical roster unchanged: "+key)
            check(party.size() == legacy["party"].size() and party.slice(party.size()-aces.size()) == aces,"Approved size and fixed final slots: "+key)
            var node := {"kind":role,"trainer":trainer,"party":party,"biome":catalog.biomes[0],"level":50}
            var public := TrainerDialogue.opponent(node,node["biome"])
            check(TrainerSprites.texture(public) != null and VisualCatalog.biome_texture(BattleBackdrops.for_stop(node,node["biome"])) != null,"Trainer portrait and room remain connected: "+key)
            check(not BossMusic.variants(public).is_empty() and TrainerDialogue.PHASES.all(func(phase: String): return not TrainerDialogue.line(public,phase).is_empty()),"Dedicated music and all dialogue phases: "+key)
            for id: int in party:
                check(VisualCatalog.supports(id) and load(VisualCatalog.sprite_path(id)) != null and load(VisualCatalog.sprite_path(id,true)) != null,"Real species/form front and back assets: "+str(id))
                var cry := load("res://assets/audio/cries/%d.ogg" % id) as AudioStream
                check(cry != null and cry.get_length() > 0,"Actual cry for approved form: "+str(id))
            for level in [18,50,100]:
                node["level"] = level
                route.stops[14] = node
                var definitions := route.opponents(14)
                var battle := TacticalBattle.new()
                battle.start_with(helper.party,helper.deck,definitions,712,"field_kit",true)
                battle.full_type_chart = true
                # Endurance fixture exercises full authored action cycles, not balance.
                for member: BattlePokemon in battle.party:
                    member.max_hp = 100000
                    member.hp = member.max_hp
                for slot in party.size():
                    var definition: Dictionary = definitions[slot]
                    check(battle.enemy().species_id == party[slot] and BossTactics.valid(definition),"Correct ordered opponent and usable boss tactics: "+key)
                    for action: Dictionary in definition["intents"]:
                        var view := TacticalMoves.definition(TacticalMoves.key_for(int(action["move_id"])))
                        check(not view.is_empty() and int(action["move_id"]) in NationalEvolution.teachable_moves(battle.enemy()) or action["kind"] not in ["attack","charge","barrage"] or int(action["move_id"]) == 165,"Damage moves follow legal source/level or Struggle: "+key)
                        var intended := battle.intent()
                        check(intended["value"] >= 0 and battle.end_turn().is_empty() and battle.phase == TacticalBattle.PLAYER,"Actual complete enemy cycle resolves: "+key)
                    var hand := battle.hand.duplicate()
                    var energy := battle.energy
                    var turn := battle.turn
                    battle.enemy().hp = 0
                    battle._outcome()
                    if slot+1 < party.size():
                        check(battle.enemy_index == slot+1 and battle.hand == hand and battle.energy == energy and battle.turn == turn,"Next approved opponent preserves turn/resources: "+key)
                    else: check(battle.phase == TacticalBattle.WON,"Final representative defeated completes boss: "+key)
            # Returned arrays and metadata cannot mutate cached parties or legacy files.
            trainer["party"][0] = 0
            party[0] = 0
            check(BossParties.party(key)[0] > 0 and var_to_bytes(legacy) == before,"Party application returns independent arrays")
            total += 1
    check(total == 137 and var_to_bytes(BossParties.entries()) == original_entries,"All approved boss definitions stay immutable")
    for seed_value in [1,7,42,712,2026]:
        var old := CampaignRoute.new(seed_value,4)
        var fresh := CampaignRoute.new(seed_value,5)
        for step in old.stops.size():
            var previous: Dictionary = old.stops[step]
            var next: Dictionary = fresh.stops[step]
            if previous["kind"] in ["gym","elite","champion"]:
                var key := TrainerDialogue.key(TrainerDialogue.opponent(next,next["biome"]))
                check(next["party"] == BossParties.party(key) and previous["trainer"].get("id",previous["trainer"].get("leader_id")) == next["trainer"].get("id",next["trainer"].get("leader_id")),"Same seed trainer selection, approved new party")
            else: check(previous == next,"v5 does not alter wild encounters, camps, levels or RNG sequence")
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        checkpoint(j)
        # Checkpoint a real, regenerated boss battle rather than an edited fixture.
        j.step = 14
        j.phase = TacticalJourney.MAP
        check(j.enter_next().is_empty(),"Enter a real new-version gym battle")
        checkpoint(j)
    var previous := TacticalJourney.new(712,"field_kit",[1,4,7],true,4)
    var store := JourneySave.new("user://boss-parties-old-v4.json")
    check(store.save(previous).is_empty(),"Write v4 compatibility fixture")
    var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
    envelope["content"] = "f1cf5bc91b4f53123011c7a2ec0049862d425f11127d63782b19971ab44411a5"
    check(JourneySave._atomic(store.path,JSON.stringify(envelope)).is_empty(),"Use exact previous-version content fingerprint")
    var restored := store.load_journey()
    check(restored != null and JourneySnapshot.encode(restored) == JourneySnapshot.encode(previous),"Actual old-fingerprint envelope restores exact old party/save")
    print("Boss parties: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
