class_name ArtLab
extends Control
## Offline visual authoring preview. This scene deliberately owns no battle rules.

const BG := Color("0c141e")
const PANEL := Color("121f2b")
const TEXT := Color("e3eadf")
const MUTED := Color("92a6ae")
const ACCENT := Color("a2dcab")
const STATUS_KEYS := ["", "burn", "poison", "paralysis", "sleep", "freeze", "confusion", "seed", "bind"]

var catalog := VisualCatalog.new()
var stage := PixelStage.new()
var biome_index := 3
var source_id := 4
var target_id := 1
var selected_move: Dictionary
var filtered_moves: Array = []
var biome_buttons: Array[Button] = []
var encounter_buttons: Array[Button] = []
var biome_title := Label.new()
var biome_description := Label.new()
var encounter_note := Label.new()
var encounter_list := VBoxContainer.new()
var move_search := LineEdit.new()
var type_filter := OptionButton.new()
var move_list := ItemList.new()
var move_description := Label.new()
var play_button := Button.new()
var source_select := OptionButton.new()
var target_select := OptionButton.new()
var status_select := OptionButton.new()
var repeat := CheckButton.new()
var _repeat_delay := 0.0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _build_theme()
    _build_ui()
    stage.canvas.effect.finished.connect(_effect_finished)
    _filter_moves()
    select_biome(3)
    select_move(52) # Ember, with a burn secondary-effect preview.
    _update_species()

func _build_theme() -> void:
    var style := Theme.new()
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
    style.default_font = font
    style.default_font_size = 15
    style.set_color("font_color", "Label", TEXT)
    style.set_color("font_color", "Button", TEXT)
    style.set_color("font_hover_color", "Button", Color.WHITE)
    style.set_color("font_pressed_color", "Button", BG)
    style.set_stylebox("normal", "Button", _box(Color("20323d")))
    style.set_stylebox("hover", "Button", _box(Color("304b50"), ACCENT))
    style.set_stylebox("pressed", "Button", _box(ACCENT))
    style.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT))
    style.set_stylebox("panel", "PanelContainer", _box(PANEL))
    style.set_stylebox("panel", "ItemList", _box(BG))
    style.set_stylebox("selected", "ItemList", _box(Color("304a47")))
    style.set_stylebox("selected_focus", "ItemList", _box(Color("304a47"), ACCENT))
    style.set_color("font_color", "ItemList", TEXT)
    style.set_color("font_selected_color", "ItemList", Color.WHITE)
    style.set_constant("v_separation", "ItemList", 7)
    style.set_stylebox("normal", "LineEdit", _box(BG))
    style.set_color("font_color", "LineEdit", TEXT)
    theme = style

func _box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1 if border.a > 0 else 0)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    return style

func _build_ui() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = BG
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 22)
    add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)
    var header := HBoxContainer.new()
    header.add_child(_label("관동 원정대", 28, TEXT))
    var subtitle := _label("   ART LAB  /  스프라이트 · 기술 · 바이옴", 15, MUTED)
    subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(subtitle)
    header.add_child(_label("151종  ·  18개 지역  ·  PIXEL ART", 14, ACCENT))
    root.add_child(header)
    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 16)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)
    _build_biome_sidebar(body)
    var middle := VBoxContainer.new()
    middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    middle.add_theme_constant_override("separation", 8)
    body.add_child(middle)
    biome_title.add_theme_font_size_override("font_size", 23)
    middle.add_child(biome_title)
    biome_description.add_theme_color_override("font_color", MUTED)
    biome_description.add_theme_font_size_override("font_size", 13)
    middle.add_child(biome_description)
    stage.custom_minimum_size = Vector2(640, 432)
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    middle.add_child(stage)
    _build_species_selectors(middle)
    _build_move_controls(middle)
    _build_inspector(body)
    root.add_child(_label("SPACE  기술 재생     ← →  지역 이동     ESC  연출 초기화     |     연출 전용 프리뷰 · 전투 규칙과 출현 밸런스는 추후 연결", 12, MUTED))

func _build_biome_sidebar(body: HBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = 190
    body.add_child(panel)
    var column := VBoxContainer.new()
    column.add_child(_label("탐험 지역", 18, ACCENT))
    column.add_child(_label("타입별 바이옴  /  관동 한정", 11, MUTED))
    panel.add_child(column)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 5)
    scroll.add_child(list)
    for i in catalog.biomes.size():
        var biome: Dictionary = catalog.biomes[i]
        var button := Button.new()
        button.text = "%02d  %s" % [i + 1, biome["name"]]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size", 13)
        button.add_theme_color_override("font_color", VisualCatalog.type_color(biome["type"]))
        button.toggle_mode = true
        button.pressed.connect(select_biome.bind(i))
        button.tooltip_text = catalog.type_name(biome["type"])
        list.add_child(button)
        biome_buttons.append(button)

