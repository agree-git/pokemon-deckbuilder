class_name MainMenu
extends Control
## New campaigns, saved-game resume and collection browsing.
var full_campaign := true
const W = preload("res://scripts/ui/combat_widgets.gd")
var catalog := VisualCatalog.new()
var session: Node
var profile: PlayerProfile
var page := Control.new()
var mode := "title"
var starting := false
var departure: JourneyTravel
var selection: Array[int] = []
var species_buttons: Dictionary = {}
var tutorial_button: Button
var tutorial_prompt: Control
var start_button: Button
var continue_button: Button
var collection_button: Button
var confirm_button: Button
var back_button: Button
var settings_button: Button
var search: LineEdit
var show_locked: CheckButton
var grid: GridContainer
var slots: Panel
var counter: Label
var notice: Label
var loadout_button: Button
var loadout_panel: StarterLoadoutPanel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    session = get_node("/root/BattleSession")
    profile = session.get("profile")
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):550.0}
    theme = Theme.new()
    theme.default_font = font
    theme.default_font_size = 20
    theme.set_color("font_color","Label",W.TEXT)
    theme.set_color("font_color","Button",W.TEXT)
    theme.set_color("font_disabled_color","Button",W.MUTED)
    for state: String in ["normal","hover","pressed","focus","disabled"]:
        theme.set_stylebox(state,"Button",W.box(Color("25434a") if state in ["hover","pressed"] else Color("152b32"),W.GOLD if state == "hover" else Color("3d555a")))
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(page)
    if session.get("open_starter_selection"):
        session.set("open_starter_selection",false)
        mode = "starters"
    get_node("/root/GameMusic").play_theme("title")
    get_node("/root/GameAmbience").clear()
    render()
func render() -> void:
    W.clear(page)
    species_buttons.clear()
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(catalog.biomes[3])
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page.add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.025,0.06,0.075,0.67 if mode == "title" else 0.92)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page.add_child(shade)
    settings_button = W.icon_button(page,"settings",Rect2(1752,34,72,56),func(): get_node("/root/Preferences").show_panel(self),"설정")
    settings_button.name = "Settings"
    if mode == "title": _title()
    else: _collection()
    page.modulate.a = 0.0
    UiMotion.begin(page,"page").tween_property(page,"modulate:a",1.0,0.2)
func _button(title: String,rect: Rect2,action: Callable,icon: String) -> Button:
    var button := W.button(page,rect,action)
    W.icon(button,icon,Rect2(24,(rect.size.y-32)/2,32,32))
    W.label(button,title,Rect2(78,0,rect.size.x-100,rect.size.y),24)
    return button
func _title() -> void:
    W.label(page,"POKÉMON EXPEDITION",Rect2(144,165,700,50),21,W.MUTED)
    W.label(page,"포켓몬 원정대",Rect2(138,227,1130,116),82,W.GOLD)
    W.label(page,"배지 8개를 모으고, 사천왕과 챔피언에게 도전하세요.",Rect2(146,365,1030,46),23,W.TEXT)
    W.label(page,"새 원정 · 도전 난도: 상성·교대·야영 준비가 중요합니다.",Rect2(146,417,1030,40),18,W.MUTED)
    var y := 505
    var journey: TacticalJourney = session.get("journey")
    if session.get("has_journey") and journey.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED]:
        continue_button = _button("이어하기",Rect2(144,y,470,80),_continue,"next")
        W.label(page,journey.progress_title()+" · 배지 %d / 8" % journey.badges,Rect2(650,y,1120,80),19,W.MUTED)
        y += 98
    start_button = _button("새 원정",Rect2(144,y,470,80),_choose,"route")
    tutorial_button = _button("튜토리얼 · 조작 연습",Rect2(144,y+92,470,64),_open_tutorial,"help")
    tutorial_button.name = "TutorialButton"
    collection_button = _button("포획 도감",Rect2(144,y+170,470,64),_open_collection,"ball")
    _button("게임 종료",Rect2(144,y+248,470,56),func(): get_tree().quit(),"close")
    W.label(page,"포획 %d / %d  ·  스타팅 %d종 해금" % [profile.captured_ids.size(),catalog.pokemon.size(),profile.unlocked_starters(catalog).size()],Rect2(144,940,1000,44),18,W.MUTED)
    var message := str(session.get("save_notice"))
    if not profile.last_error.is_empty(): message += (" · " if not message.is_empty() else "")+profile.last_error
    var preferences := get_node("/root/Preferences")
    if not preferences.last_error.is_empty(): message += (" · " if not message.is_empty() else "")+preferences.last_error
    if not message.is_empty(): W.label(page,message,Rect2(144,989,1550,34),16,W.GOLD)
    for i in 3:
        var sprite := W.sprite(page,[1,4,7][i],Rect2(1110+i*205,655+(35 if i == 1 else 0),190,190))
        var home := sprite.position
        var floating := sprite.create_tween().set_loops()
        floating.tween_property(sprite,"position:y",home.y-8,1.3+i*0.15).set_trans(Tween.TRANS_SINE)
        floating.tween_property(sprite,"position:y",home.y,1.3+i*0.15).set_trans(Tween.TRANS_SINE)
