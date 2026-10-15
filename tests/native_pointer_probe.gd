extends SceneTree
## Companion for tools/test_native_pointer.py: uses real OS mouse events under X11.
var failures := 0
var ui: BattleUI
var presses := 0
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    ui = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    var log_button: Button
    for child: Node in ui.get_children():
        if child is Button and child.text == "전투 기록":
            log_button = child
    print("OS_FOCUS ", DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    await create_timer(0.3).timeout
    for button: Button in [log_button, ui.end_turn]:
        button.pressed.connect(func(): presses += 1)
    for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(1024,768), Vector2i(900,900)]:
        root.size = dimensions
        root.position = Vector2i(20,20)
        await create_timer(0.2).timeout
        ui.restart_battle()
        for button: Button in [log_button, ui.end_turn]:
            for local: Vector2 in [Vector2(button.size.x/2,3), button.size/2, Vector2(button.size.x/2,button.size.y-3)]:
                # Viewport transforms exclude the OS window origin. Add it once.
                var at := Vector2(root.position) + root.get_final_transform() * (button.get_global_transform_with_canvas() * local)
                var before := presses
                print("OS_CLICK ", roundi(at.x), " ", roundi(at.y))
                await create_timer(0.3).timeout
                if presses != before+1:
                    failures += 1
                    push_error("OS click missed rendered %s at %s in %s" % [button.text, at, dimensions])
                ui._biome_popup.hide()
                if ui.animating:
                    ui.stage.canvas.effect._process(MoveEffect.DURATION)
    ui.free()
    print("NATIVE_POINTER: ", failures, " failures (18 real OS clicks)")
    quit(0 if failures == 0 else 1)
