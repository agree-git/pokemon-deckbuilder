extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var script := load("res://scripts/preferences.gd")
    var preferences: Node = script.new()
    preferences.path = "user://settings-test.cfg"
    if FileAccess.file_exists(preferences.path): DirAccess.remove_absolute(preferences.path)
    preferences.load_preferences()
    check(preferences.battle_speed == 1.0 and preferences.hit_motion and preferences.display_mode == "maximized", "New installs retain normal playback and maximized native UI")
    check(preferences.master_volume == 0.75 and preferences.effects_volume == 0.8 and preferences.music_volume == 0.55 and preferences.cries_volume == 0.75 and not preferences.audio_muted, "Legacy or missing audio fields retain moderate audible defaults")
    preferences.set_battle_speed(2.0)
    preferences.set_hit_motion(false)
    preferences.display_mode = "windowed"
    check(preferences.save_preferences() == OK, "Preferences persist without an expedition")
    var copy: Node = script.new()
    copy.path = preferences.path
    copy.load_preferences()
    check(copy.battle_speed == 2.0 and not copy.hit_motion and copy.display_mode == "windowed", "Reload restores all options")
    check(not FileAccess.file_exists(preferences.path + ".tmp"), "Atomic replacement leaves no temporary config")
    var contents := FileAccess.get_file_as_string(preferences.path)
    preferences.set_battle_speed(0.0)
    preferences.set_display_mode("invalid")
    check(preferences.battle_speed == 2.0 and preferences.display_mode == "windowed" and contents == FileAccess.get_file_as_string(preferences.path), "Unsupported choices do not save or apply")
    var config := ConfigFile.new()
    config.set_value("presentation", "battle_speed", "2.0")
    config.set_value("presentation", "hit_motion", "false")
    config.set_value("display", "mode", 3)
    config.set_value("audio", "master", NAN)
    config.set_value("audio", "effects", "0.5")
    config.set_value("audio", "music", 2.0)
    config.set_value("audio", "cries", -0.1)
    config.set_value("audio", "muted", "false")
    config.save(preferences.path)
    copy.load_preferences()
    check(copy.battle_speed == 1.0 and copy.hit_motion and copy.display_mode == "maximized", "Wrong types fall back independently to safe defaults")
    check(copy.master_volume == 0.75 and copy.effects_volume == 0.8 and copy.music_volume == 0.55 and copy.cries_volume == 0.75 and not copy.audio_muted, "Invalid audio fields independently fall back to defaults")
    config.set_value("presentation", "battle_speed", -1.0)
    config.set_value("presentation", "hit_motion", false)
    config.set_value("display", "mode", "fullscreen")
    config.save(preferences.path)
    copy.load_preferences()
    check(copy.battle_speed == 1.0 and not copy.hit_motion and copy.display_mode == "fullscreen", "Invalid speed cannot discard other valid fields")
    var broken := FileAccess.open(preferences.path, FileAccess.WRITE)
    broken.store_string("[unfinished")
    broken.close()
    var printed_errors := Engine.print_error_messages
    Engine.print_error_messages = false # This malformed fixture deliberately exercises ConfigFile's parser.
    copy.load_preferences()
    Engine.print_error_messages = printed_errors
    check(copy.battle_speed == 1.0 and copy.hit_motion and not copy.last_error.is_empty(), "Corrupt config reports a recoverable warning")
    check(copy.save_preferences() == OK and copy.last_error.is_empty(), "Saving repairs invalid preferences")
    var repaired := FileAccess.get_file_as_string(copy.path)
    preferences.path = "user://missing-settings-parent/settings.cfg"
    Engine.print_error_messages = false # Deliberately unwritable isolated destination.
    var save_error: Error = preferences.save_preferences()
    Engine.print_error_messages = printed_errors
    check(save_error != OK and not preferences.last_error.is_empty() and preferences.battle_speed == 2.0, "Save failure reports status while retaining the in-memory choice")
    check(FileAccess.get_file_as_string(copy.path) == repaired, "A failed save cannot overwrite the existing config")
    preferences.path = copy.path
    check(preferences.save_preferences() == OK and preferences.last_error.is_empty(), "Retry recovers after the storage path is repaired")
    preferences.free()
    copy.free()
    var actual := root.get_node("Preferences")
    actual.path = "user://settings-runtime-test.cfg"
    # Timing affects presentation only: compare automatic switching, damage and RNG.
    var expected: Dictionary = {}
    var normal_time := 0.0
    for speed: float in actual.SPEEDS:
        actual.set_battle_speed(speed)
        actual.set_hit_motion(true)
        var b := TacticalBattle.new(71)
        b.energy = 8
        b.enemy().max_hp = 500
        b.enemy().hp = 500
        b.hand.assign([BattleCardInstance.new(101, "move_55", 7)])
        var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
        ui.battle = b
        root.add_child(ui)
        await process_frame
        var start := Time.get_ticks_msec()
        ui._card(101)
        check(ui.busy and b.active().uid == 7, "Technique commits automatically switched owner at speed %s" % speed)
        var committed := b.snapshot()
        if expected.is_empty(): expected = committed
        else: check(committed == expected, "Playback speed cannot change rules, cards or RNG")
        for i in 500:
            if not ui.busy: break
            await create_timer(0.01).timeout
        var elapsed := (Time.get_ticks_msec() - start) / 1000.0
        check(not ui.busy and b.snapshot() == committed, "Timed sequence completes without a second rule mutation")
        check(ui.playback_kinds.find("switch") < ui.playback_kinds.find("skill") and ui.playback_kinds.find("skill") < ui.playback_kinds.find("damage"), "All playback speeds preserve switch, attack, damage order")
        if speed == 1.0: normal_time = elapsed
        elif speed == 2.0: check(elapsed < normal_time * 0.75, "Double speed measurably shortens the same sequence")
        UiMotion.finish_tree(ui)
        check(ui.stage.canvas.position == Vector2.ZERO and ui.stage.canvas.source_motion == Vector2.ZERO and ui.stage.canvas.target_motion == Vector2.ZERO, "Motion always returns to calibrated positions")
        actual.set_hit_motion(false)
        ui.motion.hit(true)
        await process_frame
        check(ui.stage.canvas.position == Vector2.ZERO and ui.stage.canvas.source_motion == Vector2.ZERO, "Disabled hit motion keeps battlefield and Pokemon steady")
        ui.free()
    root.get_node("GameMusic").stop_music()
    await create_timer(0.12).timeout # Let the mixer release playback owned by the UI fixtures.
    print("SETTINGS: ", checks, " checks, ", failures, " failures")
    quit(0 if failures == 0 else 1)
