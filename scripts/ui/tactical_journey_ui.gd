class_name TacticalJourneyUI
extends Control
const W = preload("res://scripts/ui/combat_widgets.gd")
var save_button: Button
var _save_session: Node
var journey: TacticalJourney
var battle_ui: TacticalUI
var page := Control.new()
var actions: Array[Button] = []
var deck_open := false
var report_open := false
var deck_action := ""
var upgrade_preview_uid := 0
var recruit_index := -1
var recruit_tab := "added"
var gear_open_for := 0
var deck_button: Button
var deck_close: Button
var camp_tab := "rest"
var camp_tabs: Dictionary = {}
var camp_notice := ""
var bag_item := ""
var evolution_result: Dictionary = {}
var special_open := false
var rare_open := false
var _evolution_catalog := VisualCatalog.new()
var rest_button: Button
var learn_buttons: Array[Button] = []
var travelling := false
var travel: JourneyTravel
var encounter_buttons: Array[Button] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if journey == null: journey = get_node("/root/BattleSession").get("journey")
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):550.0}
    theme = Theme.new()
    theme.default_font = font
    theme.default_font_size = 20
    theme.set_color("font_color","Label",W.TEXT)
    theme.set_color("font_color","Button",W.TEXT)
    for state: String in ["normal","hover","pressed","disabled","focus"]:
        theme.set_stylebox(state,"Button",W.box(Color("20383e") if state in ["hover","pressed"] else Color("14282f"),W.GOLD if state in ["hover","focus"] else Color("405960")))
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(page)
    _save_session = get_node("/root/BattleSession")
    if _save_session.tracks(journey):
        save_button = W.button(self,Rect2(1120,18,240,38),_retry_save)
        save_button.z_index = 60
        save_button.add_theme_font_size_override("font_size",14)
        _save_session.save_status_changed.connect(_save_status)
        _save_status()
    refresh()