func _build_species_selectors(parent: VBoxContainer) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)
    row.add_child(_label("아군", 13, ACCENT))
    for entry: Dictionary in catalog.pokemon:
        var name_text := "#%03d %s" % [int(entry["id"]), entry["name"]]
        source_select.add_item(name_text, int(entry["id"]))
        target_select.add_item(name_text, int(entry["id"]))
    source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    source_select.selected = source_id - 1
    target_select.selected = target_id - 1
    source_select.item_selected.connect(func(index: int):
        source_id = source_select.get_item_id(index)
        _update_species())
    target_select.item_selected.connect(func(index: int):
        target_id = target_select.get_item_id(index)
        _update_species())
    row.add_child(source_select)
    row.add_child(_label("상대", 13, Color("ffdba2")))
    row.add_child(target_select)
    var facing := CheckButton.new()
    facing.text = "뒷모습"
    facing.button_pressed = true
    facing.toggled.connect(func(value: bool):
        stage.canvas.back_view = value
        _update_species())
    row.add_child(facing)

func _build_move_controls(parent: VBoxContainer) -> void:
    var search_row := HBoxContainer.new()
    move_search.placeholder_text = "기술 검색 · 한글 / 영문 / 번호"
    move_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    move_search.text_changed.connect(func(_text: String): _filter_moves())
    search_row.add_child(move_search)
    type_filter.add_item("모든 타입", 0)
    for entry: Dictionary in catalog.types:
        type_filter.add_item(entry["name"])
    type_filter.item_selected.connect(func(_index: int): _filter_moves())
    search_row.add_child(type_filter)
    parent.add_child(search_row)
    move_list.custom_minimum_size.y = 86
    move_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    move_list.item_selected.connect(_move_selected)
    parent.add_child(move_list)
    move_description.add_theme_font_size_override("font_size", 12)
    move_description.add_theme_color_override("font_color", MUTED)
    move_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    parent.add_child(move_description)
    var actions := HBoxContainer.new()
    parent.add_child(actions)
    play_button.text = "▶  기술 이펙트 재생"
    play_button.custom_minimum_size = Vector2(220, 40)
    play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    play_button.pressed.connect(play_selected)
    actions.add_child(play_button)
    repeat.text = "반복"
    actions.add_child(repeat)
    actions.add_child(_label("속도", 12, MUTED))
    var speed := OptionButton.new()
    for value: String in ["0.5×", "1×", "2×"]:
        speed.add_item(value)
    speed.selected = 1
    speed.item_selected.connect(func(index: int): stage.canvas.effect.speed = [0.5, 1.0, 2.0][index])
    actions.add_child(speed)

