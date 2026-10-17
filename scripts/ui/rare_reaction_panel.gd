class_name RareReactionPanel
extends Control
## Acknowledges the completed choice. Closing this view never changes the journey.
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
var species_id := 0
var event := "joined"
var body: Panel
var quote: Label
var continue_button: Button
var _closed := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 110
    name = "RareReactionPanel"
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.045, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(shade)
    body = W.panel(self, Rect2(500, 235, 920, 610), Color("14282f"), W.GOLD, 14)
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    var catalog := VisualCatalog.new()
    var pokemon_name: String = catalog.species(species_id)["name"]
    W.label(body, pokemon_name + (" · 원정대 합류" if event == "joined" else " · 다시 자연으로"), Rect2(40, 30, 840, 60), 32, W.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    W.sprite(body, species_id, Rect2(366, 112, 188, 188)).name = "ReactionPortrait"
    quote = W.label(body, RareCaptureReaction.line(species_id, event), Rect2(60, 324, 800, 80), 25, W.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
    quote.name = "RareReactionQuote"
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var basic: Dictionary = catalog.species(catalog.starter_species_id(species_id))
    W.label(body, "스타팅 해금 · " + str(basic["name"]) + "\n합류·방출과 관계없이 해금은 유지됩니다.", Rect2(60, 420, 800, 62), 19, W.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
    continue_button = W.button(body, Rect2(260, 514, 400, 62), close, "계속 진행")
    continue_button.name = "RareReactionContinue"
    UiMotion.open(self)

func close() -> void:
    if _closed: return
    _closed = true
    closed.emit()

func _input(event_input: InputEvent) -> void:
    if event_input is InputEventKey:
        if event_input.keycode == KEY_F11: return
        get_viewport().set_input_as_handled()
        if event_input.pressed and not event_input.echo and event_input.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: close()
