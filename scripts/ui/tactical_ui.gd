class_name TacticalUI
extends Control
## Trial view. Combat decisions are resolved by TacticalBattle before presentation.
const GOLD := Color("f4cf78")
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
var piles_label: Label
var energy_label: Label
var status_label: Label
var ally_label: Label
var enemy_label: Label
var intent_label: Label
var opening_label: Label
var queue_label: Label
var guide_label: Label
var notice: Label
var banner: Label
var damage_layer := Control.new()
var hand_row := HBoxContainer.new()
var hand_scroll := ScrollContainer.new()
var log_panel := Panel.new()
var log_text := RichTextLabel.new()
var result := Control.new()
var result_title: Label
var result_detail: Label
var result_restart: Button
var _visual_enemy: BattlePokemon
var _banner_tween: Tween
var _shake: Tween
var _damage_events: Array[Dictionary] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle = get_node("/root/BattleSession").get("tactics")
    _theme()
    stage.source_ratio = Vector2(0.255,0.44)
    stage.target_ratio = Vector2(0.735,0.43)
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
    theme.set_color("font_hover_color","Button",Color.WHITE)
    theme.set_color("font_disabled_color","Button",Color("829790"))
    for state: String in ["normal","hover","pressed","disabled","focus"]:
        var box := StyleBoxFlat.new()
        box.bg_color = Color("1b3034") if state in ["normal","disabled"] else Color("34544f")
        if state == "focus": box.bg_color = Color.TRANSPARENT
        box.border_color = GOLD if state in ["hover","focus","pressed"] else Color("627c70")
        box.set_border_width_all(2 if state == "focus" else 1)
        box.set_content_margin_all(12)
        theme.set_stylebox(state,"Button",box)

