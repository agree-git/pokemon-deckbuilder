class_name TacticalJourney
extends RefCounted
signal changed
## Persistent run state; battle RNG and reward RNG are independent.
const BATTLE := "battle"
const REWARD := "reward"
const CAPTURE := "capture"
const LEARN := "learn"
const MAP := "map"
const REST := "rest"
const CLEARED := "cleared"
const FAILED := "failed"
var run_id := ""
var captured_ids: Array[int] = []
var _observed_battle: TacticalBattle
var phase := BATTLE
var seed_value := 2026
var relic := "field_kit"
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
var reward_options: Array[Dictionary] = []
var relics: Array[String] = []
var held_inventory: Array[String] = []
var _next_card_uid := 1
var history: Array[String] = []
var statistics: Dictionary = {}
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
var camp_states: Dictionary = {}
var time_of_day := ""

func _init(run_seed: int = 2026, selected_relic: String = "field_kit", selected_starters: Array[int] = [], campaign := false) -> void:
    full_campaign = campaign
    restart(run_seed,selected_relic,selected_starters)
func restart(run_seed: int = 2026, selected_relic: String = "field_kit", selected_starters: Array[int] = []) -> void:
    if not selected_starters.is_empty(): starter_ids.assign(selected_starters)
    run_id = Crypto.new().generate_random_bytes(16).hex_encode()
    seed_value = run_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "field_kit"
    step = 0
    wins = 0
    total_turns = 0
    badges = 0
    badge_records.clear()
    elite_wins = 0
    route = CampaignRoute.new(run_seed) if full_campaign else null
    history.clear()
    reward_options.clear()
    relics.assign([relic])
    held_inventory.clear()
    _next_card_uid = 1
    growth_reports.clear()
    pending_learning.clear()
    gold = 100
    statistics = RunStatistics.expedition()
    inventory = {"potion":1,"super_potion":0,"revive":0}
    loot.clear()
    rested_steps.clear()
    shop_stock = {}
    camp_states.clear()
    time_of_day = "day"
    _settled = null
    balls = 2
    pending_captures.clear()
    captured_ids.clear()
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
        SpecialEvolution.assign_personality(pokemon,seed_value)
        if full_campaign: pokemon.types.assign(_capture_catalog.species(pokemon.species_id)["types"])
    deck.assign(TacticalContent.starting_deck(party))
    _next_card_uid = deck.size()+1
    var opponents := route.opponents(0) if full_campaign else TacticalJourneyContent.opponents(0)
    if party.size() == 1: opponents = [opponents[0]]
    battle.start_with(party,deck,opponents,seed_value,relic,true,relics)
    battle.full_type_chart = full_campaign
    phase = BATTLE
    bind_battle()
    changed.emit()
func current() -> Dictionary:
    return route.stops[step] if full_campaign else TacticalJourneyContent.STOPS[step]
func _collect_deck() -> void:
    deck.clear()
    for pile: Array in [battle.hand,battle.draw_pile,battle.discard,battle.exhausted]: deck.append_array(pile)
    deck.sort_custom(func(a: BattleCardInstance,b: BattleCardInstance): return a.uid < b.uid)
    for card: BattleCardInstance in deck: _next_card_uid = maxi(_next_card_uid,card.uid+1)
