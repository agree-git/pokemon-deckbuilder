class_name JourneyPolicy
extends RefCounted
## Public actions only; a general grass/fire/water policy, without HP mutations.
static func action(b: TacticalBattle) -> Array:
    var preferred := b.active().uid
    var desired_type: String = {"grass":"fire","fire":"water","water":"grass"}.get(b.enemy().type,"fire")
    var best_score := -1.0
    for pokemon: BattlePokemon in b.party:
        if not pokemon.alive(): continue
        var score := (20.0 if pokemon.type == desired_type else 0.0)+float(pokemon.hp)/pokemon.max_hp
        if score > best_score:
            best_score = score
            preferred = pokemon.uid
    if b.phase == TacticalBattle.REPLACE:
        if b.member(preferred).alive(): return ["switch",preferred]
        for p: BattlePokemon in b.party:
            if b.switch_reason(p.uid).is_empty(): return ["switch",p.uid]
    if b.active().uid != preferred and b.switch_reason(preferred).is_empty(): return ["switch",preferred]
    for card: BattleCardInstance in b.hand:
        if card.key == "focus" and b.hand.size() < 9: return ["card",card.uid]
        if not b.card_reason(card.uid).is_empty(): continue
        if card.key == "counter" and b.intent()["kind"] == "charge" and not b.opening()["broken"] and "counter" not in b.opening()["sources"]: return ["card",card.uid]
        if card.key == "analysis" and b.energy >= 2 and not b.opening()["broken"] and not b.opening()["analyzed"] and "analysis" not in b.opening()["sources"]: return ["card",card.uid]
    var learned := TacticalContent.skills_for(b.active())
    for key: String in learned:
        if not b.skill_reason(key).is_empty(): continue
        var view := TacticalMoves.definition(key)
        if view.has("seed") and not b.enemy().statuses.has("seed"): return ["skill",key]
        if view.has("weaken") and b.enemy().strength > -2 and b.energy >= 2: return ["skill",key]
        if view.has("expose") and not b.enemy().statuses.has("exposed") and b.energy >= 2: return ["skill",key]
        if view.has("sleep") and not b.enemy().statuses.has("sleep") and b.intent()["kind"] == "charge": return ["skill",key]
        if view.has("strength") and b.active().strength < 2 and b.energy >= 2: return ["skill",key]
    var ordered: Array = learned.filter(func(key: String): return TacticalMoves.definition(key).has("damage"))
    ordered.sort_custom(func(a: String,c: String): return float(b.skill_view(a)["preview_damage"])/TacticalMoves.definition(a)["cost"] > float(b.skill_view(c)["preview_damage"])/TacticalMoves.definition(c)["cost"])
    for key: String in ordered:
        if b.skill_reason(key).is_empty(): return ["skill",key]
    for card: BattleCardInstance in b.hand:
        if card.key in ["guard","counter"] and b.active().block < int(b.intent().get("value",0)) and b.card_reason(card.uid).is_empty(): return ["card",card.uid]
    for key: String in learned:
        var view := TacticalMoves.definition(key)
        if view.has("block") and b.active().block < int(b.intent().get("value",0)) and b.skill_reason(key).is_empty(): return ["skill",key]
    return ["end"]
