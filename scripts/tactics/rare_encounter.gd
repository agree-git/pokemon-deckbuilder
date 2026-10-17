class_name RareEncounter
extends RefCounted
## Independent, optional overlay: never changes route RNG, stops or XP budgets.
const LEGACY_IDS := [144,145,146,150,151,243,244,245,249,250,251,377,378,379,380,381,382,383,384,385,386]
const POOL_VERSION := 2
const IDS := [144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 716, 717, 718, 719, 720, 721, 772, 773, 785, 786, 787, 788, 789, 790, 791, 792, 800, 801, 802, 807, 808, 809, 888, 889, 890, 891, 892, 893, 894, 895, 896, 897, 898, 905, 1001, 1002, 1003, 1004, 1007, 1008, 1009, 1010, 1014, 1015, 1016, 1017, 1020, 1021, 1022, 1023, 1024, 1025, 10169, 10170, 10171]
const MYTHICAL := [151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, 801, 802, 807, 808, 809, 893, 1025]
const SUPER_LEGENDARY := [150, 249, 250, 382, 383, 384, 483, 484, 487, 643, 644, 646, 716, 717, 718, 791, 792, 800, 888, 889, 890, 898, 1007, 1008, 1024]
const TIERS := {
    "sublegendary":{"name":"준전설","required":3,"balls":3,"energy":2,"hp_percent":10,"level_bonus":5},
    "mythical":{"name":"환상","required":5,"balls":3,"energy":2,"hp_percent":10,"level_bonus":5},
    "superlegendary":{"name":"초전설","required":7,"balls":5,"energy":3,"hp_percent":10,"level_bonus":8},
}
static var _catalog: VisualCatalog

static func species(id: int) -> Dictionary:
    if _catalog == null: _catalog = VisualCatalog.new()
    return _catalog.species(id)

static func target(seed_value: int, pool_version: int = POOL_VERSION) -> int:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ 1732910879
    var pool: Array = LEGACY_IDS if pool_version == 1 else IDS
    return pool[rng.randi_range(0,pool.size()-1)]
static func requirement(id: int) -> int:
    return int(rule(id)["required"])
static func tier(id: int) -> String:
    return "superlegendary" if id in SUPER_LEGENDARY else ("mythical" if id in MYTHICAL else "sublegendary")
static func rule(id: int) -> Dictionary:
    return TIERS[tier(id)]
static func capture_help(id: int) -> String:
    var r := rule(id)
    return "%s · 몬스터볼 %d개 · 에너지 %d · HP %d%% 이하\n확정 포획 · 쓰러뜨리면 원정당 1회의 기회 종료" % [r["name"],r["balls"],r["energy"],r["hp_percent"]]
static func initial(seed_value: int) -> Dictionary:
    return {"pool_version":POOL_VERSION,"target":target(seed_value),"clues":[],"battle_step":-1,"captured":false}
static func node(original: Dictionary, id: int) -> Dictionary:
    # Only top-level fields change; keep nested immutable route content shared.
    var result := original.duplicate()
    var entry := species(id)
    result["name"] = str(rule(id)["name"])+" 조우 · "+str(entry["name"])
    result["party"] = [id]
    result["level"] = mini(100,int(original["level"])+int(rule(id)["level_bonus"]))
    result["icon"] = entry["types"][0]
    result["rare"] = true
    return result
static func opponents(original: Dictionary, id: int) -> Array:
    var encounter := node(original,id)
    var entry := species(id)
    var level: int = encounter["level"]
    var result := {"id":id,"name":entry["name"],"type":entry["types"][0],"types":entry["types"],"max_hp":PokemonStats.value(id,level,"hp"),"level":level}
    result.merge(EnemyTactics.build(id,level,entry["types"],"veteran",0,1))
    return [result]
static func valid(state: Variant, run: Dictionary, route: CampaignRoute) -> bool:
    if not state is Dictionary: return false
    var version: Variant = state.get("pool_version",1)
    if not version is int or version not in [1,POOL_VERSION]: return false
    if state.size() != (5 if state.has("pool_version") else 4): return false
    if not state.get("target") is int or state["target"] != target(int(run["seed_value"]),version) or not state.get("captured") is bool: return false
    if not state.get("clues") is Array or state["clues"].size() > requirement(state["target"]): return false
    var seen := []
    for step: Variant in state["clues"]:
        if not step is int or step < 0 or step > run["step"] or step >= route.stops.size(): return false
        if step in seen or step not in run["rested_steps"] or not run["camp_states"].has(step) or route.stops[step]["kind"] != "rest": return false
        seen.append(step)
    var encounter: Variant = state.get("battle_step")
    if not encounter is int: return false
    if encounter == -1: return not state["captured"]
    if encounter < 1 or encounter >= route.stops.size() or encounter > run["step"]+1: return false
    if encounter == run["step"]+1 and run["phase"] != TacticalJourney.REST: return false
    if route.stops[encounter]["kind"] != "wild" or int(route.stops[encounter]["chapter"]) < requirement(state["target"]): return false
    if state["clues"].size() != requirement(state["target"]) or run["badges"] < requirement(state["target"]): return false
    if seen.any(func(step: int): return step >= encounter): return false
    if state["captured"] and (run["step"] < encounter or state["target"] not in run["captured_ids"]): return false
    return true

static func identity_known(j: TacticalJourney) -> bool:
    var encounter: int = j.rare_hunt.get("battle_step",-1)
    return encounter >= 0 and (j.step > encounter or (j.step == encounter and j.phase != TacticalJourney.MAP))

static func public_name(j: TacticalJourney, stop: Dictionary) -> String:
    return "희귀 조우 · ???" if stop.get("rare",false) and not identity_known(j) else str(stop["name"])

static func public_text(j: TacticalJourney, message: String) -> String:
    if identity_known(j) or j.rare_hunt.is_empty(): return message
    return message.replace(str(species(j.rare_hunt["target"])["name"]),"???")