func settle() -> String:
    if _settled == battle: return ""
    if phase != BATTLE or battle.phase not in [TacticalBattle.WON,TacticalBattle.LOST]: return "아직 전투 중입니다."
    _settled = battle
    _ensure_statistics()
    RunStatistics.settle(statistics,battle,step,current())
    _collect_deck()
    total_turns += battle.turn
    history.append(current()["name"])
    if battle.phase == TacticalBattle.LOST:
        phase = FAILED
        return notify_changed()
    wins += 1
    growth_reports.clear()
    var growing := party.duplicate()
    for pokemon: BattlePokemon in growing:
        var known := pokemon.learned_skills.duplicate()
        var friendship_before := FriendshipEvolution.value(pokemon)
        FriendshipEvolution.change(pokemon,FriendshipEvolution.VICTORY if pokemon.alive() else FriendshipEvolution.FAINTED)
        var report := TacticalGrowth.award(pokemon,experience_reward(pokemon.species_id),current_time())
        report["friendship_before"] = friendship_before
        for key: String in pokemon.learned_skills:
            if key not in known: deck.append(_allocate_card(key,pokemon.uid))
        growth_reports.append(report)
        pending_learning.append_array(report["offers"])
    for i in growing.size():
        if growth_reports[i]["evolutions"].any(func(e: Dictionary): return e["from"] == 290 and e["to"] == 291):
            _join_shedinja(growing[i],growth_reports[i])
    var role: String = current()["kind"]
    var wild := is_wild()
    var boss: bool = role in ["gym","elite","champion"]
    var coins := 180 if boss else (120 if role == "veteran" else (40 if wild else 80))
    var item := "revive" if boss else ("potion" if wild else "super_potion")
    if full_campaign and role == "gym":
        badge_records.append({"type":current()["biome"]["type"],"biome":current()["biome"]["id"],"leader_id":current()["trainer"]["leader_id"],"leader":current()["trainer"]["leader"],"step":step})
        badges = badge_records.size()
    if full_campaign and role == "elite": elite_wins += 1
    gold += coins
    _stat("gold_earned",coins)
    inventory[item] = int(inventory[item])+1
    loot.append({"name":current()["name"],"gold":coins,"item":item,"quantity":1})
    _after_learning()
    return notify_changed()
func _join_shedinja(parent: BattlePokemon, report: Dictionary) -> void:
    if party.size() >= 3 or balls <= 0:
        report["companion"] = "껍질몬: 빈자리·몬스터볼 필요"
        return
    var catalog := VisualCatalog.new()
    var definition := TacticalContent.member_definition(292,catalog)
    definition["types"] = catalog.species(292)["types"]
    var pokemon := BattlePokemon.new(definition,_next_pokemon_uid)
    _next_pokemon_uid += 1
    pokemon.level = parent.level
    TacticalGrowth.initialize(pokemon)
    pokemon.experience = parent.experience
    pokemon.learned_skills.assign(parent.learned_skills)
    if not parent.alive():
        pokemon.hp = 0
        pokemon.knocked_out = true
    party.append(pokemon)
    balls -= 1
    for key: String in TacticalContent.skills_for(pokemon): deck.append(_allocate_card(key,pokemon.uid))
    report["companion"] = "껍질몬 합류! · 몬스터볼 1개"
    history.append(report["companion"])
    _decision(report["companion"])
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
        var previous := pokemon.learned_skills[slot]
        pokemon.learned_skills[slot] = offer["key"]
        for card: BattleCardInstance in deck:
            if card.owner_uid == pokemon.uid and card.key == previous: card.key = offer["key"]
    pending_learning.pop_front()
    _after_learning()
    return notify_changed()
func _prepare_rewards() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ (step*104729+81173)
    var commons: Array = TacticalContent.CARDS.keys().filter(func(key: String): return key != "injury")
    var related := TacticalContent.synergy_cards(deck,relics)
    var candidates: Array = related if not related.is_empty() and rng.randf() < 0.5 else commons
    var first: String = candidates[rng.randi_range(0,candidates.size()-1)]
    reward_options.assign([{"kind":"card","key":first,"owner_uid":0,"upgraded":false}])
    var pokemon := party[rng.randi_range(0,party.size()-1)]
    var learned: Array = TacticalContent.skills_for(pokemon)
    reward_options.append({"kind":"card","key":learned[rng.randi_range(0,learned.size()-1)],"owner_uid":pokemon.uid,"upgraded":current()["kind"] in ["gym","elite"]})
    var available: Array = TacticalContent.RELICS.keys().filter(func(key: String): return key not in relics)
    var roll := rng.randf()
    if not available.is_empty() and (current()["kind"] in ["veteran","gym","elite"] or roll < 0.12):
        reward_options.append({"kind":"relic","key":available[rng.randi_range(0,available.size()-1)]})
    elif roll < 0.65 or current()["kind"] in ["veteran","gym","elite"]:
        var held: Array = TacticalContent.HELD_ITEMS.keys()
        reward_options.append({"kind":"held","key":held[rng.randi_range(0,held.size()-1)]})
    else:
        commons.erase(first)
        reward_options.append({"kind":"card","key":commons[rng.randi_range(0,commons.size()-1)],"owner_uid":0,"upgraded":false})
    phase = REWARD
