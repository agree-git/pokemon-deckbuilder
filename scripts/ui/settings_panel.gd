extends Control
## Shared modal for title, combat and camp. No expedition-state dependencies.
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
var preferences: Node
var body: Panel
var close_button: Button
var retry_button: Button
var speed_buttons: Dictionary = {}
var mode_buttons: Dictionary = {}
var motion_button: Button
var status: Label
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var mute_button: Button
var preview_button: Button
var cry_preview_button: Button

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.045, 0.82)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    body = W.panel(self, Rect2(480, 78, 960, 924), Color("122a32"), Color("627573"), 16)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.icon(body, "settings", Rect2(40, 36, 36, 36))
    W.label(body, "설정", Rect2(94, 22, 550, 60), 34, W.GOLD)
    close_button = W.icon_button(body, "close", Rect2(862, 28, 58, 48), close, "닫기 · Esc")
    W.label(body, "화면", Rect2(40, 94, 850, 34), 23)
    var modes := ["windowed", "maximized", "fullscreen"]
    var titles := ["창 모드", "최대화", "전체 화면"]
    for i in modes.size():
        mode_buttons[modes[i]] = _option(titles[i], Rect2(40 + i * 294, 136, 280, 54), preferences.set_display_mode.bind(modes[i]))
    W.label(body, "화면 전환 F11 · 창 크기에 맞춰 화면 비율을 유지합니다.", Rect2(40, 198, 880, 34), 17, W.MUTED)
    W.label(body, "전투 연출 속도", Rect2(40, 230, 850, 34), 23)
    for i in preferences.SPEEDS.size():
        var speed: float = preferences.SPEEDS[i]
        speed_buttons[speed] = _option("%s배" % str(speed), Rect2(40 + i * 294, 274, 280, 54), preferences.set_battle_speed.bind(speed))
    W.label(body, "공격·교대·카드 효과의 재생 속도에 적용됩니다.", Rect2(40, 336, 880, 34), 17, W.MUTED)
    W.label(body, "피격 흔들림", Rect2(40, 374, 550, 44), 23)
    motion_button = _option("", Rect2(678, 369, 240, 54), func(): preferences.set_hit_motion(not preferences.hit_motion))
    W.label(body, "끄면 피격 시 흔들림을 줄입니다. 피해 숫자는 계속 표시됩니다.", Rect2(40, 431, 880, 34), 17, W.MUTED)
    W.icon(body, "sound", Rect2(40, 480, 28, 28))
    W.label(body, "소리", Rect2(82, 470, 500, 44), 23)
    mute_button = _option("", Rect2(678, 469, 240, 48), func(): preferences.set_audio_muted(not preferences.audio_muted))
    _audio_row("master", "전체 음량", 526)
    _audio_row("effects", "효과음 음량", 578)
    _audio_row("music", "음악 음량", 630)
    _audio_row("cries", "울음소리 음량", 682)
    _audio_row("ambience", "환경음 음량", 734)
    preview_button = _option("효과음 듣기", Rect2(40, 786, 250, 48), func(): get_node("/root/GameAudio").play("shield"))
    cry_preview_button = _option("울음소리 듣기", Rect2(310, 786, 250, 48), func(): get_node("/root/GameCries").play(25))
    W.label(body, "피카츄 · 현재 음량으로 재생", Rect2(584, 786, 334, 48), 17, W.MUTED)
    status = W.label(body, "", Rect2(40, 846, 680, 46), 16, W.MUTED)
    retry_button = _option("다시 저장", Rect2(748, 846, 170, 46), preferences.save_preferences)
    preferences.changed.connect(_sync)
    get_tree().root.size_changed.connect(_sync)
    _sync()
    UiMotion.open(self)

func _option(title: String, rect: Rect2, action: Callable) -> Button:
    var button := W.button(body, rect, action, title)
    button.add_theme_font_size_override("font_size", 21)
    return button

func _audio_row(channel: String, title: String, y: int) -> void:
    W.label(body, title, Rect2(40, y, 190, 44), 20)
    var slider := HSlider.new()
    slider.position = Vector2(244, y + 6)
    slider.size = Vector2(452, 32)
    slider.min_value = 0
    slider.max_value = 100
    slider.step = 1
    slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for track: String in ["slider", "grabber_area", "grabber_area_highlight"]:
        var rail := W.box(Color("314b52") if track == "slider" else (W.GOLD if track == "grabber_area_highlight" else Color("95b7a6")), Color("587374"), 4)
        rail.content_margin_top = 4
        rail.content_margin_bottom = 4
        slider.add_theme_stylebox_override(track, rail)
    slider.value_changed.connect(func(value: float): preferences.set_audio_volume(channel, value / 100.0))
    body.add_child(slider)
    volume_sliders[channel] = slider
    volume_labels[channel] = W.label(body, "", Rect2(726, y, 192, 44), 21, W.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

func _selected(button: Button, selected: bool) -> void:
    button.add_theme_stylebox_override("normal", W.box(Color("304c47") if selected else Color("1b333b"), W.GOLD if selected else Color("4a6267")))
    button.add_theme_color_override("font_color", W.GOLD if selected else W.TEXT)

func _sync() -> void:
    for speed: float in speed_buttons: _selected(speed_buttons[speed], speed == preferences.battle_speed)
    for mode: String in mode_buttons: _selected(mode_buttons[mode], mode == preferences.current_display_mode())
    motion_button.text = "켜짐" if preferences.hit_motion else "꺼짐"
    _selected(motion_button, preferences.hit_motion)
    for channel: String in volume_sliders:
        var value := float(preferences.get(channel + "_volume"))
        volume_sliders[channel].set_value_no_signal(value * 100.0)
        volume_labels[channel].text = "%d%%" % roundi(value * 100)
    mute_button.text = "음소거 켜짐" if preferences.audio_muted else "음소거 꺼짐"
    _selected(mute_button, preferences.audio_muted)
    preview_button.disabled = preferences.audio_muted or preferences.master_volume <= 0 or preferences.effects_volume <= 0
    cry_preview_button.disabled = preferences.audio_muted or preferences.master_volume <= 0 or preferences.cries_volume <= 0
    status.text = "변경 사항은 자동으로 저장됩니다." if preferences.last_error.is_empty() else preferences.last_error
    status.add_theme_color_override("font_color", W.MUTED if preferences.last_error.is_empty() else W.GOLD)
    retry_button.visible = not preferences.last_error.is_empty()

func close() -> void:
    hide()
    closed.emit()

func _input(event: InputEvent) -> void:
    if not visible or not event is InputEventKey: return
    if event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE: close()
        elif event.keycode == KEY_F11: preferences.toggle_fullscreen()
        elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
            var focused := get_viewport().gui_get_focus_owner()
            if focused is HSlider and is_ancestor_of(focused):
                match event.keycode:
                    KEY_LEFT: focused.value -= focused.step
                    KEY_RIGHT: focused.value += focused.step
                    KEY_HOME: focused.value = focused.min_value
                    KEY_END: focused.value = focused.max_value
    get_viewport().set_input_as_handled()
