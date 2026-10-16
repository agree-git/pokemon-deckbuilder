class_name LearningComparisonPanel
extends Control
const W = preload("res://scripts/ui/combat_widgets.gd")
signal closed
signal slot_selected(slot: int)
signal accepted(slot: int)
var journey: TacticalJourney
var selected_slot := 0
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 95
    refresh()
func select_slot(slot: int) -> void:
    if journey.learning_preview(slot).is_empty(): return
    selected_slot = slot
    slot_selected.emit(slot)
    refresh()
func refresh() -> void:
    W.clear(self)
    var comparison := LearningComparison.describe(journey,selected_slot)
    if comparison.is_empty():
        closed.emit()
        return
    var change: Dictionary = comparison["change"]
    var pokemon: BattlePokemon = change["pokemon"]
    var overlay := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.86),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(320,60,1280,960),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"기술 교체 비교 · "+pokemon.display_name,Rect2(36,18,1120,44),28,W.GOLD)
    W.icon_button(panel,"close",Rect2(1196,20,48,48),func(): closed.emit(),"닫기 · Esc")
    for i in pokemon.learned_skills.size():
        var button := W.button(panel,Rect2(36+i*303,82,288,54),select_slot.bind(i),"QWER"[i]+" · "+str(TacticalMoves.definition(pokemon.learned_skills[i])["name"]))
        button.name = "ComparisonSlot_%d" % i
        if i == selected_slot: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    W.label(panel,"현재 · %s · %d장" % [TacticalMoves.definition(change["previous"])["name"],comparison["before_cards"].size()],Rect2(36,158,580,38),22)
    W.label(panel,"교체 후 · %s · %d장" % [change["incoming"]["name"],comparison["after_cards"].size()],Rect2(664,158,580,38),22,W.GOLD)
    _cards(panel,comparison["before_cards"],Rect2(36,202,580,322),"ComparisonBefore")
    _cards(panel,comparison["after_cards"],Rect2(664,202,580,322),"ComparisonAfter")
    var note := "덱 %d → %d장 · " % [change["before"],change["after"]]+("새 기본 카드 1장 추가" if change["copies"] == 0 else "기존 사본 %d장 교체 · 강화 유지" % change["copies"])
    W.label(panel,note,Rect2(36,540,1208,38),22,W.GOLD).name = "ComparisonDeckSummary"
    W.label(panel,"다음 전투 없음" if comparison["target"].is_empty() else "다음 전투 · "+str(comparison["target"]["title"]),Rect2(36,592,1208,32),20)
    for i in comparison["coverage"].size():
        var row: Dictionary = comparison["coverage"][i]
        var foe: Dictionary = row["opponent"]
        var cell := W.panel(panel,Rect2(36+i*201,636,188,174),Color("20383e"),Color("405960"))
        W.sprite(cell,int(foe["id"]),Rect2(70,4,48,48))
        W.label(cell,foe["name"],Rect2(4,52,180,28),16,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        for k in 3:
            var key: String = ["attack","strong","conditional"][k]
            var values: Array = row[key]
            var color := Color("a4d6b1") if values[1] > values[0] else (Color("e8a38d") if values[1] < values[0] else W.MUTED)
            W.label(cell,"%s %d → %d" % [["공격","약점","지속·조건"][k],values[0],values[1]],Rect2(6,84+k*27,176,26),16,color,HORIZONTAL_ALIGNMENT_CENTER).name = "Comparison_%s_%d" % [key,i]
    var scope := "현재 파티·살아있는 동료·이번 선택 한 건의 덱 상성 비교입니다. 피해량·승률 예측은 아닙니다."
    if not pokemon.alive(): scope += "\n학습 중인 동료가 기절해 해당 기술은 집계에서 제외합니다. 회복 후 사용할 수 있습니다."
    W.label(panel,scope,Rect2(36,824,1208,48),16,W.MUTED)
    W.button(panel,Rect2(100,888,460,56),func(): closed.emit(),"목록으로").name = "ComparisonCancel"
    W.button(panel,Rect2(720,888,460,56),func(): accepted.emit(selected_slot),"선택한 기술 대신 배우기").name = "ComparisonConfirm"
    UiMotion.appear(self)
func _cards(parent: Control, views: Array, rect: Rect2, node_name: String) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = node_name
    scroll.position = rect.position
    scroll.size = rect.size
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    parent.add_child(scroll)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",14)
    scroll.add_child(row)
    var stacks := CardStacks.group(views)
    for i in stacks.size():
        var view: Dictionary = stacks[i]["view"]
        var face := CardStackView.new()
        face.name = node_name+"Card_%d" % i
        face.key = view["key"]
        face.definition = view
        face.stack_count = stacks[i]["count"]
        row.add_child(face)
    if views.is_empty():
        var empty := W.label(row,"덱에 사본이 없습니다.",Rect2(Vector2.ZERO,rect.size),22,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        empty.name = node_name+"Empty"
        empty.custom_minimum_size = rect.size
