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
    if view.get("player_rules",1)>=2 and (not view.has("weather") or view.has("extension")):return "[center]"+"\n".join(PlayerTechniques.lines(view))+"[/center]"
    var rows: Array[String] = []
    if view.has("weather"):
        var key := str(view["weather"])
        rows.assign([icon("weather_"+key)+"5턴 · 양쪽 적용"])
        match key:
            "rain": rows.append_array([icon("water")+"피해 ×1.5",icon("fire")+"피해 ×0.5"])
            "sun": rows.append_array([icon("fire")+"피해 ×1.5",icon("water")+"피해 ×0.5"])
            "snow": rows.append_array([icon("ice")+"의 물리 방어 ×1.5","지속 피해 없음"])
            "sand": rows.append_array([icon("rock")+"의 특방 ×1.5","턴 종료 시 출전 멤버","최대 "+icon("heal")+"1/16 감소",icon("rock")+icon("ground")+icon("steel")+"피해 면역"])
        if key != "sand": rows.append("다른 날씨로 교체")
        return "[center]"+"\n".join(rows)+"[/center]"
    if view.has("retrieve") and view.get("condition","") == "cycle":
        rows.assign(["버린 더미의 기술","최근 %d장 손패로 회수" % int(view.get("retrieve_count",1)),"이번 턴 재섞기 시",icon("energy")+"+%d 획득" % int(view["conditional_energy"])+(" ✓" if view.get("condition_active",false) else "")])
        if view.get("exhaust",false): rows.append(icon("exhaust",16)+"이 전투에서만 제외")
        return "[center]"+"\n".join(rows)+"[/center]"
    if view.has("shield_attack"):
        rows.append("자신 "+icon("shield")+"모두 소비")
        rows.append("상대에게 "+icon("attack")+str(int(view["preview_damage"])) if view.has("preview_damage") else "같은 수치만큼 "+icon("attack")+"발생")
        rows.append("상성 무시 · 적 "+icon("shield")+"적용")
    elif view.has("damage"):
        if view.has("preview_damage"): rows.append("상대에게 "+icon("attack")+str(int(view["preview_damage"])))
        elif view.has("move_power"): rows.append("위력 "+icon("attack" if view.get("damage_class","") == "physical" else "special_attack")+str(int(view["move_power"])))
        else: rows.append("상대에게 "+icon("attack")+str(int(view["damage"])))
    for field: String in ["block","heal","bonus"]:
        if not view.has(field): continue
        if field == "bonus":
            var future_actor := not str(view.get("concept","")).is_empty()
            rows.append("다음 "+icon("attack")+(PokemonStats.percent(int(view[field])) if future_actor else amount(view,field))+" 추가")
            if future_actor or not view.has("preview_bonus"): rows.append(("공격자 최대 " if future_actor else "자신 최대 ")+icon("heal")+"기준")
            if not view.has("conditional_draw") and not view.has("conditional_bonus"): rows.append("교대해도 유지")
        else:
            var badge: String = {"block":"shield","heal":"heal"}[field]
            rows.append("자신 "+icon(badge)+"+"+amount(view,field))
            if not view.has("preview_"+field): rows.append("자신 최대 "+icon("heal")+"기준")
    for field: String in ["strength","weaken","temporary_strength","draw","energy"]:
        if not view.has(field): continue
        var value := int(view[field])*(10 if field in ["strength","weaken","temporary_strength"] else 1)
        match field:
            "draw": rows.append(icon("draw")+"%d장 뽑기" % value)
            "energy": rows.append(icon("energy")+"+%d 획득" % value)
            "weaken": rows.append("상대 "+icon("attack")+"−%d%%" % value)
            "strength": rows.append("자신 "+icon("attack")+"+%d%%" % value); rows.append("이번 전투 동안 유지")
            "temporary_strength": rows.append("자신 "+icon("attack")+"+%d%%" % value); rows.append("교대하면 해제")
    for status: String in STATUS_ICONS:
        if view.has(status):
            var turns := 3 if status == "expose" else int(view.get("preview_"+status,view[status]))
            rows.append("상대에게 "+icon(STATUS_ICONS[status])+"%d턴 부여" % turns)
    if view.has("cleanse"): rows.append(icon("cleanse")+"자신의 상태이상 해제")
    if view.has("stat_changes"):
        var changes: Dictionary = view["stat_changes"]
        var recipient := "자신 " if view.get("stat_target","") == "self" else "상대 "
        if changes.size() == 5 and changes.values().all(func(n: int): return n == 1): rows.append(recipient+icon("all_stats")+"+1단계")
        else:
            for stat: String in changes: rows.append(recipient+icon(STAT_ICONS[stat])+"%+d단계" % int(changes[stat]))
    if view.has("condition"):
        rows.append_array(BuildConceptContent.condition_rows(str(view["condition"])))
        var checked := " ✓" if view.get("condition_active",false) else ""
        if view.has("conditional_draw"): rows.append(icon("draw")+"%d장 뽑기" % int(view["conditional_draw"])+checked)
        if view.has("conditional_energy"): rows.append(icon("energy")+"+%d 획득" % int(view["conditional_energy"])+checked)
        if view.has("conditional_bonus"): rows.append("추가 "+icon("attack")+"+"+PokemonStats.percent(int(view["conditional_bonus"]))+checked)
    rows.append_array(BuildConceptContent.effect_rows(view))
    if view.has("redraw"):
        rows.append("남은 손패 모두 버리기")
        rows.append(icon("draw")+"버린 수만큼 뽑기")
        if int(view.get("redraw_bonus",0)) > 0: rows.append("카드 %d장 추가로 뽑기" % int(view["redraw_bonus"]))
    if view.has("retain"):
        rows.append("비용이 가장 높은 카드")
        rows.append("%d장을 다음 턴까지 보존" % int(view.get("retain_count",1)))
    if view.has("retrieve"):
        rows.append("버린 더미에서")
        match str(view.get("retrieve_scope","")):
            "reserve": rows.append("살아 있는 대기 동료의")
            "active": rows.append("출전 멤버의")
        if view.get("retrieve_scope","") != "" or int(view.get("retrieve_count",1)) != 1:
            rows.append("기술 최대 %d장 회수" % int(view.get("retrieve_count",1)))
            rows.append("최신 카드부터 손패로")
        else:
            rows.append("가장 최근 기술 카드 1장")
            rows.append(icon("draw")+"손패로 가져오기")
    if view.has("finisher"):
        rows.append("이번 턴 출전 멤버의")
        rows.append("다음 공격 기술 "+icon("attack")+"×2")
        rows.append("중첩 불가")
    if view.has("pulse_status"):
        rows.append("적의 "+icon("burn")+icon("ailment_poison")+icon("seed"))
        rows.append("각각 1회 즉시 발동")
        rows.append("남은 횟수 유지")
        rows.append("적 "+icon("shield")+"무시")
    if view.has("double_block"):
        rows.append("출전 멤버의 현재")
        rows.append(icon("shield")+"×2")
        rows.append(icon("shield")+"+%d 획득" % int(view["preview_block_gain"]) if view.has("preview_block_gain") else "없으면 추가 획득 없음")
    if view.has("cash"):
        rows.append("적 "+icon("burn")+icon("ailment_poison")+icon("seed")+"제거")
        rows.append("남은 횟수 1회마다")
        rows.append("적 최대 "+icon("heal")+"의 8.3%만큼")
        rows.append(icon("attack")+"발생 · 상성 무시")
    if view.has("power"):
        match str(view["power"]):
            "relay": rows.append("기술로 교대할 때마다"); rows.append("자신 "+icon("shield")+"+6.3%"); rows.append("자신 최대 "+icon("heal")+"기준")
            "ace": rows.append("교대 없이 턴 종료 시"); rows.append("다음 턴 "+icon("attack")+"+20%")
            "supply": rows.append("도구 카드를 쓸 때마다"); rows.append("자신 "+icon("shield")+"+10.4%"); rows.append("자신 최대 "+icon("heal")+"기준")
            "attrition": rows.append("적의 "+icon("burn")+icon("ailment_poison")+icon("seed")); rows.append("지속 피해 발생 시"); rows.append("적 최대 "+icon("heal")+"의 2.1%만큼"); rows.append(icon("attack")+"추가")
            _: rows.append_array(BuildConceptContent.power_rows(str(view["power"])))
        if view["power"] == "attrition": rows[-1] += " · 전투 동안 유지"
        else: rows.append("이번 전투 동안 유지")
    if view.get("key","") == "injury": rows.append("기절하면 덱에 추가"); rows.append("사용해도 효과 없음"); rows.append("야영지 휴식으로 제거")
    elif rows.is_empty(): rows.append("효과 없음")
    if view.get("exhaust",false): rows.append(icon("exhaust",16)+"이 전투에서만 제외")
    return "[center]"+"\n".join(rows)+"[/center]"