func _allocate_card(key: String, owner := 0) -> BattleCardInstance:
    var card := BattleCardInstance.new(_next_card_uid,key,owner)
    _next_card_uid += 1
    return card
func reward_view(option: Dictionary) -> Dictionary:
    if option["kind"] == "card":
        var card := BattleCardInstance.new(0,option["key"],int(option["owner_uid"]))
        card.upgraded = option.get("upgraded",false)
        var view := TacticalContent.definition(card)
        for pokemon: BattlePokemon in party:
            if pokemon.uid == card.owner_uid:
                view["species_id"] = pokemon.species_id
                view["owner_name"] = pokemon.display_name
        return view
    var view: Dictionary = (TacticalContent.RELICS if option["kind"] == "relic" else TacticalContent.HELD_ITEMS)[option["key"]].duplicate(true)
    view["category"] = option["kind"]
    return view

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
    SpecialEvolution.assign_personality(caught,seed_value)
    pending_captures.append(caught)
    if target.species_id not in captured_ids: captured_ids.append(target.species_id)
    return notify_changed()
func resolve_capture(index: int) -> String:
    if phase != CAPTURE: return "합류할 포켓몬이 없습니다."
    if index < -1 or index >= (party.size() if party.size() == 3 else 1): return "합류 또는 교체할 멤버를 선택하세요."
    var caught := pending_captures.pop_front() as BattlePokemon
    if index >= 0:
        if party.size() == 3:
            var leaving := party[index].uid
            if not party[index].held_item.is_empty(): held_inventory.append(party[index].held_item)
            party[index] = caught
            for i in range(deck.size()-1,-1,-1):
                if deck[i].injury_owner_uid == leaving or deck[i].owner_uid == leaving: deck.remove_at(i)
        else: party.append(caught)
        var skills: Array = TacticalContent.skills_for(caught)
        for key: String in skills: deck.append(_allocate_card(key,caught.uid))
        if skills.size() < 2: deck.append(_allocate_card(skills[0],caught.uid))
    if pending_captures.is_empty(): _prepare_rewards()
    return notify_changed()
func choose_reward(index: int) -> String:
    if phase != REWARD or index < -1 or index >= reward_options.size(): return "표시된 보상을 선택하세요."
    if index >= 0:
        var option := reward_options[index]
        match option["kind"]:
            "card":
                var card := _allocate_card(option["key"],int(option["owner_uid"]))
                card.upgraded = option.get("upgraded",false)
                deck.append(card)
            "relic":
                if option["key"] not in relics: relics.append(option["key"])
            "held": held_inventory.append(option["key"])
        _stat("reward_"+str(option["kind"]))
        var choice := "전투 보상 · "+str(reward_view(option)["name"])
        history.append(choice)
        _decision(choice)
    else:
        _stat("reward_skip")
        _decision("보상 넘기기")
    reward_options.clear()
    step += 1
    phase = MAP
    return notify_changed()
func enter_next() -> String:
    if phase != MAP: return "지도에서 다음 장소로 이동하세요."
    if full_campaign and current()["kind"] in ["elite","champion"]:
        if badges != 8 or elite_wins != int(current()["league_index"]): return "배지 8개와 앞선 리그 경기를 완료하세요."
    if current()["kind"] == "rest":
        phase = REST
        _prepare_camp()
    else:
        battle = TacticalBattle.new()
        battle.start_with(party,deck,route.opponents(step) if full_campaign else TacticalJourneyContent.opponents(step),seed_value+step,relic,true,relics)
        battle.full_type_chart = full_campaign
        phase = BATTLE
        bind_battle()
    return notify_changed()
