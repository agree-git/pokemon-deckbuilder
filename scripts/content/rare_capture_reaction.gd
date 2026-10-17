class_name RareCaptureReaction
extends RefCounted
## Read-only narration after a successful capture. No save fields, rewards or RNG.
const EVENTS: Array[String] = ["capture", "joined", "released"]
static var _reactions: Dictionary = {}

static func line(id: int, event: String) -> String:
    if id not in RareEncounter.IDS or event not in EVENTS: return ""
    if _reactions.is_empty():
        _reactions = JSON.parse_string(FileAccess.get_file_as_string("res://data/rare_reactions.json"))
    return str(_reactions.get(str(id), {}).get(event, ""))
