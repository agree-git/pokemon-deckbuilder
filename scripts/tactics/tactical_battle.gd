class_name TacticalBattle
extends RefCounted
## Fixed skills + shared trainer deck. All state changes are independent of UI/VFX.
const PLAYER := "player"
const REPLACE := "replace"
const WON := "won"
const LOST := "lost"
const REFUND_LIMIT := 2
var party: Array[BattlePokemon] = []
var enemies: Array[BattlePokemon] = []
var enemy_definitions: Array = []
var enemy_states: Array[Dictionary] = []
var active_index := 1
var enemy_index := 0
var phase := PLAYER
var energy := 3
var turn := 1
var switched := false
var used_skills: Dictionary = {}
var hand: Array[BattleCardInstance] = []
var draw_pile: Array[BattleCardInstance] = []
var discard: Array[BattleCardInstance] = []
var exhausted: Array[BattleCardInstance] = []
var events: Array[Dictionary] = []
var history: Array[String] = []
var seed_value := 2026
var relic := "seed_relay"
var refunds := 0
var next_attack_bonus := 0
var switch_bonus: Dictionary = {}
var free_card := false
var _next_uid := 1
var _rng := RandomNumberGenerator.new()
var _pending := ""
var _direct := false
var _relay: Dictionary = {}

func _init(battle_seed: int = 2026, selected_relic: String = "seed_relay", opponents: Array = TacticalContent.ENEMIES) -> void:
    restart(battle_seed,selected_relic,opponents)

func restart(battle_seed: int = 2026, selected_relic: String = "seed_relay", opponents: Array = TacticalContent.ENEMIES) -> void:
    seed_value = battle_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "seed_relay"
    _rng.seed = seed_value
    party.clear()
    enemies.clear()
    enemy_states.clear()
    enemy_definitions = opponents.duplicate(true)
    for definition: Dictionary in TacticalContent.PARTY:
        party.append(BattlePokemon.new(definition,int(definition["uid"])))
    for i in enemy_definitions.size():
        enemies.append(BattlePokemon.new(enemy_definitions[i],-i-1))
        enemy_states.append({"points":0,"sources":[],"broken":false,"burst":false,"cancel":false,"analyzed":false,"intent":0})
    active_index = 1
    enemy_index = 0
    phase = PLAYER
    energy = 3
    turn = 1
    switched = false
    refunds = 0
    used_skills.clear()
    switch_bonus.clear()
    next_attack_bonus = 0
    free_card = false
    hand.clear()
    draw_pile.clear()
    discard.clear()
    exhausted.clear()
    events.clear()
    history.clear()
    _relay.clear()
    _pending = ""
    _direct = false
    _next_uid = 1
    for key: String in TacticalContent.DECK:
        draw_pile.append(_new_card(key))
    _shuffle(draw_pile)
    _draw(5)
    # Keep the tutorial's opening analysis available without fixing all five cards.
    if not hand.any(func(card: BattleCardInstance): return card.key == "analysis"):
        for card: BattleCardInstance in draw_pile:
            if card.key == "analysis":
                draw_pile.erase(card)
                draw_pile.push_front(hand.pop_back())
                hand.append(card)
                break
    _record("turn","턴 1 · 에너지 3")

func active() -> BattlePokemon:
    return party[active_index]
func enemy() -> BattlePokemon:
    return enemies[enemy_index]
func opening() -> Dictionary:
    return enemy_states[enemy_index]
func intent() -> Dictionary:
    var definitions: Array = enemy_definitions[enemy_index]["intents"]
    var result: Dictionary = definitions[int(opening()["intent"]) % definitions.size()].duplicate(true)
    if result["kind"] in ["attack","charge"]:
        result["value"] = int(floor((int(result["value"])+enemy().strength)*BattleContent.multiplier(result.get("type","normal"),active().type)))
    return result
func skill_view(key: String) -> Dictionary:
    var view: Dictionary = BattleContent.CARDS[key].duplicate(true)
    if view.has("damage"):
        var base := int(view["damage"])+active().strength+next_attack_bonus+int(switch_bonus.get(active().uid,0))
        view["preview_damage"] = int(floor(base*BattleContent.multiplier(view["type"],enemy().type))) * (2 if opening()["burst"] else 1)
    return view
