class_name EvolutionItems
extends RefCounted
## Gen 1–3 base forms. Trade materials replace external trading in this solo game.
const ITEMS := {
    "darkness_scroll":{"name":"악의족자","price":220,"stock":1},
    "metal_candy":{"name":"멜탄의사탕","price":220,"stock":1},
    "fire_stone":{"name":"불꽃의돌","price":180,"stock":1},
    "water_stone":{"name":"물의돌","price":180,"stock":1},
    "thunder_stone":{"name":"천둥의돌","price":180,"stock":1},
    "leaf_stone":{"name":"리프의돌","price":180,"stock":1},
    "moon_stone":{"name":"달의돌","price":180,"stock":1},
    "sun_stone":{"name":"태양의돌","price":180,"stock":1},
    "linking_cord":{"name":"연결의끈","price":180,"stock":1},
    "kings_rock":{"name":"왕의징표석","price":220,"stock":1},
    "metal_coat":{"name":"금속코트","price":220,"stock":1},
    "dragon_scale":{"name":"용의비늘","price":220,"stock":1},
    "upgrade":{"name":"업그레이드","price":220,"stock":1},
    "deep_sea_tooth":{"name":"심해의이빨","price":220,"stock":1},
    "deep_sea_scale":{"name":"심해의비늘","price":220,"stock":1},
}
const ROUTES := {891:{"darkness_scroll":892},808:{"metal_candy":809},
    25:{"thunder_stone":26},30:{"moon_stone":31},33:{"moon_stone":34},35:{"moon_stone":36},
    37:{"fire_stone":38},39:{"moon_stone":40},44:{"leaf_stone":45,"sun_stone":182},
    58:{"fire_stone":59},61:{"water_stone":62,"kings_rock":186},64:{"linking_cord":65},
    67:{"linking_cord":68},70:{"leaf_stone":71},75:{"linking_cord":76},79:{"kings_rock":199},
    90:{"water_stone":91},93:{"linking_cord":94},95:{"metal_coat":208},102:{"leaf_stone":103},
    117:{"dragon_scale":230},120:{"water_stone":121},123:{"metal_coat":212},
    133:{"water_stone":134,"thunder_stone":135,"fire_stone":136},137:{"upgrade":233},
    191:{"sun_stone":192},271:{"water_stone":272},274:{"leaf_stone":275},300:{"moon_stone":301},
    366:{"deep_sea_tooth":367,"deep_sea_scale":368},
}
static var _items: Dictionary = {}
static func all_items() -> Dictionary:
    if _items.is_empty():
        _items = ITEMS.duplicate(true)
        for key: String in PokedexExpansion.data()["evolution_items"]:
            if _items.has(key): continue
            var item: Dictionary = PokedexExpansion.data()["evolution_items"][key].duplicate()
            item["price"] = int(item["price"])
            item["stock"] = int(item["stock"])
            _items[key] = item
    return _items
static func target_for(key: String,pokemon: BattlePokemon,time := "day") -> int:
    if pokemon.content_version < 2: return target(key,pokemon.species_id)
    var rule := NationalEvolution.item_rule(key,pokemon,time)
    return int(rule.get("to",0))
static func target(key: String, species: int) -> int:
    var historical := int(ROUTES.get(species,{}).get(key,0))
    if historical > 0: return historical
    for rule: Dictionary in NationalEvolution.rules_for(species):
        if rule["item"] == key and not rule["prepare"]: return int(rule["to"])
    return 0
static func description(key: String) -> String:
    if key not in ITEMS and all_items().has(key): return "야영지에서 사용하는 진화 재료 · 1개 소비 · 분기와 조건은 포켓몬 연구에서 확인"
    if key in ["darkness_scroll","metal_candy"]: return "야영지에서 사용해 진화 · 1개 소비"
    return "야영지에서 사용해 진화 · 1개 소비" if key.ends_with("stone") else "통신 교환을 대신하는 진화 재료 · 야영지에서 1개 소비"
static func options(species: int,modern := false) -> Array[String]:
    var result: Array[String] = []
    for key: String in ROUTES.get(species,{}): result.append(key)
    if modern:
        for rule: Dictionary in NationalEvolution.rules_for(species):
            var key := str(rule["item"])
            if not key.is_empty() and key not in result: result.append(key)
    return result
static func merchant_offer(seed_value: int, step: int, party: Array[BattlePokemon]) -> String:
    var candidates: Array[String] = []
    for pokemon: BattlePokemon in party:
        # Stock materials for the current form and its ordinary level evolutions.
        var forms: Array[int] = [pokemon.species_id]
        for i in 3:
            for rule: Dictionary in TacticalGrowth.rules_for(forms.back()):
                forms.append(int(rule["to"]))
                break
        for species: int in forms:
            for key: String in options(species,pokemon.content_version >= 2):
                if key not in candidates: candidates.append(key)
    if candidates.is_empty(): candidates.assign((all_items() if party.any(func(p: BattlePokemon): return p.content_version >= 2) else ITEMS).keys().filter(func(key: String): return key not in ["darkness_scroll","metal_candy"]))
    candidates.sort()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ (step*15485863+32452843)
    return candidates[rng.randi_range(0,candidates.size()-1)]
