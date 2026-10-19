extends Node2D
## A visual timeline for an already successful capture; never rolls capture odds.
const DURATION := 4.0
const SHAKE_STARTS := [2.0,2.48,2.96]
const SHAKE_TIME := .34
var canvas: BattleCanvas
var ball: Texture2D
var elapsed := 0.0
var active := false
var phase_name := ""
var completed_shakes := 0
var phase_history: Array[String] = []
var launch := Vector2.ZERO
var impact := Vector2.ZERO
var ground := Vector2.ZERO
var ball_position := Vector2.ZERO
var ball_angle := 0.0
var ball_stretch := Vector2.ONE
var absorb := 0.0
var flash := 0.0
var success := 0.0
var original_color := Color.WHITE

func _ready() -> void:
    var source: Texture2D = preload("res://assets/items/ball.png")
    var cropped := AtlasTexture.new()
    cropped.atlas = source
    cropped.region = source.get_image().get_used_rect()
    ball = cropped
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func start() -> void:
    clear(false)
    original_color = canvas.target_sprite.self_modulate
    launch = canvas.foot_anchor(true)+Vector2(90,-120)
    impact = canvas.sprite_rect(false).get_center()
    ground = canvas.foot_anchor(false)-Vector2(0,22)
    phase_history.clear()
    active = true
    get_node("/root/GameCries").stop_side(false)
    BattleSoundCues.play(self,"release")
    seek(0)
    UiMotion.combat(self,"capture").tween_method(seek,0.0,DURATION,DURATION)

func seek(time: float) -> void:
    elapsed = clampf(time,0,DURATION)
    absorb = clampf((elapsed-.64)/.39,0,1)
    ball_position = impact
    ball_angle = 0
    ball_stretch = Vector2.ONE
    flash = 0
    success = 0
    completed_shakes = 0
    var phase := ""
    if elapsed < .52:
        phase = "throw"
        var p := elapsed/.52
        ball_position = launch.lerp(impact,p)-Vector2(0,sin(p*PI)*180)
        ball_angle = p*TAU*1.5
    elif elapsed < .64:
        phase = "impact"
        flash = sin((elapsed-.52)/.12*PI)
    elif elapsed < 1.03:
        phase = "absorb"
        flash = .3
    elif elapsed < 1.15:
        phase = "close"
        flash = sin((elapsed-1.03)/.12*PI)
    elif elapsed < 1.60:
        phase = "drop"
        var p := (elapsed-1.15)/.45
        ball_position = impact.lerp(ground,p*p)
    else:
        ball_position = ground
        phase = "rest"
        if elapsed < 1.84:
            phase = "bounce"
            var p := (elapsed-1.60)/.24
            ball_position.y -= sin(p*PI)*28
            ball_stretch = Vector2(1+.12*sin(p*PI),1-.12*sin(p*PI))
        for i in SHAKE_STARTS.size():
            var start_time: float = SHAKE_STARTS[i]
            if elapsed >= start_time+SHAKE_TIME: completed_shakes += 1
            elif elapsed >= start_time:
                phase = "shake_%d" % (i+1)
                var p := (elapsed-start_time)/SHAKE_TIME
                ball_angle = sin(p*TAU)*.32
                ball_position.x += ball_angle*25
                ball_position.y -= absf(ball_angle)*8
        if elapsed >= 3.30:
            phase = "success"
            success = clampf((elapsed-3.30)/.70,0,1)
    if phase != phase_name:
        phase_name = phase
        phase_history.append(phase)
    canvas.target_factor = pow(1-absorb,1.7)
    canvas.target_motion = (impact-canvas.foot_anchor(false))*absorb
    canvas.target_sprite.self_modulate = original_color.lerp(Color(1,.3,.4),sin(absorb*PI))
    queue_redraw()

func finish() -> void:
    seek(DURATION)
    clear(false)

func clear(restore_target := true) -> void:
    var tracks: Dictionary = get_meta(UiMotion.META,{})
    if tracks.has("capture") and tracks["capture"].is_valid(): tracks["capture"].kill()
    active = false
    if canvas != null:
        canvas.target_motion = Vector2.ZERO
        canvas.target_sprite.self_modulate = original_color
        if restore_target: canvas.target_factor = 1
    queue_redraw()

func _draw() -> void:
    if not active or ball == null: return
    if elapsed >= 1.15:
        draw_set_transform(ground+Vector2(0,21),0,Vector2(1,.24))
        draw_circle(Vector2.ZERO,26,Color(0,0,0,.3))
        draw_set_transform(Vector2.ZERO)
    if flash > 0:
        draw_circle(impact,24+flash*36,Color(1,.82,.86,flash*.7))
        draw_arc(impact,30+flash*52,0,TAU,32,Color(1,.93,.86,flash),3)
    if phase_name == "absorb":
        for i in 10:
            var p := fmod(absorb+i*.1,1.0)
            var at := impact+Vector2.from_angle(i*TAU/10)*(1-p)*95
            draw_rect(Rect2(at.round()-Vector2(3,3),Vector2(6,6)),Color(1,.4,.5,sin(p*PI)))
        draw_arc(impact,12+sin(absorb*PI)*18,0,TAU,24,Color(1,.65,.7),3)
    draw_set_transform(ball_position.round(),ball_angle,ball_stretch)
    var gap := 0.0
    if phase_name == "impact": gap = flash*8
    elif phase_name == "absorb": gap = 8
    elif phase_name == "close": gap = (1-(elapsed-1.03)/.12)*8
    if gap > 0:
        var source_size := ball.get_size()
        draw_texture_rect_region(ball,Rect2(-22,-22-gap,44,22),Rect2(0,0,source_size.x,source_size.y/2))
        draw_texture_rect_region(ball,Rect2(-22,gap,44,22),Rect2(0,source_size.y/2,source_size.x,source_size.y/2))
    else:
        draw_texture_rect(ball,Rect2(-Vector2(22,22),Vector2(44,44)),false)
    if phase_name == "success":
        draw_circle(Vector2.ZERO,5,Color("83e0b0"))
        draw_arc(Vector2.ZERO,25+success*22,0,TAU,32,Color(.6,1,.75,1-success),2)
    draw_set_transform(Vector2.ZERO)
    if phase_name == "success":
        for i in 3:
            var at := ground+Vector2((i-1)*48,-36-success*50)
            var radius := 6*(1-success)
            var points := PackedVector2Array()
            for k in 8: points.append(at+Vector2.from_angle(-PI/2+k*PI/4)*(radius if k%2==0 else radius*.35))
            if radius > .1: draw_colored_polygon(points,Color(1,.88,.4,1-success))
