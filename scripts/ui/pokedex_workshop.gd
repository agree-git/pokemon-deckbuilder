class_name PokedexWorkshop
extends Control
## Camp preparation for expanded evolution paths, permanent forms and legal moves.
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
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    rebuild()
func current() -> BattlePokemon: return journey.party[clampi(selected,0,journey.party.size()-1)]
func rebuild() -> void:
    W.clear(self)
    var dim := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit(); queue_free())
    for state: String in ["normal","hover","pressed","focus"]: dim.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,.88),Color.TRANSPARENT,0))
    content = W.panel(self,Rect2(260,80,1400,920),Color("14282f"),W.GOLD)
    content.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(content,"포켓몬 연구",Rect2(32,20,800,48),30,W.GOLD)
    W.icon_button(content,"close",Rect2(1312,20,48,48),func(): closed.emit(); queue_free(),"닫기 · Esc")
    for i in journey.party.size():
        var p: BattlePokemon = journey.party[i]
        var index := i
        var button := W.button(content,Rect2(32+i*446,86,426,64),func(): selected = index; slot = 0; rebuild(),p.display_name)
        button.name = "WorkshopParty_%d" % i
        if selected == i: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var modes := ["evolution","forms","moves","machines"]
    for i in modes.size():
        var key: String = modes[i]
        var button := W.button(content,Rect2(32+i*334,168,318,52),func(): mode = key; query = ""; rebuild(),["진화 분기·준비","상시 폼","기술 훈련","기술머신"][i])
        button.name = "WorkshopTab_"+key
        if mode == key: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var p := current()
    var description := "기본 조건은 유지합니다. 장소·통신·특수 조작은 야영 행동 1회로 준비하며, 레벨 진화는 다음 레벨업에 진행합니다."
    if mode == "forms": description = "현재 지역 계통의 상시 폼을 준비합니다. 지역폼은 포획·진화로 획득하며 합체 폼은 두 포켓몬의 포획 기록이 필요합니다."
    elif mode == "moves": description = "레벨·기술머신·교배·가르침 습득 경로를 따릅니다. 훈련은 야영 행동 1회를 사용하며 선택한 기술의 덱 사본만 교체합니다."
    elif mode == "machines": description = "상인·야영 발견으로 기술머신을 획득합니다. 위에서 동료와 교체할 기술을 선택하세요. 사용 시 1개 소모하며 야영 행동은 사용하지 않습니다. · 골드 %d" % journey.gold
    var help := W.label(content,description,Rect2(32,236,1336,66),19,W.MUTED)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var search := LineEdit.new()
    search.name = "WorkshopSearch"
    search.position = Vector2(32,312)
    search.size = Vector2(600,44)
    search.placeholder_text = "이름·번호·타입 검색"
    search.text = query
    search.text_changed.connect(func(value: String): query = value; populate())
    content.add_child(search)
    if mode in ["moves","machines"]:
        for i in 4:
            var index := i
            var text := str(TacticalMoves.definition(p.learned_skills[i])["name"]) if i < p.learned_skills.size() else "빈 기술"
            var button := W.button(content,Rect2(648+i*180,312,166,44),func(): slot = index; rebuild(),text)
            button.name = "WorkshopSlot_%d" % i
            button.disabled = i > p.learned_skills.size()
            if i == slot: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var scroll := ScrollContainer.new()
    scroll.name = "WorkshopScroll"
    scroll.position = Vector2(32,374)
    scroll.size = Vector2(1336,442)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(scroll)
    rows = VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation",10)
    scroll.add_child(rows)
    populate()
    var result := W.label(content,notice,Rect2(32,840,1336,60),19,W.GOLD)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
