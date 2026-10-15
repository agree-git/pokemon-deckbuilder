extends SceneTree
## Capture boundaries, persistent deck ownership, full-party decisions and UI flow.
const RouteSupport = preload("res://tests/route_test_support.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func ready_capture(state: BattleState) -> void:
    state.enemy.hp = state.enemy.max_hp / 4
    state.energy = 1
func run() -> void:
    var expedition := RunState.new(41)
    var state := expedition.battle
    for restriction: String in ["hp", "energy", "ball", "trainer", "boss", "dead", "replace", "finished"]:
        state.restart(41)
        ready_capture(state)
        match restriction:
            "hp": state.enemy.hp += 1
            "energy": state.energy = 0
            "ball": state.balls = 0
            "trainer", "boss": state.wild = false
            "dead": state.enemy.hp = 0
            "replace": state.phase = BattleState.REPLACE
            "finished": state.phase = BattleState.WON
        var snapshot := state.snapshot()
        check(not state.capture().is_empty() and state.snapshot() == snapshot, "Rejected capture must not mutate: " + restriction)
    expedition.restart(41)
    state = expedition.battle
    state.party[0].hp = 17
    state.party[0].strength = 5
    ready_capture(state)
    check(state.capture().is_empty(), "Exact 25% HP and 1 energy allow capture")
    check(state.phase == BattleState.CAPTURED and state.energy == 0 and state.balls == 1, "Capture spends resources exactly once and ends battle")
    var snapshot := state.snapshot()
    check(not state.capture().is_empty() and state.snapshot() == snapshot, "Capture cannot repeat")
    expedition.settle()
    var caught := expedition.party[2]
    check(expedition.party.size() == 3 and caught.hp == caught.max_hp, "Caught ally joins fully healed")
    check(expedition.deck.size() == 16 and expedition.balls == 1, "Capture adds exactly two owned cards")
    expedition.settle()
    check(expedition.deck.size() == 16 and expedition.party.size() == 3, "Settlement is idempotent")
    check(RouteSupport.next_encounter(expedition).is_empty(), "Can enter the next encounter")
    check(expedition.battle.enemy.species_id == 7 and expedition.battle.party[0].hp == 17, "Next encounter changes enemy and preserves HP")
    check(expedition.battle.party[0].strength == 0 and expedition.battle.balls == 1, "Temporary buffs reset but balls persist")
    check(expedition.battle.switch_to(caught.uid).is_empty(), "Captured ally is playable next battle")
    for card: BattleCardInstance in expedition.battle.hand + expedition.battle.draw_pile:
        if card.owner_uid == caught.uid:
            check(expedition.battle.card_view(card)["art_id"] == 43, "Owned card uses instance species, not uid")
    var absorb: BattleCardInstance
    for card: BattleCardInstance in expedition.battle.hand + expedition.battle.draw_pile:
        if card.owner_uid == caught.uid and card.key == "absorb":
            absorb = card
    if absorb in expedition.battle.draw_pile:
        expedition.battle.draw_pile.erase(absorb)
        expedition.battle.hand.append(absorb)
    caught.hp = caught.max_hp - 1
    var hp_before := expedition.battle.enemy.hp
    check(expedition.battle.play_card(absorb.uid).is_empty(), "Captured owned card can actually be played")
    check(caught.hp == caught.max_hp and expedition.battle.enemy.hp == hp_before - 9, "Absorb applies grass weakness and heals without exceeding max HP")
    # Link a persistent injury to a party member, then replace that member.
    var injury := BattleCardInstance.new(500, "injury", 0)
    injury.injury_owner_uid = 4
    expedition.battle.discard.append(injury)
    ready_capture(expedition.battle)
    check(expedition.battle.capture().is_empty(), "Second capture succeeds with last ball")
    expedition.settle()
    check(expedition.pending_capture != null and expedition.party.size() == 3, "Full party requires an explicit choice")
    var deck_size := expedition.deck.size()
    check(not RouteSupport.next_encounter(expedition).is_empty(), "Cannot continue while replacement is pending")
    check(not expedition.resolve_capture(-999).is_empty() and expedition.deck.size() == deck_size, "Invalid release leaves party and deck unchanged")
    check(expedition.resolve_capture(4).is_empty(), "Replace initial Charmander with captured Squirtle")
    check(expedition.party.size() == 3 and expedition.party[2].species_id == 7 and expedition.balls == 0, "Replacement preserves party cap and consumes the ball")
    for card: BattleCardInstance in expedition.deck:
        check(card.owner_uid != 4 and card.injury_owner_uid != 4, "Release removes owned cards and linked injury")
    check(expedition.deck.size() == 14, "Release keeps common cards and adds two new owned cards")
    check(RouteSupport.next_encounter(expedition).is_empty() and expedition.battle.draw_pile.size() + expedition.battle.hand.size() == 14, "Replacement deck starts correctly")
    # Duplicate species need different instance UIDs; releasing the new catch keeps deck.
    expedition.battle.balls = 1
    expedition.battle.enemy = BattlePokemon.new(BattleContent.ENCOUNTERS[2],-1) # Duplicate-species fixture.
    expedition.battle.wild = true
    ready_capture(expedition.battle)
    expedition.battle.capture()
    expedition.settle()
    var pending := expedition.pending_capture
    var previous := expedition.deck.duplicate()
    check(pending.uid != 4 and pending.uid != caught.uid, "Duplicate species have unique ownership IDs")
    check(expedition.resolve_capture(pending.uid).is_empty() and expedition.deck == previous and expedition.balls == 0, "Releasing catch keeps deck but never refunds ball")
    # KO cards and the linked injury survive into the run; dead owners stay excluded.
    expedition.restart()
    expedition.battle._damage(expedition.battle.party[0], 999, true)
    expedition.battle.enemy.hp = 0
    expedition.battle._check_outcome()
    expedition.settle()
    check(expedition.deck.size() == 15, "KO excludes owned cards only from battle and adds persistent injury")
    expedition.choose_reward(-1)
    RouteSupport.next_encounter(expedition)
    check(expedition.battle.active().uid == 1 and expedition.battle.removed.size() == 4, "Next battle selects live ally and excludes KO owner's cards")
    # Actual window-coordinate clicks route capture -> join -> next encounter.
    var session: Node = root.get_node("BattleSession")
    var session_run: RunState = session.get("run")
    session_run.restart()
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    ready_capture(ui.battle)
    ui._refresh()
    click(ui.capture_button)
    await process_frame
    check(ui._result.visible and ui._result_title.text == "포획 성공", "Clicking visible capture button opens result")
    check(session_run.party.size() == 3 and not ui._next_button.disabled, "UI joins catch and enables continuation")
    click(ui._next_button)
    await process_frame
    check(ui.expedition.visible and session_run.phase == RunState.MAP, "Result continues to route map")
    click(ui.expedition.action_buttons[0])
    await process_frame
    check(ui.battle.enemy.species_id == 7 and ui.party_buttons.size() == 3 and not ui._result.visible, "Clicking visible next button enters battle with three allies")
    ready_capture(ui.battle)
    ui._refresh()
    click(ui.capture_button)
    await process_frame
    check(ui._capture_choices.get_child_count() == 4 and ui._next_button.disabled, "Full party UI offers all three releases plus new-catch release")
    click(ui._capture_choices.get_child(0))
    await process_frame
    check(session_run.pending_capture == null and not ui._next_button.disabled, "Visible party-choice click resolves replacement")
    ui.restart_battle()
    ui.free()
    print("CAPTURE_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
func click(button: Button) -> void:
    var at := root.get_final_transform() * button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion)
    for down: bool in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event)
