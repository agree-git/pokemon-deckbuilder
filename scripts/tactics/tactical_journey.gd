class_name TacticalJourney
extends RefCounted
## Persistent run state; battle RNG and reward RNG are independent.
const BATTLE := "battle"
const REWARD := "reward"
const CAPTURE := "capture"
const LEARN := "learn"
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
var full_campaign := false
var route: CampaignRoute
var badge_records: Array[Dictionary] = []
var elite_wins := 0
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
var growth_reports: Array[Dictionary] = []
var pending_learning: Array[Dictionary] = []
var gold := 100
var inventory: Dictionary = {"potion":1,"super_potion":0,"revive":0}
var loot: Array[Dictionary] = []
var rested_steps: Array[int] = []
var shop_stock: Dictionary = {}

func _init(run_seed: int = 2026, selected_relic: String = "seed_relay", selected_starters: Array[int] = [], campaign := false) -> void:
    full_campaign = campaign
    restart(run_seed,selected_relic,selected_starters)
func restart(run_seed: int = 2026, selected_relic: String = "seed_relay", selected_starters: Array[int] = []) -> void:
    if not selected_starters.is_empty(): starter_ids.assign(selected_starters)
    seed_value = run_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "seed_relay"
    step = 0
    wins = 0
    total_turns = 0
    badges = 0
    badge_records.clear()
    elite_wins = 0
    route = CampaignRoute.new(run_seed) if full_campaign else null
    history.clear()
    reward_options.clear()
    growth_reports.clear()
    pending_learning.clear()
    gold = 100
    inventory = {"potion":1,"super_potion":0,"revive":0}
    loot.clear()
    rested_steps.clear()
    shop_stock.clear()
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
    if full_campaign and _capture_catalog == null: _capture_catalog = VisualCatalog.new()
    for pokemon: BattlePokemon in party:
        TacticalGrowth.initialize(pokemon)
        if full_campaign: pokemon.types.assign(_capture_catalog.species(pokemon.species_id)["types"])
    var opponents := route.opponents(0) if full_campaign else TacticalJourneyContent.opponents(0)
    if party.size() == 1: opponents = [opponents[0]]
    battle.start_with(party,deck,opponents,seed_value,relic,not starter_ids.is_empty())
    battle.full_type_chart = full_campaign
    phase = BATTLE
func current() -> Dictionary:
    return route.stops[step] if full_campaign else TacticalJourneyContent.STOPS[step]
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
    growth_reports.clear()
    for pokemon: BattlePokemon in party:
        var report := TacticalGrowth.award(pokemon,experience_reward())
        growth_reports.append(report)
        pending_learning.append_array(report["offers"])
    var role: String = current()["kind"]
    var wild := is_wild()
    var boss: bool = role in ["gym","elite","champion"]
    var coins := 180 if boss else (40 if wild else 80)
    var item := "revive" if boss else ("potion" if wild else "super_potion")
    if full_campaign and role == "gym":
        badge_records.append({"type":current()["biome"]["type"],"biome":current()["biome"]["id"],"leader_id":current()["trainer"]["leader_id"],"leader":current()["trainer"]["leader"],"step":step})
        badges = badge_records.size()
    if full_campaign and role == "elite": elite_wins += 1
    gold += coins
    inventory[item] = int(inventory[item])+1
    loot.append({"name":current()["name"],"gold":coins,"item":item,"quantity":1})
    _after_learning()
    return ""
func _after_learning() -> void:
    if not pending_learning.is_empty():
        phase = LEARN
        return
    if (not full_campaign and current()["kind"] == "gym") or (full_campaign and current()["kind"] == "champion" and badges == 8 and elite_wins == 4):
        if not full_campaign: badges = 1
        phase = CLEARED
        return
    if not pending_captures.is_empty():
        phase = CAPTURE
        return
    _prepare_rewards()
func resolve_learning(slot: int) -> String:
    if phase != LEARN or pending_learning.is_empty(): return "배울 기술이 없습니다."
    var offer := pending_learning[0]
    var pokemon: BattlePokemon
    for member: BattlePokemon in party:
        if member.uid == int(offer["uid"]): pokemon = member
    if pokemon == null or slot < -1 or slot >= pokemon.learned_skills.size(): return "교체할 기술 또는 배우지 않기를 선택하세요."
    if slot >= 0:
        pokemon.learned_skills[slot] = offer["key"]
    pending_learning.pop_front()
    _after_learning()
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
    if phase != BATTLE or not is_wild(): return "트레이너와 관장의 포켓몬은 포획할 수 없습니다."
    if _capture_catalog == null: _capture_catalog = VisualCatalog.new()
    var species := _capture_catalog.species(battle.enemy().species_id)
    if species.is_empty() or species["is_legendary"] or species["is_mythical"]: return "특별한 포획 조건이 필요한 포켓몬입니다."
    if balls <= 0: return "몬스터볼이 없습니다."
    return battle.capture_reason()
