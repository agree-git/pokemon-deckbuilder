extends SceneTree
## Sends window-coordinate mouse events through Godot's stretch/input conversion.
var failures := 0
var presses := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func mouse(at: Vector2, click := false) -> void:
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion)
    if click:
        for down: bool in [true, false]:
            var event := InputEventMouseButton.new()
            event.position = at
            event.button_index = MOUSE_BUTTON_LEFT
            event.pressed = down
            root.push_input(event)
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    var log_button: Button
    for child: Node in ui.get_children():
        if child is Button and child.text == "전투 기록":
            log_button = child
    log_button.pressed.connect(func(): presses += 1)
    for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(1364,1024), Vector2i(1024,768)]:
        root.size = dimensions
        await process_frame
        await process_frame
        check(root.size == dimensions, "Pointer test must use the requested window size")
        for button: Button in [log_button, ui.end_turn, ui.party_buttons[1]]:
            for local: Vector2 in [Vector2(button.size.x/2, 3), button.size/2, Vector2(button.size.x/2, button.size.y-3)]:
                var point := root.get_final_transform() * (button.get_global_transform_with_canvas() * local)
                mouse(point)
                await process_frame
                check(root.gui_get_hovered_control() == button, "Visible button hit mismatch %s/%s at %s hover=%s" % [dimensions, button.text, local, root.gui_get_hovered_control()])
        var before := presses
        mouse(root.get_final_transform() * log_button.get_global_rect().get_center(), true)
        await process_frame
        check(presses == before+1, "Click at rendered center must activate log button")
        mouse(root.get_final_transform() * log_button.get_global_rect().get_center(), true)
        await process_frame # Close the popup through the same pointer path.
    # Raised cards must receive input ahead of the cards they visibly cover.
    root.size = Vector2i(1920,1080)
    await process_frame
    var card: BattleCard = ui.cards[0]
    card.set_available(true)
    mouse(root.get_final_transform() * (card.get_global_transform_with_canvas() * Vector2(70,80)))
    await create_timer(0.2).timeout
    var overlap := card.get_global_transform_with_canvas() * Vector2(195,180)
    mouse(root.get_final_transform() * overlap)
    await process_frame
    check(root.gui_get_hovered_control() == card, "Raised card must receive input in its visible overlap")
    var card_uid := int(card.definition["uid"])
    mouse(root.get_final_transform() * overlap, true)
    await process_frame
    check(ui.battle._find_hand(card_uid) == null, "Clicking raised overlap must play that visible card")
    if ui.animating:
        ui.stage.canvas.effect._process(MoveEffect.DURATION)
    # A modal is drawn above the hand and must also receive clicks above it.
    ui.restart_battle()
    ui.battle.enemy.hp = 0
    ui.battle._check_outcome()
    ui._refresh()
    ui._choose_reward(-1)
    for local: Vector2 in [Vector2(155,3), Vector2(155,31), Vector2(155,59)]:
        mouse(root.get_final_transform() * (ui._next_button.get_global_transform_with_canvas() * local))
        await process_frame
        check(root.gui_get_hovered_control() == ui._next_button, "Result button hit area must cover its visible top, center and bottom")
    ui.restart_battle()
    ui.free()
    print("Pointer checks: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
    quit(0 if failures == 0 else 1)
