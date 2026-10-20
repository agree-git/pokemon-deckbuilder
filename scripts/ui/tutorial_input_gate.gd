extends Control
## A pointer shield with live holes for only the current lesson controls.
var targets: Callable
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 220
func _has_point(point: Vector2) -> bool:
    if not targets.is_valid(): return true
    var world := get_global_transform()*point
    for target: Control in targets.call():
        if not is_instance_valid(target) or not target.is_visible_in_tree(): continue
        var rect := target.get_global_rect()
        var ancestor := target.get_parent()
        while ancestor is Control:
            if ancestor.clip_contents: rect = rect.intersection(ancestor.get_global_rect())
            ancestor = ancestor.get_parent()
        if not rect.has_point(world): continue
        if target.has_method("_has_point"):
            if not target.call("_has_point",target.get_global_transform().affine_inverse()*world): continue
        return false
    return true
func _gui_input(_event: InputEvent) -> void:
    accept_event()
