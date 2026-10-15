extends SceneTree
var output := "/workspace/.cloud-setup/pokemon-deckbuilder/previews"
var captured: Dictionary = {}
var ui: TacticalUI
func _initialize() -> void:
    call_deferred("run")
func save(name_text: String) -> void:
    if captured.has(name_text): return
    captured[name_text] = true
    await process_frame
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if picture.get_size() != Vector2i(1920,1080) or picture.save_png(output.path_join(name_text+".png")) != OK:
        push_error("Tactical screenshot failed")
        quit(1)
        return
    print("TACTICAL_CAPTURE: ",name_text)
func run() -> void:
    if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    ui.restart()
    await save("tactics_start")
    for guard in 100:
        if ui.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var step := TacticalPolicy.action(ui.battle)
        match step[0]:
            "skill": ui._skill(step[1])
            "card": ui._card(step[1])
            "switch": ui._switch(step[1])
            _: ui._end()
        if ui.battle.events.any(func(e: Dictionary): return e["kind"] == "break"):
            ui.stage.canvas.effect._process(MoveEffect.DURATION*0.6/ui.stage.canvas.effect.speed)
            await save("tactics_break_%d" % ui.battle.enemy_index)
        if ui.battle.events.any(func(e: Dictionary): return e["kind"] == "chain"):
            ui.stage.canvas.effect._process(MoveEffect.DURATION*0.6/ui.stage.canvas.effect.speed)
            await save("tactics_finisher")
        ui.stage.canvas.effect._process(MoveEffect.DURATION)
        await create_timer(0.75).timeout
    await save("tactics_result")
    ui.restart("break_focus")
    await save("tactics_trait")
    ui.free()
    quit()
