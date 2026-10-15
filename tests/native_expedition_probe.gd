extends SceneTree
## Whole expedition controlled only by X11 mouse events from the Python harness.
const Player = preload("res://tests/expedition_ui_player.gd")
func _initialize() -> void:
    call_deferred("run")
func state(ui: BattleUI) -> String:
    return str([ui.run.phase,ui.run.step,ui.run.deck.size(),ui.run.reward_pending,
        ui.run.pending_capture.uid if ui.run.pending_capture != null else -1,ui.battle.snapshot()])
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    var session_run: RunState = root.get_node("BattleSession").get("run")
    session_run.restart(2026)
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await create_timer(0.3).timeout
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    await create_timer(0.3).timeout
    var clicks := 0
    for guard in 800:
        if session_run.phase in [RunState.CLEARED,RunState.FAILED]:
            break
        var button := Player.button_for(ui)
        if button == null or button.disabled or not button.is_visible_in_tree():
            push_error("Native run requested unavailable control")
            quit(1)
            return
        var before := state(ui)
        var at := Vector2(root.position) + root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size/2))
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.25).timeout
        if ui.animating:
            ui.stage.canvas.effect._process(MoveEffect.DURATION)
        await process_frame
        if state(ui) == before:
            push_error("Native mouse click missed in %s at step %d, screen %s" % [session_run.phase,session_run.step,at])
            quit(1)
            return
        clicks += 1
        if clicks % 20 == 0:
            print("NATIVE_RUN_PROGRESS: ",clicks," clicks; stop ",session_run.step+1,"/9")
    var success := session_run.phase == RunState.CLEARED and ui.expedition.visible
    print("NATIVE_EXPEDITION: ","PASS" if success else "FAIL","; ",clicks," OS clicks; ",session_run.phase)
    ui.free()
    quit(0 if success else 1)
