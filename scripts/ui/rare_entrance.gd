class_name RareEntrance
extends Node2D
## Deterministic pixel geometry. Never consumes battle RNG or changes weather/state.
const KINDS := {150:"dna",249:"bubbles",250:"rainbow",382:"waves",383:"quake",384:"clouds",483:"clock",484:"rift",487:"shadow",643:"flames",644:"lightning",646:"ice",716:"bloom",717:"wither",718:"cells",791:"sun",792:"moon",800:"wormhole",888:"sword",889:"shield",890:"red_wormhole",898:"blizzard",1007:"past",1008:"future",1024:"stellar"}
var species_id := 150
var center := Vector2(1380,420)
var progress := 0.0:
    set(value):
        progress = value
        queue_redraw()
var motion_enabled := true

static func supports(id: int) -> bool:
    return KINDS.has(id)

func _point(at: Vector2) -> Vector2:
    return (at/4).round()*4
func _line(a: Vector2,b: Vector2,color: Color,width := 4.0) -> void:
    draw_line(_point(a),_point(b),color,width,false)
func _pixel(at: Vector2,color: Color,size := 8.0) -> void:
    draw_rect(Rect2(_point(at)-Vector2.ONE*size/2,Vector2.ONE*size),color)
func _ring(at: Vector2,radius: float,color: Color,ratio := 1.0,width := 5.0) -> void:
    for i in 40:
        var a := TAU*i/40.0
        var b := TAU*(i+1)/40.0
        _line(at+Vector2(cos(a),sin(a)*ratio)*radius,at+Vector2(cos(b),sin(b)*ratio)*radius,color,width)
func _star(at: Vector2,radius: float,color: Color) -> void:
    _line(at-Vector2(radius,0),at+Vector2(radius,0),color,4)
    _line(at-Vector2(0,radius),at+Vector2(0,radius),color,4)
    _pixel(at,color,8)
func _leaf(at: Vector2,color: Color,lean: float) -> void:
    _line(at+Vector2(0,18),at+Vector2(lean,-22),color,5)
    _line(at+Vector2(0,8),at+Vector2(-18,-5),color,6)
    _line(at+Vector2(lean/2,-4),at+Vector2(20,-18),color,6)
func _bolt(at: Vector2,extent: float,color: Color,phase: float) -> void:
    for j in 6:
        var a := at+Vector2(sin(j*2.4+phase)*24,j*extent/6)
        var b := at+Vector2(sin((j+1)*2.4+phase)*24,(j+1)*extent/6)
        _line(a,b,color,8)
        _line(a,b,Color(0.9,1,1,color.a),3)