func refresh() -> void:
    W.clear(page)
    battle_ui = null
    actions.clear()
    learn_buttons.clear()
    camp_tabs.clear()
    encounter_buttons.clear()
    if journey.phase == TacticalJourney.BATTLE:
        battle_ui = load("res://scenes/tactical_battle.tscn").instantiate()
        battle_ui.battle = journey.battle
        battle_ui.run_mode = true
        battle_ui.run_journey = journey
        battle_ui.run_title = journey.progress_title()
        battle_ui.run_biome = journey.biome()
        battle_ui.capture_action = _capture
        battle_ui.capture_status = func(): return {"wild":journey.is_wild(),"balls":journey.balls,"reason":journey.capture_reason(),"help":journey.capture_help(),"cost":RareEncounter.rule(journey.battle.enemy().species_id)["balls"] if journey.current().get("rare",false) else 1}
        battle_ui.run_continue_requested.connect(_settle)
        battle_ui.run_restart_requested.connect(_restart)
        page.add_child(battle_ui)
        return
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(journey.biome())
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page.add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.025,0.06,0.075,0.87)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page.add_child(shade)
    W.icon(page,journey.biome()["type"],Rect2(48,24,32,32))
    W.label(page,journey.biome()["name"],Rect2(96,16,500,48),24)
    W.label(page,"골드 %d  ·  배지 %d / %d" % [journey.gold,journey.badges,8 if journey.full_campaign else 1],Rect2(1400,16,360,48),17,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    W.icon_button(page,"home",Rect2(1788,18,64,44),_home,"시작 화면")
    var titles := {TacticalJourney.LEARN:"새로운 기술",TacticalJourney.REWARD:"전투 보상",TacticalJourney.CAPTURE:"새로운 동료",TacticalJourney.MAP:"다음 장소",TacticalJourney.REST:"잠시 쉬어갑니다",TacticalJourney.CLEARED:"새로운 챔피언 탄생!" if journey.full_campaign else "레인보배지 획득!",TacticalJourney.FAILED:"원정 종료"}
    W.label(page,titles[journey.phase],Rect2(96,122,1728,70),40,W.GOLD)
    _party()
    match journey.phase:
        TacticalJourney.LEARN: _learning()
        TacticalJourney.REWARD: _rewards()
        TacticalJourney.MAP: _map()
        TacticalJourney.REST: _rest()
        TacticalJourney.CAPTURE: _capture_choice()
        _: _result()
    W.label(page,"ESC 시작 화면     F11 전체 화면",Rect2(96,1014,1728,34),15,W.MUTED)
    if deck_open: _deck()
    if deck_open and upgrade_preview_uid != 0: _upgrade_preview()
    if gear_open_for != 0: _gear_picker()
    if not bag_item.is_empty(): _item_picker()
    if report_open: _report()
    if special_open: _special_picker()
    if rare_open: _rare_picker()
    if not evolution_result.is_empty(): _evolution_reveal()
    if recruit_index >= 0 and journey.phase == TacticalJourney.CAPTURE: _recruitment_preview()
    UiMotion.appear(page)
func _party() -> void:
    var panel := W.panel(page,Rect2(96,280,340,420),Color("14282f"),Color("405960"))
    W.label(panel,"원정대",Rect2(24,18,292,38),23)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        W.sprite(panel,pokemon.species_id,Rect2(20,80+i*82,64,64))
        var title := W.label(panel,"%s · Lv.%d" % [pokemon.display_name,pokemon.level],Rect2(102,77+i*82,218,32),18)
        title.mouse_filter = Control.MOUSE_FILTER_PASS
        title.tooltip_text = PokemonStats.summary(pokemon)
        title.tooltip_text += "\n"+TacticalGrowth.progress_text(pokemon)+"\n"+FriendshipEvolution.summary(pokemon,journey.current_time(),_evolution_catalog)
        if SpecialEvolution.eligible(pokemon.species_id): title.tooltip_text += "\n"+SpecialEvolution.summary(pokemon,journey.party.size(),journey.balls,_evolution_catalog)
        for key: String in EvolutionItems.options(pokemon.species_id):
            title.tooltip_text += "\n%s → %s · 야영지 가방" % [EvolutionItems.ITEMS[key]["name"],_evolution_catalog.species(EvolutionItems.target(key,pokemon.species_id))["name"]]
        var growth := "친밀 %d/220" % FriendshipEvolution.value(pokemon) if FriendshipEvolution.eligible(pokemon.species_id) else TacticalGrowth.progress_text(pokemon)
        if pokemon.species_id == 349: growth = "아름다움 %d/170" % SpecialEvolution.beauty(pokemon)
        var detail := W.label(panel,("%d / %d HP" % [pokemon.hp,pokemon.max_hp] if pokemon.alive() else "기절")+" · "+growth,Rect2(102,111+i*82,218,28),12,W.MUTED)
        detail.name = "Growth_%d" % pokemon.uid
        W.fill_bar(W.bar(panel,Rect2(102,141+i*82,200,4)),pokemon.hp,pokemon.max_hp)
        var experience := W.bar(panel,Rect2(102,148+i*82,200,3),W.GOLD)
        experience.get_child(0).size.x = 200*TacticalGrowth.progress(pokemon)
    deck_button = W.button(panel,Rect2(20,348,300,52),func():
        deck_open = true
        refresh(),"원정 덱 · %d장" % journey.deck.size())
    W.button(page,Rect2(96,718,340,54),func():
        report_open = true
        refresh(),"원정 기록").name = "OpenReport"
func _report() -> void:
    var report := RunReport.new()
    report.name = "RunReport"
    report.journey = journey
    report.closed.connect(func():
        report_open = false
        refresh())
    page.add_child(report)
func _action(title: String, rect: Rect2, callback: Callable, icon := "next") -> Button:
    var button := W.button(page,rect,callback)
    W.icon(button,icon,Rect2(20,(rect.size.y-28)/2,28,28))
    W.label(button,title,Rect2(64,0,rect.size.x-84,rect.size.y),21)
    actions.append(button)
    return button
func _rewards() -> void:
    if not journey.reward_options.is_empty() and journey.reward_options.all(func(o: Dictionary): return o["kind"] == "relic" and o["key"] in CoreRelics.KEYS):
        _core_rewards()
        _growth_summary()
        return
    W.label(page,("배지 획득! · %d / 8  ·  " % journey.badges if journey.full_campaign and journey.current()["kind"] == "gym" else "")+"카드 · 유물 · 지닌 물건 중 보상 하나를 선택하세요.",Rect2(550,225,1200,48),22,W.MUTED)
    for i in journey.reward_options.size():
        var option := journey.reward_options[i]
        var view := journey.reward_view(option)
        if option["kind"] == "card":
            var card := TrainerActionCard.new()
            card.key = option["key"]
            card.definition = view
            card.position = Vector2(650+i*320,310)
            card.pressed.connect(_reward.bind(i))
            page.add_child(card)
            card.update_card(view,"",false)
            card.deal(i*0.06)
            actions.append(card)
        else:
            var button := W.button(page,Rect2(642+i*320,350,266,266),_reward.bind(i))
            W.icon(button,view["icon"],Rect2(101,22,64,64))
            W.label(button,"유물 · 파티 전체" if option["kind"] == "relic" else "지닌 물건 · 야영지에서 장착",Rect2(10,98,246,28),14,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(button,view["name"],Rect2(10,134,246,40),23)
            var detail := W.label(button,view["description"],Rect2(16,182,234,72),16,W.MUTED)
            detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            actions.append(button)
    _action("보상 넘기기",Rect2(870,720,420,64),_reward.bind(-1),"next")
    _growth_summary()
func _core_rewards() -> void:
    W.label(page,"핵심 유물 · 이번 원정에서 하나만 선택",Rect2(550,225,1190,48),25,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER).name = "CoreRewardTitle"
    for i in journey.reward_options.size():
        var view := journey.reward_view(journey.reward_options[i])
        var button := W.button(page,Rect2(550+i*404,320,382,366),_reward.bind(i))
        button.name = "CoreReward_%d" % i
        button.tooltip_text = view["description"]
        W.icon(button,view["icon"],Rect2(159,24,64,64))
        W.label(button,view["name"],Rect2(20,106,342,48),27,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
        var benefit := W.label(button,view["benefit"],Rect2(26,176,330,90),21,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var price := W.label(button,"대가 · "+str(view["tradeoff"]).replace(" · ","\n"),Rect2(26,280,330,68),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        actions.append(button)
    var skip_text := "이번에는 넘기기 · 다음 관장에서 다시 선택" if int(journey.current()["chapter"]) < 7 else "핵심 유물 없이 계속 진행"
    _action(skip_text,Rect2(710,720,880,64),_reward.bind(-1),"next")
func _growth_summary() -> void:
    for i in journey.growth_reports.size():
        var report := journey.growth_reports[i]
        var panel := W.panel(page,Rect2(550+i*404,832,382,140),Color("172d32"),Color("475b50"))
        W.icon(panel,"boost",Rect2(18,18,24,24))
        var title := "%s · Lv.%d → %d" % [report["name"],report["before"],report["after"]]
        if not report["evolutions"].is_empty(): title = report["name"]+" → "+str(report["evolutions"].back()["name"])
        W.label(panel,title,Rect2(54,10,312,40),19,W.GOLD)
        W.label(panel,"+%s XP  ·  최대 HP +%d" % [String.num(report["xp"],1).trim_suffix(".0"),report["hp"]],Rect2(18,58,348,28),16,W.MUTED)
        W.label(panel,report.get("companion"," · ".join(report["learned"])+" 습득" if not report["learned"].is_empty() else ("자동 진화!" if not report["evolutions"].is_empty() else "다음 레벨을 향해!")),Rect2(18,96,348,28),17,W.TEXT)
func _map() -> void:
    W.label(page,journey.progress_title(),Rect2(550,225,1200,48),24)
    var stops: Array = journey.route.stops if journey.full_campaign else TacticalJourneyContent.STOPS
    var visible_steps: Array[int] = []
    for i in stops.size():
        if not journey.full_campaign or (stops[i]["chapter"] == journey.current()["chapter"] and (int(stops[i]["chapter"]) < 8 or stops[i]["kind"] != "rest")): visible_steps.append(i)
    if journey.full_campaign:
        visible_steps = visible_steps.filter(func(i: int): return stops[i]["kind"] != "rest")
    var columns := 4 if journey.full_campaign else visible_steps.size()
    var width := 1190.0/columns
    for column in visible_steps.size():
        var i := visible_steps[column]
        var stop: Dictionary = stops[i]
        if journey.full_campaign and journey.rare_hunt.get("battle_step",-1) == i:
            stop = RareEncounter.node(stop,int(journey.rare_hunt["target"]))
        var highlighted: bool = i == journey.step or (journey.current()["kind"] == "rest" and i == journey.step-1)
        var height := 148.0 if journey.full_campaign else 220.0
        var panel := W.panel(page,Rect2(550+(column%columns)*width,310+floori(column/float(columns))*164,width-12,height),Color("20383e") if highlighted else Color("14282f"),W.GOLD if highlighted else Color("405960"))
        panel.name = "Encounter_%d" % i
        W.icon(panel,"check" if i < journey.step else ("attack" if stop["kind"] in ["trainer","veteran"] else stop["icon"]),Rect2(18,20,34,34))
        W.label(panel,str(column+1),Rect2(width-64,20,38,30),17,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
        W.label(panel,stop["name"].replace(" · ","\n"),Rect2(18,62,width-48,60),17,W.TEXT)
        if journey.full_campaign:
            var final_battle: bool = stop["kind"] == "champion"
            W.icon(panel,"badge" if final_battle else "heal",Rect2(width-42,height-28,16,16))
            panel.mouse_filter = Control.MOUSE_FILTER_PASS
            panel.tooltip_text = ("승리하면 챔피언 등극" if final_battle else "전투 후 야영지")+" · 적 Lv.%d" % stop["level"]
            var opponents: Array = journey.opponents_at(i)
            if not opponents.is_empty() and opponents[0].has("boss"): panel.tooltip_text += "\n고유 전술 · "+BossTactics.heading(opponents[0])
            for opponent: Dictionary in opponents:
                panel.tooltip_text += "\n%s · %s · %s" % [opponent["name"],EnemyTactics.role_title(opponent),EnemyTactics.pattern_text(opponent)]
    W.label(page,"장소에 마우스를 올리면 상대 전술을 확인할 수 있습니다.",Rect2(550,274,1190,28),14,W.MUTED)
    _action("%s로 이동" % journey.current()["name"],Rect2(820,670,560,64),_enter)
    if journey.full_campaign:
        W.label(page,"원정 경로 · 배지 %d / 8" % journey.badges,Rect2(550,748,1190,36),19,W.MUTED)
        for i in 8:
            var biome := journey.route.biomes[i]
            var panel := W.panel(page,Rect2(550+i*150,800,138,106),Color("20383e"),W.GOLD if i < journey.badges else Color("405960"))
            W.icon(panel,"badge" if i < journey.badges else biome["type"],Rect2(51,12,32,32))
            W.label(panel,biome["name"],Rect2(4,57,130,40),13,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        W.label(page,"배지 8개 → 사천왕 4명 → 챔피언 · "+str(journey.route.champion["name"]),Rect2(550,932,1190,40),20,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
func _learning() -> void:
    var offer := journey.pending_learning[0]
    var pokemon: BattlePokemon
    for member: BattlePokemon in journey.party:
        if member.uid == int(offer["uid"]): pokemon = member
    var move := TacticalMoves.definition(offer["key"])
    W.sprite(page,pokemon.species_id,Rect2(1000,230,144,144))
    W.label(page,"%s · Lv.%d" % [pokemon.display_name,pokemon.level],Rect2(550,385,1190,44),26,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"Lv.%d에 %s 습득 가능" % [offer["level"],move["name"]],Rect2(550,440,1190,48),27,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,move["description"],Rect2(550,502,1190,44),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"기술은 네 개까지 · 교체한 기술의 덱 사본도 함께 바뀝니다. 강화는 유지됩니다.",Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    for i in pokemon.learned_skills.size():
        var known := TacticalMoves.definition(pokemon.learned_skills[i])
        var button := _action("QWER"[i]+" · "+str(known["name"]),Rect2(550+(i%2)*606,636+floori(i/2.0)*92,584,76),_learn.bind(i),"switch")
        button.tooltip_text = known["description"]
        learn_buttons.append(button)
    _action("새 기술 배우지 않기",Rect2(870,875,560,64),_learn.bind(-1),"next")
func _learn(slot: int) -> void:
    if journey.resolve_learning(slot).is_empty(): refresh()
func _camp_tab(tab: String) -> void:
    camp_tab = tab
    camp_notice = ""
    refresh()
func _rest() -> void:
    var encounter := journey.camp()
    W.label(page,encounter.get("description","필요한 만큼 준비한 뒤 출발하세요."),Rect2(550,204,1190,40),20,W.MUTED)
    var encounter_tab := "shop" if encounter.get("kind","") == "merchant" else "encounter"
    var keys := ["rest",encounter_tab,"bag","gear"]
    var labels := ["휴식·강화",encounter.get("title","아이템 구매"),"가방","장비·유물"]
    if camp_tab not in keys: camp_tab = "rest"
    for i in keys.size():
        var key: String = keys[i]
        var button := W.button(page,Rect2(550+i*300,266,284,64),_camp_tab.bind(key),labels[i])
        if key == camp_tab: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
        camp_tabs[key] = button
    _action("준비 완료 · 출발",Rect2(1260,930,480,72),_leave_camp,"next")
    match camp_tab:
        "rest":
            if journey.full_campaign:
                var hunt := journey.rare_info()
                W.button(page,Rect2(800,354,292,44),func():
                    rare_open = true
                    refresh(),"희귀 조우 · %d/%d" % [hunt["clues"].size(),RareEncounter.requirement(hunt["target"])]).name = "RareEncounter"
            if journey.party.any(func(p: BattlePokemon): return SpecialEvolution.eligible(p.species_id)):
                W.button(page,Rect2(550,354,220,44),func():
                    special_open = true
                    refresh(),"진화 준비").name = "SpecialEvolution"
            W.label(page,"원정 시간",Rect2(1270,354,150,44),17,W.MUTED)
            for i in 2:
                var value: String = ["day","night"][i]
                var time_button := W.button(page,Rect2(1440+i*150,354,136,44),_set_time.bind(value),"낮" if value == "day" else "밤")
                time_button.name = "Time_"+value
                time_button.disabled = journey.current_time() == value
                if time_button.disabled:
                    time_button.add_theme_stylebox_override("disabled",W.box(Color("29443f"),W.GOLD))
                    time_button.add_theme_color_override("font_disabled_color",W.GOLD)
                time_button.tooltip_text = "이브이의 다음 레벨업 진화에 적용 · 낮: 에브이 / 밤: 블래키\n휴식·강화 행동이나 친밀도를 소비하지 않습니다."
            W.icon(page,"heal",Rect2(1065,420,96,96))
            W.label(page,"전원 체력 50% 회복 · 기절 회복 · 부상 제거 · 친밀도 +5",Rect2(550,530,1190,60),25,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(page,"휴식·카드 강화·희귀 조우 단서 조사 중 하나를 선택하세요.
가방·장비·만남은 별도로 이용할 수 있습니다.",Rect2(550,610,1190,90),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
            rest_button = W.button(page,Rect2(650,742,500,78),_camp_rest,"야영 행동 사용 완료" if journey.step in journey.rested_steps else "휴식하기")
            rest_button.disabled = journey.step in journey.rested_steps
            var upgrade := W.button(page,Rect2(1190,742,500,78),_select_deck_action.bind("upgrade"),"카드 강화 선택")
            upgrade.name = "Upgrade"
            upgrade.disabled = journey.step in journey.rested_steps or not journey.deck.any(func(card: BattleCardInstance): return TacticalContent.can_upgrade(card))
            actions.append(upgrade)
        "encounter": _encounter()
        "shop": _shop()
        "gear": _gear()
        "bag": _bag()
    W.label(page,camp_notice,Rect2(550,870,1190,40),20,W.GOLD)
func _bag() -> void:
    var scroll := ScrollContainer.new()
    scroll.name = "BagScroll"
    scroll.position = Vector2(550,382)
    scroll.size = Vector2(1200,440)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)
    var body := Control.new()
    scroll.add_child(body)
    var i := 0
    for key: String in journey.items():
        # Materials appear when owned; keep an empty bag compact.
        if (EvolutionItems.ITEMS.has(key) or SpecialEvolution.ITEMS.has(key)) and journey.quantity(key) == 0: continue
        var item: Dictionary = journey.items()[key]
        var button := W.button(body,Rect2((i%3)*400,floori(i/3.0)*210,376,184),_open_item.bind(key))
        button.name = "Bag_"+key
        _item_sprite(button,key,Rect2(143,24,90,90))
        W.label(button,item["name"],Rect2(20,126,336,40),23,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        W.label(button,"×%d" % journey.quantity(key),Rect2(280,10,76,32),18,W.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
        button.disabled = journey.quantity(key) == 0 or key == "ball"
        button.tooltip_text = _item_description(key)
        i += 1
    body.custom_minimum_size = Vector2(1176,ceilf(i/3.0)*210-26)
func _item_description(key: String) -> String:
    if key == "blue_pokeblock": return "빈티나 아름다움 +60 · 170 이상으로 다음 레벨업 시 진화"
    if EvolutionItems.ITEMS.has(key): return EvolutionItems.description(key)
    if key == "ball": return "야생 전투에서 C로 포획"
    return "기절한 동료 HP 50% 회복" if key == "revive" else "최대 HP의 %s 회복" % PokemonStats.percent(int(journey.items()[key]["heal"]))
func _shop() -> void:
    W.label(page,"카드",Rect2(550,345,650,38),23,W.GOLD)
    W.label(page,"보급품",Rect2(1250,345,490,38),23,W.GOLD)
    var offers := journey.shop_cards()
    if offers.is_empty():
        W.label(page,"이번 상인은 보급품만 판매합니다.",Rect2(550,490,650,100),22,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    for i in offers.size():
        var offer: Dictionary = offers[i]
        var x := 550+i*224
        var view := journey.reward_view(offer)
        var card := TrainerActionCard.new()
        card.name = "ShopCard_%d" % i
        card.key = offer["key"]
        card.definition = view
        card.position = Vector2(x,362)
        page.add_child(card)
        card.update_card(view,"",false)
        card.disabled = true
        card.mouse_default_cursor_shape = Control.CURSOR_ARROW
        if offer["sold"]: card.modulate = Color(0.55,0.62,0.63)
        var owned := journey.deck.filter(func(c: BattleCardInstance): return c.key == offer["key"] and c.owner_uid == offer["owner_uid"]).size()
        W.label(page,"보유 %d장" % owned+(" · 20골드 할인" if offer["sale"] else ""),Rect2(x,686,202,32),15,W.GOLD if offer["sale"] else W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        var button := W.button(page,Rect2(x,730,202,56),_buy_card.bind(i),"판매 완료" if offer["sold"] else "%d 골드 · 구매" % offer["price"])
        button.name = "BuyCard_%d" % i
        button.add_theme_font_size_override("font_size",17)
        button.disabled = not journey.shop_card_reason(i).is_empty()
        button.tooltip_text = ("원가 %d → %d 골드\n" % [offer["full_price"],offer["price"]] if offer["sale"] else "")+journey.shop_card_reason(i)
        actions.append(button)
    var row := 0
    for key: String in journey.items():
        if journey.full_campaign and key not in journey.shop_items(): continue
        var item: Dictionary = journey.items()[key]
        var y := 390+row*(122 if journey.full_campaign else 104)
        var panel := W.panel(page,Rect2(1250,y,490,114 if journey.full_campaign else 100),Color("172d32"))
        _item_sprite(panel,key,Rect2(16,15,54,54))
        W.label(panel,"%s · %d골드" % [item["name"],item["price"]],Rect2(84,12,270,34),19,W.TEXT)
        W.label(panel,"재고 %d · 보유 %d" % [journey.shop_stock.get(key,0),journey.quantity(key)],Rect2(84,52,270,28),16,W.MUTED)
        var button := W.button(panel,Rect2(368,19,106,68),_buy.bind(key),"구매")
        button.name = "Buy_"+key
        button.disabled = not journey.buy_reason(key).is_empty()
        button.tooltip_text = journey.buy_reason(key)
        panel.mouse_filter = Control.MOUSE_FILTER_PASS
        panel.tooltip_text = _item_description(key)
        actions.append(button)
        row += 1
    var remove := W.button(page,Rect2(550,812,650,54),_select_deck_action.bind("remove"),"카드 제거 완료" if journey.camp().get("removed",false) else "카드 제거 · %d 골드" % journey.removal_price())
    remove.name = "Remove"
    remove.disabled = journey.camp().get("removed",false) or journey.gold < journey.removal_price()
    remove.tooltip_text = "상인당 1장 · 다음 제거 비용 +25골드. 휴식·강화 행동은 소비하지 않습니다."
    actions.append(remove)
    if row <= 3: W.label(page,"구매한 카드는 원정 덱에 추가됩니다.\n가방의 회복약을 쓰면 휴식 대신 강화할 수 있습니다.",Rect2(1250,790,490,80),16,W.MUTED)
func _item_sprite(parent: Node, key: String, rect: Rect2) -> TextureRect:
    var texture := TextureRect.new()
    texture.texture = load("res://assets/items/%s.png" % key)
    texture.position = rect.position
    texture.size = rect.size
    texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(texture)
    return texture
func _open_item(key: String) -> void:
    if journey.phase != TacticalJourney.REST or journey.quantity(key) == 0 or key == "ball": return
    bag_item = key
    refresh()
func _close_item() -> void:
    bag_item = ""
    refresh()
func _item_picker() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_item)
    overlay.name = "ItemPicker"
    overlay.z_index = 85
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.78),Color.TRANSPARENT,0))
    var body := W.panel(overlay,Rect2(570,190,780,700),Color("14282f"),W.GOLD)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    _item_sprite(body,bag_item,Rect2(30,28,60,60))
    W.label(body,journey.items()[bag_item]["name"]+" · 사용할 동료",Rect2(112,24,550,64),26,W.GOLD)
    if EvolutionItems.ITEMS.has(bag_item):
        W.label(body,"현재 기술은 유지 · 이후에는 진화형의 레벨업 기술을 배웁니다.",Rect2(32,88,716,28),16,W.MUTED)
    W.icon_button(body,"close",Rect2(700,28,48,48),_close_item,"닫기 · Esc").name = "Close"
    for i in journey.party.size():
        var p := journey.party[i]
        var reason := journey.item_reason(bag_item,i)
        var button := W.button(body,Rect2(32,126+i*168,716,146),_use_item.bind(bag_item,i))
        button.name = "Use_%s_%d" % [bag_item,i]
        button.disabled = not reason.is_empty()
        if button.disabled: button.self_modulate = Color(0.58,0.65,0.65)
        W.sprite(button,p.species_id,Rect2(18,18,104,104))
        W.label(button,"%s · Lv.%d" % [p.display_name,p.level],Rect2(152,18,520,38),24)
        var preview := reason
        if reason.is_empty():
            if EvolutionItems.ITEMS.has(bag_item):
                var target := EvolutionItems.target(bag_item,p.species_id)
                preview = "→ %s · 진화하기" % _evolution_catalog.species(target)["name"]
                W.sprite(button,target,Rect2(572,22,96,96))
            elif bag_item == "blue_pokeblock": preview = "아름다움 %d → %d / 170" % [SpecialEvolution.beauty(p),mini(255,SpecialEvolution.beauty(p)+60)]
            else:
                var healing := ceili(p.max_hp*0.5) if bag_item == "revive" else PokemonStats.scale(p,int(journey.items()[bag_item]["heal"]))
                preview = "HP %d / %d  →  %d / %d" % [p.hp,p.max_hp,mini(p.max_hp,p.hp+healing),p.max_hp]
        W.label(button,preview,Rect2(152,64,416 if EvolutionItems.ITEMS.has(bag_item) else 520,35),19,W.MUTED)
        W.fill_bar(W.bar(button,Rect2(152,117,510,7)),p.hp,p.max_hp)
        button.tooltip_text = reason
        if reason.is_empty() and EvolutionItems.ITEMS.has(bag_item):
            var next_moves: Array[String] = []
            for entry: Dictionary in TacticalGrowth.species_data(EvolutionItems.target(bag_item,p.species_id))["learnset"]:
                if int(entry["level"]) > p.level:
                    next_moves.append("Lv.%d · %s" % [entry["level"],TacticalMoves.definition(TacticalMoves.key_for(int(entry["move"])))["name"]])
            button.tooltip_text = "진화 후 레벨업 기술\n"+("새로 배울 기술이 없습니다. 필요한 기술을 먼저 배운 뒤 진화할 수 있습니다." if next_moves.is_empty() else "\n".join(next_moves))
    UiMotion.appear(overlay)
func _close_special() -> void:
    special_open = false
    refresh()
func _close_rare() -> void:
    rare_open = false
    refresh()
func _rare_picker() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_rare)
    overlay.name = "RarePicker"
    overlay.z_index = 86
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.8),Color.TRANSPARENT,0))
    var body := W.panel(overlay,Rect2(420,150,1080,780),Color("14282f"),W.GOLD)
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,"희귀 조우",Rect2(32,24,900,52),30,W.GOLD)
    W.icon_button(body,"close",Rect2(1004,24,48,48),_close_rare,"닫기 · Esc")
    var hunt := journey.rare_info()
    var id: int = hunt["target"]
    var required := RareEncounter.requirement(id)
    W.sprite(body,id,Rect2(64,112,192,192))
    var rule := RareEncounter.rule(id)
    W.label(body,str(_evolution_catalog.species(id)["name"])+" · "+str(rule["name"]),Rect2(310,114,690,50),30,W.TEXT).name = "RareTarget"
    var status := "단서 %d / %d   ·   배지 %d / %d" % [hunt["clues"].size(),required,journey.badges,required]
    if hunt["battle_step"] >= 0:
        status = "포획 성공 · 스타팅 영구 해금" if hunt["captured"] else ("다음 야생 전투에 도전 예약됨" if journey.step < hunt["battle_step"] else "이번 원정의 도전 종료")
    W.label(body,status,Rect2(310,186,720,90),23,W.GOLD).name = "RareProgress"
    var description := "① 야영지 조사 1회 = 단서 1개 · 해당 야영지의 휴식·강화 대신 사용\n② 단서와 배지를 모아 다음 야생 전투를 희귀 조우로 변경 · 원정당 1회\n③ 기존 야생보다 %d레벨 높은 상대 · HP %d%% 이하에서 확정 포획\n몬스터볼 %d개 + 에너지 %d 필요 · 쓰러뜨리면 포획 기회 종료\n포획 후 풀어주거나 원정에 실패해도 다음 스타팅으로 선택 가능" % [rule["level_bonus"],rule["hp_percent"],rule["balls"],rule["energy"]]
    W.label(body,description,Rect2(32,334,1016,184),20,W.MUTED).name = "RareConditions"
    var investigate_reason := journey.investigate_reason()
    var investigate := W.button(body,Rect2(32,550,490,76),_rare_action.bind(false),"단서 조사 · 휴식 행동 사용")
    investigate.name = "InvestigateRare"
    investigate.disabled = not investigate_reason.is_empty()
    investigate.tooltip_text = investigate_reason
    W.label(body,investigate_reason,Rect2(32,644,490,90),18,W.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var challenge_reason := journey.rare_challenge_reason()
    var challenge := W.button(body,Rect2(550,550,490,76),_rare_action.bind(true),"다음 야생 전투에서 도전")
    challenge.name = "ChallengeRare"
    challenge.disabled = not challenge_reason.is_empty()
    challenge.tooltip_text = challenge_reason
    W.label(body,challenge_reason,Rect2(550,644,490,90),18,W.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UiMotion.appear(overlay)
func _rare_action(challenge: bool) -> void:
    var reason := journey.challenge_rare() if challenge else journey.investigate()
    camp_notice = reason if not reason.is_empty() else ("다음 야생 전투에 희귀 조우를 예약했습니다." if challenge else "단서를 조사했습니다. 이번 야영지의 휴식·강화 행동을 사용했습니다.")
    refresh()
func _special_picker() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_special)
    overlay.name = "SpecialPicker"
    overlay.z_index = 85
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.8),Color.TRANSPARENT,0))
    var body := W.panel(overlay,Rect2(420,150,1080,780),Color("14282f"),W.GOLD)
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,"진화 준비",Rect2(32,24,900,52),30,W.GOLD)
    W.icon_button(body,"close",Rect2(1004,24,48,48),_close_special,"닫기 · Esc")
    var row := 0
    for p: BattlePokemon in journey.party:
        if not SpecialEvolution.eligible(p.species_id): continue
        var panel := W.panel(body,Rect2(28,100+row*210,1024,194),Color("1c3339"))
        W.sprite(panel,p.species_id,Rect2(16,22,112,112))
        W.label(panel,"%s · Lv.%d" % [p.display_name,p.level],Rect2(152,10,830,38),23,W.GOLD)
        var detail := W.label(panel,SpecialEvolution.summary(p,journey.party.size(),journey.balls,_evolution_catalog),Rect2(152,54,840,86),18,W.MUTED)
        detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        detail.name = "SpecialSummary_%d" % p.uid
        if p.species_id == 236:
            for i in 3:
                var target: int = SpecialEvolution.TYROGUE_CHOICES[i]
                var button := W.button(panel,Rect2(152+i*230,146,214,40),_choose_evolution.bind(p.uid,target),str(_evolution_catalog.species(target)["name"]))
                button.name = "Evolution_%d_%d" % [p.uid,target]
                button.disabled = SpecialEvolution.choice(p) == target or p.level >= 100
                if SpecialEvolution.choice(p) == target:
                    button.add_theme_stylebox_override("disabled",W.box(Color("29443f"),W.GOLD))
                    button.add_theme_color_override("font_disabled_color",W.GOLD)
        row += 1
    UiMotion.appear(overlay)
func _choose_evolution(uid: int, target: int) -> void:
    var reason := journey.choose_evolution(uid,target)
    if not reason.is_empty(): camp_notice = reason
    refresh()
func _close_evolution() -> void:
    evolution_result.clear()
    refresh()
func _evolution_reveal() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_evolution)
    overlay.name = "EvolutionReveal"
    overlay.z_index = 90
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.85),Color.TRANSPARENT,0))
    var body := W.panel(overlay,Rect2(510,215,900,650),Color("14282f"),W.GOLD)
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,"축하합니다!",Rect2(40,35,820,60),34,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.sprite(body,int(evolution_result["from"]),Rect2(95,160,240,240))
    W.label(body,"→",Rect2(370,225,100,70),48,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var evolved := W.sprite(body,int(evolution_result["to"]),Rect2(515,125,300,300))
    evolved.pivot_offset = evolved.size/2
    evolved.scale = Vector2.ONE*0.35
    var tween := UiMotion.begin(evolved,"evolve",true)
    tween.tween_property(evolved,"scale",Vector2.ONE,0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    W.label(body,"%s → %s" % [evolution_result["before"],evolution_result["after"]],Rect2(40,440,820,60),28,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.button(body,Rect2(290,540,320,64),_close_evolution,"계속").name = "CloseEvolution"
    UiMotion.appear(overlay)
func _gear() -> void:
    W.label(page,"지닌 물건 · 동료당 하나, 야영지에서 자유롭게 교환",Rect2(550,354,1190,36),21,W.GOLD)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        var y := 406+i*100
        W.label(page,pokemon.display_name,Rect2(550,y,250,40),22)
        var selector := W.button(page,Rect2(830,y,440,52),_open_gear.bind(pokemon.uid),"물건 선택" if pokemon.held_item.is_empty() else str(TacticalContent.HELD_ITEMS[pokemon.held_item]["name"]))
        selector.name = "Equipment_%d" % pokemon.uid
        if not pokemon.held_item.is_empty():
            W.label(page,TacticalContent.HELD_ITEMS[pokemon.held_item]["description"],Rect2(550,y+52,1190,34),17,W.MUTED)
    W.label(page,"파티 유물 · %d개" % journey.relics.size(),Rect2(550,732,1190,36),21,W.GOLD)
    for i in journey.relics.size():
        var definition: Dictionary = TacticalContent.RELICS[journey.relics[i]]
        var button := W.button(page,Rect2(550+(i%4)*298,780+floori(i/4.0)*46,282,40),func(): pass,definition["name"])
        button.tooltip_text = definition["description"]
func _open_gear(uid: int) -> void:
    gear_open_for = uid
    refresh()
func _close_gear() -> void:
    gear_open_for = 0
    refresh()
func _gear_picker() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_gear)
    overlay.name = "EquipmentPicker"
    for state: String in ["normal","hover","pressed","focus"]:
        overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.85),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(550,150,1040,780),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"지닌 물건 선택",Rect2(32,22,820,52),28,W.GOLD)
    W.icon_button(panel,"close",Rect2(950,28,48,48),_close_gear,"닫기 · Esc")
    var keys: Array[String] = [""]
    for pokemon: BattlePokemon in journey.party:
        if pokemon.uid == gear_open_for and not pokemon.held_item.is_empty(): keys.append(pokemon.held_item)
    for key: String in journey.held_inventory:
        if key not in keys: keys.append(key)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32,100)
    scroll.size = Vector2(976,640)
    panel.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.custom_minimum_size.x = 950
    rows.add_theme_constant_override("separation",12)
    scroll.add_child(rows)
    for key: String in keys:
        var definition: Dictionary = TacticalContent.HELD_ITEMS.get(key,{"name":"장착 해제","description":"지닌 물건을 가방에 돌려놓습니다.","icon":"switch"})
        var button := W.button(rows,Rect2(0,0,950,98),_equip.bind(key,gear_open_for))
        button.custom_minimum_size = Vector2(950,98)
        button.name = "Equip_"+key
        W.icon(button,definition["icon"],Rect2(18,28,36,36))
        W.label(button,definition["name"],Rect2(76,10,850,36),22,W.TEXT)
        W.label(button,definition["description"],Rect2(76,52,850,36),17,W.MUTED)
