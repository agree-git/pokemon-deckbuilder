class_name BuildConceptRules
extends RefCounted
## Optional concept effects. No runtime randomness and no scene dependencies.
static func condition(b: TacticalBattle,p: BattlePokemon,key: String) -> bool:
    match key:
        "relay": return bool(b.turn_flags.get("technique_switch",false))
        "ace": return bool(b.turn_flags.get("double_technique_%d" % p.uid,false))
        "status": return ["burn","poison","seed"].filter(func(k: String): return b.enemy().statuses.has(k)).size() >= 2
        "shield": return p.block > 0
        "cycle": return bool(b.turn_flags.get("reshuffled",false))
    return false
static func once(b: TacticalBattle,key: String) -> bool:
    if b.turn_flags.has(key): return false
    b.turn_flags[key] = true
    return true
static func shield(b: TacticalBattle,p: BattlePokemon,base: int,title: String) -> void:
    var amount := b._gain_block(p,PokemonStats.scale(p,base))
    if amount > 0: b._record("shield",title,{"target":p.uid,"amount":amount})
static func heal(b: TacticalBattle,p: BattlePokemon,base: int,title: String) -> void:
    if not p.alive(): return
    var amount := mini(p.max_hp-p.hp,PokemonStats.scale(p,base))
    p.hp += amount
    if amount > 0: b._record("heal",title,{"target":p.uid,"amount":amount})
static func relic(b: TacticalBattle,key: String,title: String) -> void:
    b._record("relic",title,{"relic_key":key})
static func apply(b: TacticalBattle,v: Dictionary,actor: BattlePokemon,target: BattlePokemon) -> void:
    if v.has("party_block"):
        for p: BattlePokemon in b.party:
            if p.alive(): shield(b,p,int(v["party_block"]),str(v["name"]))
    if v.has("team_bonus"):
        var amount := int(v["team_bonus"])*b.turn_actors.size()
        b.next_attack_bonus += amount
        if amount > 0: b._record("status","합동 지휘 · 다음 공격 추가 피해",{"target":actor.uid})
    if v.has("bank_energy"):
        b.powers["energy_bank"] = mini(512,int(b.powers.get("energy_bank",0))+int(v["bank_energy"]))
        b._record("power","다음 아군 턴 에너지 +%d 비축" % int(v["bank_energy"]))
    if v.has("extend_status"):
        var extended := false
        for key: String in ["burn","poison","seed"]:
            if target.alive() and target.statuses.has(key):
                target.statuses[key]["turns"] = mini(100,int(target.statuses[key]["turns"])+int(v["extend_status"]))
                extended = true
        if extended: b._record("status","지속 촉매 · 남은 횟수 연장",{"target":target.uid})
    if v.has("keep_block"):
        b.turn_flags["keep_block_%d" % actor.uid] = true
        b._record("status",actor.display_name+" · 다음 아군 턴 보호막 보존",{"target":actor.uid})
    if v.has("recover_tool") and b.hand.size() < 10:
        for i in range(b.exhausted.size()-1,-1,-1):
            if TacticalContent.definition(b.exhausted[i]).get("category","") != "tool": continue
            b.hand.append(b.exhausted.pop_at(i))
            b._record("cards_returned","소진 도구 1장 회수",{"amount":1})
            break
    if v.has("cycle_discard") and not b.hand.is_empty():
        var candidate := b.hand[0]
        for card: BattleCardInstance in b.hand:
            if int(b.card_view(card)["cost"]) < int(b.card_view(candidate)["cost"]): candidate = card
        b.hand.erase(candidate)
        b.retained.erase(candidate.uid)
        b.discard.append(candidate)
        b._record("cards_discarded","선별 정리 · 낮은 비용 1장 버리기",{"amount":1})
    if v.has("retain_all"):
        for card: BattleCardInstance in b.hand:
            if card.uid not in b.retained: b.retained.append(card.uid)
        b._record("status","남은 손패 전체 보존")
    if v.get("condition_active",false):
        if v.has("conditional_energy"):
            b.energy = mini(10000,b.energy+int(v["conditional_energy"]))
            b._record("power",str(v["name"])+" · 에너지 +%d" % int(v["conditional_energy"]))
        if v.has("conditional_bonus"):
            b.next_attack_bonus += int(v["conditional_bonus"])
            b._record("status",str(v["name"])+" · 조건부 추가 피해",{"target":actor.uid})
static func technique(b: TacticalBattle,p: BattlePokemon) -> void:
    var stacks := int(b.powers.get("ace_guard",0))
    if stacks > 0 and p.uid == b.turn_speed_owner_uid and not b.turn_flags.has("technique_%d" % p.uid): shield(b,p,5*stacks,"침착한 호흡")
