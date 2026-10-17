extends SceneTree
## Optional X11 real-pointer check; use tools/native_pointer.py with a separate user profile.
var checks := 0
var failures := 0
var clicks := 0
var output_dir := OS.get_environment("SOUNDSCAPE_REVIEW_DIR")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click_at(control: Control, ratio: Vector2) -> void:
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*ratio))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(.3).timeout
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    var prefs := root.get_node("Preferences")
    prefs.show_panel(menu)
    await create_timer(.4).timeout
    var panel: Control = prefs.panel
    var slider: HSlider = panel.volume_sliders["ambience"]
    var music_before: float = prefs.music_volume
    var effects_before: float = prefs.effects_volume
    await click_at(slider,Vector2(.5,.5))
    print("OS_KEY Home")
    await create_timer(.3).timeout
    check(is_zero_approx(prefs.ambience_volume),"Actual slider keyboard Home sets zero")
    print("OS_KEY End")
    await create_timer(.3).timeout
    check(is_equal_approx(prefs.ambience_volume,1),"Actual slider keyboard End sets maximum")
    await click_at(slider,Vector2(.4,.5))
    check(prefs.ambience_volume > .3 and prefs.ambience_volume < .5,"Actual pointer sets environment volume")
    check(is_equal_approx(prefs.music_volume,music_before) and is_equal_approx(prefs.effects_volume,effects_before),"Environment slider leaves music and effects untouched")
    for channel: String in panel.volume_sliders:
        var row: HSlider = panel.volume_sliders[channel]
        check(row.get_global_rect().end.y < panel.preview_button.get_global_rect().position.y,"Volume row clears preview buttons: "+channel)
    if not output_dir.is_empty():
        DirAccess.make_dir_recursive_absolute(output_dir)
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(output_dir.path_join("settings.png")) == OK,"Settings screenshot")
    await click_at(panel.close_button,Vector2(.5,.5))
    check(prefs.panel == null,"Pointer closes settings")
    prefs.show_panel(menu)
    await create_timer(.3).timeout
    panel = prefs.panel
    check(is_equal_approx(panel.volume_sliders["ambience"].value,prefs.ambience_volume*100),"Reopened settings retains volume")
    var config := ConfigFile.new()
    check(config.load(prefs.path) == OK and is_equal_approx(config.get_value("audio","ambience",-1),prefs.ambience_volume),"Actual pointer choice saved")
    panel.close()
    menu.free()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameAmbience").stop_ambience()
    await process_frame
    # Let the audio mixer release stopped WAV playbacks before engine teardown.
    await create_timer(.15).timeout
    print("NATIVE_SOUNDSCAPE: ",checks," checks / ",failures," failures; ",clicks," clicks")
    quit(0 if failures == 0 else 1)
