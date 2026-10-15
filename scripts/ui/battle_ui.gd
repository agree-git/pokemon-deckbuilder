class_name BattleUI
extends Control
## Native 1080p battle controller/view. Rules and state live in BattleState.

signal card_requested(definition: Dictionary)
signal switch_requested(pokemon_id: int)
signal end_turn_requested

const SCREEN := Vector2(1920, 1080)
const INK := Color("111e22")
const CREAM := Color("eee3c5")
const GOLD := Color("d8bd7e")
const MINT := Color("b3d3ae")

var catalog := VisualCatalog.new()
var run: RunState
var battle: BattleState
var animating := false
var stage := PixelStage.new()
var active_id := 4
var target_id := 43
var biome_index := 3
var cards: Array[BattleCard] = []
var party_buttons: Array[Button] = []
var end_turn: Button
var notice: Label
var ally_name: Label
var ally_hp: Label
var enemy_name: Label
var region_label: Label
var _ally_hp_bar: ProgressBar
var _biome_popup := PanelContainer.new()
var _enemy_hp_bar: ProgressBar
var _enemy_hp: Label
var _party_hp: Label
var _intent_value: Label
var _intent_icon: Label
var _turn_label: Label
var _energy_label: Label
var _draw_count: Label
var _discard_count: Label
var _hand_count: Label
var _ally_info: Label
var _enemy_info: Label
var _history: RichTextLabel
var _result := Control.new()
var _result_title: Label
var _result_detail: Label
var capture_button: Button
var _ball_count: Label
var _battle_number: Label
var _next_button: Button
var _capture_choices := HBoxContainer.new()
var _shown_capture_uid := 0
var _reward_cards := Control.new()
var _reward_skip: Button
var _reward_signature := ""
var _party_signature := ""
var expedition := ExpeditionOverlay.new()
var _progress: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    run = get_node("/root/BattleSession").get("run") as RunState
    battle = run.battle
    _theme()
    stage.source_ratio = Vector2(0.245, 0.53)
    stage.target_ratio = Vector2(0.735, 0.47)
    stage.canvas.show_nameplates = false
    stage.canvas.sprite_zoom = 4
    stage.canvas.use_effect_statuses = false
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(stage)
    _build_shade()
    _build_top_bar()
    _build_combat_hud()
    _build_piles_and_energy()
    _build_biome_menu()
    _build_result()
    expedition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    expedition.z_index = 200
    add_child(expedition)
    expedition.changed.connect(_sync_run)
    expedition.restart_requested.connect(_restart_expedition)
    _set_biome(int(run.current_node["biome"]))
    card_requested.connect(_play_card)
    switch_requested.connect(set_active)
    end_turn_requested.connect(_end_turn)
    stage.canvas.effect.finished.connect(_animation_finished)
    _refresh()

func _theme() -> void:
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550.0}
    theme = Theme.new()
    theme.default_font = font
    theme.default_font_size = 19
    theme.set_color("font_color", "Label", CREAM)
    theme.set_color("font_color", "Button", CREAM)
    theme.set_stylebox("normal", "Button", _style(Color("1f3234"), Color("68776a")))
    theme.set_stylebox("hover", "Button", _style(Color("30494a"), GOLD))
    theme.set_stylebox("pressed", "Button", _style(Color("486259"), GOLD))
    theme.set_color("font_disabled_color", "Button", Color("82938c"))
    theme.set_stylebox("disabled", "Button", _style(Color("1c2a2d"), Color("44534e")))
    theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD))

func _style(color: Color, border: Color = Color.TRANSPARENT, width: int = 1) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(width)
    return box

func _build_shade() -> void:
    _rect(Rect2(0, 0, 1920, 76), Color(0.035, 0.08, 0.09, 0.95))
    _rect(Rect2(0, 75, 1920, 2), Color(GOLD, 0.55))
    for i in 9:
        _rect(Rect2(0, 720 + i * 40, 1920, 40), Color(0.025, 0.06, 0.07, 0.04 + i * 0.095))
    _rect(Rect2(0, 1039, 1920, 41), Color(0.025, 0.06, 0.07, 0.9))

