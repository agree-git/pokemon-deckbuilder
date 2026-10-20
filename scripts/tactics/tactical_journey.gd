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
var machines: Dictionary = {}
var loot: Array[Dictionary] = []
var rested_steps: Array[int] = []
var shop_stock: Dictionary = {}
var camp_states: Dictionary = {}
var time_of_day := ""
var rare_hunt: Dictionary = {}

func _init(run_seed: int = 2026, selected_relic: String = "field_kit", selected_starters: Array[int] = [], campaign := false,route_version: int = CampaignRoute.VERSION) -> void:
    full_campaign = campaign
    _initialize_run(run_seed,selected_relic,selected_starters,route_version)
func _initialize_run(run_seed: int = 2026, selected_relic: String = "field_kit", selected_starters: Array[int] = [],route_version: int = CampaignRoute.VERSION) -> void:
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
    route = CampaignRoute.new(run_seed,route_version) if full_campaign else null
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
    machines.clear()
    loot.clear()
    rested_steps.clear()
    shop_stock = {}
    camp_states.clear()
    time_of_day = "day"
    rare_hunt.clear()
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
    if full_campaign and route.generation >= 4:
        for pokemon: BattlePokemon in party: _next_pokemon_uid = maxi(_next_pokemon_uid,pokemon.uid+1)
    for pokemon: BattlePokemon in party:
        TacticalGrowth.initialize(pokemon,full_campaign and route.generation >= 4)
        SpecialEvolution.assign_personality(pokemon,seed_value)
        if full_campaign: pokemon.types.assign(_capture_catalog.species(pokemon.species_id)["types"])
    deck.assign(TacticalContent.starting_deck(party))
    _next_card_uid = deck.size()+1
    var opponents := route.opponents(0,route.generation>=28) if full_campaign else TacticalJourneyContent.opponents(0)
    if party.size() == 1: opponents = [opponents[0]]
    battle.player_moves_version=PlayerTechniques.version(route.generation) if full_campaign else 1
    battle.start_with(party,deck,opponents,seed_value,relic,true,relics)
    battle.full_type_chart = full_campaign
    phase = BATTLE
    bind_battle()
    changed.emit()
func current() -> Dictionary:
    if full_campaign and rare_hunt.get("battle_step",-1) == step:
        return RareEncounter.node(route.stops[step],int(rare_hunt["target"]))
    return route.stops[step] if full_campaign else TacticalJourneyContent.STOPS[step]
func opponents_at(index: int) -> Array:
    if full_campaign and rare_hunt.get("battle_step",-1) == index:
        var definitions:=RareEncounter.opponents(route.stops[index],int(rare_hunt["target"]))
        return CampaignChallenge.decorate(definitions,route.stops[index]) if route.generation>=28 else definitions
    # Saved active battles stay intact; apply the correction when creating the next one.
    return route.opponents(index,route.generation>=28) if full_campaign else TacticalJourneyContent.opponents(index)
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
    var coins := battle_gold_reward()
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
    var pokemon := BattlePokemon.new(definition,_allocate_pokemon_uid())
    pokemon.level = parent.level
    TacticalGrowth.initialize(pokemon,full_campaign and route.generation >= 4)
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
func learning_preview(slot: int) -> Dictionary:
    if phase != LEARN or pending_learning.is_empty(): return {}
    var offer := pending_learning[0]
    for pokemon: BattlePokemon in party:
        if pokemon.uid != int(offer["uid"]): continue
        if slot < 0 or slot >= pokemon.learned_skills.size(): return {}
        var previous := pokemon.learned_skills[slot]
        var copies := deck.filter(func(card: BattleCardInstance): return card.owner_uid == pokemon.uid and card.key == previous).size()
        return {"pokemon":pokemon,"previous":previous,"copies":copies,"before":deck.size(),"after":deck.size()+(1 if copies == 0 else 0),"incoming":reward_view({"kind":"card","key":offer["key"],"owner_uid":pokemon.uid,"upgraded":false})}
    return {}
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
        var copies := 0
        for card: BattleCardInstance in deck:
            if card.owner_uid == pokemon.uid and card.key == previous:
                card.key = offer["key"]
                copies += 1
        # A removed old technique has no card to replace. Learning still grants
        # one usable unupgraded card; unrelated deliberately removed cards stay gone.
        if copies == 0: deck.append(_allocate_card(offer["key"],pokemon.uid))
    pending_learning.pop_front()
    _after_learning()
    return notify_changed()