func _build_inspector(body: HBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = 244
    body.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    column.add_child(_label("지역 출현 포켓몬", 18, ACCENT))
    column.add_child(_label("선택하면 상대 스프라이트로 표시", 11, MUTED))
    encounter_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    encounter_note.custom_minimum_size.x = 222
    encounter_note.add_theme_font_size_override("font_size", 12)
    encounter_note.add_theme_color_override("font_color", MUTED)
    column.add_child(encounter_note)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    encounter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    encounter_list.add_theme_constant_override("separation", 5)
    scroll.add_child(encounter_list)
    column.add_child(HSeparator.new())
    column.add_child(_label("지속 상태 이펙트", 15, TEXT))
    status_select.add_item("상태 없음")
    for i in range(1, STATUS_KEYS.size()):
        status_select.add_item(VisualCatalog.EFFECT_NAMES[STATUS_KEYS[i]])
    status_select.item_selected.connect(func(index: int):
        stage.canvas.status = STATUS_KEYS[index]
        stage.canvas.status_on_self = false)
    column.add_child(status_select)
    var clear := Button.new()
    clear.text = "연출 초기화"
    clear.pressed.connect(_clear)
    column.add_child(clear)
    column.add_child(_label("1세대 기술 165종 · 연출 샘플\n1920 × 1080 / 도트 에셋", 11, MUTED))
    var battle_link := Button.new()
    battle_link.text = "전투 UI로 돌아가기 · F2"
    battle_link.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_preview.tscn"))
    column.add_child(battle_link)

func select_biome(index: int) -> void:
    biome_index = posmod(index, catalog.biomes.size())
    var biome: Dictionary = catalog.biomes[biome_index]
    var color := VisualCatalog.type_color(biome["type"])
    biome_title.text = "%s  ·  %s" % [biome["name"], catalog.type_name(biome["type"])]
    biome_title.add_theme_color_override("font_color", color)
    biome_description.text = biome["description"]
    stage.canvas.background = VisualCatalog.biome_texture(biome)
    _clear()
    for i in biome_buttons.size():
        biome_buttons[i].set_pressed_no_signal(i == biome_index)
    encounter_note.text = biome["encounter_note"]
    for child in encounter_list.get_children():
        encounter_list.remove_child(child)
        child.queue_free()
    encounter_buttons.clear()
    var tier_labels := {"common": "자주", "uncommon": "가끔", "rare": "희귀"}
    for entry: Dictionary in biome["encounters"]:
        var id: int = int(entry["pokemon_id"])
        var button := Button.new()
        button.text = "%s   · %s" % [catalog.species(id)["name"], tier_labels[entry["tier"]]]
        button.icon = load(VisualCatalog.sprite_path(id))
        button.expand_icon = true
        button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_constant_override("icon_max_width", 36)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size", 12)
        button.custom_minimum_size.y = 44
        button.tooltip_text = "#%03d · %s" % [id, _species_types(id)]
        button.pressed.connect(func():
            target_id = id
            target_select.select(id - 1)
            _update_species())
        encounter_list.add_child(button)
        encounter_buttons.append(button)
    if not biome["landmarks"].is_empty():
        var names := PackedStringArray()
        for entry: Dictionary in biome["landmarks"]:
            names.append(catalog.species(int(entry["pokemon_id"]))["name"])
        var note := _label("별도 이벤트 후보\n" + " · ".join(names), 11, Color("c9b28b"))
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        encounter_list.add_child(note)
    target_id = int(biome["encounters"][0]["pokemon_id"])
    target_select.select(target_id - 1)
    _update_species()

func _species_types(id: int) -> String:
    var names := PackedStringArray()
    for key: String in catalog.species(id)["types"]:
        names.append(catalog.type_name(key))
    return " / ".join(names)

func _update_species() -> void:
    stage.canvas.set_species(source_id, target_id, catalog)
    status_select.select(0)

func _filter_moves() -> void:
    var selected_id := int(selected_move.get("id", 52))
    filtered_moves.clear()
    move_list.clear()
    var query := move_search.text.strip_edges().to_lower()
    var type_key := ""
    if type_filter.selected > 0:
        type_key = catalog.types[type_filter.selected - 1]["key"]
    for entry: Dictionary in catalog.moves:
        if not type_key.is_empty() and entry["type"] != type_key:
            continue
        var haystack := ("%s %s %d" % [entry["name"], entry["key"], int(entry["id"])]).to_lower()
        if not query.is_empty() and not query in haystack:
            continue
        filtered_moves.append(entry)
        move_list.add_item("%s   ·   %s" % [entry["name"], catalog.type_name(entry["type"])])
        move_list.set_item_custom_fg_color(move_list.item_count - 1, VisualCatalog.type_color(entry["type"]))
    play_button.disabled = filtered_moves.is_empty()
    if filtered_moves.is_empty():
        selected_move = {}
        move_description.text = "일치하는 기술이 없습니다."
        return
    var index := 0
    for i in filtered_moves.size():
        if int(filtered_moves[i]["id"]) == selected_id:
            index = i
    move_list.select(index)
    _move_selected(index)

func select_move(id: int) -> void:
    for i in filtered_moves.size():
        if int(filtered_moves[i]["id"]) == id:
            move_list.select(i)
            move_list.ensure_current_is_visible()
            _move_selected(i)
            return

func _move_selected(index: int) -> void:
    selected_move = filtered_moves[index]
    var profile: Dictionary = selected_move["vfx"]
    var target_name := {"self": "사용자", "opponent": "상대", "field": "필드"}
    var description := "%s  ·  %s  ·  대상: %s" % [selected_move["name"], VisualCatalog.EFFECT_NAMES[profile["primary"]], target_name[profile["target"]]]
    if not profile["secondary"].is_empty():
        description += "  ·  %s 부가 연출" % VisualCatalog.EFFECT_NAMES[profile["secondary"]]
    move_description.text = description

func play_selected() -> void:
    if selected_move.is_empty():
        return
    stage.canvas.status = ""
    status_select.select(0)
    stage.canvas.effect.play(selected_move, stage.canvas.source_anchor, stage.canvas.target_anchor)

func _clear() -> void:
    stage.canvas.clear_effects()
    status_select.select(0)
    _repeat_delay = 0

func _effect_finished(_move: Dictionary) -> void:
    if repeat.button_pressed:
        _repeat_delay = 0.7

func _process(delta: float) -> void:
    if _repeat_delay > 0:
        _repeat_delay -= delta
        if _repeat_delay <= 0 and repeat.button_pressed:
            play_selected()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if move_search.has_focus():
            return
        match event.keycode:
            KEY_F2:
                get_tree().change_scene_to_file("res://scenes/battle_preview.tscn")
            KEY_SPACE:
                play_selected()
                get_viewport().set_input_as_handled()
            KEY_LEFT:
                select_biome(biome_index - 1)
            KEY_RIGHT:
                select_biome(biome_index + 1)
            KEY_ESCAPE:
                repeat.button_pressed = false
                _clear()

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label
