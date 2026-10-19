class_name BattleCanvas
extends Node2D
## Only a visual stage; no HP, card, or combat rules are simulated here.

const POKEMON := preload("res://scripts/content/pokemon_animation.gd")
const SOURCE := Vector2(240, 320)
const TARGET := Vector2(725, 280)
var background: Texture2D
var canvas_size := Vector2(960, 540)
var source_anchor := SOURCE
var target_anchor := TARGET
var show_nameplates := true
var sprite_zoom := 3.0
var source_motion := Vector2.ZERO
var target_motion := Vector2.ZERO
var source_factor := 1.0
var target_factor := 1.0
var source_sprite := Sprite2D.new()
var target_sprite := Sprite2D.new()
var effect := MoveEffect.new()
var source_species := 0
var target_species := 0
var source_name := ""
var target_name := ""
var status := ""
var status_on_self := false
var weather_layer := BattleWeatherVisual.new()
var weather := "":
    set(value):
        weather = value
        weather_layer.set_weather(value)
var clock := 0.0
var back_view := true
var font := FontVariation.new()
var effect_from_enemy := false
var use_effect_statuses := true
var ally_statuses: Array[String] = []
var enemy_statuses: Array[String] = []
var frame_for_hand := false
var _opaque_bounds: Dictionary = {}
var battlefield_layout: Dictionary = {}
var show_floor_guides := false
var _source_zoom := 0.0
var _target_zoom := 0.0

func set_backdrop(descriptor: Dictionary) -> void:
    background = VisualCatalog.biome_texture(descriptor)
    battlefield_layout = BattlefieldLayout.for_backdrop(descriptor) if frame_for_hand else {}
    layout_battlefield()

func layout_battlefield() -> void:
    if battlefield_layout.is_empty() or background == null: return
    var lift := Vector2(0,88*sprite_zoom/4.0)
    source_anchor = foot_anchor(true)-lift
    target_anchor = foot_anchor(false)-lift
    _fit_sprites()
    queue_redraw()

func zoom_for(on_ally: bool) -> float:
    var fitted := _source_zoom if on_ally else _target_zoom
    return fitted if fitted > 0 else sprite_zoom

func sprite_rect(on_ally: bool,zoom: float = -1) -> Rect2:
    var sprite := source_sprite if on_ally else target_sprite
    var bounds := sprite_bounds(sprite.texture)
    var dimensions := Vector2(bounds.size)*(zoom_for(on_ally) if zoom < 0 else zoom)
    return Rect2(foot_anchor(on_ally)-Vector2(dimensions.x/2,dimensions.y),dimensions)

func _fit_sprites() -> void:
    # Keep integer pixel scales; unusually wide/tall sprites must clear the HUD.
    # Only the real opaque rectangle matters, not transparent 96x96 padding.
    for on_ally: bool in [true,false]:
        var zoom := sprite_zoom
        if frame_for_hand:
            var roster := Rect2(36,104,240,252) if on_ally else Rect2(1644,104,240,450)
            while zoom > 2:
                var rect := sprite_rect(on_ally,zoom).grow(8)
                if rect.position.y >= 132 and not rect.intersects(roster): break
                zoom -= 1
        if on_ally: _source_zoom = zoom
        else: _target_zoom = zoom

func sprite_bounds(texture: Texture2D) -> Rect2i:
    if texture == null: return Rect2i(0,0,96,96)
    if texture.has_meta("pokemon_bounds"): return texture.get_meta("pokemon_bounds")
    var key := texture.get_instance_id()
    if not _opaque_bounds.has(key):
        var pixels := texture.get_image()
        _opaque_bounds[key] = pixels.get_used_rect() if pixels != null and not pixels.is_empty() else Rect2i(Vector2i.ZERO,Vector2i(texture.get_size()))
    return _opaque_bounds[key]

func foot_anchor(on_ally: bool) -> Vector2:
    if not battlefield_layout.is_empty() and background != null:
        return BattlefieldLayout.project(battlefield_layout,on_ally,canvas_size,background.get_size())
    return (source_anchor if on_ally else target_anchor)+Vector2(0,88*sprite_zoom/4.0)

func _grounded_position(sprite: Sprite2D,on_ally: bool) -> Vector2:
    if sprite.texture == null: return source_anchor if on_ally else target_anchor
    var bounds := sprite_bounds(sprite.texture)
    var center := sprite.texture.get_size()/2
    var offset := Vector2(bounds.position.x+bounds.size.x/2.0,bounds.end.y)-center
    var zoom := zoom_for(on_ally)*(source_factor if on_ally else target_factor)
    return (foot_anchor(on_ally)-offset*zoom+(source_motion if on_ally else target_motion)).round()