static func after_card(b: TacticalBattle,v: Dictionary,p: BattlePokemon) -> void:
    if v["category"] == "technique" and b.turn_actors.size() >= 2 and b.has_relic("relay_signal") and once(b,"relay_signal"):
        b._draw(1)
        relic(b,"relay_signal","교차 신호기 · 카드 1장")
    if v["category"] != "tool" or not v.get("exhaust",false): return
    var stacks := int(b.powers.get("tool_bonus",0))
    if stacks > 0 and once(b,"tool_bonus"):
        b.next_attack_bonus += 4*stacks
        b._record("power","현장 조립 · 다음 공격 추가 피해")
    if b.has_relic("tool_pouch") and once(b,"tool_pouch"):
        heal(b,p,3,"구조 파우치")
        relic(b,"tool_pouch","구조 파우치 · 소진 도구 회복")
static func after_switch(b: TacticalBattle,technique_switch: bool) -> void:
    var stacks := int(b.powers.get("relay_cycle",0))
    if technique_switch and stacks > 0 and once(b,"relay_cycle"):
        b._draw(stacks)
        b._record("power","순환 작전 · 카드 %d장" % stacks)
static func end_turn(b: TacticalBattle) -> void:
    var stacks := int(b.powers.get("bulwark",0))
    if stacks > 0 and b.active().alive(): shield(b,b.active(),6*stacks,"요새 작전")
    if b.has_relic("cycle_bookmark") and b.hand.any(func(c: BattleCardInstance): return c.uid in b.retained): b.turn_flags["cycle_bookmark"] = true
static func start_turn(b: TacticalBattle,previous: Dictionary,stayed: bool) -> void:
    var banked := int(b.powers.get("energy_bank",0))
    b.powers.erase("energy_bank")
    if banked > 0:
        b.energy = mini(10000,b.energy+banked)
        b._record("power","비축 에너지 +%d" % banked)
    if previous.get("cycle_bookmark",false) and b.has_relic("cycle_bookmark"):
        b.energy = mini(10000,b.energy+1)
        relic(b,"cycle_bookmark","보존 책갈피 · 에너지 +1")
    if previous.get("shield_badge",false) and b.has_relic("shield_badge"):
        b._draw(1)
        relic(b,"shield_badge","보루 휘장 · 카드 1장")
    if stayed and b.has_relic("ace_calm"):
        b._draw(1)
        relic(b,"ace_calm","고요한 메달 · 카드 1장")
static func reshuffle(b: TacticalBattle) -> void:
    b.turn_flags["reshuffled"] = true
    var stacks := int(b.powers.get("cycle_energy",0))
    if stacks > 0 and once(b,"cycle_energy"):
        b.energy = mini(10000,b.energy+stacks)
        b._record("power","재순환 엔진 · 에너지 +%d" % stacks)
    if b.has_relic("cycle_spring") and once(b,"cycle_spring"):
        shield(b,b.active(),4,"되감기 태엽")
        relic(b,"cycle_spring","되감기 태엽 · 첫 재섞기")
static func status_hit(b: TacticalBattle,p: BattlePokemon,key: String,lost: int) -> void:
    if p.uid >= 0 or key not in ["burn","poison","seed"] or lost <= 0: return
    var stacks := int(b.powers.get("toxin_heal",0))
    if stacks > 0 and once(b,"toxin_heal"): heal(b,b.active(),2*stacks,"흡수 작전")
    if b.has_relic("status_ember") and once(b,"status_ember"):
        b.next_attack_bonus += 3
        relic(b,"status_ember","잔열 결정 · 다음 공격 추가 피해")
static func expired(b: TacticalBattle,p: BattlePokemon,key: String) -> void:
    if p.uid < 0 and key in ["burn","poison","seed"] and b.has_relic("status_vial") and once(b,"status_vial"):
        b._draw(1)
        relic(b,"status_vial","봉인 유리병 · 카드 1장")
static func full_guard(b: TacticalBattle,p: BattlePokemon,blocked: int,lost: int) -> void:
    if b.phase == "enemy" and p.uid > 0 and blocked > 0 and lost == 0 and b.has_relic("shield_badge") and once(b,"shield_badge"):
        b._record("status","보루 휘장 충전 · 다음 아군 턴 카드 +1",{"target":p.uid})
static func sight_active(b: TacticalBattle,v: Dictionary,p: BattlePokemon) -> bool:
    return v.get("category","technique") == "technique" and v.has("damage") and p.uid == b.turn_speed_owner_uid and b.has_relic("ace_sight") and not b.turn_flags.has("ace_sight")
