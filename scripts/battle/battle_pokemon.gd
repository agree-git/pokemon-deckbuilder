class_name BattlePokemon
extends RefCounted
## Mutable combatant instance. Content definitions never hold battle state.

var uid: int
var species_id: int
var display_name: String
var type: String
var max_hp: int
var hp: int
var block := 0
var strength := 0
var statuses: Dictionary = {}
var knocked_out := false
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
    max_hp = int(definition["max_hp"])
    hp = max_hp

func alive() -> bool:
    return hp > 0

func gain_experience(base: int = 1) -> void:
    # Fixed tenths preserve 30% awards across repeated KOs without truncation.
    _experience_tenths += maxi(0,base) * (10 if alive() else 3)

func experience_text() -> String:
    return String.num(experience,1).trim_suffix(".0")

func snapshot() -> Dictionary:
    return {"uid": uid, "id": species_id, "hp": hp, "max_hp": max_hp, "block": block,
        "experience": experience, "strength": strength, "statuses": statuses.duplicate(true), "knocked_out": knocked_out}
