class_name TacticalUI
extends Control
## Shared battle view. Combat rules resolve before presentation; the journey owns travel.
const W = preload("res://scripts/ui/combat_widgets.gd")
const SKILL_KEYS := [KEY_Q,KEY_W,KEY_E,KEY_R]
const SKILL_LABELS := ["Q","W","E","R"]
const GOLD := Color("edcb80")
const CREAM := Color("eee5cd")
const MINT := Color("b5e1c3")
var battle: TacticalBattle
var run_mode := false
var run_title := ""
var run_biome: Dictionary = {}
signal run_continue_requested
signal run_restart_requested(selected_relic: String)
var result_next: Button
var capture_action: Callable
var capture_status: Callable
var capture_button: Button
var home_button: Button
var run_journey: TacticalJourney
var bag_panel: Control
var bag_button: Button
var catalog := VisualCatalog.new()
var stage := PixelStage.new()
var busy := false
var top_bar: ColorRect
var ally_roster: Panel
var enemy_roster: Panel
var enemy_names: Array[Label] = []
var enemy_values: Array[Label] = []
var enemy_bars: Array[ColorRect] = []
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
var queue_label: Label
var notice: Label
var banner: Label
var damage_layer := Control.new()
var skill_panel: Panel
var skill_title: Label
var card_effects := Control.new()
var _hand_turn := -1
var _shown_active := 0
var _shown_enemy := 0
var _shown_intent := ""
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
    if battle == null: battle = get_node("/root/BattleSession").get("tactics")
    _theme()
    stage.source_ratio = Vector2(0.25,0.425)
    stage.target_ratio = Vector2(0.73,0.42)
    stage.canvas.sprite_zoom = 4
    stage.canvas.show_nameplates = false
    stage.canvas.use_effect_statuses = false
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(stage)
    stage.canvas.background = VisualCatalog.biome_texture(run_biome if not run_biome.is_empty() else catalog.biomes[3])
    stage.canvas.effect.speed = 2.4
    stage.canvas.effect.finished.connect(_finished)
    stage.canvas.effect.impact.connect(_impact)
    _build()
    if run_mode:
        W.panel(self,Rect2(640,88,640,38),Color(0.035,0.075,0.095,0.9),Color.TRANSPARENT,19)
        W.label(self,run_title,Rect2(640,88,640,38),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
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
    # A borderless, opaque rectangle fills every edge; transparent style borders
    # previously exposed the stage along the top and sides of this bar.
    top_bar = ColorRect.new()
    top_bar.color = Color("09151b")
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = 72
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top_bar)
    W.icon(self,run_biome.get("type","grass"),Rect2(42,23,28,28))
    _label(run_biome.get("name","햇살숲"),Rect2(86,16,190,40),21)
    relic_chip = W.button(self,Rect2(274,16,208,40),func(): _open_overlay(menu_panel))
    W.icon(relic_chip,"seed",Rect2(12,8,24,24)).name = "Icon"
    W.label(relic_chip,"",Rect2(48,0,146,40),17,W.MUTED).name = "Title"
    status_label = _label("",Rect2(830,18,260,36),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    history_button = W.icon_button(self,"history",Rect2(1660,14,48,44),func(): _open_overlay(log_panel),"전투 기록")
    help_button = W.icon_button(self,"help",Rect2(1724,14,48,44),func(): _open_overlay(help_panel),"전투 도움말 · F1")
    menu_button = W.icon_button(self,"menu",Rect2(1788,14,84,44),func(): _open_overlay(menu_panel),"메뉴 · Esc")
    _build_combat_hud()
    _build_rosters()
    _build_actions()
    menu_panel = _build_menu()
    help_panel = _build_help()
    _build_log()
    pile_panel = _modal("카드 더미",Rect2(590,180,740,710))
    _build_result()
    card_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card_effects.z_index = 35
    add_child(card_effects)
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
    W.icon(self,"grass",Rect2(567,578,20,20)).name = "AllyType2"
    W.icon(self,"grass",Rect2(591,578,24,24)).name = "AllyType"
    W.icon(self,"grass",Rect2(1489,571,20,20)).name = "EnemyType2"
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

func _roster_row(panel: Panel,index: int,pokemon: BattlePokemon,action: Callable) -> Button:
    var row := W.button(panel,Rect2(12,44+index*66,216,58),action)
    W.sprite(row,pokemon.species_id,Rect2(6,5,48,48))
    return row

func _build_rosters() -> void:
    ally_roster = W.panel(self,Rect2(36,104,240,54+battle.party.size()*66),Color(0.04,0.08,0.10,0.83),Color("344b51"))
    W.label(ally_roster,"내 파티",Rect2(12,9,94,27),16,CREAM)
    switch_label = W.label(ally_roster,"",Rect2(100,9,128,27),12,MINT,HORIZONTAL_ALIGNMENT_RIGHT)
    for i in battle.party.size():
        var row := _roster_row(ally_roster,i,battle.party[i],func(): _switch(battle.party[i].uid))
        party_names.append(W.label(row,"",Rect2(66,4,114,25),16))
        W.label(row,str(i+1),Rect2(187,6,20,22),12,MINT,HORIZONTAL_ALIGNMENT_CENTER)
        party_values.append(W.label(row,"",Rect2(66,27,132,22),12,W.MUTED))
        party_bars.append(W.bar(row,Rect2(66,51,132,3)))
        party_buttons.append(row)
    enemy_roster = W.panel(self,Rect2(1644,104,240,54+battle.enemies.size()*66),Color(0.04,0.08,0.10,0.83),Color("344b51"))
    W.label(enemy_roster,"상대 파티",Rect2(12,9,120,27),16,CREAM)
    queue_label = W.label(enemy_roster,"",Rect2(144,9,82,27),13,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    for i in battle.enemies.size():
        var row := _roster_row(enemy_roster,i,battle.enemies[i],func(): pass)
        row.mouse_default_cursor_shape = Control.CURSOR_ARROW
        enemy_names.append(W.label(row,"",Rect2(66,4,114,25),16))
        W.icon(row,"next",Rect2(188,9,16,16)).name = "Active"
        enemy_values.append(W.label(row,"",Rect2(66,27,132,22),12,W.MUTED))
        enemy_bars.append(W.bar(row,Rect2(66,51,132,3)))
        enemy_slots.append(row)

func _build_actions() -> void:
    # Pokemon skills sit beside the actor; only trainer cards occupy the hand table.
    for i in 7:
        _shade(Rect2(0,736+i*8,1920,8),Color(0.025,0.06,0.075,0.12+i*0.12))
    _shade(Rect2(0,792,1920,288),Color(0.025,0.06,0.075,0.98))
    W.panel(self,Rect2(48,878,112,112),Color("2d3d3c"),Color("aa975f"),56)
    W.icon(self,"energy",Rect2(88,889,32,32))
    energy_label = _label("",Rect2(49,924,110,53),38,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var energy_tip := W.button(self,Rect2(48,878,112,112),func(): pass)
    energy_tip.flat = true
    energy_tip.name = "Energy"
    # A transparent hit surface gives the energy orb its complete tooltip.
    for state: String in ["normal","hover","pressed","focus"]:
        energy_tip.add_theme_stylebox_override(state,W.box(Color.TRANSPARENT,Color.TRANSPARENT,56))
    _label("에너지",Rect2(48,839,112,30),15,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    hand_scroll.position = Vector2(426,746)
    hand_scroll.size = Vector2(1074,328)
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(hand_scroll)
    hand_row.add_theme_constant_override("separation",12)
    hand_scroll.add_child(hand_row)
    draw_button = _pile_button("draw",Rect2(184,864,204,62),"뽑을 더미",func(): _show_pile("draw"))
    draw_count = draw_button.get_node("Count")
    discard_button = _pile_button("discard",Rect2(184,936,204,62),"버린 더미",func(): _show_pile("discard"))
    discard_count = discard_button.get_node("Count")
    end_button = W.button(self,Rect2(1640,900,232,76),_end)
    if run_mode:
        capture_button = W.button(self,Rect2(1640,790,232,78),_capture)
        W.icon(capture_button,"ball",Rect2(18,23,32,32))
        W.label(capture_button,"",Rect2(60,0,154,78),21).name = "Title"
    end_button.add_theme_stylebox_override("normal",W.box(Color("a7915d"),Color("e6c97f")))
    end_button.add_theme_stylebox_override("hover",W.box(Color("c2a86a"),GOLD))
    W.label(end_button,"턴 종료",Rect2(12,0,173,76),23,Color("10232b"),HORIZONTAL_ALIGNMENT_CENTER).name = "Title"
    W.icon(end_button,"next",Rect2(187,26,24,24))
    W.label(self,"ENTER",Rect2(1640,989,232,25),13,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _pile_button(key: String,rect: Rect2,title: String,action: Callable) -> Button:
    var button := W.button(self,rect,action)
    W.icon(button,key,Rect2(12,19,24,24))
    W.label(button,"",Rect2(146,10,44,42),23,CREAM,HORIZONTAL_ALIGNMENT_CENTER).name = "Count"
    W.label(button,"남은 카드" if key == "draw" else "버린 카드",Rect2(44,2,102,58),14,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    button.tooltip_text = title+" · 클릭하여 확인"
    return button

func _modal(title: String,rect: Rect2) -> Control:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 80
    add_child(overlay)
    var dismiss := W.button(overlay,Rect2(0,0,1920,1080),func(): UiMotion.close(overlay))
    for state: String in ["normal","hover","pressed","focus","disabled"]:
        dismiss.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.65),Color.TRANSPARENT,0))
    var body := W.panel(overlay,rect,Color("142831"),Color("536b6e"),12)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,title,Rect2(32,22,rect.size.x-112,46),27)
    var close := W.icon_button(body,"close",Rect2(rect.size.x-76,22,44,44),func(): UiMotion.close(overlay),"닫기 · Esc")
    close.name = "Close"
    overlay.hide()
    return overlay

func _build_menu() -> Control:
    var overlay := _modal("메뉴",Rect2(1250,96,622,900))
    var body: Panel = overlay.get_node("Body")
    _label("파티 유물",Rect2(32,94,470,32),17,W.MUTED,HORIZONTAL_ALIGNMENT_LEFT,body)
    for index in battle.relics.size():
        var key := battle.relics[index]
        var definition: Dictionary = TacticalContent.RELICS[key]
        W.icon(body,definition["icon"],Rect2(36,139+index*36,24,24))
        var label := W.label(body,definition["name"],Rect2(76,132+index*36,480,36),17)
        label.tooltip_text = definition["description"]
    restart_button = _menu_action(body,"restart","다시 시작","",420,restart)
    if run_mode:
        home_button = _menu_action(body,"home","시작 화면","",492,_home)
        bag_button = _menu_action(body,"heal","가방","",564,_show_bag)
    else:
        old_button = _menu_action(body,"route","기존 원정","F3",492,_old_run)
        lab_button = _menu_action(body,"lab","아트 랩","F2",564,_open_lab)
    _menu_action(body,"normal","화면 전환","F11",636,_fullscreen)
    _menu_action(body,"exhaust","소진된 카드","",708,func(): _show_pile("exhausted"))
    if not run_mode: _menu_action(body,"route","전술 원정","F4",780,_toggle_journey)
    _label("1 / 2 / 3 교대 · Q / W / E / R 손패 1~4장",Rect2(32,848,558,32),16,W.MUTED,HORIZONTAL_ALIGNMENT_LEFT,body)
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
        ["draw","하나의 공유 덱","기술 · 도구 · 트레이너 카드를 뽑습니다.\n턴마다 에너지 3 · 카드 5장\n남은 카드는 턴 종료 시 버립니다."],
        ["switch","기술 사용 → 자동 교대","다른 동료의 기술을 쓰면 즉시 교대.\n자동 교대에는 추가 비용이 없습니다.\n마지막 출전 동료가 공격을 받습니다."],
        ["boost","카드와 유물의 조합","지속 카드는 사용한 전투 동안 유지.\n유물은 파티 전체에 적용됩니다.\n소진 카드는 다음 전투에 돌아옵니다."],
    ]
    for i in steps.size():
        var x := 36+i*340
        W.icon(body,steps[i][0],Rect2(x,118,48,48))
        W.label(body,steps[i][1],Rect2(x,186,316,40),22,GOLD)
        W.label(body,steps[i][2],Rect2(x,247,320,125),16,CREAM)
    W.panel(body,Rect2(36,420,1008,164),Color("203940"),Color.TRANSPARENT)
    W.icon(body,"switch",Rect2(60,446,32,32))
    W.label(body,"기술 카드 자동 교대 무료 · 직접 교대는 에너지 1",Rect2(112,437,860,44),21)
    W.label(body,"공격 순서와 마지막 출전 포켓몬을 함께 생각하세요.\n포켓몬별 보호막과 강화 · 도구 카드 · 유물로 전술을 만드세요.",Rect2(60,495,940,70),19,W.MUTED)
    W.label(body,"교체 1 / 2 / 3     기술 Q / W / E / R     턴 종료 Enter",Rect2(36,609,1008,32),18,MINT)
    W.label(body,"아이콘과 카드에 마우스를 올리면 자세한 효과를 확인할 수 있습니다.",Rect2(36,654,1008,32),17,W.MUTED)
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
    for i in battle.party.size(): W.sprite(body,battle.party[i].species_id,Rect2(380-battle.party.size()*52+i*104,165,96,96))
    result_detail = W.label(body,"",Rect2(36,290,688,50),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    result_restart = W.button(body,Rect2(200,395,360,68),restart,"원정 다시 하기" if run_mode else "다시 하기")
    result_next = W.button(body,Rect2(200,483,360,56),func():
        if run_mode: run_continue_requested.emit()
        else: _old_run(),"계속 진행" if run_mode else "짧은 원정으로")

func _open_overlay(overlay: Control) -> void:
    if result.visible: return
    _close_overlays(true)
    overlay.move_to_front()
    UiMotion.open(overlay)
func _close_overlays(immediate := false) -> void:
    for overlay: Control in [menu_panel,help_panel,log_panel,pile_panel,bag_panel]:
        if overlay != null: UiMotion.close(overlay,immediate)
func _overlay_open() -> bool:
    return menu_panel.visible or help_panel.visible or log_panel.visible or pile_panel.visible or (bag_panel != null and bag_panel.visible)
func _show_bag() -> void:
    if busy or run_journey == null: return
    if bag_panel == null: bag_panel = _modal("가방 · 회복 아이템은 야영지에서 사용",Rect2(410,200,1100,650))
    var body: Panel = bag_panel.get_node("Body")
    if body.has_node("Items"):
        var previous := body.get_node("Items")
        body.remove_child(previous)
        previous.queue_free()
    var content := Control.new()
    content.name = "Items"
    body.add_child(content)
    var row := 0
    for key: String in TacticalJourneyContent.ITEMS:
        W.label(content,"%s ×%d" % [TacticalJourneyContent.ITEMS[key]["name"],run_journey.inventory[key]],Rect2(36,142+row*145,304,60),21)
        for index in run_journey.party.size():
            var target := run_journey.party[index]
            var button := W.button(content,Rect2(350+index*240,142+row*145,222,76),_bag_item.bind(key,index),target.display_name)
            button.name = "Use_%s_%d" % [key,index]
            button.disabled = not run_journey.item_reason(key,index).is_empty()
            button.tooltip_text = run_journey.item_reason(key,index)
        row += 1
    W.label(content,"몬스터볼 ×%d · 야생 전투에서 C로 포획" % run_journey.balls,Rect2(36,578,990,36),16,W.MUTED)
    _open_overlay(bag_panel)
func _bag_item(key: String,index: int) -> void:
    if busy or run_journey == null: return
    var reason := run_journey.use_item(key,index)
    _present(reason)
    _show_bag()
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
    var views: Dictionary = {}
    for card: BattleCardInstance in pile:
        var view := battle.card_view(card)
        var group := "%s:%d:%s" % [card.key,card.owner_uid,card.upgraded]
        counts[group] = int(counts.get(group,0))+1
        views[group] = view
    for group: String in counts:
        var view: Dictionary = views[group]
        text.text += "%s%s ×%d\n%s\n\n" % [view["name"]," · "+str(view.get("owner_name","")) if view.get("owner_uid",0) != 0 else "",counts[group],view["description"]]
    body.add_child(text)
    _open_overlay(pile_panel)

func _refresh() -> void:
    var foe := _visual_enemy if busy and _visual_enemy != null else battle.enemy()
    stage.canvas.set_species(battle.active().species_id,foe.species_id,catalog,false)
    stage.canvas.ally_statuses.assign(battle.active().statuses.keys())
    stage.canvas.enemy_statuses.assign(foe.statuses.keys())
    UiMotion.text(status_label,"턴 %d" % battle.turn)
    queue_label.text = "%d / %d" % [battle.enemy_index+1,battle.enemies.size()]
    for i in enemy_slots.size():
        var p := battle.enemies[i]
        var slot := enemy_slots[i]
        slot.tooltip_text = "%s · HP %d / %d%s" % [p.display_name,p.hp,p.max_hp," · 기절" if not p.alive() else ""]
        slot.get_child(0).modulate.a = 0.25 if not p.alive() else 1.0
        slot.get_node("Active").visible = i == battle.enemy_index and p.alive()
        enemy_names[i].text = p.display_name
        enemy_names[i].modulate.a = 1.0 if p.alive() else 0.4
        enemy_values[i].text = "%d / %d" % [p.hp,p.max_hp] if p.alive() else ("포획" if battle.enemy_states[i].get("captured",false) else "기절")
        W.fill_bar(enemy_bars[i],p.hp,p.max_hp)
        slot.add_theme_stylebox_override("normal",W.box(Color("20353a") if i == battle.enemy_index else Color("152930"),GOLD if i == battle.enemy_index else Color("30474d")))
    W.fill_bar(ally_bar,battle.active().hp,battle.active().max_hp)
    W.fill_bar(enemy_bar,foe.hp,foe.max_hp)
    ally_label.text = "%s · Lv.%d" % [battle.active().display_name,battle.active().level]
    enemy_label.text = "%s · Lv.%d" % [foe.display_name,foe.level]
    get_node("AllyHP").text = "%d / %d" % [battle.active().hp,battle.active().max_hp]
    get_node("EnemyHP").text = "%d / %d" % [foe.hp,foe.max_hp]
    get_node("AllyType2").visible = battle.full_type_chart and battle.active().types.size() > 1
    if battle.active().types.size() > 1: get_node("AllyType2").texture = W.texture(battle.active().types[1])
    get_node("EnemyType2").visible = battle.full_type_chart and foe.types.size() > 1
    if foe.types.size() > 1: get_node("EnemyType2").texture = W.texture(foe.types[1])
    get_node("AllyType").texture = W.texture(battle.active().type)
    get_node("EnemyType").texture = W.texture(foe.type)
    _refresh_statuses(ally_statuses,battle.active())
    _refresh_statuses(enemy_statuses,foe)
    var action := battle.intent()
    var names := {"charge":"강공격","attack":"공격","block":"방어","boost":"강화"}
    var intent_icon := {"charge":"attack","attack":"attack","block":"shield","boost":"boost"}
    var cancelled: bool = action.get("asleep",false)
    var intent_signature := str([battle.enemy().uid,action,cancelled])
    if _shown_intent != intent_signature:
        UiMotion.pulse(get_node("Intent/Icon"))
        _shown_intent = intent_signature
    get_node("Intent/Icon").texture = W.texture("counter" if cancelled else intent_icon[action["kind"]])
    get_node("Intent/Title").text = "행동 취소" if cancelled else names[action["kind"]]
    intent_label.text = "—" if cancelled else str(action["value"])
    get_node("Intent").tooltip_text = "수면으로 다음 행동을 취소합니다." if cancelled else "다음 적 행동: %s %d\n상성과 적 강화가 적용된 수치입니다." % [names[action["kind"]],action["value"]]
    UiMotion.text(energy_label,str(battle.energy))
    get_node("Energy").tooltip_text = "에너지 %d · 턴 시작 시 3\n기술·도구·트레이너 카드가 공유합니다. 기술 자동 교대는 무료입니다." % battle.energy
    UiMotion.text(draw_count,str(battle.draw_pile.size()))
    UiMotion.text(discard_count,str(battle.discard.size()))
    end_button.disabled = busy or battle.phase != TacticalBattle.PLAYER
    end_button.get_node("Title").text = "교체 선택" if battle.phase == TacticalBattle.REPLACE else "턴 종료"
    end_button.get_node("Title").add_theme_color_override("font_color",W.MUTED if end_button.disabled else Color("10232b"))
    end_button.get_child(1).modulate.a = 0.35 if end_button.disabled else 1.0
    switch_label.text = "교대 선택" if battle.phase == TacticalBattle.REPLACE else "직접 교대 1"
    for i in party_buttons.size():
        var pokemon := battle.party[i]
        var button := party_buttons[i]
        party_names[i].text = "%s · %d" % [pokemon.display_name,pokemon.level]
        party_values[i].text = "기절" if not pokemon.alive() else "%d / %d" % [pokemon.hp,pokemon.max_hp]
        W.fill_bar(party_bars[i],pokemon.hp,pokemon.max_hp)
        button.disabled = busy or not battle.switch_reason(pokemon.uid).is_empty()
        button.tooltip_text = "%d · %s · Lv.%d · %s\n%s · 성장 공격 +%d\n%s" % [i+1,pokemon.display_name,pokemon.level,catalog.type_name(pokemon.type),TacticalGrowth.progress_text(pokemon),TacticalGrowth.attack_bonus(pokemon),"출전 중" if pokemon == battle.active() else (battle.switch_reason(pokemon.uid) if not battle.switch_reason(pokemon.uid).is_empty() else switch_label.text)]
        if not pokemon.held_item.is_empty(): button.tooltip_text += "\n"+str(TacticalContent.HELD_ITEMS[pokemon.held_item]["name"])+" · "+str(TacticalContent.HELD_ITEMS[pokemon.held_item]["description"])
        var border := MINT if pokemon == battle.active() else Color("3d555a")
        button.add_theme_stylebox_override("disabled",W.box(Color("203a3d") if pokemon == battle.active() else Color("17262e"),border))
        button.get_child(0).modulate.a = 0.25 if not pokemon.alive() else 1.0
    if _shown_active != battle.active().uid:
        UiMotion.appear(stage.canvas.source_sprite)
        UiMotion.appear(party_buttons[battle.active_index].get_child(0))
        _shown_active = battle.active().uid
    if _shown_enemy != foe.uid:
        UiMotion.appear(stage.canvas.target_sprite)
        _shown_enemy = foe.uid
    _refresh_hand()
    relic_chip.get_node("Icon").texture = W.texture("badge")
    relic_chip.get_node("Title").text = "파티 유물 · %d" % battle.relics.size()
    var descriptions: Array[String] = []
    for key: String in battle.relics: descriptions.append(str(TacticalContent.RELICS[key]["name"])+" · "+str(TacticalContent.RELICS[key]["description"]))
    for key: String in battle.powers: descriptions.append("지속 작전 · %s ×%d" % [{"relay":"릴레이","ace":"에이스","supply":"보급"}[key],battle.powers[key]])
    relic_chip.tooltip_text = "\n".join(descriptions)
    log_text.text = "\n".join(battle.history)
    if run_mode and capture_status.is_valid():
        var capture_state: Dictionary = capture_status.call()
        capture_button.visible = capture_state["wild"]
        capture_button.disabled = busy or not str(capture_state["reason"]).is_empty()
        capture_button.get_node("Title").text = "포획 · %d" % capture_state["balls"]
        capture_button.tooltip_text = "C · 몬스터볼 1개와 에너지 1\n"+(str(capture_state["reason"]) if not str(capture_state["reason"]).is_empty() else "체력 25% 이하 · 포획 시 스타팅 해금")
    var show_result := not busy and battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]
    if show_result:
        _close_overlays(true)
        if not result.visible:
            result.move_to_front()
            UiMotion.open(result)
        result_title.text = "승리!" if battle.phase == TacticalBattle.WON else "파티가 쓰러졌습니다"
        var captures := battle.enemy_states.filter(func(s: Dictionary): return s.get("captured",false)).size()
        result_detail.text = "%d턴  ·  격파 %d  ·  포획 %d" % [battle.turn,battle.enemies.filter(func(p: BattlePokemon): return not p.alive()).size()-captures,captures]
    else:
        UiMotion.close(result,true)

func _refresh_statuses(row: Control,pokemon: BattlePokemon) -> void:
    var items: Array = []
    if pokemon.block > 0: items.append(["shield",str(pokemon.block),"보호막 %d · 다음 턴 시작 시 해제" % pokemon.block])
    if pokemon.strength != 0: items.append(["boost",str(pokemon.strength),"공격력 %+d · 이번 전투 동안 유지" % pokemon.strength])
    for key: String in pokemon.statuses:
        var turns: int = pokemon.statuses[key]["turns"]
        var titles := {"burn":"화상 · 2 피해","seed":"씨뿌리기 · 2 흡수","poison":"독 · 2 피해","sleep":"수면 · 행동 취소","paralysis":"마비 · 공격 -2","confusion":"혼란 · 공격 -2 / 2 피해","exposed":"방어 약화 · 받는 피해 +2"}
        items.append(["fire" if key == "burn" else ("seed" if key == "seed" else "counter"),str(turns),str(titles.get(key,key))+" · %d회 남음" % turns])
    if pokemon == battle.active() and battle.next_attack_bonus > 0:
        items.append(["boost","+%d" % battle.next_attack_bonus,"강화 지시 · 다음 공격 기본 피해 +%d" % battle.next_attack_bonus])
    if pokemon == battle.active() and battle.switch_bonus.has(pokemon.uid):
        items.append(["switch","+3","교체 연계 · 다음 공격 기본 피해 +3"])

    var signature := str([pokemon.uid,items])
    if row.get_meta("status_signature","") == signature: return
    row.set_meta("status_signature",signature)
    W.clear(row)
    for i in items.size():
        var chip := W.button(row,Rect2(i*68,0,62,30),func(): pass)
        W.icon(chip,items[i][0],Rect2(7,5,20,20))
        W.label(chip,items[i][1],Rect2(30,0,28,30),14,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
        chip.tooltip_text = items[i][2]
        UiMotion.appear(chip,i*0.025)

func _refresh_hand() -> void:
    var new_turn := _hand_turn != battle.turn
    if new_turn:
        W.clear(hand_row)
        trainer_buttons.clear()
        _hand_turn = battle.turn
    var live_ids: Array = battle.hand.map(func(card: BattleCardInstance): return card.uid)
    for uid: int in trainer_buttons.keys():
        if uid not in live_ids:
            var old: TrainerActionCard = trainer_buttons[uid]
            hand_row.remove_child(old)
            old.queue_free()
            trainer_buttons.erase(uid)
    var dealt := 0
    for card: BattleCardInstance in battle.hand:
        if not trainer_buttons.has(card.uid):
            var new_button := TrainerActionCard.new()
            new_button.uid = card.uid
            new_button.key = card.key
            new_button.definition = battle.card_view(card)
            new_button.pressed.connect(_card.bind(card.uid))
            hand_row.add_child(new_button)
            trainer_buttons[card.uid] = new_button
            new_button.call_deferred("deal",dealt*0.035)
            dealt += 1
        var button: TrainerActionCard = trainer_buttons[card.uid]
        button.update_card(battle.card_view(card),battle.card_reason(card.uid),busy)
    if dealt > 0: UiMotion.pulse(draw_button.get_child(0))

func _fly_card(card: TrainerActionCard,used := true,delay := 0.0) -> void:
    var copy := card.copy_face(card_effects)
    copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var exhausted: bool = used and (card.definition.get("exhaust",false) or card.definition.has("power"))
    var middle := Vector2(885,500)
    var destination := middle+Vector2(0,-72) if exhausted else discard_button.get_global_rect().get_center()
    var tween := UiMotion.begin(copy,"flight",true)
    if used:
        tween.tween_property(copy,"position",middle,0.17).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(copy,"scale",Vector2.ONE*0.78,0.17).set_delay(delay)
        tween.chain().tween_interval(0.07)
    tween.chain().tween_property(copy,"position",destination,0.24).set_delay(0.0 if used else delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(copy,"scale",Vector2.ONE*0.12,0.24)
    tween.parallel().tween_property(copy,"modulate:a",0.0,0.24)
    tween.chain().tween_callback(copy.queue_free)

func _skill_slot(index: int) -> void:
    if index >= 0 and index < battle.hand.size(): _card(battle.hand[index].uid)

func _skill(key: String) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.use_skill(key))
func _card(uid: int) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    var reason := battle.play_card(uid)
    if reason.is_empty() and trainer_buttons.has(uid): _fly_card(trainer_buttons[uid])
    _present(reason)
func _switch(uid: int) -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    _present(battle.switch_to(uid))
func _end() -> void:
    if busy: return
    _visual_enemy = battle.enemy()
    if battle.phase == TacticalBattle.PLAYER:
        var index := 0
        for card: TrainerActionCard in trainer_buttons.values():
            _fly_card(card,false,index*0.02)
            index += 1
    _present(battle.end_turn())
func _capture() -> void:
    if busy or not capture_action.is_valid(): return
    _visual_enemy = battle.enemy()
    var response: Dictionary = capture_action.call()
    _present(response["reason"])
    if str(response["reason"]).is_empty(): _notify(response["notice"])
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
    if battle.events.any(func(event: Dictionary): return event["kind"] in ["relic","power","cancel"]):
        var highlights := battle.events.filter(func(event: Dictionary): return event["kind"] in ["relic","power","cancel"])
        banner.text = highlights.back()["text"]
        banner.modulate.a = 1.0
        UiMotion.pulse(banner)
        if _banner_tween: _banner_tween.kill()
        _banner_tween = create_tween()
        _banner_tween.tween_interval(1.2)
        _banner_tween.tween_property(banner,"modulate:a",0.0,0.35)
    busy = move_id > 0
    _refresh()
    if busy:
        stage.canvas.effect_from_enemy = from_enemy
        var start := stage.canvas.target_anchor if from_enemy else stage.canvas.source_anchor
        var finish := stage.canvas.source_anchor if from_enemy else stage.canvas.target_anchor
        stage.canvas.effect.play(catalog.move_by_id(move_id) if not catalog.move_by_id(move_id).is_empty() else TacticalMoves.visual(move_id),start,finish)
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
    if run_mode:
        run_restart_requested.emit(battle.relic if selected_relic.is_empty() else selected_relic)
        return
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
    _close_overlays(true)
    W.clear(card_effects)
    W.clear(hand_row)
    trainer_buttons.clear()
    _hand_turn = -1
    _shown_active = 0
    _shown_enemy = 0
    _shown_intent = ""
    battle.restart(battle.seed_value,battle.relic if selected_relic.is_empty() else selected_relic)
    notice.text = ""
    _refresh()
func _old_run() -> void:
    get_tree().change_scene_to_file("res://scenes/battle_preview.tscn")
func _home() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
func _open_lab() -> void:
    get_node("/root/BattleSession").set("return_scene","res://scenes/tactical_journey.tscn" if run_mode else "res://scenes/tactical_battle.tscn")
    get_tree().change_scene_to_file("res://scenes/art_lab.tscn")
func _toggle_journey() -> void:
    get_tree().change_scene_to_file("res://scenes/tactical_battle.tscn" if run_mode else "res://scenes/tactical_journey.tscn")
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
    if run_mode and event.keycode in [KEY_F2,KEY_F3,KEY_F4]: return
    if result.visible:
        match event.keycode:
            KEY_F3: _old_run()
            KEY_F4: _toggle_journey()
            KEY_F11: _fullscreen()
        return
    if event.keycode in SKILL_KEYS:
        _skill_slot(SKILL_KEYS.find(event.keycode))
        return
    match event.keycode:
        KEY_1,KEY_2,KEY_3:
            var index: int = event.keycode-KEY_1
            if index < battle.party.size(): _switch(battle.party[index].uid)
        KEY_C:
            if run_mode: _capture()
        KEY_ENTER: _end()
        KEY_F1: _open_overlay(help_panel)
        KEY_F2: _open_lab()
        KEY_F3: _old_run()
        KEY_F4: _toggle_journey()
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
