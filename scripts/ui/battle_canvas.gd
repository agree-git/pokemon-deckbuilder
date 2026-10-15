class_name BattleCanvas
extends Node2D
## Only a visual stage; no HP, card, or combat rules are simulated here.

const SOURCE := Vector2(240, 320)
const TARGET := Vector2(725, 280)
var background: Texture2D
var canvas_size := Vector2(960, 540)
var source_anchor := SOURCE
var target_anchor := TARGET
var show_nameplates := true
var sprite_zoom := 3.0
var source_sprite := Sprite2D.new()
var target_sprite := Sprite2D.new()
var effect := MoveEffect.new()
var source_name := ""
var target_name := ""
var status := ""
var status_on_self := false
var clock := 0.0
var back_view := true
var font := FontVariation.new()
var effect_from_enemy := false
var use_effect_statuses := true
var ally_statuses: Array[String] = []
var enemy_statuses: Array[String] = []

func _ready() -> void:
    font.base_font = preload("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(source_sprite)
    add_child(target_sprite)
    source_sprite.scale = Vector2.ONE * sprite_zoom
    target_sprite.scale = Vector2.ONE * sprite_zoom
    add_child(effect)
    effect.impact.connect(_on_impact)

func _process(delta: float) -> void:
    clock += delta
    source_sprite.position = (source_anchor + Vector2(0, roundf(sin(clock * 2.4) * 3))).round()
    target_sprite.position = (target_anchor + Vector2(0, roundf(sin(clock * 2.1 + 1) * 3))).round()
    queue_redraw()

func set_species(source_id: int, target_id: int, catalog: VisualCatalog, clear: bool = true) -> void:
    source_sprite.texture = load(VisualCatalog.sprite_path(source_id, back_view))
    target_sprite.texture = load(VisualCatalog.sprite_path(target_id))
    source_name = catalog.species(source_id)["name"]
    target_name = catalog.species(target_id)["name"]
    if clear:
        clear_effects()

func clear_effects() -> void:
    effect.stop()
    status = ""
    source_sprite.modulate = Color.WHITE
    target_sprite.modulate = Color.WHITE

func _on_impact(move: Dictionary) -> void:
    var on_self: bool = move["vfx"]["target"] == "self"
    var hits_ally: bool = on_self != effect_from_enemy
    var sprite := source_sprite if hits_ally else target_sprite
    var tween := create_tween()
    sprite.modulate = Color(1.4, 1.4, 1.4)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)
    if not use_effect_statuses:
        return
    var kind: String = move["vfx"]["primary"]
    if kind in ["burn", "poison", "paralysis", "sleep", "freeze", "confusion", "seed", "bind"]:
        status = kind
        status_on_self = on_self
    elif not move["vfx"]["secondary"].is_empty():
        status = move["vfx"]["secondary"]
        status_on_self = on_self

func _draw() -> void:
    if background:
        var cover := maxf(canvas_size.x / background.get_width(), canvas_size.y / background.get_height())
        var dimensions := background.get_size() * cover
        draw_texture_rect(background, Rect2(((canvas_size - dimensions) * 0.5).floor(), dimensions), false)
    else:
        draw_rect(Rect2(Vector2.ZERO, canvas_size), Color("243d3a"))
    # Shadows and labels remain understated so both small sprites read clearly.
    for point: Vector2 in [source_anchor + Vector2(0, 80), target_anchor + Vector2(0, 78)]:
        draw_set_transform(point, 0, Vector2(1, 0.24))
        draw_circle(Vector2.ZERO, 78, Color(0.03, 0.07, 0.1, 0.35))
    draw_set_transform(Vector2.ZERO)
    if show_nameplates:
        _nameplate(source_anchor + Vector2(-90, 119), source_name, Color("9ee3bb"))
        _nameplate(target_anchor + Vector2(-90, 112), target_name, Color("ffdba2"))
    if not status.is_empty():
        MoveEffect.draw_status(self, status, source_anchor if status_on_self else target_anchor, clock * 2)
    for i in ally_statuses.size():
        MoveEffect.draw_status(self, ally_statuses[i], source_anchor + Vector2(i * 24, 0), clock * 2)
    for i in enemy_statuses.size():
        MoveEffect.draw_status(self, enemy_statuses[i], target_anchor + Vector2(i * 24, 0), clock * 2)

func _nameplate(point: Vector2, text: String, color: Color) -> void:
    draw_rect(Rect2(point + Vector2(-12, -40), Vector2(246, 54)), Color(0.025, 0.06, 0.09, 0.83))
    draw_rect(Rect2(point + Vector2(-12, -40), Vector2(5, 54)), color)
    draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, 228, 40, Color("f3f3e9"))
