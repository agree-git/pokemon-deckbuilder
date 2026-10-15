class_name BattleCardInstance
extends RefCounted

var uid: int
var key: String
var owner_uid: int
var injury_owner_uid := 0

func _init(instance_uid: int, content_key: String, owner: int) -> void:
    uid = instance_uid
    key = content_key
    owner_uid = owner
