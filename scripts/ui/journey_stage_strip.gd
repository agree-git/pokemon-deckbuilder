extends ScrollContainer
## Four stage cards per viewport, connected in their existing route order.
const W = preload("res://scripts/ui/combat_widgets.gd")
const CARD_WIDTH := 260.0
const CARD_HEIGHT := 280.0
const GAP := 50.0
const VISIBLE_CARDS := 4
const VIEW_WIDTH := CARD_WIDTH*VISIBLE_CARDS+GAP*(VISIBLE_CARDS-1)
const PITCH := CARD_WIDTH+GAP
var journey: TacticalJourney
var steps: Array[int] = []
var body: Control
func _ready() -> void:
    name = "JourneyStageStrip"
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    follow_focus = false
    body = Control.new();body.name="StageCards"
    add_child(body)
    var stops: Array = journey.route.stops if journey.full_campaign else TacticalJourneyContent.STOPS
    for i in stops.size():
        if journey.full_campaign and (stops[i]["chapter"] != journey.current()["chapter"] or stops[i]["kind"] == "rest"): continue
        steps.append(i)
    body.custom_minimum_size = Vector2(maxf(VIEW_WIDTH,steps.size()*CARD_WIDTH+maxi(0,steps.size()-1)*GAP),CARD_HEIGHT)
    var current_index := 0
    for index in steps.size():
        var at := steps[index]
        var stop: Dictionary = stops[at]
        if journey.full_campaign and journey.rare_hunt.get("battle_step",-1) == at: stop = RareEncounter.node(stop,int(journey.rare_hunt["target"]))
        var unknown: bool = stop.get("rare",false) and not RareEncounter.identity_known(journey)
        if unknown:
            stop = stop.duplicate();stop["name"]="희귀 조우 · ???";stop["icon"]="route"
        var current: bool = at == journey.step or (journey.current()["kind"] == "rest" and at == journey.step-1)
        if current: current_index=index
        var done := at<journey.step
        var card := W.panel(body,Rect2(index*PITCH,0,CARD_WIDTH,CARD_HEIGHT),Color("20383e") if current else Color("14282f"),W.GOLD if current else Color("405960"),14)
        card.name="Encounter_%d"%at
        card.mouse_filter=Control.MOUSE_FILTER_PASS
        var state := "현재" if current else ("완료" if done else "예정")
        W.label(card,"STAGE %02d · %s"%[index+1,state],Rect2(18,14,224,28),16,W.GOLD if current else W.MUTED)
        W.icon(card,"check" if done else ("attack" if stop["kind"] in ["trainer","veteran"] else stop["icon"]),Rect2(102,56,56,56))
        var title := W.label(card,stop["name"].replace(" · ","\n"),Rect2(18,130,224,72),20,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.max_lines_visible=3
        title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var final_battle: bool = stop["kind"] == "champion"
        W.label(card,"적 Lv.%d"%stop.get("level",5),Rect2(18,212,224,28),17,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        W.icon(card,"badge" if final_battle else "heal",Rect2(22,250,18,18))
        W.label(card,"챔피언 등극" if final_battle else "전투 후 야영지",Rect2(48,242,194,32),14,W.GOLD if final_battle else W.MUTED)
        card.tooltip_text=("승리하면 챔피언 등극" if final_battle else "전투 후 야영지")+" · 적 Lv.%d"%stop.get("level",5)
        var opponents: Array = [] if unknown or not journey.full_campaign else journey.opponents_at(at)
        if not opponents.is_empty() and opponents[0].has("boss"): card.tooltip_text+="\n고유 전술 · "+BossTactics.heading(opponents[0])
        for opponent: Dictionary in opponents: card.tooltip_text+="\n%s · %s · %s"%[opponent["name"],EnemyTactics.role_title(opponent),EnemyTactics.pattern_text(opponent)]
        if index<steps.size()-1:
            W.label(body,"→",Rect2(index*PITCH+CARD_WIDTH,108,GAP,56),30,W.GOLD if done else W.MUTED,HORIZONTAL_ALIGNMENT_CENTER).name="StageArrow_%d"%index
    _show_current.call_deferred(current_index)
func _show_current(index: int) -> void:
    await get_tree().process_frame
    if not is_inside_tree(): return
    scroll_horizontal = mini(int(index/VISIBLE_CARDS)*int(PITCH*VISIBLE_CARDS),max_scroll())
func max_scroll() -> int:
    return maxi(0,int(body.custom_minimum_size.x-size.x))
func turn_page(direction: int) -> void:
    scroll_horizontal = clampi(scroll_horizontal+direction*int(PITCH*VISIBLE_CARDS),0,max_scroll())