func _draw() -> void:
    if progress <= 0 or progress >= 1: return
    var p := progress
    var fade := minf(p*5,(1-p)*4)
    var core := fade*clampf((0.74-p)/0.22,0,1)
    var c := center
    var t := p*TAU
    var blue := Color(0.25,0.82,1,fade)
    var gold := Color(1,0.84,0.3,fade)
    var purple := Color(0.65,0.3,1,fade)
    var red := Color(1,0.23,0.28,fade)
    var green := Color(0.45,1,0.58,fade)
    var white := Color(0.86,0.98,1,fade)
    var kind: String = KINDS.get(species_id,"")
    match kind:
        "dna":
            for i in 25:
                var y := -245+i*14.0
                var x := sin(t*1.6+i*0.48)*105
                var a := c+Vector2(x,y)
                var b := c+Vector2(-x,y)
                _line(a,b,Color(0.75,0.45,1,fade*0.65),4)
                _pixel(a,purple,12)
                _pixel(b,blue,12)
        "bubbles":
            for i in 36:
                var rise := fposmod(p*1.6+i*0.137,1)
                var at := c+Vector2(sin(i*12.3)*245+sin(t+i)*15,120-rise*410)
                _ring(at,7+(i%4)*4,blue,1,4)
                _pixel(at-Vector2(3,4),white,4)
        "rainbow":
            for band in 7:
                var color := Color.from_hsv(band/7.0,0.65,1,fade*0.85)
                for i in 32:
                    var a := PI+PI*i/32.0
                    var b := PI+PI*(i+1)/32.0
                    var radius := 250-band*13.0
                    _line(c+Vector2(0,70)+Vector2(cos(a),sin(a))*radius,c+Vector2(0,70)+Vector2(cos(b),sin(b))*radius,color,12)
            for i in 16: _star(c+Vector2(sin(i*4.2)*240,cos(i*2.7)*170),8,gold)
        "waves":
            for row in 5:
                for i in 30:
                    var x := -340+i*24.0
                    var y := 80-row*28+sin(x/65+t*2+row)*20
                    _line(c+Vector2(x,y),c+Vector2(x+24,80-row*28+sin((x+24)/65+t*2+row)*20),blue if row%2 == 0 else white,9)
        "quake":
            var shake := sin(t*15)*8 if motion_enabled else 0.0
            for i in 10:
                var start := c+Vector2((i-5)*55,80+shake)
                for j in 4: _line(start+Vector2(j*14,j*18),start+Vector2((j+1)*14+sin(i+j)*20,(j+1)*18),Color(0.95,0.46,0.15,fade),7)
                _pixel(start+Vector2(sin(i)*20,-absf(sin(t+i))*85),Color(0.65,0.43,0.25,fade),16)
        "clouds":
            for i in 18:
                var x := fposmod(i*137-p*1800,750)-375
                var y := -250+(i%7)*48.0
                draw_rect(Rect2(_point(c+Vector2(x,y)),Vector2(100+(i%3)*40,20)),Color(0.78,0.95,0.9,fade*0.65))
        "clock":
            _ring(c,185,blue)
            _ring(c,164,gold)
            for i in 12:
                var a := TAU*i/12
                _line(c+Vector2(cos(a),sin(a))*145,c+Vector2(cos(a),sin(a))*160,gold,7)
            _line(c,c+Vector2(cos(-PI/2+t*2),sin(-PI/2+t*2))*138,white,7)
            _line(c,c+Vector2(cos(-PI/2+t/2),sin(-PI/2+t/2))*90,blue,11)
            _pixel(c,gold,18)
        "rift":
            var spread := sin(p*PI)*92
            var left := PackedVector2Array()
            var right := PackedVector2Array()
            for i in 13:
                var y := -260+i*34.0
                var x := sin(i*2.1)*25
                left.append(_point(c+Vector2(x-spread,y)))
                right.append(_point(c+Vector2(x+spread,y)))
            var shape := left.duplicate()
            right.reverse()
            shape.append_array(right)
            draw_colored_polygon(shape,Color(0.09,0.025,0.2,core))
            draw_polyline(left,Color(1,0.55,0.94,fade),7,false)
            draw_polyline(right,white,6,false)
        "shadow":
            for i in 12:
                var a := i*TAU/12+t*0.4
                var radius := 60+sin(t+i)*60
                _line(c+Vector2(cos(a),sin(a))*radius,c+Vector2(cos(a),sin(a))*260,Color(0.1,0.03,0.2,core),24)
            _ring(c+Vector2(0,100),220,purple,0.25,10)
        "flames":
            for i in 34:
                var rise := fposmod(p*1.8+i*0.127,1)
                var at := c+Vector2(sin(i*3.7)*190,110-rise*340)
                _line(at,at+Vector2(sin(t*2+i)*16,-35),Color(0.12,0.4,1,fade*(1-rise)),14)
                _pixel(at,blue,8)
        "lightning":
            for i in 5: _bolt(c+Vector2(-210+i*105,-275),380,blue,t+i)
            _ring(c+Vector2(0,85),180,blue,0.28,7)
        "ice":
            for i in 9:
                var at := c+Vector2((i-4)*52,120)
                var h := 110+absf(sin(i*2.1))*170
                var shape := PackedVector2Array([_point(at-Vector2(22,0)),_point(at+Vector2(-18,-h+35)),_point(at+Vector2(2,-h)),_point(at+Vector2(26,-h+42)),_point(at+Vector2(22,0))])
                draw_colored_polygon(shape,Color(0.3,0.75,0.94,core*0.55))
                draw_polyline(shape,white,4,false)
            for i in 17: _pixel(c+Vector2(sin(i*13)*230,120-p*280+cos(i*6)*90),white,8)
        "bloom","wither":
            for i in 17:
                var at := c+Vector2((i-8)*33,105+sin(i)*12)
                var color := green if kind == "bloom" else Color(0.4,0.26,0.25,fade)
                _leaf(at,color,sin(i+t)*12 if kind == "bloom" else p*34)
                if kind == "bloom": _star(at+Vector2(0,-45-absf(sin(t+i))*65),10,Color.from_hsv(i/17.0,0.5,1,fade))
                else: _pixel(at+Vector2(p*50,-p*80),red,6)
        "cells":
            for i in 55:
                var a := i*2.399
                var distance := (1-p)*300+30
                var at := c+Vector2(cos(a)*distance,sin(a)*distance*0.75)
                _ring(at,7,green,1,4)
                _pixel(at,Color(0.08,0.35,0.13,fade),5)
        "sun":
            for i in 20:
                var a := i*TAU/20+t*0.1
                _line(c+Vector2(cos(a),sin(a))*75,c+Vector2(cos(a),sin(a))*(170+(i%2)*100),gold,12)
            _ring(c,90,white,1,14)
        "moon":
            draw_circle(_point(c+Vector2(0,-70)),115,Color(0.7,0.75,1,core*0.65))
            draw_circle(_point(c+Vector2(40,-92)),102,Color(0.06,0.07,0.2,core))
            for i in 24: _star(c+Vector2(sin(i*6.2)*280,cos(i*3.8)*210),7,white)
        "wormhole","red_wormhole":
            var at := c-Vector2(0,165) if kind == "red_wormhole" else c
            var color := red if kind == "red_wormhole" else blue
            draw_circle(_point(at),126,Color(0.01,0.02,0.08,core))
            for ring in 5:
                _ring(at,135+ring*14,color if ring%2 == 0 else purple,0.5 if kind == "red_wormhole" else 1.0,6)
            for i in 40:
                var a := i*0.71+t*2
                var r := 30+(i%8)*22.0
                _pixel(at+Vector2(cos(a)*r,sin(a)*r*(0.5 if kind == "red_wormhole" else 1)),color,8)
            if kind == "red_wormhole":
                for i in 8: _line(at+Vector2((i-4)*30,35),c+Vector2((i-4)*18,100),Color(1,0.12,0.2,fade*0.45),8)
        "sword":
            for i in 3:
                var at := c+Vector2(-90+i*85,-80)
                _line(at+Vector2(-90,-145),at+Vector2(100,135),blue,18)
                _line(at+Vector2(-90,-145),at+Vector2(100,135),white,5)
                _line(at+Vector2(45,95),at+Vector2(95,60),gold,9)
        "shield":
            var points := PackedVector2Array([c+Vector2(-140,-160),c+Vector2(0,-205),c+Vector2(140,-160),c+Vector2(120,40),c+Vector2(0,135),c+Vector2(-120,40),c+Vector2(-140,-160)])
            draw_colored_polygon(points,Color(0.25,0.45,0.75,fade*0.4))
            draw_polyline(points,gold,12,false)
            _line(c+Vector2(0,-160),c+Vector2(0,90),white,9)
            _line(c+Vector2(-100,-75),c+Vector2(100,-75),white,9)
            _star(c,175,gold)
        "blizzard":
            for i in 60:
                var x := fposmod(i*83+p*980,700)-350
                var y := -270+fposmod(i*47+p*300,400)
                var gap := 30+p*150
                if absf(x) < gap: x += gap if x >= 0 else -gap
                _line(c+Vector2(x,y),c+Vector2(x+20,y+12),white,5)
        "past":
            for layer in 7:
                for i in 15:
                    var x := (i-7)*48.0
                    var y := 90+layer*15+sin(i*0.8+t)*12
                    _line(c+Vector2(x,y),c+Vector2(x+48,y+sin(i)*14),Color(0.9,0.4+layer*0.035,0.17,fade),6)
            for i in 36:
                var x := fposmod(i*73-p*500,660)-330
                _pixel(c+Vector2(x,-180+fposmod(i*37-p*200,330)),Color(0.9,0.3,0.18,fade),10)
        "future":
            for i in 13:
                var x := (i-6)*40.0
                _line(c+Vector2(x,-250),c+Vector2(x,120),purple,3)
                var y := -250+i*30.0
                _line(c+Vector2(-260,y),c+Vector2(260,y),blue,3)
            for i in 48:
                var start := Vector2(sin(i*7.1)*310,cos(i*3.3)*240)
                var goal := Vector2(sin(i*4.3)*75,cos(i*2.1)*130)
                _pixel(c+start.lerp(goal,minf(1,p*1.7)),blue if i%2 == 0 else purple,10)
            _line(c+Vector2(-260,120-p*350),c+Vector2(260,120-p*350),white,7)
        "stellar":
            for i in 24:
                var at := c+Vector2(cos(i*2.4),sin(i*2.4))*float(90+i%5*30)
                var color := Color.from_hsv(fposmod(i/12.0+p*0.2,1),0.55,1,fade)
                var shape := PackedVector2Array([at+Vector2(0,-24),at+Vector2(15,0),at+Vector2(0,24),at+Vector2(-15,0)])
                draw_colored_polygon(shape,color)
                _star(at,7,white)
            for i in 7: _ring(c,140+i*9.0,Color.from_hsv(i/7.0,0.5,1,fade*0.7),0.65,6)
