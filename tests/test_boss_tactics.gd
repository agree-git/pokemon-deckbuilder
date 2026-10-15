extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(style: String, species := 68) -> TacticalBattle:
    var catalog := VisualCatalog.new()
    var members: Array[BattlePokemon] = []
    for id in [9,65,143]:
        var p := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        p.level = 50
        PokemonStats.apply(p,true)
        members.append(p)
    var boss := ""
    var slot := 0
    for key: String in BossTactics.TRAINERS:
        if style in BossTactics.TRAINERS[key]["styles"]:
            boss = key
            slot = BossTactics.TRAINERS[key]["styles"].find(style)
            break
    var foe := TacticalContent.member_definition(species,catalog)
    foe["level"] = 50
    foe["types"] = catalog.species(species)["types"]
    foe.merge(BossTactics.build(boss,slot,species,50,foe["types"]))
    foe["tactic"] = "balanced"
    var b := TacticalBattle.new()
    b.start_with(members,[],[foe],42,"field_kit")
    b.full_type_chart = true
    return b
func seek(b: TacticalBattle, kind: String) -> Dictionary:
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["kind"] == kind:
            b.enemy_states[0]["intent"] = i
            return b.intent()
    check(false,"Fixture contains "+kind)
    return {}
func content_checks() -> void:
    var catalog := VisualCatalog.new()
    var rosters: Dictionary = {}
    for entry: Dictionary in catalog.gyms: rosters["gym:"+str(entry["leader_id"])]=entry
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    for role: String in league:
        for entry: Dictionary in league[role]: rosters[("elite:" if role == "elite" else "champion:")+str(entry["id"])]=entry
    check(rosters.size() == 60 and BossTactics.TRAINERS.size() == rosters.size(),"All 18 gyms, 31 Elite candidates and 11 champions have authored commands")
    for boss: String in rosters:
        var roster: Array = rosters[boss]["party"]
        check(BossTactics.TRAINERS.has(boss) and BossTactics.TRAINERS[boss]["styles"].size() == roster.size(),"Trainer command matches the full roster: "+boss)
        for level in [18,50,100]:
            for i in roster.size():
                var id := int(roster[i])
                var definition := BossTactics.build(boss,i,id,level,catalog.species(id)["types"])
                check(BossTactics.valid(definition) and definition == BossTactics.build(boss,i,id,level,catalog.species(id)["types"]),"Every boss slot has a stable, valid style")
                for action: Dictionary in definition["intents"]:
                    if action["kind"] not in ["attack","charge","barrage"]: continue
                    var selected := EnemyTactics.moves(id,level,catalog.species(id)["types"])
                    check(action["move_id"] in selected.values(),"Boss offense retains level-legal species moves or Struggle")
                    check(TacticalMoves.definition(TacticalMoves.key_for(action["move_id"]))["type"] == action["type"],"Boss attack type agrees with its actual move")
    check(BossTactics.TRAINERS["gym:koga"] != BossTactics.TRAINERS["elite:koga"] and BossTactics.TRAINERS["elite:lance"] != BossTactics.TRAINERS["champion:lance"],"Different appearances have distinct authored plans")
    for seed_value in 10:
        var route := CampaignRoute.new(seed_value)
        var signature := route.signature
        for step in route.stops.size():
            var node := route.stops[step]
            if node["kind"] == "rest": continue
            var opponents := route.opponents(step)
            if node["kind"] in ["gym","elite","champion"]:
                check(opponents.all(func(d: Dictionary): return d.has("boss") and BossTactics.valid(d)),"Route installs authored commands only on boss parties")
            else: check(opponents.all(func(d: Dictionary): return not d.has("boss")),"Normal encounters keep their original profiles")
        check(route.signature == signature and CampaignRoute.new(seed_value).signature == signature,"Loading commands consumes no route randomness or changes saved route signatures")
