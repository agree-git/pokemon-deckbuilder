class_name TrainerEntrance
extends Node2D
## Original pixel trainer, with distinct roles and a timed throwing arm.
## Presentation only: no battle state, random calls, cards or save changes.
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
    return canvas.foot_anchor(false)+Vector2(160+slide,0)
func _pixel(rect: Rect2,color: Color) -> void:
    draw_rect(Rect2((trainer_foot()+Vector2(-72,-204)+rect.position*4).round(),rect.size*4),color)
func _draw() -> void:
    if canvas == null: return
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
    if projectile:
        var start := canvas.foot_anchor(false)+Vector2(76,-128)
        var end := canvas.target_anchor
        var at := start.lerp(end,throw_progress)
        at.y -= sin(throw_progress*PI)*90
        draw_texture_rect(ball,Rect2(at.round()-Vector2(18,18),Vector2(36,36)),false)
