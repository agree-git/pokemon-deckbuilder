extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func chosen(values: Array) -> Array[int]:
    var typed: Array[int] = []
    typed.assign(values)
    return typed
func run() -> void:
    var catalog := VisualCatalog.new()
    var path := "user://tests/collection_%d.json" % Time.get_ticks_usec()
    var profile := PlayerProfile.new(path)
    check(profile.unlocked_starters(catalog) == [1,4,7],"New profile starts with the three base starters")
    for id: int in [6,373,26,134,197,386]:
        check(profile.record_capture(id,catalog).is_empty(),"Capture writes a permanent profile")
    var expected := profile.captured_ids.duplicate()
    profile.record_capture(6,catalog)
    check(profile.captured_ids == expected,"Duplicate capture is idempotent")
    check(not profile.record_capture(999,catalog).is_empty() and profile.captured_ids == expected,"Invalid capture is rejected")
    var loaded := PlayerProfile.new(path)
    check(loaded.captured_ids == expected and loaded.unlocked_starters(catalog) == [1,4,7,133,172,371,386],"Reload preserves captures and resolves basic starters")
    var session := root.get_node("BattleSession")
    var original: PlayerProfile = session.get("profile")
    session.set("profile",profile)
    var previous: TacticalJourney = session.get("journey")
    for invalid: Array in [[],[4,4],[1,4,7,133],[6],[25]]:
        check(not session.start_journey(chosen(invalid),42).is_empty() and session.get("journey") == previous,"Invalid selection cannot replace existing run")
    check(session.start_journey(chosen([7,4]),42).is_empty(),"Chosen unlocked starters start a run")
    var j: TacticalJourney = session.get("journey")
    check(j.party.size() == 2 and j.party[0].species_id == 7 and j.party[1].species_id == 4 and j.battle.active().species_id == 7,"Party and lead respect selection order")
    j.restart(42)
    check(j.starter_ids == [7,4] and j.party.size() == 2,"Restart preserves original starter selection")
    check(session.start_journey(chosen([371]),42).is_empty(),"Captured evolution's base form can start a solo run")
    j = session.get("journey")
    check(j.party.size() == 1 and j.battle.enemies.size() == 1 and j.battle.active().species_id == 371,"Solo starters have a safe single-enemy opening")
    check(not TacticalContent.skills_for(j.battle.active()).is_empty(),"Unlocked starter has usable skills")
    # Rule fixture: capture at the displayed threshold, then resolve join.
    j = TacticalJourney.new(42,"seed_relay",[4])
    var before := j.battle.snapshot()
    check(not j.capture().is_empty() and j.battle.snapshot() == before and j.balls == 2,"Capture above threshold is atomic")
    j.battle.enemy().hp = 10
    check(j.capture().is_empty() and j.balls == 1 and j.battle.energy == 2 and j.battle.phase == TacticalBattle.WON,"Legal capture costs a ball/energy and resolves wild encounter")
    check(j.battle.opening().get("captured",false) and j.battle.refunds == 0,"Capture does not grant knockout chain refunds")
    j.settle()
    check(j.phase == TacticalJourney.CAPTURE and j.pending_captures.size() == 1,"Captured member waits for explicit join decision")
    check(j.resolve_capture(99) != "" and j.pending_captures.size() == 1,"Invalid join does not consume capture")
    check(j.resolve_capture(0).is_empty() and j.party.size() == 2 and j.party[1].species_id == 43 and j.phase == TacticalJourney.REWARD,"Captured Pokemon joins with identity and skills")
    j.choose_reward(-1)
    j.enter_next()
    j.rest("heal")
    j.leave_camp()
    j.enter_next()
    before = j.battle.snapshot()
    check(not j.capture().is_empty() and j.battle.snapshot() == before and j.balls == 1,"Trainer Pokemon cannot be captured")
    check(j.battle.party.size() == 2 and j.battle.party[1].uid == 1000,"Joined member persists into next battle")
    check(j.battle.switch_to(1000).is_empty() and j.battle.use_skill("move_71").is_empty(),"Captured member can switch in and act")
    var legendary := TacticalJourney.new(42,"seed_relay",[4])
    legendary.battle.enemies[0].species_id = 151
    legendary.battle.enemy().hp = 1
    check(not legendary.capture().is_empty() and legendary.balls == 2,"Legendary/mythical capture cannot use ordinary wild conditions")
    j = TacticalJourney.new(42,"seed_relay",[1,4,7])
    j.battle.enemy().hp = 10
    j.capture()
    for pokemon: BattlePokemon in j.party: j.battle._damage(pokemon,999,true)
    j.battle._outcome()
    j.settle()
    check(j.phase == TacticalJourney.FAILED,"Captured member cannot prevent total party wipe before joining")
    # Corrupted primary profile falls back to a validated backup.
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string("corrupt")
    file.close()
    loaded = PlayerProfile.new(path)
    check(loaded.captured_ids == expected and loaded.last_error.is_empty(),"Backup recovers permanent unlocks after primary corruption")
    check(loaded.save().is_empty() and PlayerProfile.new(path).captured_ids == expected,"Recovered profile can be saved again")
    session.set("profile",original)
    session.set("journey",previous)
    session.set("has_journey",false)
    for suffix: String in ["",".bak",".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
    print("START_FLOW: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
