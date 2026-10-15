extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(tactic: String) -> TacticalBattle:
    var catalog := VisualCatalog.new()
    var members: Array[BattlePokemon] = []
    for id in [4,7]:
        var member := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        member.level = 50
        members.append(member)
    var foe := TacticalContent.member_definition(68,catalog)
    foe["types"] = catalog.species(68)["types"]
    foe["level"] = 50
    foe.merge(EnemyTactics.build(68,50,foe["types"],"gym",5,6))
    foe["tactic"] = tactic
    foe["intents"] = []
    for kind: String in EnemyTactics.PROFILES[tactic]["cycle"]:
        foe["intents"].append({"kind":kind,"value":2 if kind == "boost" else 10,"move_id":33 if kind in ["attack","charge"] else (74 if kind == "boost" else 115),"type":"normal"})
    var b := TacticalBattle.new()
    b.start_with(members,[],[foe],42,"field_kit")
    b.full_type_chart = true
    for pokemon: BattlePokemon in b.party+b.enemies:
        pokemon.max_hp = 5000
        pokemon.hp = 5000
    return b
func run() -> void:
    var catalog := VisualCatalog.new()
    var roles := {}
    for species in range(1,387):
        var types: Array = catalog.species(species)["types"]
        for level in [5,50,100]:
            var known: Array[int] = []
            for entry: Dictionary in TacticalGrowth.species_data(species)["learnset"]:
                if int(entry["level"]) <= level and TacticalMoves.definition(TacticalMoves.key_for(int(entry["move"]))).has("damage"): known.append(int(entry["move"]))
            var pattern := EnemyTactics.build(species,level,types,"wild",0,1)
            roles[pattern["tactic"]] = true
            check(pattern == EnemyTactics.build(species,level,types,"wild",0,1),"Enemy loadout is deterministic")
            for action: Dictionary in pattern["intents"]:
                if action["kind"] not in ["attack","charge"]: continue
                var id: int = action["move_id"]
                check(id in known or (known.is_empty() and id == 165),"Offense must be learned at the current level, or fallback Struggle: %d/%d/%d" % [species,level,id])
                check(action["type"] == TacticalMoves.definition(TacticalMoves.key_for(id))["type"],"Attack type agrees with selected move")
            var selected := EnemyTactics.moves(species,level,types)
            var eligible: Array = known.filter(func(id: int): return int(TacticalMoves.definition(TacticalMoves.key_for(id)).get("move_power",40)) <= 80)
            if not eligible.is_empty(): check(TacticalMoves.definition(TacticalMoves.key_for(selected["normal"]))["move_power"] <= 80,"Normal attacks prefer a lower-power move before the telegraphed heavy attack")
    check(roles.has("balanced") and roles.has("striker") and roles.has("guardian"),"Wild species cover multiple behavior profiles")
    check(EnemyTactics.role(213,"wild",0,1) == "guardian" and EnemyTactics.role(65,"wild",0,1) == "striker","Natural bulk and speed influence wild behavior")
    for kind: String in ["gym","elite","champion"]:
        var size := 5 if kind == "elite" else 6
        var distinct := {}
        for i in size: distinct[EnemyTactics.role(68,kind,i,size)] = true
        check(distinct.size() >= 3 and EnemyTactics.role(68,kind,0,size) == "guardian" and EnemyTactics.role(68,kind,size-1,size) == "setup","Boss parties have distinct opening, attacker and final setup roles")
    for tactic: String in EnemyTactics.PROFILES:
        var b := fixture(tactic)
        var cycle: Array = EnemyTactics.PROFILES[tactic]["cycle"]
        for index in cycle.size()*2:
            var action := b.intent()
            check(action["kind"] == cycle[index%cycle.size()] and action["tactic"] == tactic,"Visible pattern repeats in the advertised order")
            var before := b.snapshot()
            var alternate := b.intent_for(b.party[1])
            check(alternate["kind"] == action["kind"] and alternate["move_id"] == action["move_id"] and b.snapshot() == before,"Preview cannot reroll or change action in response to a defender")
            var hp := b.active().hp
            var block := b.active().block
            var strength := b.enemy().strength
            b.end_turn()
            if action["kind"] in ["attack","charge"]: check(b.active().hp == hp-maxi(0,int(action["value"])-block),"Telegraphed damage equals resolved damage")
            elif action["kind"] == "block": check(b.enemy().block == int(action["value"]) and b.active().hp == hp,"Guard turn grants only the advertised shield")
            else: check(b.enemy().strength == strength+2 and b.active().hp == hp,"Setup spends a turn to gain twenty percent damage bonus")
        check(b.phase == TacticalBattle.PLAYER,"Patterns keep returning control to the player")
    var b := fixture("setup")
    b.enemy().statuses["sleep"] = {"turns":1,"source_uid":4}
    b.end_turn()
    check(b.enemy().strength == 0 and b.intent()["kind"] == "attack","Sleep cancels setup and advances the advertised cycle")
    b = fixture("setup")
    b.end_turn()
    var before_switch := b.intent()
    var energy := b.energy
    b.switch_to(7)
    check(b.intent()["move_id"] == before_switch["move_id"] and b.energy == energy-1,"Manual switch changes target but never rerolls the enemy action or grants energy")
    var struggle := fixture("balanced")
    struggle.enemy_definitions[0]["intents"] = [{"kind":"attack","value":40,"type":"normal","move_id":165}]
    struggle.active().types.assign(["ghost"])
    check(struggle.intent()["value"] > 0,"Support-only enemy's Struggle also bypasses Normal immunity")
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"New pattern saves validate")
    var loaded := JourneySnapshot.restore(data)
    check(JourneySnapshot.encode(loaded) == data and loaded.battle.intent() == j.battle.intent(),"Reload preserves exact pattern position, moves and forecast")
    var malformed := data.duplicate(true)
    malformed["battle"]["enemy_definitions"][0]["tactic"] = "unknown"
    check(not JourneySnapshot.validate(malformed),"Unknown tactic in save is rejected")
    # Existing v3 battles retain their authored pattern; no forced new-run reset.
    for definition: Dictionary in data["battle"]["enemy_definitions"]: definition.erase("tactic")
    check(JourneySnapshot.validate(data),"Legacy saved opponent definitions remain loadable")
    loaded = JourneySnapshot.restore(data)
    check(loaded.battle.intent().get("tactic","") == "" and EnemyTactics.title("") == "기본형","Legacy battle uses a readable fallback without regenerating its moves")
    print("ENEMY_TACTICS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
