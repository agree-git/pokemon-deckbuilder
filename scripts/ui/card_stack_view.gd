class_name CardStackView
extends TrainerActionCard
## Passive by default, with bounded depth and an exact copy count.
var stack_count := 1
var count_label: Label
var backs: Array[Panel] = []
func _ready() -> void:
    var accent: Color = COLORS.get(definition.get("category","trainer"),COLORS["trainer"])
    if stack_count > 1:
        var offsets: Array = [Vector2(6,3)] if stack_count == 2 else [Vector2(8,4),Vector2(4,2)]
        for offset: Vector2 in offsets:
            backs.append(W.panel(self,Rect2(HOME+offset,FACE_SIZE),Color("20383e"),accent.darkened(0.25),11))
    super._ready()
    # Browsing faces stay fully readable and never play cards.
    disabled = true
    mouse_default_cursor_shape = Control.CURSOR_ARROW
    if stack_count > 1:
        var badge := W.panel(self,Rect2(138,5,64,30),Color("29443f"),W.GOLD,8)
        badge.name = "StackBadge"
        count_label = W.label(badge,"×%d" % stack_count,Rect2(0,0,64,30),20,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
        count_label.name = "StackCount"
        tooltip_text += "\n같은 카드 %d장" % stack_count
func allow_selection(reason: String) -> void:
    update_card(definition,reason,false)
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reason.is_empty() else Control.CURSOR_ARROW
    if stack_count > 1: tooltip_text += "\n같은 카드 %d장 · 선택하면 1장만 제거" % stack_count
