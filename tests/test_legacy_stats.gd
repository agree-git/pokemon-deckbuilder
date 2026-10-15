extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func checkpoint(name: String) -> void:
    var store := JourneySave.new("res://tests/fixtures/legacy-stats/legacy-%s.json" % name)
    var old := store._read(store.path)
    check(not old.is_empty() and not old.has("stat_basis"),"Read a genuine pre-removal "+name+" checkpoint")
    if old.is_empty(): return
    var original := var_to_bytes(old)
    var j := store.load_journey()
    check(j != null,"Load the old envelope through the normal save API")
    if j == null: return
    var current := JourneySnapshot.encode(j)
    check(var_to_bytes(old) == original,"Migration never mutates its source")
    check(current["stat_basis"] == PokemonStats.BASIS and JourneySnapshot.validate(current),"Converted graph validates under species-and-level rules")
    check(current["run"] == old["run"] and current["cards"] == old["cards"] and current["route"] == old["route"],"Keep all route, XP, stock, currency, capture, deck and settlement state")
    for key: String in old["battle"]:
        if key in ["events","enemy_definitions"]: continue
        check(current["battle"][key] == old["battle"][key],"Keep paused combat field: "+key)
    for uid: int in old["pokemon"]:
        var before: Dictionary = old["pokemon"][uid]
        var after: Dictionary = current["pokemon"][uid]
        for key: String in before:
            if key in ["max_hp","hp","evolution_training"]: continue
            check(after[key] == before[key],"Keep Pokemon field: "+key)
        var expected := PokemonStats.value(before["species_id"],before["level"],"hp") if before["species_stats"] else int(before["max_hp"])
        var hp: int = 0 if before["hp"] == 0 else maxi(1,expected-(before["max_hp"]-before["hp"]))
        check(after["max_hp"] == expected and after["hp"] == hp,"Preserve missing HP, living minimum and KO while removing old HP bonus")
        check(not after.has("evolution_training"),"No legacy training remains in a new save")
        if before.has("evolution_training"): check(after["evolution_choice"] == 107,"Old defensive preparation keeps Hitmonchan choice without a stat bonus")
    for i in j.battle.enemies.size(): check(j.battle.enemy_definitions[i]["max_hp"] == j.battle.enemies[i].max_hp,"Enemy definition uses migrated HP")
    var fresh := JourneySave.new("user://tests/no_iv_%d_%s.json" % [Time.get_ticks_usec(),name])
    check(fresh.save(j).is_empty(),"Write converted checkpoint")
    var reloaded := fresh.load_journey()
    check(reloaded != null and JourneySnapshot.encode(reloaded) == current,"Second load is exact and cannot reduce HP again or repay energy")
    var corrupt := old.duplicate(true)
    corrupt["pokemon"][j.party[0].uid]["max_hp"] += 1
    check(not JourneySnapshot.validate(corrupt),"Reject an invalid old HP value")
    corrupt = current.duplicate(true)
    corrupt["stat_basis"] = "unknown"
    check(not JourneySnapshot.validate(corrupt),"Reject an unknown stat basis")
    corrupt = current.duplicate(true)
    corrupt["pokemon"][j.party[0].uid]["evolution_training"] = "defense"
    check(not JourneySnapshot.validate(corrupt),"New saves reject old effort metadata")
    if name == "camp":
        check(j.party[0].hp == 1 and j.party[1].hp == 0 and j.party[1].knocked_out and j.party[2].max_hp-j.party[2].hp == 7,"Actual old camp retains low HP, faint and seven missing HP")
        check(j.party[0].attack == j.party[0].defense,"Old Tyrogue effort no longer changes stats")
        var p := j.party[0]
        TacticalGrowth.award(p,(TacticalGrowth.experience_floor(20,236)-p.experience))
        check(p.level == 20 and p.species_id == 107,"Prepared evolution still happens on the next earned level")
    elif name == "battle":
        check(j.battle.active().uid != j.battle.turn_speed_owner_uid,"Fixture really paused after a manual switch")
        var next := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
        check(next.battle.turn_speed_actor == 9 and next.battle.turn_speed_enemy == PokemonStats.effective(next.battle.enemy(),"speed"),"Fresh turns compare only new speeds")
    else:
        check(not j.pending_captures.is_empty() and j.battle.phase == TacticalBattle.WON,"Actual pending capture survives conversion")
        check(j.settle().is_empty(),"Captured victory can settle")
        var settled := JourneySnapshot.encode(j)
        check(j.settle().is_empty() and JourneySnapshot.encode(j) == settled,"Capture settlement cannot pay twice")
func run() -> void:
    for name: String in ["camp","battle","capture"]: checkpoint(name)
    print("LEGACY_STATS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
