class_name RemovalPreviewPanel
extends Control
const W = preload("res://scripts/ui/combat_widgets.gd")
signal closed
signal accepted
var journey: TacticalJourney
var uid := 0
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 95
    var change := RemovalPreview.describe(journey,uid)
    if change.is_empty():
        closed.emit()
        return
    var shade := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: shade.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.86),Color.TRANSPARENT,0))
    var panel := W.panel(shade,Rect2(320,90,1280,900),Color("14282f"),W.GOLD)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"카드 제거 확인",Rect2(36,18,1120,44),29,W.GOLD)
    W.icon_button(panel,"close",Rect2(1196,20,48,48),func(): closed.emit(),"목록으로 · Esc").name = "RemovalClose"
    W.label(panel,"제거할 카드 · 1장",Rect2(36,80,330,36),21,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    var face := CardStackView.new()
    face.name = "RemovalCard"
    face.key = change["card"]["key"]
    face.definition = change["card"]
    face.position = Vector2(92,104)
    panel.add_child(face)
    W.label(panel,"같은 카드 사본  %d → %d장" % [change["copies_before"],change["copies_after"]],Rect2(400,142,800,46),25).name = "RemovalCopies"
    W.label(panel,"원정 덱  %d → %d장" % [change["before"],change["after"]],Rect2(400,208,800,46),25).name = "RemovalDeck"
    var gold_text := "골드  %d → %d  ·  비용 %d" % [journey.gold,change["gold_after"],change["price"]] if journey.gold >= change["price"] else "골드 %d  ·  비용 %d  ·  부족 %d" % [journey.gold,change["price"],change["price"]-journey.gold]
    W.label(panel,gold_text,Rect2(400,274,800,46),25,W.GOLD).name = "RemovalGold"
    var reason: String = change["reason"]
    W.label(panel,"선택한 사본 1장만 원정 덱에서 제거합니다.\n이번 야영지의 휴식·강화는 계속 이용할 수 있습니다." if reason.is_empty() else reason,Rect2(400,346,800,70),19,W.MUTED if reason.is_empty() else Color("e8a38d")).name = "RemovalReason"
    W.label(panel,"다음 전투 없음" if change["target"].is_empty() else "다음 전투 · "+str(change["target"]["title"]),Rect2(36,486,1208,36),21)
    DeckCoverageCards.draw(panel,change["coverage"],Vector2(36,536),"Removal")
    var lost: Array[String] = []
    for row: Dictionary in change["coverage"]:
        if row["attack"][0] > 0 and row["attack"][1] == 0: lost.append(row["opponent"]["name"])
    W.label(panel,"직접 공격 소실 · "+"·".join(lost) if not lost.is_empty() else "현재 파티의 살아있는 동료와 이번 제거 한 장을 기준으로 비교합니다.",Rect2(36,730,1208,36),20,Color("e8a38d") if not lost.is_empty() else W.MUTED).name = "RemovalWarning"
    W.label(panel,"상성에 따른 사본 수입니다. 실제 피해·승률과 이후 회복·학습·영입은 예측하지 않습니다.",Rect2(36,774,1208,28),16,W.MUTED)
    W.button(panel,Rect2(100,822,460,56),func(): closed.emit(),"목록으로").name = "RemovalCancel"
    var confirm := W.button(panel,Rect2(720,822,460,56),func(): accepted.emit(),"%d 골드 · 이 카드 1장 제거" % change["price"])
    confirm.name = "RemovalConfirm"
    confirm.disabled = not reason.is_empty()
    UiMotion.appear(self)
