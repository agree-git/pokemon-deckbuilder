class_name PokedexWorkshop
extends Control
## Automatic evolution guide, permanent forms and full legal move training.
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
var journey: TacticalJourney
var collection: Array = []
var selected := 0
var mode := "evolution"
var slot := 0
var query := ""
var notice := ""
var content: Control
var rows: VBoxContainer
var empty_label: Label
var search: LineEdit
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    rebuild()
func current() -> BattlePokemon: return journey.party[clampi(selected,0,journey.party.size()-1)]
func rebuild() -> void:
    set_process(false)
    W.clear(self)
    var dim := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit(); queue_free())
    for state: String in ["normal","hover","pressed","focus"]: dim.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,.88),Color.TRANSPARENT,0))
    content = W.panel(self,Rect2(320,80,1280,920),Color("14282f"),W.GOLD)
    content.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(content,"포켓몬 연구",Rect2(32,24,1120,48),30,W.GOLD)
    W.icon_button(content,"close",Rect2(1196,24,52,52),func(): closed.emit(); queue_free(),"닫기 · Esc")
    W.label(content,"연구할 동료",Rect2(32,96,232,32),18,W.MUTED)
    W.panel(content,Rect2(288,104,1,704),Color("344b51"))
    for i in journey.party.size():
        var p: BattlePokemon = journey.party[i]
        var index := i
        var button := W.button(content,Rect2(32,152+i*112,232,88),func(): selected = index; slot = 0; rebuild())
        W.sprite(button,p.species_id,Rect2(12,12,64,64))
        var name_label := W.label(button,p.display_name,Rect2(88,12,128,36),19)
        W.fit_label(name_label)
        W.label(button,"Lv. %d" % p.level,Rect2(88,48,128,28),15,W.MUTED)
        button.tooltip_text = p.display_name
        button.name = "WorkshopParty_%d" % i
        if selected == i: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var modes := ["evolution","forms","moves","machines"]
    for i in modes.size():
        var key: String = modes[i]
        var x := 312 if i == 0 else 496+(i-1)*168
        var button := W.button(content,Rect2(x,104,160 if i == 0 else 144,48),func(): mode = key; query = ""; rebuild(),["진화 안내","상시 폼","기술 훈련","기술머신"][i])
        button.add_theme_font_size_override("font_size",18)
        W.fit_button(button)
        button.name = "WorkshopTab_"+key
        if mode == key: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var p := current()
    var description := "레벨·친밀도·시간·기술 조건을 충족하면 레벨업 시 자동 진화합니다. 분기를 선택할 필요가 없으며 진화 재료는 가방에서 사용합니다."
    if mode == "forms": description = "현재 지역 계통의 상시 폼을 준비합니다. 지역폼은 포획·진화로 획득하며 합체 폼은 두 포켓몬의 포획 기록이 필요합니다."
    elif mode == "moves": description = "현재 레벨까지의 자력기 전체 100골드 · 그 외 호환 기술 200골드 · 야영 행동·횟수 제한 없음 · 골드 %d" % journey.gold
    elif mode == "machines": description = "상인·야영 발견으로 기술머신을 획득합니다. 위에서 동료와 교체할 기술을 선택하세요. 사용 시 1개 소모하며 야영 행동은 사용하지 않습니다. · 골드 %d" % journey.gold
    var help := W.label(content,description,Rect2(312,184,936,64),18,W.MUTED)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    search = LineEdit.new()
    search.name = "WorkshopSearch"
    search.position = Vector2(312,272)
    search.size = Vector2(528,48)
    search.placeholder_text = "이름·번호·타입 검색"
    search.text = query
    search.text_changed.connect(_search_changed)
    content.add_child(search)
    if mode in ["moves","machines"]:
        W.label(content,"교체할 기술",Rect2(312,344,104,56),17,W.MUTED)
        for i in 4:
            var index := i
            var text := str(TacticalMoves.definition(p.learned_skills[i])["name"]) if i < p.learned_skills.size() else "빈 기술"
            var button := W.button(content,Rect2(440+i*200,344,176,56),func(): slot = index; rebuild(),text)
            button.add_theme_font_size_override("font_size",18)
            button.tooltip_text = text
            W.fit_button(button)
            button.name = "WorkshopSlot_%d" % i
            button.disabled = i > p.learned_skills.size()
            if i == slot: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var scroll := ScrollContainer.new()
    scroll.name = "WorkshopScroll"
    scroll.position = Vector2(312,432 if mode in ["moves","machines"] else 344)
    scroll.size = Vector2(936,376 if mode in ["moves","machines"] else 464)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(scroll)
    rows = VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation",24)
    scroll.add_child(rows)
    populate()
    var result := W.label(content,notice,Rect2(312,840,936,48),18,W.GOLD)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
