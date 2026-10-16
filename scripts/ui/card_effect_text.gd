class_name CardEffectText
extends RefCounted
## Presentation only: structured effects keep their full Korean rules in tooltips.
const W = preload("res://scripts/ui/combat_widgets.gd")
const STAT_ICONS := {"attack":"attack","defense":"defense","special_attack":"special_attack","special_defense":"special_defense","speed":"speed"}
const STATUS_ICONS := {"burn":"burn","seed":"seed","poison":"ailment_poison","sleep":"sleep","paralysis":"paralysis","confusion":"confusion","expose":"counter"}
static func icon(key: String,side := 18) -> String:
    return "[img=%dx%d]res://assets/ui/icons/%s.svg[/img]" % [side,side,key]
static func label(parent: Node,rect: Rect2,font_size := 15,color := W.TEXT) -> RichTextLabel:
    var node := RichTextLabel.new()
    node.position = rect.position
    node.size = rect.size
    node.bbcode_enabled = true
    node.scroll_active = false
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_theme_font_size_override("normal_font_size",font_size)
    node.add_theme_color_override("default_color",color)
    node.add_theme_constant_override("line_separation",0)
    parent.add_child(node)
    return node
static func amount(view: Dictionary,field: String) -> String:
    return str(view["preview_"+field]) if view.has("preview_"+field) else PokemonStats.percent(int(view[field]))
static func render(view: Dictionary) -> String:
    var rows: Array[String] = []
    var tokens: Array[String] = []
    if view.has("shield_attack"):
        rows.append(icon("shield")+"전부 → "+icon("attack")+str(view.get("preview_damage","같은 수치")))
        rows.append("모두 소비 · 상성 무시")
    elif view.has("damage"):
        if view.has("preview_damage"): tokens.append(icon("attack")+str(view["preview_damage"]))
        elif view.has("move_power"): tokens.append("위력 "+icon("attack" if view.get("damage_class","") == "physical" else "special_attack")+str(view["move_power"]))
        else: tokens.append(icon("attack")+str(view["damage"]))
    for field: String in ["block","heal","bonus"]:
        if view.has(field): tokens.append(("다음 " if field == "bonus" else "")+icon({"block":"shield","heal":"heal","bonus":"attack"}[field])+"+"+amount(view,field))
    for field: String in ["strength","weaken","temporary_strength","draw","energy"]:
        if view.has(field):
            var badge: String = {"strength":"attack","weaken":"attack","temporary_strength":"attack","draw":"draw","energy":"energy"}[field]
            var value := int(view[field])*(10 if field in ["strength","weaken","temporary_strength"] else 1)
            tokens.append(("적 위력 " if field == "weaken" else ("교대 전 " if field == "temporary_strength" else ("위력 " if field == "strength" else "")))+icon(badge)+("−" if field == "weaken" else "+")+str(value)+("%" if field in ["strength","weaken","temporary_strength"] else ""))
    for status: String in STATUS_ICONS:
        if view.has(status): tokens.append(icon(STATUS_ICONS[status])+"%d회" % int(view.get("preview_"+status,view[status])))
    if view.has("cleanse"): tokens.append(icon("cleanse")+"해제")
    # Two effects per line keep numbers legible on the 186px card face.
    while not tokens.is_empty():
        var line: String = tokens.pop_front()
        if not tokens.is_empty(): line += "  "+str(tokens.pop_front())
        rows.append(line)
    if view.has("stat_changes"):
        var changes: Dictionary = view["stat_changes"]
        var stages: Array[String] = []
        if changes.size() == 5 and changes.values().all(func(n: int): return n == 1): stages.append(icon("all_stats")+"+1")
        else:
            for stat: String in changes: stages.append(icon(STAT_ICONS[stat])+"%+d" % int(changes[stat]))
        rows.append(("자신 " if view.get("stat_target","") == "self" else "상대 ")+" ".join(stages)+"단계")
    if view.has("conditional_draw"):
        rows.append(("교대 후 " if view["condition"] == "relay" else "기술 2회 후 ")+icon("draw")+"+%d" % int(view["conditional_draw"])+( " ✓" if view.get("condition_active",false) else ""))
    if view.has("redraw"): rows.append(icon("discard")+"전부 → "+icon("draw")+"같은 수치"+("+1" if view.get("redraw_bonus",0) > 0 else ""))
    if view.has("retain"): rows.append("최고 비용 "+icon("draw")+"%d 보존" % int(view.get("retain_count",1)))
    if view.has("retrieve"): rows.append(icon("discard")+" → "+icon("draw")+"1 기술")
    if view.has("cash"):
        rows.append(icon("burn")+icon("ailment_poison")+icon("seed")+" 소비")
        rows.append("횟수 × 적 "+icon("attack")+"8.3%")
    if view.has("power"):
        match str(view["power"]):
            "relay": rows.append("기술 교대 → "+icon("shield")+"6.3%")
            "ace": rows.append("출전 유지 · 다음 턴"); rows.append(icon("attack")+"+20%")
            "supply": rows.append(icon("bag")+"사용 → "+icon("shield")+"10.4%")
            "attrition": rows.append(icon("burn")+icon("ailment_poison")+icon("seed")+" 매회"); rows.append("적 "+icon("attack")+"+2.1%")
    if rows.is_empty(): rows.append("효과 없음")
    if view.get("exhaust",false):
        rows[-1] += "  "+icon("exhaust",16)
    # Support percentages use max HP; power modifiers and stage changes stay distinct.
    return "[center]"+"\n".join(rows)+"[/center]"
static func apply(node: RichTextLabel,view: Dictionary) -> void:
    var content := render(view)
    var rows := content.count("\n")+1
    node.position.y = 184
    node.size = Vector2(162,60)
    for font_size: int in [20,17,14,12]:
        var side: int = {20:24,17:20,14:18,12:16}[font_size]
        node.add_theme_font_size_override("normal_font_size",font_size)
        node.text = content.replace("img=18x18","img=%dx%d" % [side,side])
        if node.get_content_height() <= 60 and node.get_line_count() <= rows: break
    var offset := maxf(0,floorf((60-node.get_content_height())/2.0))
    node.position.y += offset
    node.size.y -= offset
static func legend(parent: Node,rect: Rect2) -> void:
    var node := label(parent,rect,16)
    node.text = icon("heal")+" HP·회복   "+icon("attack")+" 피해·공격   "+icon("shield")+" 보호막   "+icon("draw")+" 뽑기   "+icon("energy")+" 에너지   "+icon("exhaust")+" 소진\n방패·회복·추가 피해 % = 최대 HP 비율 · 단계 = 능력 변화 · 상세 규칙은 툴팁"

static func status_legend(parent: Node,rect: Rect2) -> void:
    var node := label(parent,rect,16)
    node.text = icon("defense")+" 방어   "+icon("special_attack")+" 특공   "+icon("special_defense")+" 특방   "+icon("speed")+" 스피드   "+icon("all_stats")+" 모든 능력\n"+icon("burn")+" 화상   "+icon("ailment_poison")+" 독   "+icon("seed")+" 씨앗   "+icon("sleep")+" 수면   "+icon("paralysis")+" 마비   "+icon("confusion")+" 혼란\n위력의 %는 공격 보정 · 상태 옆 숫자는 남은 횟수 · 방패는 피해를 먼저 흡수"
