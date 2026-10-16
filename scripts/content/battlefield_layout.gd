class_name BattlefieldLayout
extends RefCounted
## Measured floor points in atlas-cell pixels. Presentation only; no run state.
static var _data: Dictionary = {}

static func data() -> Dictionary:
    if _data.is_empty():
        _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/battlefield_layouts.json"))
    return _data

static func for_backdrop(descriptor: Dictionary) -> Dictionary:
    var cells: Array = data()["backgrounds"].get(descriptor.get("background",""),[])
    var cell := int(descriptor.get("cell",-1))
    return cells[cell].duplicate(true) if cell >= 0 and cell < cells.size() else {}

static func point(profile: Dictionary,on_ally: bool) -> Vector2:
    var p: Array = profile["ally" if on_ally else "enemy"]
    return Vector2(float(p[0]),float(p[1]))

static func frame(profile: Dictionary,viewport: Vector2,texture_size: Vector2) -> Rect2:
    var zoom := viewport.x/texture_size.x
    # Camera derives from artwork, never from a sprite's changing position/size.
    # Keep the JSON's double precision until after floor. Casting a fractional
    # point to Vector2 first can turn 297.6*2.5 into 744.000015 and shift a room
    # by one pixel compared with the HTML editor and the intended camera rule.
    var origin_y := floorf(viewport.y*float(data()["ally_screen_y"])/1080-float(profile["ally"][1])*zoom)
    var origin := Vector2(0,origin_y)
    return Rect2(origin,texture_size*zoom)

static func project(profile: Dictionary,on_ally: bool,viewport: Vector2,texture_size: Vector2) -> Vector2:
    var rect := frame(profile,viewport,texture_size)
    return rect.position+point(profile,on_ally)*(rect.size.x/texture_size.x)
