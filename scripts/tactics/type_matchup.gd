class_name TypeMatchup
extends RefCounted
## Modern types, including dual typing and immunities. Legacy trials keep their tuning.
static var _chart: Dictionary = {}
static func multiplier(attack: String, defenses: Array[String]) -> float:
    if _chart.is_empty(): _chart = JSON.parse_string(FileAccess.get_file_as_string("res://data/type_chart.json"))
    var value := 1.0
    for defense: String in defenses: value *= float(_chart.get(attack,{}).get(defense,1.0))
    return value
