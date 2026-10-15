class_name TacticalJourneyContent
extends RefCounted
## One grass biome spanning generations 1–3; an authored fan-game party.
const STOPS := [
    {"name":"햇살숲 입구","kind":"battle","icon":"grass"},
    {"name":"숲속 야영지","kind":"rest","icon":"heal"},
    {"name":"체육관 수련자","kind":"battle","icon":"attack"},
    {"name":"체육관 앞 야영지","kind":"rest","icon":"heal"},
    {"name":"풀의 체육관 · 민화","kind":"gym","icon":"grass"},
]
const GYM_PARTY := [
    {"id":182,"name":"아르코","type":"grass","max_hp":32},
    {"id":189,"name":"솜솜코","type":"grass","max_hp":38},
    {"id":315,"name":"로젤리아","type":"grass","max_hp":36},
    {"id":114,"name":"덩쿠리","type":"grass","max_hp":40},
    {"id":45,"name":"라플레시아","type":"grass","max_hp":46},
    {"id":71,"name":"우츠보트","type":"grass","max_hp":54},
]
static func _base_opponents(step: int) -> Array:
    if step == 0: return TacticalContent.ENEMIES.duplicate(true)
    if step == 2:
        return [enemy(187,"통통코",44,10),enemy(285,"버섯꼬",54,12)]
    var result: Array = []
    for definition: Dictionary in GYM_PARTY:
        result.append(enemy(definition["id"],definition["name"],definition["max_hp"],12 if definition["id"] != 71 else 16))
    return result
const BASE_EXPERIENCE := 400
const ITEMS := {
    "potion":{"name":"상처약","price":30,"heal":20,"stock":3},
    "super_potion":{"name":"좋은상처약","price":70,"heal":50,"stock":2},
    "revive":{"name":"기력의조각","price":100,"revive":true,"stock":1},
}
static func experience_multiplier(step: int) -> float:
    return 1.0+floori(step/2.0)*0.75
static func experience_reward(step: int) -> float:
    var encounter := 1.0 if step == 0 else (1.25 if step == 2 else 1.5)
    return BASE_EXPERIENCE*experience_multiplier(step)*encounter
static func enemy_level(step: int) -> int:
    return 6+floori(step/2.0)*4
static func opponents(step: int) -> Array:
    var result := _base_opponents(step)
    var level := enemy_level(step)
    for definition: Dictionary in result:
        definition["level"] = level
        definition["max_hp"] = int(definition["max_hp"])+level-6
        for intent: Dictionary in definition["intents"]:
            if intent["kind"] in ["attack","charge"]: intent["value"] = int(intent["value"])+floori((level-6)/5.0)
    return result
static func enemy(id: int, title: String, hp: int, power: int) -> Dictionary:
    return {"id":id,"name":title,"type":"grass","max_hp":hp,"intents":[
        {"kind":"charge","value":power,"type":"grass","move_id":22},
        {"kind":"block","value":6,"move_id":115},
        {"kind":"attack","value":power-2,"type":"grass","move_id":75}]}
