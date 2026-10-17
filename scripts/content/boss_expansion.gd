class_name BossExpansion
extends RefCounted
## Separate v3 route inputs preserve regeneration of v1/v2 saved routes.
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty():
        _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_expansion.json"))
    return _data