func _prepare_rewards() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ (step*104729+81173)
    if full_campaign and current()["kind"] == "gym" and CoreRelics.selected(relics).is_empty():
        reward_options.assign(CoreRelics.offers(relics,rng))
        phase = REWARD
        return
    var commons: Array = TacticalContent.CARDS.keys().filter(func(key: String): return key != "injury")
    var related := TacticalContent.synergy_cards(deck,relics)
    var candidates: Array = related if not related.is_empty() and rng.randf() < 0.5 else commons
    var first: String = candidates[rng.randi_range(0,candidates.size()-1)]
    reward_options.assign([{"kind":"card","key":first,"owner_uid":0,"upgraded":false}])
    var pokemon := party[rng.randi_range(0,party.size()-1)]
    var learned: Array = TacticalContent.skills_for(pokemon)
    reward_options.append({"kind":"card","key":learned[rng.randi_range(0,learned.size()-1)],"owner_uid":pokemon.uid,"upgraded":current()["kind"] in ["gym","elite"]})
    var available: Array = TacticalContent.RELICS.keys().filter(func(key: String): return key not in relics and key not in CoreRelics.KEYS)
    var roll := rng.randf()
    if not available.is_empty() and (current()["kind"] in ["veteran","gym","elite"] or roll < 0.12):
        reward_options.append({"kind":"relic","key":available[rng.randi_range(0,available.size()-1)]})
    elif roll < 0.65 or current()["kind"] in ["veteran","gym","elite"]:
        var held: Array = HeldItems.reward_keys(route.generation)
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
        var view := TacticalContent.definition(card,PlayerTechniques.version(route.generation) if full_campaign else 1)
        for pokemon: BattlePokemon in party:
            if pokemon.uid == card.owner_uid:
                view["species_id"] = pokemon.species_id
                view["owner_name"] = pokemon.display_name
        return view
    var view: Dictionary = (TacticalContent.RELICS if option["kind"] == "relic" else TacticalContent.HELD_ITEMS)[option["key"]].duplicate(true)
    view["category"] = option["kind"]
    return view

func capture_reason(candidate: TacticalBattle = null) -> String:
    # Preview callers may supply a detached battle; capture() always checks live.
    var combat := candidate if candidate != null else battle
    if phase != BATTLE or not is_wild(): return "트레이너와 관장의 포켓몬은 포획할 수 없습니다."
    if _capture_catalog == null: _capture_catalog = VisualCatalog.new()
    var species := _capture_catalog.species(combat.enemy().species_id)
    if species.is_empty(): return "포획할 수 없는 포켓몬입니다."
    if combat.enemy().species_id in RareEncounter.IDS:
        if not current().get("rare",false) or int(rare_hunt.get("target",0)) != combat.enemy().species_id or rare_hunt.get("captured",false): return "특별한 포획 조건이 필요한 포켓몬입니다."
        var rule := RareEncounter.rule(combat.enemy().species_id)
        if balls < rule["balls"]: return "희귀 포획에는 몬스터볼 %d개가 필요합니다." % rule["balls"]
        if combat.energy < rule["energy"]: return "희귀 포획에는 에너지 %d이 필요합니다." % rule["energy"]
        if combat.enemy().hp*100 > combat.enemy().max_hp*rule["hp_percent"]: return "체력을 %d%% 이하로 낮추세요. 쓰러뜨리면 기회가 끝납니다." % rule["hp_percent"]
    if balls <= 0: return "몬스터볼이 없습니다."
    return combat.capture_reason()