func _build() -> void:
    _shade(Rect2(0,0,1920,80),Color(0.025,0.06,0.08,0.97))
    _label("관동 원정대  /  전술 시험",Rect2(35,18,440,45),28,GOLD)
    status_label = _label("",Rect2(490,22,350,40),21)
    old_button = _button("기존 원정 · F3",Rect2(1030,18,190,44),_old_run)
    history_button = _button("전투 기록",Rect2(1235,18,150,44),func(): log_panel.visible = not log_panel.visible)
    lab_button = _button("아트 랩 · F2",Rect2(1400,18,180,44),_open_lab)
    restart_button = _button("시험 재시작 · R",Rect2(1595,18,280,44),restart)
    _shade(Rect2(24,105,300,565),Color(0.03,0.08,0.09,0.9))
    _label("시험 특성 선택",Rect2(42,117,264,32),21,GOLD)
    var index := 0
    for key: String in TacticalContent.RELICS:
        var definition: Dictionary = TacticalContent.RELICS[key]
        var button := _button(definition["name"],Rect2(42,162+index*52,264,43),restart.bind(key))
        button.tooltip_text = definition["description"]+"\n선택하면 같은 시드로 시험 전투를 재시작합니다."
        relic_buttons[key] = button
        index += 1
    guide_label = _label("",Rect2(42,327,264,95),17,MINT)
    _label("빈틈 3 → 브레이크\n약점 · 상태 · 분석 · 견제\n서로 다른 방법으로 채우세요.\n\n브레이크: 다음 행동 취소\n다음 공격 ×2 · 에너지 +1\n격파: 에너지 +1 · 드로우 1\n환급은 둘을 합해 턴당 2회",Rect2(42,430,264,155),16)
    _shade(Rect2(1070,96,805,56),Color(0.035,0.08,0.09,0.82))
    queue_label = _label("",Rect2(1080,100,795,48),20,CREAM,HORIZONTAL_ALIGNMENT_RIGHT)
    _shade(Rect2(1260,195,310,112),Color(0.035,0.08,0.09,0.93))
    intent_label = _label("",Rect2(1270,207,290,85),23,Color("ffc9a0"),HORIZONTAL_ALIGNMENT_CENTER)
    _shade(Rect2(335,560,355,129),Color(0.035,0.08,0.09,0.94))
    _shade(Rect2(1225,548,380,174),Color(0.035,0.08,0.09,0.94))
    _shade(Rect2(345,684,790,40),Color(0.035,0.08,0.09,0.94))
    ally_bar = _health_bar(Rect2(345,674,335,8))
    enemy_bar = _health_bar(Rect2(1245,641,335,8))
    ally_label = _label("",Rect2(345,568,330,100),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    enemy_label = _label("",Rect2(1245,553,335,86),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER)
    opening_label = _label("",Rect2(1150,650,525,66),21,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    _shade(Rect2(0,726,1920,354),Color(0.025,0.06,0.075,0.96))
    _label("파티 교체  Q / W / E",Rect2(35,735,295,30),18,MINT)
    for i in 3:
        var button := _button("",Rect2(35,780+i*87,295,76),func(): _switch(battle.party[i].uid))
        party_buttons.append(button)
    _label("고정 기술 · 포켓몬당 각 기술 턴 1회",Rect2(390,736,1080,28),18,MINT)
    for i in 3:
        var button := _button("",Rect2(390+i*347,775,332,103),func(): _skill(TacticalContent.SKILLS[battle.active().species_id][i]))
        skills.append(button)
    _label("트레이너 손패  /  추가 카드는 가로 스크롤",Rect2(390,888,1120,30),17,MINT)
    hand_scroll.position = Vector2(390,923)
    hand_scroll.size = Vector2(1030,142)
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(hand_scroll)
    hand_row.add_theme_constant_override("separation",12)
    hand_scroll.add_child(hand_row)
    energy_label = _label("",Rect2(1470,767,405,80),28,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    end_button = _button("턴 종료 · Enter",Rect2(1490,854,365,77),_end)
    piles_label = _label("",Rect2(1490,936,365,27),16,MINT,HORIZONTAL_ALIGNMENT_CENTER)
    _label("1 / 2 / 3 기술  ·  R 재시작\n첫 교체 무료 / 추가 교체 1\nF11 전체 화면",Rect2(1490,975,365,95),18,MINT,HORIZONTAL_ALIGNMENT_CENTER)
    notice = _label("씨뿌리기 + 분석 → 턴 종료 / 다음 턴 파이리: 불꽃세례 → 화염방사",Rect2(355,684,770,40),16,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    banner = _label("",Rect2(550,180,660,160),30,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var banner_box := StyleBoxFlat.new()
    banner_box.bg_color = Color(0.035,0.08,0.09,0.97)
    banner_box.border_color = GOLD
    banner_box.set_border_width_all(2)
    banner_box.set_content_margin_all(12)
    banner.add_theme_stylebox_override("normal",banner_box)
    banner.modulate.a = 0.0
    banner.z_index = 30
    damage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    damage_layer.z_index = 25
    add_child(damage_layer)
    _build_log()
    _build_result()

func _build_log() -> void:
    log_panel.position = Vector2(600,100)
    log_panel.size = Vector2(900,590)
    log_panel.z_index = 80
    var box := StyleBoxFlat.new()
    box.bg_color = Color("10272d")
    log_panel.add_theme_stylebox_override("panel",box)
    add_child(log_panel)
    log_text.position = Vector2(25,24)
    log_text.size = Vector2(850,535)
    log_text.scroll_following = true
    log_panel.add_child(log_text)
    log_panel.hide()

func _build_result() -> void:
    result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result.z_index = 100
    result.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(result)
    var shade := ColorRect.new()
    shade.color = Color(0.015,0.035,0.05,0.93)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result.add_child(shade)
    result_title = _label("",Rect2(410,260,1100,95),56,GOLD,HORIZONTAL_ALIGNMENT_CENTER,result)
    result_detail = _label("",Rect2(510,390,900,140),25,CREAM,HORIZONTAL_ALIGNMENT_CENTER,result)
    result_restart = _button("다시 시험하기 · R",Rect2(650,600,620,85),restart,result)
    _button("기존 짧은 원정 플레이 · F3",Rect2(650,710,620,70),_old_run,result)
    result.hide()

func _refresh() -> void:
    var foe := _visual_enemy if busy and _visual_enemy != null else battle.enemy()
    stage.canvas.set_species(battle.active().species_id,foe.species_id,catalog,false)
    stage.canvas.ally_statuses.assign(battle.active().statuses.keys())
    stage.canvas.enemy_statuses.assign(foe.statuses.keys())
    status_label.text = "턴 %d  ·  적 %d / %d" % [battle.turn,battle.enemy_index+1,battle.enemies.size()]
    var queue: Array[String] = []
    for pokemon: BattlePokemon in battle.enemies:
        queue.append("%s %s %d/%d" % ["▶" if pokemon == battle.enemy() else ("✓" if not pokemon.alive() else "·"),pokemon.display_name,pokemon.hp,pokemon.max_hp])
    queue_label.text = "  →  ".join(queue)
    ally_bar.get_child(0).size.x = ally_bar.size.x*battle.active().hp/battle.active().max_hp
    enemy_bar.get_child(0).size.x = enemy_bar.size.x*foe.hp/foe.max_hp
    ally_label.text = _pokemon_text(battle.active())
    enemy_label.text = _pokemon_text(foe)
    var action := battle.intent()
    var names := {"charge":"강공격", "attack":"공격", "block":"보호막", "boost":"공격력 강화"}
    intent_label.text = "다음 행동\n%s %d" % [names[action["kind"]],action["value"]]
    if battle.opening()["cancel"]: intent_label.text = "다음 행동\n브레이크로 취소!"
    var state := battle.opening()
    opening_label.text = "빈틈  %s  %d / 3\n%s" % ["◆".repeat(state["points"])+"◇".repeat(3-state["points"]),state["points"],"다음 공격 기술 ×2 준비!" if state["burst"] else ("브레이크 사용 완료" if state["broken"] else ("분석 예약됨" if state["analyzed"] else "약점 / 상태 / 분석 / 견제"))]
    energy_label.text = "에너지  %d\n환급 %d / %d" % [battle.energy,battle.refunds,TacticalBattle.REFUND_LIMIT]
    piles_label.text = "뽑기 %d  ·  버림 %d  ·  소진 %d" % [battle.draw_pile.size(),battle.discard.size(),battle.exhausted.size()]
    end_button.disabled = busy or battle.phase != TacticalBattle.PLAYER
    end_button.text = "아군을 선택하세요" if battle.phase == TacticalBattle.REPLACE else "턴 종료 · Enter"
    for i in party_buttons.size():
        var pokemon := battle.party[i]
        party_buttons[i].text = "%s%s  %d / %d\n%s" % ["▶ " if pokemon == battle.active() else "",pokemon.display_name,pokemon.hp,pokemon.max_hp,"출전 중" if pokemon == battle.active() else ("기절" if not pokemon.alive() else ("교체 · 무료" if not battle.switched or battle.phase == TacticalBattle.REPLACE else "교체 · 에너지 1"))]
        party_buttons[i].disabled = busy or not battle.switch_reason(pokemon.uid).is_empty()
    for i in skills.size():
        var key: String = TacticalContent.SKILLS[battle.active().species_id][i]
        var view := battle.skill_view(key)
        var reason := battle.skill_reason(key)
        var support := {"seed":"씨앗 3회 · 피해 2 / 회복 2", "growth":"전투 동안 공격력 +2", "fire_guard":"보호막 +8", "shell":"보호막 +8"}
        var description: String = "피해 %d" % view["preview_damage"] if view.has("preview_damage") else support.get(key,str(view["description"]).replace("\n"," "))
        if view.has("burn"): description += " · 화상 3회"
        skills[i].text = "%d  %s   [ %d ]\n%s" % [i+1,view["name"],view["cost"],description]
        skills[i].tooltip_text = str(view["description"])+("\n"+reason if not reason.is_empty() else "\n이 포켓몬으로 턴 1회 사용")
        skills[i].disabled = busy or not reason.is_empty()
    _refresh_hand()
    for key: String in relic_buttons:
        relic_buttons[key].text = ("✓  " if key == battle.relic else "")+TacticalContent.RELICS[key]["name"]
    guide_label.text = TacticalContent.RELICS[battle.relic]["description"]+"\n특성 선택 시 전투 재시작"
    log_text.text = "\n".join(battle.history)
    result.visible = not busy and battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]
    if result.visible:
        result.move_to_front()
        var breaks := battle.enemy_states.filter(func(s: Dictionary): return s["broken"]).size()
        result_title.text = "전술 시험 승리" if battle.phase == TacticalBattle.WON else "파티 전원 기절"
        result_detail.text = "턴 %d · 적 %d마리 격파 · 브레이크 %d회\n선택 특성: %s\n\n고정 기술 + 트레이너 카드 방식의 비교 전투입니다." % [battle.turn,battle.enemies.filter(func(p: BattlePokemon): return not p.alive()).size(),breaks,TacticalContent.RELICS[battle.relic]["name"]]

func _refresh_hand() -> void:
    for child: Node in hand_row.get_children():
        hand_row.remove_child(child)
        child.queue_free()
    trainer_buttons.clear()
    for card: BattleCardInstance in battle.hand:
        var view := battle.card_view(card)
        var button := Button.new()
        button.custom_minimum_size = Vector2(196,120)
        var summaries := {"analysis":"다음 공격에 빈틈 +1", "guard":"보호막 +6", "focus":"드로우 2 · 소진", "rally":"다음 공격 기본 피해 +4", "counter":"강공격 견제: 빈틈 +1\n그 외: 보호막 +4", "injury":"효과 없음"}
        button.text = "[ %d ]  %s\n%s" % [view["cost"],view["name"],summaries[card.key]]
        button.add_theme_font_size_override("font_size",17)
        button.tooltip_text = view["description"]
        button.disabled = busy or not battle.card_reason(card.uid).is_empty()
        button.pressed.connect(_card.bind(card.uid))
        hand_row.add_child(button)
        trainer_buttons[card.uid] = button
    # Costs/effects are available on hover, while the current deck remains inspectable.
    hand_scroll.tooltip_text = "뽑기 %d · 버림 %d · 소진 %d\n%s" % [battle.draw_pile.size(),battle.discard.size(),battle.exhausted.size(),"카드는 턴 종료 시 버립니다."]

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
        notice.text = reason
        return
    var move_id := 0
    var from_enemy := false
    var captions: Array[String] = []
    _damage_events.assign(battle.events.filter(func(event: Dictionary): return event["kind"] == "damage" and event["amount"] > 0))
    for event: Dictionary in battle.events:
        if event["kind"] in ["skill","card","enemy_action"] and event.has("move_id"):
            move_id = event["move_id"]
            from_enemy = event["kind"] == "enemy_action"
        if event["kind"] in ["break","chain","refund","enemy_switch","cancel","relay"]:
            captions.append(event["text"])
    notice.text = battle.events.back()["text"] if not battle.events.is_empty() else ""
    if not captions.is_empty():
        banner.text = "\n".join(captions.slice(0,3))
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
    log_panel.hide()
    battle.restart(battle.seed_value,battle.relic if selected_relic.is_empty() else selected_relic)
    notice.text = "씨뿌리기 + 분석 → 턴 종료 / 다음 턴 파이리: 불꽃세례 → 화염방사"
    _refresh()
func _old_run() -> void:
    get_tree().change_scene_to_file("res://scenes/battle_preview.tscn")
func _open_lab() -> void:
    get_node("/root/BattleSession").set("return_scene","res://scenes/tactical_battle.tscn")
    get_tree().change_scene_to_file("res://scenes/art_lab.tscn")
func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_1,KEY_2,KEY_3:
            _skill(TacticalContent.SKILLS[battle.active().species_id][event.keycode-KEY_1])
        KEY_Q: _switch(battle.party[0].uid)
        KEY_W: _switch(battle.party[1].uid)
        KEY_E: _switch(battle.party[2].uid)
        KEY_ENTER: _end()
        KEY_R: restart()
        KEY_F2: _open_lab()
        KEY_F3: _old_run()
        KEY_F11:
            var mode := DisplayServer.window_get_mode()
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
        KEY_ESCAPE: log_panel.hide()
func _pokemon_text(pokemon: BattlePokemon) -> String:
    var info := "%s · %s\nHP %d / %d  ·  보호막 %d" % [pokemon.display_name,catalog.type_name(pokemon.type),pokemon.hp,pokemon.max_hp,pokemon.block]
    var statuses: Array[String] = []
    for key: String in pokemon.statuses:
        statuses.append("%s %d회" % ["화상" if key == "burn" else "씨앗",pokemon.statuses[key]["turns"]])
    if pokemon.strength > 0: statuses.append("공격 +%d" % pokemon.strength)
    return info+"\n"+" / ".join(statuses)
func _label(value: String, rect: Rect2, font_size: int = 19, color: Color = CREAM, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, parent: Node = self) -> Label:
    var label := Label.new()
    label.text = value
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.horizontal_alignment = alignment
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label
func _button(value: String, rect: Rect2, action: Callable, parent: Node = self) -> Button:
    var button := Button.new()
    button.text = value
    button.position = rect.position
    button.size = rect.size
    button.pressed.connect(action)
    parent.add_child(button)
    return button
func _health_bar(rect: Rect2) -> ColorRect:
    var bar := ColorRect.new()
    bar.position = rect.position
    bar.size = rect.size
    bar.color = Color("364443")
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fill := ColorRect.new()
    fill.size = rect.size
    fill.color = Color("c4dd91")
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_child(fill)
    add_child(bar)
    return bar

func _shade(rect: Rect2,color: Color) -> void:
    var shade := ColorRect.new()
    shade.position = rect.position
    shade.size = rect.size
    shade.color = color
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