func rest(action: String = "heal", card_uid: int = 0) -> String:
    if phase != REST: return "야영지에서 휴식할 수 있습니다."
    if action not in ["heal","upgrade"]: return "휴식 또는 카드 강화를 선택하세요."
    if step in rested_steps: return "이번 야영지의 휴식·강화 행동을 이미 사용했습니다."
    if action == "upgrade":
        for card: BattleCardInstance in deck:
            if card.uid == card_uid and TacticalContent.can_upgrade(card):
                card.upgraded = true
                rested_steps.append(step)
                var choice := "카드 강화 · "+str(TacticalContent.definition(card)["name"])
                history.append(choice)
                _stat("cards_upgraded")
                _decision(choice)
                return notify_changed()
        return "아직 강화하지 않은 카드를 선택하세요."
    _stat("rests")
    for pokemon: BattlePokemon in party:
        var hp_before := pokemon.hp
        FriendshipEvolution.change(pokemon,FriendshipEvolution.REST)
        pokemon.hp = mini(pokemon.max_hp,pokemon.hp+ceili(pokemon.max_hp*0.5))
        _stat("camp_healing",pokemon.hp-hp_before)
        pokemon.knocked_out = false
        pokemon.block = 0
        pokemon.strength = 0
        pokemon.statuses.clear()
        pokemon.stat_stages.clear()
    for i in range(deck.size()-1,-1,-1):
        if deck[i].key == "injury": deck.remove_at(i)
    rested_steps.append(step)
    history.append(current()["name"]+" · 휴식")
    return notify_changed()
func leave_camp() -> String:
    if phase != REST: return "현재 야영지에 있지 않습니다."
    step += 1
    phase = MAP
    return notify_changed()
func current_time() -> String:
    return time_of_day if not time_of_day.is_empty() else "day"
func set_time(value: String) -> String:
    if phase != REST: return "야영지에서 원정 시간대를 준비하세요."
    if value not in ["day","night"]: return "낮 또는 밤을 선택하세요."
    if value == current_time(): return "이미 선택한 시간대입니다."
    time_of_day = value
    _decision("원정 시간 · "+("낮" if value == "day" else "밤"))
    return notify_changed()
func train_evolution(uid: int, style: String) -> String:
    if phase != REST: return "야영지에서 진화 훈련을 준비하세요."
    if style not in ["attack","defense","balanced"]: return "공격·균형·방어 훈련을 선택하세요."
    for pokemon: BattlePokemon in party:
        if pokemon.uid != uid: continue
        if pokemon.species_id != 236 or pokemon.level >= 100: return "레벨업할 수 있는 배루키의 훈련입니다."
        if style == SpecialEvolution.training(pokemon): return "이미 선택한 훈련입니다."
        pokemon.evolution_training = style
        _decision("배루키 진화 훈련 · "+str({"attack":"공격","defense":"방어","balanced":"균형"}[style]))
        return notify_changed()
    return "파티의 배루키를 선택하세요."
func buy_reason(key: String) -> String:
    if phase != REST: return "물건은 야영지에서 구매할 수 있습니다."
    if full_campaign and camp().get("kind","") != "merchant": return "이번 야영지에는 상인이 없습니다."
    if not items().has(key): return "판매하지 않는 아이템입니다."
    if int(shop_stock.get(key,0)) <= 0: return "이번 야영지의 재고가 없습니다."
    if gold < int(items()[key]["price"]): return "골드가 부족합니다."
    return ""
func buy(key: String) -> String:
    var reason := buy_reason(key)
    if not reason.is_empty(): return reason
    gold -= int(items()[key]["price"])
    _stat("gold_supplies",int(items()[key]["price"]))
    _stat("supplies_bought")
    shop_stock[key] = int(shop_stock[key])-1
    if key == "ball": balls += 1
    else: inventory[key] = int(inventory.get(key,0))+1
    return notify_changed()
func shop_cards() -> Array:
    return camp().get("card_offers",[])