func capture() -> String:
    var reason := capture_reason()
    if not reason.is_empty(): return reason
    var target := battle.enemy()
    var definition := {"id":target.species_id,"name":target.display_name,"type":target.type,"types":target.types.duplicate(),"max_hp":target.max_hp,"level":target.level}
    battle.capture_enemy()
    balls -= 1
    var caught := BattlePokemon.new(definition,_next_pokemon_uid)
    _next_pokemon_uid += 1
    TacticalGrowth.initialize(caught)
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
    if full_campaign and current()["kind"] in ["elite","champion"]:
        if badges != 8 or elite_wins != int(current()["league_index"]): return "배지 8개와 앞선 리그 경기를 완료하세요."
    if current()["kind"] == "rest":
        phase = REST
        shop_stock.clear()
        for key: String in items(): shop_stock[key] = items()[key]["stock"]
    else:
        battle = TacticalBattle.new()
        battle.start_with(party,deck,route.opponents(step) if full_campaign else TacticalJourneyContent.opponents(step),seed_value+step,relic,not starter_ids.is_empty())
        battle.full_type_chart = full_campaign
        phase = BATTLE
    return ""
func rest(action: String = "heal", _member_index: int = 0) -> String:
    if phase != REST: return "야영지에서 휴식할 수 있습니다."
    if action != "heal": return "야영지에서 휴식·구매·가방·전리품을 이용하세요."
    if step in rested_steps: return "이번 야영지에서는 이미 휴식했습니다."
    for pokemon: BattlePokemon in party:
        pokemon.hp = mini(pokemon.max_hp,pokemon.hp+ceili(pokemon.max_hp*0.5))
        pokemon.knocked_out = false
        pokemon.block = 0
        pokemon.strength = 0
        pokemon.statuses.clear()
    for i in range(deck.size()-1,-1,-1):
        if deck[i].key == "injury": deck.remove_at(i)
    rested_steps.append(step)
    history.append(current()["name"]+" · 휴식")
    return ""
func leave_camp() -> String:
    if phase != REST: return "현재 야영지에 있지 않습니다."
    step += 1
    phase = MAP
    return ""
func buy_reason(key: String) -> String:
    if phase != REST: return "물건은 야영지에서 구매할 수 있습니다."
    if not items().has(key): return "판매하지 않는 아이템입니다."
    if int(shop_stock.get(key,0)) <= 0: return "이번 야영지의 재고가 없습니다."
    if gold < int(items()[key]["price"]): return "골드가 부족합니다."
    return ""
func buy(key: String) -> String:
    var reason := buy_reason(key)
    if not reason.is_empty(): return reason
    gold -= int(items()[key]["price"])
    shop_stock[key] = int(shop_stock[key])-1
    if key == "ball": balls += 1
    else: inventory[key] = int(inventory[key])+1
    return ""
func item_reason(key: String,index: int) -> String:
    if key == "ball": return "야생 전투에서 C 또는 포획 버튼을 사용하세요."
    if phase != REST and not (phase == BATTLE and battle.phase == TacticalBattle.PLAYER): return "지금은 아이템을 사용할 수 없습니다."
    if not items().has(key) or int(inventory.get(key,0)) <= 0: return "보유한 아이템이 없습니다."
    if index < 0 or index >= party.size(): return "사용할 동료를 선택하세요."
    if phase == BATTLE and battle.energy < 1: return "전투 중 아이템 사용에는 에너지 1이 필요합니다."
    var pokemon := party[index]
    if key == "revive":
        if pokemon.alive(): return "기절한 동료에게 사용하세요."
    elif not pokemon.alive(): return "기절한 동료는 기력의조각으로 회복하세요."
    elif pokemon.hp >= pokemon.max_hp: return "체력이 가득 찼습니다."
    return ""
func use_item(key: String,index: int) -> String:
    var reason := item_reason(key,index)
    if not reason.is_empty(): return reason
    var pokemon := party[index]
    if key == "revive":
        pokemon.hp = ceili(pokemon.max_hp*0.5)
        pokemon.knocked_out = false
    else: pokemon.hp = mini(pokemon.max_hp,pokemon.hp+int(items()[key]["heal"]))
    inventory[key] = int(inventory[key])-1
    if phase == BATTLE:
        battle.events.clear()
        battle.energy -= 1
        battle._record("item",pokemon.display_name+" · "+str(items()[key]["name"]))
    return ""

func is_wild() -> bool:
    return current()["kind"] == "wild" if full_campaign else step == 0
func items() -> Dictionary:
    var result := TacticalJourneyContent.ITEMS.duplicate(true)
    if full_campaign: result["ball"] = {"name":"몬스터볼","price":35,"stock":4}
    return result
func quantity(key: String) -> int:
    return balls if key == "ball" else int(inventory.get(key,0))
func experience_reward() -> float:
    return route.experience_reward(step) if full_campaign else TacticalJourneyContent.experience_reward(step)
func biome() -> Dictionary:
    return current()["biome"] if full_campaign else VisualCatalog.new().biomes[3]
func progress_title() -> String:
    if not full_campaign: return "%d / 5  ·  %s" % [step+1,current()["name"]]
    return ("바이옴 %d / 8" % (int(current()["chapter"])+1) if int(current()["chapter"]) < 8 else "포켓몬 리그 · %d / 4승" % elite_wins)+"  ·  "+str(current()["name"])
