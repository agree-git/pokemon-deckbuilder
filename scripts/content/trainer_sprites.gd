class_name TrainerSprites
extends RefCounted
## Stable role-qualified mapping; missing art keeps the original generic entrance.
static var _manifest: Dictionary = {}
static func manifest() -> Dictionary:
    if _manifest.is_empty():
        _manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sources/trainer_sprites.json"))
    return _manifest
static func entry(trainer: Dictionary) -> Dictionary:
    return manifest()["entries"].get(TrainerDialogue.key(trainer),{})
static func texture(trainer: Dictionary) -> Texture2D:
    var path := str(entry(trainer).get("path",""))
    return null if path.is_empty() else load("res://"+path) as Texture2D
static func bounds(trainer: Dictionary) -> Rect2:
    var path := str(entry(trainer).get("path",""))
    if path.is_empty(): return Rect2()
    var values: Array = manifest()["assets"][path]["bounds"]
    return Rect2(values[0],values[1],values[2],values[3])
