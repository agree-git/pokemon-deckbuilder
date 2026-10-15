class_name MerchantContent
extends RefCounted
## Quotes are generated once on arrival, independently of route/battle/reward RNG.
const DISCOUNT := 20

static func list_price(view: Dictionary, chapter: int) -> int:
    var base := 60
    if view.get("category","") == "technique": base = 70+(20 if int(view["cost"]) >= 2 else 0)
    elif view.has("power") or view.has("energy"): base = 90
    return base+5*clampi(chapter,0,8)

static func generate(run_seed: int, step: int, chapter: int, deck: Array[BattleCardInstance], party: Array[BattlePokemon], relics: Array[String]) -> Array[Dictionary]:
    var rng := RandomNumberGenerator.new()
    rng.seed = run_seed ^ (step*104729+32452843)
    var commons: Array = TacticalContent.CARDS.keys().filter(func(key: String): return key != "injury")
    var related := TacticalContent.synergy_cards(deck,relics)
    var first_pool: Array = related if not related.is_empty() else commons
    var first: String = first_pool[rng.randi_range(0,first_pool.size()-1)]
    var other: Array = commons.filter(func(key: String): return key != first and key not in related)
    if other.is_empty(): other = commons.filter(func(key: String): return key != first)
    var result: Array[Dictionary] = [
        {"kind":"card","key":first,"owner_uid":0,"upgraded":false},
        {"kind":"card","key":other[rng.randi_range(0,other.size()-1)],"owner_uid":0,"upgraded":false},
    ]
    var owner := party[rng.randi_range(0,party.size()-1)]
    var skills: Array = TacticalContent.skills_for(owner)
    var skill_key: String = skills[rng.randi_range(0,skills.size()-1)] if not skills.is_empty() else "move_165"
    result.append({"kind":"card","key":skill_key,"owner_uid":owner.uid,"upgraded":false})
    var sale := rng.randi_range(0,2)
    for i in result.size():
        var offer := result[i]
        var view := TacticalContent.definition(BattleCardInstance.new(0,offer["key"],offer["owner_uid"]))
        offer["full_price"] = list_price(view,chapter)
        offer["sale"] = i == sale
        offer["price"] = int(offer["full_price"])-(DISCOUNT if offer["sale"] else 0)
        offer["sold"] = false
    return result

static func valid_offers(value: Variant, chapter: int) -> bool:
    if not value is Array or value.size() != 3: return false
    var sales := 0
    var common_keys: Array[String] = []
    for i in value.size():
        var offer: Variant = value[i]
        if not offer is Dictionary or not offer.get("kind") is String or offer["kind"] != "card" or not offer.get("key") is String: return false
        if not offer.get("owner_uid") is int or offer["owner_uid"] < 0 or offer["owner_uid"] > 1000000: return false
        if not offer.get("upgraded") is bool or offer["upgraded"]: return false
        if not offer.get("sold") is bool or not offer.get("sale") is bool: return false
        if not offer.get("price") is int or not offer.get("full_price") is int: return false
        if i < 2:
            if offer["owner_uid"] != 0 or not TacticalContent.CARDS.has(offer["key"]) or offer["key"] == "injury" or offer["key"] in common_keys: return false
            common_keys.append(offer["key"])
        elif offer["owner_uid"] == 0: return false
        var view := TacticalContent.definition(BattleCardInstance.new(0,offer["key"],offer["owner_uid"]))
        if view.is_empty() or offer["full_price"] != list_price(view,chapter): return false
        if offer["price"] != offer["full_price"]-(DISCOUNT if offer["sale"] else 0): return false
        if offer["sale"]: sales += 1
    return sales == 1
