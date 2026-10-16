class_name StarterLoadoutPanel
extends Control
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
var loadout: StarterLoadout
var owner_filter := -1
var card_grid: GridContainer
var scroll: ScrollContainer
var filter_buttons: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 80
    var shade := W.button(self,Rect2(0,0,1920,1080),close)
    for state: String in ["normal","hover","pressed","focus"]:
        shade.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.88),Color.TRANSPARENT,0))
    var body := W.panel(shade,Rect2(180,100,1560,880),Color("14282f"),W.GOLD)
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,"출발 덱과 파티",Rect2(32,22,1380,52),30,W.GOLD)
    W.icon_button(body,"close",Rect2(1476,26,48,48),close,"닫기 · Esc").name = "Close"
    var totals := loadout.counts()
    W.label(body,"Lv.5 · %d장   |   기술 %d · 도구 %d · 트레이너 %d" % [loadout.cards.size(),totals["technique"],totals["tool"],totals["trainer"]],Rect2(32,78,1440,40),20,W.MUTED)
    W.label(body,"동료를 누르면 해당 기술 카드만 표시합니다.",Rect2(32,132,460,32),16,W.MUTED)
    for i in loadout.members.size():
        var p := loadout.members[i]
        var row := W.button(body,Rect2(32,184+i*196,448,180),_filter.bind(p.uid))
        row.name = "Member_%d" % p.uid
        W.sprite(row,p.species_id,Rect2(18,10,96,96))
        W.label(row,p.display_name,Rect2(134,14,292,40),24)
        var caption := "Lv.5 · "+("첫 출전" if i == 0 else "%d번 교체" % (i+1))
        if p.species_id in RareEncounter.IDS: caption += " · "+str(RareEncounter.rule(p.species_id)["name"])
        W.label(row,caption,Rect2(134,58,292,32),16,W.GOLD if p.species_id in RareEncounter.IDS else W.MUTED)
        W.label(row,PokemonStats.summary(p),Rect2(16,112,416,60),17,W.TEXT)
        filter_buttons[p.uid] = row
    for i in 2:
        var filter_key: int = [-1,0][i]
        var button := W.button(body,Rect2(520+i*248,132,232,48),_filter.bind(filter_key),"전체 카드" if i == 0 else "공용 카드")
        button.name = "AllCards" if i == 0 else "CommonCards"
        filter_buttons[filter_key] = button
    W.label(body,"실제 피해는 상대의 방어·상성에 따라 달라집니다.",Rect2(520,184,1008,28),16,W.MUTED)
    scroll = ScrollContainer.new()
    scroll.name = "DeckScroll"
    scroll.position = Vector2(520,222)
    scroll.size = Vector2(1008,552)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    card_grid = GridContainer.new()
    card_grid.name = "Cards"
    card_grid.columns = 4
    card_grid.add_theme_constant_override("h_separation",24)
    card_grid.add_theme_constant_override("v_separation",8)
    scroll.add_child(card_grid)
    W.label(body,"첫 번째 동료가 먼저 출전합니다.",Rect2(32,802,448,36),17,W.MUTED)
    W.label(body,loadout.note(),Rect2(520,790,1008,68),16,W.GOLD).name = "PreparationNote"
    _filter(-1)
    UiMotion.appear(self)

func _filter(uid: int) -> void:
    owner_filter = uid
    W.clear(card_grid)
    scroll.scroll_vertical = 0
    var views: Array[Dictionary] = []
    for instance: BattleCardInstance in loadout.cards:
        if uid >= 0 and instance.owner_uid != uid: continue
        views.append(loadout.view(instance))
    for stack: Dictionary in CardStacks.group(views):
        var view: Dictionary = stack["view"]
        var card := CardStackView.new()
        card.name = "StarterCard_%d" % view["uid"]
        card.uid = view["uid"]
        card.key = view["key"]
        card.definition = view
        card.stack_count = stack["count"]
        card_grid.add_child(card)
        if card.key == "move_165" and card.key not in loadout.member(int(view["owner_uid"])).learned_skills:
            card.tooltip_text += "\n공격 기술이 없는 동료에게 출발 시 제공하는 카드 · 배운 기술 슬롯을 차지하지 않습니다."
    for key: int in filter_buttons:
        filter_buttons[key].add_theme_stylebox_override("normal",W.box(Color("29443f") if key == uid else Color("14282f"),W.GOLD if key == uid else Color("405960")))
func close() -> void:
    closed.emit()
    get_parent().remove_child(self)
    queue_free()