func _equip(key: String,uid: int) -> void:
    var reason := journey.equip_held(key,uid)
    camp_notice = reason if not reason.is_empty() else "지닌 물건을 정리했습니다."
    if reason.is_empty(): gear_open_for = 0
    refresh()
func _select_deck_action(action: String) -> void:
    upgrade_preview_uid = 0
    deck_action = action
    deck_open = true
    refresh()
func _encounter() -> void:
    var encounter := journey.camp()
    W.icon(page,encounter["icon"],Rect2(1060,366,80,80))
    W.label(page,encounter["title"],Rect2(550,474,1190,54),30,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    if encounter.get("resolved",false):
        W.label(page,encounter["outcome"],Rect2(550,580,1190,70),24,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        return
    var options: Array = encounter.get("choices",[]).duplicate()
    if encounter["kind"] == "discovery": options = ["%s ×%d 줍기" % [journey.items()[encounter["item"]]["name"],encounter["quantity"]]]
    for i in options.size():
        var button := W.button(page,Rect2(650+i*550,588,520,76),_camp_choice.bind(i),options[i])
        button.name = "CampChoice_%d" % i
        button.disabled = not journey.camp_choice_reason(i).is_empty()
        button.tooltip_text = journey.camp_choice_reason(i)
        encounter_buttons.append(button)
        actions.append(button)
    if not options.is_empty():
        var skip := W.button(page,Rect2(870,722,560,64),_camp_choice.bind(-1),"지나치기")
        skip.name = "CampChoice_skip"
        encounter_buttons.append(skip)
        actions.append(skip)
func _camp_choice(choice: int) -> void:
    if travelling: return
    var reason := journey.resolve_camp(choice)
    camp_notice = reason if not reason.is_empty() else journey.camp()["outcome"]
    refresh()
func _camp_rest() -> void:
    var reason := journey.rest()
    camp_notice = reason if not reason.is_empty() else "동료들이 기운을 회복했습니다."
    refresh()
func _set_time(value: String) -> void:
    var reason := journey.set_time(value)
    camp_notice = reason if not reason.is_empty() else ("낮" if value == "day" else "밤")+"에 다음 전투를 시작합니다."
    refresh()
func _buy(key: String) -> void:
    var reason := journey.buy(key)
    camp_notice = reason if not reason.is_empty() else str(journey.items()[key]["name"])+" 구매 완료"
    refresh()
func _buy_card(index: int) -> void:
    if travelling: return
    var card_name := str(journey.reward_view(journey.shop_cards()[index])["name"])
    var reason := journey.buy_shop_card(index)
    camp_notice = reason if not reason.is_empty() else card_name+" · 원정 덱에 추가했습니다."
    refresh()
func _use_item(key: String,index: int) -> void:
    var pokemon := journey.party[index]
    var before := {"from":pokemon.species_id,"before":pokemon.display_name}
    var reason := journey.use_item(key,index)
    camp_notice = reason if not reason.is_empty() else journey.party[index].display_name+"에게 사용했습니다."
    if reason.is_empty() and key == "blue_pokeblock": camp_notice = "빈티나 아름다움 %d/170" % SpecialEvolution.beauty(pokemon)+(" · 다음 레벨업에 진화합니다." if SpecialEvolution.beauty(pokemon) >= 170 else "")
    if reason.is_empty(): bag_item = ""
    if reason.is_empty() and pokemon.species_id != before["from"]:
        evolution_result = before.merged({"to":pokemon.species_id,"after":pokemon.display_name})
    refresh()
func _leave_camp() -> void:
    if journey.leave_camp().is_empty():
        camp_tab = "rest"
        camp_notice = ""
        refresh()
func _result() -> void:
    var cleared := journey.phase == TacticalJourney.CLEARED
    W.icon(page,"badge" if cleared else "injury",Rect2(1056,280,112,112))
    W.label(page,("챔피언 %s 격파 · 명예의 전당에 올랐습니다." % journey.route.champion["name"] if journey.full_campaign else "민화의 6마리 파티를 이겼습니다.") if cleared else "원정대가 모두 쓰러졌습니다.",Rect2(550,430,1190,60),30,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"%d승  ·  총 %d턴  ·  배지 %d개" % [journey.wins,journey.total_turns,journey.badges],Rect2(550,510,1190,44),24,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var totals: Dictionary = journey.statistics.get("combat",{})
    W.label(page,"사용 카드 %d · 받은 피해 %d · 상세 내용은 원정 기록에서 확인" % [totals.get("cards_played",0),totals.get("damage_taken",0)],Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    _growth_summary()
    if journey.full_campaign:
        W.label(page,"배지 %d / 8  ·  사천왕 %d / 4" % [journey.badges,journey.elite_wins],Rect2(550,630,1190,42),23,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    _action("같은 시드로 다시 출발",Rect2(650,710,470,76),_restart.bind(journey.relic),"restart")
    _action("새 시드로 출발",Rect2(1160,710,470,76),_new_seed,"route")
    _action("시작 화면",Rect2(140,800,300,62),_home,"home")
func _capture_choice() -> void:
    var caught := journey.pending_captures[0]
    W.sprite(page,caught.species_id,Rect2(1000,280,180,180))
    W.label(page,caught.display_name+" 포획 성공!",Rect2(550,465,1190,60),30,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var catalog := VisualCatalog.new()
    var basic := catalog.species(catalog.starter_species_id(caught.species_id))
    W.label(page,"스타팅 해금 · "+str(basic["name"]),Rect2(550,535,1190,40),21,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    if journey.party.size() < 3:
        _action("합류할 기술 카드 확인",Rect2(820,630,560,76),_preview_recruit.bind(0),"ball").name = "Recruit_0"
    else:
        for i in journey.party.size():
            _action(journey.party[i].display_name+"와 교체 확인",Rect2(550+i*404,630,382,76),_preview_recruit.bind(i),"switch").name = "Recruit_%d" % i
    _action("풀어주기",Rect2(900,740,470,62),_resolve_capture.bind(-1),"next")
func _resolve_capture(index: int) -> void:
    if journey.resolve_capture(index).is_empty():
        recruit_index = -1
        refresh()
func _preview_recruit(index: int) -> void:
    if RecruitmentPreview.describe(journey,index).is_empty(): return
    recruit_index = index
    recruit_tab = "added"
    refresh()
func _close_recruit() -> void:
    recruit_index = -1
    refresh()
func _recruitment_preview() -> void:
    var change := RecruitmentPreview.describe(journey,recruit_index)
    if change.is_empty():
        recruit_index = -1
        return
    var incoming: BattlePokemon = change["incoming"]
    var outgoing: BattlePokemon = change["outgoing"]
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_recruit)
    overlay.name = "RecruitmentPreview"
    overlay.z_index = 90
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.86),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(360,100,1200,880),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"원정대 합류 확인",Rect2(36,22,1000,50),29,W.GOLD)
    W.icon_button(panel,"close",Rect2(1116,24,48,48),_close_recruit,"목록으로 · Esc")
    W.sprite(panel,incoming.species_id,Rect2(36,94,100,100))
    W.label(panel,"%s · Lv.%d · HP %d/%d" % [incoming.display_name,incoming.level,incoming.hp,incoming.max_hp],Rect2(154,100,980,42),25)
    W.label(panel,"%s와 교체" % outgoing.display_name if outgoing != null else "빈 파티 자리에 합류",Rect2(154,146,980,36),20,W.MUTED)
    W.label(panel,"덱 %d → %d장 · 추가 %d · 제거 %d" % [change["before"],change["after"],change["added"].size(),change["removed"].size()],Rect2(36,214,1128,40),23,W.GOLD).name = "RecruitDeckSummary"
    var returned: String = change["returned_item"]
    W.label(panel,"반환 장비 · "+str(TacticalContent.HELD_ITEMS[returned]["name"]) if not returned.is_empty() else "합류·방출과 관계없이 스타팅 해금은 유지됩니다.",Rect2(36,260,1128,34),17,W.MUTED)
    for i in 2:
        var key: String = ["added","removed"][i]
        var tab := W.button(panel,Rect2(36+i*570,314,552,48),func():
            recruit_tab = key
            refresh(),("추가되는 카드" if i == 0 else "빠지는 카드")+" · %d장" % change[key].size())
        tab.name = "RecruitTab_"+key
        if recruit_tab == key: tab.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var scroll := ScrollContainer.new()
    scroll.name = "RecruitCards"
    scroll.position = Vector2(36,376)
    scroll.size = Vector2(1128,322)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",14)
    scroll.add_child(row)
    var views: Array = change[recruit_tab]
    for i in views.size():
        var face := TrainerActionCard.new()
        face.name = "RecruitCard_%d" % i
        face.key = views[i]["key"]
        face.definition = views[i]
        row.add_child(face)
        face.update_card(views[i],"",false)
        face.disabled = true
    if views.is_empty(): W.label(row,"빠지는 카드가 없습니다.",Rect2(0,80,1000,100),24,W.MUTED)
    W.button(panel,Rect2(90,758,450,72),_close_recruit,"목록으로").name = "RecruitCancel"
    W.button(panel,Rect2(660,758,450,72),_resolve_capture.bind(recruit_index),"이 편성으로 합류").name = "RecruitConfirm"
    UiMotion.appear(overlay)
func _capture() -> Dictionary:
    var id := journey.battle.enemy().species_id
    var title := journey.battle.enemy().display_name
    var reason := journey.capture()
    var message := title+" 포획 성공!"
    if reason.is_empty():
        var profile: PlayerProfile = get_node("/root/BattleSession").get("profile")
        var save_error := profile.record_capture(id,VisualCatalog.new())
        if not save_error.is_empty(): message += "\n"+save_error
    return {"reason":reason,"notice":message}
func _deck() -> void:
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_deck)
    for state: String in ["normal","hover","pressed","focus"]:
        overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.85),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(520,120,880,840),Color("14282f"),Color("536b6e"))
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"원정 덱 · %d장" % journey.deck.size(),Rect2(32,24,720,60),28,W.GOLD)
    deck_close = W.icon_button(panel,"close",Rect2(796,30,48,48),_close_deck,"닫기 · Esc")
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32,110)
    scroll.size = Vector2(816,690)
    var rows := VBoxContainer.new()
    rows.custom_minimum_size.x = 790
    rows.add_theme_constant_override("separation",8)
    scroll.add_child(rows)
    panel.add_child(scroll)
    if not deck_action.is_empty():
        W.label(panel,"강화할 카드 선택 · 휴식과 공유" if deck_action == "upgrade" else "영구 제거할 카드 선택 · %d 골드" % journey.removal_price(),Rect2(32,78,720,30),17,W.MUTED)
    for card: BattleCardInstance in journey.deck:
        var view := TacticalContent.definition(card)
        var owner := ""
        for pokemon: BattlePokemon in journey.party:
            if pokemon.uid == card.owner_uid: owner = " · "+pokemon.display_name
        var button := Button.new()
        button.custom_minimum_size = Vector2(790,80)
        button.text = str(view["name"])+owner+"\n"+str(view["description"])
        button.add_theme_font_size_override("font_size",16)
        button.tooltip_text = view["description"]
        button.name = "Card_%d" % card.uid
        rows.add_child(button)
        if deck_action == "upgrade":
            button.disabled = not TacticalContent.can_upgrade(card) or journey.step in journey.rested_steps
            button.pressed.connect(_deck_select.bind(card.uid))
        elif deck_action == "remove":
            button.disabled = not journey.remove_card_reason(card.uid).is_empty()
            button.tooltip_text = journey.remove_card_reason(card.uid)
            button.pressed.connect(_deck_select.bind(card.uid))
        else: button.mouse_default_cursor_shape = Control.CURSOR_ARROW
