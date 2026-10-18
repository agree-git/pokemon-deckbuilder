extends RefCounted
## Public card actions only, shared by model and real-input regression probes.
static func incoming(a: Dictionary) -> int:
    if a.get("asleep",false): return 0
    return int(a.get("value",0)) if a["kind"] in ["attack","charge","barrage"] or (a["kind"] == "move" and a.get("damage_class") != "status") else 0
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
        if BossBattleEffects.active_in(b):view=BossBattleEffects.filter_view(b,view)
        var actor := b.member(card.owner_uid) if card.owner_uid != 0 else b.active()
        var cost := maxi(1,int(view["cost"]))
        var value := 0.0
        if actor!=b.active() and BossBattleEffects.active_in(b):value-=BossBattleEffects.entry_damage(b,actor)*1.5
        var damage := int(view.get("preview_damage",0))
        var pressure := incoming(b.intent())
        if actor != b.active():
            var action := b.intent_for(actor)
            pressure = incoming(action)
        if view.has("damage"):
            value += mini(damage,b.enemy().hp+b.enemy().block)*1.3
            if damage >= b.enemy().hp+b.enemy().block: value += 40
            if actor.hp+actor.block <= pressure and damage < b.enemy().hp+b.enemy().block: value -= 2.0*pressure
        if view.has("block"):
            value += mini(int(view.get("preview_block",view["block"])),maxi(0,pressure-actor.block))*1.1
            if pressure >= actor.hp+actor.block: value += 12
        if view.has("weaken"): value += mini(int(view["weaken"]),maxi(0,b.enemy().strength+6))*2.5
        if view.has("expose") and not b.enemy().statuses.has("exposed"): value += 6
        for status: String in ["burn","seed","poison","sleep","paralysis"]:
            if view.has(status) and not b.enemy().statuses.has(status):
                value += mini(b.enemy().hp,PokemonStats.scale(b.enemy(),2)*int(view[status])) if status in ["seed","burn","poison"] else (pressure*0.9 if status == "sleep" else 6)
        if view.has("stat_changes"):
            var recipient := actor if view["stat_target"] == "self" else b.enemy()
            for stat: String in view["stat_changes"]:
                var stage := int(recipient.stat_stages.get(stat,0))
                var change := int(view["stat_changes"][stat])
                if abs(stage) < 4:
                    if view["stat_target"] == "enemy" and change < 0:
                        value += pressure*0.25 if stat == ("special_attack" if b.intent().get("damage_class") == "special" else "attack") else 3
                    elif view["stat_target"] == "self" and change > 0: value += 5*change
        if view.has("heal"): value += mini(int(view.get("preview_heal",view["heal"])),actor.max_hp-actor.hp)*0.9
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
    if uid != 0: return ["card",uid]
    # End with a safe defender when the drawn hand cannot finish the enemy.
    var current := b.intent()
    if incoming(current) > 0:
        var risk := maxf(0,int(current["value"])-b.active().block)/maxf(1,b.active().hp)
        var defender := 0
        for candidate: BattlePokemon in b.party:
            if not b.switch_reason(candidate.uid).is_empty(): continue
            var entry:=BossBattleEffects.entry_damage(b,candidate) if BossBattleEffects.active_in(b) else 0
            if entry>=candidate.hp:continue
            var candidate_risk := (entry+maxf(0,int(b.intent_for(candidate)["value"])-candidate.block))/maxf(1,candidate.hp-entry)
            if candidate_risk < risk*0.6:
                risk = candidate_risk
                defender = candidate.uid
        if defender != 0: return ["switch",defender]
    return ["end"]
static func apply(b: TacticalBattle,step: Array) -> String:
    match step[0]:
        "skill": return b.use_skill(step[1])
        "card": return b.play_card(step[1])
        "switch": return b.switch_to(step[1])
        _: return b.end_turn()