func action_checks() -> void:
    var b := fixture("tempo")
    var action := seek(b,"barrage")
    check(action["value"] == action["per_hit"]*2 and action["hits"] == 2,"Two-hit forecast exposes per-hit and total damage")
    var before := b.snapshot()
    var alternate := b.intent_for(b.party[1])
    check(alternate["move_id"] == action["move_id"] and alternate["hits"] == 2 and b.snapshot() == before,"Changing the preview defender never changes the attack or RNG")
    b.active().block = int(action["per_hit"])+1
    var hp := b.active().hp
    var shield := b.active().block
    b.end_turn()
    check(b.active().hp == hp-maxi(0,int(action["value"])-shield),"Two hits consume shield sequentially for the advertised total")
    check(b.events.filter(func(e: Dictionary): return e["kind"] == "damage" and e["target"] > 0).size() == 2 and b.events.any(func(e: Dictionary): return e["kind"] == "enemy_hit"),"Each hit has its own damage and the second windup has a separate frame")
    b = fixture("tempo")
    seek(b,"barrage")
    b.active().block = 0
    b.active().hp = 1
    hp = b.party[1].hp
    b.end_turn()
    check(b.phase == TacticalBattle.REPLACE and b.party[1].hp == hp,"Fainting interrupts the barrage without hitting a benched Pokemon")
    check(b.events.filter(func(e: Dictionary): return e["kind"] == "damage" and e["target"] > 0).size() == 1 and b.statistics["counts"]["knockouts"] == 1,"Interrupted barrage creates exactly one hit, knockout and injury")
    for style: String in ["bulwark","precision"]:
        b = fixture(style)
        action = seek(b,"fortify")
        var stat: String = action["stat"]
        b.end_turn()
        check(b.enemy().stat_stages[stat] == 1 and b.enemy().block == action["value"],"Fortification grants the announced stat stage and shield")
        b.enemy().stat_stages[stat] = 6
        action = seek(b,"fortify")
        check(action["stat_delta"] == 0,"Forecast respects the original stat-stage cap")
        b.end_turn()
        check(b.enemy().stat_stages[stat] == 6,"Repeated fortification cannot exceed stage six")
    b = fixture("sustain")
    check(seek(b,"recover")["value"] == 0,"Full-health recovery openly wastes the healing turn")
    b.enemy().hp -= 1
    action = seek(b,"recover")
    check(action["value"] == 1,"Recovery preview is capped to actual missing HP")
    b.end_turn()
    check(b.enemy().hp == b.enemy().max_hp and b.statistics["counts"]["healing"] == 0,"Enemy recovery never inflates allied healing measurements")
    for style: String in ["venom","scorch","roots"]:
        b = fixture(style)
        action = seek(b,"status")
        var status: String = action["status"]
        b.end_turn()
        check(b.active().statuses[status]["turns"] == 2 and b.active().statuses[status]["source_uid"] == b.enemy().uid,"Public status command applies to the current defender for two ticks")
        check(b.intent()["kind"] == BossTactics.STYLES[style]["cycle"][1],"Status action consumes an entire enemy turn and advances its public cycle")
    b = fixture("roots")
    seek(b,"status")
    b.enemy().hp -= 20
    b.end_turn()
    var source_hp := b.enemy().hp
    hp = b.active().hp
    b._tick(b.active())
    check(b.active().hp < hp and b.enemy().hp == source_hp+hp-b.active().hp,"Enemy seed drains actual allied HP to its living source")
    check(b.statistics["counts"]["healing"] == 0,"Enemy seed healing stays outside allied recovery totals")
    b.enemy().hp = 0
    b.enemy().knocked_out = true
    b._tick(b.active())
    check(b.enemy().hp == 0,"A fainted seed source cannot be revived by later ticks")
    for style: String in ["tempo","bulwark","precision","sustain","venom","scorch","roots"]:
        b = fixture(style)
        action = seek(b,{"tempo":"barrage","bulwark":"fortify","precision":"fortify","sustain":"recover"}.get(style,"status"))
        b.enemy().statuses["sleep"] = {"turns":1,"source_uid":b.active().uid}
        hp = b.active().hp
        var enemy_hp := b.enemy().hp
        b.end_turn()
        check(b.active().hp == hp and b.enemy().hp == enemy_hp and b.enemy().stat_stages.is_empty() and b.active().statuses.is_empty(),"Sleep cancels every new boss action without side effects")
func save_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    var original := JourneySnapshot.encode(j)
    j.phase = TacticalJourney.MAP
    j.step = 14
    for p: BattlePokemon in j.party:
        p.level = 50
        PokemonStats.apply(p,true)
    check(j.enter_next().is_empty(),"Enter a real six-Pokemon gym")
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"Authored commands and new action fields validate")
    var restored := JourneySnapshot.restore(data)
    check(JourneySnapshot.encode(restored) == data,"Reload preserves every order and current position")
    var legacy := data.duplicate(true)
    var definitions: Array = legacy["battle"]["enemy_definitions"]
    for i in definitions.size():
        var definition: Dictionary = definitions[i]
        definition.erase("boss")
        definition.erase("boss_style")
        definition.merge(EnemyTactics.build(int(definition["id"]),int(definition["level"]),definition["types"],"gym",i,definitions.size()),true)
    check(JourneySnapshot.validate(legacy),"Previously saved gym patterns require no boss metadata")
    check(JourneySnapshot.encode(JourneySnapshot.restore(legacy)) == legacy,"A legacy gym keeps its old patterns rather than regenerating new commands")
    j.battle.end_turn()
    restored.battle.end_turn()
    check(JourneySnapshot.encode(j) == JourneySnapshot.encode(restored),"Continued boss action and measurements match after restore")
    data = JourneySnapshot.encode(j)
    for edit: Dictionary in [{"boss":"missing"},{"boss_style":"missing"},{"boss":3}]:
        var broken := data.duplicate(true)
        broken["battle"]["enemy_definitions"][0].merge(edit,true)
        check(not JourneySnapshot.validate(broken),"Reject unknown or malformed boss metadata")
    for action: Dictionary in [{"kind":"barrage","move_id":33,"value":40,"type":"normal","hits":999},{"kind":"fortify","move_id":115,"value":6,"stat":"hp"},{"kind":"status","move_id":92,"value":2,"status":"sleep"},{"kind":"recover","move_id":105,"value":999}]:
        var broken := data.duplicate(true)
        broken["battle"]["enemy_definitions"][0]["intents"] = [action]
        check(not JourneySnapshot.validate(broken),"Reject invalid hit count, stat, status or recovery amount")
    check(JourneySnapshot.validate(original),"Unchanged old profile battles remain compatible")
    var store := JourneySave.new("user://tests/boss_orders_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Persist a boss checkpoint to disk")
    var loaded := store.load_journey()
    check(loaded != null and JourneySnapshot.encode(loaded) == JourneySnapshot.encode(j),"Disk reload retains authored patterns and stat changes")
func run() -> void:
    content_checks()
    action_checks()
    save_checks()
    print("BOSS_TACTICS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
