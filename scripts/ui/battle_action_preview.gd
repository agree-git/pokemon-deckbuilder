class_name BattleActionPreview
extends Panel
## Temporary feedback between the combatants and the hand. It never handles input.
const W = preload("res://scripts/ui/combat_widgets.gd")
var title: Label
var target: RichTextLabel
var actor: RichTextLabel
var resources: RichTextLabel
var capture: Label
var ally_forecast: ColorRect
var enemy_forecast: ColorRect
var result: Dictionary = {}

func _ready() -> void:
    position = Vector2(770,568)
    size = Vector2(380,150)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel",W.box(Color(0.035,0.075,0.095,0.96),Color("8da9a6"),10))
    title = W.label(self,"",Rect2(14,6,352,26),16,W.GOLD)
    target = CardEffectText.label(self,Rect2(14,34,352,25),16)
    actor = CardEffectText.label(self,Rect2(14,60,352,25),16)
    resources = CardEffectText.label(self,Rect2(14,86,352,25),16,W.MUTED)
    capture = W.label(self,"",Rect2(14,112,352,26),16,W.GOLD)
    hide()

func bind_bars(ally_bar: Control,enemy_bar: Control) -> void:
    ally_forecast = _overlay(ally_bar)
    enemy_forecast = _overlay(enemy_bar)

func _overlay(track: Control) -> ColorRect:
    var node := ColorRect.new()
    node.name = "ActionForecast"
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.z_index = 2
    track.add_child(node)
    node.hide()
    return node

func clear() -> void:
    result = {}
    hide()
    if ally_forecast != null: ally_forecast.hide()
    if enemy_forecast != null: enemy_forecast.hide()

func _bar(overlay: ColorRect,before: Dictionary,after: Dictionary) -> void:
    var previous := int(before["hp"])
    var next := int(after["hp"])
    overlay.visible = next != previous
    var width: float = (overlay.get_parent() as Control).size.x
    var maximum := maxi(1,int(before["max_hp"]))
    overlay.position = Vector2(width*minf(previous,next)/maximum,-2)
    overlay.size = Vector2(width*absf(previous-next)/maximum,11)
    overlay.color = Color("f5ac79") if next < previous else Color("b4f4c5")

func display(value: Dictionary,current_actor_uid: int) -> void:
    clear()
    if not str(value.get("reason","")).is_empty() or value.is_empty(): return
    result = value
    var before: Dictionary = value["target_before"]
    var after: Dictionary = value["target_after"]
    var own_before: Dictionary = value["actor_before"]
    var own_after: Dictionary = value["actor_after"]
    title.text = "사용 직후 · "+str(value["name"])+( " · 자동 교대" if value["switched"] else "")
    var target_change := _vitals(before,after)
    var actor_change := _vitals(own_before,own_after)
    target.text = "상대  "+target_change
    actor.text = str(own_after["name"])+"  "+actor_change
    target.visible = not target_change.is_empty()
    actor.visible = not actor_change.is_empty()
    var intent: Dictionary = value["intent"]
    var next := "다음 상대 " if value["enemy_changed"] else "다음 "
    var incoming := "전투 승리" if value["won"] else (next+CardEffectText.icon("attack")+str(int(intent["value"])) if intent["kind"] in ["attack","charge","barrage"] else ("상대 교대" if value["enemy_changed"] else ""))
    if intent.get("asleep",false) and not value["won"]: incoming = "상대 "+CardEffectText.icon("sleep")
    var energy_change := int(value["energy_after"])-int(value["energy_before"])
    resources.text = (CardEffectText.icon("energy")+" "+_signed(energy_change) if energy_change != 0 else "")
    if not incoming.is_empty(): resources.text += (" · " if not resources.text.is_empty() else "")+incoming
    resources.visible = not resources.text.is_empty()
    capture.visible = value["capture_shown"]
    capture.text = "포획 가능 · 사용 후 C" if value["capture_reason"] == "" else str(value["capture_reason"])
    var row_y := 34.0
    for line: Control in [target,actor,resources,capture]:
        line.position.y = row_y
        if line.visible: row_y += 26
    _bar(enemy_forecast,before,after)
    if int(own_after["uid"]) == current_actor_uid: _bar(ally_forecast,own_before,own_after)
    show()

func _signed(value: int) -> String:
    return ("+" if value > 0 else "−")+str(absi(value))

func _vitals(before: Dictionary,after: Dictionary) -> String:
    var parts: Array[String] = []
    for field: String in ["hp","block"]:
        var change := int(after[field])-int(before[field])
        if change == 0: continue
        parts.append(CardEffectText.icon("heal" if field == "hp" else "shield")+" "+_signed(change))
    return "   ".join(parts)
