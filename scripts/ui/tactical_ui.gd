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
var run_background: Dictionary = {}
var opponent_trainer: Dictionary = {}
var trainer_intro: TrainerEntrance
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
var speed_label: Label
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
var hand_row := BattleHandLayout.new()
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
var settings_button: Button
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
var motion := CombatMotion.new()
var _visual_frame: Dictionary = {}
var _visual_members: Dictionary = {}
var _sequence: Tween
var _action_before: Dictionary = {}
var shield_badges: Array[Control] = []
var shield_values: Array[Label] = []
var _hud_positions: Array[Dictionary] = []
var playback_kinds: Array[String] = []
var _banner_tween: Tween
var _shake: Tween
var _damage_events: Array[Dictionary] = []
var action_preview := BattleActionPreview.new()
var _preview_uid := 0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if battle == null: battle = get_node("/root/BattleSession").get("tactics")
    var music := get_node("/root/GameMusic")
    music.play_theme("camp" if battle.phase in [TacticalBattle.WON,TacticalBattle.LOST] else music.for_battle(str(opponent_trainer.get("kind","wild"))))
    _theme()
    stage.source_ratio = Vector2(0.25,0.442)
    stage.target_ratio = Vector2(0.73,0.37)
    stage.canvas.sprite_zoom = 4
    stage.canvas.frame_for_hand = true
    stage.canvas.show_nameplates = false
    stage.canvas.use_effect_statuses = false
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(stage)
    stage.canvas.set_backdrop(run_background if not run_background.is_empty() else (run_biome if not run_biome.is_empty() else catalog.biomes[3]))
    stage.canvas.effect.speed = 2.4
    motion.canvas = stage.canvas
    stage.canvas.add_child(motion)
    _build()
    add_child(action_preview)
    action_preview.bind_bars(ally_bar,enemy_bar)
    if run_mode:
        W.panel(self,Rect2(640,88,640,38),Color(0.035,0.075,0.095,0.9),Color.TRANSPARENT,19)
        W.label(self,run_title,Rect2(640,88,640,38),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    _refresh()
    if not opponent_trainer.is_empty() and battle.turn == 1 and battle.enemy_index == 0 and battle.phase == TacticalBattle.PLAYER and int(battle.statistics["counts"]["cards_played"]) == 0 and int(battle.statistics["counts"]["manual_switches"]) == 0 and not battle.get_meta("trainer_intro_seen",false):
        battle.set_meta("trainer_intro_seen",true)
        _start_trainer_intro()

func _start_trainer_intro() -> void:
    busy = true
    _refresh()
    stage.canvas.target_factor = 0
    trainer_intro = TrainerEntrance.new()
    trainer_intro.canvas = stage.canvas
    trainer_intro.role = opponent_trainer["kind"]
    trainer_intro.accent = VisualCatalog.type_color(opponent_trainer["type"])
    stage.canvas.add_child(trainer_intro)
    get_node("Intent").hide()
    _announce(str(opponent_trainer["name"])+"의 도전!")
    playback_kinds.assign(["trainer_enter"])
    _sequence = UiMotion.combat(self,"battle_sequence")
    _sequence.tween_property(trainer_intro,"slide",0.0,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _sequence.tween_interval(0.28)
    _sequence.tween_callback(func():
        trainer_intro.pose = "windup"
        playback_kinds.append("trainer_windup"))
    _sequence.tween_interval(0.16)
    _sequence.tween_callback(func():
        trainer_intro.pose = "throw"
        trainer_intro.projectile = true
        playback_kinds.append("trainer_throw"))
    _sequence.tween_property(trainer_intro,"throw_progress",1.0,0.40)
    _sequence.tween_callback(func():
        trainer_intro.projectile = false
        motion.release(false,true)
        playback_kinds.append("trainer_release")
        _announce(battle.enemy().display_name+" 출전!"))
    _sequence.tween_interval(0.42)
    _sequence.tween_property(trainer_intro,"modulate:a",0.0,0.20)
    _sequence.parallel().tween_property(trainer_intro,"slide",80.0,0.20)
    _sequence.tween_callback(func():
        trainer_intro.hide()
        stage.canvas.target_factor = 1
        _finished())

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
    var place_name: String = run_biome.get("name","햇살숲")
    var place_size := 21
    if run_journey != null and run_journey.current()["kind"] == "elite":
        place_name = catalog.type_name(run_biome["type"])+" 배틀 룸"
        place_size = 18
    elif run_journey != null and run_journey.current()["kind"] == "champion":
        place_name = str(run_journey.current()["trainer"]["region"])+" 챔피언 룸"
        place_size = 18
    _label(place_name,Rect2(86,16,190,40),place_size).name = "StageTitle"
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
    pile_panel = _modal("카드 더미",Rect2(260,90,1400,900))
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
    var first_child := get_child_count()
    for at: Vector2 in [Vector2(315,589),Vector2(1237,558)]:
        W.panel(self,Rect2(at,Vector2(330,90)),Color(0.04,0.085,0.10,0.93),Color("3f5653"))
    ally_label = _label("",Rect2(335,597,210,32),21)
    enemy_label = _label("",Rect2(1257,566,210,32),21)
    W.icon(self,"heal",Rect2(335,633,22,22))
    W.icon(self,"heal",Rect2(1257,602,22,22))
    ally_bar = W.bar(self,Rect2(335,662,290,7))
    enemy_bar = W.bar(self,Rect2(1257,631,290,7))
    # The HP values stay separate from names and status icons.
    _label("",Rect2(380,629,245,28),17,CREAM,HORIZONTAL_ALIGNMENT_RIGHT).name = "AllyHP"
    _label("",Rect2(1302,598,245,28),17,CREAM,HORIZONTAL_ALIGNMENT_RIGHT).name = "EnemyHP"
    W.icon(self,"grass",Rect2(567,602,20,20)).name = "AllyType2"
    W.icon(self,"grass",Rect2(591,602,24,24)).name = "AllyType"
    W.icon(self,"grass",Rect2(1489,571,20,20)).name = "EnemyType2"
    W.icon(self,"grass",Rect2(1513,571,24,24)).name = "EnemyType"
    for at: Vector2 in [Vector2(335,682),Vector2(1257,651)]:
        var badge := W.panel(self,Rect2(at,Vector2(290,42)),Color("193d58"),Color("7ac8f0"),7)
        W.icon(badge,"shield",Rect2(12,7,28,28))
        shield_values.append(W.label(badge,"",Rect2(52,0,222,42),22,Color("c5eeff")))
        badge.mouse_filter = Control.MOUSE_FILTER_PASS
        badge.tooltip_text = "보호막이 먼저 피해를 흡수합니다. "+("다음 플레이어 턴 시작 시 사라집니다." if shield_badges.is_empty() else "다음 적 행동 직전에 사라집니다.")
        shield_badges.append(badge)
    ally_statuses.position = Vector2(335,730)
    ally_statuses.size = Vector2(400,32)
    ally_statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ally_statuses)
    enemy_statuses.position = Vector2(1257,699)
    enemy_statuses.size = Vector2(400,32)
    enemy_statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(enemy_statuses)
    # Preserve root node names used by refresh/input while grouping their layout.
    for i in range(first_child,get_child_count()):
        var widget := get_child(i) as Control
        var ally := widget.position.x < 960
        var base := Vector2(315,589) if ally else Vector2(1237,558)
        _hud_positions.append({"node":widget,"ally":ally,"offset":widget.position-base})
    # A compact attack badge sits above the enemy, like intent in deck-building games.
    var intent_box := W.button(self,Rect2(1338,269,128,88),func(): pass)
    intent_box.name = "Intent"
    W.icon(intent_box,"attack",Rect2(16,15,32,32)).name = "Icon"
    intent_label = W.label(intent_box,"",Rect2(54,7,60,48),29,Color("f1b69b"),HORIZONTAL_ALIGNMENT_CENTER)
    W.label(intent_box,"",Rect2(0,53,128,27),14,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER).name = "Title"
    var tactic_title := W.label(intent_box,"",Rect2(0,-32,128,28),14,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    tactic_title.name = "Tactic"
    tactic_title.add_theme_stylebox_override("normal",W.box(Color(0.035,0.075,0.095,0.96),Color("405960"),7))

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
    # One overlapping hand for technique, tool and trainer cards.
    for i in 7:
        _shade(Rect2(0,736+i*8,1920,8),Color(0.025,0.06,0.075,0.12+i*0.12))
    _shade(Rect2(0,792,1920,288),Color(0.025,0.06,0.075,0.98))
    W.panel(self,Rect2(48,878,112,112),Color("2d3d3c"),Color("aa975f"),56)
    W.icon(self,"energy",Rect2(88,889,32,32))
    energy_label = _label("",Rect2(49,924,110,53),38,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    speed_label = _label("",Rect2(28,996,152,30),16,MINT,HORIZONTAL_ALIGNMENT_CENTER)
    var energy_tip := W.button(self,Rect2(48,878,112,112),func(): pass)
    energy_tip.flat = true
    energy_tip.name = "Energy"
    # A transparent hit surface gives the energy orb its complete tooltip.
    for state: String in ["normal","hover","pressed","focus"]:
        energy_tip.add_theme_stylebox_override(state,W.box(Color.TRANSPARENT,Color.TRANSPARENT,56))
    _label("에너지",Rect2(48,839,112,30),15,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    hand_scroll.position = Vector2(426,714)
    hand_scroll.size = Vector2(1172,360)
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hand_scroll.clip_contents = false
    add_child(hand_scroll)
    hand_row.custom_minimum_size = hand_scroll.size
    hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    var relic_scroll := ScrollContainer.new()
    relic_scroll.name = "RelicScroll"
    relic_scroll.position = Vector2(32,132)
    relic_scroll.size = Vector2(558,264)
    relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(relic_scroll)
    var relic_list := VBoxContainer.new()
    relic_list.custom_minimum_size.x = 530
    relic_list.add_theme_constant_override("separation",2)
    relic_scroll.add_child(relic_list)
    var ordered := battle.relics.duplicate()
    var core := CoreRelics.selected(ordered)
    if not core.is_empty():
        ordered.erase(core)
        ordered.push_front(core)
    for key: String in ordered:
        var definition: Dictionary = TacticalContent.RELICS[key]
        var row := Control.new()
        row.custom_minimum_size = Vector2(530,36)
        relic_list.add_child(row)
        W.icon(row,definition["icon"],Rect2(4,6,24,24))
        var label := W.label(row,("핵심 · " if key in CoreRelics.KEYS else "")+str(definition["name"]),Rect2(44,0,480,36),17,W.GOLD if key in CoreRelics.KEYS else W.TEXT)
        label.mouse_filter = Control.MOUSE_FILTER_PASS
        label.tooltip_text = definition["description"]
    restart_button = _menu_action(body,"restart","다시 시작","",420,restart)
    if run_mode:
        home_button = _menu_action(body,"home","시작 화면","",492,_home)
        bag_button = _menu_action(body,"heal","가방","",564,_show_bag)
    else:
        old_button = _menu_action(body,"route","기존 원정","F3",492,_old_run)
        lab_button = _menu_action(body,"lab","아트 랩","F2",564,_open_lab)
    settings_button = _menu_action(body,"settings","설정","",636,_settings)
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
        ["draw","하나의 공유 덱","기술 · 도구 · 트레이너 카드를 뽑습니다.\n턴마다 기본 에너지 3 · 카드 5장\n턴 시작 시 더 빠르면 에너지 +1."],
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
    W.label(body,"기술 카드 자동 교대 무료 · 직접 교대는 에너지 %d" % battle.manual_switch_cost(),Rect2(112,437,860,44),21)
    CardEffectText.status_legend(body,Rect2(60,495,940,78))
    W.label(body,"교체 1 / 2 / 3     손패 Q / W / E / R     턴 종료 Enter",Rect2(36,609,1008,32),18,MINT)
    CardEffectText.legend(body,Rect2(36,648,1008,42))
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
    if result.visible or busy: return
    _clear_action_preview()
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
    if busy: return
    var titles := {"draw":"남은 카드","discard":"버린 카드","exhausted":"소진된 카드"}
    var pile: Array = {"draw":battle.draw_pile,"discard":battle.discard,"exhausted":battle.exhausted}[key].duplicate()
    var body: Panel = pile_panel.get_node("Body")
    if body.has_node("Cards"): body.get_node("Cards").free()
    var content := Control.new()
    content.name = "Cards"
    body.add_child(content)
    W.label(content,"%s · %d장" % [titles[key],pile.size()],Rect2(32,80,1280,34),20,GOLD)
    if pile.is_empty(): W.label(content,"카드가 없습니다.",Rect2(32,280,1336,100),26,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(30,120)
    scroll.size = Vector2(1340,738)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation",16)
    grid.add_theme_constant_override("v_separation",8)
    scroll.add_child(grid)
    # Sort a copy; browsing never exposes or changes the hidden draw order.
    pile.sort_custom(func(a: BattleCardInstance,b: BattleCardInstance): return ("%s:%04d:%s" % [a.key,a.owner_uid,a.upgraded]) < ("%s:%04d:%s" % [b.key,b.owner_uid,b.upgraded]))
    var views: Array[Dictionary] = []
    for instance: BattleCardInstance in pile:
        var view := TacticalContent.definition(instance)
        var owner := battle.member(instance.owner_uid)
        view["owner_name"] = owner.display_name if owner != null else ""
        view["species_id"] = owner.species_id if owner != null else 0
        views.append(view)
    for stack: Dictionary in CardStacks.group(views):
        var view: Dictionary = stack["view"]
        var card := CardStackView.new()
        card.name = "PileCard_%d" % view["uid"]
        card.uid = view["uid"]
        card.key = view["key"]
        card.definition = view
        card.stack_count = stack["count"]
        grid.add_child(card)
    _open_overlay(pile_panel)

func _position_intent() -> void:
    var canvas := stage.canvas
    var texture := canvas.target_sprite.texture
    if texture == null: return
    var bounds := canvas.sprite_bounds(texture)
    var foot := canvas.foot_anchor(false)
    var zoom := canvas.zoom_for(false)
    var top := foot.y-bounds.size.y*zoom
    var badge := get_node("Intent") as Control
    if top-104 >= 124:
        badge.position = Vector2(foot.x-64,minf(269,top-104)).round()
    else:
        # Tall sprites (e.g. Charizard) need a side badge, clear of their face.
        badge.position = Vector2(foot.x-bounds.size.x*zoom/2-152,maxf(164,top+28)).round()

func _position_combat_hud() -> void:
    for item: Dictionary in _hud_positions:
        var foot := stage.canvas.foot_anchor(item["ally"])
        var left := clampf(foot.x-165,32,1300)
        item["node"].position = (Vector2(left,foot.y+24)+item["offset"]).round()

func _refresh() -> void:
    _clear_action_preview()
    var foe := _view_enemy()
    var ally := _view_active()
    stage.canvas.set_species(ally.species_id,foe.species_id,catalog,false)
    _position_combat_hud()
    _position_intent()
    get_node("Intent").visible = trainer_intro == null or not trainer_intro.visible
    stage.canvas.ally_statuses.assign(ally.statuses.keys())
    stage.canvas.enemy_statuses.assign(foe.statuses.keys())
    UiMotion.text(status_label,"턴 %d" % int(_visual_frame.get("turn",battle.turn)))
    queue_label.text = "%d / %d" % [int(_visual_frame.get("enemy_index",battle.enemy_index))+1,battle.enemies.size()]
    for i in enemy_slots.size():
        var p := _view_member(battle.enemies[i])
        var slot := enemy_slots[i]
        slot.tooltip_text = "%s · Lv.%d · HP %d / %d%s\n%s\n%s" % [p.display_name,p.level,p.hp,p.max_hp," · 기절" if not p.alive() else "",PokemonStats.summary(p),EnemyTactics.description(battle.enemy_definitions[i])]
        slot.get_child(0).modulate.a = 0.25 if not p.alive() else 1.0
        slot.get_node("Active").visible = i == int(_visual_frame.get("enemy_index",battle.enemy_index)) and p.alive()
        enemy_names[i].text = p.display_name
        enemy_names[i].modulate.a = 1.0 if p.alive() else 0.4
        enemy_values[i].text = "%d / %d" % [p.hp,p.max_hp] if p.alive() else ("포획" if battle.enemy_states[i].get("captured",false) else "기절")
        W.fill_bar(enemy_bars[i],p.hp,p.max_hp)
        slot.add_theme_stylebox_override("normal",W.box(Color("20353a") if i == int(_visual_frame.get("enemy_index",battle.enemy_index)) else Color("152930"),GOLD if i == int(_visual_frame.get("enemy_index",battle.enemy_index)) else Color("30474d")))
    W.fill_bar(ally_bar,ally.hp,ally.max_hp)
    W.fill_bar(enemy_bar,foe.hp,foe.max_hp)
    ally_label.text = "%s · Lv.%d" % [ally.display_name,ally.level]
    enemy_label.text = "%s · Lv.%d" % [foe.display_name,foe.level]
    get_node("AllyHP").text = "%d / %d" % [ally.hp,ally.max_hp]
    get_node("EnemyHP").text = "%d / %d" % [foe.hp,foe.max_hp]
    get_node("AllyType2").visible = battle.full_type_chart and ally.types.size() > 1
    if ally.types.size() > 1: get_node("AllyType2").texture = W.texture(ally.types[1])
    get_node("EnemyType2").visible = battle.full_type_chart and foe.types.size() > 1
    if foe.types.size() > 1: get_node("EnemyType2").texture = W.texture(foe.types[1])
    get_node("AllyType").texture = W.texture(ally.type)
    get_node("EnemyType").texture = W.texture(foe.type)
    _refresh_statuses(ally_statuses,ally)
    _refresh_statuses(enemy_statuses,foe)
    var action: Dictionary = _visual_frame.get("intent",battle.intent())
    var names := {"charge":"강공격","attack":"공격","block":"방어","boost":"강화","barrage":"연타","fortify":"방벽","recover":"회복","status":"상태 지시"}
    var intent_icon := {"charge":"attack","attack":"attack","block":"shield","boost":"boost","barrage":"attack","fortify":"shield","recover":"heal","status":"counter"}
    var cancelled: bool = action.get("asleep",false)
    var intent_signature := str([battle.enemy().uid,action,cancelled])
    if _shown_intent != intent_signature:
        UiMotion.pulse(get_node("Intent/Icon"))
        _shown_intent = intent_signature
    get_node("Intent/Icon").texture = W.texture("counter" if cancelled else intent_icon[action["kind"]])
    get_node("Intent/Title").text = "행동 취소" if cancelled else names[action["kind"]]
    intent_label.text = "—" if cancelled else ("+%d%%" % (int(action["value"])*10) if action["kind"] == "boost" else str(action["value"]))
    if not cancelled:
        if action["kind"] == "barrage": intent_label.text = "%d×%d" % [action["per_hit"],action["hits"]]
        elif action["kind"] == "recover": intent_label.text = "+%d" % action["value"]
        elif action["kind"] == "status":
            intent_label.text = "%d회" % action["value"]
            get_node("Intent/Title").text = {"burn":"화상","poison":"독","seed":"씨앗"}[action["status"]]
            get_node("Intent/Icon").texture = W.texture(CardEffectText.STATUS_ICONS[action["status"]])
    intent_label.add_theme_font_size_override("font_size",22 if action["kind"] in ["boost","barrage","status"] else 29)
    get_node("Intent/Tactic").text = EnemyTactics.role_title(action)
    get_node("Intent").tooltip_text = EnemyTactics.intent_text(action)+"\n"+EnemyTactics.description(battle.enemy_definitions[int(_visual_frame.get("enemy_index",battle.enemy_index))])
    if action["kind"] in ["attack","charge","barrage"] and not cancelled:
        get_node("Intent").tooltip_text += "\n현재 보호막으로 %d 흡수 · 남은 피해 %d" % [mini(ally.block,int(action["value"])),maxi(0,int(action["value"])-ally.block)]
    UiMotion.text(energy_label,str(int(_visual_frame.get("energy",battle.energy))))
    var speed_bonus := int(_visual_frame.get("turn_energy_bonus",battle.turn_energy_bonus))
    speed_label.text = "스피드 +1" if speed_bonus == 1 else "기본 에너지 3"
    get_node("Energy").tooltip_text = "에너지 %d · 이번 턴 지급 %d\n턴 시작 스피드: 아군 %d / 상대 %d\n더 빠르면 +1, 동률은 기본 3. 교대 시 재지급하지 않습니다." % [int(_visual_frame.get("energy",battle.energy)),3+speed_bonus,int(_visual_frame.get("turn_speed_actor",battle.turn_speed_actor)),int(_visual_frame.get("turn_speed_enemy",battle.turn_speed_enemy))]
    ally_label.mouse_filter = Control.MOUSE_FILTER_PASS
    enemy_label.mouse_filter = Control.MOUSE_FILTER_PASS
    ally_label.tooltip_text = PokemonStats.summary(ally)
    enemy_label.tooltip_text = PokemonStats.summary(foe)
    UiMotion.text(draw_count,str(_visual_frame.get("draw",battle.draw_pile.size())))
    UiMotion.text(discard_count,str(_visual_frame.get("discard",battle.discard.size())))
    end_button.disabled = busy or battle.phase != TacticalBattle.PLAYER
    end_button.get_node("Title").text = "교체 선택" if battle.phase == TacticalBattle.REPLACE else "턴 종료"
    end_button.get_node("Title").add_theme_color_override("font_color",W.MUTED if end_button.disabled else Color("10232b"))
    end_button.get_child(1).modulate.a = 0.35 if end_button.disabled else 1.0
    switch_label.text = "교대 선택" if battle.phase == TacticalBattle.REPLACE else "직접 교대 1"
    for i in party_buttons.size():
        var pokemon := _view_member(battle.party[i])
        var button := party_buttons[i]
        party_names[i].text = "%s · %d" % [pokemon.display_name,pokemon.level]
        party_values[i].text = "기절" if not pokemon.alive() else "%d / %d" % [pokemon.hp,pokemon.max_hp]
        W.fill_bar(party_bars[i],pokemon.hp,pokemon.max_hp)
        button.disabled = busy or not battle.switch_reason(pokemon.uid).is_empty()
        button.tooltip_text = "%d · %s · Lv.%d · %s\n%s XP\n%s\n%s" % [i+1,pokemon.display_name,pokemon.level,catalog.type_name(pokemon.type),TacticalGrowth.progress_text(pokemon),PokemonStats.summary(pokemon),"출전 중" if pokemon.uid == ally.uid else (battle.switch_reason(pokemon.uid) if not battle.switch_reason(pokemon.uid).is_empty() else switch_label.text)]
        if not pokemon.held_item.is_empty(): button.tooltip_text += "\n"+str(TacticalContent.HELD_ITEMS[pokemon.held_item]["name"])+" · "+str(TacticalContent.HELD_ITEMS[pokemon.held_item]["description"])
        var border := MINT if pokemon.uid == ally.uid else Color("3d555a")
        button.add_theme_stylebox_override("disabled",W.box(Color("203a3d") if pokemon.uid == ally.uid else Color("17262e"),border))
        button.get_child(0).modulate.a = 0.25 if not pokemon.alive() else 1.0
    if not busy and _shown_active != ally.uid:
        UiMotion.appear(stage.canvas.source_sprite)
        UiMotion.appear(party_buttons[battle.active_index].get_child(0))
        _shown_active = ally.uid
    if not busy and _shown_enemy != foe.uid:
        UiMotion.appear(stage.canvas.target_sprite)
        _shown_enemy = foe.uid
    for i in 2:
        var pokemon := ally if i == 0 else foe
        shield_badges[i].visible = pokemon.block > 0
        UiMotion.text(shield_values[i],str(pokemon.block))
    if not busy: _refresh_hand()
    else:
        for card: TrainerActionCard in trainer_buttons.values(): card.disabled = true
    relic_chip.get_node("Icon").texture = W.texture("badge")
    relic_chip.get_node("Title").text = "파티 유물 · %d" % battle.relics.size()
    var descriptions: Array[String] = []
    for key: String in battle.relics: descriptions.append(str(TacticalContent.RELICS[key]["name"])+" · "+str(TacticalContent.RELICS[key]["description"]))
    for key: String in battle.powers: descriptions.append("지속 작전 · %s ×%d" % [{"relay":"릴레이","ace":"에이스","supply":"보급","attrition":"소모전"}[key],battle.powers[key]])
    relic_chip.tooltip_text = "\n".join(descriptions)
    log_text.text = "\n".join(battle.history)
    if run_mode and capture_status.is_valid():
        var capture_state: Dictionary = capture_status.call()
        capture_button.visible = capture_state["wild"]
        capture_button.disabled = busy or not str(capture_state["reason"]).is_empty()
        capture_button.get_node("Title").text = "포획 · %d" % capture_state["balls"]
        if int(capture_state.get("cost",1)) > 1: capture_button.get_node("Title").text += "/%d" % capture_state["cost"]
        capture_button.tooltip_text = "C · "+str(capture_state.get("help","몬스터볼 1개 · 에너지 1 · HP 25% 이하"))+"\n"+str(capture_state["reason"])
    var show_result := not busy and battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]
    if show_result:
        _close_overlays(true)
        if not result.visible:
            result.move_to_front()
            UiMotion.open(result)
        result_title.text = "승리!" if battle.phase == TacticalBattle.WON else "파티가 쓰러졌습니다"
        var captures := battle.enemy_states.filter(func(s: Dictionary): return s.get("captured",false)).size()
        result_detail.text = "%d턴  ·  격파 %d  ·  포획 %d" % [int(_visual_frame.get("turn",battle.turn)),battle.enemies.filter(func(p: BattlePokemon): return not p.alive()).size()-captures,captures]
    else:
        UiMotion.close(result,true)

func _refresh_statuses(row: Control,pokemon: BattlePokemon) -> void:
    var items: Array = []
    if pokemon.strength != 0: items.append(["boost",str(pokemon.strength),"위력 보정 %+d%% · 이번 전투 동안 유지" % (pokemon.strength*10)])
    for stat: String in pokemon.stat_stages:
        if pokemon.stat_stages[stat] != 0: items.append([CardEffectText.STAT_ICONS[stat],"%+d" % pokemon.stat_stages[stat],"%s %+d단계 · 교대 시 해제" % [PokemonStats.TITLES[stat],pokemon.stat_stages[stat]]])
    for key: String in pokemon.statuses:
        var turns: int = pokemon.statuses[key]["turns"]
        var titles := {"burn":"화상 · %d 피해 / 물리 위력 절반" % battle.status_damage(pokemon,"burn"),"seed":"씨뿌리기 · %d 흡수" % battle.status_damage(pokemon,"seed"),"poison":"독 · %d 피해" % battle.status_damage(pokemon,"poison"),"sleep":"수면 · 행동 취소","paralysis":"마비 · 스피드 절반","confusion":"혼란 · %d 피해" % PokemonStats.scale(pokemon,2),"exposed":"방어 약화 · 공격자 체력에 비례한 추가 피해"}
        items.append([CardEffectText.STATUS_ICONS.get("expose" if key == "exposed" else key,"counter"),str(turns),str(titles.get(key,key))+" · %d회 남음" % turns])
    if pokemon.uid == battle.active().uid and battle.next_attack_bonus > 0:
        items.append(["boost","+%d" % battle.next_attack_bonus,"강화 지시 · 다음 공격 추가 피해 +%d (자속·상성 적용 전)" % PokemonStats.scale(pokemon,battle.next_attack_bonus)])
    if pokemon.uid == battle.active().uid and battle.switch_bonus.has(pokemon.uid):
        items.append(["switch","+3","교체 연계 · 다음 공격 추가 피해 +%d (자속·상성 적용 전)" % PokemonStats.scale(pokemon,3)])

    var signature := str([pokemon.uid,items])
    if row.get_meta("status_signature","") == signature: return
    row.set_meta("status_signature",signature)
    W.clear(row)
    for i in items.size():
        var chip := W.button(row,Rect2((i%4)*68,floori(i/4.0)*34,62,30),func(): pass)
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
    var cards: Array[TrainerActionCard] = []
    for card: BattleCardInstance in battle.hand:
        if not trainer_buttons.has(card.uid):
            var new_button := TrainerActionCard.new()
            new_button.uid = card.uid
            new_button.key = card.key
            new_button.definition = battle.card_view(card)
            new_button.pressed.connect(_card.bind(card.uid))
            new_button.hand_hover_changed.connect(_on_action_hover)
            hand_row.add_child(new_button)
            trainer_buttons[card.uid] = new_button
            new_button.call_deferred("deal",dealt*0.035)
            dealt += 1
        var button: TrainerActionCard = trainer_buttons[card.uid]
        button.self_modulate.a = 1
        button.update_card(battle.card_view(card),battle.card_reason(card.uid),busy)
        cards.append(button)
    hand_row.arrange(cards)
    if dealt > 0: UiMotion.pulse(draw_button.get_child(0))

func _clear_action_preview() -> void:
    _preview_uid = 0
    action_preview.clear()

func _on_action_hover(card: TrainerActionCard,value: bool) -> void:
    if not value:
        if _preview_uid == card.uid: _clear_action_preview()
        return
    _clear_action_preview()
    if busy or _overlay_open() or result.visible or not battle.card_reason(card.uid).is_empty(): return
    var capture_check := Callable()
    if run_journey != null and run_journey.is_wild(): capture_check = run_journey.capture_reason
    var forecast := BattleCardPreview.analyze(battle,card.uid,capture_check)
    _preview_uid = card.uid
    action_preview.display(forecast,battle.active().uid)

func _fly_card(card: TrainerActionCard,used := true,delay := 0.0) -> void:
    var copy := card.copy_face(card_effects)
    copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.self_modulate.a = 0
    var exhausted: bool = used and (card.definition.get("exhaust",false) or card.definition.has("power"))
    var middle := Vector2(885,500)
    var destination := middle+Vector2(0,-72) if exhausted else discard_button.get_global_rect().get_center()
    var tween := UiMotion.combat(copy,"flight",true)
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
    _action_before = BattleFrame.capture(battle)
    _present(battle.use_skill(key))
func _card(uid: int) -> void:
    if busy: return
    _action_before = BattleFrame.capture(battle)
    var reason := battle.play_card(uid)
    if reason.is_empty() and trainer_buttons.has(uid): _fly_card(trainer_buttons[uid])
    _present(reason)
func _switch(uid: int) -> void:
    if busy: return
    _action_before = BattleFrame.capture(battle)
    _present(battle.switch_to(uid))
func _end() -> void:
    if busy: return
    _action_before = BattleFrame.capture(battle)
    if battle.phase == TacticalBattle.PLAYER:
        var index := 0
        for card: TrainerActionCard in trainer_buttons.values():
            if card.uid in battle.retained: continue
            _fly_card(card,false,index*0.02)
            index += 1
    _present(battle.end_turn())
func _capture() -> void:
    if busy or not capture_action.is_valid(): return
    _action_before = BattleFrame.capture(battle)
    var response: Dictionary = capture_action.call()
    _present(response["reason"])
    if str(response["reason"]).is_empty(): _notify(response["notice"])
func _view_member(p: BattlePokemon) -> BattlePokemon:
    return _visual_members.get(p.uid,p)
func _view_active() -> BattlePokemon:
    return _view_member(battle.party[int(_visual_frame.get("active_index",battle.active_index))])
func _view_enemy() -> BattlePokemon:
    return _view_member(battle.enemies[int(_visual_frame.get("enemy_index",battle.enemy_index))])
func _apply_frame(frame: Dictionary) -> void:
    _visual_frame = frame.duplicate(true)
    _visual_members.clear()
    for row: Dictionary in frame.get("party",[])+frame.get("enemies",[]): _visual_members[int(row["uid"])] = BattleFrame.restore(row)
    _refresh()
func _present(reason: String) -> void:
    _clear_action_preview()
    if not reason.is_empty():
        _notify(reason)
        return
    busy = true
    playback_kinds.clear()
    _close_overlays(true)
    _apply_frame(_action_before)
    notice.text = ""
    var frames: Array = battle.events.duplicate(true)
    _sequence = UiMotion.combat(self,"battle_sequence")
    for event: Dictionary in frames:
        var kind: String = event["kind"]
        if kind in ["switch","enemy_switch"]:
            var on_ally := kind == "switch"
            _sequence.tween_callback(func():
                playback_kinds.append(kind)
                motion.recall(on_ally)
                _announce(event["text"]))
            _sequence.tween_interval(0.25)
            _sequence.tween_callback(func():
                _apply_frame(event.get("frame",{}))
                motion.release(on_ally))
            _sequence.tween_interval(0.42)
        else:
            _sequence.tween_callback(_play_event.bind(event))
            var duration := 0.40 if kind in ["skill","card","enemy_action","enemy_hit"] else (0.28 if kind in ["damage","shield","heal","knockout","turn"] else 0.22)
            _sequence.tween_interval(duration)
    _sequence.tween_callback(_finished)
func _announce(text: String) -> void:
    banner.text = text
    banner.modulate.a = 1.0
    UiMotion.pulse(banner)
func _play_event(event: Dictionary) -> void:
    BattleSoundCues.play(self,BattleSoundCues.for_event(event))
    var kind: String = event["kind"]
    playback_kinds.append(kind)
    _apply_frame(event.get("frame",{}))
    if kind in ["skill","card","enemy_action","enemy_hit"]:
        _announce(event["text"])
        var from_enemy := kind in ["enemy_action","enemy_hit"]
        var id := int(event.get("move_id",0))
        var definition := catalog.move_by_id(id) if not catalog.move_by_id(id).is_empty() else TacticalMoves.visual(id)
        if not definition.is_empty():
            stage.canvas.effect_from_enemy = from_enemy
            var start := stage.canvas.target_anchor if from_enemy else stage.canvas.source_anchor
            var finish := stage.canvas.source_anchor if from_enemy else stage.canvas.target_anchor
            stage.canvas.effect.speed = 2.4 * UiMotion.combat_speed(self)
            stage.canvas.effect.play(definition,start,finish)
            var is_attack: bool = TacticalMoves.definition(TacticalMoves.key_for(id)).has("damage")
            if from_enemy: is_attack = event.get("action","") in ["attack","charge","barrage"]
            if is_attack: motion.attack(from_enemy,str(definition.get("category")) in ["2","physical"])
    elif kind in ["damage","shield","heal"]:
        var on_ally := int(event["target"]) > 0
        var amount := int(event["amount"])
        if int(event["target"]) not in [_view_active().uid,_view_enemy().uid]:
            for i in battle.party.size():
                if battle.party[i].uid == int(event["target"]): UiMotion.pulse(party_buttons[i])
            return
        if kind == "damage":
            var blocked := int(event.get("blocked",0))
            if amount > 0 or blocked > 0:
                motion.hit(on_ally,amount == 0)
                _float_value("−%d" % amount if amount > 0 else str(blocked),on_ally,Color("fff3d4") if amount > 0 else Color("9edfff"),"attack" if amount > 0 else "shield")
        elif amount > 0:
            _float_value("+%d" % amount,on_ally,Color("9edfff") if kind == "shield" else MINT,"shield" if kind == "shield" else "heal")
            if kind == "shield": UiMotion.pulse(shield_badges[0 if on_ally else 1])
    elif kind == "knockout":
        _announce(event["text"])
        # The frame shows zero HP before the combatant disappears.
        var target := int(event.get("target",0))
        if target == _view_active().uid or target == _view_enemy().uid: motion.faint(target > 0)
    elif kind in ["relic","power","cancel","turn","capture","status","stat","shield_spent"]: _announce(event["text"])
func _float_value(text: String,on_ally: bool,color: Color,icon_key := "") -> void:
    var at := stage.canvas.source_anchor if on_ally else stage.canvas.target_anchor
    var number := CardEffectText.label(damage_layer,Rect2(at.x-170,at.y-120,340,90),42,color)
    number.text = "[center]"+(CardEffectText.icon(icon_key,36)+" " if not icon_key.is_empty() else "")+text+"[/center]"
    number.add_theme_constant_override("outline_size",8)
    number.add_theme_color_override("font_outline_color",Color("152627"))
    var tween := UiMotion.combat(number,"float",true)
    tween.tween_property(number,"position:y",number.position.y-64,0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(number,"modulate:a",0.0,0.35).set_delay(0.35)
    tween.chain().tween_callback(number.queue_free)
func _finished() -> void:
    if battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: get_node("/root/GameMusic").play_theme("camp")
    if battle.phase == TacticalBattle.WON and "capture" not in playback_kinds: BattleSoundCues.play(self,"victory")
    elif battle.phase == TacticalBattle.LOST: BattleSoundCues.play(self,"defeat")
    stage.canvas.effect.stop()
    busy = false
    _visual_frame.clear()
    _visual_members.clear()
    banner.modulate.a = 0
    _refresh()
func finish_presentation() -> void:
    # Deterministically finish the same playback tween in integration probes.
    if _sequence != null and _sequence.is_valid(): _sequence.custom_step(60.0)
    UiMotion.finish_tree(motion)
    UiMotion.finish_tree(stage.canvas)
    stage.canvas.effect.stop()
func restart(selected_relic: String = "") -> void:
    if run_mode:
        run_restart_requested.emit(battle.relic if selected_relic.is_empty() else selected_relic)
        return
    if _sequence != null and _sequence.is_valid(): _sequence.kill()
    stage.canvas.clear_effects()
    motion.reset()
    if _shake: _shake.kill()
    if _banner_tween: _banner_tween.kill()
    stage.canvas.position = Vector2.ZERO
    banner.text = ""
    banner.modulate.a = 0.0
    _damage_events.clear()
    for number: Node in damage_layer.get_children():
        number.queue_free()
    busy = false
    _visual_frame.clear()
    _visual_members.clear()
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
func _settings() -> void:
    if busy: return
    _clear_action_preview()
    get_node("/root/Preferences").show_panel(self)
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
