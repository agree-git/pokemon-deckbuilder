class_name BattleState
extends RefCounted
## Pure deterministic battle rules. No nodes, animation timers, or UI callbacks.

const PLAYER := "player"
const ENEMY := "enemy"
const REPLACE := "replace"
const WON := "won"
const LOST := "lost"

var party: Array[BattlePokemon] = []
var enemy: BattlePokemon
var active_index := 0
var hand: Array[BattleCardInstance] = []
var draw_pile: Array[BattleCardInstance] = []
var discard: Array[BattleCardInstance] = []
var removed: Array[BattleCardInstance] = []
var injuries: Array[int] = []
var energy := 3
var turn := 1
var switched := false
var phase := PLAYER
var seed_value: int
var events: Array[Dictionary] = []
var history: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _next_card_uid := 1
var _intent_index := 0
var _pending := ""

func _init(battle_seed: int = 2026) -> void:
    restart(battle_seed)

func restart(battle_seed: int) -> void:
    seed_value = battle_seed
    _rng.seed = battle_seed
    party.clear()
    for definition: Dictionary in BattleContent.PARTY:
        party.append(BattlePokemon.new(definition, int(definition["uid"])))
    enemy = BattlePokemon.new(BattleContent.ENEMY, -1)
    active_index = 0
    hand.clear()
    draw_pile.clear()
    discard.clear()
    removed.clear()
    injuries.clear()
    events.clear()
    history.clear()
    _next_card_uid = 1
    _intent_index = 0
    _pending = ""
    energy = 3
    turn = 1
    switched = false
    phase = PLAYER
    for entry: Dictionary in BattleContent.DECK:
        for copy in int(entry["copies"]):
            draw_pile.append(_new_card(entry["key"], int(entry["owner"])))
    _shuffle(draw_pile)
    _draw(5)
    _record("turn", "턴 1 · 에너지 3", {"turn": 1})

func active() -> BattlePokemon:
    return party[active_index]

func intent() -> Dictionary:
    var next: Dictionary = BattleContent.INTENTS[_intent_index % BattleContent.INTENTS.size()].duplicate()
    if next["kind"] == "attack":
        next["value"] = int(next["value"]) + enemy.strength
    return next

func card_view(card: BattleCardInstance) -> Dictionary:
    var view: Dictionary = BattleContent.CARDS[card.key].duplicate(true)
    view["uid"] = card.uid
    view["key"] = card.key
    view["owner"] = card.owner_uid
    view["owner_name"] = "공용" if card.owner_uid == 0 else _ally(card.owner_uid).display_name
    view["art_id"] = active().species_id if card.owner_uid == 0 else _ally(card.owner_uid).species_id
    if view.has("damage"):
        view["preview_damage"] = int(floor((int(view["damage"]) + active().strength) * BattleContent.multiplier(view["type"], enemy.type)))
    return view

func card_reason(uid: int) -> String:
    if phase != PLAYER:
        return "먼저 살아 있는 아군을 선택하세요." if phase == REPLACE else "지금은 카드를 사용할 수 없습니다."
    var card := _find_hand(uid)
    if card == null:
        return "손패에 없는 카드입니다."
    if card.owner_uid != 0 and card.owner_uid != active().uid:
        return "%s로 교체해야 합니다." % _ally(card.owner_uid).display_name
    if energy < int(BattleContent.CARDS[card.key]["cost"]):
        return "에너지가 부족합니다."
    return ""

func play_card(uid: int) -> String:
    var reason := card_reason(uid)
    if not reason.is_empty():
        return reason
    events.clear()
    var card := _find_hand(uid)
    var definition: Dictionary = BattleContent.CARDS[card.key]
    var actor := active()
    energy -= int(definition["cost"])
    hand.erase(card) # Resolving card is not eligible for its own draw/reshuffle.
    _record("card", "%s · %s" % [actor.display_name, definition["name"]], {"card_uid": uid, "move_id": definition["move_id"]})
    if definition.has("damage"):
        var amount := int(floor((int(definition["damage"]) + actor.strength) * BattleContent.multiplier(definition["type"], enemy.type)))
        _damage(enemy, amount)
    if enemy.alive():
        for status: String in ["burn", "seed"]:
            if definition.has(status):
                enemy.statuses[status] = {"turns": int(definition[status]), "source_uid": actor.uid}
                _record("status", "%s · %s %d회" % [enemy.display_name, "화상" if status == "burn" else "씨뿌리기", int(definition[status])])
    if definition.has("block"):
        actor.block += int(definition["block"])
        _record("block", "%s · 보호막 +%d" % [actor.display_name, int(definition["block"])])
    if definition.has("strength"):
        actor.strength += int(definition["strength"])
        _record("strength", "%s · 공격력 +%d" % [actor.display_name, int(definition["strength"])])
    if definition.has("draw"):
        _draw(int(definition["draw"]))
    discard.append(card)
    _check_outcome()
    return ""

func switch_reason(uid: int) -> String:
    if phase not in [PLAYER, REPLACE]:
        return "지금은 교체할 수 없습니다."
    var target := _ally(uid)
    if target == null or not target.alive():
        return "살아 있는 대기 포켓몬을 선택하세요."
    if target == active():
        return "이미 출전 중입니다."
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
    for i in party.size():
        if party[i].uid == uid:
            active_index = i
            break
    _record("switch", "%s 출전%s" % [active().display_name, " · 강제 교체" if forced else ""])
    if forced:
        if _pending == "enemy_action":
            _enemy_action()
        elif _pending == "start_player":
            _start_player()
    return ""