func _build_top_bar() -> void:
    _label("관동 원정대", Rect2(35, 18, 210, 42), 27, GOLD)
    _party_hp = _label("", Rect2(270, 23, 180, 35), 22, Color("efa493"))
    _progress = _label("", Rect2(465, 23, 110, 35), 20, GOLD)
    _ball_count = _label("", Rect2(590, 23, 210, 35), 20, GOLD)
    _label("ACT 1", Rect2(895, 14, 100, 26), 14, MINT, HORIZONTAL_ALIGNMENT_CENTER)
    region_label = _label("햇살숲 정원", Rect2(825, 37, 240, 28), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _battle_number = _label("전투 01", Rect2(1100, 24, 105, 32), 18, MINT)
    var restart_button := _button("원정 재시작 · R", Rect2(1214, 18, 160, 40))
    restart_button.pressed.connect(restart_battle)
    restart_button.tooltip_text = "R: 같은 시드로 원정 재시작 · Shift+R: 새 시드"
    var biomes := _button("전투 기록", Rect2(1390, 18, 128, 40))
    biomes.pressed.connect(func(): _biome_popup.visible = not _biome_popup.visible)
    var lab := _button("아트 랩 · F2", Rect2(1534, 18, 150, 40))
    lab.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/art_lab.tscn"))
    var settings := _button("화면 · F11", Rect2(1700, 18, 165, 40))
    settings.pressed.connect(_toggle_fullscreen)
    _label("관동 교체 전투", Rect2(35, 103, 220, 27), 19, Color("d1debf"))
    _label("9개 장소 · 목표: 숲의 수호자 격파", Rect2(35, 136, 320, 27), 16, Color("b0c4a9"))

func _build_combat_hud() -> void:
    var intent := Panel.new()
    intent.position = Vector2(1320, 296)
    intent.size = Vector2(180, 66)
    intent.add_theme_stylebox_override("panel", _style(Color(0.11, 0.12, 0.12, 0.91), Color("d9a38b")))
    add_child(intent)
    _intent_icon = _label("⚔", Rect2(1333, 303, 48, 49), 31, Color("f1a58d"), HORIZONTAL_ALIGNMENT_CENTER)
    _intent_value = _label("", Rect2(1382, 306, 108, 40), 24, Color("efc7a5"))
    _label("다음 행동", Rect2(1320, 365, 180, 29), 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _rect(Rect2(326, 654, 290, 78), Color(0.06, 0.13, 0.13, 0.74))
    _rect(Rect2(1265, 620, 290, 78), Color(0.06, 0.13, 0.13, 0.74))
    ally_name = _label("파이리", Rect2(336, 663, 270, 34), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    enemy_name = _label("뚜벅쵸", Rect2(1275, 629, 270, 34), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _ally_hp_bar = _health_bar(Rect2(336, 704, 270, 21), Color("dc8571"), 42, 45)
    ally_hp = _label("42 / 45", Rect2(336, 699, 270, 31), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _enemy_hp_bar = _health_bar(Rect2(1275, 670, 270, 21), Color("dc8571"), 64, 64)
    _enemy_hp = _label("", Rect2(1275, 665, 270, 31), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _ally_info = _label("", Rect2(336, 735, 380, 29), 15, MINT)
    _enemy_info = _label("", Rect2(1250, 701, 390, 29), 15, MINT)
    _label("아군 교체", Rect2(230, 741, 145, 28), 15, MINT)
    _build_party_buttons()
    capture_button = _button("포획 · 에너지 1", Rect2(1660, 727, 204, 66))
    capture_button.add_theme_font_size_override("font_size", 21)
    capture_button.pressed.connect(_capture)
    notice = _label("카드를 사용하고 적의 다음 행동에 대비하세요.", Rect2(660, 690, 600, 34), 19, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    notice.add_theme_color_override("font_shadow_color", Color("12251e"))
    notice.add_theme_constant_override("shadow_offset_x", 2)
    notice.add_theme_constant_override("shadow_offset_y", 2)
    end_turn = _button("턴 종료  ›", Rect2(1660, 817, 204, 66))
    end_turn.add_theme_font_size_override("font_size", 26)
    end_turn.add_theme_stylebox_override("normal", _style(Color("36514a"), GOLD, 2))
    end_turn.pressed.connect(func(): end_turn_requested.emit())
    _turn_label = _label("", Rect2(1660, 890, 204, 28), 17, MINT, HORIZONTAL_ALIGNMENT_CENTER)

func _build_party_buttons() -> void:
    for old: Button in party_buttons:
        remove_child(old)
        old.queue_free()
    party_buttons.clear()
    var signature := ""
    for i in battle.party.size():
        var pokemon: BattlePokemon = battle.party[i]
        var id := pokemon.uid
        signature += str(id) + ":"
        var button := _button("", Rect2(230, 772 + i * 70, 145, 63))
        button.icon = load(VisualCatalog.sprite_path(pokemon.species_id))
        button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.expand_icon = true
        button.add_theme_constant_override("icon_max_width", 48)
        button.add_theme_font_size_override("font_size", 14)
        button.pressed.connect(func(): switch_requested.emit(id))
        party_buttons.append(button)
    _party_signature = signature

func _build_hand() -> void:
    for old: BattleCard in cards:
        remove_child(old)
        old.queue_free()
    cards.clear()
    var step := minf(188, 900.0 / maxf(1, battle.hand.size() - 1))
    for i in battle.hand.size():
        var card := BattleCard.new()
        var instance: BattleCardInstance = battle.hand[i]
        card.definition = battle.card_view(instance)
        var offset := i - (battle.hand.size() - 1) / 2.0
        card.home_position = Vector2(1010 + offset * step - 101, 752 + absf(offset) * 10)
        card.home_rotation = deg_to_rad(offset * 3)
        card.position = card.home_position
        card.rotation = card.home_rotation
        add_child(card)
        card.pressed.connect(func(): card_requested.emit(card.definition))
        var reason := "연출 진행 중입니다." if animating else battle.card_reason(instance.uid)
        card.set_available(reason.is_empty(), reason)
        cards.append(card)

func _build_piles_and_energy() -> void:
    var orb := Panel.new()
    orb.position = Vector2(64, 824)
    orb.size = Vector2(146, 146)
    var box := _style(Color("263e3b"), GOLD, 3)
    box.set_corner_radius_all(73)
    orb.add_theme_stylebox_override("panel", box)
    orb.tooltip_text = "파티 공유 에너지 · 기본 3 · 어니부기 특성: 첫 턴 +1"
    add_child(orb)
    _energy_label = _label("", Rect2(76, 832, 122, 86), 65, Color("f2e2a8"), HORIZONTAL_ALIGNMENT_CENTER)
    _label("공유 에너지", Rect2(73, 915, 128, 29), 17, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _draw_count = _pile(Rect2(74, 983, 116, 67), "뽑을 더미", "")
    _discard_count = _pile(Rect2(1734, 983, 116, 67), "버린 더미", "")
    _hand_count = _label("", Rect2(839, 1050, 242, 27), 16, MINT, HORIZONTAL_ALIGNMENT_CENTER)
    _label("Enter 턴 종료 · R 다시 시작 · F2 아트 랩", Rect2(1400, 1050, 465, 27), 14, Color("96aa9c"), HORIZONTAL_ALIGNMENT_RIGHT)

func _pile(rect: Rect2, name_text: String, count: String) -> Label:
    for offset in [Vector2(6, -6), Vector2(3, -3), Vector2.ZERO]:
        var panel := Panel.new()
        panel.position = rect.position + offset
        panel.size = rect.size
        panel.add_theme_stylebox_override("panel", _style(Color("1c3435"), Color("a5ab87")))
        panel.tooltip_text = name_text
        add_child(panel)
    var label := _label(count, Rect2(rect.position + Vector2(0, 1), Vector2(rect.size.x, 35)), 27, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _label(name_text, Rect2(rect.position + Vector2(0, 36), Vector2(rect.size.x, 25)), 14, MINT, HORIZONTAL_ALIGNMENT_CENTER)
    return label

func _build_biome_menu() -> void:
    _biome_popup.position = Vector2(1210, 86)
    _biome_popup.size = Vector2(650, 480)
    _biome_popup.add_theme_stylebox_override("panel", _style(Color("152a2b"), GOLD))
    _biome_popup.z_index = 50
    add_child(_biome_popup)
    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    _biome_popup.add_child(margin)
    _history = RichTextLabel.new()
    _history.custom_minimum_size = Vector2(610, 440)
    _history.scroll_following = true
    _history.add_theme_font_size_override("normal_font_size", 18)
    margin.add_child(_history)
    _biome_popup.hide()

func _build_result() -> void:
    _result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _result.z_index = 100
    add_child(_result)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.05, 0.07, 0.8)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _result.add_child(shade)
    var panel := Panel.new()
    panel.position = Vector2(480, 220)
    panel.size = Vector2(960, 610)
    panel.add_theme_stylebox_override("panel", _style(Color("162c2c"), GOLD, 2))
    _result.add_child(panel)
    _result_title = _label("", Rect2(530, 250, 860, 70), 45, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    remove_child(_result_title)
    _result.add_child(_result_title)
    _result_detail = _label("", Rect2(530, 340, 860, 110), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    remove_child(_result_detail)
    _result.add_child(_result_detail)
    var again := _button("원정 재시작 · R", Rect2(620, 720, 310, 62))
    remove_child(again)
    _result.add_child(again)
    again.pressed.connect(restart_battle)
    _next_button = _button("원정 지도로  ›", Rect2(990, 720, 310, 62))
    remove_child(_next_button)
    _result.add_child(_next_button)
    _next_button.pressed.connect(_next_battle)
    _capture_choices.position = Vector2(520, 490)
    _capture_choices.size = Vector2(880, 170)
    _capture_choices.add_theme_constant_override("separation", 16)
    _result.add_child(_capture_choices)
    _reward_cards.position = Vector2(0, 420)
    _reward_cards.size = Vector2(1920, 282)
    _reward_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _result.add_child(_reward_cards)
    _reward_skip = _button("보상 넘기기", Rect2(990, 720, 310, 62))
    remove_child(_reward_skip)
    _result.add_child(_reward_skip)
    _reward_skip.pressed.connect(_choose_reward.bind(-1))
    _reward_skip.hide()
    _result.hide()

func _set_biome(index: int) -> void:
    biome_index = index
    var biome: Dictionary = catalog.biomes[index]
    stage.canvas.background = VisualCatalog.biome_texture(biome)
    region_label.text = biome["name"]

func set_active(id: int) -> void:
    if animating or run.phase != RunState.BATTLE:
        return
    var reason := battle.switch_to(id)
    if not reason.is_empty():
        notice.text = reason
        return
    notice.text = "%s 출전" % battle.active().display_name
    _animate_enemy_if_needed()
    _refresh()

func _play_card(definition: Dictionary) -> void:
    if animating or run.phase != RunState.BATTLE:
        return
    var reason := battle.play_card(int(definition["uid"]))
    if not reason.is_empty():
        notice.text = reason
        return
    var move := catalog.move_by_id(int(definition["move_id"])).duplicate(true)
    move["name"] = definition["name"]
    animating = true
    stage.canvas.effect_from_enemy = false
    stage.canvas.effect.play(move, stage.canvas.source_anchor, stage.canvas.target_anchor)
    notice.text = "%s의 %s" % [battle.active().display_name, definition["name"]]
    _refresh()

func _end_turn() -> void:
    if animating or run.phase != RunState.BATTLE:
        return
    var reason := battle.end_turn()
    if not reason.is_empty():
        notice.text = reason
        return
    _animate_enemy_if_needed()
    _refresh()

func _animate_enemy_if_needed() -> void:
    for event: Dictionary in battle.events:
        if event["kind"] == "enemy_action":
            var move := catalog.move_by_id(int(event["move_id"])).duplicate(true)
            animating = true
            stage.canvas.effect_from_enemy = true
            # A KO may have changed the active ally only during forced selection.
            stage.canvas.effect.play(move, stage.canvas.target_anchor, stage.canvas.source_anchor)
            notice.text = event["text"]
            return

func _animation_finished(_move: Dictionary) -> void:
    animating = false
    _refresh()

func restart_battle() -> void:
    stage.canvas.clear_effects()
    animating = false
    run.restart(run.seed_value)
    battle = run.battle
    _shown_capture_uid = 0
    _reward_signature = ""
    _build_party_buttons()
    _biome_popup.hide()
    _set_biome(int(run.current_node["biome"]))
    notice.text = "햇살숲 원정 출발 · 수호자를 쓰러뜨리고 9개 장소를 완주하세요."
    _refresh()

func _refresh() -> void:
    if run.battle != battle:
        battle = run.battle
    var signature := ""
    for pokemon: BattlePokemon in battle.party:
        signature += str(pokemon.uid) + ":"
    if signature != _party_signature:
        _build_party_buttons()
    var actor := battle.active()
    if active_id != actor.species_id or target_id != battle.enemy.species_id or stage.canvas.source_sprite.texture == null:
        active_id = actor.species_id
        target_id = battle.enemy.species_id
        stage.canvas.set_species(active_id, target_id, catalog, not animating)
    ally_name.text = actor.display_name
    enemy_name.text = battle.enemy.display_name
    ally_hp.text = "%d / %d" % [actor.hp, actor.max_hp]
    _ally_hp_bar.max_value = actor.max_hp
    _ally_hp_bar.value = actor.hp
    _enemy_hp.text = "%d / %d" % [battle.enemy.hp, battle.enemy.max_hp]
    _enemy_hp_bar.max_value = battle.enemy.max_hp
    _enemy_hp_bar.value = battle.enemy.hp
    var total := 0
    var maximum := 0
    for i in battle.party.size():
        var pokemon: BattlePokemon = battle.party[i]
        total += pokemon.hp
        maximum += pokemon.max_hp
        var selected := pokemon == actor
        var caption := "출전 중" if selected else "교체 · 1" if battle.switched and battle.phase == BattleState.PLAYER else "교체 · 무료"
        if not pokemon.alive():
            caption = "기절"
        party_buttons[i].text = "%s\n%d/%d" % [caption, pokemon.hp, pokemon.max_hp]
        var reason := "연출 진행 중입니다." if animating else battle.switch_reason(pokemon.uid)
        party_buttons[i].disabled = not reason.is_empty()
        party_buttons[i].tooltip_text = reason if not reason.is_empty() else "%s 출전" % pokemon.display_name
        party_buttons[i].add_theme_stylebox_override("normal", _style(Color("385344") if selected else Color("1e3434"), GOLD if selected else Color("64796b")))
    _progress.text = "%d / 9" % (run.step + 1)
    _battle_number.text = "전투 %02d" % (run.encounter + 1)
    _ball_count.text = "몬스터볼  %d" % battle.balls
    _party_hp.text = "♥  %d / %d" % [total, maximum]
    _energy_label.text = str(battle.energy)
    _draw_count.text = str(battle.draw_pile.size())
    _discard_count.text = str(battle.discard.size())
    _hand_count.text = "공유 손패  %d장" % battle.hand.size()
    _turn_label.text = "턴 %d" % battle.turn
    var next := battle.intent()
    _intent_value.text = "%s %d" % [{"attack": "공격", "block": "방어", "boost": "강화"}[next["kind"]], int(next["value"])]
    _intent_icon.text = {"attack": "⚔", "block": "◇", "boost": "↑"}[next["kind"]]
    var xp_text := "XP %d / 4" % actor.experience if ExpeditionContent.EVOLUTIONS.has(actor.species_id) else "XP %d" % actor.experience
    _ally_info.text = _status_text(actor) + "  · " + xp_text
    _enemy_info.text = _status_text(battle.enemy)
    stage.canvas.ally_statuses.assign(actor.statuses.keys())
    stage.canvas.enemy_statuses.assign(battle.enemy.statuses.keys())
    _history.text = "전투 기록\n\n" + "\n".join(battle.history)
    capture_button.disabled = animating or not battle.capture_reason().is_empty()
    capture_button.tooltip_text = "체력 25% 이하 · 확정 포획 · 기술 보상 없음" if not capture_button.disabled else battle.capture_reason()
    end_turn.disabled = animating or battle.phase != BattleState.PLAYER
    end_turn.text = "아군 선택" if battle.phase == BattleState.REPLACE else "전투 종료" if battle.phase in [BattleState.WON, BattleState.LOST, BattleState.CAPTURED] else "턴 종료  ›"
    if battle.phase == BattleState.REPLACE:
        notice.text = "기절한 아군을 대신할 포켓몬을 선택하세요."
    stage.canvas.source_sprite.visible = actor.alive()
    stage.canvas.target_sprite.visible = battle.enemy.alive() or animating
    _result.visible = run.phase in [RunState.BATTLE,RunState.FAILED] and not animating and battle.phase in [BattleState.WON, BattleState.LOST, BattleState.CAPTURED]
    if _result.visible:
        run.settle()
        _result_title.text = "포획 성공" if battle.phase == BattleState.CAPTURED else "전투 승리" if battle.phase == BattleState.WON else "전투 패배"
        _result_detail.text = "턴 %d · 남은 체력 %d / %d\n체력과 덱을 유지해 다음 야생 전투로 이동합니다." % [battle.turn, total, maximum]
        if battle.phase == BattleState.CAPTURED:
            _result_detail.text = "%s 포획 · 몬스터볼 %d개 남음\n%s" % [battle.enemy.display_name, run.balls, "파티가 가득 찼습니다. 내보낼 포켓몬을 선택하세요." if run.pending_capture != null else run.capture_result]
        elif battle.phase == BattleState.LOST:
            _result_detail.text = "모든 아군이 기절했습니다. 원정을 다시 시작하세요."
        _next_button.disabled = run.pending_capture != null or run.reward_pending
        if battle.phase == BattleState.WON:
            _result_detail.text = "살아 있는 파티원의 기술 1장을 선택하세요.\n보상을 넘기면 덱을 유지합니다." if run.reward_pending else run.reward_result
        _next_button.visible = battle.phase != BattleState.LOST and not run.reward_pending
        _update_capture_choices()
    _capture_choices.visible = run.pending_capture != null
    _reward_cards.visible = _result.visible and run.reward_pending
    _reward_skip.visible = _reward_cards.visible
    if _reward_cards.visible:
        _update_reward_cards()
    _build_hand()
    # GUI hit order uses sibling order, so overlays must follow newly built cards.
    if _result.visible:
        _result.move_to_front()
    elif _biome_popup.visible:
        _biome_popup.move_to_front()
    expedition.show_run(run)
    if expedition.visible:
        expedition.move_to_front()

func _update_reward_cards() -> void:
    var signature := "%d:%d:%s" % [run.seed_value, run.encounter, run.reward_options]
    if _reward_signature == signature:
        return
    _reward_signature = signature
    for child: Node in _reward_cards.get_children():
        _reward_cards.remove_child(child)
        child.queue_free()
    var count := run.reward_options.size()
    for i in count:
        var card := BattleCard.new()
        card.definition = run.reward_view(i)
        card.lift_on_hover = false
        card.position = Vector2(960 - (count * 202 + (count - 1) * 68) / 2.0 + i * 270, 0)
        _reward_cards.add_child(card)
        card.pressed.connect(_choose_reward.bind(i))

func _choose_reward(index: int) -> void:
    var reason := run.choose_reward(index)
    if not reason.is_empty():
        notice.text = reason
        return
    _refresh()

func _capture() -> void:
    if animating or run.phase != RunState.BATTLE:
        return
    var reason := battle.capture()
    if not reason.is_empty():
        notice.text = reason
        return
    notice.text = "%s 포획 성공!" % battle.enemy.display_name
    _refresh()

func _update_capture_choices() -> void:
    if run.pending_capture == null or _shown_capture_uid == run.pending_capture.uid:
        return
    _shown_capture_uid = run.pending_capture.uid
    for child: Node in _capture_choices.get_children():
        _capture_choices.remove_child(child)
        child.queue_free()
    var choices: Array[BattlePokemon] = run.party.duplicate()
    choices.append(run.pending_capture)
    for pokemon: BattlePokemon in choices:
        var button := Button.new()
        button.custom_minimum_size = Vector2(208, 160)
        button.text = "%s\n%s" % [pokemon.display_name, "새 포켓몬 풀어주기" if pokemon == run.pending_capture else "내보내고 교체"]
        button.icon = load(VisualCatalog.sprite_path(pokemon.species_id))
        button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
        button.add_theme_font_size_override("font_size", 17)
        if pokemon != run.pending_capture:
            var owned := 0
            var injuries := 0
            for card: BattleCardInstance in run.deck:
                owned += 1 if card.owner_uid == pokemon.uid else 0
                injuries += 1 if card.injury_owner_uid == pokemon.uid else 0
            button.tooltip_text = "전용 카드 %d장과 연결된 부상 %d장을 제거합니다. 공용 카드는 유지됩니다." % [owned, injuries]
        var uid := pokemon.uid
        button.pressed.connect(func():
            var reason := run.resolve_capture(uid)
            if not reason.is_empty():
                notice.text = reason
            _refresh())
        _capture_choices.add_child(button)

func _next_battle() -> void:
    var reason := run.next_battle()
    if not reason.is_empty():
        notice.text = reason
        return
    _sync_run()

func _sync_run() -> void:
    battle = run.battle
    stage.canvas.clear_effects()
    animating = false
    _shown_capture_uid = 0
    _reward_signature = ""
    _build_party_buttons()
    _set_biome(int(run.current_node["biome"]))
    notice.text = "%s · %s" % [run.current_node["name"],ExpeditionContent.kind_name(run.current_node["kind"])]
    _refresh()

func _restart_expedition(new_seed: bool) -> void:
    if new_seed:
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        var next_seed := rng.randi_range(1,999999)
        run.seed_value = next_seed if next_seed != run.seed_value else (next_seed + 1) % 1000000
    restart_battle()

func _status_text(pokemon: BattlePokemon) -> String:
    var parts := PackedStringArray()
    if pokemon.block > 0:
        parts.append("보호막 %d" % pokemon.block)
    if pokemon.strength > 0:
        parts.append("공격력 +%d" % pokemon.strength)
    for key: String in pokemon.statuses:
        parts.append("%s %d회" % ["화상" if key == "burn" else "씨뿌리기", int(pokemon.statuses[key]["turns"])])
    return " · ".join(parts)

func _toggle_fullscreen() -> void:
    var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F2:
                get_tree().change_scene_to_file("res://scenes/art_lab.tscn")
            KEY_R:
                _restart_expedition(event.shift_pressed)
            KEY_ENTER:
                if not end_turn.disabled:
                    end_turn_requested.emit()
            KEY_F11:
                _toggle_fullscreen()
            KEY_ESCAPE:
                _biome_popup.hide()

func _health_bar(rect: Rect2, color: Color, value: float, maximum: float) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = rect.position
    bar.size = rect.size
    bar.max_value = maximum
    bar.value = value
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_theme_stylebox_override("background", _style(Color("253b35"), Color("788476")))
    bar.add_theme_stylebox_override("fill", _style(color))
    add_child(bar)
    return bar

func _rect(rect: Rect2, color: Color) -> void:
    var node := ColorRect.new()
    node.position = rect.position
    node.size = rect.size
    node.color = color
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(node)

func _label(text_value: String, rect: Rect2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = rect.position
    label.size = rect.size
    label.horizontal_alignment = alignment
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label

func _button(text_value: String, rect: Rect2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = rect.position
    button.size = rect.size
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    add_child(button)
    return button
