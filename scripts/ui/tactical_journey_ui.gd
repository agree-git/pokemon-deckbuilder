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
    if journey.phase == TacticalJourney.BATTLE:
        battle_ui = load("res://scenes/tactical_battle.tscn").instantiate()
        battle_ui.battle = journey.battle
        battle_ui.run_mode = true
        battle_ui.run_title = "%d / 5  ·  %s" % [journey.step+1,journey.current()["name"]]
        battle_ui.capture_action = _capture
        battle_ui.capture_status = func(): return {"wild":journey.step == 0,"balls":journey.balls,"reason":journey.capture_reason()}
        battle_ui.run_continue_requested.connect(_settle)
        battle_ui.run_restart_requested.connect(_restart)
        page.add_child(battle_ui)
        return
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(VisualCatalog.new().biomes[3])
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
    W.icon(page,"grass",Rect2(48,24,32,32))
    W.label(page,"햇살숲 원정",Rect2(96,16,500,48),24)
    W.label(page,"배지 %d / 1  ·  시드 %d" % [journey.badges,journey.seed_value],Rect2(1400,16,360,48),17,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    W.icon_button(page,"home",Rect2(1788,18,64,44),_home,"시작 화면")
    var titles := {TacticalJourney.REWARD:"전투 보상",TacticalJourney.CAPTURE:"새로운 동료",TacticalJourney.MAP:"다음 장소",TacticalJourney.REST:"잠시 쉬어갑니다",TacticalJourney.CLEARED:"레인보배지 획득!",TacticalJourney.FAILED:"원정 종료"}
    W.label(page,titles[journey.phase],Rect2(96,122,1728,70),40,W.GOLD)
    _party()
    match journey.phase:
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
    W.label(page,"트레이너 카드 1장을 덱에 추가합니다.",Rect2(550,225,1200,48),22,W.MUTED)
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
        W.label(panel,"%s · Lv.%d → %d" % [report["name"],report["before"],report["after"]],Rect2(54,10,312,40),19,W.GOLD)
        W.label(panel,"+%s XP  ·  최대 HP +%d" % [String.num(report["xp"],1).trim_suffix(".0"),report["hp"]],Rect2(18,58,348,28),16,W.MUTED)
        W.label(panel,"R · "+report["learned"]+" 습득!" if not str(report["learned"]).is_empty() else "다음 레벨을 향해!",Rect2(18,96,348,28),17,W.TEXT)
func _map() -> void:
    W.label(page,"%d / 5  ·  %s" % [journey.step+1,journey.current()["name"]],Rect2(550,225,1200,48),25)
    for i in TacticalJourneyContent.STOPS.size():
        var stop: Dictionary = TacticalJourneyContent.STOPS[i]
        var x := 552+i*244
        var panel := W.panel(page,Rect2(x,350,218,220),Color("20383e") if i == journey.step else Color("14282f"),W.GOLD if i == journey.step else Color("405960"))
        W.icon(panel,"check" if i < journey.step else stop["icon"],Rect2(85,34,48,48))
        W.label(panel,str(i+1),Rect2(0,94,218,30),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        W.label(panel,stop["name"].replace(" · ","\n"),Rect2(12,130,194,64),18,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    _action("%s로 이동" % journey.current()["name"],Rect2(820,700,560,72),_enter)
    if not journey.last_evolution.is_empty():
        var evolved := journey.last_evolution
        W.sprite(page,evolved["from"],Rect2(680,828,96,112))
        W.icon(page,"next",Rect2(808,864,32,32))
        var sprite := W.sprite(page,evolved["to"],Rect2(872,812,128,144))
        UiMotion.appear(sprite)
        W.label(page,evolved["name"]+" → "+evolved["evolved_name"]+" 진화!",Rect2(1040,832,700,48),27,W.GOLD)
        W.label(page,"최대 HP +12 · 공격 +1 · 레벨과 기술 유지",Rect2(1040,893,700,36),19,W.TEXT)
func _rest() -> void:
    W.label(page,"회복 · 훈련 · 진화 중 한 번만 선택하세요.",Rect2(550,225,1200,48),22,W.MUTED)
    _action("전원 체력 50% 회복 · 부활 · 부상 제거",Rect2(550,320,1190,90),_rest_action.bind("heal",0),"heal")
    W.label(page,"훈련: 선택한 포켓몬의 최대 체력과 현재 체력 +8",Rect2(550,459,1190,44),20,W.MUTED)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        var button := _action(pokemon.display_name+" 훈련",Rect2(550+i*404,540,382,80),_rest_action.bind("train",i),"boost")
        button.disabled = not pokemon.alive()
    W.label(page,"진화: 최대 HP +12 · 공격 +1 · 기술 유지",Rect2(550,690,1190,44),20,W.GOLD)
    var catalog := VisualCatalog.new()
    for i in journey.party.size():
        var pokemon := journey.party[i]
        var rules := TacticalGrowth.rules_for(pokemon.species_id)
        if rules.is_empty():
            var has_evolution := catalog.pokemon.any(func(species: Dictionary): return int(species.get("evolves_from",0)) == pokemon.species_id)
            var unavailable := _action(pokemon.display_name+(" · 특수 진화" if has_evolution else " · 진화 완료"),Rect2(550+i*404,766,382,80),func(): pass,"boost")
            unavailable.disabled = true
            unavailable.tooltip_text = "특수한 조건이 필요한 진화는 아직 사용할 수 없습니다." if has_evolution else "현재 진화의 마지막 모습입니다."
            continue
        var target := int(rules[0]["to"])
        var reason := TacticalGrowth.evolution_reason(pokemon,target)
        var evolve_button := _action(pokemon.display_name+" → "+str(catalog.species(target)["name"]),Rect2(550+i*404,766,382,80),_evolve.bind(i,target),"boost")
        evolve_button.disabled = not reason.is_empty()
        evolve_button.tooltip_text = "Lv.%d · %s" % [int(rules[0]["level"]),reason if not reason.is_empty() else "야영지 행동을 사용해 진화합니다."]
func _result() -> void:
    var cleared := journey.phase == TacticalJourney.CLEARED
    W.icon(page,"badge" if cleared else "injury",Rect2(1056,280,112,112))
    W.label(page,"민화의 6마리 파티를 이겼습니다." if cleared else "원정대가 모두 쓰러졌습니다.",Rect2(550,430,1190,60),30,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"%d승  ·  총 %d턴  ·  배지 %d개" % [journey.wins,journey.total_turns,journey.badges],Rect2(550,510,1190,44),24,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,("기본 경험치 +%d · 기절한 동료는 30%%" % TacticalJourneyContent.experience_reward(journey.step) if cleared else journey.current()["name"]),Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    _action("같은 시드로 다시 출발",Rect2(650,710,470,76),_restart.bind(journey.relic),"restart")
    _action("새 시드로 출발",Rect2(1160,710,470,76),_new_seed,"route")
    _action("시작 화면",Rect2(900,820,470,62),_home,"home")
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
func _rest_action(action: String,index: int) -> void:
    if journey.rest(action,index).is_empty(): refresh()
func _evolve(index: int,target: int) -> void:
    if journey.evolve(index,target).is_empty(): refresh()
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
