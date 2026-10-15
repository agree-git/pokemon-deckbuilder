class_name TacticalJourney
extends RefCounted
## Persistent run state; battle RNG and reward RNG are independent.
const BATTLE := "battle"
const REWARD := "reward"
const CAPTURE := "capture"
const MAP := "map"
const REST := "rest"
const CLEARED := "cleared"
const FAILED := "failed"
var phase := BATTLE
var seed_value := 2026
var relic := "seed_relay"
var step := 0
var wins := 0
var total_turns := 0
var badges := 0
var battle: TacticalBattle
var party: Array[BattlePokemon] = []
var deck: Array[BattleCardInstance] = []
var reward_options: Array[String] = []
var history: Array[String] = []
var _settled: TacticalBattle
var starter_ids: Array[int] = []
var balls := 2
var pending_captures: Array[BattlePokemon] = []
var _next_pokemon_uid := 1000
var _capture_catalog: VisualCatalog

func _init(run_seed: int = 2026, selected_relic: String = "seed_relay", selected_starters: Array[int] = []) -> void:
    restart(run_seed,selected_relic,selected_starters)
func restart(run_seed: int = 2026, selected_relic: String = "seed_relay", selected_starters: Array[int] = []) -> void:
    if not selected_starters.is_empty(): starter_ids.assign(selected_starters)
    seed_value = run_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "seed_relay"
    step = 0
    wins = 0
    total_turns = 0
    badges = 0
    history.clear()
    reward_options.clear()
    _settled = null
    balls = 2
    pending_captures.clear()
    _next_pokemon_uid = 1000
    battle = TacticalBattle.new(seed_value,relic)
    party.assign(battle.party)
    _collect_deck()
    if not starter_ids.is_empty():
        party.clear()
        var catalog := VisualCatalog.new()
        for id: int in starter_ids:
            party.append(BattlePokemon.new(TacticalContent.member_definition(id,catalog),id))
        var opponents := TacticalContent.ENEMIES.duplicate(true)
        if party.size() == 1: opponents = [opponents[0]]
        battle.start_with(party,deck,opponents,seed_value,relic,true)
    phase = BATTLE
func current() -> Dictionary:
    return TacticalJourneyContent.STOPS[step]
func _collect_deck() -> void:
    deck.clear()
    for pile: Array in [battle.hand,battle.draw_pile,battle.discard,battle.exhausted]: deck.append_array(pile)
    deck.sort_custom(func(a: BattleCardInstance,b: BattleCardInstance): return a.uid < b.uid)
func settle() -> String:
    if _settled == battle: return ""
    if phase != BATTLE or battle.phase not in [TacticalBattle.WON,TacticalBattle.LOST]: return "아직 전투 중입니다."
    _settled = battle
    _collect_deck()
    total_turns += battle.turn
    history.append(current()["name"])
    if battle.phase == TacticalBattle.LOST:
        phase = FAILED
        return ""
    wins += 1
    for pokemon: BattlePokemon in party:
        pokemon.gain_experience()
    if current()["kind"] == "gym":
        badges = 1
        phase = CLEARED
        return ""
    if not pending_captures.is_empty():
        phase = CAPTURE
        return ""
    _prepare_rewards()
    return ""
func _prepare_rewards() -> void:
    var candidates: Array[String] = ["analysis","guard","focus","rally","counter"]
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value+step*104729+81173
    for i in range(candidates.size()-1,0,-1):
        var j := rng.randi_range(0,i)
        var swap := candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = swap
    reward_options.assign(candidates.slice(0,3))
    phase = REWARD

func capture_reason() -> String:
    if phase != BATTLE or step != 0: return "트레이너와 관장의 포켓몬은 포획할 수 없습니다."
    if _capture_catalog == null: _capture_catalog = VisualCatalog.new()
    var species := _capture_catalog.species(battle.enemy().species_id)
    if species.is_empty() or species["is_legendary"] or species["is_mythical"]: return "특별한 포획 조건이 필요한 포켓몬입니다."
    if balls <= 0: return "몬스터볼이 없습니다."
    return battle.capture_reason()
func capture() -> String:
    var reason := capture_reason()
    if not reason.is_empty(): return reason
    var target := battle.enemy()
    var definition := {"id":target.species_id,"name":target.display_name,"type":target.type,"max_hp":target.max_hp}
    battle.capture_enemy()
    balls -= 1
    var caught := BattlePokemon.new(definition,_next_pokemon_uid)
    _next_pokemon_uid += 1
    caught.experience = 1
    pending_captures.append(caught)
    return ""
func resolve_capture(index: int) -> String:
    if phase != CAPTURE: return "합류할 포켓몬이 없습니다."
    if index < -1 or index >= (party.size() if party.size() == 3 else 1): return "합류 또는 교체할 멤버를 선택하세요."
    var caught := pending_captures.pop_front() as BattlePokemon
    if index >= 0:
        if party.size() == 3:
            var leaving := party[index].uid
            party[index] = caught
            for i in range(deck.size()-1,-1,-1):
                if deck[i].injury_owner_uid == leaving: deck.remove_at(i)
        else: party.append(caught)
    if pending_captures.is_empty(): _prepare_rewards()
    return ""
func choose_reward(index: int) -> String:
    if phase != REWARD or index < -1 or index >= reward_options.size(): return "표시된 보상을 선택하세요."
    if index >= 0:
        var next_uid := 1
        for card: BattleCardInstance in deck: next_uid = maxi(next_uid,card.uid+1)
        deck.append(BattleCardInstance.new(next_uid,reward_options[index],0))
    reward_options.clear()
    step += 1
    phase = MAP
    return ""
func enter_next() -> String:
    if phase != MAP: return "지도에서 다음 장소로 이동하세요."
    if current()["kind"] == "rest":
        phase = REST
    else:
        battle = TacticalBattle.new()
        battle.start_with(party,deck,TacticalJourneyContent.opponents(step),seed_value+step,relic,not starter_ids.is_empty())
        phase = BATTLE
    return ""
func rest(action: String, member_index: int = 0) -> String:
    if phase != REST: return "휴식 장소마다 한 번만 행동할 수 있습니다."
    match action:
        "heal":
            for pokemon: BattlePokemon in party:
                pokemon.hp = mini(pokemon.max_hp,pokemon.hp+int(ceil(pokemon.max_hp*0.5)))
                pokemon.knocked_out = false
            for i in range(deck.size()-1,-1,-1):
                if deck[i].key == "injury": deck.remove_at(i)
        "train":
            if member_index < 0 or member_index >= party.size() or not party[member_index].alive(): return "살아 있는 포켓몬을 선택하세요."
            party[member_index].max_hp += 8
            party[member_index].hp += 8
        _: return "회복 또는 훈련을 선택하세요."
    for pokemon: BattlePokemon in party:
        pokemon.block = 0
        pokemon.strength = 0
        pokemon.statuses.clear()
    history.append(current()["name"]+" · "+("회복" if action == "heal" else party[member_index].display_name+" 훈련"))
    step += 1
    phase = MAP
    return ""