func capture() -> String:
    var reason := capture_reason()
    if not reason.is_empty(): return reason
    var target := battle.enemy()
    var definition := {"id":target.species_id,"name":target.display_name,"type":target.type,"types":target.types.duplicate(),"max_hp":target.max_hp,"level":target.level}
    var rare: bool = current().get("rare",false)
    var rule := RareEncounter.rule(target.species_id)
    battle.capture_enemy(int(rule["energy"]) if rare else 1)
    balls -= int(rule["balls"]) if rare else 1
    if rare: rare_hunt["captured"] = true
    var caught := BattlePokemon.new(definition,_allocate_pokemon_uid())
    TacticalGrowth.initialize(caught,full_campaign and route.generation >= 4)
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
        for key: String in RecruitmentPreview.keys_for(caught): deck.append(_allocate_card(key,caught.uid))
    if pending_captures.is_empty(): _prepare_rewards()
    return notify_changed()
func choose_reward(index: int) -> String:
    if phase != REWARD or index < -1 or index >= reward_options.size(): return "표시된 보상을 선택하세요."
    if index >= 0:
        var option := reward_options[index]
        if option["kind"] == "relic" and option["key"] in CoreRelics.KEYS and not CoreRelics.selected(relics).is_empty(): return "핵심 유물은 원정당 하나만 선택할 수 있습니다."
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
        battle.player_moves_version=PlayerTechniques.version(route.generation) if full_campaign else 1
        battle.start_with(party,deck,opponents_at(step),seed_value+step,relic,true,relics)
        battle.full_type_chart = full_campaign
        phase = BATTLE
        bind_battle()
    return notify_changed()
func rest(action: String = "heal", card_uid: int = 0) -> String:
    if phase != REST: return "야영지에서 휴식할 수 있습니다."
    if action not in ["heal","upgrade"]: return "휴식 또는 카드 강화를 선택하세요."
    if step in rested_steps: return "이번 야영지의 휴식·강화·조사 행동을 이미 사용했습니다."
    if action == "upgrade":
        for card: BattleCardInstance in deck:
            if card.uid == card_uid and TacticalContent.can_upgrade(card,PlayerTechniques.version(route.generation) if full_campaign else 1):
                card.upgraded = true
                rested_steps.append(step)
                var choice := "카드 강화 · "+str(TacticalContent.definition(card,PlayerTechniques.version(route.generation) if full_campaign else 1)["name"])
                history.append(choice)
                _stat("cards_upgraded")
                _decision(choice)
                return notify_changed()
        return "아직 강화하지 않은 카드를 선택하세요."
    _stat("rests")
    for pokemon: BattlePokemon in party:
        var hp_before := pokemon.hp
        FriendshipEvolution.change(pokemon,FriendshipEvolution.REST)
        pokemon.hp = mini(pokemon.max_hp,pokemon.hp+ceili(pokemon.max_hp*CampaignChallenge.rest_percent(self)/100.0))
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
func rare_info() -> Dictionary:
    return rare_hunt.duplicate(true) if not rare_hunt.is_empty() else RareEncounter.initial(seed_value)
func investigate_reason() -> String:
    if phase != REST or not full_campaign: return "정식 원정의 야영지에서 조사하세요."
    if rare_hunt.get("battle_step",-1) >= 0: return "이번 원정의 희귀 조우 도전을 이미 사용했습니다."
    if step in rested_steps: return "이번 야영지의 휴식·강화·조사 행동을 이미 사용했습니다."
    var info := rare_info()
    if info["clues"].size() >= RareEncounter.requirement(info["target"]): return "단서를 모두 모았습니다. 배지와 다음 야생 전투를 확인하세요."
    return ""
func investigate() -> String:
    var reason := investigate_reason()
    if not reason.is_empty(): return reason
    if rare_hunt.is_empty(): rare_hunt = RareEncounter.initial(seed_value)
    rare_hunt["clues"].append(step)
    rested_steps.append(step)
    var choice := "희귀 조우 · 단서 조사 %d / %d" % [rare_hunt["clues"].size(),RareEncounter.requirement(rare_hunt["target"])]
    history.append(choice)
    _decision(choice)
    return notify_changed()