func shop_card_reason(index: int) -> String:
    if phase != REST or camp().get("kind","") != "merchant": return "상인이 있는 야영지에서 카드를 구매하세요."
    var offers := shop_cards()
    if index < 0 or index >= offers.size(): return "진열된 카드를 선택하세요."
    var offer: Dictionary = offers[index]
    if offer["sold"]: return "이미 판매된 카드입니다."
    if int(offer["owner_uid"]) != 0 and not party.any(func(p: BattlePokemon): return p.uid == offer["owner_uid"]): return "파티를 떠난 동료의 기술입니다."
    if gold < int(offer["price"]): return "골드가 부족합니다."
    return ""
func buy_shop_card(index: int) -> String:
    var reason := shop_card_reason(index)
    if not reason.is_empty(): return reason
    var offer: Dictionary = shop_cards()[index]
    var card := _allocate_card(offer["key"],int(offer["owner_uid"]))
    gold -= int(offer["price"])
    _stat("gold_cards",int(offer["price"]))
    _stat("cards_bought")
    deck.append(card)
    offer["sold"] = true
    var choice := "상인 카드 구매 · %s · %d 골드" % [TacticalContent.definition(card)["name"],offer["price"]]
    history.append(choice)
    _decision(choice)
    return notify_changed()
func item_reason(key: String,index: int) -> String:
    if key == "ball": return "야생 전투에서 C 또는 포획 버튼을 사용하세요."
    if phase != REST: return "가방의 회복 아이템은 야영지에서 사용하세요. 전투에서는 도구 카드를 사용합니다."
    if not items().has(key) or int(inventory.get(key,0)) <= 0: return "보유한 아이템이 없습니다."
    if index < 0 or index >= party.size(): return "사용할 동료를 선택하세요."
    var pokemon := party[index]
    if key == "blue_pokeblock":
        if pokemon.species_id != 349: return "빈티나의 아름다움을 높이는 간식입니다."
        if not pokemon.alive(): return "기절한 동료를 먼저 회복하세요."
        if pokemon.level >= 100: return "진화하려면 다음 레벨업이 필요합니다."
        if SpecialEvolution.beauty(pokemon) >= SpecialEvolution.BEAUTY_THRESHOLD: return "아름다움 조건을 만족했습니다. 다음 레벨업을 준비하세요."
        return ""
    if EvolutionItems.ITEMS.has(key):
        if not pokemon.alive(): return "기절한 동료를 먼저 회복하세요."
        if EvolutionItems.target(key,pokemon.species_id) == 0: return "이 재료로 진화할 수 없는 동료입니다."
        return ""
    if key == "revive":
        if pokemon.alive(): return "기절한 동료에게 사용하세요."
    elif not pokemon.alive(): return "기절한 동료는 기력의조각으로 회복하세요."
    elif pokemon.hp >= pokemon.max_hp: return "체력이 가득 찼습니다."
    return ""
func use_item(key: String,index: int) -> String:
    var reason := item_reason(key,index)
    if not reason.is_empty(): return reason
    var pokemon := party[index]
    if key == "blue_pokeblock":
        pokemon.beauty = mini(255,SpecialEvolution.beauty(pokemon)+SpecialEvolution.BEAUTY_GAIN)
        inventory[key] = int(inventory[key])-1
        _stat("items_used")
        _decision("빈티나 아름다움 · %d/170" % pokemon.beauty)
        return notify_changed()
    if EvolutionItems.ITEMS.has(key):
        var previous := pokemon.display_name
        TacticalGrowth.evolve(pokemon,EvolutionItems.target(key,pokemon.species_id),VisualCatalog.new())
        inventory[key] = int(inventory[key])-1
        _stat("items_used")
        var choice := "%s → %s · %s" % [previous,pokemon.display_name,items()[key]["name"]]
        history.append(choice)
        _decision("진화 · "+choice)
        return notify_changed()
    var hp_before := pokemon.hp
    if key == "revive":
        pokemon.hp = ceili(pokemon.max_hp*0.5)
        pokemon.knocked_out = false
    else: pokemon.hp = mini(pokemon.max_hp,pokemon.hp+PokemonStats.scale(pokemon,int(items()[key]["heal"])))
    inventory[key] = int(inventory[key])-1
    _stat("items_used")
    _stat("camp_healing",pokemon.hp-hp_before)
    return notify_changed()

