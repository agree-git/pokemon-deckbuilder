extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var catalog := VisualCatalog.new()
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    for role: String in league:
        for trainer: Dictionary in league[role]:
            var seen: Array[int] = []
            for id: float in trainer["party"]:
                var species := catalog.species(int(id))
                check(not species.is_empty() and not species["is_legendary"] and not species["is_mythical"] and int(id) not in seen,"Valid unique non-legendary league party: "+trainer["name"])
                if role == "elite": check(trainer["type"] in species["types"],"Elite specialty matches species")
                seen.append(int(id))
            check(seen.size() == (5 if role == "elite" else 6),"League party size")
    for seed_value in 100:
        var a := CampaignRoute.new(seed_value)
        check(a.stops == CampaignRoute.new(seed_value).stops,"Seed reproduces entire route")
        check(a.stops.size() == 57 and a.biomes.size() == 8 and a.elite.size() == 4,"Eight regions and complete league")
        var types: Array[String] = []
        var people: Array[String] = [a.champion["id"]]
        for biome: Dictionary in a.biomes:
            check(biome["type"] not in types,"Distinct biomes")
            types.append(biome["type"])
        check(types[0] not in ["ghost","steel","rock"],"Opening type supports Lv.5 Normal moves")
        for trainer: Dictionary in a.elite:
            check(trainer["id"] not in people,"No duplicate league person")
            people.append(trainer["id"])
        var wilds := 0
        var gyms := 0
        for node: Dictionary in a.stops:
            if node["kind"] == "gym":
                gyms += 1
                check(node["party"].size() == 6,"Six opponents per gym")
            if node["kind"] == "wild":
                wilds += 1
                var species := catalog.species(int(node["party"][0]))
                check(node["biome"]["type"] in species["types"] and not species["is_legendary"] and not species["is_mythical"],"Wild belongs to biome and is not legendary")
        check(wilds == 8 and gyms == 8,"Eight captures and badges")
    check(TypeMatchup.multiplier("electric",["water","flying"]) == 4.0,"Dual weakness")
    check(TypeMatchup.multiplier("normal",["ghost"]) == 0.0,"Normal immunity")
    check(TypeMatchup.multiplier("fire",["water","dragon"]) == 0.25,"Dual resistance")
    check(TypeMatchup.multiplier("dragon",["fairy"]) == 0.0,"Modern Fairy immunity")
    var gate := TacticalJourney.new(2026,"seed_relay",[1,4,7],true)
    gate.phase = TacticalJourney.MAP
    gate.step = 48
    var prior := gate.battle.snapshot()
    check(not gate.enter_next().is_empty() and gate.battle.snapshot() == prior,"League rejects insufficient badges atomically")
    gate.badges = 8
    gate.step = 56
    check(not gate.enter_next().is_empty(),"Champion rejects missing Elite wins")
    # A later region is capturable too; preserve its level, dual type and learnset.
    var capture_run := TacticalJourney.new(2026,"seed_relay",[1,4,7],true)
    capture_run.phase = TacticalJourney.MAP
    capture_run.step = 6
    capture_run.enter_next()
    var target := capture_run.battle.enemy()
    target.hp = maxi(1,floori(target.max_hp*0.25))
    var target_level := target.level
    var target_types := target.types.duplicate()
    var before_balls := capture_run.balls
    check(capture_run.capture().is_empty() and capture_run.balls == before_balls-1,"Capture is available beyond the first biome")
    check(capture_run.pending_captures[0].level == target_level and capture_run.pending_captures[0].types == target_types and not capture_run.pending_captures[0].learned_skills.is_empty(),"Later captures keep level, dual typing and canonical moves")
    capture_run.phase = TacticalJourney.MAP
    capture_run.step = 7
    capture_run.enter_next()
    var money := capture_run.gold
    before_balls = capture_run.balls
    check(capture_run.buy("ball").is_empty() and capture_run.gold == money-35 and capture_run.balls == before_balls+1 and capture_run.shop_stock["ball"] == 3,"Capture supplies are replenishable at camps")
    var ball_count := capture_run.balls
    check(not capture_run.use_item("ball",0).is_empty() and capture_run.balls == ball_count,"Ball cannot be consumed as a recovery item")
    # Verify full-type arithmetic through the real engine, not only chart lookup.
    var typed_battle := TacticalBattle.new(42)
    var actor := BattlePokemon.new({"id":130,"name":"테스트 아군","type":"water","types":["water","flying"],"max_hp":999},10)
    actor.progression_initialized = true
    actor.learned_skills.assign(["move_85","move_33"])
    var members: Array[BattlePokemon] = [actor]
    var cards: Array[BattleCardInstance] = []
    var foe := {"id":130,"name":"테스트 적","type":"water","types":["water","flying"],"max_hp":999,"intents":[{"kind":"attack","value":10,"type":"electric","move_id":85}]}
    typed_battle.start_with(members,cards,[foe],42,"seed_relay",true)
    typed_battle.full_type_chart = true
    var preview := int(typed_battle.skill_view("move_85")["preview_damage"])
    check(typed_battle.intent()["value"] == 40,"Enemy intent uses dual weakness")
    var hp := typed_battle.enemy().hp
    typed_battle.use_skill("move_85")
    check(typed_battle.enemy().hp == hp-preview and preview == int(TacticalMoves.definition("move_85")["damage"])*4,"Real damage matches full-type preview")
    typed_battle.enemy().types.assign(["ghost"])
    hp = typed_battle.enemy().hp
    check(typed_battle.skill_view("move_33")["preview_damage"] == 0,"Immune skill previews zero")
    typed_battle.use_skill("move_33")
    check(typed_battle.enemy().hp == hp,"Immunity prevents actual direct damage")
    # Use legal actions throughout the full campaign, including training choices.
    var completed := 0
    for seed_value in range(30):
        var j := TacticalJourney.new(seed_value,"seed_relay",[1,4,7],true)
        var guard := 0
        while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and guard < 20000:
            guard += 1
            var reason := ""
            match j.phase:
                TacticalJourney.BATTLE:
                    if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                        reason = j.settle()
                        var coins := j.gold
                        var count := j.badges
                        var xp := j.party.map(func(p: BattlePokemon): return p.experience)
                        j.settle()
                        check(j.gold == coins and j.badges == count and j.party.map(func(p: BattlePokemon): return p.experience) == xp,"Settlement exactly once")
                        if j.badges == 8 and j.elite_wins < 4: check(j.phase != TacticalJourney.CLEARED,"Eighth badge does not finish campaign")
                    else: reason = CampaignPolicy.apply(j,CampaignPolicy.action(j))
                TacticalJourney.LEARN: reason = j.resolve_learning(CampaignPolicy.learn(j))
                TacticalJourney.REWARD: reason = j.choose_reward(-1)
                TacticalJourney.MAP: reason = j.enter_next()
                TacticalJourney.REST:
                    CampaignPolicy.camp(j)
                    reason = j.leave_camp()
            if not reason.is_empty():
                check(false,"Legal campaign action: "+reason)
                break
        print("CAMPAIGN seed=",seed_value," phase=",j.phase," step=",j.step," wins=",j.wins," levels=",j.party.map(func(p: BattlePokemon): return p.level)," actions=",guard)
        check(j.phase == TacticalJourney.CLEARED and j.badges == 8 and j.elite_wins == 4 and j.wins == 29,"Full playable campaign: %d" % seed_value)
        if j.phase == TacticalJourney.CLEARED: completed += 1
        var stops := j.route.stops.duplicate(true)
        j.restart(seed_value)
        check(j.full_campaign and j.badges == 0 and j.elite_wins == 0 and j.route.stops == stops and j.party.all(func(p: BattlePokemon): return p.level == 5),"Restart resets growth and badges with same route")
    print("CAMPAIGN: ",checks," checks, ",failures," failures; ",completed," complete campaigns")
    quit(0 if failures == 0 else 1)
