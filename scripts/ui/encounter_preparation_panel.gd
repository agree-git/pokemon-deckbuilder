class_name EncounterPreparationPanel
extends Control
const W = preload("res://scripts/ui/combat_widgets.gd")
signal closed
var journey: TacticalJourney
var selected := 0
var group := "attack"
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 90
    refresh()
func refresh() -> void:
    W.clear(self)
    var preview := EncounterPreparation.describe(journey)
    if preview.get("hidden",false):
        _unknown(preview)
        return
    if preview.is_empty() or preview["enemies"].is_empty():
        closed.emit()
        return
    selected = clampi(selected,0,preview["enemies"].size()-1)
    var row: Dictionary = preview["enemies"][selected]
    var groups: Dictionary = row["groups"]
    var overlay := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.86),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(340,64,1240,952),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"다음 전투 준비",Rect2(36,20,1050,44),29,W.GOLD)
    W.label(panel,preview["title"],Rect2(36,70,1100,36),20)
    W.icon_button(panel,"close",Rect2(1156,24,48,48),func(): closed.emit(),"닫기 · Esc")
    for i in preview["enemies"].size():
        var opponent: Dictionary = preview["enemies"][i]["opponent"]
        var button := W.button(panel,W.row_rect(Rect2(36,124,minf(1168,preview["enemies"].size()*180+(preview["enemies"].size()-1)*24),126),i,preview["enemies"].size()),func():
            selected = i
            refresh())
        button.name = "PreparationEnemy_%d" % i
        if i == selected: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
        W.sprite(button,int(opponent["id"]),Rect2((button.size.x-64)/2,6,64,64))
        W.fit_label(W.label(button,"%s · Lv.%d" % [opponent["name"],opponent["level"]],Rect2(6,70,button.size.x-12,28),16,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER),13)
        var types: Array = opponent.get("types",[opponent["type"]])
        for k in types.size(): W.icon(button,types[k],Rect2(button.size.x/2-types.size()*12+k*24,102,20,20))
    var attacks: int = groups["attack"].size()
    var message := "통하는 공격 %d장 · 약점 공략 %d장" % [attacks,row["strong"]]
    if not row["living"]: message = "출전 가능한 동료가 없습니다. 휴식·가방으로 회복하세요."
    elif attacks == 0: message = "직접 공격 없음 · 지속·조건부 카드를 확인하세요." if not groups["conditional"].is_empty() else "현재 덱에 이 상대에게 통하는 피해 카드가 없습니다."
    W.label(panel,message,Rect2(36,276,1168,44),23,W.GOLD if attacks > 0 else Color("e8a38d")).name = "PreparationSummary"
    var keys := ["attack","immune","conditional"]
    var titles := ["통하는 공격","타격 무효","지속·조건부"]
    for i in keys.size():
        var key: String = keys[i]
        var button := W.button(panel,W.row_rect(Rect2(36,338,1168,56),i,keys.size()),func():
            group = key
            refresh(),"%s · %d장" % [titles[i],groups[key].size()])
        button.name = "PreparationTab_"+key
        if key == group: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    var scroll := ScrollContainer.new()
    scroll.name = "PreparationCards"
    scroll.position = Vector2(36,418)
    scroll.size = Vector2(1168,332)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation",24)
    scroll.add_child(cards)
    var views: Array[Dictionary] = []
    for entry: Dictionary in groups[group]: views.append(entry["card"])
    var stacks := CardStacks.group(views)
    for i in stacks.size():
        var view: Dictionary = stacks[i]["view"]
        var face := CardStackView.new()
        face.name = "PreparationCard_%d" % i
        face.key = view["key"]
        face.definition = view
        face.stack_count = stacks[i]["count"]
        cards.add_child(face)
        var entry: Dictionary = groups[group].filter(func(item: Dictionary): return item["card"] == view)[0]
        W.label(face,entry["label"],Rect2(0,2,130,30),16,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    if groups[group].is_empty():
        var empty := W.label(cards,"해당 카드가 없습니다.",Rect2(0,0,1168,320),24,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        empty.name = "PreparationEmpty"
        empty.custom_minimum_size = Vector2(1168,320)
    var note := "현재 덱 · 살아있는 동료 기준. 실제 손패·에너지·상태·보호막에 따라 결과가 달라집니다."
    if row["unavailable"] > 0: note += "\n기절한 동료의 기술 %d장은 제외했습니다. 회복 후 다시 확인하세요." % row["unavailable"]
    elif group == "conditional": note += "\n지속 피해는 타격 상성과 별개입니다. 보호막 전환·상태 회수에는 준비가 필요합니다."
    W.label(panel,note,Rect2(36,774,1168,48),17,W.MUTED).name = "PreparationNote"
    W.button(panel,Rect2(400,846,440,58),func(): closed.emit(),"준비로 돌아가기").name = "PreparationClose"
    UiMotion.appear(self)

func _unknown(preview: Dictionary) -> void:
    var overlay := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.86),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(540,260,840,560),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,str(preview["title"]),Rect2(32,30,776,50),30,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(panel,"?",Rect2(32,105,776,170),128,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(panel,"조우 전에는 상대 정보를 알 수 없습니다.\n동료와 덱을 정비하고 흔적을 따라가세요.",Rect2(32,300,776,90),24,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER).name = "PreparationUnknown"
    W.button(panel,Rect2(200,446,440,64),func(): closed.emit(),"준비로 돌아가기").name = "PreparationClose"
    UiMotion.appear(self)
