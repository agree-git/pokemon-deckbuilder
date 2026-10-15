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
    var b := j.battle
    if b.phase == TacticalBattle.REPLACE: return JourneyPolicy.action(b)
    var best := -1000.0
    var preferred := b.active().uid
    for p: BattlePokemon in b.party:
        if not p.alive(): continue
        var damage := 0.0
        for key: String in TacticalContent.skills_for(p):
            var view := TacticalMoves.definition(key)
            if view.has("damage"):
                damage = maxf(damage,(int(view["damage"])+TacticalGrowth.attack_bonus(p)+p.strength)*b.multiplier(view["type"],b.enemy())/maxi(1,int(view["cost"])))
        var value := damage+float(p.hp)/p.max_hp*4.0
        if value > best:
            best = value
            preferred = p.uid
    if preferred != b.active().uid and b.switch_reason(preferred).is_empty(): return ["switch",preferred]
    var dangerous := int(b.intent().get("value",0)) >= b.active().hp
    if dangerous:
        for key: String in ["super_potion","potion"]:
            if j.item_reason(key,b.active_index).is_empty(): return ["item",key,b.active_index]
    # JourneyPolicy handles setup, break sources, efficient attacks, and guard.
    # Retain its choice only when it doesn't undo our matchup selection.
    var choice := JourneyPolicy.action(b)
    if choice[0] != "switch": return choice
    var skills: Array = TacticalContent.skills_for(b.active()).filter(func(key: String): return TacticalMoves.definition(key).has("damage"))
    skills.sort_custom(func(a: String,c: String): return b.skill_view(a)["preview_damage"] > b.skill_view(c)["preview_damage"])
    for key: String in skills:
        if b.skill_reason(key).is_empty(): return ["skill",key]
    return ["end"]
static func apply(j: TacticalJourney, action_value: Array) -> String:
    return j.use_item(action_value[1],action_value[2]) if action_value[0] == "item" else TacticalPolicy.apply(j.battle,action_value)
static func camp(j: TacticalJourney) -> void:
    j.rest()
    for i in j.party.size():
        for key: String in ["revive","super_potion","potion"]:
            if j.quantity(key) == 0 and j.party[i].hp < j.party[i].max_hp/2.0 and j.buy_reason(key).is_empty(): j.buy(key)
            if j.item_reason(key,i).is_empty(): j.use_item(key,i)
