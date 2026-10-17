class_name TrainerDialogue
extends RefCounted
## Original character writing, selected by encounter role + stable trainer ID.
const PHASES := ["intro","last","defeat"]
const ROLES := {"gym":"관장","elite":"사천왕","champion":"챔피언"}
static var _lines: Dictionary = {}
static func data() -> Dictionary:
    if _lines.is_empty():
        _lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainer_dialogue.json"))["lines"]
    return _lines
static func opponent(stop: Dictionary,biome: Dictionary) -> Dictionary:
    var trainer: Dictionary = stop.get("trainer",{})
    var type := str(trainer.get("type",biome.get("type","normal")))
    return {"id":str(trainer.get("leader_id",trainer.get("id",""))),
        "name":str(trainer.get("leader",trainer.get("name",stop.get("name","트레이너")))),
        "kind":str(stop.get("kind","trainer")),"region":str(trainer.get("region","")),
        "mixed":type == "mixed","type":str(biome.get("type","normal")) if type == "mixed" else type}
static func key(trainer: Dictionary) -> String:
    return str(trainer.get("kind",""))+":"+str(trainer.get("id",""))
static func line(trainer: Dictionary,phase: String) -> String:
    if phase not in PHASES: return ""
    return str(data().get(key(trainer),{}).get(phase,""))
static func title(trainer: Dictionary) -> String:
    var parts: Array[String] = []
    if not str(trainer.get("region","")).is_empty(): parts.append(str(trainer["region"]))
    if ROLES.has(trainer.get("kind","")): parts.append(ROLES[trainer["kind"]])
    parts.append(str(trainer.get("name","트레이너")))
    return " ".join(parts)
