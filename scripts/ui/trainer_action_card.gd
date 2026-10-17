class_name TrainerActionCard
extends Button
signal hand_hover_changed(card: TrainerActionCard,value: bool)
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
var effect_label: RichTextLabel
var category_label: Label
var _accent := Color("aebedd")
var _hovered := false
var _available := true
var _dealing := false
var _locked := false
# The next card owns its exposed strip. Raising a face must not hide that input.
var hand_exposed_width := -1.0
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
    var art_frame := W.panel(face,Rect2(9,52,168,60),_accent.darkened(0.72),_accent.darkened(0.25),0)
    art_frame.clip_contents = true
    if int(definition.get("species_id",0)) > 0:
        W.sprite(art_frame,int(definition["species_id"]),Rect2(36,0,96,60))
        W.icon(art_frame,definition.get("type","normal"),Rect2(138,30,24,24))
    else:
        var art := TrainerCardArt.new()
        art.card_key = key
        # Preserve the full central emblem while cropping decorative scenery.
        art.position = Vector2(0,-8)
        art.size = Vector2(168,96)
        art_frame.add_child(art)
    title_label = W.label(face,"",Rect2(43,8,132,34),17,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(-2,-2,42,42),Color("2b3e43"),_accent,21)
    cost_label = W.label(face,"",Rect2(-2,-2,42,42),25,Color("f1d58c"),HORIZONTAL_ALIGNMENT_CENTER)
    category_label = W.label(face,"",Rect2(9,113,168,23),12,_accent,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(face,Rect2(9,138,168,110),Color("e6dcc1"),Color("a99b7c"),3)
    effect_label = CardEffectText.label(face,Rect2(12,139,162,108),14,Color("273936"))
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
    if view.has("preview_damage") and not view.has("shield_attack"):
        var original := "위력 %d · %s" % [view["move_power"],"물리" if view.get("damage_class","") == "physical" else "특수"] if view.has("move_power") else "피해 %d" % int(view["damage"])
        description = description.replace(original,"피해 %d" % int(view["preview_damage"]))
    if view.has("preview_heal"): description = description.replace("회복 %d" % int(view["heal"]),"회복 %d" % int(view["preview_heal"]))
    if view.has("preview_block"): description = description.replace("보호막 %d" % int(view["block"]),"보호막 %d" % int(view["preview_block"]))
    if view.has("expose"): description = description.replace("방어 약화 %d회" % int(view["expose"]),"방어 약화 3턴")
    CardEffectText.apply(effect_label,view)
    tooltip_text = ("위력 %d · %s\n" % [view["move_power"],"물리" if view.get("damage_class","") == "physical" else "특수"] if view.has("move_power") else "")+str(view["name"])+"\n"+caption+"\n"+description+("\n자동 교대 후 사용 · 추가 교대 비용 없음" if view.get("switches",false) else "")+("\n"+reason if not reason.is_empty() else "")
    if view.get("exhaust",false): tooltip_text += "\n소진: 사용 후 이번 전투에서 제외됩니다."
    if int(view.get("core_discount",0)) > 0: tooltip_text += "\n고정 조준경 · 턴 시작 출전 멤버의 첫 기술 비용 -1"
    if int(view.get("tool_discount",0)) > 0: tooltip_text += "\n정밀 공구 · 첫 도구 카드 비용 -1"
    _available = not locked and reason.is_empty()
    _locked = locked
    disabled = not _available
    face.modulate = Color.WHITE if _available else Color(0.65,0.71,0.72)
    if locked: _set_hover(false)
func _has_point(point: Vector2) -> bool:
    if not is_instance_valid(face) or face.self_modulate.a < 0.35 or self_modulate.a < 0.35: return false
    var exposed := Vector2(minf(FACE_SIZE.x,hand_exposed_width) if hand_exposed_width >= 0 else FACE_SIZE.x,FACE_SIZE.y)
    return Rect2(HOME,exposed).has_point(point) or ((_hovered or hand_exposed_width < 0) and Rect2(Vector2.ZERO,FACE_SIZE).has_point(face.get_transform().affine_inverse()*point))
func visible_point(vertical := 0.5) -> Vector2:
    if hand_exposed_width >= 0 and not _hovered:
        return HOME+Vector2(minf(FACE_SIZE.x,hand_exposed_width)/2,lerpf(3,FACE_SIZE.y-3,vertical))
    return face.get_transform()*Vector2(FACE_SIZE.x/2,lerpf(3,FACE_SIZE.y-3,vertical))
func _set_hover(value: bool,force := false) -> void:
    var next := value and not _locked
    if _hovered == next and not _dealing and not force: return
    _hovered = next
    z_index = 20 if _hovered else 0
    hand_hover_changed.emit(self,_hovered)
    if _dealing: return
    var lift := 34 if hand_exposed_width >= 0 else 24
    var zoom := 1.10 if hand_exposed_width >= 0 else 1.025
    var tween := UiMotion.begin(self,"face",true)
    tween.tween_property(face,"position",HOME+Vector2(0,-lift if _hovered else 0),0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(face,"scale",Vector2.ONE*(zoom if _hovered else 1.0),0.14)
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
        _set_hover(_hovered,true))
func copy_face(parent: Node) -> Control:
    var copy := face.duplicate() as Control
    copy.pivot_offset = Vector2.ZERO
    copy.position = face.get_global_transform_with_canvas().origin
    copy.scale = face.scale
    copy.rotation = face.rotation
    copy.self_modulate.a = 1
    parent.add_child(copy)
    return copy
