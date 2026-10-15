class_name TrainerActionCard
extends Button
## A stable input envelope with a moving face for all three card categories.
const W = preload("res://scripts/ui/combat_widgets.gd")
const FACE_SIZE := Vector2(186,266)
const SLOT_SIZE := Vector2(202,312)
const HOME := Vector2(8,40)
const COLORS := {"technique":Color("a4d6b1"),"tool":Color("e5c280"),"trainer":Color("aebedd"),"status":Color("c59ba7")}
var uid := 0
var key := "analysis"
var definition: Dictionary = {}
var face: Panel
var cost_label: Label
var title_label: Label
var effect_label: Label
var category_label: Label
var _accent := Color("aebedd")
var _hovered := false
var _available := true
var _dealing := false
func _ready() -> void:
    if definition.is_empty(): definition = TacticalContent.definition(BattleCardInstance.new(uid,key,0))
    custom_minimum_size = SLOT_SIZE
    size = SLOT_SIZE
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for state: String in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    _accent = COLORS.get(definition.get("category","trainer"),COLORS["trainer"])
    W.panel(self,Rect2(HOME+Vector2(3,4),FACE_SIZE),Color(0,0,0,0.34),Color.TRANSPARENT,11)
    face = W.panel(self,Rect2(HOME,FACE_SIZE),Color("172c34"),_accent,11)
    face.pivot_offset = Vector2(FACE_SIZE.x/2,FACE_SIZE.y)
    W.panel(face,Rect2(4,4,178,258),Color.TRANSPARENT,_accent.darkened(0.48),8)
    W.panel(face,Rect2(9,52,168,100),_accent.darkened(0.72),_accent.darkened(0.25),0)
    if int(definition.get("species_id",0)) > 0:
        W.sprite(face,int(definition["species_id"]),Rect2(45,54,96,96))
        W.icon(face,definition.get("type","normal"),Rect2(140,118,24,24))
    else:
        var art := TrainerCardArt.new()
        art.card_key = key
        art.position = Vector2(9,54)
        art.size = Vector2(168,96)
        face.add_child(art)
    title_label = W.label(face,"",Rect2(43,8,132,34),17,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(-2,-2,42,42),Color("2b3e43"),_accent,21)
    cost_label = W.label(face,"",Rect2(-2,-2,42,42),25,Color("f1d58c"),HORIZONTAL_ALIGNMENT_CENTER)
    category_label = W.label(face,"",Rect2(9,154,168,24),12,_accent,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(9,183,168,62),Color("e6dcc1"),Color("a99b7c"),3)
    effect_label = W.label(face,"",Rect2(14,185,158,58),13,Color("273936"),HORIZONTAL_ALIGNMENT_CENTER)
    effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    W.panel(face,Rect2(14,253,158,3),_accent,Color.TRANSPARENT,0)
    mouse_entered.connect(func(): _set_hover(true))
    mouse_exited.connect(func(): _set_hover(false))
    update_card(definition,"",false)
func update_card(view: Dictionary,reason: String,locked: bool) -> void:
    definition = view
    UiMotion.text(cost_label,str(view["cost"]))
    title_label.text = view["name"]
    var category: String = view.get("category","trainer")
    var caption: String = {"technique":"기술","tool":"도구","trainer":"트레이너","status":"상태"}.get(category,"트레이너")
    if category == "technique": caption += " · "+str(view.get("owner_name",""))
    if view.get("switches",false): caption += " ↔"
    if view.has("power"): caption += " · 지속"
    if view.get("retained",false): caption += " · 보존"
    category_label.text = caption
    var description: String = view["description"]
    if view.has("preview_damage"): description = description.replace("피해 %d" % int(view["damage"]),"피해 %d" % int(view["preview_damage"]))
    if view.has("preview_block"): description = description.replace("보호막 %d" % int(view["block"]),"보호막 %d" % int(view["preview_block"]))
    var summaries := {"relay_plan":"기술로 교대 시\n보호막 +3","ace_plan":"출전 유지 시 다음 턴\n공격 +2","tool_plan":"도구 사용 시\n보호막 +5","status_cash":"화상·독·씨앗 소비\n남은 횟수 ×4 피해"}
    effect_label.text = summaries.get(key,description)
    tooltip_text = str(view["name"])+"\n"+caption+"\n"+description+("\n자동 교대 후 사용 · 추가 교대 비용 없음" if view.get("switches",false) else "")+("\n"+reason if not reason.is_empty() else "")
    _available = not locked and reason.is_empty()
    disabled = not _available
    face.modulate = Color.WHITE if _available else Color(0.65,0.71,0.72)
    if not _available: _set_hover(false)
func _has_point(point: Vector2) -> bool:
    if not is_instance_valid(face) or face.self_modulate.a < 0.35: return false
    return Rect2(HOME,FACE_SIZE).has_point(point) or Rect2(Vector2.ZERO,FACE_SIZE).has_point(face.get_transform().affine_inverse()*point)
func visible_point(vertical := 0.5) -> Vector2:
    return face.get_transform()*Vector2(FACE_SIZE.x/2,lerpf(3,FACE_SIZE.y-3,vertical))
func _set_hover(value: bool) -> void:
    _hovered = value and _available
    if _dealing: return
    var tween := UiMotion.begin(self,"face",true)
    tween.tween_property(face,"position",HOME+Vector2(0,-24 if _hovered else 0),0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(face,"scale",Vector2.ONE*(1.025 if _hovered else 1.0),0.14)
    face.add_theme_stylebox_override("panel",W.box(Color("243b40") if _hovered else Color("172c34"),Color("f1d58c") if _hovered else _accent,11))
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
