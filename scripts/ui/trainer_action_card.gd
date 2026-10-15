class_name TrainerActionCard
extends Button
## Persistent hand slot: hover moves the artwork inside a stable input envelope.
const W = preload("res://scripts/ui/combat_widgets.gd")
const FACE_SIZE := Vector2(186,266)
const SLOT_SIZE := Vector2(202,312)
const HOME := Vector2(8,40)
var uid := 0
var key := "analysis"
var face: Panel
var cost_label: Label
var _hovered := false
var _available := true
var _dealing := false
func _ready() -> void:
    custom_minimum_size = SLOT_SIZE
    size = SLOT_SIZE
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for state: String in ["normal","hover","pressed","disabled","focus"]:
        add_theme_stylebox_override(state,StyleBoxEmpty.new())
    var accent: Color = TrainerCardArt.COLORS[key]
    W.panel(self,Rect2(HOME+Vector2(3,4),FACE_SIZE),Color(0,0,0,0.34),Color.TRANSPARENT,11)
    face = W.panel(self,Rect2(HOME,FACE_SIZE),Color("172c34"),accent,11)
    face.pivot_offset = Vector2(FACE_SIZE.x/2,FACE_SIZE.y)
    W.panel(face,Rect2(4,4,178,258),Color.TRANSPARENT,accent.darkened(0.48),8)
    W.panel(face,Rect2(9,52,168,100),accent.darkened(0.72),accent.darkened(0.25),0)
    var art := TrainerCardArt.new()
    art.card_key = key
    art.position = Vector2(9,54)
    art.size = Vector2(168,96)
    face.add_child(art)
    W.label(face,TacticalContent.CARDS[key]["name"],Rect2(43,8,132,34),19,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(-2,-2,42,42),Color("2b3e43"),accent,21)
    cost_label = W.label(face,"",Rect2(-2,-2,42,42),25,Color("f1d58c"),HORIZONTAL_ALIGNMENT_CENTER)
    W.label(face,"상태" if key == "injury" else "트레이너 · 지시",Rect2(9,154,168,24),12,accent,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(9,183,168,62),Color("e6dcc1"),Color("a99b7c"),3)
    var summaries := {"analysis":"다음 공격에\n빈틈 +1","guard":"보호막 +6","focus":"카드 2장 드로우\n사용 후 소진","rally":"다음 공격의\n기본 피해 +4","counter":"강공격: 빈틈 +1\n그 외: 보호막 +4","injury":"효과 없음"}
    W.label(face,summaries[key],Rect2(14,185,158,58),16,Color("273936"),HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(14,253,158,3),accent,Color.TRANSPARENT,0)
    mouse_entered.connect(func(): _set_hover(true))
    mouse_exited.connect(func(): _set_hover(false))
func update_card(view: Dictionary,reason: String,locked: bool) -> void:
    UiMotion.text(cost_label,str(view["cost"]))
    tooltip_text = view["name"]+"\n"+view["description"]+("\n"+reason if not reason.is_empty() else "")
    _available = not locked and reason.is_empty()
    disabled = not _available
    face.modulate = Color.WHITE if _available else Color(0.65,0.71,0.72)
    if not _available: _set_hover(false)
func _has_point(point: Vector2) -> bool:
    if not is_instance_valid(face) or face.self_modulate.a < 0.35: return false
    # Keep the resting shadow clickable while the card lifts under the pointer.
    return Rect2(HOME,FACE_SIZE).has_point(point) or Rect2(Vector2.ZERO,FACE_SIZE).has_point(face.get_transform().affine_inverse()*point)
func visible_point(vertical := 0.5) -> Vector2:
    return face.get_transform()*Vector2(FACE_SIZE.x/2,lerpf(3,FACE_SIZE.y-3,vertical))
func _set_hover(value: bool) -> void:
    _hovered = value and _available
    if _dealing: return
    var tween := UiMotion.begin(self,"face",true)
    tween.tween_property(face,"position",HOME+Vector2(0,-24 if _hovered else 0),0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(face,"scale",Vector2.ONE*(1.025 if _hovered else 1.0),0.14)
    face.add_theme_stylebox_override("panel",W.box(Color("243b40") if _hovered else Color("172c34"),Color("f1d58c") if _hovered else TrainerCardArt.COLORS[key],11))
func deal(delay := 0.0) -> void:
    if not is_inside_tree(): return
    _dealing = true
    face.position = HOME+Vector2(-18,52)
    face.scale = Vector2.ONE*0.94
    face.self_modulate.a = 0
    var tween := UiMotion.begin(self,"face",true)
    tween.tween_property(face,"position",HOME,0.26).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(face,"scale",Vector2.ONE,0.26).set_delay(delay)
    tween.tween_property(face,"self_modulate:a",1.0,0.18).set_delay(delay)
    tween.chain().tween_callback(func():
        _dealing = false
        _set_hover(_hovered))
func copy_face(parent: Node) -> Control:
    var copy := face.duplicate() as Control
    copy.pivot_offset = Vector2.ZERO
    copy.position = face.get_global_transform_with_canvas().origin
    copy.scale = face.scale
    copy.rotation = face.rotation
    copy.self_modulate.a = 1
    parent.add_child(copy)
    return copy
