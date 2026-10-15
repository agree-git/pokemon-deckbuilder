class_name RunState
extends RefCounted
## Persistent party, deck and balls; battle-only effects reset at each encounter.

const PARTY_LIMIT := 3
const BATTLE := "battle"
const MAP := "map"
const REST := "rest"
const CLEARED := "cleared"
const FAILED := "failed"
var phase := BATTLE
var step := 0
var current_node: Dictionary = ExpeditionContent.ROUTE[0][0].duplicate(true)
var route_history: Array[Dictionary] = []
var rest_result := ""
var wins := 0
var capture_count := 0
var total_turns := 0

var battle: BattleState
var party: Array[BattlePokemon] = []
var deck: Array[BattleCardInstance] = []
var balls := 2
var encounter := 0
var seed_value := 2026
var pending_capture: BattlePokemon
var capture_result := ""
var reward_options: Array[Dictionary] = []
var reward_pending := false
var reward_result := ""
var _settled := false
var _next_pokemon_uid := 100

func _init(run_seed: int = 2026) -> void:
    restart(run_seed)

func restart(run_seed: int = 2026) -> void:
    seed_value = run_seed
    encounter = 0
    phase = BATTLE
    step = 0
    current_node = ExpeditionContent.ROUTE[0][0].duplicate(true)
    route_history.clear()
    rest_result = ""
    wins = 0
    capture_count = 0
    total_turns = 0
    balls = 2
    pending_capture = null
    capture_result = ""
    reward_options.clear()
    reward_pending = false
    reward_result = ""
    _next_pokemon_uid = 100
    _settled = false
    battle = BattleState.new(seed_value)
    party.assign(battle.party)
    deck.clear()
    deck.append_array(battle.hand)
    deck.append_array(battle.draw_pile)

func settle() -> void:
    if _settled or battle.phase not in [BattleState.WON, BattleState.LOST, BattleState.CAPTURED]:
        return
    _settled = true
    balls = battle.balls
    # Restore cards excluded by KO to the run deck, along with new injury cards.
    deck.clear()
    for pile: Array in [battle.hand, battle.draw_pile, battle.discard, battle.removed]:
        deck.append_array(pile)
    total_turns += battle.turn
    if battle.phase == BattleState.LOST:
        phase = FAILED
    else:
        for pokemon: BattlePokemon in party:
            if pokemon.alive():
                pokemon.experience += 1
        wins += 1 if battle.phase == BattleState.WON else 0
    if battle.phase == BattleState.WON:
        if current_node["kind"] == "boss":
            phase = CLEARED
            route_history.append(current_node.duplicate(true))
        else:
            _prepare_rewards()
    if battle.phase == BattleState.CAPTURED:
        capture_count += 1
        pending_capture = battle.caught
        pending_capture.experience = 1 # Joining a completed capture grants its first XP.
        pending_capture.uid = _next_pokemon_uid
        _next_pokemon_uid += 1
        if party.size() < PARTY_LIMIT:
            resolve_capture()

