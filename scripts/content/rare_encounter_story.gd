class_name RareEncounterStory
extends RefCounted
## Read-only flavor keyed by species and already-earned clues; no RNG or save fields.
static var _stories: Dictionary = {}
static var _biomes: Array = []

static func entry(id: int) -> Dictionary:
    if _stories.is_empty():
        _stories = JSON.parse_string(FileAccess.get_file_as_string("res://data/rare_stories.json"))
    return _stories.get(str(id),{}).duplicate(true)

static func clue(id: int, count: int) -> String:
    var story := entry(id)
    if story.is_empty(): return ""
    var clues: Array = story["clues"]
    return str(story["rumor"]) if count <= 0 else str(clues[mini(count,clues.size())-1])

static func backdrop(id: int) -> Dictionary:
    var story := entry(id)
    if story.is_empty(): return {}
    if _biomes.is_empty():
        _biomes = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
    for biome: Dictionary in _biomes:
        if biome["type"] != story["backdrop_type"]: continue
        var result := biome.duplicate(true)
        result["name"] = story["site"]
        return result
    return {}
