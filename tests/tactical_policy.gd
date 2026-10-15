class_name TacticalPolicy
extends RefCounted
## A legal, repeatable strategy used by model, UI and OS-input encounter tests.
static func action(b: TacticalBattle) -> Array:
    if b.phase == TacticalBattle.REPLACE:
        for p: BattlePokemon in b.party:
            if b.switch_reason(p.uid).is_empty(): return ["switch",p.uid]
    if b.turn == 1:
        if b.skill_reason("seed").is_empty(): return ["skill","seed"]
        for c: BattleCardInstance in b.hand:
            if c.key == "analysis" and not b.opening()["analyzed"]: return ["card",c.uid]
        return ["end"]
    var desired := 4 if b.enemy_index == 0 else 7
    if b.active().uid != desired and b.switch_reason(desired).is_empty(): return ["switch",desired]
    if b.active().uid == 4:
        for key: String in ["ember","flame"]:
            if b.skill_reason(key).is_empty(): return ["skill",key]
    else:
        for c: BattleCardInstance in b.hand:
            if c.key == "analysis" and not b.opening()["analyzed"] and not b.opening()["broken"] and b.card_reason(c.uid).is_empty() and b.energy >= 2:
                return ["card",c.uid]
        for key: String in ["water_gun","tackle"]:
            if b.skill_reason(key).is_empty(): return ["skill",key]
    return ["end"]
static func apply(b: TacticalBattle,step: Array) -> String:
    match step[0]:
        "skill": return b.use_skill(step[1])
        "card": return b.play_card(step[1])
        "switch": return b.switch_to(step[1])
        _: return b.end_turn()
