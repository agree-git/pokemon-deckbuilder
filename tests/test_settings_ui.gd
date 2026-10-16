extends SceneTree
var native := false
var checks := 0
var failures := 0
var clicks := 0
var preferences: Node
var previewed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle(host: Node) -> void:
    UiMotion.finish_tree(host)
    UiMotion.finish_tree(host)
func click(control: Control) -> void:
    settle(root)
    if native:
        var at := Vector2(root.position) + root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size / 2))
        print("OS_CLICK ", roundi(at.x), " ", roundi(at.y))
        await create_timer(0.22).timeout
    else:
        TacticalUIPlayer.click(self, control)
        await process_frame
    clicks += 1
    settle(root)
func key(code: Key, symbol: String) -> void:
    if native:
        print("OS_KEY ", symbol)
        await create_timer(0.20).timeout
    else:
        for down: bool in [true, false]:
            var event := InputEventKey.new()
            event.keycode = code
            event.pressed = down
            root.push_input(event)
        await process_frame
    settle(root)
func picture() -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("/tmp/pokemon-settings-screen.png") == OK, "Capture rendered settings panel")
func run() -> void:
    Engine.max_fps = 60
    preferences = root.get_node("Preferences")
    preferences.path = "user://settings-ui-test.cfg"
    preferences.set_battle_speed(1.0)
    preferences.set_hit_motion(true)
    preferences.set_audio_volume("master", 0.75)
    preferences.set_audio_volume("effects", 0.8)
    preferences.set_audio_muted(false)
    root.get_node("GameAudio").cue_played.connect(func(cue: String): previewed.append(cue))
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920, 1080)
    root.position = Vector2i.ZERO
    if native: root.mode = Window.MODE_FULLSCREEN
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    if native:
        print("OS_FOCUS ", DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var session := root.get_node("BattleSession")
    var had_journey: bool = session.has_journey
    var journey_before: TacticalJourney = session.journey
    var profile_before: Array[int] = session.profile.captured_ids.duplicate()
    await click(menu.settings_button)
    check(is_instance_valid(preferences.panel), "Title settings opens via pointer")
    if not is_instance_valid(preferences.panel): quit(1); return
    var panel: Control = preferences.panel
    await click(panel.speed_buttons[1.5])
    check(preferences.battle_speed == 1.5, "Pointer selects intermediate playback speed")
    await click(panel.motion_button)
    check(not preferences.hit_motion and panel.motion_button.text == "꺼짐", "Hit motion toggles with visible state")
    await click(panel.volume_sliders["master"])
    await click(panel.volume_sliders["effects"])
    check(preferences.master_volume == 0.5 and preferences.effects_volume == 0.5 and panel.volume_labels["master"].text == "50%", "Real slider hitboxes update both gains and percentage labels")
    await key(KEY_LEFT, "Left")
    check(preferences.effects_volume == 0.49, "Focused volume slider accepts arrow keys inside the modal")
    await key(KEY_RIGHT, "Right")
    check(preferences.effects_volume == 0.5, "Arrow adjustment returns precisely without forwarding battle hotkeys")
    previewed.clear()
    await click(panel.preview_button)
    check("shield" in previewed, "Sound preview triggers the real effect service")
    await click(panel.mute_button)
    check(preferences.audio_muted and panel.preview_button.disabled and AudioServer.is_bus_mute(AudioServer.get_bus_index("Game")), "Mute immediately silences the bus and disables preview")
    previewed.clear()
    await click(panel.preview_button)
    check(previewed.is_empty(), "Muted preview cannot emit any sound")
    await click(panel.mute_button)
    check(not preferences.audio_muted and not panel.preview_button.disabled, "Unmute restores preview without changing gains")
    await picture()
    await click(menu.start_button)
    check(menu.mode == "title" and preferences.panel == panel, "Modal prevents clicks reaching the title underneath")
    await key(KEY_ESCAPE, "Escape")
    check(not is_instance_valid(preferences.panel) and menu.mode == "title", "Escape closes only settings")
    check(session.has_journey == had_journey and session.journey == journey_before and session.profile.captured_ids == profile_before, "Settings cannot start a journey or change permanent unlocks")
    for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(900, 900)]:
        root.mode = Window.MODE_WINDOWED
        root.size = dimensions
        root.position = Vector2i.ZERO
        await process_frame
        await click(menu.settings_button)
        panel = preferences.panel
        check(is_instance_valid(panel), "Settings remains clickable at %s" % dimensions)
        if not is_instance_valid(panel): quit(1); return
        await click(panel.speed_buttons[2.0])
        check(preferences.battle_speed == 2.0, "Scaled settings hitboxes align at %s" % dimensions)
        await click(panel.volume_sliders["effects"])
        check(preferences.effects_volume == 0.5, "Audio slider hitbox aligns at %s" % dimensions)
        await click(panel.close_button)
        check(not is_instance_valid(preferences.panel), "Close hitbox aligns at %s" % dimensions)
    menu.free()
    var b := TacticalBattle.new(71)
    b.energy = 8
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    await process_frame
    settle(root)
    await click(ui.menu_button)
    await click(ui.settings_button)
    check(is_instance_valid(preferences.panel) and ui.menu_panel.visible, "Battle menu opens common settings above the existing menu")
    panel = preferences.panel
    var before := b.snapshot()
    for input: Array in [[KEY_Q, "q"], [KEY_2, "2"], [KEY_ENTER, "Return"]]: await key(input[0], input[1])
    check(b.snapshot() == before and not ui.busy, "Settings blocks card, switch and end-turn hotkeys")
    await click(panel.speed_buttons[2.0])
    await click(panel.motion_button)
    await key(KEY_ESCAPE, "Escape")
    check(not is_instance_valid(preferences.panel) and ui.menu_panel.visible and b.snapshot() == before, "Closing settings preserves battle and underlying menu")
    await key(KEY_ESCAPE, "Escape")
    check(not ui.menu_panel.visible, "Second Escape returns to combat")
    await key(KEY_Q, "q")
    check(b.snapshot() != before and int(b.statistics["counts"]["cards_played"]) == 1, "Battle input resumes after settings closes")
    ui.finish_presentation()
    settle(root)
    ui.free()
    var j := TacticalJourney.new(2026, "field_kit", [1,4,7], false)
    j.phase = TacticalJourney.MAP
    j.step = 1
    j.enter_next()
    var camp: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    camp.journey = j
    root.add_child(camp)
    await process_frame
    await click(camp.settings_button)
    check(is_instance_valid(preferences.panel) and j.phase == TacticalJourney.REST, "Camp opens the same settings")
    panel = preferences.panel
    var gold := j.gold
    var hp := j.party[0].hp
    await key(KEY_ESCAPE, "Escape")
    check(camp.is_inside_tree() and j.gold == gold and j.party[0].hp == hp and j.phase == TacticalJourney.REST, "Settings Escape does not leave camp or consume its resources")
    await click(camp.settings_button)
    panel = preferences.panel
    if native:
        await click(panel.mode_buttons["fullscreen"])
        await create_timer(0.35).timeout
        check(preferences.current_display_mode() == "fullscreen", "Real display enters fullscreen")
        await key(KEY_F11, "F11")
        await create_timer(0.35).timeout
        check(preferences.current_display_mode() == "windowed" and preferences.display_mode == "windowed", "F11 leaves fullscreen once and persists the choice")
        await click(panel.mode_buttons["maximized"])
        await create_timer(0.35).timeout
        check(preferences.current_display_mode() == "maximized", "Real display maximizes")
    await click(panel.close_button)
    var loaded: Node = load("res://scripts/preferences.gd").new()
    loaded.path = preferences.path
    loaded.load_preferences()
    check(loaded.battle_speed == preferences.battle_speed and loaded.hit_motion == preferences.hit_motion and loaded.display_mode == preferences.display_mode and loaded.master_volume == preferences.master_volume and loaded.effects_volume == preferences.effects_volume and loaded.audio_muted == preferences.audio_muted, "Latest UI choices reload from disk")
    loaded.free()
    camp.free()
    print("SETTINGS UI native=", native, ": ", checks, " checks, ", failures, " failures; ", clicks, " clicks")
    quit(0 if failures == 0 else 1)
