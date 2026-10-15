class_name JourneyPolicy
extends RefCounted
## Public actions only; a general grass/fire/water policy, without HP mutations.
static func action(b: TacticalBattle) -> Array:
    var preferred: int = {"grass":4,"fire":7,"water":1}.get(b.enemy().type,4)
    if b.phase == TacticalBattle.REPLACE:
        if b.member(preferred).alive(): return ["switch",preferred]
        for p: BattlePokemon in b.party:
            if b.switch_reason(p.uid).is_empty(): return ["switch",p.uid]
    if b.turn == 1 and b.active().uid == 1:
        if b.skill_reason("seed").is_empty(): return ["skill","seed"]
        for card: BattleCardInstance in b.hand:
            if card.key == "analysis" and not b.opening()["analyzed"] and b.card_reason(card.uid).is_empty(): return ["card",card.uid]
        return ["end"]
    if b.active().uid != preferred and b.switch_reason(preferred).is_empty(): return ["switch",preferred]
    for card: BattleCardInstance in b.hand:
        if card.key == "focus" and b.hand.size() < 9: return ["card",card.uid]
        if not b.card_reason(card.uid).is_empty(): continue
        if card.key == "counter" and b.intent()["kind"] == "charge" and not b.opening()["broken"] and "counter" not in b.opening()["sources"]: return ["card",card.uid]
        if card.key == "analysis" and b.energy >= 2 and not b.opening()["broken"] and not b.opening()["analyzed"] and "analysis" not in b.opening()["sources"]: return ["card",card.uid]
    var ordered: Array = {4:["ember","flame"],7:["water_gun","tackle"],1:["growth","vine","seed"]}[b.active().uid]
    for key: String in ordered:
        if key == "seed" and b.enemy().statuses.has("seed"): continue
        if b.skill_reason(key).is_empty(): return ["skill",key]
    for card: BattleCardInstance in b.hand:
        if card.key in ["guard","counter"] and b.active().block < int(b.intent().get("value",0)) and b.card_reason(card.uid).is_empty(): return ["card",card.uid]
    for key: String in ["fire_guard","shell"]:
        if b.skill_reason(key).is_empty(): return ["skill",key]
    return ["end"]
