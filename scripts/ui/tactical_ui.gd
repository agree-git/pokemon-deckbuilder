class_name TacticalUI
extends Control
## Trial view. Combat decisions are resolved by TacticalBattle before presentation.
const W = preload("res://scripts/ui/combat_widgets.gd")
const GOLD := Color("edcb80")
const CREAM := Color("eee5cd")
const MINT := Color("b5e1c3")
var battle: TacticalBattle
var catalog := VisualCatalog.new()
var stage := PixelStage.new()
var busy := false
var skills: Array[Button] = []
var party_buttons: Array[Button] = []
var relic_buttons: Dictionary = {}
var trainer_buttons: Dictionary = {}
var end_button: Button
var restart_button: Button
var old_button: Button
var lab_button: Button
var history_button: Button
var ally_bar: ColorRect
var enemy_bar: ColorRect
var energy_label: Label
var status_label: Label
var ally_label: Label
var enemy_label: Label
var intent_label: Label
var opening_label: Label
var queue_label: Label
var notice: Label
var banner: Label
var damage_layer := Control.new()
var hand_row := HBoxContainer.new()
var hand_scroll := ScrollContainer.new()
var log_panel: Control
var log_text := RichTextLabel.new()
var result: Control
var result_title: Label
var result_detail: Label
var result_restart: Button
var menu_panel: Control
var help_panel: Control
var pile_panel: Control
var menu_button: Button
var help_button: Button
var draw_button: Button
var discard_button: Button
var relic_chip: Button
var ally_statuses := Control.new()
var enemy_statuses := Control.new()
var break_pips: Array[Panel] = []
var enemy_slots: Array[Button] = []
var skill_names: Array[Label] = []
var skill_values: Array[Label] = []
var skill_costs: Array[Label] = []
var skill_icons: Array[TextureRect] = []
var party_names: Array[Label] = []
var party_bars: Array[ColorRect] = []
var party_values: Array[Label] = []
var draw_count: Label
var discard_count: Label
var switch_label: Label
var _notice_tween: Tween
var _visual_enemy: BattlePokemon
var _banner_tween: Tween
var _shake: Tween
var _damage_events: Array[Dictionary] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle = get_node("/root/BattleSession").get("tactics")
    _theme()
    stage.source_ratio = Vector2(0.25,0.425)
    stage.target_ratio = Vector2(0.73,0.42)
    stage.canvas.sprite_zoom = 4
    stage.canvas.show_nameplates = false
    stage.canvas.use_effect_statuses = false
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(stage)
    stage.canvas.background = VisualCatalog.biome_texture(catalog.biomes[3])
    stage.canvas.effect.speed = 2.4
    stage.canvas.effect.finished.connect(_finished)
    stage.canvas.effect.impact.connect(_impact)
    _build()
    _refresh()

func _theme() -> void:
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):550.0}
    theme = Theme.new()
    theme.default_font = font
    theme.default_font_size = 19
    theme.set_color("font_color","Label",CREAM)
    theme.set_color("font_color","Button",CREAM)
    theme.set_color("font_disabled_color","Button",Color("71858b"))
    for state: String in ["normal","hover","pressed","disabled","focus"]:
        var fill := Color("1a2e35") if state in ["normal","disabled"] else Color("2d454c")
        if state == "focus": fill = Color.TRANSPARENT
        var border := GOLD if state in ["hover","pressed","focus"] else Color("3d555a")
        theme.set_stylebox(state,"Button",W.box(fill,border))
    var tooltip_box := W.box(Color("101f27"),Color("77908d"))
    tooltip_box.set_content_margin_all(12)
    theme.set_stylebox("panel","TooltipPanel",tooltip_box)
    theme.set_font_size("font_size","TooltipLabel",18)

