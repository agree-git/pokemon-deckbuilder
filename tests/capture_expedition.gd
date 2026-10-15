extends SceneTree
## Screenshot a complete pointer-driven expedition using the actual renderer.
const Player = preload("res://tests/expedition_ui_player.gd")
var output: String
var captured: Dictionary = {}
func _initialize() -> void:
    call_deferred("run")
func save(name_text: String) -> void:
    if captured.has(name_text):
        return
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if picture.get_size() != Vector2i(1920,1080) or picture.save_png(output.path_join(name_text+".png")) != OK:
        push_error("Expedition screenshot failed")
        quit(1)
        return
    captured[name_text] = true
    print("EXPEDITION_CAPTURE: ",name_text)
func run() -> void:
    output = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://.godot/previews"
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    var state: RunState = root.get_node("BattleSession").get("run")
    state.restart(2026)
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    await save("expedition_start")
    for guard in 800:
        if state.phase == RunState.MAP and state.step == 1:
            await save("expedition_map")
            ui.expedition._deck_panel.show()
            await save("expedition_deck")
            ui.expedition._deck_panel.hide()
        elif state.phase == RunState.REST and state.step == 2:
            await save("expedition_rest")
        elif state.phase == RunState.REST and state.step == 5:
            await save("expedition_evolution_ready")
        elif state.phase == RunState.MAP and state.step == 6:
            await save("expedition_evolved")
        elif state.phase == RunState.BATTLE and state.step == 8 and ui.battle.turn == 1:
            await save("expedition_boss")
        elif state.phase in [RunState.CLEARED,RunState.FAILED]:
            break
        var reason: String = await Player.step(ui,self)
        if not reason.is_empty():
            push_error(reason)
            quit(1)
            return
    if state.phase != RunState.CLEARED:
        push_error("Pointer-driven screenshot run did not clear")
        quit(1)
        return
    await save("expedition_cleared")
    ui.restart_battle()
    for guard in 100:
        if state.phase == RunState.FAILED:
            break
        if ui.battle.phase == BattleState.REPLACE:
            for i in ui.battle.party.size():
                if not ui.party_buttons[i].disabled:
                    Player.click(self,ui.party_buttons[i])
                    break
        else:
            Player.click(self,ui.end_turn)
        await process_frame
        if ui.animating:
            ui.stage.canvas.effect._process(MoveEffect.DURATION)
        await process_frame
    if state.phase != RunState.FAILED:
        push_error("No-card defeat fixture did not end")
        quit(1)
        return
    await save("expedition_failed")
    ui.restart_battle()
    ui.free()
    print("EXPEDITION_CAPTURE_OK: ",captured.size()," native 1920x1080 scenes")
    quit()