func _prepare_rewards() -> void:
    var candidates: Array[Dictionary] = []
    for pokemon: BattlePokemon in party:
        if not pokemon.alive():
            continue
        for key: String in BattleContent.LEARNSETS.get(pokemon.species_id, []):
            candidates.append({"key": key, "owner": pokemon.uid})
    # A separate RNG preserves battle draws and never rerolls on UI refresh/reentry.
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + encounter * 104729 + 81173
    for i in range(candidates.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var temporary := candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = temporary
    reward_options.assign(candidates.slice(0, mini(3, candidates.size())))
    reward_pending = not reward_options.is_empty()

func reward_view(index: int) -> Dictionary:
    if index < 0 or index >= reward_options.size():
        return {}
    var option := reward_options[index]
    var view: Dictionary = BattleContent.CARDS[option["key"]].duplicate(true)
    for slot in party.size():
        var pokemon := party[slot]
        if pokemon.uid == int(option["owner"]):
            view.merge({"key": option["key"], "owner": pokemon.uid,
                "owner_name": "%s · 파티 %d" % [pokemon.display_name, slot + 1],
                "art_id": pokemon.species_id})
            break
    return view

func choose_reward(index: int) -> String:
    if not reward_pending or battle.phase != BattleState.WON:
        return "선택할 기술 보상이 없습니다."
    if index < -1 or index >= reward_options.size():
        return "표시된 보상 중 하나를 선택하세요."
    if index == -1:
        reward_result = "기술 보상을 넘겼습니다. 덱을 유지합니다."
    else:
        var option := reward_options[index]
        var next_uid := 1
        for card: BattleCardInstance in deck:
            next_uid = maxi(next_uid, card.uid + 1)
        deck.append(BattleCardInstance.new(next_uid, option["key"], int(option["owner"])))
        var view := reward_view(index)
        reward_result = "%s · %s 획득 · 원정 덱 %d장" % [view["owner_name"], view["name"], deck.size()]
    reward_pending = false
    return ""

func resolve_capture(release_uid: int = 0) -> String:
    if pending_capture == null:
        return "합류를 기다리는 포켓몬이 없습니다."
    if release_uid == pending_capture.uid:
        capture_result = "%s를 풀어주었습니다. 몬스터볼은 소모되었습니다." % pending_capture.display_name
        pending_capture = null
        return ""
    if party.size() >= PARTY_LIMIT:
        var leaving: BattlePokemon
        for pokemon: BattlePokemon in party:
            if pokemon.uid == release_uid:
                leaving = pokemon
        if leaving == null:
            return "내보낼 파티원을 선택하세요."
        party.erase(leaving)
        for i in range(deck.size() - 1, -1, -1):
            if deck[i].owner_uid == release_uid or deck[i].injury_owner_uid == release_uid:
                deck.remove_at(i)
    capture_result = "%s 합류 · 최대 체력 회복 · 전용 카드 2장 추가" % pending_capture.display_name
    party.append(pending_capture)
    var next_uid := 1
    for card: BattleCardInstance in deck:
        next_uid = maxi(next_uid, card.uid + 1)
    for key: String in BattleContent.CAPTURE_CARDS[pending_capture.species_id]:
        deck.append(BattleCardInstance.new(next_uid, key, pending_capture.uid))
        next_uid += 1
    pending_capture = null
    return ""

func next_battle() -> String:
    if phase != BATTLE:
        return "전투 결과에서만 지도로 이동할 수 있습니다."
    settle()
    if not _settled or phase != BATTLE:
        return "원정이 끝났거나 아직 전투 중입니다."
    if pending_capture != null:
        return "먼저 포획한 포켓몬의 합류 여부를 선택하세요."
    if reward_pending:
        return "기술 보상을 선택하거나 넘기세요."
    reward_options.clear()
    reward_result = ""
    route_history.append(current_node.duplicate(true))
    step += 1
    phase = MAP
    return ""

func options() -> Array:
    return ExpeditionContent.ROUTE[step].duplicate(true) if phase == MAP and step < ExpeditionContent.ROUTE.size() else []

func choose_node(index: int) -> String:
    var choices := options()
    if index < 0 or index >= choices.size():
        return "지도에 표시된 다음 장소를 선택하세요."
    current_node = choices[index].duplicate(true)
    rest_result = ""
    if current_node["kind"] == "rest":
        phase = REST
    else:
        encounter += 1
        battle = BattleState.new(seed_value + encounter)
        battle.start_with(party, deck, current_node["enemy"], seed_value + encounter, balls)
        _settled = false
        phase = BATTLE
    return ""

func rest_options() -> Array[BattleCardInstance]:
    var result: Array[BattleCardInstance] = []
    for card: BattleCardInstance in deck:
        if not card.upgraded and BattleContent.UPGRADES.has(card.key):
            result.append(card)
    return result

func evolve_reason(uid: int) -> String:
    if phase != REST:
        return "휴식 장소에서만 진화할 수 있습니다."
    var pokemon := member(uid)
    if pokemon == null or not pokemon.alive():
        return "살아 있는 포켓몬을 선택하세요."
    if not ExpeditionContent.EVOLUTIONS.has(pokemon.species_id):
        return "이번 원정에서 가능한 진화가 없습니다."
    if pokemon.experience < 4:
        return "경험치 4가 필요합니다. (현재 %d)" % pokemon.experience
    return ""

func rest(action: String, uid: int = 0) -> String:
    if phase != REST:
        return "휴식 행동은 장소마다 한 번만 선택할 수 있습니다."
    match action:
        "heal":
            for pokemon: BattlePokemon in party:
                pokemon.hp = mini(pokemon.max_hp, pokemon.hp + maxi(1, int(ceil(pokemon.max_hp * 0.3))))
                pokemon.knocked_out = false
                pokemon.statuses.clear()
                pokemon.block = 0
                pokemon.strength = 0
            for i in range(deck.size() - 1, -1, -1):
                if deck[i].injury_owner_uid != 0:
                    deck.remove_at(i)
            rest_result = "파티 전원 최대 체력의 30% 회복 · 기절 부활 · 연결된 부상 제거"
        "evolve":
            var reason := evolve_reason(uid)
            if not reason.is_empty():
                return reason
            var pokemon := member(uid)
            var evolution: Dictionary = ExpeditionContent.EVOLUTIONS[pokemon.species_id]
            pokemon.hp = maxi(1, int(ceil(float(pokemon.hp) / pokemon.max_hp * int(evolution["max_hp"]))))
            pokemon.max_hp = int(evolution["max_hp"])
            pokemon.species_id = int(evolution["id"])
            pokemon.display_name = evolution["name"]
            for card: BattleCardInstance in deck:
                if card.owner_uid == uid and card.key == evolution["from_card"]:
                    card.key = evolution["to_card"]
                    break
            rest_result = "%s 진화 · %s" % [pokemon.display_name, evolution["trait"]]
        "upgrade":
            var selected: BattleCardInstance
            for card: BattleCardInstance in rest_options():
                if card.uid == uid:
                    selected = card
            if selected == null:
                return "아직 강화하지 않은 기술 카드를 선택하세요."
            selected.upgraded = true
            rest_result = "%s 강화 완료" % BattleContent.card_definition(selected)["name"]
        "skip":
            rest_result = "휴식을 마치고 출발합니다."
        _:
            return "회복, 강화, 진화 중 하나를 선택하세요."
    route_history.append(current_node.duplicate(true))
    step += 1
    phase = MAP
    return ""

func member(uid: int) -> BattlePokemon:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid:
            return pokemon
    return null