func end_turn() -> String:
    if phase != PLAYER:
        return "현재 턴을 종료할 수 없습니다."
    events.clear()
    discard.append_array(hand)
    hand.clear()
    phase = ENEMY
    for pokemon: BattlePokemon in party:
        _tick_statuses(pokemon)
        if _check_outcome():
            return ""
    if not active().alive():
        _require_replacement("enemy_action")
    else:
        _enemy_action()
    return ""

func _enemy_action() -> void:
    phase = ENEMY
    _pending = ""
    enemy.block = 0
    var action := intent()
    _record("enemy_action", "%s · %s %d" % [enemy.display_name, {"attack": "공격", "block": "방어", "boost": "강화"}[action["kind"]], int(action["value"])], action)
    match action["kind"]:
        "attack":
            _damage(active(), int(action["value"]))
        "block":
            enemy.block = int(action["value"])
        "boost":
            enemy.strength += int(action["value"])
    _intent_index += 1
    if _check_outcome():
        return
    _tick_statuses(enemy)
    if _check_outcome():
        return
    if not active().alive():
        _require_replacement("start_player")
    else:
        _start_player()

func _start_player() -> void:
    phase = PLAYER
    _pending = ""
    turn += 1
    energy = 3
    switched = false
    for pokemon: BattlePokemon in party:
        pokemon.block = 0
    _draw(5)
    _record("turn", "턴 %d · 에너지 3" % turn, {"turn": turn})

func _tick_statuses(pokemon: BattlePokemon) -> void:
    for key: String in ["burn", "seed"]:
        if not pokemon.alive() or not pokemon.statuses.has(key):
            continue
        var status: Dictionary = pokemon.statuses[key]
        _damage(pokemon, 2, true)
        if key == "seed":
            var owner: BattlePokemon = enemy if int(status["source_uid"]) == -1 else _ally(int(status["source_uid"]))
            if owner != null and owner.alive():
                var healed := mini(2, owner.max_hp - owner.hp)
                owner.hp += healed
                _record("heal", "%s · 체력 +%d" % [owner.display_name, healed])
        status["turns"] = int(status["turns"]) - 1
        if int(status["turns"]) <= 0:
            pokemon.statuses.erase(key)

func _damage(target: BattlePokemon, amount: int, piercing: bool = false) -> void:
    var absorbed := 0 if piercing else mini(target.block, amount)
    target.block -= absorbed
    var lost := mini(target.hp, maxi(0, amount - absorbed))
    target.hp -= lost
    _record("damage", "%s · 피해 %d%s" % [target.display_name, lost, " (방어 %d)" % absorbed if absorbed > 0 else ""], {"target_uid": target.uid, "hp_lost": lost, "absorbed": absorbed})
    if not target.alive() and not target.knocked_out:
        target.knocked_out = true
        target.statuses.clear()
        _record("knockout", "%s 기절" % target.display_name)
        if target.uid != -1:
            _remove_owner_cards(target.uid)
            injuries.append(target.uid)
            discard.append(_new_card("injury", 0))

func _remove_owner_cards(uid: int) -> void:
    for pile: Array in [hand, draw_pile, discard]:
        for i in range(pile.size() - 1, -1, -1):
            if pile[i].owner_uid == uid:
                removed.append(pile[i])
                pile.remove_at(i)

func _require_replacement(next_step: String) -> void:
    phase = REPLACE
    _pending = next_step
    _record("replacement", "기절한 아군을 대신할 포켓몬을 선택하세요.")

func _check_outcome() -> bool:
    var alive := false
    for pokemon: BattlePokemon in party:
        alive = alive or pokemon.alive()
    if alive and enemy.alive():
        return false
    phase = WON if alive else LOST
    _pending = ""
    for pokemon: BattlePokemon in party:
        pokemon.statuses.clear()
    enemy.statuses.clear()
    _record("outcome", "전투 승리" if phase == WON else "전투 패배")
    return true

func _draw(amount: int) -> void:
    for count in amount:
        if draw_pile.is_empty():
            draw_pile.append_array(discard)
            discard.clear()
            _shuffle(draw_pile)
        if draw_pile.is_empty():
            break
        hand.append(draw_pile.pop_back())

func _shuffle(pile: Array[BattleCardInstance]) -> void:
    for i in range(pile.size() - 1, 0, -1):
        var j := _rng.randi_range(0, i)
        var temporary := pile[i]
        pile[i] = pile[j]
        pile[j] = temporary

func _new_card(key: String, owner: int) -> BattleCardInstance:
    var card := BattleCardInstance.new(_next_card_uid, key, owner)
    _next_card_uid += 1
    return card

func _find_hand(uid: int) -> BattleCardInstance:
    for card: BattleCardInstance in hand:
        if card.uid == uid:
            return card
    return null

func _ally(uid: int) -> BattlePokemon:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid:
            return pokemon
    return null

func _record(kind: String, text: String, data: Dictionary = {}) -> void:
    var event := data.duplicate(true)
    event["kind"] = kind
    event["text"] = text
    events.append(event)
    history.append(text)
    if history.size() > 200:
        history.pop_front()

func snapshot() -> Dictionary:
    var result := {"phase": phase, "turn": turn, "energy": energy, "active": active_index, "switched": switched,
        "intent": _intent_index, "pending": _pending, "rng": _rng.state, "next_uid": _next_card_uid,
        "enemy": enemy.snapshot(), "party": [], "injuries": injuries.duplicate(), "piles": [], "history": history.duplicate(), "events": events.duplicate(true)}
    for pokemon: BattlePokemon in party:
        result["party"].append(pokemon.snapshot())
    for pile: Array in [hand, draw_pile, discard, removed]:
        var ids: Array = []
        for card: BattleCardInstance in pile:
            ids.append([card.uid, card.key, card.owner_uid])
        result["piles"].append(ids)
    return result
