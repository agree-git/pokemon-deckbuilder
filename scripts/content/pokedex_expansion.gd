class_name PokedexExpansion
extends RefCounted
## National Dex metadata. Immutable, cached and independent from gameplay RNG.
const PATH := "res://data/pokedex_expansion.json"
const MAX_ID := 65535
static var _data: Dictionary = {}
static var _species: Dictionary = {}
static var _families: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty():
        _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        for entry: Dictionary in _data["pokemon"]:
            _species[int(entry["id"])] = entry
            var dex := int(entry["dex_id"])
            if not _families.has(dex): _families[dex] = []
            _families[dex].append(int(entry["id"]))
    return _data
static func species(id: int) -> Dictionary:
    data()
    return _species.get(id,{})
static func supports(id: int) -> bool:
    data()
    return _species.has(id)
static func forms(id: int) -> Array[int]:
    var entry := species(id)
    var result: Array[int] = []
    if entry.is_empty(): return result
    for candidate: int in _families[int(entry["dex_id"])]:
        if species(candidate).get("regional","") == entry.get("regional",""): result.append(candidate)
    return result
static func form_requirements(id: int) -> Array[int]:
    match id:
        10022: return [646,644]
        10023: return [646,643]
        10155: return [800,791]
        10156: return [800,792]
        10193: return [898,896]
        10194: return [898,897]
    return []
static func form_known(id: int,captured: Array) -> bool:
    var entry := species(id)
    if entry.is_empty(): return false
    for partner: int in form_requirements(id):
        if not captured.any(func(value: int): return value == partner or int(species(value).get("dex_id",0)) == partner): return false
    if id in captured: return true
    return captured.any(func(value: int):
        var other := species(value)
        return not other.is_empty() and other["dex_id"] == entry["dex_id"] and other.get("regional","") == entry.get("regional",""))
static func ability_text(id: int) -> String:
    var names: Array[String] = []
    for ability: Dictionary in species(id).get("abilities",[]):
        var entry: Dictionary = data()["abilities"].get(str(int(ability["id"])),{})
        names.append(str(entry.get("name",""))+(" (숨겨진 특성)" if ability["hidden"] else ""))
    return " / ".join(names)
static func move_type(id: int,move_id: int,fallback: String) -> String:
    var entry := species(id)
    if entry.is_empty(): return fallback
    if move_id in [449,718,686]: return str(entry["types"][0])
    if move_id == 546:
        return {"shock":"electric","burn":"fire","chill":"ice","douse":"water"}.get(str(entry.get("form","")),fallback)
    if move_id == 873:
        var key := str(entry.get("key",""))
        if key.contains("blaze-breed"): return "fire"
        if key.contains("aqua-breed"): return "water"
        if key.contains("combat-breed"): return "fighting"
    return fallback
