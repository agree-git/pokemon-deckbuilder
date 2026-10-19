extends Node2D
## Read-only presentation of resolved conditions; never decides damage or turns.
const COLORS := {
    "burn":Color("ff9857"), "poison":Color("d69bff"),
    "paralysis":Color("ffe46b"), "sleep":Color("b2caff"),
    "freeze":Color("9eeeff"), "confusion":Color("ffb7ed"),
    "seed":Color("a0e8a0"), "bind":Color("dfc5a4"),
    "curse":Color("c3a0e9"), "sand":Color("e1c58c"),
}
var canvas: BattleCanvas
var pulses: Array[Dictionary] = []

static func from_text(value: String) -> String:
    for pair: Array in [["맹독","poison"],["독","poison"],["화상","burn"],["마비","paralysis"],["수면","sleep"],["잠들","sleep"],["혼란","confusion"],["씨앗","seed"],["씨뿌리기","seed"],["엉겨붙기","bind"],["구속","bind"],["저주","curse"],["모래바람","sand"]]:
        if value.contains(pair[0]): return pair[1]
    return ""

func burst(kind: String,on_ally: bool) -> void:
    if not COLORS.has(kind): return
    pulses.append({"kind":kind,"ally":on_ally,"time":0.0})
    var sprite := canvas.source_sprite if on_ally else canvas.target_sprite
    var tint: Color = COLORS[kind]
    var t := UiMotion.combat(sprite,"status_flash")
    t.tween_property(sprite,"self_modulate",Color.WHITE.lerp(tint,.65),.07)
    t.tween_property(sprite,"self_modulate",Color.WHITE,.43)
    queue_redraw()

func clear() -> void:
    pulses.clear()
    for sprite: Sprite2D in [canvas.source_sprite,canvas.target_sprite]:
        var tracks: Dictionary = sprite.get_meta(UiMotion.META,{})
        if tracks.has("status_flash") and tracks["status_flash"].is_valid(): tracks["status_flash"].kill()
        sprite.self_modulate = Color.WHITE
    queue_redraw()

func _process(delta: float) -> void:
    if pulses.is_empty(): return
    for pulse: Dictionary in pulses: pulse["time"] += delta*UiMotion.combat_speed(self)
    pulses = pulses.filter(func(pulse: Dictionary): return pulse["time"] < .65)
    queue_redraw()

func _draw() -> void:
    for pulse: Dictionary in pulses:
        var on_ally: bool = pulse["ally"]
        var key: String = pulse["kind"]
        var time: float = pulse["time"]
        var sprite := canvas.source_sprite if on_ally else canvas.target_sprite
        if not sprite.visible or (canvas.source_factor if on_ally else canvas.target_factor)<.05: continue
        var center := canvas.sprite_rect(on_ally).get_center()+(canvas.source_motion if on_ally else canvas.target_motion)
        var alpha := sin(clampf(time/.65,0,1)*PI)
        var color: Color = COLORS[key]
        color.a = alpha*.5
        draw_arc(center,56+time*64,0,TAU,40,color,5,false)
        draw_set_transform(center,0,Vector2.ONE*1.65)
        MoveEffect.draw_status(self,key,Vector2.ZERO,time*10,alpha)
        draw_set_transform(Vector2.ZERO)
