class_name MoveEffect
extends Node2D
## Deterministic, procedural presentation. Call play() with resolved move data.
## The future battle controller decides outcomes and applies status/damage.

signal impact(move: Dictionary)
signal finished(move: Dictionary)

const DURATION := 1.55
var move: Dictionary = {}
var source := Vector2.ZERO
var destination := Vector2.ZERO
var elapsed := 0.0
var playing := false
var speed := 1.0
var _hit := false

func play(definition: Dictionary, from: Vector2, to: Vector2) -> void:
    move = definition.duplicate(true)
    source = from
    destination = to
    elapsed = 0.0
    _hit = false
    playing = true
    queue_redraw()

func stop() -> void:
    playing = false
    queue_redraw()

func _process(delta: float) -> void:
    if not playing:
        return
    elapsed += delta * speed
    if not _hit and elapsed >= DURATION * 0.58:
        _hit = true
        impact.emit(move)
    if elapsed >= DURATION:
        playing = false
        finished.emit(move)
    queue_redraw()

func _draw() -> void:
    if not playing:
        return
    var p: float = clampf(elapsed / DURATION, 0.0, 1.0)
    var kind: String = move["vfx"]["primary"]
    var color := VisualCatalog.type_color(move["type"])
    var point: Vector2 = source if move["vfx"]["target"] == "self" else destination
    if move["vfx"]["target"] == "field":
        point = source.lerp(destination, 0.5)
    var alpha := sin(p * PI)
    color.a = alpha
    match kind:
        "projectile", "charge":
            if kind == "charge":
                draw_arc(source, 40.0 + 30.0 * (1.0 - p), 0, TAU * minf(p * 3.0, 1.0), 40, color, 4.0, false)
            var projectile_phase := clampf((p - 0.2) / 0.65, 0, 1) if kind == "charge" else p
            _projectile(source, point, projectile_phase, color, move["type"])
        "impact", "slash", "explosion":
            var strength := 1.7 if kind == "explosion" else 1.0
            _burst(point, p, color, strength)
            if kind == "slash":
                for i in 3:
                    var x := float(i - 1) * 22.0
                    draw_line(point + Vector2(x - 40, -65), point + Vector2(x + 30, 50), Color(1, 1, 1, alpha), 6.0, false)
            elif kind == "impact":
                draw_line(source.lerp(point, 0.15), source.lerp(point, minf(p * 2.0, 0.85)), Color(color, alpha * 0.35), 12.0, false)
            else:
                _burst(source, p, color, 0.7)
        "shield":
            _polygon_ring(point, 65 + sin(p * PI) * 12, 6, color, 4)
            _polygon_ring(point, 53, 6, Color(color, alpha * 0.4), 2)
        "heal", "drain":
            if kind == "drain":
                for i in 8:
                    var t := fposmod(p * 1.5 + i * 0.07, 1.0)
                    var pos := point.lerp(source, t) + Vector2(0, sin(t * TAU + i) * 22)
                    draw_circle(pos, 5, Color("9ce7b5") * Color(1, 1, 1, alpha))
            _healing(source if kind == "drain" else point, p, alpha)
        "stat_up", "stat_down":
            var sign_y := -1.0 if kind == "stat_up" else 1.0
            var arrow_color := Color("96e4ba") if sign_y < 0 else Color("c29ae5")
            arrow_color.a = alpha
            for i in 4:
                var pos := point + Vector2((i - 1.5) * 30, sign_y * (p * 110 - 40))
                draw_line(pos, pos + Vector2(0, sign_y * 30), arrow_color, 4, false)
                draw_polyline(PackedVector2Array([pos + Vector2(-9, sign_y * 19), pos + Vector2(0, sign_y * 30), pos + Vector2(9, sign_y * 19)]), arrow_color, 4, false)
        "mist":
            for i in 6:
                draw_set_transform(point + Vector2((i - 2.5) * 85, sin(p * TAU + i) * 25), 0, Vector2(2.2, 0.5))
                draw_circle(Vector2.ZERO, 45 + p * 20, Color(0.7, 0.9, 1, alpha * 0.19))
            draw_set_transform(Vector2.ZERO)
        "evade":
            for i in 6:
                var pos := point + Vector2(-100 * p, (i - 2.5) * 16)
                draw_line(pos, pos + Vector2(90, 0), Color(0.8, 0.9, 1, alpha), 3, false)
        "transform":
            draw_arc(source, 70, p * TAU, p * TAU + PI * 1.6, 48, color, 5, false)
            for i in 8:
                _star(source + Vector2.from_angle(i * TAU / 8 + p * 2) * 65, 9, color)
        "seal":
            _polygon_ring(point, 58, 6, Color(0.8, 0.6, 1, alpha), 4)
            draw_line(point + Vector2(-30, -30), point + Vector2(30, 30), Color(1, 0.65, 0.7, alpha), 6)
            draw_line(point + Vector2(30, -30), point + Vector2(-30, 30), Color(1, 0.65, 0.7, alpha), 6)
        "splash":
            for i in 3:
                draw_arc(source + Vector2(0, 65 - i * 15 - sin(p * PI) * 35), 25 + i * 10, 0.2, PI - 0.2, 16, Color(0.8, 0.9, 1, alpha), 3)
        "utility":
            draw_arc(point, 45 + p * 15, p * TAU, p * TAU + PI, 24, color, 3)
        _:
            draw_status(self, kind, point, p * TAU, alpha)

