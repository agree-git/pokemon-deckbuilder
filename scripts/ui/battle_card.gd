class_name BattleCard
extends Button
## A hand view with ownership/hover cues. Emits a request; never spends energy.

const CARD_SIZE := Vector2(202, 282)
var definition: Dictionary = {}
var home_position := Vector2.ZERO
var home_rotation := 0.0
var available := true
var _motion: Tween
var _owner_label: Label

func _ready() -> void:
    size = CARD_SIZE
    pivot_offset = Vector2(CARD_SIZE.x / 2, CARD_SIZE.y)
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
        add_theme_stylebox_override(state, StyleBoxEmpty.new())
    _label(definition["name"], Vector2(40, 18), Vector2(152, 32), 21, Color("f2e5bd"))
    _label(str(definition["cost"]), Vector2(-7, 0), Vector2(46, 42), 28, Color("f4eccf"), HORIZONTAL_ALIGNMENT_CENTER)
    var art := Control.new()
    art.position = Vector2(12, 61)
    art.size = Vector2(178, 106)
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(art)
    var sprite := Sprite2D.new()
    var id: int = int(definition.get("art_id", definition["owner"] if int(definition["owner"]) > 0 else 4))
    sprite.texture = load(VisualCatalog.sprite_path(id))
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2(2, 2)
    sprite.position = Vector2(89, 51)
    art.add_child(sprite)
    var description := _label(definition["description"], Vector2(16, 178), Vector2(174, 58), 17, Color("29372e"), HORIZONTAL_ALIGNMENT_CENTER)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _owner_label = _label("", Vector2(14, 246), Vector2(174, 25), 13, Color("59614e"), HORIZONTAL_ALIGNMENT_CENTER)
    mouse_entered.connect(_hover.bind(true))
    mouse_exited.connect(_hover.bind(false))
    focus_entered.connect(_hover.bind(true))
    focus_exited.connect(_hover.bind(false))
    set_available(available)

func set_available(value: bool, reason: String = "") -> void:
    available = value
    disabled = not value
    var owner: int = int(definition.get("owner", 0))
    var owner_name: String = definition.get("owner_name", "공용" if owner == 0 else ("파이리" if owner == 4 else "이상해씨"))
    _owner_label.text = "%s · %s" % [owner_name, definition.get("kind", "스킬")]
    if not value:
        _owner_label.text = owner_name + (" · 에너지 부족" if "에너지" in reason else " · 교체 필요" if "교체" in reason else " · 사용 대기")
    tooltip_text = definition.get("name", "") + "\n" + definition.get("description", "")
    if not reason.is_empty():
        tooltip_text += "\n" + reason
    elif definition.has("preview_damage"):
        tooltip_text += "\n상성·공격력 적용 피해: %d" % int(definition["preview_damage"])
    modulate = Color.WHITE if value else Color(0.63, 0.69, 0.64)
    queue_redraw()

func _hover(entered: bool) -> void:
    if not available or not is_inside_tree():
        return
    if _motion:
        _motion.kill()
    z_index = 30 if entered else 0
    _motion = create_tween().set_parallel(true)
    _motion.tween_property(self, "position", home_position + Vector2(0, -42 if entered else 0), 0.12)
    _motion.tween_property(self, "rotation", 0.0 if entered else home_rotation, 0.12)

func _draw() -> void:
    var color := VisualCatalog.type_color(definition.get("type", "normal"))
    var frame := PackedVector2Array([Vector2(9, 0), Vector2(193, 0), Vector2(202, 9), Vector2(202, 273), Vector2(193, 282), Vector2(9, 282), Vector2(0, 273), Vector2(0, 9)])
    draw_colored_polygon(frame, Color("1c302c"))
    draw_polyline(frame + PackedVector2Array([Vector2(9, 0)]), color.darkened(0.1), 3, false)
    draw_rect(Rect2(8, 53, 186, 220), Color("e0d6b6"))
    draw_rect(Rect2(12, 61, 178, 106), color.darkened(0.68))
    for i in 9:
        draw_rect(Rect2(14 + i * 21, 137 - (i % 3) * 19, 14, 29 + (i % 3) * 19), Color(color, 0.11))
    draw_rect(Rect2(9, 237, 184, 1), Color("a6a386"))
    draw_circle(Vector2(16, 20), 25, Color("152a2a"))
    draw_arc(Vector2(16, 20), 25, 0, TAU, 40, Color("cebb79"), 3, false)
    draw_rect(Rect2(13, 275, 176, 3), color.darkened(0.25))

func _label(text_value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = at
    label.size = dimensions
    label.horizontal_alignment = alignment
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    add_child(label)
    return label
