extends TextEdit
## A single-line search surface using TextEdit's native CJK composition buffer.
signal query_changed(value: String)
var _last_query := ""
func _ready() -> void:
    wrap_mode = TextEdit.LINE_WRAPPING_NONE
    scroll_fit_content_height = true
    caret_blink = true
    text_changed.connect(_publish_query)
    _publish_query()
func query_text() -> String:
    # Read committed text and the still-composing syllable without modifying either.
    return get_line_with_ime(0)
func _publish_query() -> void:
    # Context-menu paste can bypass key handling; flatten only committed newlines.
    if not has_ime_text() and get_line_count()>1:
        text = text.replace("\r\n"," ").replace("\n"," ").replace("\r"," ")
        set_caret_line(0)
        set_caret_column(text.length())
    var value := query_text()
    if value == _last_query: return
    _last_query = value
    query_changed.emit(value)
func _process(_delta: float) -> void:
    if has_focus(): _publish_query()
func _input(event: InputEvent) -> void:
    if not has_focus() or not event is InputEventKey or not event.pressed: return
    if event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
        # Enter commits Korean composition/search rather than inserting another line.
        if has_ime_text(): apply_ime()
        get_viewport().set_input_as_handled()
        _publish_query.call_deferred()
    elif ((event.ctrl_pressed or event.meta_pressed) and event.keycode==KEY_V) or (event.shift_pressed and event.keycode==KEY_INSERT):
        if has_ime_text(): apply_ime()
        var pasted := DisplayServer.clipboard_get().replace("\r\n"," ").replace("\n"," ").replace("\r"," ")
        insert_text_at_caret(pasted)
        get_viewport().set_input_as_handled()
        _publish_query.call_deferred()