func _build() -> void:
    W.panel(self,Rect2(0,0,1920,72),Color(0.035,0.075,0.095,0.95),Color.TRANSPARENT,0)
    W.icon(self,"grass",Rect2(42,23,28,28))
    _label("햇살숲",Rect2(86,16,190,40),23)
    relic_chip = W.button(self,Rect2(274,16,208,40),func(): _open_overlay(menu_panel))
    W.icon(relic_chip,"seed",Rect2(12,8,24,24)).name = "Icon"
    W.label(relic_chip,"",Rect2(48,0,146,40),17,W.MUTED).name = "Title"
    status_label = _label("",Rect2(830,18,260,36),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    queue_label = _label("",Rect2(1280,19,180,34),16,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    for i in battle.enemies.size():
        var slot := W.button(self,Rect2(1620-(battle.enemies.size()-i)*58,12,48,48),func(): pass)
        W.sprite(slot,battle.enemies[i].species_id,Rect2(0,0,48,48))
        enemy_slots.append(slot)
    history_button = W.icon_button(self,"history",Rect2(1660,14,48,44),func(): _open_overlay(log_panel),"전투 기록")
    help_button = W.icon_button(self,"help",Rect2(1724,14,48,44),func(): _open_overlay(help_panel),"전투 도움말 · F1")
    menu_button = W.icon_button(self,"menu",Rect2(1788,14,84,44),func(): _open_overlay(menu_panel),"메뉴 · Esc")
    _build_combat_hud()
    _build_actions()
    menu_panel = _build_menu()
    help_panel = _build_help()
    _build_log()
    pile_panel = _modal("카드 더미",Rect2(590,180,740,710))
    _build_result()
    notice = _label("",Rect2(590,644,670,34),18,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    notice.z_index = 25
    notice.modulate.a = 0
    banner = _label("",Rect2(700,220,520,112),32,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    banner.add_theme_stylebox_override("normal",W.box(Color(0.04,0.08,0.10,0.95),Color("756d4a")))
    banner.modulate.a = 0
    banner.z_index = 30
    damage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    damage_layer.z_index = 25
    add_child(damage_layer)

func _build_combat_hud() -> void:
    for at: Vector2 in [Vector2(315,565),Vector2(1237,558)]:
        W.panel(self,Rect2(at,Vector2(330,90)),Color(0.04,0.085,0.10,0.93),Color("3f5653"))
    ally_label = _label("",Rect2(335,573,210,32),21)
    enemy_label = _label("",Rect2(1257,566,210,32),21)
    _label("HP",Rect2(335,608,35,24),13,W.MUTED)
    _label("HP",Rect2(1257,601,35,24),13,W.MUTED)
    ally_bar = W.bar(self,Rect2(335,638,290,7))
    enemy_bar = W.bar(self,Rect2(1257,631,290,7))
    # The HP values stay separate from names and status icons.
    _label("",Rect2(380,605,245,28),17,CREAM,HORIZONTAL_ALIGNMENT_RIGHT).name = "AllyHP"
    _label("",Rect2(1302,598,245,28),17,CREAM,HORIZONTAL_ALIGNMENT_RIGHT).name = "EnemyHP"
    W.icon(self,"grass",Rect2(591,578,24,24)).name = "AllyType"
    W.icon(self,"grass",Rect2(1513,571,24,24)).name = "EnemyType"
    ally_statuses.position = Vector2(335,662)
    ally_statuses.size = Vector2(400,32)
    ally_statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ally_statuses)
    enemy_statuses.position = Vector2(1580,604)
    enemy_statuses.size = Vector2(400,32)
    enemy_statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(enemy_statuses)
    # A compact attack badge sits above the enemy, like intent in deck-building games.
    var intent_box := W.button(self,Rect2(1338,269,128,88),func(): pass)
    intent_box.name = "Intent"
    W.icon(intent_box,"attack",Rect2(16,15,32,32)).name = "Icon"
    intent_label = W.label(intent_box,"",Rect2(54,7,60,48),29,Color("f1b69b"),HORIZONTAL_ALIGNMENT_CENTER)
    W.label(intent_box,"",Rect2(0,53,128,27),14,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER).name = "Title"
    var break_box := W.button(self,Rect2(1257,657,290,32),func(): pass)
    break_box.name = "Break"
    W.icon(break_box,"break",Rect2(9,6,20,20))
    opening_label = W.label(break_box,"빈틈",Rect2(37,1,65,30),15,W.MUTED)
    for i in 3:
        break_pips.append(W.panel(break_box,Rect2(112+i*39,10,30,12),Color("34484e"),Color.TRANSPARENT,3))
    W.label(break_box,"",Rect2(235,1,45,30),16,GOLD,HORIZONTAL_ALIGNMENT_CENTER).name = "Burst"

func _build_actions() -> void:
    # One action area: skills above cards; reserve Pokemon and energy to the left.
    for i in 7:
        _shade(Rect2(0,724+i*8,1920,8),Color(0.025,0.06,0.075,0.12+i*0.12))
    _shade(Rect2(0,780,1920,300),Color(0.025,0.06,0.075,0.98))
    for i in 3:
        var button := W.button(self,Rect2(575+i*316,710,296,68),func(): _skill(TacticalContent.SKILLS[battle.active().species_id][i]))
        skill_icons.append(W.icon(button,"grass",Rect2(17,18,32,32)))
        skill_names.append(W.label(button,"",Rect2(65,6,167,29),18))
        skill_values.append(W.label(button,"",Rect2(65,34,181,25),14,W.MUTED))
        skill_costs.append(W.badge(button,"",Rect2(248,18,32,32)))
        skills.append(button)
    _label("파티",Rect2(48,840,80,28),15,W.MUTED)
    switch_label = _label("",Rect2(142,840,212,28),15,MINT,HORIZONTAL_ALIGNMENT_RIGHT)
    for i in 3:
        var button := W.button(self,Rect2(48+i*106,882,96,158),func(): _switch(battle.party[i].uid))
        W.sprite(button,battle.party[i].species_id,Rect2(16,4,64,64))
        W.label(button,["Q","W","E"][i],Rect2(7,3,20,20),11,W.MUTED)
        party_names.append(W.label(button,"",Rect2(2,68,92,28),14,CREAM,HORIZONTAL_ALIGNMENT_CENTER))
        party_values.append(W.label(button,"",Rect2(2,103,92,24),13,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER))
        party_bars.append(W.bar(button,Rect2(12,140,72,4)))
        party_buttons.append(button)
    W.panel(self,Rect2(410,878,112,112),Color("2d3d3c"),Color("aa975f"),56)
    W.icon(self,"energy",Rect2(450,889,32,32))
    energy_label = _label("",Rect2(411,924,110,53),38,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var energy_tip := W.button(self,Rect2(410,878,112,112),func(): pass)
    energy_tip.flat = true
    energy_tip.name = "Energy"
    # A transparent hit surface gives the energy orb its complete tooltip.
    for state: String in ["normal","hover","pressed","focus"]:
        energy_tip.add_theme_stylebox_override(state,W.box(Color.TRANSPARENT,Color.TRANSPARENT,56))
    _label("에너지",Rect2(410,839,112,30),15,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    _label("트레이너 카드",Rect2(575,793,300,26),14,W.MUTED)
    hand_scroll.position = Vector2(575,830)
    hand_scroll.size = Vector2(942,235)
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(hand_scroll)
    hand_row.add_theme_constant_override("separation",14)
    hand_scroll.add_child(hand_row)
    draw_button = _pile_button("draw",Rect2(432,1007,72,44),"뽑을 더미",func(): _show_pile("draw"))
    draw_count = draw_button.get_node("Count")
    discard_button = _pile_button("discard",Rect2(1541,1007,72,44),"버린 더미",func(): _show_pile("discard"))
    discard_count = discard_button.get_node("Count")
    end_button = W.button(self,Rect2(1640,900,232,76),_end)
    end_button.add_theme_stylebox_override("normal",W.box(Color("a7915d"),Color("e6c97f")))
    end_button.add_theme_stylebox_override("hover",W.box(Color("c2a86a"),GOLD))
    W.label(end_button,"턴 종료",Rect2(12,0,173,76),23,Color("10232b"),HORIZONTAL_ALIGNMENT_CENTER).name = "Title"
    W.icon(end_button,"next",Rect2(187,26,24,24))
    W.label(self,"ENTER",Rect2(1640,989,232,25),13,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _pile_button(key: String,rect: Rect2,title: String,action: Callable) -> Button:
    var button := W.button(self,rect,action)
    W.icon(button,key,Rect2(9,10,24,24))
    W.label(button,"",Rect2(36,0,30,44),17,CREAM,HORIZONTAL_ALIGNMENT_CENTER).name = "Count"
    button.tooltip_text = title+" · 클릭하여 확인"
    return button

func _modal(title: String,rect: Rect2) -> Control:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 80
    add_child(overlay)
    var dismiss := W.button(overlay,Rect2(0,0,1920,1080),func(): overlay.hide())
    for state: String in ["normal","hover","pressed","focus","disabled"]:
        dismiss.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.65),Color.TRANSPARENT,0))
    var body := W.panel(overlay,rect,Color("142831"),Color("536b6e"),12)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,title,Rect2(32,22,rect.size.x-112,46),27)
    var close := W.icon_button(body,"close",Rect2(rect.size.x-76,22,44,44),func(): overlay.hide(),"닫기 · Esc")
    close.name = "Close"
    overlay.hide()
    return overlay

func _build_menu() -> Control:
    var overlay := _modal("메뉴",Rect2(1250,96,622,900))
    var body: Panel = overlay.get_node("Body")
    _label("전투 특성",Rect2(32,96,470,32),17,W.MUTED,HORIZONTAL_ALIGNMENT_LEFT,body)
    var relic_icons := {"seed_relay":"seed","switch_power":"switch","break_focus":"break"}
    var index := 0
    for key: String in TacticalContent.RELICS:
        var button := W.button(body,Rect2(32,146+index*68,558,56),restart.bind(key))
        W.icon(button,relic_icons[key],Rect2(18,12,32,32))
        W.label(button,TacticalContent.RELICS[key]["name"],Rect2(68,0,410,56),19)
        W.icon(button,"check",Rect2(510,16,24,24)).name = "Selected"
        button.tooltip_text = TacticalContent.RELICS[key]["description"]+"\n선택하면 같은 시드로 전투를 새로 시작합니다."
        relic_buttons[key] = button
        index += 1
    _label("특성 변경 시 전투를 처음부터 시작합니다.",Rect2(32,356,558,28),15,W.MUTED,HORIZONTAL_ALIGNMENT_LEFT,body)
    restart_button = _menu_action(body,"restart","다시 시작","R",420,restart)
    old_button = _menu_action(body,"route","짧은 원정","F3",492,_old_run)
    lab_button = _menu_action(body,"lab","아트 랩","F2",564,_open_lab)
    _menu_action(body,"normal","화면 전환","F11",636,_fullscreen)
    _menu_action(body,"exhaust","소진된 카드","",708,func(): _show_pile("exhausted"))
    _label("1 / 2 / 3  기술     Q / W / E  교체",Rect2(32,821,558,32),16,W.MUTED,HORIZONTAL_ALIGNMENT_LEFT,body)
    return overlay

func _menu_action(body: Node,icon_key: String,title: String,key: String,y: int,action: Callable) -> Button:
    var button := W.button(body,Rect2(32,y,558,56),action)
    W.icon(button,icon_key,Rect2(18,12,32,32))
    W.label(button,title,Rect2(68,0,360,56),19)
    W.label(button,key,Rect2(440,0,88,56),15,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    return button

func _build_help() -> Control:
    var overlay := _modal("전투 도움말",Rect2(420,175,1080,720))
    var body: Panel = overlay.get_node("Body")
    var steps := [
        ["energy","기술과 카드","기술과 손패는 에너지를 공유합니다.\n턴마다 에너지 3 · 카드 5장\n각 기술은 포켓몬당 턴 1회"],
        ["break","빈틈 3 → 브레이크","약점 · 상태 · 분석 · 견제\n서로 다른 방법을 3번 사용하세요.\n적 행동 취소 · 다음 공격 ×2"],
        ["next","격파하고 이어가기","브레이크와 직접 격파 시 환급\n에너지 환급은 합쳐서 턴당 2회\n다음 적도 같은 턴에 공격할 수 있습니다."],
    ]
    for i in steps.size():
        var x := 36+i*340
        W.icon(body,steps[i][0],Rect2(x,118,48,48))
        W.label(body,steps[i][1],Rect2(x,186,316,40),22,GOLD)
        W.label(body,steps[i][2],Rect2(x,247,320,125),16,CREAM)
    W.panel(body,Rect2(36,420,1008,164),Color("203940"),Color.TRANSPARENT)
    W.icon(body,"switch",Rect2(60,446,32,32))
    W.label(body,"첫 교체 무료 · 추가 교체는 에너지 1",Rect2(112,437,860,44),21)
    W.label(body,"1턴: 씨뿌리기 + 분석 → 턴 종료\n2턴: 파이리 교체 → 불꽃세례 → 화염방사",Rect2(60,495,940,70),18,W.MUTED)
    W.label(body,"아이콘과 카드에 마우스를 올리면 자세한 효과를 확인할 수 있습니다.",Rect2(36,627,1008,40),18,W.MUTED)
    return overlay

func _build_log() -> void:
    log_panel = _modal("전투 기록",Rect2(540,160,840,760))
    log_text.position = Vector2(32,100)
    log_text.size = Vector2(776,620)
    log_text.scroll_following = true
    log_text.add_theme_font_size_override("normal_font_size",18)
    log_panel.get_node("Body").add_child(log_text)

func _build_result() -> void:
    result = _modal("",Rect2(580,220,760,630))
    result.z_index = 100
    result.get_node("Body/Close").hide()
    result.get_child(0).disabled = true
    var body: Panel = result.get_node("Body")
    result_title = W.label(body,"",Rect2(36,50,688,80),46,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    for i in 3: W.sprite(body,battle.party[i].species_id,Rect2(202+i*104,165,96,96))
    result_detail = W.label(body,"",Rect2(36,290,688,50),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    result_restart = W.button(body,Rect2(200,395,360,68),restart,"다시 하기")
    W.button(body,Rect2(200,483,360,56),_old_run,"짧은 원정으로")

func _open_overlay(overlay: Control) -> void:
    if result.visible: return
    _close_overlays()
    overlay.show()
    overlay.move_to_front()
func _close_overlays() -> void:
    for overlay: Control in [menu_panel,help_panel,log_panel,pile_panel]:
        if overlay != null: overlay.hide()
func _overlay_open() -> bool:
    return menu_panel.visible or help_panel.visible or log_panel.visible or pile_panel.visible
func _show_pile(key: String) -> void:
    var titles := {"draw":"뽑을 더미","discard":"버린 더미","exhausted":"소진된 카드"}
    var pile: Array = {"draw":battle.draw_pile,"discard":battle.discard,"exhausted":battle.exhausted}[key]
    var body: Panel = pile_panel.get_node("Body")
    if body.has_node("Cards"): body.get_node("Cards").free()
    var text := RichTextLabel.new()
    text.name = "Cards"
    text.position = Vector2(32,100)
    text.size = Vector2(676,566)
    text.add_theme_font_size_override("normal_font_size",19)
    text.text = titles[key]+" · %d장\n\n" % pile.size()
    if pile.is_empty(): text.text += "카드가 없습니다."
    # Inspection groups equal cards and does not reveal the hidden draw order.
    var counts: Dictionary = {}
    for card: BattleCardInstance in pile: counts[card.key] = int(counts.get(card.key,0))+1
    for card_key: String in TacticalContent.CARDS:
        if counts.has(card_key):
            var card: Dictionary = TacticalContent.CARDS[card_key]
            text.text += "%s  ×%d\n%s\n\n" % [card["name"],counts[card_key],card["description"]]
    body.add_child(text)
    _open_overlay(pile_panel)

func _refresh() -> void:
    var foe := _visual_enemy if busy and _visual_enemy != null else battle.enemy()
    stage.canvas.set_species(battle.active().species_id,foe.species_id,catalog,false)
    stage.canvas.ally_statuses.assign(battle.active().statuses.keys())
    stage.canvas.enemy_statuses.assign(foe.statuses.keys())
    status_label.text = "턴 %d" % battle.turn
    queue_label.text = "상대 %d / %d" % [battle.enemy_index+1,battle.enemies.size()]
    for i in enemy_slots.size():
        var p := battle.enemies[i]
        enemy_slots[i].tooltip_text = "%s · HP %d / %d%s" % [p.display_name,p.hp,p.max_hp," · 기절" if not p.alive() else ""]
        enemy_slots[i].get_child(0).modulate.a = 0.25 if not p.alive() else 1.0
        enemy_slots[i].add_theme_stylebox_override("normal",W.box(Color("1a2e35"),GOLD if i == battle.enemy_index else Color.TRANSPARENT))
    W.fill_bar(ally_bar,battle.active().hp,battle.active().max_hp)
    W.fill_bar(enemy_bar,foe.hp,foe.max_hp)
    ally_label.text = battle.active().display_name
    enemy_label.text = foe.display_name
    get_node("AllyHP").text = "%d / %d" % [battle.active().hp,battle.active().max_hp]
    get_node("EnemyHP").text = "%d / %d" % [foe.hp,foe.max_hp]
    get_node("AllyType").texture = W.texture(battle.active().type)
    get_node("EnemyType").texture = W.texture(foe.type)
    _refresh_statuses(ally_statuses,battle.active())
    _refresh_statuses(enemy_statuses,foe)
    var action := battle.intent()
    var names := {"charge":"강공격","attack":"공격","block":"방어","boost":"강화"}
    var intent_icon := {"charge":"attack","attack":"attack","block":"shield","boost":"boost"}
    var cancelled: bool = battle.opening()["cancel"]
    get_node("Intent/Icon").texture = W.texture("break" if cancelled else intent_icon[action["kind"]])
    get_node("Intent/Title").text = "행동 취소" if cancelled else names[action["kind"]]
    intent_label.text = "—" if cancelled else str(action["value"])
    get_node("Intent").tooltip_text = "브레이크로 다음 행동을 취소합니다." if cancelled else "다음 적 행동: %s %d\n상성과 적 강화가 적용된 수치입니다." % [names[action["kind"]],action["value"]]
    var state := battle.opening()
    for i in break_pips.size():
        break_pips[i].add_theme_stylebox_override("panel",W.box(GOLD if i < state["points"] else Color("34484e"),Color.TRANSPARENT,3))
    opening_label.text = "브레이크" if state["broken"] else "빈틈"
    get_node("Break/Burst").text = "×2" if state["burst"] else ""
    get_node("Break").tooltip_text = "빈틈 %d / 3 · %s\n약점 / 상태 / 분석 / 견제는 적마다 각각 한 번씩 빈틈을 만듭니다." % [state["points"],"다음 공격 ×2" if state["burst"] else ("브레이크 사용 완료" if state["broken"] else "서로 다른 전술로 채우세요.")]
    energy_label.text = str(battle.energy)
    get_node("Energy").tooltip_text = "에너지 %d · 턴 시작 시 3\n브레이크·격파 에너지 환급 %d / %d회" % [battle.energy,battle.refunds,TacticalBattle.REFUND_LIMIT]
    draw_count.text = str(battle.draw_pile.size())
    discard_count.text = str(battle.discard.size())
    end_button.disabled = busy or battle.phase != TacticalBattle.PLAYER
    end_button.get_node("Title").text = "교체 선택" if battle.phase == TacticalBattle.REPLACE else "턴 종료"
    end_button.get_node("Title").add_theme_color_override("font_color",W.MUTED if end_button.disabled else Color("10232b"))
    end_button.get_child(1).modulate.a = 0.35 if end_button.disabled else 1.0
    switch_label.text = "무료 교체" if not battle.switched or battle.phase == TacticalBattle.REPLACE else "교체 1 에너지"
    for i in party_buttons.size():
        var pokemon := battle.party[i]
        var button := party_buttons[i]
        party_names[i].text = pokemon.display_name
        party_values[i].text = "기절" if not pokemon.alive() else "%d / %d" % [pokemon.hp,pokemon.max_hp]
        W.fill_bar(party_bars[i],pokemon.hp,pokemon.max_hp)
        button.disabled = busy or not battle.switch_reason(pokemon.uid).is_empty()
        button.tooltip_text = "%s · %s\n%s" % [pokemon.display_name,catalog.type_name(pokemon.type),"출전 중" if pokemon == battle.active() else (battle.switch_reason(pokemon.uid) if not battle.switch_reason(pokemon.uid).is_empty() else switch_label.text)]
        var border := MINT if pokemon == battle.active() else Color("3d555a")
        button.add_theme_stylebox_override("disabled",W.box(Color("203a3d") if pokemon == battle.active() else Color("17262e"),border))
        button.get_child(0).modulate.a = 0.25 if not pokemon.alive() else 1.0
    var support := {"seed":"씨앗 3회 · 회당 2 흡수","growth":"공격력 +2","fire_guard":"보호막 +8","shell":"보호막 +8"}
    for i in skills.size():
        var key: String = TacticalContent.SKILLS[battle.active().species_id][i]
        var view := battle.skill_view(key)
        var reason := battle.skill_reason(key)
        skill_names[i].text = view["name"]
        skill_values[i].text = "피해 %d%s" % [view["preview_damage"]," · 화상" if view.has("burn") else ""] if view.has("preview_damage") else support[key]
        skill_values[i].add_theme_color_override("font_color",GOLD if state["burst"] and view.has("damage") else W.MUTED)
        skill_icons[i].texture = W.texture("shield" if view.has("block") else ("seed" if key == "seed" else ("boost" if key == "growth" else view["type"])))
        if battle.used_skills.has("%d:%s" % [battle.active().uid,key]):
            skill_icons[i].texture = W.texture("check")
            skill_values[i].text = "다음 턴에 사용"
        skill_costs[i].text = str(view["cost"])
        skills[i].tooltip_text = "%s\n%s\n%s" % [view["name"],view["description"],reason if not reason.is_empty() else "이 포켓몬으로 턴 1회 사용"]
        skills[i].disabled = busy or not reason.is_empty()
        W.fade(skills[i])
    _refresh_hand()
    var relic_icons := {"seed_relay":"seed","switch_power":"switch","break_focus":"break"}
    relic_chip.get_node("Icon").texture = W.texture(relic_icons[battle.relic])
    relic_chip.get_node("Title").text = TacticalContent.RELICS[battle.relic]["name"]
    relic_chip.tooltip_text = TacticalContent.RELICS[battle.relic]["description"]+"\n클릭하여 특성 변경"
    for key: String in relic_buttons: relic_buttons[key].get_node("Selected").visible = key == battle.relic
    log_text.text = "\n".join(battle.history)
    result.visible = not busy and battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]
    if result.visible:
        _close_overlays()
        result.move_to_front()
        result_title.text = "승리!" if battle.phase == TacticalBattle.WON else "파티가 쓰러졌습니다"
        result_detail.text = "%d턴  ·  %d마리 격파  ·  브레이크 %d회" % [battle.turn,battle.enemies.filter(func(p: BattlePokemon): return not p.alive()).size(),battle.enemy_states.filter(func(s: Dictionary): return s["broken"]).size()]

func _refresh_statuses(row: Control,pokemon: BattlePokemon) -> void:
    W.clear(row)
    var items: Array = []
    if pokemon.block > 0: items.append(["shield",str(pokemon.block),"보호막 %d · 다음 턴 시작 시 해제" % pokemon.block])
    if pokemon.strength > 0: items.append(["boost",str(pokemon.strength),"공격력 +%d · 이번 전투 동안 유지" % pokemon.strength])
    for key: String in pokemon.statuses:
        var turns: int = pokemon.statuses[key]["turns"]
        items.append(["fire" if key == "burn" else "seed",str(turns),("화상" if key == "burn" else "씨뿌리기")+" · %d회 남음\n행동 종료 시 2 피해%s" % [turns," · 사용자 2 회복" if key == "seed" else ""]])
    if pokemon == battle.active() and battle.next_attack_bonus > 0:
        items.append(["boost","+%d" % battle.next_attack_bonus,"강화 지시 · 다음 공격 기본 피해 +%d" % battle.next_attack_bonus])
    if pokemon == battle.active() and battle.switch_bonus.has(pokemon.uid):
        items.append(["switch","+3","교체 연계 · 다음 공격 기본 피해 +3"])
    if pokemon == battle.enemy() and battle.opening()["analyzed"]: items.append(["analysis","1","분석 · 다음 공격에 빈틈 +1"])
    for i in items.size():
        var chip := W.button(row,Rect2(i*68,0,62,30),func(): pass)
        W.icon(chip,items[i][0],Rect2(7,5,20,20))
        W.label(chip,items[i][1],Rect2(30,0,28,30),14,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
        chip.tooltip_text = items[i][2]

func _refresh_hand() -> void:
    W.clear(hand_row)
    trainer_buttons.clear()
    var summaries := {"analysis":"다음 공격\n빈틈 +1","guard":"보호막 +6","focus":"드로우 2\n소진","rally":"다음 공격\n기본 피해 +4","counter":"강공격: 빈틈 +1\n그 외: 보호막 +4","injury":"효과 없음"}
    var icons := {"analysis":"analysis","guard":"shield","focus":"draw","rally":"boost","counter":"counter","injury":"injury"}
    for card: BattleCardInstance in battle.hand:
        var view := battle.card_view(card)
        var button := W.button(hand_row,Rect2(0,0,174,218),_card.bind(card.uid))
        button.custom_minimum_size = Vector2(174,218)
        W.badge(button,str(view["cost"]),Rect2(12,12,30,30))
        W.label(button,"지시" if card.key != "injury" else "상태",Rect2(93,12,66,28),12,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
        W.label(button,view["name"],Rect2(8,49,158,30),18,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
        W.icon(button,icons[card.key],Rect2(63,92,48,48))
        W.label(button,summaries[card.key],Rect2(8,152,158,54),16,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        var reason := battle.card_reason(card.uid)
        button.tooltip_text = view["name"]+"\n"+view["description"]+("\n"+reason if not reason.is_empty() else "")
        button.disabled = busy or not battle.card_reason(card.uid).is_empty()
        W.fade(button)
        trainer_buttons[card.uid] = button

func _skill(key: String) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.use_skill(key))
func _card(uid: int) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.play_card(uid))
func _switch(uid: int) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.switch_to(uid))
func _end() -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.end_turn())
func _present(reason: String) -> void:
    if not reason.is_empty():
        _notify(reason)
        return
    var move_id := 0
    var from_enemy := false
    _damage_events.assign(battle.events.filter(func(event: Dictionary): return event["kind"] == "damage" and event["amount"] > 0))
    for event: Dictionary in battle.events:
        if event["kind"] in ["skill","card","enemy_action"] and event.has("move_id"):
            move_id = event["move_id"]
            from_enemy = event["kind"] == "enemy_action"
    notice.text = ""
    if battle.events.any(func(e: Dictionary): return e["kind"] in ["chain","break","cancel"]):
        var kinds := battle.events.map(func(event: Dictionary): return event["kind"])
        if "chain" in kinds:
            banner.text = "연쇄 격파!\n"+("에너지 +1 · 카드 +1" if battle.events.any(func(e: Dictionary): return e["kind"] == "refund" and e.get("reason","") == "finish") else "다음 적에게 이어서 공격")
        elif "break" in kinds:
            banner.text = "BREAK!\n다음 공격 ×2"
        elif "cancel" in kinds:
            banner.text = "행동 취소"
        banner.modulate.a = 1.0
        if _banner_tween: _banner_tween.kill()
        _banner_tween = create_tween()
        _banner_tween.tween_interval(1.9)
        _banner_tween.tween_property(banner,"modulate:a",0.0,0.35)
    busy = move_id > 0
    _refresh()
    if busy:
        stage.canvas.effect_from_enemy = from_enemy
        var start := stage.canvas.target_anchor if from_enemy else stage.canvas.source_anchor
        var finish := stage.canvas.source_anchor if from_enemy else stage.canvas.target_anchor
        stage.canvas.effect.play(catalog.move_by_id(move_id),start,finish)
    else:
        _visual_enemy = null
        _show_damage()
func _impact(_move: Dictionary) -> void:
    _show_damage()
    if _shake: _shake.kill()
    _shake = create_tween()
    for delta: Vector2 in [Vector2(7,0),Vector2(-5,2),Vector2(3,-2),Vector2.ZERO]:
        _shake.tween_property(stage.canvas,"position",delta,0.035)
func _show_damage() -> void:
    for i in _damage_events.size():
        var event: Dictionary = _damage_events[i]
        var at := stage.canvas.source_anchor if int(event["target"]) > 0 else stage.canvas.target_anchor
        var big: bool = int(event["amount"]) >= 24
        var number := _label("−%d" % event["amount"],Rect2(at.x-100+i*35,at.y-100,200,90),64 if big else 44,GOLD if big else Color("fff3d4"),HORIZONTAL_ALIGNMENT_CENTER,damage_layer)
        number.add_theme_constant_override("outline_size",8)
        number.add_theme_color_override("font_outline_color",Color("152627"))
        var tween := number.create_tween().set_parallel(true)
        tween.tween_property(number,"position:y",number.position.y-70,0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(number,"modulate:a",0.0,0.45).set_delay(0.25)
        tween.chain().tween_callback(number.queue_free)
    _damage_events.clear()
func _finished(_move: Dictionary = {}) -> void:
    busy = false
    _visual_enemy = null
    _refresh()
func restart(selected_relic: String = "") -> void:
    stage.canvas.clear_effects()
    if _shake: _shake.kill()
    if _banner_tween: _banner_tween.kill()
    stage.canvas.position = Vector2.ZERO
    banner.text = ""
    banner.modulate.a = 0.0
    _damage_events.clear()
    for number: Node in damage_layer.get_children():
        number.queue_free()
    busy = false
    _visual_enemy = null
    _close_overlays()
    battle.restart(battle.seed_value,battle.relic if selected_relic.is_empty() else selected_relic)
    notice.text = ""
    _refresh()
func _old_run() -> void:
    get_tree().change_scene_to_file("res://scenes/battle_preview.tscn")
func _open_lab() -> void:
    get_node("/root/BattleSession").set("return_scene","res://scenes/tactical_battle.tscn")
    get_tree().change_scene_to_file("res://scenes/art_lab.tscn")
func _fullscreen() -> void:
    var mode := DisplayServer.window_get_mode()
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    if event.keycode == KEY_ESCAPE:
        if _overlay_open(): _close_overlays()
        elif not result.visible: _open_overlay(menu_panel)
        get_viewport().set_input_as_handled()
        return
    if _overlay_open(): return
    if result.visible:
        match event.keycode:
            KEY_R: restart()
            KEY_F3: _old_run()
            KEY_F11: _fullscreen()
        return
    match event.keycode:
        KEY_1,KEY_2,KEY_3: _skill(TacticalContent.SKILLS[battle.active().species_id][event.keycode-KEY_1])
        KEY_Q: _switch(battle.party[0].uid)
        KEY_W: _switch(battle.party[1].uid)
        KEY_E: _switch(battle.party[2].uid)
        KEY_ENTER: _end()
        KEY_R: restart()
        KEY_F1: _open_overlay(help_panel)
        KEY_F2: _open_lab()
        KEY_F3: _old_run()
        KEY_F11: _fullscreen()
func _notify(message: String) -> void:
    notice.text = message
    notice.modulate.a = 1
    if _notice_tween: _notice_tween.kill()
    _notice_tween = create_tween()
    _notice_tween.tween_interval(1.6)
    _notice_tween.tween_property(notice,"modulate:a",0.0,0.3)
func _label(value: String,rect: Rect2,font_size: int = 19,color: Color = CREAM,alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,parent: Node = self) -> Label:
    return W.label(parent,value,rect,font_size,color,alignment)
func _shade(rect: Rect2,color: Color) -> void:
    var shade := ColorRect.new()
    shade.position = rect.position
    shade.size = rect.size
    shade.color = color
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
