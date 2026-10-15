class_name ExpeditionOverlay
extends Control
## Native-resolution journey screens. All irreversible decisions go through RunState.
signal changed
signal restart_requested(new_seed: bool)
var run: RunState
var _catalog := VisualCatalog.new()
var action_buttons: Array[Button] = []
var heal_button: Button
var evolve_buttons: Array[Button] = []
var upgrade_select: OptionButton
var upgrade_button: Button
var _upgrade_preview: Label
var _deck_panel: Panel
var _signature := ""
const CREAM := Color("eee3c5")
const GOLD := Color("d8bd7e")
const MINT := Color("b3d3ae")

func show_run(state: RunState) -> void:
    run = state
    visible = run.phase != RunState.BATTLE
    if not visible:
        _signature = ""
        return
    var signature := "%s:%d:%s:%d:%s" % [run.phase,run.step,run.party.map(func(p: BattlePokemon): return p.snapshot()),run.deck.size(),run.rest_result]
    if signature == _signature:
        return
    _signature = signature
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()
    action_buttons.clear()
    evolve_buttons.clear()
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(_catalog.biomes[int(run.current_node["biome"])])
    background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.025,0.065,0.075,0.94)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
    _label("관동 원정대  /  햇살숲", Rect2(80,45,1000,40),26,GOLD)
    _label("시드 %d · 공유 덱 %d장 · 몬스터볼 %d개" % [run.seed_value,run.deck.size(),run.balls],Rect2(80,95,1100,40),20,MINT)
    var restart := _button("같은 원정 다시 · R",Rect2(1530,45,300,50))
    restart.pressed.connect(func(): restart_requested.emit(false))
    var fresh := _button("새 시드로 출발",Rect2(1530,110,300,50))
    fresh.pressed.connect(func(): restart_requested.emit(true))
    if run.phase == RunState.MAP:
        _build_map()
    elif run.phase == RunState.REST:
        _build_rest()
    else:
        _build_end()
    _build_party()
    _build_deck()

func _build_map() -> void:
    _label("다음 경로를 선택하세요",Rect2(80,175,1250,65),42,CREAM)
    _label(run.rest_result if not run.rest_result.is_empty() else "체력과 덱을 유지해 숲의 수호자에게 도전하세요.",Rect2(80,242,1200,42),21,MINT)
    for i in ExpeditionContent.ROUTE.size():
        var node := Panel.new()
        node.position = Vector2(80+i*195,315)
        node.size = Vector2(175,42)
        node.add_theme_stylebox_override("panel",_style(Color("45634c") if i < run.step else Color("795f35") if i == run.step else Color("192c30")))
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(node)
        _label("%d %s" % [i+1,"휴식" if ExpeditionContent.ROUTE[i][0]["kind"] == "rest" else "수호자" if i == 8 else "전투"],Rect2(node.position+Vector2(12,4),Vector2(160,35)),20,CREAM)
    var choices := run.options()
    var width := 600.0
    var start := 960.0 - (choices.size()*width + (choices.size()-1)*36)/2.0
    for i in choices.size():
        var node: Dictionary = choices[i]
        var text := "%s\n%s" % [node["name"],ExpeditionContent.kind_name(node["kind"])]
        if node.has("enemy"):
            text += "\n%s · HP %d · %s" % [node["enemy"]["name"],node["enemy"]["max_hp"],_catalog.type_name(node["enemy"]["type"])]
        else:
            text += "\n회복·부활 / 강화 / 진화 중 하나"
        var button := _button(text,Rect2(start+i*636,400,width,270))
        button.add_theme_font_size_override("font_size",25)
        if node.has("enemy"):
            button.icon = load(VisualCatalog.sprite_path(int(node["enemy"]["id"])))
            button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
        button.pressed.connect(_choose_node.bind(i))
        action_buttons.append(button)
    _label("다음 장소  %d / %d  ·  마지막 장소: 숲의 수호자" % [run.step+1,ExpeditionContent.ROUTE.size()],Rect2(80,720,1500,50),23,GOLD)

func _build_rest() -> void:
    _label(run.current_node["name"],Rect2(80,175,1200,65),42,CREAM)
    _label("이번 장소에서 행동 하나를 선택하세요. 회복과 성장을 함께 할 수는 없습니다.",Rect2(80,242,1400,42),22,MINT)
    heal_button = _button("파티 회복\n전원 최대 체력의 30% 회복\n기절 부활 · 연결된 부상 제거",Rect2(100,420,420,230))
    heal_button.add_theme_font_size_override("font_size",23)
    heal_button.pressed.connect(_rest.bind("heal",0))
    _label("포켓몬 진화 · 경험치 4",Rect2(580,355,600,42),25,GOLD)
    for i in run.party.size():
        var pokemon := run.party[i]
        var reason := run.evolve_reason(pokemon.uid)
        var evolution: Dictionary = ExpeditionContent.EVOLUTIONS.get(pokemon.species_id,{})
        var text := "%s → %s\nXP %s / 4" % [pokemon.display_name,evolution.get("name","진화 완료 / 대상 아님"),pokemon.experience_text()]
        var button := _button(text,Rect2(580,420+i*90,570,78))
        button.add_theme_font_size_override("font_size",20)
        button.disabled = not reason.is_empty()
        button.tooltip_text = reason if button.disabled else evolution["trait"] + " · 전용 기술 1장 교체 · HP 비율 유지"
        button.pressed.connect(_rest.bind("evolve",pokemon.uid))
        evolve_buttons.append(button)
    _label("기술 카드 한 장 강화",Rect2(1210,355,620,42),25,GOLD)
    upgrade_select = OptionButton.new()
    upgrade_select.position = Vector2(1210,420)
    upgrade_select.size = Vector2(610,55)
    upgrade_select.add_theme_font_size_override("font_size",19)
    for card: BattleCardInstance in run.rest_options():
        var owner := "공용" if card.owner_uid == 0 else run.member(card.owner_uid).display_name
        upgrade_select.add_item("%s · %s" % [BattleContent.CARDS[card.key]["name"],owner],card.uid)
    add_child(upgrade_select)
    _upgrade_preview = _label("",Rect2(1210,490,610,100),20,MINT)
    _upgrade_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    upgrade_button = _button("선택한 카드 강화",Rect2(1210,605,610,60))
    upgrade_button.disabled = upgrade_select.item_count == 0
    upgrade_select.item_selected.connect(func(_index: int): _update_upgrade_preview())
    upgrade_button.pressed.connect(func(): _rest("upgrade",upgrade_select.get_selected_id()))
    _update_upgrade_preview()
    var skip := _button("행동 없이 이동",Rect2(100,725,420,55))
    skip.pressed.connect(_rest.bind("skip",0))