static func apply(node: RichTextLabel,view: Dictionary) -> void:
    var content := render(view)
    var rows := content.count("\n")+1
    node.add_theme_constant_override("line_separation",-2 if rows >= 5 else 0)
    node.position.y = 139
    node.size = Vector2(162,108)
    for font_size: int in [18,16,14,13,12]:
        var side: int = {18:22,16:20,14:18,13:16,12:16}[font_size]
        node.add_theme_font_size_override("normal_font_size",font_size)
        node.text = content.replace("img=18x18","img=%dx%d" % [side,side])
        if node.get_content_height() <= 108 and node.get_line_count() <= rows: break
    var offset := maxf(0,floorf((108-node.get_content_height())/2.0))
    node.position.y += offset
    node.size.y -= offset
static func legend(parent: Node,rect: Rect2) -> void:
    var node := label(parent,rect,16)
    node.text = icon("heal")+" HP·회복   "+icon("attack")+" 피해·공격   "+icon("shield")+" 보호막   "+icon("draw")+" 뽑기   "+icon("energy")+" 에너지   "+icon("exhaust")+" 소진\n방패·회복·추가 피해 % = 최대 HP 비율 · 단계 = 능력 변화 · 상세 규칙은 툴팁"

static func status_legend(parent: Node,rect: Rect2) -> void:
    var node := label(parent,rect,16)
    node.text = icon("defense")+" 방어   "+icon("special_attack")+" 특공   "+icon("special_defense")+" 특방   "+icon("speed")+" 스피드   "+icon("all_stats")+" 모든 능력\n"+icon("burn")+" 화상   "+icon("ailment_poison")+" 독   "+icon("seed")+" 씨앗   "+icon("sleep")+" 수면   "+icon("paralysis")+" 마비   "+icon("confusion")+" 혼란\n위력의 %는 공격 보정 · 상태 옆 숫자는 남은 횟수 · 방패는 피해를 먼저 흡수"
