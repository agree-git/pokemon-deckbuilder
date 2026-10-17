extends Node
## Presentation preferences live separately from expedition/profile saves.
signal changed
const PATH := "user://settings.cfg"
const SPEEDS: Array[float] = [1.0, 1.5, 2.0]
const MODES: Array[String] = ["windowed", "maximized", "fullscreen"]
var path := PATH
var battle_speed := 1.0
var hit_motion := true
var display_mode := "maximized"
var master_volume := 0.75
var effects_volume := 0.8
var music_volume := 0.55
var ambience_volume := 0.55
var cries_volume := 0.75
var audio_muted := false
var last_error := ""
var panel: Control

func _ready() -> void:
    load_preferences()
    apply_display()

func load_preferences() -> void:
    battle_speed = 1.0
    hit_motion = true
    display_mode = "maximized"
    master_volume = 0.75
    effects_volume = 0.8
    music_volume = 0.55
    ambience_volume = 0.55
    cries_volume = 0.75
    audio_muted = false
    last_error = ""
    var config := ConfigFile.new()
    var error := config.load(path)
    if error == ERR_FILE_NOT_FOUND: return
    if error != OK:
        last_error = "설정 파일을 읽지 못해 기본 설정을 사용합니다."
        return
    var speed: Variant = config.get_value("presentation", "battle_speed", 1.0)
    if (speed is float or speed is int) and float(speed) in SPEEDS:
        battle_speed = float(speed)
    var motion: Variant = config.get_value("presentation", "hit_motion", true)
    if motion is bool: hit_motion = motion
    var mode: Variant = config.get_value("display", "mode", "maximized")
    if mode is String and mode in MODES: display_mode = mode
    for channel: String in ["master", "effects", "music", "cries", "ambience"]:
        var volume: Variant = config.get_value("audio", channel, get(channel + "_volume"))
        if (volume is float or volume is int) and is_finite(float(volume)) and float(volume) >= 0 and float(volume) <= 1:
            set(channel + "_volume", float(volume))
    var muted: Variant = config.get_value("audio", "muted", false)
    if muted is bool: audio_muted = muted

func save_preferences() -> Error:
    var config := ConfigFile.new()
    config.set_value("presentation", "battle_speed", battle_speed)
    config.set_value("presentation", "hit_motion", hit_motion)
    config.set_value("display", "mode", display_mode)
    config.set_value("audio", "master", master_volume)
    config.set_value("audio", "effects", effects_volume)
    config.set_value("audio", "music", music_volume)
    config.set_value("audio", "ambience", ambience_volume)
    config.set_value("audio", "cries", cries_volume)
    config.set_value("audio", "muted", audio_muted)
    var error := config.save(path + ".tmp")
    if error == OK:
        error = DirAccess.rename_absolute(path + ".tmp", path)
    last_error = "" if error == OK else "설정을 저장하지 못했습니다. 현재 실행에는 적용됩니다."
    changed.emit()
    return error

func set_battle_speed(value: float) -> void:
    if value not in SPEEDS or value == battle_speed: return
    battle_speed = value
    save_preferences()

func set_hit_motion(value: bool) -> void:
    if value == hit_motion: return
    hit_motion = value
    save_preferences()

func set_audio_volume(channel: String, value: float) -> void:
    if channel not in ["master", "effects", "music", "cries", "ambience"] or not is_finite(value) or value < 0 or value > 1: return
    if get(channel + "_volume") == value: return
    set(channel + "_volume", value)
    save_preferences()

func set_audio_muted(value: bool) -> void:
    if value == audio_muted: return
    audio_muted = value
    save_preferences()

func set_display_mode(value: String) -> void:
    if value not in MODES: return
    display_mode = value
    apply_display()
    save_preferences()

func current_display_mode() -> String:
    if DisplayServer.get_name() == "headless": return display_mode
    match DisplayServer.window_get_mode():
        DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: return "fullscreen"
        DisplayServer.WINDOW_MODE_MAXIMIZED: return "maximized"
    return "windowed"

func toggle_fullscreen() -> void:
    set_display_mode("windowed" if current_display_mode() == "fullscreen" else "fullscreen")

func apply_display() -> void:
    if DisplayServer.get_name() == "headless": return
    match display_mode:
        "fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        "maximized": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
        "windowed":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            _size_window()

func _size_window() -> void:
    var usable := DisplayServer.screen_get_usable_rect()
    var dimensions := Vector2i(mini(1280, usable.size.x - 32), mini(720, usable.size.y - 64))
    DisplayServer.window_set_size(dimensions)
    DisplayServer.window_set_position(usable.position + (usable.size - dimensions) / 2)

func show_panel(host: Control) -> void:
    if is_instance_valid(panel): return
    var layer := CanvasLayer.new()
    layer.layer = 90
    host.add_child(layer)
    panel = load("res://scripts/ui/settings_panel.gd").new()
    panel.theme = host.theme
    layer.add_child(panel)
    panel.closed.connect(func():
        panel = null
        layer.queue_free())

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
        toggle_fullscreen()
        get_viewport().set_input_as_handled()
