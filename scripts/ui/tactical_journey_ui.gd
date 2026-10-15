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
var deck_action := ""
var gear_open_for := 0
var deck_button: Button
var deck_close: Button
var camp_tab := "rest"
var camp_tabs: Dictionary = {}
var camp_notice := ""
var bag_item := ""
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
        battle_ui.capture_status = func(): return {"wild":journey.is_wild(),"balls":journey.balls,"reason":journey.capture_reason()}
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
    if gear_open_for != 0: _gear_picker()
    if not bag_item.is_empty(): _item_picker()
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
        W.label(panel,("%d / %d HP" % [pokemon.hp,pokemon.max_hp] if pokemon.alive() else "기절")+" · "+TacticalGrowth.progress_text(pokemon),Rect2(102,111+i*82,218,28),12,W.MUTED)
        W.fill_bar(W.bar(panel,Rect2(102,141+i*82,200,4)),pokemon.hp,pokemon.max_hp)
        var experience := W.bar(panel,Rect2(102,148+i*82,200,3),W.GOLD)
        experience.get_child(0).size.x = 200*TacticalGrowth.progress(pokemon)
    deck_button = W.button(panel,Rect2(20,348,300,52),func():
        deck_open = true
        refresh(),"원정 덱 · %d장" % journey.deck.size())
func _action(title: String, rect: Rect2, callback: Callable, icon := "next") -> Button:
    var button := W.button(page,rect,callback)
    W.icon(button,icon,Rect2(20,(rect.size.y-28)/2,28,28))
    W.label(button,title,Rect2(64,0,rect.size.x-84,rect.size.y),21)
    actions.append(button)
    return button