func skill_reason(key: String) -> String:
    if phase != PLAYER:
        return "살아 있는 아군을 선택하세요." if phase == REPLACE else "전투가 끝났습니다."
    if key not in TacticalContent.SKILLS[active().species_id]:
        return "현재 포켓몬이 사용할 수 없는 기술입니다."
    if used_skills.has("%d:%s" % [active().uid,key]):
        return "이 기술은 이번 턴에 사용했습니다."
    if energy < int(BattleContent.CARDS[key]["cost"]):
        return "에너지가 부족합니다."
    return ""

func use_skill(key: String) -> String:
    var reason := skill_reason(key)
    if not reason.is_empty():
        return reason
    events.clear()
    var definition: Dictionary = BattleContent.CARDS[key]
    var actor := active()
    var target := enemy()
    var state := opening()
    var burst: bool = state["burst"] and definition.has("damage")
    energy -= int(definition["cost"])
    used_skills["%d:%s" % [actor.uid,key]] = true
    _record("skill","%s · %s" % [actor.display_name,definition["name"]],{"move_id":definition["move_id"],"actor":actor.uid})
    if definition.has("damage"):
        if burst:
            state["burst"] = false
        var multiplier := BattleContent.multiplier(definition["type"],target.type)
        if multiplier > 1:
            _opening("weakness","약점 공격")
        if state["analyzed"]:
            state["analyzed"] = false
            _opening("analysis","분석한 빈틈")
        var base := int(definition["damage"])+actor.strength+next_attack_bonus+int(switch_bonus.get(actor.uid,0))
        next_attack_bonus = 0
        switch_bonus.erase(actor.uid)
        _direct = true
        _damage(target,int(floor(base*multiplier))*(2 if burst else 1))
        _direct = false
    if target.alive():
        for key_name: String in ["burn","seed"]:
            if definition.has(key_name):
                var fresh := not target.statuses.has(key_name)
                target.statuses[key_name] = {"turns":int(definition[key_name]),"source_uid":actor.uid}
                if fresh:
                    _opening("status","상태 활용")
    if definition.has("heal"):
        actor.hp = mini(actor.max_hp,actor.hp+int(definition["heal"]))
    if definition.has("block"):
        actor.block += int(definition["block"])
    if definition.has("strength"):
        actor.strength += int(definition["strength"])
    _outcome()
    return ""

func card_view(card: BattleCardInstance) -> Dictionary:
    var view: Dictionary = TacticalContent.CARDS[card.key].duplicate(true)
    view["uid"] = card.uid
    view["key"] = card.key
    view["cost"] = 0 if free_card and card.key != "injury" and int(view["cost"]) > 0 else view["cost"]
    return view
func card_reason(uid: int) -> String:
    if phase != PLAYER:
        return "현재 카드를 사용할 수 없습니다."
    var card := _hand(uid)
    if card == null:
        return "손패에 없는 카드입니다."
    if energy < int(card_view(card)["cost"]):
        return "에너지가 부족합니다."
    return ""
func play_card(uid: int) -> String:
    var reason := card_reason(uid)
    if not reason.is_empty():
        return reason
    events.clear()
    var card := _hand(uid)
    var view := card_view(card)
    hand.erase(card)
    energy -= int(view["cost"])
    if free_card and card.key != "injury" and int(TacticalContent.CARDS[card.key]["cost"]) > 0:
        free_card = false
    _record("card",view["name"],{"move_id":view["move_id"]})
    match card.key:
        "analysis": opening()["analyzed"] = true
        "guard": active().block += 6
        "focus": _draw(2)
        "rally": next_attack_bonus = 4
        "counter":
            if intent()["kind"] == "charge":
                _opening("counter","강공격 견제")
            else:
                active().block += 4
    if card.key == "focus":
        exhausted.append(card)
    else:
        discard.append(card)
    return ""

