class_name BossParties
extends RefCounted
## Approved v5 parties. Historical roster files remain unchanged for saved routes.
const PATH := "res://data/boss_parties.json"
static var _entries: Dictionary = {}
static func entries() -> Dictionary:
    if _entries.is_empty():
        _entries = JSON.parse_string(FileAccess.get_file_as_string(PATH))["entries"]
    return _entries
static func party(key: String) -> Array[int]:
    var result: Array[int] = []
    result.assign(entries().get(key,{}).get("party",[]))
    return result
static func aces(key: String) -> Array[int]:
    var result: Array[int] = []
    result.assign(entries().get(key,{}).get("fixed_aces",[]))
    return result
static func apply(role: String,trainer: Dictionary) -> Dictionary:
    var result := trainer.duplicate(true)
    var key := role+":"+str(trainer.get("leader_id",trainer.get("id","")))
    if entries().has(key):
        result["party"] = party(key)
        result["fixed_aces"] = aces(key)
    return result
