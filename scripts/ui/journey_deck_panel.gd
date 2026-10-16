class_name JourneyDeckPanel
extends Control
## One permanent-deck browser for inspection, upgrades and merchant removal.
const W = preload("res://scripts/ui/combat_widgets.gd")
signal closed
signal selected(uid: int)
signal filter_selected(uid: int)
var journey: TacticalJourney
var action := ""
var owner_filter := -1
var close_button: Button
var scroll: ScrollContainer
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 80
    refresh()
func _filter(uid: int) -> void:
    owner_filter = uid
    refresh()
    filter_selected.emit(uid)
func refresh() -> void:
    W.clear(self)
    if owner_filter > 0 and not journey.party.any(func(p: BattlePokemon): return p.uid == owner_filter): owner_filter = -1
    var overlay := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: overlay.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.85),Color.TRANSPARENT,0))
    var panel := W.panel(overlay,Rect2(520,120,880,840),Color("14282f"),Color("536b6e"))
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(panel,"원정 덱 · %d장" % journey.deck.size(),Rect2(32,24,720,48),28,W.GOLD)
    close_button = W.icon_button(panel,"close",Rect2(796,30,48,48),func(): closed.emit(),"닫기 · Esc")
    close_button.name = "DeckClose"
    var hint := "동료별 카드 확인 · 같은 카드는 묶음으로 표시합니다."
    if action == "upgrade": hint = "강화할 카드 선택 · 묶음에서 1장 · 휴식과 공유"
    elif action == "remove": hint = "제거할 카드 선택 · %d 골드 · 묶음에서 1장" % journey.removal_price()
    W.label(panel,hint,Rect2(32,76,760,32),17,W.MUTED)
    var filters: Array[Dictionary] = [{"uid":-1,"name":"전체"},{"uid":0,"name":"공용"}]
    for p: BattlePokemon in journey.party: filters.append({"uid":p.uid,"name":p.display_name})
    for i in filters.size():
        var filter_uid: int = filters[i]["uid"]
        var count := journey.deck.filter(func(c: BattleCardInstance): return filter_uid < 0 or c.owner_uid == filter_uid).size()
        var button := W.button(panel,Rect2(32+i*164,116,152,40),_filter.bind(filter_uid),"%s · %d" % [filters[i]["name"],count])
        button.name = "DeckFilter_%d" % filter_uid
        button.add_theme_font_size_override("font_size",16)
        if filter_uid == owner_filter: button.add_theme_stylebox_override("normal",W.box(Color("29443f"),W.GOLD))
    scroll = ScrollContainer.new()
    scroll.name = "JourneyDeckCards"
    scroll.position = Vector2(32,164)
    scroll.size = Vector2(816,636)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation",28)
    grid.add_theme_constant_override("v_separation",8)
    scroll.add_child(grid)
    var views: Array[Dictionary] = []
    for card: BattleCardInstance in journey.deck:
        if owner_filter >= 0 and card.owner_uid != owner_filter: continue
        var view := journey.reward_view({"kind":"card","key":card.key,"owner_uid":card.owner_uid,"upgraded":card.upgraded})
        view["uid"] = card.uid
        views.append(view)
    for stack: Dictionary in CardStacks.group(views):
        var face := CardStackView.new()
        face.uid = stack["view"]["uid"]
        face.name = ("DeckStack_%d" if action.is_empty() else "Card_%d") % face.uid
        face.key = stack["view"]["key"]
        face.definition = stack["view"]
        face.stack_count = stack["count"]
        grid.add_child(face)
        if action.is_empty(): continue
        var source := journey.deck.filter(func(c: BattleCardInstance): return c.uid == face.uid)[0] as BattleCardInstance
        var reason := journey.remove_card_reason(source.uid) if action == "remove" else _upgrade_reason(source)
        face.allow_selection(reason,"선택하면 1장만 "+("제거" if action == "remove" else "강화"))
        face.pressed.connect(func(): selected.emit(face.uid))
    if views.is_empty():
        var empty := W.label(grid,"해당 카드가 없습니다.",Rect2(0,0,790,300),24,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
        empty.name = "DeckEmpty"
        empty.custom_minimum_size = Vector2(790,300)
func _upgrade_reason(card: BattleCardInstance) -> String:
    if journey.phase != TacticalJourney.REST: return "야영지에서 강화할 수 있습니다."
    if journey.step in journey.rested_steps: return "이번 야영지의 주 행동을 이미 사용했습니다."
    return "" if TacticalContent.can_upgrade(card) else "이 카드는 강화할 수 없습니다."