func _rewards() -> void:
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
func _growth_summary() -> void:
    for i in journey.growth_reports.size():
        var report := journey.growth_reports[i]
        var panel := W.panel(page,Rect2(550+i*404,832,382,140),Color("172d32"),Color("475b50"))
        W.icon(panel,"boost",Rect2(18,18,24,24))
        var title := "%s · Lv.%d → %d" % [report["name"],report["before"],report["after"]]
        if not report["evolutions"].is_empty(): title = report["name"]+" → "+str(report["evolutions"].back()["name"])
        W.label(panel,title,Rect2(54,10,312,40),19,W.GOLD)
        W.label(panel,"+%s XP  ·  최대 HP +%d" % [String.num(report["xp"],1).trim_suffix(".0"),report["hp"]],Rect2(18,58,348,28),16,W.MUTED)
        W.label(panel," · ".join(report["learned"])+" 습득" if not report["learned"].is_empty() else ("자동 진화!" if not report["evolutions"].is_empty() else "다음 레벨을 향해!"),Rect2(18,96,348,28),17,W.TEXT)
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
        var highlighted: bool = i == journey.step or (journey.current()["kind"] == "rest" and i == journey.step-1)
        var height := 148.0 if journey.full_campaign else 220.0
        var panel := W.panel(page,Rect2(550+(column%columns)*width,310+floori(column/float(columns))*164,width-12,height),Color("20383e") if highlighted else Color("14282f"),W.GOLD if highlighted else Color("405960"))
        W.icon(panel,"check" if i < journey.step else ("attack" if stop["kind"] in ["trainer","veteran"] else stop["icon"]),Rect2(18,20,34,34))
        W.label(panel,str(column+1),Rect2(width-64,20,38,30),17,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
        W.label(panel,stop["name"].replace(" · ","\n"),Rect2(18,62,width-48,60),17,W.TEXT)
        if journey.full_campaign:
            var final_battle: bool = stop["kind"] == "champion"
            W.icon(panel,"badge" if final_battle else "heal",Rect2(width-42,height-28,16,16))
            panel.tooltip_text = ("승리하면 챔피언 등극" if final_battle else "전투 후 야영지")+" · 적 Lv.%d" % stop["level"]
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
            W.icon(page,"heal",Rect2(1065,390,96,96))
            W.label(page,"전원 체력 50% 회복 · 기절 회복 · 부상 제거",Rect2(550,530,1190,60),25,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(page,"휴식과 카드 강화 중 하나를 선택하세요.
가방·장비·만남은 별도로 이용할 수 있습니다.",Rect2(550,610,1190,90),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
            rest_button = W.button(page,Rect2(650,742,500,78),_camp_rest,"휴식 완료" if journey.step in journey.rested_steps else "휴식하기")
            rest_button.disabled = journey.step in journey.rested_steps
            var upgrade := W.button(page,Rect2(1190,742,500,78),_select_deck_action.bind("upgrade"),"카드 강화 선택")
            upgrade.name = "Upgrade"
            upgrade.disabled = journey.step in journey.rested_steps or not journey.deck.any(func(card: BattleCardInstance): return TacticalContent.can_upgrade(card))
            actions.append(upgrade)
        "encounter": _encounter()
        "shop":
            var i := 0
            for key: String in journey.items():
                if journey.full_campaign and key not in encounter.get("offers",[]): continue
                var item: Dictionary = journey.items()[key]
                var y := 356+i*120
                W.panel(page,Rect2(550,y,1190,114),Color("172d32"))
                _item_sprite(page,key,Rect2(574,y+28,60,60))
                W.label(page,"%s · %d 골드" % [item["name"],item["price"]],Rect2(650,y+12,600,40),24,W.TEXT)
                W.label(page,("야생 전투에서 포획 · C" if key == "ball" else ("기절한 동료의 HP 50% 회복" if key == "revive" else "최대 HP의 %s 회복" % PokemonStats.percent(int(journey.items()[key]["heal"]))))+" · 재고 %d / 보유 %d" % [journey.shop_stock.get(key,0),journey.quantity(key)],Rect2(650,y+61,600,34),18,W.MUTED)
                var button := W.button(page,Rect2(1440,y+22,270,70),_buy.bind(key),"구매")
                button.name = "Buy_"+key
                button.disabled = not journey.buy_reason(key).is_empty()
                button.tooltip_text = journey.buy_reason(key)
                actions.append(button)
                i += 1
            var remove := W.button(page,Rect2(870,760,560,64),_select_deck_action.bind("remove"),"카드 제거 · %d 골드" % journey.removal_price())
            remove.name = "Remove"
            remove.disabled = journey.camp().get("removed",false) or journey.gold < journey.removal_price()
            actions.append(remove)
        "gear": _gear()
        "bag":
            var i := 0
            for key: String in journey.items():
                var item: Dictionary = journey.items()[key]
                var button := W.button(page,Rect2(550+(i%3)*400,382+floori(i/3.0)*210,376,184),_open_item.bind(key))
                button.name = "Bag_"+key
                _item_sprite(button,key,Rect2(143,24,90,90))
                W.label(button,item["name"],Rect2(20,126,336,40),23,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
                W.label(button,"×%d" % journey.quantity(key),Rect2(280,10,76,32),18,W.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
                button.disabled = journey.quantity(key) == 0 or key == "ball"
                button.tooltip_text = "야생 전투에서 C로 포획" if key == "ball" else ("기절한 동료 HP 50% 회복" if key == "revive" else "최대 HP의 %s 회복" % PokemonStats.percent(int(item["heal"])))
                i += 1
    W.label(page,camp_notice,Rect2(550,870,1190,40),20,W.GOLD)
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
        var healing := ceili(p.max_hp*0.5) if bag_item == "revive" else PokemonStats.scale(p,int(journey.items()[bag_item]["heal"]))
        W.label(button,"HP %d / %d  →  %d / %d" % [p.hp,p.max_hp,mini(p.max_hp,p.hp+healing),p.max_hp] if reason.is_empty() else reason,Rect2(152,64,520,35),19,W.MUTED)
        W.fill_bar(W.bar(button,Rect2(152,117,510,7)),p.hp,p.max_hp)
        button.tooltip_text = reason
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
func _buy(key: String) -> void:
    var reason := journey.buy(key)
    camp_notice = reason if not reason.is_empty() else str(journey.items()[key]["name"])+" 구매 완료"
    refresh()
func _use_item(key: String,index: int) -> void:
    var reason := journey.use_item(key,index)
    camp_notice = reason if not reason.is_empty() else journey.party[index].display_name+"에게 사용했습니다."
    if reason.is_empty(): bag_item = ""
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
    W.label(page,("기본 경험치 +%d · 기절한 동료는 30%%" % journey.experience_reward() if cleared else journey.current()["name"]),Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
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
        _action("원정대에 합류",Rect2(820,630,560,76),_resolve_capture.bind(0),"ball")
    else:
        for i in journey.party.size():
            _action(journey.party[i].display_name+"와 교체",Rect2(550+i*404,630,382,76),_resolve_capture.bind(i),"switch")
    _action("풀어주기",Rect2(900,740,470,62),_resolve_capture.bind(-1),"next")
func _resolve_capture(index: int) -> void:
    if journey.resolve_capture(index).is_empty(): refresh()
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
    var reason := journey.rest("upgrade",uid) if deck_action == "upgrade" else journey.remove_card(uid)
    if reason.is_empty():
        camp_notice = "카드를 강화했습니다." if deck_action == "upgrade" else "카드를 제거했습니다."
        deck_open = false
        deck_action = ""
    else: camp_notice = reason
    refresh()
func _close_deck() -> void:
    deck_action = ""
    deck_open = false
    refresh()
func _settle() -> void:
    if journey.settle().is_empty(): refresh()
func _reward(index: int) -> void:
    if journey.choose_reward(index).is_empty(): refresh()
func _enter() -> void:
    if travelling or deck_open: return
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
    if gear_open_for != 0:
        if event.keycode == KEY_ESCAPE: _close_gear()
        return
    if not bag_item.is_empty():
        if event.keycode == KEY_ESCAPE: _close_item()
        get_viewport().set_input_as_handled()
        return
    if deck_open:
        if event.keycode == KEY_ESCAPE: _close_deck()
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
