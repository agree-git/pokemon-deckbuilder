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
var experience := 0

func _init(definition: Dictionary, instance_uid: int) -> void:
    uid = instance_uid
    species_id = int(definition["id"])
    display_name = definition["name"]
    type = definition["type"]
    max_hp = int(definition["max_hp"])
    hp = max_hp

func alive() -> bool:
    return hp > 0

func snapshot() -> Dictionary:
    return {"uid": uid, "id": species_id, "hp": hp, "max_hp": max_hp, "block": block,
        "experience": experience, "strength": strength, "statuses": statuses.duplicate(true), "knocked_out": knocked_out}