func _update_upgrade_preview() -> void:
    if upgrade_select.item_count == 0:
        _upgrade_preview.text = "모든 기술이 이미 강화되었습니다."
        return
    for card: BattleCardInstance in run.rest_options():
        if card.uid == upgrade_select.get_selected_id():
            var preview := BattleCardInstance.new(card.uid,card.key,card.owner_uid)
            preview.upgraded = true
            var before := BattleContent.card_definition(card)
            var after := BattleContent.card_definition(preview)
            _upgrade_preview.text = "강화 후: 비용 %d\n%s" % [after["cost"],after["description"].replace("\n"," ")]
            _upgrade_preview.tooltip_text = "현재: 비용 %d · %s" % [before["cost"],before["description"].replace("\n"," ")]

func _build_end() -> void:
    var won := run.phase == RunState.CLEARED
    _label("원정 완주!" if won else "원정 실패",Rect2(80,200,1500,90),64,GOLD if won else Color("e8a496"))
    _label("숲의 수호자를 쓰러뜨렸습니다." if won else "모든 아군이 기절했습니다. 다른 경로와 덱으로 다시 도전하세요.",Rect2(80,310,1650,65),29,CREAM)
    _label("진행 %d / 9  ·  전투 승리 %d회  ·  포획 %d회  ·  총 %d턴" % [9 if won else run.step+1,run.wins,run.capture_count,run.total_turns],Rect2(80,420,1660,65),29,MINT)
    var names := PackedStringArray()
    for node: Dictionary in run.route_history:
        names.append(node["name"])
    var route := _label("지나온 경로\n" + " → ".join(names),Rect2(80,530,1650,160),23,CREAM)
    route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label("같은 시드로 다시 도전하거나 새 시드로 시작할 수 있습니다.",Rect2(80,735,1650,55),24,GOLD)

func _build_party() -> void:
    for i in run.party.size():
        var pokemon := run.party[i]
        var box := Panel.new()
        box.position = Vector2(80+i*590,845)
        box.size = Vector2(560,165)
        box.add_theme_stylebox_override("panel",_style(Color("172e30")))
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(box)
        var sprite := TextureRect.new()
        sprite.texture = load(VisualCatalog.sprite_path(pokemon.species_id))
        sprite.position = box.position+Vector2(12,28)
        sprite.size = Vector2(96,96)
        sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(sprite)
        _label("%s  ·  HP %d / %d\n경험치 %s  ·  %s" % [pokemon.display_name,pokemon.hp,pokemon.max_hp,pokemon.experience_text(),"기절" if not pokemon.alive() else "전투 가능"],Rect2(box.position+Vector2(125,25),Vector2(420,100)),23,CREAM)
    _label("R 같은 시드  ·  Shift+R 새 시드  ·  F2 아트 랩  ·  F11 전체화면  ·  진행은 앱을 닫으면 초기화됩니다.",Rect2(80,1030,1740,35),17,MINT)

func _build_deck() -> void:
    var open := _button("덱 확인 · %d장" % run.deck.size(),Rect2(1530,195,300,50))
    _deck_panel = Panel.new()
    _deck_panel.position = Vector2(1190,270)
    _deck_panel.size = Vector2(640,535)
    _deck_panel.add_theme_stylebox_override("panel",_style(Color("13282c")))
    add_child(_deck_panel)
    var close := Button.new()
    close.text = "닫기"
    close.position = Vector2(490,15)
    close.size = Vector2(130,45)
    close.pressed.connect(func(): _deck_panel.hide())
    _deck_panel.add_child(close)
    var list := RichTextLabel.new()
    list.position = Vector2(25,80)
    list.size = Vector2(590,435)
    list.add_theme_font_size_override("normal_font_size",21)
    for card: BattleCardInstance in run.deck:
        var owner := "공용" if card.owner_uid == 0 else run.member(card.owner_uid).display_name
        list.text += "%s · %s\n" % [BattleContent.card_definition(card)["name"],owner]
    _deck_panel.add_child(list)
    open.pressed.connect(func(): _deck_panel.visible = not _deck_panel.visible)
    _deck_panel.hide()

func _choose_node(index: int) -> void:
    if run.choose_node(index).is_empty():
        changed.emit()
func _rest(action: String, uid: int) -> void:
    if run.rest(action,uid).is_empty():
        changed.emit()
func _label(value: String,rect: Rect2,font_size: int,color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = rect.position
    label.size = rect.size
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    add_child(label)
    return label
func _button(value: String,rect: Rect2) -> Button:
    var button := Button.new()
    button.text = value
    button.position = rect.position
    button.size = rect.size
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    add_child(button)
    return button
func _style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = GOLD.darkened(0.35)
    style.set_border_width_all(1)
    return style
