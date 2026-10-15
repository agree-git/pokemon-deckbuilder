class_name TacticalJourneyContent
extends RefCounted
## One grass biome. Authored fan-game party, not a recreation of a specific edition.
const STOPS := [
    {"name":"햇살숲 입구","kind":"battle","icon":"grass"},
    {"name":"숲속 야영지","kind":"rest","icon":"heal"},
    {"name":"체육관 수련자","kind":"battle","icon":"attack"},
    {"name":"체육관 앞 야영지","kind":"rest","icon":"heal"},
    {"name":"풀의 체육관 · 민화","kind":"gym","icon":"grass"},
]
const GYM_PARTY := [
    {"id":69,"name":"모다피","type":"grass","max_hp":32},
    {"id":114,"name":"덩쿠리","type":"grass","max_hp":38},
    {"id":102,"name":"아라리","type":"grass","max_hp":36},
    {"id":70,"name":"우츠동","type":"grass","max_hp":40},
    {"id":45,"name":"라플레시아","type":"grass","max_hp":46},
    {"id":71,"name":"우츠보트","type":"grass","max_hp":54},
]
static func opponents(step: int) -> Array:
    if step == 0: return TacticalContent.ENEMIES.duplicate(true)
    if step == 2:
        return [enemy(43,"뚜벅쵸",44,10),enemy(44,"냄새꼬",54,12)]
    var result: Array = []
    for definition: Dictionary in GYM_PARTY:
        result.append(enemy(definition["id"],definition["name"],definition["max_hp"],12 if definition["id"] != 71 else 16))
    return result
static func enemy(id: int, title: String, hp: int, power: int) -> Dictionary:
    return {"id":id,"name":title,"type":"grass","max_hp":hp,"intents":[
        {"kind":"charge","value":power,"type":"grass","move_id":22},
        {"kind":"block","value":6,"move_id":115},
        {"kind":"attack","value":power-2,"type":"grass","move_id":75}]}
