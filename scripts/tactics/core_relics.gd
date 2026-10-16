class_name CoreRelics
extends RefCounted
## One optional run-defining choice; ordinary party relics remain additive.
const KEYS := ["relay_core","ace_core","status_core","shield_core","supply_core"]
static func selected(acquired: Array) -> String:
    for key: String in acquired:
        if key in KEYS: return key
    return ""
static func valid(acquired: Array) -> bool:
    return acquired.filter(func(key: Variant): return key in KEYS).size() <= 1
static func draw_count(acquired: Array) -> int:
    return 4 if selected(acquired) in ["relay_core","supply_core"] else 5
static func offers(acquired: Array, rng: RandomNumberGenerator) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not selected(acquired).is_empty(): return result
    var available := KEYS.duplicate()
    for i in 3:
        var index := rng.randi_range(0,available.size()-1)
        result.append({"kind":"relic","key":available.pop_at(index)})
    return result