func _deck_select(uid: int) -> void:
    if deck_action == "upgrade":
        if not journey.deck.any(func(card: BattleCardInstance): return card.uid == uid and TacticalContent.can_upgrade(card)): return
        if journey.phase != TacticalJourney.REST or journey.step in journey.rested_steps: return
        upgrade_preview_uid = uid
        refresh()
        return
    _apply_deck_action(uid)
func _apply_deck_action(uid: int) -> void:
    var reason := journey.rest("upgrade",uid) if deck_action == "upgrade" else journey.remove_card(uid)
    if reason.is_empty():
        camp_notice = "카드를 강화했습니다." if deck_action == "upgrade" else "카드를 제거했습니다."
        deck_open = false
        deck_action = ""
        upgrade_preview_uid = 0
    else: camp_notice = reason
    refresh()
func _close_upgrade_preview() -> void:
    upgrade_preview_uid = 0
    refresh()
func _confirm_upgrade() -> void:
    if upgrade_preview_uid == 0 or deck_action != "upgrade": return
    _apply_deck_action(upgrade_preview_uid)
func _upgrade_preview() -> void:
    var selected: BattleCardInstance
    for card: BattleCardInstance in journey.deck:
        if card.uid == upgrade_preview_uid: selected = card
    if selected == null:
        upgrade_preview_uid = 0
        return
    var overlay := W.button(page,Rect2(0,0,1920,1080),_close_upgrade_preview)
    overlay.name = "UpgradePreview"
    overlay.z_index = 85
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.85),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(420,150,1080,780),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.icon_button(panel,"close",Rect2(998,24,48,48),_close_upgrade_preview,"목록으로 · Esc")
    for i in 2:
        W.label(panel,"현재 카드" if i == 0 else "강화 후",Rect2(100+i*470,24,400,48),27,W.TEXT if i == 0 else W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
        var view := journey.reward_view({"kind":"card","key":selected.key,"owner_uid":selected.owner_uid,"upgraded":i == 1})
        var face := TrainerActionCard.new()
        face.name = "UpgradeBefore" if i == 0 else "UpgradeAfter"
        face.key = selected.key
        face.definition = view
        face.position = Vector2(160+i*470,80)
        face.scale = Vector2.ONE*1.35
        panel.add_child(face)
        face.update_card(view,"",false)
        face.disabled = true
        face.mouse_default_cursor_shape = Control.CURSOR_ARROW
    W.label(panel,"→",Rect2(488,264,100,64),46,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(panel,"이번 야영지 행동 · 카드 1장 강화\n휴식·희귀 단서 조사와 같은 행동을 사용합니다.",Rect2(44,520,992,88),22,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    W.button(panel,Rect2(130,650,350,72),_close_upgrade_preview,"목록으로").name = "UpgradeCancel"
    var confirm := W.button(panel,Rect2(600,650,350,72),_confirm_upgrade,"이 카드 강화")
    confirm.name = "UpgradeConfirm"
    confirm.disabled = journey.phase != TacticalJourney.REST or journey.step in journey.rested_steps or not TacticalContent.can_upgrade(selected)
    UiMotion.appear(overlay)
func _close_deck() -> void:
    upgrade_preview_uid = 0
    deck_action = ""
    deck_open = false
    refresh()
func _settle() -> void:
    if journey.settle().is_empty(): refresh()
func _reward(index: int) -> void:
    if journey.choose_reward(index).is_empty(): refresh()
func _enter() -> void:
    if travelling or deck_open or report_open: return
    if not journey.enter_next().is_empty(): return
    if not journey.full_campaign:
        refresh()
        return
    travelling = true
    travel = JourneyTravel.new()
    add_child(travel)
    travel.arrived.connect(func():
        travelling = false
        travel = null
        refresh())
    travel.start(journey.current()["name"],journey.biome(),journey.party)
func _restart(relic: String) -> void:
    deck_open = false
    report_open = false
    journey.restart(journey.seed_value,relic)
    refresh()
func _new_seed() -> void:
    journey.restart(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec(),journey.relic)
    refresh()
func _lab() -> void:
    get_node("/root/BattleSession").set("return_scene","res://scenes/tactical_journey.tscn")
    get_tree().change_scene_to_file("res://scenes/art_lab.tscn")
func _home() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
func _unhandled_key_input(event: InputEvent) -> void:
    if travelling: return
    if journey.phase == TacticalJourney.BATTLE or not event is InputEventKey or not event.pressed or event.echo: return
    if recruit_index >= 0:
        if event.keycode == KEY_ESCAPE: _close_recruit()
        get_viewport().set_input_as_handled()
        return
    if not evolution_result.is_empty():
        if event.keycode in [KEY_ESCAPE,KEY_ENTER]: _close_evolution()
        get_viewport().set_input_as_handled()
        return
    if special_open:
        if event.keycode == KEY_ESCAPE: _close_special()
        get_viewport().set_input_as_handled()
        return
    if rare_open:
        if event.keycode == KEY_ESCAPE: _close_rare()
        get_viewport().set_input_as_handled()
        return
    if report_open:
        if event.keycode == KEY_ESCAPE:
            report_open = false
            refresh()
        get_viewport().set_input_as_handled()
        return
    if gear_open_for != 0:
        if event.keycode == KEY_ESCAPE: _close_gear()
        return
    if not bag_item.is_empty():
        if event.keycode == KEY_ESCAPE: _close_item()
        get_viewport().set_input_as_handled()
        return
    if deck_open:
        if event.keycode == KEY_ESCAPE:
            if upgrade_preview_uid != 0: _close_upgrade_preview()
            else: _close_deck()
        get_viewport().set_input_as_handled()
        return
    match event.keycode:
        KEY_ESCAPE: _home()
        KEY_F11:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_status() -> void:
    if not is_instance_valid(save_button): return
    var notice := str(_save_session.get("save_notice"))
    save_button.text = "자동 저장됨" if notice.is_empty() else "저장 안내 · 다시 저장"
    save_button.tooltip_text = "행동 후 자동 저장합니다. 게임을 종료해도 이어할 수 있습니다.
클릭하여 다시 저장" if notice.is_empty() else notice+"
클릭하여 다시 저장"
    save_button.add_theme_color_override("font_color",W.MUTED if notice.is_empty() else W.GOLD)
func _retry_save() -> void:
    if travelling: return
    _save_session.checkpoint()