func matches(text: String) -> bool: return query.strip_edges().is_empty() or text.to_lower().contains(query.strip_edges().to_lower())
func row(title: String,detail: String,action: Callable,button_text: String,disabled := false,sprite_id := 0) -> void:
    var panel := Panel.new()
    panel.custom_minimum_size = Vector2(896,144)
    panel.add_theme_stylebox_override("panel",W.box(Color("1c3339"),Color("3d555a")))
    rows.add_child(panel)
    if sprite_id > 0: panel.name = "WorkshopRow_%d" % sprite_id
    var left := 128 if sprite_id > 0 else 24
    if sprite_id > 0: W.sprite(panel,sprite_id,Rect2(24,28,80,80))
    var heading := W.label(panel,title,Rect2(left,16,664-left,36),20,W.TEXT)
    heading.mouse_filter = Control.MOUSE_FILTER_PASS
    heading.tooltip_text = title
    W.fit_label(heading)
    var label := W.label(panel,detail,Rect2(left,60,664-left,64),17,W.MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.max_lines_visible = 2
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.mouse_filter = Control.MOUSE_FILTER_PASS
    label.tooltip_text = detail
    if action.is_valid():
        var button := W.button(panel,Rect2(688,44,184,56),action,button_text)
        button.add_theme_font_size_override("font_size",18)
        W.fit_button(button)
        button.name = "WorkshopAction"
        button.disabled = disabled
    else:
        W.label(panel,button_text,Rect2(688,44,184,56),18,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER).name = "AutomaticEvolution"
func populate() -> void:
    W.clear(rows)
    var p := current()
    if mode == "evolution":
        for rule: Dictionary in NationalEvolution.rules_for(p.species_id):
            var target := int(rule["to"])
            var name := str(PokedexExpansion.species(target)["name"])
            var detail := NationalEvolution.condition_text(rule)
            if SpecialEvolution.eligible(p.species_id): detail = SpecialEvolution.summary(p,journey.party.size(),journey.balls,VisualCatalog.new())
            row(name,detail,Callable(),"재료 사용" if rule["method"] == "item" else "자동 진화",false,target)
            rows.get_child(-1).set_meta("search_terms",name+str(target))
    elif mode == "forms":
        for target: int in PokedexExpansion.forms(p.species_id):
            var entry := PokedexExpansion.species(target)
            var partners := PokedexExpansion.form_requirements(target)
            var known := collection.duplicate()
            for member: BattlePokemon in journey.party: known.append(member.species_id)
            var available := PokedexExpansion.form_known(target,known)
            var detail := "상시 폼 · "+PokedexExpansion.ability_text(target)
            if not partners.is_empty(): detail = "두 포켓몬의 포획 기록 확인" if available else "추가 포획 기록이 필요한 합체 폼입니다."
            row(str(entry["name"]) if available else "미해금 합체 폼",detail,_form.bind(p.uid,target),"현재 모습" if target == p.species_id else "폼 준비",target == p.species_id or not available,target if available else 0)
            rows.get_child(-1).set_meta("search_terms",str(entry["name"])+str(target))
    elif mode == "moves":
        for move: int in journey.training_offers(p.uid):
            var view := _move_definition(move)
            var type := VisualCatalog.new().type_name(view["type"])
            var known := TacticalMoves.key_for(move) in p.learned_skills
            var price := journey.train_move_price(p.uid,move)
            row(("자력기" if price == 100 else "기타 습득")+" · "+str(view["name"])+" · "+type,str(view["description"]),_train.bind(p.uid,move,slot),"습득 완료" if known else "훈련 · %d골드" % price,not journey.train_move_reason(p.uid,move,slot).is_empty())
            rows.get_child(-1).get_node("WorkshopAction").tooltip_text = journey.train_move_reason(p.uid,move,slot)
            rows.get_child(-1).set_meta("search_terms",str(view["name"])+str(move)+type)
    else:
        var offers: Array = journey.camp().get("machine_offers",[])
        for i in offers.size():
            var offer: Dictionary = offers[i]
            var move := int(offer["move"])
            var view := _move_definition(move)
            var type := VisualCatalog.new().type_name(view["type"])
            var merchant: bool = journey.camp().get("kind","") == "merchant"
            var origin := "상인 판매" if merchant else "야영 발견"
            row(origin+" · "+str(view["name"])+" · "+type,_machine_detail(move,p),_take_machine.bind(i),"획득 완료" if offer["taken"] else ("%d 골드 · 구매" % TechnicalMachines.PRICE if merchant else "기술머신 줍기"),not journey.machine_offer_reason(i).is_empty())
            rows.get_child(-1).set_meta("search_terms",str(view["name"])+str(move)+type)
            rows.get_child(-1).name = "MachineOffer_%d" % i
        var owned: Array = journey.machines.keys()
        owned.sort()
        for move: int in owned:
            var count := int(journey.machines[move])
            if count <= 0: continue
            var view := _move_definition(move)
            var type := VisualCatalog.new().type_name(view["type"])
            var known := TacticalMoves.key_for(move) in p.learned_skills
            var compatible := move in TechnicalMachines.moves(p.species_id)
            row("보유 %d개 · %s · %s" % [count,view["name"],type],_machine_detail(move,p),_use_machine.bind(p.uid,move,slot),"습득 완료" if known else ("배우기 · 1개" if compatible else "사용 불가"),known or not compatible or not p.alive())
            rows.get_child(-1).set_meta("search_terms",str(view["name"])+str(move)+type)
            rows.get_child(-1).name = "MachineOwned_%d" % move
    empty_label = W.label(rows,"",Rect2(0,0,896,72),22,W.MUTED)
    empty_label.name = "WorkshopEmpty"
    empty_label.custom_minimum_size = Vector2(896,72)
    _filter_rows()
func _search_changed(value: String) -> void:
    query = value
    # text_changed can fire inside the OS IME commit; keep this callback non-visual.
    set_process(true)
func _process(_delta: float) -> void:
    if is_instance_valid(search) and search.has_ime_text(): return
    set_process(false)
    if not is_instance_valid(search) or not is_instance_valid(rows): return
    query = search.text
    _filter_rows()
func _filter_rows() -> void:
    # Do not rebuild nodes, rewrite LineEdit.text, grab focus or interrupt IME here.
    var count := 0
    for panel: Control in rows.get_children():
        if panel == empty_label: continue
        panel.visible = matches(str(panel.get_meta("search_terms","")))
        if panel.visible: count += 1
    empty_label.text = "현재 배울 수 있는 훈련 기술이 없습니다." if mode == "moves" and query.is_empty() else "해당하는 항목이 없습니다."
    empty_label.visible = count == 0
    (rows.get_parent() as ScrollContainer).scroll_vertical = 0
func _machine_detail(move: int,p: BattlePokemon) -> String:
    var compatible := move in TechnicalMachines.moves(p.species_id)
    return "%s · %s\n%s" % [p.display_name,"사용 가능" if compatible else "호환되지 않음",_move_definition(move)["description"]]
func _take_machine(index: int) -> void:
    notice = journey.take_machine(index)
    if notice.is_empty(): notice = "기술머신을 획득했습니다. 보유 목록에서 사용할 수 있습니다."
    rebuild()
func _use_machine(uid: int,move: int,index: int) -> void:
    notice = journey.train_move(uid,move,index,true)
    if notice.is_empty(): notice = "기술머신 1개를 사용해 기술을 배웠습니다."
    rebuild()
func _input(event: InputEvent) -> void:
    # The search field can consume Escape before unhandled input is dispatched.
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        closed.emit()
        queue_free()

func _form(uid: int,target: int) -> void:
    notice = journey.change_form(uid,target,collection)
    if notice.is_empty(): notice = "폼을 준비했습니다."
    rebuild()
func _train(uid: int,move: int,index: int) -> void:
    notice = journey.train_move(uid,move,index)
    if notice.is_empty(): notice = "기술을 훈련했습니다. 골드만 소비하며 야영 행동은 유지됩니다."
    rebuild()

func _move_definition(move:int) -> Dictionary:
    return PlayerTechniques.definition(TacticalMoves.key_for(move),journey.battle.player_moves_version) if journey.full_campaign and journey.route.generation>=10 else TacticalMoves.definition(TacticalMoves.key_for(move))