func rare_challenge_reason() -> String:
    if phase != REST or not full_campaign: return "정식 원정의 야영지에서 도전하세요."
    var info := rare_info()
    if info["battle_step"] >= 0: return "원정당 한 번만 도전할 수 있습니다."
    var required := RareEncounter.requirement(info["target"])
    if info["clues"].size() < required: return "단서를 %d개 모으세요." % required
    if badges < required: return "배지 %d개가 필요합니다." % required
    if step+1 >= route.stops.size() or route.stops[step+1]["kind"] != "wild": return "다음 장소가 야생 전투인 야영지에서 도전하세요."
    var cost: int = RareEncounter.rule(info["target"])["balls"]
    if balls < cost: return "포획용 몬스터볼 %d개를 먼저 준비하세요." % cost
    return ""
func challenge_rare() -> String:
    var reason := rare_challenge_reason()
    if not reason.is_empty(): return reason
    rare_hunt["battle_step"] = step+1
    var choice := "희귀 조우 · ??? 도전 예약"
    history.append(choice)
    _decision(choice)
    return notify_changed()
func capture_help() -> String:
    return RareEncounter.capture_help(int(rare_hunt["target"])) if current().get("rare",false) else "몬스터볼 1개 · 에너지 1 · HP 25% 이하\n포획 시 스타팅 영구 해금"
func set_time(value: String) -> String:
    if phase != REST: return "야영지에서 원정 시간대를 준비하세요."
    if value not in ["day","night"]: return "낮 또는 밤을 선택하세요."
    if value == current_time(): return "이미 선택한 시간대입니다."
    time_of_day = value
    _decision("원정 시간 · "+("낮" if value == "day" else "밤"))
    return notify_changed()
func choose_evolution(_uid: int, _target: int) -> String:
    return "진화 분기는 따로 선택하지 않습니다. 조건을 만족하면 레벨업 시 자동 진화합니다."
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
func gold_progression_percent() -> float:
    if not full_campaign: return 100
    # The linear route records departures through step; no new saved counter or RNG.
    var departures := 0
    for index in mini(step,route.stops.size()):
        if route.stops[index]["kind"] == "rest": departures += 1
    return 100.0*pow(1.1,departures)
func scale_gold(base: int) -> int:
    # Remove sub-cent floating noise before rounding whole gold upward (100→110→121).
    return ceili(snappedf(base*gold_progression_percent()/100.0,0.0000001))
func battle_gold_reward() -> int:
    var role: String = current()["kind"]
    return scale_gold(180 if role in ["gym","elite","champion"] else (120 if role == "veteran" else (40 if is_wild() else 80)))
func shop_cards() -> Array:
    # Stored offers remain in their original format for exact save validation.
    var offers: Array = camp().get("card_offers",[]).duplicate(true)
    var old_region_premium := 5*clampi(int(current().get("chapter",0)),0,8) if full_campaign else 0
    for offer: Dictionary in offers:
        # Remove the old region premium from the quote; only departures raise prices.
        offer["price"] = scale_gold(int(offer["price"])-old_region_premium)
        offer["full_price"] = scale_gold(int(offer["full_price"])-old_region_premium)
    return offers
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
    camp()["card_offers"][index]["sold"] = true
    var choice := "상인 카드 구매 · %s · %d 골드" % [TacticalContent.definition(card,PlayerTechniques.version(route.generation) if full_campaign else 1)["name"],offer["price"]]
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
    if EvolutionItems.all_items().has(key):
        if not pokemon.alive(): return "기절한 동료를 먼저 회복하세요."
        if EvolutionItems.target_for(key,pokemon,current_time()) == 0: return "이 재료로 진화할 수 없는 동료입니다."
        if pokemon.content_version >= 2:
            var rule := NationalEvolution.item_rule(key,pokemon,current_time())
            var condition := NationalEvolution.reason(pokemon,rule,current_time())
            if not condition.is_empty(): return condition
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
    if EvolutionItems.all_items().has(key):
        var previous := pokemon.display_name
        TacticalGrowth.evolve(pokemon,EvolutionItems.target_for(key,pokemon,current_time()),VisualCatalog.new())
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
    if full_campaign: result.merge(EvolutionItems.all_items().duplicate(true),true)
    if full_campaign: result.merge(SpecialEvolution.ITEMS.duplicate(true),true)
    for item: Dictionary in result.values(): item["price"] = scale_gold(int(item["price"]))
    return result
func quantity(key: String) -> int:
    return balls if key == "ball" else int(inventory.get(key,0))
