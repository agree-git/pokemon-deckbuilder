class_name CombatMotion
extends Node2D
## Anticipation, action and recovery poses on top of the stable battle layout.
var canvas: BattleCanvas
var ball: Texture2D = preload("res://assets/items/ball.png")
var progress := 0.0
var mode := ""
var ally := true
var ball_already_landed := false
var last_profile := ""
func _process(_delta: float) -> void: queue_redraw()
func recall(on_ally: bool) -> void:
    get_node("/root/GameCries").stop_side(on_ally)
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
    t.tween_callback(_cry.bind(on_ally)).set_delay(0.13)
    t.chain().tween_callback(func(): mode = "")
func _cry(on_ally: bool) -> void:
    get_node("/root/GameCries").play(canvas.source_species if on_ally else canvas.target_species,on_ally)

func attack(from_enemy: bool, physical: bool) -> void:
    use_move(from_enemy,{"category":"physical" if physical else "special"})

func use_move(from_enemy: bool, definition: Dictionary) -> void:
    var property := "target_motion" if from_enemy else "source_motion"
    var direction := -1 if from_enemy else 1
    var category := str(definition.get("category","special"))
    var primary := str(definition.get("vfx",{}).get("primary",""))
    var profile := "cast"
    if category in ["2","physical"]: profile = "slash" if primary == "slash" else "strike"
    elif category in ["1","status"]:
        profile = "guard" if primary == "shield" else ("heal" if primary in ["heal","drain"] else "support")
    elif primary in ["charge","explosion"]: profile = "charge"
    last_profile = profile
    var t := UiMotion.combat(canvas,property)
    match profile:
        "strike", "slash":
            _pose(t,from_enemy,Vector2(-direction*18,6),Vector2(1.10,.90),-direction*.06,.08)
            _pose(t,from_enemy,Vector2(direction*(88 if profile == "slash" else 104),-28 if profile == "slash" else -14),Vector2(.95,1.08),direction*(.17 if profile == "slash" else .10),.13,Tween.TRANS_CUBIC,Tween.EASE_IN)
        "cast", "charge":
            _pose(t,from_enemy,Vector2(-direction*12,6),Vector2(1.12,.88),-direction*.05,.12)
            _pose(t,from_enemy,Vector2(direction*32,-18 if profile == "charge" else -8),Vector2(.94,1.10),direction*.07,.09,Tween.TRANS_CUBIC,Tween.EASE_OUT)
        "guard":
            _pose(t,from_enemy,Vector2(-direction*8,9),Vector2(1.14,.86),-direction*.04,.10)
            _pose(t,from_enemy,Vector2(-direction*4,3),Vector2(1.06,.94),0,.11)
        "heal", "support":
            _pose(t,from_enemy,Vector2(0,5),Vector2(1.06,.94),-direction*.04,.09)
            _pose(t,from_enemy,Vector2(direction*8,-24 if profile == "heal" else -16),Vector2(.97,1.06),direction*.04,.12,Tween.TRANS_SINE,Tween.EASE_OUT)
    _pose(t,from_enemy,Vector2.ZERO,Vector2.ONE,0,.19,Tween.TRANS_QUAD,Tween.EASE_OUT)

func _pose(t: Tween,from_enemy: bool,offset: Vector2,stretch: Vector2,lean: float,duration: float,transition := Tween.TRANS_QUAD,easing := Tween.EASE_IN_OUT) -> void:
    var side := "target_" if from_enemy else "source_"
    t.tween_property(canvas,side+"motion",offset,duration).set_trans(transition).set_ease(easing)
    t.parallel().tween_property(canvas,side+"stretch",stretch,duration).set_trans(transition).set_ease(easing)
    t.parallel().tween_property(canvas,side+"lean",lean,duration).set_trans(transition).set_ease(easing)
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
    _pose(t,not on_ally,Vector2(direction*(8 if guarded else 22),0),Vector2(1.08,.92),direction*.04,.06)
    _pose(t,not on_ally,Vector2(-direction*7,0),Vector2(.98,1.02),-direction*.025,.07)
    _pose(t,not on_ally,Vector2.ZERO,Vector2.ONE,0,.12)
func faint(on_ally: bool) -> void:
    var t := UiMotion.combat(canvas,"faint")
    t.tween_property(canvas,"source_factor" if on_ally else "target_factor",0.0,0.24)
func settle_poses() -> void:
    # The action sequence and its child tweens can finish on adjacent slow frames.
    # Unlock input in a neutral pose without undoing a faint or summon fade.
    var tracks: Dictionary = canvas.get_meta(UiMotion.META,{})
    for key: String in ["source_motion","target_motion","hit_shake"]:
        if tracks.has(key) and tracks[key].is_valid(): tracks[key].kill()
    canvas.position = Vector2.ZERO
    canvas.source_motion = Vector2.ZERO
    canvas.target_motion = Vector2.ZERO
    canvas.source_stretch = Vector2.ONE
    canvas.target_stretch = Vector2.ONE
    canvas.source_lean = 0
    canvas.target_lean = 0
func reset() -> void:
    for node: Node in [self,canvas]:
        var tracks: Dictionary = node.get_meta(UiMotion.META,{})
        for tween: Tween in tracks.values():
            if tween.is_valid(): tween.kill()
    mode = ""
    ball_already_landed = false
    settle_poses()
    canvas.source_factor = 1
    canvas.target_factor = 1
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
