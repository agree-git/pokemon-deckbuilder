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
    W.icon_button(page,"lab",Rect2(1788,18,64,44),_lab,"아트 랩 · F2")
    var titles := {TacticalJourney.REWARD:"전투 보상",TacticalJourney.MAP:"다음 장소",TacticalJourney.REST:"잠시 쉬어갑니다",TacticalJourney.CLEARED:"레인보배지 획득!",TacticalJourney.FAILED:"원정 종료"}
    W.label(page,titles[journey.phase],Rect2(96,122,1728,70),40,W.GOLD)
    _party()
    match journey.phase:
        TacticalJourney.REWARD: _rewards()
        TacticalJourney.MAP: _map()
        TacticalJourney.REST: _rest()
        _: _result()
    W.label(page,"F2 아트 랩     F3 기존 원정     F4 전술 시험     F11 전체 화면",Rect2(96,1014,1728,34),15,W.MUTED)
    if deck_open: _deck()
    UiMotion.appear(page)
func _party() -> void:
    var panel := W.panel(page,Rect2(96,280,340,420),Color("14282f"),Color("405960"))
    W.label(panel,"원정대",Rect2(24,18,292,38),23)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        W.sprite(panel,pokemon.species_id,Rect2(20,80+i*82,64,64))
        W.label(panel,pokemon.display_name,Rect2(102,77+i*82,210,32),20)
        W.label(panel,"%d / %d HP" % [pokemon.hp,pokemon.max_hp] if pokemon.alive() else "기절",Rect2(102,111+i*82,210,28),17,W.MUTED)
        W.fill_bar(W.bar(panel,Rect2(102,143+i*82,200,4)),pokemon.hp,pokemon.max_hp)
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
func _rest() -> void:
    W.label(page,"회복과 훈련 중 한 번만 선택하세요.",Rect2(550,225,1200,48),22,W.MUTED)
    _action("전원 체력 50% 회복 · 부활 · 부상 제거",Rect2(550,320,1190,90),_rest_action.bind("heal",0),"heal")
    W.label(page,"훈련: 선택한 포켓몬의 최대 체력과 현재 체력 +8",Rect2(550,459,1190,44),20,W.MUTED)
    for i in journey.party.size():
        var pokemon := journey.party[i]
        var button := _action(pokemon.display_name+" 훈련",Rect2(550+i*404,540,382,80),_rest_action.bind("train",i),"boost")
        button.disabled = not pokemon.alive()
func _result() -> void:
    var cleared := journey.phase == TacticalJourney.CLEARED
    W.icon(page,"badge" if cleared else "injury",Rect2(1056,280,112,112))
    W.label(page,"민화의 6마리 파티를 이겼습니다." if cleared else "원정대가 모두 쓰러졌습니다.",Rect2(550,430,1190,60),30,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"%d승  ·  총 %d턴  ·  배지 %d개" % [journey.wins,journey.total_turns,journey.badges],Rect2(550,510,1190,44),24,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(page,"햇살숲 짧은 원정 완주" if cleared else journey.current()["name"],Rect2(550,570,1190,40),20,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    _action("같은 시드로 다시 출발",Rect2(650,710,470,76),_restart.bind(journey.relic),"restart")
    _action("새 시드로 출발",Rect2(1160,710,470,76),_new_seed,"route")
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
func _unhandled_key_input(event: InputEvent) -> void:
    if journey.phase == TacticalJourney.BATTLE or not event is InputEventKey or not event.pressed or event.echo: return
    if deck_open:
        if event.keycode == KEY_ESCAPE: _close_deck()
        return
    match event.keycode:
        KEY_F2: _lab()
        KEY_F3: get_tree().change_scene_to_file("res://scenes/battle_preview.tscn")
        KEY_F4: get_tree().change_scene_to_file("res://scenes/tactical_battle.tscn")
        KEY_F11:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
