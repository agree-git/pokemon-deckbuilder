class_name BattleBackdrops
extends RefCounted
## Presentation-only room selection. Route, encounter RNG and saves stay intact.
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_backdrops.json"))
    return _data
static func for_stop(stop: Dictionary,biome: Dictionary) -> Dictionary:
    var trainer: Dictionary = stop.get("trainer",{})
    var key := str(stop["kind"])+":"+str(trainer.get("leader_id",trainer.get("id","")))
    if BossExpansion.data()["backdrops"].has(key):
        return BossExpansion.data()["backdrops"][key].duplicate(true)
    if stop["kind"] == "elite":
        var type: String = trainer.get("type",biome["type"])
        if data()["elite"].has(type): return data()["elite"][type].duplicate(true)
    elif stop["kind"] == "champion":
        return data()["champions"].get(trainer.get("id",""),data()["fallback_champion"]).duplicate(true)
    return biome.duplicate(true)