func _projectile(from: Vector2, to: Vector2, p: float, color: Color, type: String) -> void:
    var travel := clampf((p - 0.12) / 0.46, 0, 1)
    var head := from.lerp(to, travel)
    if p < 0.62:
        for i in 7:
            var pos := from.lerp(head, 1.0 - i * 0.055)
            draw_circle(pos, 22.0 - i * 2.5, Color(color, color.a * (1.0 - i * 0.12)))
        match type:
            "electric":
                var points := PackedVector2Array()
                for i in 13:
                    points.append(from.lerp(head, i / 12.0) + Vector2(0, sin(i * 2.1 + p * 40) * 17))
                draw_polyline(points, Color("ffe77e") * Color(1, 1, 1, color.a), 5, false)
            "grass", "bug":
                for i in 4:
                    var pos := head + Vector2.from_angle(i * TAU / 4 + p * 10) * 20
                    _diamond(pos, 14, color)
            "ice", "rock", "ground", "steel":
                for i in 5:
                    _diamond(head + Vector2(i * -8, sin(i + p * 4) * 18), 12, color)
            "psychic", "ghost", "dark":
                draw_arc(head, 35, p * 12, p * 12 + PI * 1.7, 32, color, 4, false)
            "flying":
                for i in 3:
                    draw_arc(head + Vector2(0, (i - 1) * 14), 25, -1.2, 1.2, 16, color, 3, false)
            "fairy", "dragon":
                _star(head, 30, Color(color, color.a))
            "fire":
                draw_circle(head + Vector2(6, 0), 14, Color(1, 0.9, 0.5, color.a))
            "water":
                draw_arc(head, 26, 0, TAU, 32, Color(0.8, 0.96, 1, color.a), 3, false)
    if p > 0.42:
        _burst(to, clampf((p - 0.42) / 0.58, 0, 1), color, 1)

func _burst(point: Vector2, p: float, color: Color, strength: float) -> void:
    var radius := (12.0 + p * 85.0) * strength
    draw_arc(point, radius, 0, TAU, 40, color, 3.5, false)
    for i in 12:
        var direction := Vector2.from_angle(i * TAU / 12 + 0.2)
        draw_line(point + direction * radius * 0.55, point + direction * radius, color, 4, false)
    _star(point, maxf(2, (1 - p) * 38 * strength), Color(1, 1, 0.9, color.a))

