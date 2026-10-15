class_name TacticalJourney
extends RefCounted
## Persistent run state; battle RNG and reward RNG are independent.
const BATTLE := "battle"
const REWARD := "reward"
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

func _init(run_seed: int = 2026, selected_relic: String = "seed_relay") -> void:
    restart(run_seed,selected_relic)
func restart(run_seed: int = 2026, selected_relic: String = "seed_relay") -> void:
    seed_value = run_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "seed_relay"
    step = 0
    wins = 0
    total_turns = 0
    badges = 0
    history.clear()
    reward_options.clear()
    _settled = null
    battle = TacticalBattle.new(seed_value,relic)
    party.assign(battle.party)
    _collect_deck()
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
        battle.start_with(party,deck,TacticalJourneyContent.opponents(step),seed_value+step,relic)
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
