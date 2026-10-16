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

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.045, 0.82)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    body = W.panel(self, Rect2(480, 185, 960, 710), Color("122a32"), Color("627573"), 16)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.icon(body, "settings", Rect2(40, 36, 36, 36))
    W.label(body, "설정", Rect2(94, 22, 550, 60), 34, W.GOLD)
    close_button = W.icon_button(body, "close", Rect2(862, 28, 58, 48), close, "닫기 · Esc")
    W.label(body, "화면", Rect2(40, 116, 850, 34), 23)
    var modes := ["windowed", "maximized", "fullscreen"]
    var titles := ["창 모드", "최대화", "전체 화면"]
    for i in modes.size():
        mode_buttons[modes[i]] = _option(titles[i], Rect2(40 + i * 294, 164, 280, 54), preferences.set_display_mode.bind(modes[i]))
    W.label(body, "화면 전환 F11 · 창 크기에 맞춰 화면 비율을 유지합니다.", Rect2(40, 226, 880, 34), 17, W.MUTED)
    W.label(body, "전투 연출 속도", Rect2(40, 302, 850, 34), 23)
    for i in preferences.SPEEDS.size():
        var speed: float = preferences.SPEEDS[i]
        speed_buttons[speed] = _option("%s배" % str(speed), Rect2(40 + i * 294, 350, 280, 54), preferences.set_battle_speed.bind(speed))
    W.label(body, "공격·교대·카드 효과의 재생 속도에 적용됩니다.", Rect2(40, 412, 880, 34), 17, W.MUTED)
    W.label(body, "피격 흔들림", Rect2(40, 485, 550, 44), 23)
    motion_button = _option("", Rect2(678, 480, 240, 54), func(): preferences.set_hit_motion(not preferences.hit_motion))
    W.label(body, "끄면 피격 시 흔들림을 줄입니다. 피해 숫자는 계속 표시됩니다.", Rect2(40, 542, 880, 34), 17, W.MUTED)
    status = W.label(body, "", Rect2(40, 621, 680, 46), 16, W.MUTED)
    retry_button = _option("다시 저장", Rect2(748, 621, 170, 46), preferences.save_preferences)
    preferences.changed.connect(_sync)
    get_tree().root.size_changed.connect(_sync)
    _sync()
    UiMotion.open(self)

func _option(title: String, rect: Rect2, action: Callable) -> Button:
    var button := W.button(body, rect, action, title)
    button.add_theme_font_size_override("font_size", 21)
    return button

func _selected(button: Button, selected: bool) -> void:
    button.add_theme_stylebox_override("normal", W.box(Color("304c47") if selected else Color("1b333b"), W.GOLD if selected else Color("4a6267")))
    button.add_theme_color_override("font_color", W.GOLD if selected else W.TEXT)

func _sync() -> void:
    for speed: float in speed_buttons: _selected(speed_buttons[speed], speed == preferences.battle_speed)
    for mode: String in mode_buttons: _selected(mode_buttons[mode], mode == preferences.current_display_mode())
    motion_button.text = "켜짐" if preferences.hit_motion else "꺼짐"
    _selected(motion_button, preferences.hit_motion)
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
    get_viewport().set_input_as_handled()