func _opening(source: String, caption: String) -> void:
    var state := opening()
    if state["broken"] or source in state["sources"]:
        return
    state["sources"].append(source)
    state["points"] = mini(3,int(state["points"])+1)
    _record("opening","%s · 빈틈 %d/3" % [caption,state["points"]])
    if state["points"] == 3:
        state["broken"] = true
        state["burst"] = true
        state["cancel"] = true
        _record("break","BREAK! 행동 취소 · 다음 공격 기술 ×2")
        _refund("break")
        if relic == "break_focus":
            _draw(1)
            free_card = true

func _refund(reason: String) -> void:
    if refunds >= REFUND_LIMIT:
        return
    refunds += 1
    energy += 1
    if reason == "finish":
        _draw(1)
    _record("refund","에너지 +1%s · 환급 %d/%d" % [" / 드로우 1" if reason == "finish" else "",refunds,REFUND_LIMIT],{"reason":reason})
func switch_reason(uid: int) -> String:
    if phase not in [PLAYER,REPLACE]:
        return "전투가 끝났습니다."
    var pokemon := member(uid)
    if pokemon == null or not pokemon.alive() or pokemon == active():
        return "살아 있는 대기 포켓몬을 선택하세요."
    if phase == PLAYER and switched and energy < 1:
        return "추가 교체에는 에너지 1이 필요합니다."
    return ""
func switch_to(uid: int) -> String:
    var reason := switch_reason(uid)
    if not reason.is_empty():
        return reason
    events.clear()
    var forced := phase == REPLACE
    if not forced:
        if switched:
            energy -= 1
        switched = true
        if relic == "switch_power":
            switch_bonus[uid] = 3
    for i in party.size():
        if party[i].uid == uid:
            active_index = i
    _record("switch",active().display_name+" 출전")
    if forced:
        if _pending == "enemy":
            _enemy_action()
        else:
            _start_player()
    return ""
func end_turn() -> String:
    if phase != PLAYER:
        return "현재 턴을 종료할 수 없습니다."
    events.clear()
    discard.append_array(hand)
    hand.clear()
    phase = "enemy"
    for pokemon: BattlePokemon in party:
        _tick(pokemon)
        if _outcome():
            return ""
    if not active().alive():
        phase = REPLACE
        _pending = "enemy"
    else:
        _enemy_action()
    return ""
func _enemy_action() -> void:
    _pending = ""
    enemy().block = 0
    var state := opening()
    var action := intent()
    if state["cancel"]:
        state["cancel"] = false
        _record("cancel",enemy().display_name+"의 행동이 브레이크로 취소되었습니다.")
    else:
        _record("enemy_action",enemy().display_name+" · "+str(action["kind"]),action)
        match action["kind"]:
            "attack","charge": _damage(active(),int(action["value"]))
            "block": enemy().block = int(action["value"])
            "boost": enemy().strength += int(action["value"])
    state["intent"] = int(state["intent"])+1
    if _outcome():
        return
    _tick(enemy())
    if _outcome():
        return
    if not active().alive():
        phase = REPLACE
        _pending = "player"
    else:
        _start_player()
func _start_player() -> void:
    phase = PLAYER
    _pending = ""
    turn += 1
    energy = 3
    switched = false
    refunds = 0
    used_skills.clear()
    switch_bonus.clear()
    for pokemon: BattlePokemon in party:
        pokemon.block = 0
    _draw(5)
    _record("turn","턴 %d · 에너지 3" % turn)
func _tick(pokemon: BattlePokemon) -> void:
    for key: String in ["burn","seed"]:
        if not pokemon.alive() or not pokemon.statuses.has(key):
            continue
        var status: Dictionary = pokemon.statuses[key]
        # Consume the tick before damage so a lethal tick relays only remaining ticks.
        status["turns"] = int(status["turns"])-1
        if int(status["turns"]) <= 0:
            pokemon.statuses.erase(key)
        _damage(pokemon,2,true)
        if key == "seed":
            var owner := member(int(status["source_uid"]))
            if owner != null and owner.alive():
                owner.hp = mini(owner.max_hp,owner.hp+2)
