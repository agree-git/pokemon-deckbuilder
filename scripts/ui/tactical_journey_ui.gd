class_name TacticalJourneyUI
extends Control
const W = preload("res://scripts/ui/combat_widgets.gd")
var journey: TacticalJourney
var battle_ui: TacticalUI
var page := Control.new()
var actions: Array[Button] = []
var deck_open := false
var deck_button: Button
var deck_close: Button
var camp_tab := "rest"
var camp_tabs: Dictionary = {}
var camp_notice := ""
var rest_button: Button
var learn_buttons: Array[Button] = []

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
    refresh()
func refresh() -> void:
    W.clear(page)
    battle_ui = null
    actions.clear()
    learn_buttons.clear()
    camp_tabs.clear()
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
    UiMotion.appear(page)
func _party() -> void:
    var panel := W.panel(page,Rect2(96,280,340,420),Color("14282f"),Color("405960"))
    W.label(panel,"원정대",Rect2(24,18,292,38),23)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        W.sprite(panel,pokemon.species_id,Rect2(20,80+i*82,64,64))
        W.label(panel,"%s · Lv.%d" % [pokemon.display_name,pokemon.level],Rect2(102,77+i*82,218,32),18)
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
    W.label(page,("배지 획득! · %d / 8  ·  " % journey.badges if journey.full_campaign and journey.current()["kind"] == "gym" else "")+"트레이너 카드 1장을 덱에 추가합니다.",Rect2(550,225,1200,48),22,W.MUTED)
    for i in journey.reward_options.size():
        var key := journey.reward_options[i]
        var card := TrainerActionCard.new()
        card.key = key
        card.position = Vector2(650+i*254,310)
        card.pressed.connect(_reward.bind(i))
        page.add_child(card)
        card.update_card(TacticalContent.CARDS[key],"",false)
        card.deal(i*0.06)
        actions.append(card)
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
    var width := 1190.0/visible_steps.size()
    for column in visible_steps.size():
        var i := visible_steps[column]
        var stop: Dictionary = stops[i]
        var panel := W.panel(page,Rect2(550+column*width,350,width-12,220),Color("20383e") if i == journey.step else Color("14282f"),W.GOLD if i == journey.step else Color("405960"))
        W.icon(panel,"check" if i < journey.step else stop["icon"],Rect2((width-60)/2,34,48,48))
        W.label(panel,str(column+1),Rect2(0,94,width-12,30),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        W.label(panel,stop["name"].replace(" · ","\n"),Rect2(8,130,width-28,72),16,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    _action("%s로 이동" % journey.current()["name"],Rect2(820,620,560,72),_enter)
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
    W.label(page,"기술은 네 개까지 · 잊을 기술을 선택하세요.",Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
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
    W.label(page,"필요한 만큼 준비한 뒤 출발하세요.",Rect2(550,204,1190,40),22,W.MUTED)
    for i in 4:
        var key: String = ["rest","shop","bag","loot"][i]
        var button := W.button(page,Rect2(550+i*303,266,282,64),_camp_tab.bind(key),["휴식","아이템 구매","가방","전리품"][i])
        if key == camp_tab: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
        camp_tabs[key] = button
    _action("준비 완료 · 출발",Rect2(1260,930,480,72),_leave_camp,"next")
    match camp_tab:
        "rest":
            W.icon(page,"heal",Rect2(1065,390,96,96))
            W.label(page,"전원 체력 50% 회복 · 기절 회복 · 부상 제거",Rect2(550,530,1190,60),25,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(page,"이번 야영지에서 한 번 휴식할 수 있습니다.
휴식 후에도 구매·아이템 사용·전리품 확인을 계속할 수 있습니다.",Rect2(550,610,1190,90),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
            rest_button = W.button(page,Rect2(870,742,560,78),_camp_rest,"휴식 완료" if journey.step in journey.rested_steps else "휴식하기")
            rest_button.disabled = journey.step in journey.rested_steps
        "shop":
            var i := 0
            for key: String in journey.items():
                var item: Dictionary = journey.items()[key]
                var y := 356+i*120
                W.panel(page,Rect2(550,y,1190,114),Color("172d32"))
                W.icon(page,"ball" if key == "ball" else "heal",Rect2(574,y+30,48,48))
                W.label(page,"%s · %d 골드" % [item["name"],item["price"]],Rect2(650,y+12,600,40),24,W.TEXT)
                W.label(page,("야생 전투에서 포획 · C" if key == "ball" else ("기절한 동료의 HP 50% 회복" if key == "revive" else "체력 %d 회복" % item["heal"]))+" · 재고 %d / 보유 %d" % [journey.shop_stock.get(key,0),journey.quantity(key)],Rect2(650,y+61,600,34),18,W.MUTED)
                var button := W.button(page,Rect2(1440,y+22,270,70),_buy.bind(key),"구매")
                button.name = "Buy_"+key
                button.disabled = not journey.buy_reason(key).is_empty()
                button.tooltip_text = journey.buy_reason(key)
                actions.append(button)
                i += 1
        "bag":
            var i := 0
            for key: String in journey.items():
                if key == "ball":
                    W.label(page,"몬스터볼 ×%d · 야생 전투에서 C로 포획" % journey.balls,Rect2(550,818,1190,40),19,W.MUTED)
                    continue
                W.label(page,"%s ×%d" % [journey.items()[key]["name"],journey.quantity(key)],Rect2(550,390+i*140,320,70),23)
                for index in journey.party.size():
                    var pokemon := journey.party[index]
                    var button := W.button(page,Rect2(870+index*290,390+i*140,270,76),_use_item.bind(key,index),pokemon.display_name)
                    button.name = "Use_%s_%d" % [key,index]
                    button.disabled = not journey.item_reason(key,index).is_empty()
                    button.tooltip_text = journey.item_reason(key,index)
                    actions.append(button)
                i += 1
        "loot":
            var text := ""
            for entry: Dictionary in journey.loot:
                text += "%s\n+%d 골드 · %s ×%d\n\n" % [entry["name"],entry["gold"],TacticalJourneyContent.ITEMS[entry["item"]]["name"],entry["quantity"]]
            var list := RichTextLabel.new()
            list.position = Vector2(600,370)
            list.size = Vector2(1090,420)
            list.text = text if not text.is_empty() else "아직 얻은 전리품이 없습니다."
            list.add_theme_font_size_override("normal_font_size",22)
            page.add_child(list)
            W.label(page,"전리품은 전투 종료 시 가방과 골드에 자동 반영됩니다.",Rect2(600,815,1090,40),18,W.MUTED)
    W.label(page,camp_notice,Rect2(550,870,1190,40),20,W.GOLD)
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
    var text := RichTextLabel.new()
    text.position = Vector2(32,110)
    text.size = Vector2(816,690)
    text.add_theme_font_size_override("normal_font_size",21)
    var counts: Dictionary = {}
    for card: BattleCardInstance in journey.deck: counts[card.key] = int(counts.get(card.key,0))+1
    for key: String in TacticalContent.CARDS:
        if counts.has(key): text.text += "%s ×%d\n%s\n\n" % [TacticalContent.CARDS[key]["name"],counts[key],TacticalContent.CARDS[key]["description"]]
    panel.add_child(text)
func _close_deck() -> void:
    deck_open = false
    refresh()
func _settle() -> void:
    if journey.settle().is_empty(): refresh()
func _reward(index: int) -> void:
    if journey.choose_reward(index).is_empty(): refresh()
func _enter() -> void:
    if journey.enter_next().is_empty(): refresh()
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
    if journey.phase == TacticalJourney.BATTLE or not event is InputEventKey or not event.pressed or event.echo: return
    if deck_open:
        if event.keycode == KEY_ESCAPE: _close_deck()
        return
    match event.keycode:
        KEY_ESCAPE: _home()
        KEY_F11:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