func experience_reward(species_id := 1) -> float:
    return route.experience_reward(step,species_id) if full_campaign else TacticalJourneyContent.experience_reward(step)
func biome() -> Dictionary:
    return current()["biome"] if full_campaign else VisualCatalog.new().biomes[3]
func progress_title() -> String:
    if not full_campaign: return "%d / 5  ·  %s" % [step+1,current()["name"]]
    return ("바이옴 %d / 8" % (int(current()["chapter"])+1) if int(current()["chapter"]) < 8 else "포켓몬 리그 · %d / 4승" % elite_wins)+"  ·  "+RareEncounter.public_name(self,current())

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
        if full_campaign: state["machine_offers"] = TechnicalMachines.generate(seed_value,step,party,state["kind"] == "merchant")
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
    if state.get("id","") == "lesson" and gold < scale_gold(50): return "수업에는 %d골드가 필요합니다." % scale_gold(50)
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
            var fee := scale_gold(50)
            gold -= fee
            _stat("gold_events",fee)
            var key := "analysis" if choice == 0 else "counter"
            deck.append(_allocate_card(key))
            outcome = TacticalContent.CARDS[key]["name"]+" 카드를 덱에 추가했습니다."
            _decision("전술 수업 · %s · %d 골드" % [TacticalContent.CARDS[key]["name"],fee])
        elif state["id"] == "satchel":
            _camp_loot(state["title"],60 if choice == 1 else 0,"ball" if choice == 0 else "",2 if choice == 0 else 0)
            outcome = "몬스터볼 2개 획득" if choice == 0 else "부품을 팔아 %d골드를 얻었습니다." % scale_gold(60)
    state["resolved"] = true
    state["outcome"] = outcome
    history.append(str(state["title"])+" · "+outcome)
    return notify_changed()
func _camp_loot(title: String, coins: int, item: String, count: int) -> void:
    coins = scale_gold(coins)
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
    return scale_gold(50+count*25)
func remove_card(uid: int) -> String:
    var reason := remove_card_reason(uid)
    if not reason.is_empty(): return reason
    var price := removal_price()
    gold -= price
    _stat("gold_removal",price)
    _stat("cards_removed")
    for card: BattleCardInstance in deck:
        if card.uid == uid:
            var choice := "카드 제거 · %s · %d 골드" % [TacticalContent.definition(card,PlayerTechniques.version(route.generation) if full_campaign else 1)["name"],price]
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

func _allocate_pokemon_uid() -> int:
    while party.any(func(p: BattlePokemon): return p.uid == _next_pokemon_uid) or pending_captures.any(func(p: BattlePokemon): return p.uid == _next_pokemon_uid):
        _next_pokemon_uid += 1
    var allocated := _next_pokemon_uid
    _next_pokemon_uid += 1
    return allocated

func prepare_evolution(_uid: int,_target: int) -> String:
    return "진화 준비는 필요하지 않습니다. 레벨업 또는 진화 재료 사용 시 조건에 따라 자동으로 결정됩니다."
func change_form(uid: int,target: int,collection: Array = []) -> String:
    if phase != REST: return "폼은 야영지에서 준비하세요."
    for pokemon: BattlePokemon in party:
        if pokemon.uid != uid: continue
        if not pokemon.alive(): return "기절한 동료를 먼저 회복하세요."
        if target == pokemon.species_id: return "현재 모습입니다."
        if target not in PokedexExpansion.forms(pokemon.species_id): return "지역폼은 각 지역의 개체를 포획하거나 진화시켜야 합니다."
        var known := collection.duplicate()
        known.append(pokemon.species_id)
        for member: BattlePokemon in party: known.append(member.species_id)
        if not PokedexExpansion.form_known(target,known): return "합체에 필요한 포켓몬을 먼저 포획하세요."
        var hp_before := pokemon.hp
        pokemon.content_version = 2
        TacticalGrowth.evolve(pokemon,target,VisualCatalog.new())
        pokemon.hp = mini(hp_before,pokemon.max_hp)
        var choice := "폼 준비 · "+pokemon.display_name
        history.append(choice)
        _decision(choice)
        return notify_changed()
    return "파티의 동료를 선택하세요."
