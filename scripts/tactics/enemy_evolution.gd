extends RefCounted
## Resolve the selected family backwards without drawing RNG or raising enemy levels.
static var _incoming: Dictionary = {}
static var _minimum: Dictionary = {}
static func _load() -> void:
    if not _incoming.is_empty(): return
    for rule: Dictionary in PokedexExpansion.data()["evolutions"]:
        var target := int(rule["to"])
        if not _incoming.has(target): _incoming[target] = []
        _incoming[target].append(rule)
    # Costume/size/sex forms may share an evolution without their own graph edge.
    for entry: Dictionary in PokedexExpansion.data()["pokemon"]:
        var id := int(entry["id"])
        if _incoming.has(id) or int(entry["evolves_from"]) == 0: continue
        for sibling: int in PokedexExpansion.forms(id):
            if _incoming.has(sibling):
                _incoming[id] = _incoming[sibling]
                break
static func minimum_level(id: int) -> int:
    _load()
    if _minimum.has(id): return _minimum[id]
    var result := 1 if not _incoming.has(id) else 100
    for rule: Dictionary in _incoming.get(id,[]):
        result = mini(result,maxi(int(rule["level"]),minimum_level(int(rule["from"]))))
    _minimum[id] = result
    return result
static func at_level(id: int,level: int) -> int:
    if level >= minimum_level(id): return id
    var parent := id
    var earliest := 101
    for rule: Dictionary in _incoming.get(id,[]):
        var required := maxi(int(rule["level"]),minimum_level(int(rule["from"])))
        if required < earliest:
            earliest = required
            parent = int(rule["from"])
    return at_level(parent,level) if parent != id else id
