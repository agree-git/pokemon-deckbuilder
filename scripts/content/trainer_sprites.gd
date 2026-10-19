class_name TrainerSprites
extends RefCounted
## Dedicated boss mapping plus a reusable original-game pool for ordinary trainers.
static var _manifest: Dictionary = {}
static var _regular: Array = []
static func regular() -> Array:
    if _regular.is_empty():
        _regular = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sources/regular_trainers.json"))["entries"]
    return _regular
static func manifest() -> Dictionary:
    if _manifest.is_empty():
        _manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sources/trainer_sprites.json"))
    return _manifest
static func entry(trainer: Dictionary) -> Dictionary:
    if trainer.get("kind","") in ["trainer","veteran"]:
        # A presentation-only seed keeps the same encounter's portrait on refresh/load.
        var seed_value := int(trainer.get("sprite_seed",TrainerDialogue.title(trainer).hash()))
        return regular()[posmod(seed_value,regular().size())]
    return manifest()["entries"].get(TrainerDialogue.key(trainer),{})
static func texture(trainer: Dictionary) -> Texture2D:
    var path := str(entry(trainer).get("path",""))
    return null if path.is_empty() else load("res://"+path) as Texture2D
static func bounds(trainer: Dictionary) -> Rect2:
    var definition := entry(trainer)
    var path := str(definition.get("path",""))
    if path.is_empty(): return Rect2()
    var values: Array = definition["bounds"] if definition.has("bounds") else manifest()["assets"][path]["bounds"]
    return Rect2(values[0],values[1],values[2],values[3])
