class_name TacticalPolicy
extends RefCounted
## Public card actions only, shared by model and real-input regression probes.
static func action(b: TacticalBattle) -> Array:
    if b.phase == TacticalBattle.REPLACE:
        var best: BattlePokemon
        for p: BattlePokemon in b.party:
            if p.alive() and (best == null or p.hp > best.hp): best = p
        return ["switch",best.uid]
    var best_score := 0.0
    var uid := 0
    for card: BattleCardInstance in b.hand:
        if not b.card_reason(card.uid).is_empty(): continue
        var view := b.card_view(card)
        var actor := b.member(card.owner_uid) if card.owner_uid != 0 else b.active()
        var cost := maxi(1,int(view["cost"]))
        var value := 0.0
        var damage := int(view.get("preview_damage",0))
        var incoming := int(b.intent().get("value",0)) if b.intent()["kind"] in ["attack","charge"] else 0
        if actor != b.active():
            var definition: Dictionary = b.enemy_definitions[b.enemy_index]["intents"][int(b.opening()["intent"])%b.enemy_definitions[b.enemy_index]["intents"].size()]
            incoming = int((int(definition.get("value",0))+b.enemy().strength)*b.multiplier(definition.get("type","normal"),actor)) if definition["kind"] in ["attack","charge"] else 0
        if view.has("damage"):
            value += mini(damage,b.enemy().hp+b.enemy().block)*1.3
            if damage >= b.enemy().hp+b.enemy().block: value += 40
            if actor.hp+actor.block <= incoming and damage < b.enemy().hp+b.enemy().block: value -= 12
        if view.has("block"):
            value += mini(int(view.get("preview_block",view["block"])),maxi(0,incoming-actor.block))*1.1
            if incoming >= actor.hp+actor.block: value += 12
        if view.has("weaken"): value += mini(int(view["weaken"]),maxi(0,b.enemy().strength+6))*2.5
        if view.has("expose") and not b.enemy().statuses.has("exposed"): value += 6
        for status: String in ["burn","seed","poison","sleep","paralysis"]:
            if view.has(status) and not b.enemy().statuses.has(status): value += 12 if status == "seed" else 6
        if view.has("heal"): value += mini(int(view["heal"]),actor.max_hp-actor.hp)*0.9
        if view.has("strength") and actor.strength < 8: value += int(view["strength"])*3
        if view.has("temporary_strength") and b.energy >= 1: value += 9
        if view.has("draw") and b.hand.size() <= 7: value += int(view["draw"])*9
        if view.has("energy"): value += int(view["energy"])*8
        if view.has("bonus") and b.energy >= 2 and b.hand.any(func(c: BattleCardInstance): return b.card_view(c).has("damage")): value += int(view["bonus"])*2
        if view.has("power") and b.turn < 5 and (b.enemies.size()-b.enemy_index > 1 or b.enemy().hp > 45): value += 10
        if view.has("retrieve") and b.energy >= 2 and b.discard.any(func(c: BattleCardInstance): return c.owner_uid != 0): value += 4
        if view.has("retain") and b.hand.size() > 1: value += 1
        if view.has("cash"):
            for key: String in ["burn","seed","poison"]: value += int(b.enemy().statuses.get(key,{}).get("turns",0))*4.0
        value /= cost
        if value > best_score:
            best_score = value
            uid = card.uid
    return ["card",uid] if uid != 0 else ["end"]
static func apply(b: TacticalBattle,step: Array) -> String:
    match step[0]:
        "skill": return b.use_skill(step[1])
        "card": return b.play_card(step[1])
        "switch": return b.switch_to(step[1])
        _: return b.end_turn()
