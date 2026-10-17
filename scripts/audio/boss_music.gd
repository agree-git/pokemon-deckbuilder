class_name BossMusic
extends RefCounted
const MANIFEST := "res://assets/audio/boss_music/manifest.json"
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    return _data
static func variants(trainer: Dictionary) -> Array:
    return data()["trainers"].get(TrainerDialogue.key(trainer),[])
static func path(id: String) -> String:
    for track: Dictionary in data()["tracks"]:
        if track["id"] == id: return track["path"]
    return ""