func is_wild() -> bool:
    return current()["kind"] == "wild" if full_campaign else step == 0
func items() -> Dictionary:
    var result := TacticalJourneyContent.ITEMS.duplicate(true)
    if full_campaign: result["ball"] = {"name":"몬스터볼","price":35,"stock":4}
    if full_campaign: result.merge(EvolutionItems.ITEMS,true)
    if full_campaign: result.merge(SpecialEvolution.ITEMS,true)
    return result
func quantity(key: String) -> int:
    return balls if key == "ball" else int(inventory.get(key,0))
func experience_reward(species_id := 1) -> float:
    return route.experience_reward(step,species_id) if full_campaign else TacticalJourneyContent.experience_reward(step)
func biome() -> Dictionary:
    return current()["biome"] if full_campaign else VisualCatalog.new().biomes[3]
func progress_title() -> String:
    if not full_campaign: return "%d / 5  ·  %s" % [step+1,current()["name"]]
    return ("바이옴 %d / 8" % (int(current()["chapter"])+1) if int(current()["chapter"]) < 8 else "포켓몬 리그 · %d / 4승" % elite_wins)+"  ·  "+str(current()["name"])

func _prepare_camp() -> void:
    if not camp_states.has(step):
        var state: Dictionary = current()["camp"].duplicate(true) if full_campaign else {"kind":"merchant","offers":items().keys()}
        state["resolved"] = false
        state["outcome"] = ""
        state["stock"] = {}
        if state["kind"] == "merchant":
            for key: String in state["offers"]: state["stock"][key] = items()[key]["stock"]
            state["card_offers"] = MerchantContent.generate(seed_value,step,int(current().get("chapter",0)),deck,party,relics)
            if full_campaign:
                state["evolution_offer"] = EvolutionItems.merchant_offer(seed_value,step,party)
                if party.any(func(p: BattlePokemon): return p.species_id == 349 and p.level < 100 and SpecialEvolution.beauty(p) < SpecialEvolution.BEAUTY_THRESHOLD): state["evolution_offer"] = "blue_pokeblock"
                state["stock"][state["evolution_offer"]] = items()[state["evolution_offer"]]["stock"]
        camp_states[step] = state
    shop_stock = camp_states[step]["stock"]
func camp() -> Dictionary:
    return camp_states.get(step,{})
func shop_items() -> Array:
    var offers: Array = camp().get("offers",[]).duplicate()
    if camp().has("evolution_offer"): offers.append(camp()["evolution_offer"])
    return offers
func camp_choice_reason(choice: int) -> String:
    if phase != REST or not full_campaign: return "야영지의 만남을 확인하세요."
    var state := camp()
    if state.is_empty() or state.get("resolved",false): return "이미 이번 만남을 마쳤습니다."
    if choice == -1: return ""
    if state["kind"] not in ["event","discovery"]: return "선택할 특별한 만남이 없습니다."
    if choice < 0 or choice >= (2 if state["kind"] == "event" else 1): return "표시된 선택지를 고르세요."
    if state.get("id","") == "lesson" and gold < 50: return "수업에는 50골드가 필요합니다."
    return ""
func resolve_camp(choice: int) -> String:
    var reason := camp_choice_reason(choice)
    if not reason.is_empty(): return reason
    var state := camp()
    var outcome := "만남을 지나쳤습니다."
    if choice >= 0:
        if state["kind"] == "discovery":
            var key: String = state["item"]
            _camp_loot(state["title"],0,key,int(state["quantity"]))
            outcome = "%s ×%d 획득" % [items()[key]["name"],state["quantity"]]
        elif state["id"] == "spring":
            if choice == 0:
                for pokemon: BattlePokemon in party:
                    var hp_before := pokemon.hp
                    pokemon.hp = mini(pokemon.max_hp,pokemon.hp+ceili(pokemon.max_hp*0.25))
                    _stat("camp_healing",pokemon.hp-hp_before)
                    pokemon.knocked_out = not pokemon.alive()
                outcome = "치유의 샘 · 전원 HP 25% 회복"
            else:
                _camp_loot(state["title"],0,"super_potion",1)
                outcome = "좋은상처약 1개를 담았습니다."
        elif state["id"] == "lesson":
            gold -= 50
            _stat("gold_events",50)
            var key := "analysis" if choice == 0 else "counter"
            deck.append(_allocate_card(key))
            outcome = TacticalContent.CARDS[key]["name"]+" 카드를 덱에 추가했습니다."
            _decision("전술 수업 · "+str(TacticalContent.CARDS[key]["name"])+" · 50 골드")
        elif state["id"] == "satchel":
            _camp_loot(state["title"],60 if choice == 1 else 0,"ball" if choice == 0 else "",2 if choice == 0 else 0)
            outcome = "몬스터볼 2개 획득" if choice == 0 else "부품을 팔아 60골드를 얻었습니다."
    state["resolved"] = true
    state["outcome"] = outcome
    history.append(str(state["title"])+" · "+outcome)
    return notify_changed()
