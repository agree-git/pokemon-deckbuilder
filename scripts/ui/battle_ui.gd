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

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle = get_node("/root/BattleSession").get("battle") as BattleState
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
    _set_biome(3)
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
    _label("●  0", Rect2(465, 23, 90, 35), 22, GOLD)
    _label("포션", Rect2(590, 23, 60, 35), 18, MINT)
    for i in 3:
        var slot := Panel.new()
        slot.position = Vector2(650 + i * 48, 17)
        slot.size = Vector2(38, 40)
        slot.add_theme_stylebox_override("panel", _style(Color("182d30"), Color("657c70")))
        slot.tooltip_text = "빈 포션 슬롯"
        add_child(slot)
        _label("◇", Rect2(653 + i * 48, 20, 32, 34), 23, Color("768f83"), HORIZONTAL_ALIGNMENT_CENTER)
    _label("ACT 1", Rect2(895, 14, 100, 26), 14, MINT, HORIZONTAL_ALIGNMENT_CENTER)
    region_label = _label("햇살숲 정원", Rect2(825, 37, 240, 28), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    _label("전투 01", Rect2(1100, 24, 105, 32), 18, MINT)
    var restart_button := _button("다시 시작 · R", Rect2(1214, 18, 160, 40))
    restart_button.pressed.connect(restart_battle)
    var biomes := _button("전투 기록", Rect2(1390, 18, 128, 40))
    biomes.pressed.connect(func(): _biome_popup.visible = not _biome_popup.visible)
    var lab := _button("아트 랩 · F2", Rect2(1534, 18, 150, 40))
    lab.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/art_lab.tscn"))
    var settings := _button("화면 · F11", Rect2(1700, 18, 165, 40))
    settings.pressed.connect(_toggle_fullscreen)
    _label("관동 교체 전투", Rect2(35, 103, 220, 27), 19, Color("d1debf"))
    _label("공유 덱 · 파이리 / 이상해씨", Rect2(35, 136, 320, 27), 16, Color("b0c4a9"))

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
    for i in battle.party.size():
        var pokemon: BattlePokemon = battle.party[i]
        var id := pokemon.uid
        var button := _button("", Rect2(230, 772 + i * 70, 145, 63))
        button.icon = load(VisualCatalog.sprite_path(pokemon.species_id))
        button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.expand_icon = true
        button.add_theme_constant_override("icon_max_width", 48)
        button.add_theme_font_size_override("font_size", 14)
        button.tooltip_text = "아군 교체 · %s" % catalog.species(id)["name"]
        button.pressed.connect(func(): switch_requested.emit(id))
        party_buttons.append(button)
    notice = _label("카드를 사용하고 적의 다음 행동에 대비하세요.", Rect2(660, 690, 600, 34), 19, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    notice.add_theme_color_override("font_shadow_color", Color("12251e"))
    notice.add_theme_constant_override("shadow_offset_x", 2)
    notice.add_theme_constant_override("shadow_offset_y", 2)
    end_turn = _button("턴 종료  ›", Rect2(1660, 817, 204, 66))
    end_turn.add_theme_font_size_override("font_size", 26)
    end_turn.add_theme_stylebox_override("normal", _style(Color("36514a"), GOLD, 2))
    end_turn.pressed.connect(func(): end_turn_requested.emit())
    _turn_label = _label("", Rect2(1660, 890, 204, 28), 17, MINT, HORIZONTAL_ALIGNMENT_CENTER)

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
    orb.tooltip_text = "파티 공유 에너지 · 턴 시작 시 3 회복"
    add_child(orb)
    _energy_label = _label("", Rect2(76, 832, 122, 86), 65, Color("f2e2a8"), HORIZONTAL_ALIGNMENT_CENTER)
    _label("에너지 / 3", Rect2(73, 915, 128, 29), 17, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
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
    panel.position = Vector2(540, 300)
    panel.size = Vector2(840, 370)
    panel.add_theme_stylebox_override("panel", _style(Color("162c2c"), GOLD, 2))
    _result.add_child(panel)
    _result_title = _label("", Rect2(590, 340, 740, 70), 45, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    remove_child(_result_title)
    _result.add_child(_result_title)
    _result_detail = _label("", Rect2(590, 430, 740, 75), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
    remove_child(_result_detail)
    _result.add_child(_result_detail)
    var again := _button("다시 도전 · R", Rect2(805, 550, 310, 62))
    remove_child(again)
    _result.add_child(again)
    again.pressed.connect(restart_battle)
    _result.hide()

func _set_biome(index: int) -> void:
    biome_index = index
    var biome: Dictionary = catalog.biomes[index]
    stage.canvas.background = VisualCatalog.biome_texture(biome)
    region_label.text = biome["name"]

func set_active(id: int) -> void:
    if animating:
        return
    var reason := battle.switch_to(id)
    if not reason.is_empty():
        notice.text = reason
        return
    notice.text = "%s 출전" % battle.active().display_name
    _animate_enemy_if_needed()
    _refresh()

func _play_card(definition: Dictionary) -> void:
    if animating:
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
    if animating:
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
    battle.restart(battle.seed_value)
    _biome_popup.hide()
    notice.text = "새 전투 · 카드와 교체로 적의 행동에 대비하세요."
    _refresh()

func _refresh() -> void:
    var actor := battle.active()
    if active_id != actor.species_id or stage.canvas.source_sprite.texture == null:
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
    _party_hp.text = "♥  %d / %d" % [total, maximum]
    _energy_label.text = str(battle.energy)
    _draw_count.text = str(battle.draw_pile.size())
    _discard_count.text = str(battle.discard.size())
    _hand_count.text = "공유 손패  %d장" % battle.hand.size()
    _turn_label.text = "턴 %d" % battle.turn
    var next := battle.intent()
    _intent_value.text = "%s %d" % [{"attack": "공격", "block": "방어", "boost": "강화"}[next["kind"]], int(next["value"])]
    _intent_icon.text = {"attack": "⚔", "block": "◇", "boost": "↑"}[next["kind"]]
    _ally_info.text = _status_text(actor)
    _enemy_info.text = _status_text(battle.enemy)
    stage.canvas.ally_statuses.assign(actor.statuses.keys())
    stage.canvas.enemy_statuses.assign(battle.enemy.statuses.keys())
    _history.text = "전투 기록\n\n" + "\n".join(battle.history)
    end_turn.disabled = animating or battle.phase != BattleState.PLAYER
    end_turn.text = "아군 선택" if battle.phase == BattleState.REPLACE else "전투 종료" if battle.phase in [BattleState.WON, BattleState.LOST] else "턴 종료  ›"
    if battle.phase == BattleState.REPLACE:
        notice.text = "기절한 아군을 대신할 포켓몬을 선택하세요."
    stage.canvas.source_sprite.visible = actor.alive()
    stage.canvas.target_sprite.visible = battle.enemy.alive() or animating
    _result.visible = not animating and battle.phase in [BattleState.WON, BattleState.LOST]
    if _result.visible:
        _result_title.text = "전투 승리" if battle.phase == BattleState.WON else "전투 패배"
        _result_detail.text = "턴 %d · 남은 체력 %d / %d\n다시 도전하면 같은 시드로 덱 순서가 재현됩니다." % [battle.turn, total, maximum]
    _build_hand()

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
                restart_battle()
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