func _choose() -> void:
    if get_node("/root/Preferences").tutorial_status == "new":
        _offer_tutorial()
        return
    _choose_starters()
func _choose_starters() -> void:
    mode = "starters"
    selection.clear()
    render()
func _offer_tutorial() -> void:
    if is_instance_valid(tutorial_prompt): return
    tutorial_prompt = Control.new()
    tutorial_prompt.name = "TutorialOffer"
    tutorial_prompt.z_index = 100
    tutorial_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.add_child(tutorial_prompt)
    var shade := ColorRect.new()
    shade.color = Color(0.01,0.025,0.04,0.86)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_prompt.add_child(shade)
    var panel := W.panel(tutorial_prompt,Rect2(480,280,960,520),Color("14282f"),W.GOLD,14)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"처음이라면 조작부터 연습해 볼까요?",Rect2(40,44,880,70),32,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(panel,"카드 사용 · 자동 교대 · 방어와 턴 종료 · 포획 · 야영지 준비\n실제 버튼을 눌러 익히는 별도 연습입니다.\n진행 중인 원정과 도감은 바뀌지 않으며 언제든 나올 수 있습니다.",Rect2(50,142,860,138),22,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.button(panel,Rect2(80,334,380,70),_open_tutorial,"연습하고 시작").name = "OfferPractice"
    W.button(panel,Rect2(500,334,380,70),func():
        get_node("/root/Preferences").set_tutorial_status("skipped")
        _close_tutorial_offer()
        _choose_starters(),"바로 스타팅 선택").name = "OfferSkip"
    W.label(panel,"시작 화면의 ‘튜토리얼 · 조작 연습’에서 언제든 다시 할 수 있습니다.",Rect2(40,430,880,42),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
func _close_tutorial_offer() -> void:
    if not is_instance_valid(tutorial_prompt): return
    tutorial_prompt.queue_free()
    tutorial_prompt = null
func _open_tutorial() -> void:
    get_tree().change_scene_to_file("res://scenes/tutorial.tscn")
func _open_collection() -> void:
    mode = "collection"
    render()
func _collection() -> void:
    back_button = _button("돌아가기",Rect2(96,34,250,60),_back,"home")
    W.label(page,"스타팅 선택" if mode == "starters" else "포획 도감",Rect2(96,104,1400,66),38,W.GOLD)
    search = LineEdit.new()
    search.position = Vector2(116,188)
    search.size = Vector2(660,48)
    search.placeholder_text = "포켓몬 이름 또는 도감 번호 검색"
    search.text_changed.connect(func(_value: String): _filter())
    page.add_child(search)
    show_locked = CheckButton.new()
    show_locked.position = Vector2(820,188)
    show_locked.size = Vector2(306,48)
    show_locked.text = "미해금 포함"
    show_locked.toggled.connect(func(_value: bool): _filter())
    page.add_child(show_locked)
    W.panel(page,Rect2(96,254,1030,668),Color("10252c"),Color("344b51"))
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(116,274)
    scroll.size = Vector2(990,628)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)
    grid = GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation",16)
    grid.add_theme_constant_override("v_separation",16)
    scroll.add_child(grid)
    slots = W.panel(page,Rect2(1216,254,608,560),Color("142b32"),Color("405960"))
    counter = W.label(page,"",Rect2(1216,188,608,48),23,W.TEXT)
    notice = W.label(page,"새 원정을 시작하면 진행 중인 원정을 덮어씁니다." if mode == "starters" and session.get("has_journey") else "",Rect2(1216,835,608,66),17,W.GOLD)
    if mode == "starters":
        confirm_button = _button("원정 시작",Rect2(1216,930,608,80),_start,"next")
    W.label(page,"포획한 진화체는 가장 미진화한 모습으로 스타팅에 추가됩니다.",Rect2(96,970,1070,42),17,W.MUTED)
    _filter()
    _sync_selection()
func _filter() -> void:
    W.clear(grid)
    species_buttons.clear()
    var unlocked := profile.unlocked_starters(catalog)
    var collection_known := known_collection()
    var seen: Array[int] = []
    var query := search.text.strip_edges().to_lower()
    for entry: Dictionary in catalog.pokemon:
        var id := int(entry["id"])
        if mode == "starters": id = catalog.starter_species_id(id)
        if id in seen: continue
        seen.append(id)
        var allowed := id in (unlocked if mode == "starters" else collection_known)
        var species := catalog.species(id)
        var active_run: TacticalJourney = session.get("journey")
        var encountered: bool = active_run != null and not active_run.rare_hunt.is_empty() and RareEncounter.identity_known(active_run) and active_run.rare_hunt["target"] == id
        var rare_id := id if id in RareEncounter.IDS else int(species.get("dex_id",id))
        var unknown: bool = rare_id in RareEncounter.IDS and not allowed and id not in profile.captured_ids and not encountered
        if unknown and not query.is_empty() and query not in "???": continue
        if not allowed and not show_locked.button_pressed: continue
        if not unknown and not query.is_empty() and query not in str(species["name"]).to_lower() and query not in "%03d" % int(species.get("dex_id",id)): continue
        var button := W.button(grid,Rect2(0,0,310,184),_select.bind(id))
        button.custom_minimum_size = Vector2(310,184)
        if unknown:
            W.label(button,"?",Rect2(18,34,88,104),64,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(button,"???",Rect2(112,35,184,38),22,W.MUTED)
            W.label(button,"미발견",Rect2(112,76,184,28),15,W.MUTED)
        else:
            var sprite := W.sprite(button,id,Rect2(18,34,88,104))
            if not allowed and not encountered: sprite.modulate = Color(0,0,0,0.55)
            W.fit_label(W.label(button,str(species["name"]) if allowed or encountered else "미해금",Rect2(112,35,184,38),22,W.TEXT if allowed else W.MUTED))
            W.label(button,"#%03d" % int(species.get("dex_id",id)),Rect2(112,76,184,28),15,W.MUTED)
            var types: Array = species["types"].map(func(key: String): return catalog.type_name(key))
            W.label(button," / ".join(types),Rect2(112,111,184,28),15,VisualCatalog.type_color(species["types"][0]))
        button.disabled = not allowed
        button.tooltip_text = "포획하면 해금됩니다." if not allowed else str(species["name"])
        species_buttons[id] = button
    if species_buttons.is_empty():
        W.label(grid,"아직 포획한 포켓몬이 없습니다." if mode == "collection" and profile.captured_ids.is_empty() else "조건에 맞는 포켓몬이 없습니다.",Rect2(0,0,900,90),23,W.MUTED)
    if mode == "starters": _sync_selection()
func _select(id: int) -> void:
    if mode == "collection":
        W.clear(slots)
        var species := catalog.species(id)
        var basic := catalog.species(catalog.starter_species_id(id))
        W.sprite(slots,id,Rect2(204,48,200,200))
        W.fit_label(W.label(slots,str(species["name"]),Rect2(28,275,552,60),34,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER),18)
        W.label(slots,"스타팅 해금 · "+str(basic["name"]),Rect2(28,356,552,48),23,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        var info := W.label(slots,"특성 정보 · "+PokedexExpansion.ability_text(id),Rect2(28,420,552,100),18,W.MUTED)
        info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        return
    if id in selection: selection.erase(id)
    elif selection.size() < session.MAX_STARTERS: selection.append(id)
    else:
        notice.text = "최대 %d마리까지 편성할 수 있습니다." % session.MAX_STARTERS
        return
    notice.text = ""
    _sync_selection()
func _sync_selection() -> void:
    W.clear(slots)
    if mode == "collection":
        counter.text = "포획 %d / %d" % [profile.captured_ids.size(),catalog.pokemon.size()]
        W.label(slots,"원정에서 포획한 동료들을\n이곳에서 확인할 수 있습니다.",Rect2(32,180,544,120),24,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        return
    counter.text = "원정대 · %d / %d" % [selection.size(),session.MAX_STARTERS]
    W.label(slots,"함께 떠날 포켓몬",Rect2(28,20,552,48),26,W.GOLD)
    for i in session.MAX_STARTERS:
        var row := W.button(slots,Rect2(28,96+i*120,552,100),func():
            if i < selection.size(): _select(selection[i]))
        if i < selection.size():
            var id := selection[i]
            W.sprite(row,id,Rect2(18,14,72,72))
            W.label(row,str(catalog.species(id)["name"]),Rect2(116,10,380,40),24)
            W.label(row,"첫 출전" if i == 0 else "대기 · %d번 교체" % (i+1),Rect2(116,53,380,30),16,W.MUTED)
            W.icon(row,"close",Rect2(508,36,24,24))
        else:
            row.disabled = true
            W.label(row,"빈 자리",Rect2(26,0,500,100),22,W.MUTED)
    loadout_button = W.button(slots,Rect2(28,486,552,48),_show_loadout,"출발 덱·Lv.5 능력치 확인")
    loadout_button.name = "PreviewLoadout"
    loadout_button.disabled = selection.is_empty()
    confirm_button.disabled = selection.is_empty()
    for id: int in species_buttons:
        species_buttons[id].add_theme_stylebox_override("normal",W.box(Color("23403d") if id in selection else Color("152b32"),W.GOLD if id in selection else Color("3d555a")))
func _show_loadout() -> void:
    if selection.is_empty() or is_instance_valid(loadout_panel): return
    var focused := get_viewport().gui_get_focus_owner()
    if focused != null: focused.release_focus()
    loadout_panel = StarterLoadoutPanel.new()
    loadout_panel.name = "StarterLoadout"
    loadout_panel.loadout = StarterLoadout.new(selection,catalog)
    loadout_panel.closed.connect(func(): loadout_panel = null)
    page.add_child(loadout_panel)
func _start() -> void:
    if starting: return
    var error: String = session.start_journey(selection,int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec(),full_campaign)
    if not error.is_empty():
        notice.text = error
        return
    starting = true
    confirm_button.disabled = true
    departure = JourneyTravel.new()
    add_child(departure)
    departure.arrived.connect(func(): get_tree().change_scene_to_file("res://scenes/tactical_journey.tscn"))
    var j: TacticalJourney = session.get("journey")
    get_node("/root/GameMusic").play_region(j)
    departure.start(j.current()["name"],j.biome(),j.party,"원정 출발 · 동료들과 길을 나서는 중")
func _continue() -> void:
    get_tree().change_scene_to_file("res://scenes/tactical_journey.tscn")
func _back() -> void:
    mode = "title"
    render()
func _unhandled_key_input(event: InputEvent) -> void:
    if starting: return
    if not event is InputEventKey or not event.pressed or event.echo: return
    if is_instance_valid(tutorial_prompt):
        if event.keycode == KEY_ESCAPE: _close_tutorial_offer()
        get_viewport().set_input_as_handled()
        return
    if is_instance_valid(loadout_panel):
        if event.keycode == KEY_ESCAPE: loadout_panel.close()
        get_viewport().set_input_as_handled()
        return
    if event.keycode == KEY_ESCAPE and mode != "title": _back()

func known_collection() -> Array[int]:
    var result: Array[int] = []
    for entry: Dictionary in catalog.pokemon:
        var id := int(entry["id"])
        if PokedexExpansion.form_known(id,profile.captured_ids): result.append(id)
    return result
