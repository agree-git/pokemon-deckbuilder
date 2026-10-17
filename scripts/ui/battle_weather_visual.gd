class_name BattleWeatherVisual
extends Control
## Presentation only. Pixel weather above combatants, below effects and the HUD.
const FADE_SECONDS := 0.55
const PIXEL := 3.0
const TINTS := {
    "rain":Color(0.055,0.13,0.27,0.27),
    "snow":Color(0.69,0.83,0.96,0.17),
    "sun":Color(1,0.68,0.18,0.14),
    "sand":Color(0.62,0.39,0.12,0.26),
}
var weather := ""
var clock := 0.0
var weights := {"rain":0.0,"snow":0.0,"sun":0.0,"sand":0.0}
func _ready() -> void:
    name = "FieldWeather"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func set_weather(key: String) -> void:
    weather = key if TINTS.has(key) else ""
func _process(delta: float) -> void:
    advance(delta)
func advance(delta: float) -> void:
    clock += maxf(0,delta)
    var any_visible := false
    for key: String in weights:
        weights[key] = move_toward(float(weights[key]),1.0 if key == weather else 0.0,maxf(0,delta)/FADE_SECONDS)
        any_visible = any_visible or float(weights[key]) > 0
    visible = any_visible
    if any_visible: queue_redraw()
func _draw() -> void:
    # The UI stays native resolution. Only these graphic primitives use a 3px grid.
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE*PIXEL)
    var field := (size/PIXEL).floor()
    if field.x <= 0 or field.y <= 0: return
    for key: String in weights:
        var alpha := float(weights[key])
        if alpha <= 0: continue
        var bottom_fade := minf(24,field.y)
        draw_rect(Rect2(0,0,field.x,field.y-bottom_fade),Color(TINTS[key],TINTS[key].a*alpha))
        for row in int(bottom_fade):
            draw_rect(Rect2(0,field.y-bottom_fade+row,field.x,1),Color(TINTS[key],TINTS[key].a*alpha*(1-row/bottom_fade)))
        match key:
            "rain": _rain(field,alpha)
            "snow": _snow(field,alpha)
            "sun": _sun(field,alpha)
            "sand": _sand(field,alpha)
    draw_set_transform(Vector2.ZERO)
func _rain(field: Vector2,alpha: float) -> void:
    for i in 170:
        var near := i % 3 == 0
        var speed := 210.0 if near else 142.0
        var at := Vector2(fposmod(i*137.0-clock*38,field.x+12)-6,fposmod(i*83.0+clock*speed,field.y+16)-8).floor()
        var length := 10 if near else 6
        draw_line(at,at+Vector2(-3,length),Color(0.66,0.85,1,alpha*(0.72 if near else 0.38)*_floor_fade(at.y,field)),1,false)
    # Short stepped ripples anchor the rain to the ground, beyond falling lines.
    for i in 24:
        var phase := fposmod(clock*1.4+i*0.37,1.0)
        var at := Vector2(fposmod(i*101.0+21,field.x),field.y*(0.52+0.44*fmod(i*0.31,1.0))).floor()
        var radius := 1+floorf(phase*4)
        var ink := Color(0.64,0.84,0.98,alpha*(1-phase)*0.42)
        draw_line(at+Vector2(-radius,0),at+Vector2(radius,0),ink,1,false)
        draw_rect(Rect2(at+Vector2(-radius,-1),Vector2(1,1)),ink)
        draw_rect(Rect2(at+Vector2(radius,-1),Vector2(1,1)),ink)
func _snow(field: Vector2,alpha: float) -> void:
    for i in 110:
        var near := i % 5 == 0
        var drift := sin(clock*0.7+i*1.3)*7
        var at := Vector2(fposmod(i*97.0+clock*8+drift,field.x+10)-5,fposmod(i*59.0+clock*(22 if near else 12),field.y+10)-5).floor()
        var ink := Color(0.89,0.97,1,alpha*(0.95 if near else 0.65)*_floor_fade(at.y,field))
        draw_rect(Rect2(at,Vector2(2,2) if near else Vector2.ONE),ink)
        if near:
            draw_rect(Rect2(at+Vector2(-1,0),Vector2(4,1)),ink)
            draw_rect(Rect2(at+Vector2(0,-1),Vector2(1,4)),ink)
    # Soft cold air along the floor, without permanent snow on the biome artwork.
    for row in 10:
        var y := field.y-1-row*2
        draw_rect(Rect2(0,y,field.x,2),Color(0.79,0.9,1,alpha*0.045*sin(row/10.0*PI)))
