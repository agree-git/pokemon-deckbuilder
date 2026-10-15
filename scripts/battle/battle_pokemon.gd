class_name BattlePokemon
extends RefCounted
## Mutable combatant instance. Content definitions never hold battle state.

var uid: int
var species_id: int
var display_name: String
var type: String
var types: Array[String] = []
var max_hp: int
var hp: int
var block := 0
var strength := 0
var statuses: Dictionary = {}
var knocked_out := false
var level := 5
var evolution_power := 0
var learned_skills: Array[String] = []
var progression_initialized := false
var _experience_tenths := 0
var experience: float:
    get:
        return _experience_tenths / 10.0
    set(value):
        _experience_tenths = maxi(0,roundi(value * 10.0))

func _init(definition: Dictionary, instance_uid: int) -> void:
    uid = instance_uid
    species_id = int(definition["id"])
    display_name = definition["name"]
    type = definition["type"]
    types.assign(definition.get("types",[type]))
    max_hp = int(definition["max_hp"])
    level = int(definition.get("level",5))
    hp = max_hp

func alive() -> bool:
    return hp > 0

func gain_experience(base: float = 1.0) -> void:
    # Fixed tenths preserve 30% awards across repeated KOs without truncation.
    _experience_tenths += roundi(maxf(0,base) * (10 if alive() else 3))

func experience_text() -> String:
    return String.num(experience,1).trim_suffix(".0")

func snapshot() -> Dictionary:
    return {"types":types.duplicate(),"uid": uid, "id": species_id, "hp": hp, "max_hp": max_hp, "block": block,
        "experience": experience, "level": level, "evolution_power": evolution_power,
        "skills": learned_skills.duplicate(), "strength": strength, "statuses": statuses.duplicate(true), "knocked_out": knocked_out}