func _damage(target: BattlePokemon, amount: int, piercing: bool = false) -> void:
    var blocked := 0 if piercing else mini(target.block,amount)
    target.block -= blocked
    var lost := mini(target.hp,maxi(0,amount-blocked))
    target.hp -= lost
    _record("damage","%s · 피해 %d" % [target.display_name,lost],{"target":target.uid,"amount":lost})
    if target.alive() or target.knocked_out:
        return
    target.knocked_out = true
    if target.uid < 0:
        if relic == "seed_relay" and target.statuses.has("seed"):
            _relay = target.statuses["seed"].duplicate(true)
        if _direct and opening()["broken"]:
            _record("chain","브레이크 격파! 다음 적에게 연계")
            _refund("finish")
    else:
        discard.append(_new_card("injury"))
    target.statuses.clear()
    _record("knockout",target.display_name+" 기절")
func _outcome() -> bool:
    if phase in [WON,LOST]:
        return true
    if not party.any(func(p: BattlePokemon): return p.alive()):
        phase = LOST
        _clear_statuses()
        _record("outcome","전투 패배")
        return true
    if not enemy().alive():
        if enemy_index+1 < enemies.size():
            enemy_index += 1
            if not _relay.is_empty():
                enemy().statuses["seed"] = _relay.duplicate(true)
                _relay.clear()
                _record("relay","씨앗이 "+enemy().display_name+"에게 전이되었습니다.")
                _opening("status","전이된 씨앗")
            _record("enemy_switch",enemy().display_name+" 출전 · 턴과 남은 자원 유지")
        else:
            phase = WON
            _clear_statuses()
            _record("outcome","적 파티 전원 격파 · 전투 승리")
            return true
    return false
func _clear_statuses() -> void:
    _relay.clear()
    for pokemon: BattlePokemon in party+enemies:
        pokemon.statuses.clear()
func member(uid: int) -> BattlePokemon:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid:
            return pokemon
    return null
func _hand(uid: int) -> BattleCardInstance:
    for card: BattleCardInstance in hand:
        if card.uid == uid:
            return card
    return null
func _new_card(key: String) -> BattleCardInstance:
    var card := BattleCardInstance.new(_next_uid,key,0)
    _next_uid += 1
    return card
func _draw(count: int) -> void:
    for i in count:
        if hand.size() >= 10:
            break
        if draw_pile.is_empty():
            draw_pile.append_array(discard)
            discard.clear()
            _shuffle(draw_pile)
        if draw_pile.is_empty():
            break
        hand.append(draw_pile.pop_back())
func _shuffle(cards: Array[BattleCardInstance]) -> void:
    for i in range(cards.size()-1,0,-1):
        var j := _rng.randi_range(0,i)
        var card := cards[i]
        cards[i] = cards[j]
        cards[j] = card
func _record(kind: String, caption: String, data: Dictionary = {}) -> void:
    var event := data.duplicate(true)
    event["kind"] = kind
    event["text"] = caption
    events.append(event)
    history.append(caption)
    if history.size() > 160:
        history.pop_front()
func snapshot() -> Dictionary:
    var piles: Array = []
    for cards: Array in [hand,draw_pile,discard,exhausted]:
        piles.append(cards.map(func(card: BattleCardInstance): return [card.uid,card.key]))
    return {"phase":phase,"energy":energy,"turn":turn,"active":active_index,"enemy":enemy_index,
        "party":party.map(func(p: BattlePokemon): return p.snapshot()),"enemies":enemies.map(func(p: BattlePokemon): return p.snapshot()),
        "openings":enemy_states.duplicate(true),"definitions":enemy_definitions.duplicate(true),"used":used_skills.duplicate(),
        "switched":switched,"refunds":refunds,"bonus":next_attack_bonus,"switch_bonus":switch_bonus.duplicate(),"free":free_card,
        "pending":_pending,"relay":_relay.duplicate(true),"rng":_rng.state,"next_uid":_next_uid,"piles":piles,
        "seed":seed_value,"relic":relic,"events":events.duplicate(true),"history":history.duplicate()}
