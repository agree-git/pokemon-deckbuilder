extends SceneTree
## Rule tests and real window-coordinate clicks for victory card rewards.
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
func win(expedition: RunState) -> void:
    expedition.battle.enemy.hp = 0
    expedition.battle._check_outcome()
    expedition.settle()
func snapshot(expedition: RunState) -> Dictionary:
    var cards: Array = []
    for card: BattleCardInstance in expedition.deck:
        cards.append([card.uid, card.key, card.owner_uid, card.injury_owner_uid])
    return {"deck": cards, "options": expedition.reward_options.duplicate(true),
        "pending": expedition.reward_pending, "result": expedition.reward_result,
        "encounter": expedition.encounter, "battle": expedition.battle.snapshot()}
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    var seen: Dictionary = {}
    for battle_seed in range(32):
        var expedition := RunState.new(battle_seed)
        check(not expedition.choose_reward(0).is_empty(), "No reward during battle")
        var battle_before := expedition.battle.snapshot()
        expedition.settle()
        check(not expedition.reward_pending and expedition.battle.snapshot() == battle_before, "Settling an ongoing battle has no effect")
        win(expedition)
        var options := expedition.reward_options.duplicate(true)
        seen[str(options)] = true
        check(options.size() == 3 and expedition.reward_pending, "Victory offers three cards")
        var unique: Dictionary = {}
        for option: Dictionary in options:
            unique[str(option)] = true
            check(option["owner"] in [1,4] and option["key"] in BattleContent.LEARNSETS[option["owner"]], "Only current party learnsets are offered")
        check(unique.size() == 3, "Offers do not repeat an owner/card pair")
        var same := RunState.new(battle_seed)
        win(same)
        check(same.reward_options == options, "Same seed reproduces the offers")
        var before := snapshot(expedition)
        expedition.settle()
        check(snapshot(expedition) == before, "Repeated settlement never rerolls")
        check(not RouteSupport.next_encounter(expedition).is_empty() and snapshot(expedition) == before, "Pending reward blocks continuation without state changes")
        for invalid in [-2,3,999]:
            check(not expedition.choose_reward(invalid).is_empty() and snapshot(expedition) == before, "Invalid selection is atomic")
        var view := expedition.reward_view(0)
        view["name"] = "mutated preview"
        check(expedition.reward_view(0)["name"] != view["name"], "UI preview cannot mutate card content")
        var selected: Dictionary = options[battle_seed % 3]
        check(expedition.choose_reward(battle_seed % 3).is_empty(), "Offered reward can be claimed")
        var card := expedition.deck.back() as BattleCardInstance
        check(expedition.deck.size() == 15 and card.key == selected["key"] and card.owner_uid == selected["owner"], "Exactly one selected owned card enters the run deck")
        before = snapshot(expedition)
        check(not expedition.choose_reward(0).is_empty() and snapshot(expedition) == before, "Repeated claim cannot duplicate cards")
        check(RouteSupport.next_encounter(expedition).is_empty(), "Resolved reward allows continuation")
        check(card in expedition.battle.hand + expedition.battle.draw_pile, "Reward reaches the next battle's draw pool")
        var ids: Dictionary = {}
        for item: BattleCardInstance in expedition.battle.hand + expedition.battle.draw_pile:
            ids[item.uid] = true
        check(ids.size() == 15 and not expedition.reward_pending and expedition.reward_options.is_empty(), "Card IDs are unique and previous rewards clear")
        var deck_before := same.deck.duplicate()
        check(same.choose_reward(-1).is_empty() and same.deck == deck_before, "Skipping keeps the deck unchanged")
        check(RouteSupport.next_encounter(same).is_empty(), "Skipping permits continuation")
    check(seen.size() > 1, "Different seeds vary the offers")
    var expedition := RunState.new()
    expedition.battle.party[0].hp = 0
    win(expedition)
    for option: Dictionary in expedition.reward_options:
        check(option["owner"] == 1, "KO party member is excluded from current rewards")
    expedition.restart()
    expedition.battle.enemy.hp = 16
    expedition.battle.capture()
    expedition.settle()
    check(not expedition.reward_pending and expedition.reward_options.is_empty(), "Capture never grants victory rewards")
    RouteSupport.next_encounter(expedition)
    # Keep only the newly captured instance alive; uid differs from species number.
    expedition.party[0].hp = 0
    expedition.party[1].hp = 0
    win(expedition)
    var captured := expedition.party[2]
    for i in expedition.reward_options.size():
        check(expedition.reward_options[i]["owner"] == captured.uid and expedition.reward_view(i)["art_id"] == 43, "Captured instance owns its rewards and uses the correct sprite")
    check(expedition.choose_reward(0).is_empty(), "Captured Pokemon can learn a reward")
    var learned := expedition.deck.back() as BattleCardInstance
    RouteSupport.next_encounter(expedition)
    expedition.battle.wild = true # Fixture: a wild encounter for release cleanup.
    expedition.battle.enemy = BattlePokemon.new(BattleContent.ENEMY,-1)
    expedition.battle.balls = 1 # Fixture: one more ball to exercise full-party release.
    expedition.battle.enemy.hp = expedition.battle.enemy.max_hp / 4
    expedition.battle.capture()
    expedition.settle()
    expedition.resolve_capture(captured.uid)
    check(learned not in expedition.deck, "Releasing a member also removes its learned reward card")
    for card: BattleCardInstance in expedition.deck:
        check(card.owner_uid != captured.uid, "All released instance's cards are removed")
    expedition.restart()
    for pokemon: BattlePokemon in expedition.party:
        pokemon.hp = 0
    expedition.battle._check_outcome()
    expedition.settle()
    check(not expedition.reward_pending and not expedition.choose_reward(0).is_empty(), "Defeat grants no rewards")
    expedition.restart()
    check(not expedition.reward_pending and expedition.reward_options.is_empty() and expedition.reward_result.is_empty(), "Restart clears reward state")
    # Click a displayed reward, retain the result across UI reentry, then continue.
    var session_run: RunState = root.get_node("BattleSession").get("run")
    session_run.restart()
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    win(session_run)
    ui._refresh()
    var options := session_run.reward_options.duplicate(true)
    check(ui._reward_cards.visible and ui._reward_cards.get_child_count() == 3 and not ui._next_button.visible, "Victory UI displays choices and gates continuation")
    ui.queue_free()
    await process_frame
    ui = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(session_run.reward_options == options and ui._reward_cards.visible, "Scene reentry preserves pending offers")
    for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768)]:
        root.size = dimensions
        await process_frame
        await process_frame
        for child: Node in ui._reward_cards.get_children():
            var card := child as BattleCard
            for local: Vector2 in [Vector2(101,12),Vector2(101,141),Vector2(101,270)]:
                var motion := InputEventMouseMotion.new()
                motion.position = root.get_final_transform() * (card.get_global_transform_with_canvas() * local)
                root.push_input(motion)
                await process_frame
                check(root.gui_get_hovered_control() == card, "Reward hit area matches visible card at each window size")
    click(ui._reward_cards.get_child(1))
    await process_frame
    check(session_run.deck.size() == 15 and not ui._reward_cards.visible and ui._next_button.visible, "Pointer selection claims exactly one card and reveals continue")
    var selected_card := session_run.deck.back() as BattleCardInstance
    ui._choose_reward(1)
    check(session_run.deck.size() == 15, "Stale UI callback cannot duplicate reward")
    ui.queue_free()
    await process_frame
    ui = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(not ui._reward_cards.visible and ui._result_detail.text == session_run.reward_result, "Claimed reward remains resolved after reentry")
    click(ui._next_button)
    await process_frame
    check(ui.expedition.visible and session_run.phase == RunState.MAP, "Result continues to route map")
    click(ui.expedition.action_buttons[0])
    await process_frame
    check(ui.battle == session_run.battle and selected_card in ui.battle.hand + ui.battle.draw_pile, "Pointer continuation uses the updated deck")
    win(session_run)
    ui._refresh()
    var count := session_run.deck.size()
    click(ui._reward_skip)
    await process_frame
    check(session_run.deck.size() == count and ui._next_button.visible and not ui._reward_skip.visible, "Pointer skip keeps deck and reveals continue")
    ui.restart_battle()
    ui.free()
    print("REWARD_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
func click(button: Button) -> void:
    var at := root.get_final_transform() * button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion)
    for down: bool in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event)
