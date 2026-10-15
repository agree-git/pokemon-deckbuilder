extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(text)
func write(path: String, value: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(value)
func run() -> void:
    var directory := "user://tests/save_files_%d" % Time.get_ticks_usec()
    var path := directory+"/journey.json"
    var store := JourneySave.new(path)
    var j := TacticalJourney.new(9223372036854775000,"seed_relay",[1,4,7],true)
    check(store.save(j).is_empty(),"Write a seed larger than JSON's exact integer range")
    check(store.load_journey().seed_value == j.seed_value,"64-bit seed survives disk round trip")
    write(path+".head",JSON.stringify({"version":1,"run_id":j.run_id,"finished":"invalid"}))
    check(store.load_journey() != null,"Malformed metadata cannot hide a valid primary checkpoint")
    store.save(j)
    j.battle.play_card(j.battle.hand.filter(func(c: BattleCardInstance): return c.key == "analysis")[0].uid)
    var backup := JourneySnapshot.encode(j)
    store.save(j)
    j.battle.switch_to(4)
    store.save(j)
    write(path,"{truncated")
    var recovered := store.load_journey()
    check(recovered != null and store.recovered and JourneySnapshot.encode(recovered) == backup,"Corrupt primary restores its same-run backup exactly")
    check(not store.last_error.is_empty(),"Recovery is disclosed")
    # A new attempt must never fall back to an old attempt's backup.
    var next := TacticalJourney.new(42,"seed_relay",[1,4,7],true)
    store.save(next)
    write(path,"broken new attempt")
    check(store.load_journey() == null,"Old-run backup cannot revive after starting a new run")
    store.save(next)
    # Invalid data and incompatible game content are rejected before UI construction.
    var text := FileAccess.get_file_as_string(path)
    var envelope: Dictionary = JSON.parse_string(text)
    envelope["content"] = "different-ruleset"
    write(path,JSON.stringify(envelope))
    check(store.load_journey() == null,"Different content cannot silently change a saved route")
    write(path,text)
    for pokemon: BattlePokemon in next.party: pokemon.hp = 0
    next.battle._outcome()
    next.settle()
    store.save(next)
    write(path,"corrupt final checkpoint")
    check(store.load_journey() == null,"Terminal marker prevents loss/ending backup resurrection")
    next.restart(42)
    store.save(next)
    check(store.load_journey() != null,"A new attempt after terminal state can be resumed")
    var state := JourneySnapshot.encode(next)
    var invalid := state.duplicate(true)
    invalid["battle"]["rng"] = 0.5
    check(not JourneySnapshot.validate(invalid),"Reject lossy RNG state")
    invalid = state.duplicate(true)
    invalid["battle"]["enemy_definitions"][0]["intents"] = []
    check(not JourneySnapshot.validate(invalid),"Reject intents that would crash battle UI")
    invalid = state.duplicate(true)
    invalid["battle"]["piles"][0].append(invalid["battle"]["piles"][0][0])
    check(not JourneySnapshot.validate(invalid),"Reject duplicate card instances")
    invalid = state.duplicate(true)
    invalid["run"]["phase"] = TacticalJourney.LEARN
    invalid["run"]["pending_learning"] = [{"uid":-1,"key":"move_45","level":7}]
    check(not JourneySnapshot.validate(invalid),"Reject learning offers without a party member")
    invalid = state.duplicate(true)
    invalid["pokemon"][1]["learned_skills"] = ["not_a_move"]
    check(not JourneySnapshot.validate(invalid),"Reject unknown moves")
    invalid = state.duplicate(true)
    invalid["run"]["gold"] = -1
    check(not JourneySnapshot.validate(invalid),"Reject invalid resources")
    # Model signals must persist successful actions without relying on rendering or exit.
    var session := root.get_node("BattleSession")
    session.set("save_store",JourneySave.new(directory+"/auto.json"))
    session.set("profile",PlayerProfile.new(directory+"/collection.json"))
    session.adopt_journey(next)
    next.battle.switch_to(4)
    var auto: JourneySave = session.get("save_store")
    check(JourneySnapshot.encode(auto.load_journey()) == JourneySnapshot.encode(next),"Switch autosaves before UI animation")
    var file_before := FileAccess.get_file_as_string(auto.path)
    check(not next.battle.switch_to(4).is_empty() and FileAccess.get_file_as_string(auto.path) == file_before,"Invalid action leaves checkpoint untouched")
    next.battle.enemy().hp = 1 # Threshold fixture only; capture itself remains public.
    check(next.capture().is_empty(),"Capture succeeds at its threshold")
    check(session.get("profile").captured_ids.has(next.pending_captures[0].species_id),"Capture journal synchronizes permanent starter unlocks")
    var captured := auto.load_journey()
    check(captured != null and captured.pending_captures.size() == 1 and captured.balls == next.balls,"Autosave waits until capture transaction is complete")
    if captured != null:
        captured.settle()
        while captured.phase == TacticalJourney.LEARN: captured.resolve_learning(-1)
        check(captured.phase == TacticalJourney.CAPTURE,"Captured member remains pending after reload")
    var bad_path := directory+"/blocker"
    write(bad_path,"file instead of directory")
    session.set("save_store",JourneySave.new(bad_path+"/journey.json"))
    var before_run: TacticalJourney = session.get("journey")
    check(not session.checkpoint().is_empty() and session.get("journey") == before_run,"Write failure is reported without replacing live state")
    session.set("save_store",auto)
    check(session.checkpoint().is_empty(),"Checkpoint can be retried after storage becomes usable")
    print("SAVE_FILES: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
