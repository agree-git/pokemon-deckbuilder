class_name RunStatistics
extends RefCounted
## Local counters only. No RNG, clocks, network, or gameplay decisions.
const COMBAT_KEYS := ["turns_started","cards_played","techniques","tools","trainers","status_cards","energy_spent","unused_energy","drawn","reshuffles","auto_switches","manual_switches","forced_switches","damage_dealt","damage_taken","shield_absorbed","healing","knockouts","captures"]
const RUN_KEYS := ["gold_earned","gold_cards","gold_supplies","gold_removal","gold_events","cards_bought","cards_removed","cards_upgraded","supplies_bought","items_used","camp_healing","rests","reward_card","reward_relic","reward_held","reward_skip"]

static func zeros(keys: Array) -> Dictionary:
    var result := {}
    for key: String in keys: result[key] = 0
    return result
static func battle(partial := false) -> Dictionary:
    return {"partial":partial,"counts":zeros(COMBAT_KEYS),"cards":{},"relics":{}}
static func expedition(partial := false) -> Dictionary:
    return {"partial":partial,"counts":zeros(RUN_KEYS),"combat":zeros(COMBAT_KEYS),"cards":{},"relics":{},"battles":[],"choices":[]}
static func increment(mapping: Dictionary, key: String, amount := 1) -> void:
    mapping[key] = int(mapping.get(key,0))+amount
static func merge_counts(target: Dictionary, source: Dictionary) -> void:
    for key: String in source: increment(target,key,int(source[key]))
static func decision(stats: Dictionary, step: int, text: String) -> void:
    stats["choices"].append("%d전 후 · %s" % [floori(step/2.0)+1,text])
    if stats["choices"].size() > 512: stats["choices"].pop_front()
static func settle(stats: Dictionary, b: TacticalBattle, step: int, place: Dictionary) -> void:
    var combat := b.statistics if not b.statistics.is_empty() else battle(true)
    stats["partial"] = stats["partial"] or combat["partial"]
    merge_counts(stats["combat"],combat["counts"])
    merge_counts(stats["cards"],combat["cards"])
    merge_counts(stats["relics"],combat["relics"])
    stats["battles"].append({"step":step,"name":place["name"],"kind":place["kind"],"won":b.phase == TacticalBattle.WON,"turns":b.turn,"partial":combat["partial"],"counts":combat["counts"].duplicate(true)})
static func spent(stats: Dictionary) -> int:
    var counts: Dictionary = stats["counts"]
    return int(counts["gold_cards"])+int(counts["gold_supplies"])+int(counts["gold_removal"])+int(counts["gold_events"])
static func ranked(mapping: Dictionary) -> Array:
    var keys := mapping.keys()
    keys.sort_custom(func(a: String,b: String): return int(mapping[a]) > int(mapping[b]) if mapping[a] != mapping[b] else a < b)
    return keys
static func card_name(key: String) -> String:
    var view: Dictionary = TacticalContent.CARDS[key] if TacticalContent.CARDS.has(key) else TacticalMoves.definition(key)
    return str(view.get("name",key))
static func valid_counts(value: Variant, keys: Array) -> bool:
    if not value is Dictionary or value.size() != keys.size(): return false
    for key: String in keys:
        if not value.get(key) is int or value[key] < 0 or value[key] > 1000000000: return false
    return true
static func valid_uses(value: Variant, relics := false) -> bool:
    if not value is Dictionary or value.size() > 512: return false
    for key: Variant in value:
        if not key is String or key.length() > 64 or not value[key] is int or value[key] < 1 or value[key] > 1000000000: return false
        if relics:
            if not TacticalContent.RELICS.has(key): return false
        elif not TacticalContent.CARDS.has(key) and TacticalMoves.definition(key).is_empty(): return false
    return true
static func valid_battle(value: Variant) -> bool:
    return value is Dictionary and value.get("partial") is bool and valid_counts(value.get("counts"),COMBAT_KEYS) and valid_uses(value.get("cards")) and valid_uses(value.get("relics"),true)
static func valid_run(value: Variant) -> bool:
    if not value is Dictionary or not value.get("partial") is bool: return false
    if not valid_counts(value.get("counts"),RUN_KEYS) or not valid_counts(value.get("combat"),COMBAT_KEYS): return false
    if not valid_uses(value.get("cards")) or not valid_uses(value.get("relics"),true): return false
    if not value.get("battles") is Array or value["battles"].size() > 69 or not value.get("choices") is Array or value["choices"].size() > 512: return false
    var seen := {}
    var totals := zeros(COMBAT_KEYS)
    for entry: Variant in value["battles"]:
        if not entry is Dictionary or not entry.get("step") is int or entry["step"] < 0 or entry["step"] > 136 or seen.has(entry["step"]): return false
        if not entry.get("name") is String or entry["name"].length() > 256 or not entry.get("kind") is String: return false
        if entry["kind"] not in ["battle","wild","trainer","veteran","gym","elite","champion"]: return false
        if not entry.get("won") is bool or not entry.get("partial") is bool or not entry.get("turns") is int or entry["turns"] < 1 or entry["turns"] > 1000000: return false
        if not valid_counts(entry.get("counts"),COMBAT_KEYS): return false
        seen[entry["step"]] = true
        merge_counts(totals,entry["counts"])
    if totals != value["combat"]: return false
    for entry: Variant in value["choices"]:
        if not entry is String or entry.length() > 256: return false
    return true