func matches(text: String) -> bool: return query.strip_edges().is_empty() or text.to_lower().contains(query.strip_edges().to_lower())
func row(title: String,detail: String,action: Callable,button_text: String,disabled := false,sprite_id := 0) -> void:
    var panel := Panel.new()
    panel.custom_minimum_size = Vector2(1296,126)
    panel.add_theme_stylebox_override("panel",W.box(Color("1c3339"),Color("3d555a")))
    rows.add_child(panel)
    if sprite_id > 0: panel.name = "WorkshopRow_%d" % sprite_id
    var left := 128 if sprite_id > 0 else 20
    if sprite_id > 0: W.sprite(panel,sprite_id,Rect2(16,16,96,96))
    W.fit_label(W.label(panel,title,Rect2(left,8,968-left,36),22,W.TEXT))
    var label := W.label(panel,detail,Rect2(left,48,968-left,68),17,W.MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var button := W.button(panel,Rect2(994,32,272,60),action,button_text)
    button.name = "WorkshopAction"
    button.disabled = disabled
func populate() -> void:
    W.clear(rows)
    var p := current()
    if mode == "evolution":
        for rule: Dictionary in NationalEvolution.rules_for(p.species_id):
            var target := int(rule["to"])
            var name := str(PokedexExpansion.species(target)["name"])
            if not matches(name+str(target)): continue
            var disabled: bool = p.evolution_prepared == target or (rule["prepare"] and journey.step in journey.rested_steps)
            row(name,NationalEvolution.condition_text(rule),_prepare.bind(p.uid,target),"준비 완료" if p.evolution_prepared == target else ("야영 행동으로 준비" if rule["prepare"] else "분기 선택"),disabled,target)
    elif mode == "forms":
        for target: int in PokedexExpansion.forms(p.species_id):
            var entry := PokedexExpansion.species(target)
            if not matches(str(entry["name"])+str(target)): continue
            var partners := PokedexExpansion.form_requirements(target)
            var known := collection.duplicate()
            for member: BattlePokemon in journey.party: known.append(member.species_id)
            var available := PokedexExpansion.form_known(target,known)
            var detail := "상시 폼 · "+PokedexExpansion.ability_text(target)
            if not partners.is_empty(): detail = "두 포켓몬의 포획 기록 확인" if available else "추가 포획 기록이 필요한 합체 폼입니다."
            row(str(entry["name"]) if available else "미해금 합체 폼",detail,_form.bind(p.uid,target),"현재 모습" if target == p.species_id else "폼 준비",target == p.species_id or not available,target if available else 0)
    elif mode == "moves":
        for move: int in NationalEvolution.teachable_moves(p):
            var view := TacticalMoves.definition(TacticalMoves.key_for(move))
            var type := VisualCatalog.new().type_name(view["type"])
            if not matches(str(view["name"])+str(move)+type): continue
            var known := TacticalMoves.key_for(move) in p.learned_skills
            row(str(view["name"])+" · "+type,str(view["description"]),_train.bind(p.uid,move,slot),"습득 완료" if known else "야영 행동으로 훈련",known or journey.step in journey.rested_steps)
    else:
        var offers: Array = journey.camp().get("machine_offers",[])
        for i in offers.size():
            var offer: Dictionary = offers[i]
            var move := int(offer["move"])
            var view := TacticalMoves.definition(TacticalMoves.key_for(move))
            var type := VisualCatalog.new().type_name(view["type"])
            if not matches(str(view["name"])+str(move)+type): continue
            var merchant: bool = journey.camp().get("kind","") == "merchant"
            var origin := "상인 판매" if merchant else "야영 발견"
            row(origin+" · "+str(view["name"])+" · "+type,_machine_detail(move,p),_take_machine.bind(i),"획득 완료" if offer["taken"] else ("%d 골드 · 구매" % TechnicalMachines.PRICE if merchant else "기술머신 줍기"),not journey.machine_offer_reason(i).is_empty())
            rows.get_child(-1).name = "MachineOffer_%d" % i
        var owned: Array = journey.machines.keys()
        owned.sort()
        for move: int in owned:
            var count := int(journey.machines[move])
            if count <= 0: continue
            var view := TacticalMoves.definition(TacticalMoves.key_for(move))
            var type := VisualCatalog.new().type_name(view["type"])
            if not matches(str(view["name"])+str(move)+type): continue
            var known := TacticalMoves.key_for(move) in p.learned_skills
            var compatible := move in TechnicalMachines.moves(p.species_id)
            row("보유 %d개 · %s · %s" % [count,view["name"],type],_machine_detail(move,p),_use_machine.bind(p.uid,move,slot),"습득 완료" if known else ("1개 사용 · 기술 배우기" if compatible else "사용 불가"),known or not compatible or not p.alive())
            rows.get_child(-1).name = "MachineOwned_%d" % move
    if rows.get_child_count() == 0: W.label(rows,"해당하는 항목이 없습니다.",Rect2(0,0,1200,72),22,W.MUTED)
func _machine_detail(move: int,p: BattlePokemon) -> String:
    var compatible := move in TechnicalMachines.moves(p.species_id)
    return "%s · %s\n%s" % [p.display_name,"사용 가능" if compatible else "호환되지 않음",TacticalMoves.definition(TacticalMoves.key_for(move))["description"]]
func _take_machine(index: int) -> void:
    notice = journey.take_machine(index)
    if notice.is_empty(): notice = "기술머신을 획득했습니다. 보유 목록에서 사용할 수 있습니다."
    rebuild()
func _use_machine(uid: int,move: int,index: int) -> void:
    notice = journey.train_move(uid,move,index,true)
    if notice.is_empty(): notice = "기술머신 1개를 사용해 기술을 배웠습니다."
    rebuild()
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        closed.emit()
        queue_free()

func _prepare(uid: int,target: int) -> void:
    notice = journey.prepare_evolution(uid,target)
    if notice.is_empty(): notice = "진화 분기를 준비했습니다. 남은 조건을 충족하세요."
    rebuild()
func _form(uid: int,target: int) -> void:
    notice = journey.change_form(uid,target,collection)
    if notice.is_empty(): notice = "폼을 준비했습니다."
    rebuild()
func _train(uid: int,move: int,index: int) -> void:
    notice = journey.train_move(uid,move,index)
    if notice.is_empty(): notice = "기술을 훈련했습니다."
    rebuild()
