class_name TrainerEntrance
extends Node2D
## Original-game trainer art where available; generic pixel trainer otherwise.
## Presentation only: no battle state, random calls, cards or save changes.
var portrait: Texture2D
var portrait_bounds := Rect2()
func set_trainer(trainer: Dictionary) -> void:
    portrait = TrainerSprites.texture(trainer)
    portrait_bounds = TrainerSprites.bounds(trainer)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func portrait_extent() -> Vector2:
    var zoom := maxf(1,floor(minf(260/portrait_bounds.size.y,260/portrait_bounds.size.x)))
    return portrait_bounds.size*zoom
func portrait_rect() -> Rect2:
    var extent := portrait_extent()
    var offset := Vector2(8,-6) if pose == "windup" else (Vector2(-10,0) if pose == "throw" else Vector2.ZERO)
    return Rect2((trainer_foot()+offset-Vector2(extent.x/2,extent.y)).round(),extent)
var canvas: BattleCanvas
var role := "trainer"
var accent := Color("73a6ba")
var slide := 72.0
var pose := "stand"
var throw_progress := 0.0
var projectile := false
var ball: Texture2D = preload("res://assets/items/ball.png")
func _process(_delta: float) -> void: queue_redraw()
func trainer_foot() -> Vector2:
    var foot := canvas.foot_anchor(false)
    var right_limit := canvas.canvas_size.x-360
    if portrait != null:
        right_limit = minf(right_limit,canvas.canvas_size.x-300-portrait_extent().x/2)
    return Vector2(minf(foot.x+160,right_limit)+slide,foot.y)
func _pixel(rect: Rect2,color: Color) -> void:
    draw_rect(Rect2((trainer_foot()+Vector2(-72,-204)+rect.position*4).round(),rect.size*4),color)
func _draw() -> void:
    if canvas == null: return
    if portrait != null:
        var area := portrait_rect()
        draw_rect(Rect2(trainer_foot()+Vector2(-48,-4),Vector2(96,8)),Color(0.02,0.04,0.06,0.45))
        draw_texture_rect_region(portrait,area,portrait_bounds)
        if pose == "windup":
            var at := area.position+Vector2(area.size.x*0.15,area.size.y*0.4)
            draw_texture_rect(ball,Rect2(at.round(),Vector2(24,24)),false)
        _draw_projectile()
        return
    var ink := Color("182331")
    var skin := Color("e9bc91")
    var shade := Color("be896f")
    var shirt := Color("eee9d5")
    var trousers := Color("34415a")
    var coat := accent.darkened(0.2)
    # Stepped contact shadow and feet.
    _pixel(Rect2(6,49,25,2),Color(0.02,0.04,0.06,0.45))
    if role == "champion":
        _pixel(Rect2(22,16,9,29),coat.darkened(0.3))
        _pixel(Rect2(27,25,6,17),coat.darkened(0.45))
    _pixel(Rect2(10,32,9,17),ink)
    _pixel(Rect2(21,32,8,17),ink)
    _pixel(Rect2(12,34,5,12),trousers)
    _pixel(Rect2(23,34,4,12),trousers.lightened(0.12))
    _pixel(Rect2(7,47,12,4),ink)
    _pixel(Rect2(20,47,12,4),ink)
    _pixel(Rect2(9,18,20,17),ink)
    _pixel(Rect2(11,19,16,14),coat)
    _pixel(Rect2(15,18,9,5),shirt)
    _pixel(Rect2(17,23,7,10),shirt.darkened(0.15))
    _pixel(Rect2(11,33,17,2),ink)
    _pixel(Rect2(20,33,3,2),Color("e6bf66"))
    _pixel(Rect2(13,5,15,14),ink)
    _pixel(Rect2(11,8,15,10),skin)
    _pixel(Rect2(11,15,10,3),shade)
    _pixel(Rect2(9,10,4,4),skin)
    _pixel(Rect2(12,10,2,2),ink)
    _pixel(Rect2(18,4,11,5),Color("604c4a"))
    _pixel(Rect2(12,2,16,6),Color("604c4a"))
    if role == "trainer":
        _pixel(Rect2(10,1,19,5),coat)
        _pixel(Rect2(7,5,20,3),accent)
    elif role == "veteran":
        _pixel(Rect2(11,3,17,3),Color("9ba8b4"))
        _pixel(Rect2(10,10,8,2),ink)
    elif role in ["gym","elite","champion"]:
        _pixel(Rect2(25,20,2,4),Color("e6bf66"))
    _pixel(Rect2(25,21,5,13),coat.darkened(0.25))
    _pixel(Rect2(26,33,4,4),skin)
    if pose == "windup":
        _pixel(Rect2(9,19,6,6),coat)
        _pixel(Rect2(8,13,5,10),shade)
        _pixel(Rect2(7,10,5,5),skin)
    elif pose == "throw":
        _pixel(Rect2(4,19,10,5),coat)
        _pixel(Rect2(-1,18,9,4),shade)
        _pixel(Rect2(-4,16,5,5),skin)
    else:
        _pixel(Rect2(7,20,6,9),coat)
        _pixel(Rect2(4,26,7,4),shade)
        _pixel(Rect2(2,25,5,5),skin)
        draw_texture_rect(ball,Rect2((trainer_foot()+Vector2(-68,-104)).round(),Vector2(24,24)),false)
    if pose == "windup":
        draw_texture_rect(ball,Rect2((trainer_foot()+Vector2(-44,-172)).round(),Vector2(24,24)),false)
    _draw_projectile()
func _draw_projectile() -> void:
    if projectile:
        var start := trainer_foot()+Vector2(-84,-128)
        if portrait != null:
            var area := portrait_rect()
            start = area.position+Vector2(area.size.x*0.15,area.size.y*0.4)
        var end := canvas.target_anchor
        var at := start.lerp(end,throw_progress)
        at.y -= sin(throw_progress*PI)*90
        draw_texture_rect(ball,Rect2(at.round()-Vector2(18,18),Vector2(36,36)),false)