func _ready() -> void:
    font.base_font = preload("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(source_sprite)
    add_child(target_sprite)
    source_sprite.scale = Vector2.ONE * sprite_zoom
    target_sprite.scale = Vector2.ONE * sprite_zoom
    add_child(weather_layer)
    add_child(effect)
    effect.impact.connect(_on_impact)

func _process(delta: float) -> void:
    clock += delta
    var top := 72.0 if frame_for_hand else 0.0
    var bottom := minf(780.0,canvas_size.y) if frame_for_hand else canvas_size.y
    weather_layer.position = Vector2(0,top)
    weather_layer.size = Vector2(canvas_size.x,maxf(0,bottom-top))
    source_sprite.position = _grounded_position(source_sprite,true)
    target_sprite.position = _grounded_position(target_sprite,false)
    source_sprite.scale = Vector2.ONE*zoom_for(true)*source_factor
    target_sprite.scale = Vector2.ONE*zoom_for(false)*target_factor
    queue_redraw()

func set_species(source_id: int, target_id: int, catalog: VisualCatalog, clear: bool = true) -> void:
    source_species = source_id
    target_species = target_id
    POKEMON.bind(source_sprite,source_id,back_view)
    POKEMON.bind(target_sprite,target_id)
    _fit_sprites()
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
    var tween := UiMotion.combat(sprite,"impact_flash")
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
        # Frame the terrain for the visible battlefield above the hand. Covering
        # the entire 1080px canvas put the ground behind the lower HUD instead.
        var cover := canvas_size.x/background.get_width() if frame_for_hand else maxf(canvas_size.x/background.get_width(),canvas_size.y/background.get_height())
        var dimensions := background.get_size() * cover
        var origin := Vector2(0,foot_anchor(true).y-dimensions.y*0.82).floor() if frame_for_hand else ((canvas_size-dimensions)*0.5).floor()
        if not battlefield_layout.is_empty():
            var measured_frame := BattlefieldLayout.frame(battlefield_layout,canvas_size,background.get_size())
            dimensions = measured_frame.size
            origin = measured_frame.position
        draw_texture_rect(background, Rect2(origin, dimensions), false)
        var bottom := origin.y+dimensions.y
        if frame_for_hand and bottom < canvas_size.y:
            # Fade into the hand table instead of stretching a 2px edge into
            # long vertical streaks below the original artwork.
            var floor_color := Color(0.025,0.06,0.075)
            for y in range(floori(bottom)-48,ceili(bottom),4):
                draw_rect(Rect2(0,y,canvas_size.x,4),Color(floor_color,clampf((y-(bottom-48))/44.0,0,1)))
            draw_rect(Rect2(0,bottom,canvas_size.x,canvas_size.y-bottom),floor_color)
    else:
        draw_rect(Rect2(Vector2.ZERO, canvas_size), Color("243d3a"))
    _contact_shadow(true)
    _contact_shadow(false)
    if show_floor_guides and not battlefield_layout.is_empty():
        _floor_guides()
    if show_nameplates:
        _nameplate(source_anchor + Vector2(-90, 119), source_name, Color("9ee3bb"))
        _nameplate(target_anchor + Vector2(-90, 112), target_name, Color("ffdba2"))
    if not status.is_empty():
        MoveEffect.draw_status(self, status, source_anchor if status_on_self else target_anchor, clock * 2)
    for i in ally_statuses.size():
        MoveEffect.draw_status(self, ally_statuses[i], source_anchor + Vector2(i * 24, 0), clock * 2)
    for i in enemy_statuses.size():
        MoveEffect.draw_status(self, enemy_statuses[i], target_anchor + Vector2(i * 24, 0), clock * 2)

func _contact_shadow(on_ally: bool) -> void:
    var sprite := source_sprite if on_ally else target_sprite
    var factor := clampf(source_factor if on_ally else target_factor,0,1)
    if factor < 0.05 or sprite.texture == null: return
    var bounds := sprite_bounds(sprite.texture)
    var radius := clampf(bounds.size.x*zoom_for(on_ally)*0.42,28,108)*factor
    var point := foot_anchor(on_ally)+(source_motion if on_ally else target_motion)+Vector2(0,-4)
    # Stepped ellipse strips retain crisp 4px edges at the native UI resolution.
    for y in range(-16,17,4):
        var half := floorf(sqrt(maxf(0,1-pow(y/20.0,2)))*radius/4)*4
        draw_rect(Rect2((point+Vector2(-half,y)).round(),Vector2(half*2,4)),Color(0.025,0.055,0.07,0.36*factor))
    for y in range(-8,9,4):
        var half := floorf(sqrt(maxf(0,1-pow(y/12.0,2)))*radius*0.63/4)*4
        draw_rect(Rect2((point+Vector2(-half,y)).round(),Vector2(half*2,4)),Color(0.02,0.04,0.045,0.34*factor))

func _floor_guides() -> void:
    draw_line(foot_anchor(true),foot_anchor(false),Color(1,1,1,0.6),2)
    for ally: bool in [true,false]:
        var p := foot_anchor(ally)
        var ink := Color("78ffbe") if ally else Color("ffb86b")
        draw_circle(p,28,Color(0.02,0.04,0.07,0.7))
        draw_arc(p,32,0,TAU,48,ink,3)
        draw_line(p-Vector2(42,0),p+Vector2(42,0),ink,3)
        draw_line(p-Vector2(0,42),p+Vector2(0,42),ink,3)
        var source := BattlefieldLayout.point(battlefield_layout,ally)
        var text := "%s cell(%.1f,%.1f) screen(%.1f,%.1f)" % ["ALLY" if ally else "ENEMY",source.x,source.y,p.x,p.y]
        var at := p+Vector2(-180,70)
        draw_rect(Rect2(at-Vector2(8,27),Vector2(410,38)),Color(0.02,0.04,0.07,0.94))
        draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,21,ink)

func _nameplate(point: Vector2, text: String, color: Color) -> void:
    draw_rect(Rect2(point + Vector2(-12, -40), Vector2(246, 54)), Color(0.025, 0.06, 0.09, 0.83))
    draw_rect(Rect2(point + Vector2(-12, -40), Vector2(5, 54)), color)
    draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, 228, 40, Color("f3f3e9"))
