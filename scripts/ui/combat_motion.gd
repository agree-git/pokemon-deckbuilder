class_name CombatMotion
extends Node2D
## Small pixel motions on top of the stable battle layout.
var canvas: BattleCanvas
var ball: Texture2D = preload("res://assets/items/ball.png")
var progress := 0.0
var mode := ""
var ally := true
var ball_already_landed := false
func _process(_delta: float) -> void: queue_redraw()
func recall(on_ally: bool) -> void:
    BattleSoundCues.play(self,"recall")
    ally = on_ally
    ball_already_landed = false
    mode = "recall"
    progress = 0
    var t := UiMotion.combat(self,"ball",true)
    t.tween_property(canvas,"source_factor" if ally else "target_factor",0.02,0.24).set_trans(Tween.TRANS_QUAD)
    t.tween_property(self,"progress",1.0,0.24)
func release(on_ally: bool,at_target := false) -> void:
    BattleSoundCues.play(self,"release")
    ally = on_ally
    ball_already_landed = at_target
    mode = "release"
    progress = 0
    canvas.set("source_factor" if ally else "target_factor",0.02)
    var t := UiMotion.combat(self,"ball",true)
    t.tween_property(self,"progress",1.0,0.38)
    t.tween_property(canvas,"source_factor" if ally else "target_factor",1.0,0.25).set_delay(0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    t.chain().tween_callback(func(): mode = "")
func attack(from_enemy: bool, physical: bool) -> void:
    var property := "target_motion" if from_enemy else "source_motion"
    var direction := -1 if from_enemy else 1
    var t := UiMotion.combat(canvas,property)
    t.tween_property(canvas,property,Vector2(direction*(48 if physical else 22),-10),0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_property(canvas,property,Vector2.ZERO,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
func hit(on_ally: bool, guarded := false) -> void:
    var preferences := get_node_or_null("/root/Preferences")
    if preferences != null and not preferences.hit_motion: return
    var shake := UiMotion.combat(canvas,"hit_shake")
    shake.tween_property(canvas,"position",Vector2(4,-2),0.045)
    shake.tween_property(canvas,"position",Vector2(-3,1),0.045)
    shake.tween_property(canvas,"position",Vector2.ZERO,0.09)
    var property := "source_motion" if on_ally else "target_motion"
    var direction := -1 if on_ally else 1
    var t := UiMotion.combat(canvas,property)
    t.tween_property(canvas,property,Vector2(direction*(8 if guarded else 22),0),0.06)
    t.tween_property(canvas,property,Vector2(-direction*7,0),0.07)
    t.tween_property(canvas,property,Vector2.ZERO,0.12)
func faint(on_ally: bool) -> void:
    var t := UiMotion.combat(canvas,"faint")
    t.tween_property(canvas,"source_factor" if on_ally else "target_factor",0.0,0.24)
func reset() -> void:
    for node: Node in [self,canvas]:
        var tracks: Dictionary = node.get_meta(UiMotion.META,{})
        for tween: Tween in tracks.values():
            if tween.is_valid(): tween.kill()
    mode = ""
    ball_already_landed = false
    canvas.position = Vector2.ZERO
    canvas.source_factor = 1
    canvas.target_factor = 1
    canvas.source_motion = Vector2.ZERO
    canvas.target_motion = Vector2.ZERO
func _draw() -> void:
    if mode.is_empty() or canvas == null: return
    var anchor := canvas.source_anchor if ally else canvas.target_anchor
    var trainer := anchor+Vector2(-270 if ally else 270,110)
    var point := anchor if mode == "release" and ball_already_landed else (anchor.lerp(trainer,progress) if mode == "recall" else trainer.lerp(anchor,progress))
    if not ball_already_landed: point.y -= sin(progress*PI)*70
    if mode == "recall":
        draw_line(point.round(),anchor.round(),Color(0.5,0.9,1,1.0-progress),6,false)
    else:
        for i in 8:
            var spark := anchor+Vector2.from_angle(i*TAU/8)*(18+progress*70)
            draw_rect(Rect2(spark.round(),Vector2(7,7)),Color(0.8,0.95,1,sin(progress*PI)))
    draw_texture_rect(ball,Rect2(point.round()-Vector2(30,30),Vector2(60,60)),false,Color(1,1,1,1-progress if ball_already_landed else 1))