func _sun(field: Vector2,alpha: float) -> void:
    # One upper-left light source, clear of the party panel, with a diagonal lens axis.
    var origin := Vector2(field.x*0.165,10)+Vector2(sin(clock*0.16),cos(clock*0.13))*2
    var breath := 0.94+0.06*sin(clock*0.35)
    _disc(origin,108,Color(1,0.85,0.43,alpha*0.055))
    _disc(origin,76,Color(1,0.91,0.62,alpha*0.09))
    _disc(origin,46,Color(1,0.97,0.79,alpha*0.18))
    _disc(origin,20,Color(1,1,0.94,alpha*0.3))
    _disc(origin,6,Color(1,1,0.97,alpha*0.45))
    draw_rect(Rect2((origin-Vector2(30,0)).floor(),Vector2(60,1)),Color(1,0.98,0.83,alpha*0.22))
    draw_rect(Rect2((origin-Vector2(0,17)).floor(),Vector2(1,34)),Color(1,0.98,0.83,alpha*0.17))
    for beam in 4:
        var slope: float = [1.0,1.65,2.35,3.1][beam]
        for y in range(0,int(field.y),3):
            var distance := y-origin.y
            var center := origin.x+distance*slope
            var width := 3+distance*(0.09 if beam % 2 == 0 else 0.16)
            var strength := alpha*breath*(1-y/(field.y*1.7))*_floor_fade(y,field)
            draw_rect(Rect2(floorf(center-width/2),y,floorf(width),3),Color(1,0.9,0.56,0.18*strength))
            draw_rect(Rect2(floorf(center-width/2-3),y,3,3),Color(1,0.95,0.72,0.07*strength))
    var axis := Vector2(field.x*0.82,field.y*0.84)-origin
    var stops: Array[float] = [0.18,0.36,0.62,0.88]
    var radii: Array[int] = [5,10,18,9]
    for i in stops.size():
        var at := (origin+axis*stops[i]).floor()
        var ink := Color(1,0.86,0.42) if i % 2 == 0 else Color(0.65,0.9,0.83)
        _disc(at,radii[i]+3,Color(ink,alpha*0.035*breath))
        _disc(at,radii[i],Color(ink,alpha*0.22*breath),true)
        _disc(at,maxi(2,radii[i]-2),Color(ink,alpha*0.075*breath))
    for i in 24:
        var at := Vector2(fposmod(i*89.0+sin(clock*0.4+i)*6,field.x),fposmod(i*47.0-clock*4,field.y)).floor()
        var light := 0.4+0.2*sin(clock*0.8+i)
        draw_rect(Rect2(at,Vector2.ONE),Color(1,0.93,0.65,alpha*light*_floor_fade(at.y,field)))
func _disc(at: Vector2,radius: int,ink: Color,ring := false) -> void:
    # Stepped rows keep halos and lens ghosts in the sprite's pixel art style.
    for row in range(-radius,radius+1,2):
        var half := floorf(sqrt(maxf(0,radius*radius-row*row)))
        if ring:
            var inside := floorf(sqrt(maxf(0,pow(radius-2,2)-row*row)))
            draw_rect(Rect2((at+Vector2(-half,row)).floor(),Vector2(maxf(1,half-inside),2)),ink)
            draw_rect(Rect2((at+Vector2(inside,row)).floor(),Vector2(maxf(1,half-inside),2)),ink)
        else:
            draw_rect(Rect2((at+Vector2(-half,row)).floor(),Vector2(half*2,2)),ink)
func _sand(field: Vector2,alpha: float) -> void:
    # Broken horizontal banks and differently sized grains create a moving dust front.
    for band in 7:
        var y := field.y*(0.1+band*0.14)+sin(clock*0.5+band)*6
        for strip in 4:
            var x := fposmod(strip*193.0+band*83.0+clock*(28+band*3),field.x+180)-180
            draw_rect(Rect2(Vector2(x,y+strip%2*3).floor(),Vector2(150,5+band%3)),Color(0.86,0.65,0.31,alpha*0.055*_floor_fade(y,field)))
    for i in 130:
        var near := i % 4 == 0
        var at := Vector2(fposmod(i*113.0+clock*(170 if near else 95),field.x+14)-7,fposmod(i*71.0+sin(clock*1.2+i)*5,field.y)).floor()
        draw_rect(Rect2(at,Vector2(5,1) if near else Vector2(2,1)),Color(0.96,0.79,0.43,alpha*(0.74 if near else 0.38)*_floor_fade(at.y,field)))
    for row in 12:
        draw_rect(Rect2(0,field.y-row*3-3,field.x,3),Color(0.78,0.56,0.24,alpha*0.065*sin(row/12.0*PI)))

static func _floor_fade(y: float,field: Vector2) -> float:
    return clampf((field.y-y)/24.0,0,1)
