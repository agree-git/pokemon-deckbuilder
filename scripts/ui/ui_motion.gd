class_name UiMotion
extends RefCounted
## Interruptible presentation tweens shared by the HUD, cards and overlays.
const META := &"ui_motion"
static func combat_speed(node: Node) -> float:
    var preferences := node.get_node_or_null("/root/Preferences")
    return float(preferences.battle_speed) if preferences != null else 1.0
static func combat(node: Node,key: String,parallel := false) -> Tween:
    var tween := begin(node,key,parallel)
    tween.set_speed_scale(combat_speed(node))
    return tween
static func begin(node: Node,key: String,parallel := false) -> Tween:
    var tracks: Dictionary = node.get_meta(META,{})
    if tracks.has(key) and tracks[key].is_valid(): tracks[key].kill()
    var tween := node.create_tween()
    tween.set_parallel(parallel)
    tracks[key] = tween
    node.set_meta(META,tracks)
    return tween
static func bind_button(button: Button) -> void:
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.mouse_entered.connect(func():
        if not button.disabled:
            begin(button,"hover").tween_property(button,"self_modulate",Color(1.16,1.16,1.12),0.10))
    button.mouse_exited.connect(func(): begin(button,"hover").tween_property(button,"self_modulate",Color.WHITE,0.12))
    button.button_down.connect(func():
        BattleSoundCues.play(button,"ui_click")
        button.self_modulate = Color(0.82,0.88,0.88)
        begin(button,"hover").tween_property(button,"self_modulate",Color.WHITE,0.15))
static func pulse(node: Control) -> void:
    node.pivot_offset = node.size/2
    node.scale = Vector2.ONE*1.10
    begin(node,"pulse").tween_property(node,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
static func text(label: Label,content: String) -> void:
    if label.text == content: return
    var had_value := not label.text.is_empty()
    label.text = content
    if had_value: pulse(label)
static func value(node: Node,property: NodePath,target: float,duration := 0.24) -> void:
    var key := "value_"+str(property).replace(":","_")
    var targets: Dictionary = node.get_meta("ui_values",{})
    if targets.get(key,null) == target: return
    targets[key] = target
    node.set_meta("ui_values",targets)
    begin(node,key).tween_property(node,property,target,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
static func appear(node: CanvasItem,delay := 0.0) -> void:
    node.self_modulate.a = 0.15
    begin(node,"appear").tween_property(node,"self_modulate:a",1.0,0.18).set_delay(delay)
static func open(overlay: Control) -> void:
    var body: Control = overlay.get_node("Body")
    var home: Vector2 = body.get_meta("home",body.position)
    body.set_meta("home",home)
    overlay.show()
    overlay.modulate.a = 0
    body.position = home+Vector2(0,14)
    var tween := begin(overlay,"visibility",true)
    tween.tween_property(overlay,"modulate:a",1.0,0.16)
    tween.tween_property(body,"position",home,0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
static func close(overlay: Control,immediate := false) -> void:
    if not overlay.visible: return
    var tween := begin(overlay,"visibility")
    if immediate:
        overlay.hide()
        overlay.modulate.a = 1
        tween.kill()
        return
    tween.tween_property(overlay,"modulate:a",0.0,0.12)
    tween.tween_callback(overlay.hide)
static func finish_tree(node: Node) -> void:
    if not is_instance_valid(node): return
    # Also used by integration tests to complete real tweens without wall-clock sleeps.
    var tracks: Dictionary = node.get_meta(META,{})
    for tween: Tween in tracks.values():
        if tween.is_valid(): tween.custom_step(5.0)
    for child: Node in node.get_children(): finish_tree(child)