func machine_offer_reason(index: int) -> String:
    if phase != REST: return "기술머신은 야영지에서 획득하세요."
    var offers: Array = camp().get("machine_offers",[])
    if index < 0 or index >= offers.size(): return "진열된 기술머신을 선택하세요."
    if offers[index]["taken"]: return "이미 획득한 기술머신입니다."
    if camp().get("kind","") == "merchant" and gold < TechnicalMachines.PRICE: return "골드가 부족합니다."
    return ""
func take_machine(index: int) -> String:
    var reason := machine_offer_reason(index)
    if not reason.is_empty(): return reason
    var offer: Dictionary = camp()["machine_offers"][index]
    if camp()["kind"] == "merchant":
        gold -= TechnicalMachines.PRICE
        _stat("gold_supplies",TechnicalMachines.PRICE)
        _stat("supplies_bought")
    var move := int(offer["move"])
    machines[move] = int(machines.get(move,0))+1
    offer["taken"] = true
    var choice := "기술머신 획득 · "+str(TacticalMoves.definition(TacticalMoves.key_for(move))["name"])
    history.append(choice)
    _decision(choice)
    return notify_changed()
const TRAINING = preload("res://scripts/tactics/camp_move_training.gd")
func training_offers(uid: int) -> Array[int]:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid: return TRAINING.offers(seed_value,step,pokemon)
    return []
func train_move_price(uid: int,move_id: int) -> int:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid: return TRAINING.price(pokemon,move_id)
    return 0
func train_move_reason(uid: int,move_id: int,slot: int,use_machine := false) -> String:
    if phase != REST: return "기술 훈련은 야영지에서 진행하세요."
    if use_machine:
        if not TechnicalMachines.valid(move_id) or int(machines.get(move_id,0)) <= 0: return "보유한 기술머신이 없습니다."
    for pokemon: BattlePokemon in party:
        if pokemon.uid != uid: continue
        if not pokemon.alive(): return "기절한 동료를 먼저 회복하세요."
        var key := TacticalMoves.key_for(move_id)
        if use_machine:
            if move_id not in TechnicalMachines.moves(pokemon.species_id): return "이 포켓몬은 해당 기술머신을 사용할 수 없습니다."
        elif move_id not in training_offers(uid): return "현재 레벨의 자력기 또는 이 포켓몬의 습득 경로에 있는 기술만 훈련할 수 있습니다."
        if key in pokemon.learned_skills: return "이미 배운 기술입니다."
        if slot < 0 or slot > pokemon.learned_skills.size() or slot >= 4: return "교체할 기술을 선택하세요."
        if not use_machine and gold < TRAINING.price(pokemon,move_id): return "기술 훈련에는 %d골드가 필요합니다." % TRAINING.price(pokemon,move_id)
        return ""
    return "파티의 동료를 선택하세요."
func train_move(uid: int,move_id: int,slot: int,use_machine := false) -> String:
    var reason := train_move_reason(uid,move_id,slot,use_machine)
    if not reason.is_empty(): return reason
    for pokemon: BattlePokemon in party:
        if pokemon.uid != uid: continue
        var key := TacticalMoves.key_for(move_id)
        var fee := 0 if use_machine else TRAINING.price(pokemon,move_id)
        pokemon.content_version = 2
        var copies := 0
        if slot < pokemon.learned_skills.size():
            var previous := pokemon.learned_skills[slot]
            pokemon.learned_skills[slot] = key
            for card: BattleCardInstance in deck:
                if card.owner_uid == pokemon.uid and card.key == previous:
                    card.key = key
                    copies += 1
        else: pokemon.learned_skills.append(key)
        if copies == 0: deck.append(_allocate_card(key,pokemon.uid))
        if use_machine: machines[move_id] = int(machines[move_id])-1
        else:
            gold -= fee
            _stat("gold_events",fee)
        var choice := "%s · %s · %s" % ["기술머신 사용" if use_machine else "기술 훈련",pokemon.display_name,TacticalMoves.definition(key)["name"]]
        if not use_machine: choice += " · %d 골드" % fee
        history.append(choice)
        _decision(choice)
        return notify_changed()
    return "파티의 동료를 선택하세요."