func _camp_loot(title: String, coins: int, item: String, count: int) -> void:
    gold += coins
    _stat("gold_earned",coins)
    if item == "ball": balls += count
    elif not item.is_empty(): inventory[item] = int(inventory.get(item,0))+count
    loot.append({"name":title,"gold":coins,"item":item,"quantity":count})

func remove_card_reason(uid: int) -> String:
    if phase != REST or camp().get("kind","") != "merchant": return "상인이 있는 야영지에서 카드를 제거할 수 있습니다."
    if camp().get("removed",false): return "이번 상인에게 이미 카드 제거를 의뢰했습니다."
    if gold < removal_price(): return "카드 제거 비용이 부족합니다."
    for card: BattleCardInstance in deck:
        if card.uid != uid: continue
        if deck.size() <= 5: return "덱에는 최소 5장이 필요합니다."
        if card.owner_uid != 0:
            var count := 0
            for other: BattleCardInstance in deck:
                if other.owner_uid == card.owner_uid: count += 1
            if count <= 1: return "동료의 마지막 기술 카드는 제거할 수 없습니다."
        return ""
    return "덱에 없는 카드입니다."
func removal_price() -> int:
    var count := 0
    for state: Dictionary in camp_states.values():
        if state.get("removed",false): count += 1
    return 50+count*25
func remove_card(uid: int) -> String:
    var reason := remove_card_reason(uid)
    if not reason.is_empty(): return reason
    var price := removal_price()
    gold -= price
    _stat("gold_removal",price)
    _stat("cards_removed")
    for card: BattleCardInstance in deck:
        if card.uid == uid:
            var choice := "카드 제거 · %s · %d 골드" % [TacticalContent.definition(card)["name"],price]
            history.append(choice)
            _decision(choice)
            deck.erase(card)
            break
    camp()["removed"] = true
    return notify_changed()
func equip_held(key: String, member_uid: int) -> String:
    if phase != REST: return "지닌 물건은 야영지에서 정리하세요."
    for pokemon: BattlePokemon in party:
        if pokemon.uid != member_uid: continue
        var previous := pokemon.held_item
        if key == previous: return ""
        if not key.is_empty() and key not in held_inventory: return "보유하지 않은 지닌 물건입니다."
        if not key.is_empty(): held_inventory.erase(key)
        pokemon.held_item = key
        if not previous.is_empty(): held_inventory.append(previous)
        return notify_changed()
    return "파티 멤버를 선택하세요."

func bind_battle() -> void:
    if _observed_battle != null and _observed_battle.changed.is_connected(_on_battle_changed): _observed_battle.changed.disconnect(_on_battle_changed)
    _observed_battle = battle
    battle.changed.connect(_on_battle_changed)
func _on_battle_changed() -> void:
    changed.emit()
func notify_changed() -> String:
    changed.emit()
    return ""

func _ensure_statistics() -> void:
    if statistics.is_empty(): statistics = RunStatistics.expedition(true)
func _stat(key: String, amount := 1) -> void:
    _ensure_statistics()
    RunStatistics.increment(statistics["counts"],key,amount)
func _decision(text: String) -> void:
    _ensure_statistics()
    RunStatistics.decision(statistics,step,text)
