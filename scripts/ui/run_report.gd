class_name RunReport
extends Control
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
var journey: TacticalJourney
var tab := "battles"
var body: Panel
var content: Control
var tabs: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 90
    var shade := W.button(self,Rect2(0,0,1920,1080),func(): closed.emit())
    for state: String in ["normal","hover","pressed","focus"]: shade.add_theme_stylebox_override(state,W.box(Color(0.01,0.025,0.04,0.84),Color.TRANSPARENT,0))
    body = W.panel(self,Rect2(300,100,1320,880),Color("14282f"),W.GOLD)
    body.mouse_filter = Control.MOUSE_FILTER_STOP
    W.label(body,"원정 기록",Rect2(36,20,800,50),30,W.GOLD)
    W.icon_button(body,"close",Rect2(1230,24,52,48),func(): closed.emit(),"닫기 · Esc").name = "Close"
    var stats := journey.statistics if not journey.statistics.is_empty() else RunStatistics.expedition(true)
    W.label(body,"정산한 %d전투 · 시드 %d%s" % [stats["battles"].size(),journey.seed_value," · 업데이트 이후 기록만 집계" if stats["partial"] else ""],Rect2(36,77,1240,32),16,W.MUTED)
    var combat: Dictionary = stats["combat"]
    var counts: Dictionary = stats["counts"]
    summary(0,"전투",["카드 %d · 기술 교대 %d" % [combat["cards_played"],combat["auto_switches"]],"뽑은 카드 %d · 재섞기 %d" % [combat["drawn"],combat["reshuffles"]],"턴 종료 잔여 에너지 %d" % combat["unused_energy"]])
    summary(1,"생존",["받은 피해 %d · 기절 %d" % [combat["damage_taken"],combat["knockouts"]],"보호막으로 막은 피해 %d" % combat["shield_absorbed"],"회복 · 전투 %d / 야영 %d" % [combat["healing"],counts["camp_healing"]]])
    summary(2,"골드",["보상·이벤트 수입 %d" % counts["gold_earned"],"총 지출 %d · 현재 %d" % [RunStatistics.spent(stats),journey.gold],"카드 %d · 보급 %d" % [counts["gold_cards"],counts["gold_supplies"]]])
    summary(3,"덱 성장",["구매 %d · 강화 %d · 제거 %d" % [counts["cards_bought"],counts["cards_upgraded"],counts["cards_removed"]],"보상 선택 %d · 넘김 %d" % [int(counts["reward_card"])+int(counts["reward_relic"])+int(counts["reward_held"]),counts["reward_skip"]],"휴식 %d · 가방 사용 %d" % [counts["rests"],counts["items_used"]]])
    for i in 3:
        var key: String = ["battles","choices","build"][i]
        var button := W.button(body,Rect2(36+i*420,292,404,52),select.bind(key),["전투별 기록","카드·골드 선택","카드 사용·유물 발동"][i])
        button.name = "Tab_"+key
        tabs[key] = button
    content = Control.new()
    content.name = "Content"
    body.add_child(content)
    select(tab)
    UiMotion.appear(self)

func summary(index: int, title: String, lines: Array) -> void:
    var panel := W.panel(body,Rect2(36+index*316,124,300,144),Color("20383e"))
    W.label(panel,title,Rect2(16,8,268,28),18,W.GOLD)
    for i in lines.size(): W.label(panel,lines[i],Rect2(16,43+i*30,268,28),16,W.TEXT)

func select(key: String) -> void:
    tab = key
    W.clear(content)
    for name_key: String in tabs:
        tabs[name_key].add_theme_stylebox_override("normal",W.box(Color("29443f") if name_key == key else Color("14282f"),W.GOLD if name_key == key else Color("405960")))
    var stats := journey.statistics if not journey.statistics.is_empty() else RunStatistics.expedition(true)
    var scroll := ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.position = Vector2(36,402)
    scroll.size = Vector2(1248,438)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.name = "Rows"
    rows.custom_minimum_size.x = 1220
    rows.add_theme_constant_override("separation",8)
    scroll.add_child(rows)
    match key:
        "battles":
            for column: Array in [["전투명",16,630],["결과",650,100],["턴",770,80],["받은 피해",900,130],["기절",1100,90]]:
                W.label(content,column[0],Rect2(36+column[1],356,column[2],36),18,W.MUTED)
            var entries: Array = stats["battles"].duplicate()
            entries.reverse()
            for entry: Dictionary in entries:
                var row := Control.new()
                row.name = "Battle_%d" % entry["step"]
                row.custom_minimum_size = Vector2(1220,60)
                rows.add_child(row)
                W.panel(row,Rect2(0,0,1220,60),Color("20383e"))
                W.label(row,entry["name"]+(" *" if entry["partial"] else ""),Rect2(16,10,630,40),18)
                W.label(row,"승리" if entry["won"] else "패배",Rect2(650,10,100,40),18,W.GOLD if entry["won"] else Color("efb2a5"))
                W.label(row,str(entry["turns"]),Rect2(770,10,80,40),18)
                W.label(row,str(entry["counts"]["damage_taken"]),Rect2(900,10,130,40),18)
                W.label(row,str(entry["counts"]["knockouts"]),Rect2(1100,10,90,40),18)
            if entries.is_empty(): line(rows,"아직 정산한 전투 기록이 없습니다.")
        "choices":
            var counts: Dictionary = stats["counts"]
            W.label(content,"지출 · 카드 %d / 보급품 %d / 제거 %d / 수업 %d 골드" % [counts["gold_cards"],counts["gold_supplies"],counts["gold_removal"],counts["gold_events"]],Rect2(48,356,1220,36),18,W.MUTED)
            var choices: Array = stats["choices"].duplicate()
            choices.reverse()
            for choice: String in choices: line(rows,choice)
            if choices.is_empty(): line(rows,"아직 카드·보상 선택 기록이 없습니다.")
        "build":
            W.label(content,"카드 사용은 사본·소유자를 합산합니다. 유물 발동 횟수는 실제 피해 기여도와 다릅니다.",Rect2(48,356,1220,36),17,W.MUTED)
            line(rows,"사용한 카드",true)
            for card: String in RunStatistics.ranked(stats["cards"]): line(rows,"%s · %d회" % [RunStatistics.card_name(card),stats["cards"][card]])
            line(rows,"유물 발동",true)
            for relic: String in RunStatistics.ranked(stats["relics"]): line(rows,"%s · %d회" % [TacticalContent.RELICS[relic]["name"],stats["relics"][relic]])

func line(parent: Node, text: String, title := false) -> void:
    var row := Control.new()
    row.custom_minimum_size = Vector2(1220,48)
    parent.add_child(row)
    W.panel(row,Rect2(0,0,1220,48),Color("20383e"))
    W.label(row,text,Rect2(16,4,1180,40),18,W.GOLD if title else W.TEXT)
