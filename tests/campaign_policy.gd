class_name CampaignPolicy
extends RefCounted
## A deterministic public-action player, with no HP/energy or victory mutations.
static func learn(j: TacticalJourney) -> int:
    var offer := j.pending_learning[0]
    var pokemon: BattlePokemon
    for member: BattlePokemon in j.party:
        if member.uid == int(offer["uid"]): pokemon = member
    var new_move := TacticalMoves.definition(offer["key"])
    var worst := 1000.0
    var slot := -1
    for i in pokemon.learned_skills.size():
        var rating := score(TacticalMoves.definition(pokemon.learned_skills[i]))
        if rating < worst:
            worst = rating
            slot = i
    return slot if score(new_move) > worst else -1
static func score(move: Dictionary) -> float:
    if move.has("seed"): return 25
    if move.has("damage"): return 10.0+float(move["damage"])/maxi(1,int(move["cost"]))+(2 if move.has("heal") else 0)
    if move.has("weaken"): return 9
    if move.has("strength"): return 8
    if move.has("block"): return 5
    return 0
static func action(j: TacticalJourney) -> Array:
    return TacticalPolicy.action(j.battle)
static func apply(j: TacticalJourney, action_value: Array) -> String:
    return j.use_item(action_value[1],action_value[2]) if action_value[0] == "item" else TacticalPolicy.apply(j.battle,action_value)
static func camp(j: TacticalJourney) -> void:
    j.rest()
    for i in j.party.size():
        for key: String in ["revive","super_potion","potion"]:
            if j.quantity(key) == 0 and j.party[i].hp < j.party[i].max_hp/2.0 and j.buy_reason(key).is_empty(): j.buy(key)
            if j.item_reason(key,i).is_empty(): j.use_item(key,i)