func _healing(point: Vector2, p: float, alpha: float) -> void:
    for i in 6:
        var pos := point + Vector2((i - 2.5) * 22, -fposmod(p * 130 + i * 19, 130) + 45)
        var c := Color(0.6, 1, 0.76, alpha)
        draw_line(pos - Vector2(8, 0), pos + Vector2(8, 0), c, 4, false)
        draw_line(pos - Vector2(0, 8), pos + Vector2(0, 8), c, 4, false)

func _polygon_ring(point: Vector2, radius: float, sides: int, color: Color, width: float) -> void:
    var points := PackedVector2Array()
    for i in sides + 1:
        points.append(point + Vector2.from_angle(i * TAU / sides - PI / 2) * radius)
    draw_polyline(points, color, width, false)

func _diamond(point: Vector2, radius: float, color: Color) -> void:
    draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius * 0.5, 0), point + Vector2(0, radius), point + Vector2(-radius * 0.5, 0)]), color)

func _star(point: Vector2, radius: float, color: Color) -> void:
    var points := PackedVector2Array()
    for i in 10:
        points.append(point + Vector2.from_angle(i * TAU / 10 - PI / 2) * radius * (1.0 if i % 2 == 0 else 0.4))
    draw_colored_polygon(points, color)

static func draw_status(canvas: CanvasItem, kind: String, point: Vector2, phase: float, alpha: float = 1.0) -> void:
    var color := Color(1, 1, 1, alpha)
    for i in 5:
        var angle := phase + i * TAU / 5
        var pos := point + Vector2(cos(angle) * 48, sin(angle) * 23 - 25)
        match kind:
            "burn":
                color = Color(1, 0.45 + 0.1 * sin(angle), 0.15, alpha)
                pos.y -= fposmod(phase * 12 + i * 13, 45)
                canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, 8), pos + Vector2(1, -20), pos + Vector2(11, 8)]), color)
                canvas.draw_circle(pos + Vector2(1, 6), 5, Color(1, 0.9, 0.4, alpha))
            "poison":
                canvas.draw_circle(pos - Vector2(0, fposmod(phase * 9 + i * 10, 45)), 8, Color(0.75, 0.4, 0.9, alpha * 0.7))
            "paralysis":
                canvas.draw_polyline(PackedVector2Array([pos + Vector2(4, -15), pos + Vector2(-5, 0), pos + Vector2(6, -1), pos + Vector2(-4, 16)]), Color(1, 0.9, 0.3, alpha), 4, false)
            "sleep":
                canvas.draw_string(ThemeDB.fallback_font, pos - Vector2(0, fposmod(phase * 8 + i * 9, 40)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20 + i * 2, Color(0.75, 0.85, 1, alpha))
            "freeze":
                canvas.draw_polyline(PackedVector2Array([pos + Vector2(0, -18), pos + Vector2(9, 3), pos + Vector2(0, 14), pos + Vector2(-9, 3), pos + Vector2(0, -18)]), Color(0.65, 0.95, 1, alpha), 3, false)
            "seed":
                canvas.draw_arc(point + Vector2(i * 9 - 18, 30), 25 + i * 5, -PI, 0, 22, Color(0.4, 0.9, 0.5, alpha), 3, false)
                canvas.draw_circle(pos, 5, Color(0.7, 1, 0.45, alpha))
            "bind":
                canvas.draw_set_transform(point + Vector2(0, i * 13 - 30), 0, Vector2(1, 0.3))
                canvas.draw_arc(Vector2.ZERO, 52, phase + i, phase + i + PI * 1.6, 32, Color(0.85, 0.75, 0.65, alpha), 3, false)
                canvas.draw_set_transform(Vector2.ZERO)
            _:
                canvas.draw_circle(pos, 5 + 2 * sin(angle), Color(1, 0.84, 0.35, alpha))
