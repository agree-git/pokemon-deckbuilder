class_name RunState
extends RefCounted
## Persistent party, deck and balls; battle-only effects reset at each encounter.

const PARTY_LIMIT := 3
var battle: BattleState
var party: Array[BattlePokemon] = []
var deck: Array[BattleCardInstance] = []
var balls := 2
var encounter := 0
var seed_value := 2026
var pending_capture: BattlePokemon
var capture_result := ""
var _settled := false
var _next_pokemon_uid := 100

func _init(run_seed: int = 2026) -> void:
    restart(run_seed)

func restart(run_seed: int = 2026) -> void:
    seed_value = run_seed
    encounter = 0
    balls = 2
    pending_capture = null
    capture_result = ""
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
    if battle.phase == BattleState.CAPTURED:
        pending_capture = battle.caught
        pending_capture.uid = _next_pokemon_uid
        _next_pokemon_uid += 1
        if party.size() < PARTY_LIMIT:
            resolve_capture()

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
    settle()
    if not _settled or battle.phase == BattleState.LOST:
        return "승리하거나 포획한 뒤 다음 전투로 이동하세요."
    if pending_capture != null:
        return "먼저 포획한 포켓몬의 합류 여부를 선택하세요."
    encounter += 1
    battle = BattleState.new(seed_value + encounter)
    battle.start_with(party, deck, BattleContent.ENCOUNTERS[encounter % BattleContent.ENCOUNTERS.size()], seed_value + encounter, balls)
    _settled = false
    return ""
