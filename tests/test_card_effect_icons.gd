extends SceneTree
var checks := 0
var failures := 0
var cards: Array[TrainerActionCard] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var views: Array[Dictionary] = []
    for key: String in TacticalContent.CARDS:
        for upgraded: bool in [false,true]:
            var card := BattleCardInstance.new(1,key,0)
            card.upgraded = upgraded
            views.append(TacticalContent.definition(card))
    for id: String in TacticalGrowth.data()["moves"]:
        for upgraded: bool in [false,true]:
            var card := BattleCardInstance.new(1,"move_"+id,4)
            card.upgraded = upgraded
            views.append(TacticalContent.definition(card))
    var b := TacticalBattle.new()
    b.restart(42,"field_kit")
    for key: String in TacticalContent.CARDS:
        views.append(b.card_view(BattleCardInstance.new(1,key,0)))
    for i in range(0,views.size(),24):
        for n in range(i,mini(i+24,views.size())):
            var button := TrainerActionCard.new()
            button.definition = views[n]
            button.key = str(views[n].get("key","analysis"))
            root.add_child(button)
            cards.append(button)
        await process_frame
        await process_frame
        for button: TrainerActionCard in cards:
            var view := button.definition
            check(button.effect_label.get_content_height() <= button.effect_label.size.y,"No clipped effect rows: "+str(view.get("key"))+" "+str(button.effect_label.get_content_height())+" "+button.effect_label.text)
            if view.get("category","") != "technique":
                check(button.effect_label.get_theme_font_size("normal_font_size") >= 14,"Common card explanation stays legible: "+str(view.get("key")))
            check(not button.tooltip_text.is_empty() and button.tooltip_text.contains(view["name"]),"Full textual tooltip survives for "+str(view.get("key")))
            check(button.effect_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Icons do not intercept card hover/click")
            for field: String in ["block","heal","bonus"]:
                if view.has(field) and not view.has("preview_"+field): check(button.effect_label.text.contains(PokemonStats.percent(int(view[field]))),"Unbound support effect keeps HP percentage")
            for status: String in CardEffectText.STATUS_ICONS:
                if view.has(status): check(button.effect_label.text.contains("/"+str(CardEffectText.STATUS_ICONS[status])+".svg"),"Status retains distinct icon")
            button.free()
        cards.clear()
    # These are meaning-bearing facts, not just evidence that a texture exists.
    var poison := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"toxic_flask",0)))
    check(poison.contains("상대에게 ") and poison.contains("3턴 부여") and poison.contains("이 전투에서만 제외") and not poison.contains("독"),"Poison explains recipient, duration, application and exhaustion")
    var attrition := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"status_plan",0)))
    check(attrition.contains("적의 ") and attrition.contains("/burn.svg") and attrition.contains("/ailment_poison.svg") and attrition.contains("/seed.svg") and attrition.contains("지속 피해 발생 시") and attrition.contains("2.1%") and attrition.contains("전투 동안 유지"),"Attrition identifies the affected damage, additive target-HP basis and lifetime")
    var retrieve := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"retrieve",0)))
    check(retrieve.contains("버린 더미") and retrieve.contains("가장 최근 기술 카드 1장") and retrieve.contains("손패로 가져오기"),"Retrieve explains the source, selection and destination")
    var redraw := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"redraw",0)))
    check(redraw.contains("남은 손패 모두 버리기") and redraw.contains("버린 수만큼 뽑기"),"Redraw states both actions instead of an unexplained arrow")
    var cash := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"status_cash",0)))
    check(cash.contains("제거") and cash.contains("남은 횟수 1회마다") and cash.contains("적 최대 ") and cash.contains("상성 무시"),"Status cash explains consumption, count, damage basis and affinity exception")
    var ace := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"ace_order",0)))
    check(ace.contains("출전 멤버") and ace.contains("이번 턴") and ace.contains("기술 2회 이상 사용 시"),"Conditional draw keeps its owner, turn and skill-count restriction")
    var injury := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"injury",0)))
    check(injury.contains("기절하면 덱에 추가") and injury.contains("야영지 휴식으로 제거"),"Injury keeps its source and removal rule")
    var bonus := CardEffectText.render(TacticalContent.definition(BattleCardInstance.new(1,"rally",0)))
    check(bonus.contains("다음 ") and bonus.contains("추가") and bonus.contains("자신 최대 ") and bonus.contains("/heal.svg") and bonus.contains("교대해도 유지"),"Next-attack bonus is additive damage with its own HP basis, not an unexplained attack percent")
    for spec: Array in [["guard","보호막"],["potion_card","회복"],["ether_card","에너지"],["toxic_flask","독"],["move_74","공격"]]:
        var view := TacticalContent.definition(BattleCardInstance.new(1,spec[0],4 if str(spec[0]).begins_with("move_") else 0))
        check(not CardEffectText.render(view).contains(spec[1]),"Icon and its equivalent name are not duplicated on "+str(spec[0]))
    var unbound := TacticalContent.definition(BattleCardInstance.new(1,"move_52",4))
    check(CardEffectText.render(unbound).contains("위력"),"Unbound move power is never presented as damage")
    var before := b.snapshot()
    for c: BattleCardInstance in b.hand:
        var view := b.card_view(c)
        var text := CardEffectText.render(view)
        if view.has("preview_damage"): check(text.contains(str(view["preview_damage"])),"Battle face uses calculated damage")
    check(b.snapshot() == before,"Formatting cannot change battle rules, RNG or piles")
    var preview := BattleActionPreview.new()
    var delta := preview._vitals({"hp":8,"block":0},{"hp":5,"block":0})
    check(delta == CardEffectText.icon("heal")+" −3","8 to 5 is the requested HP loss of three, without unchanged shield")
    check(preview._vitals({"hp":5,"block":2},{"hp":8,"block":6}) == CardEffectText.icon("heal")+" +3   "+CardEffectText.icon("shield")+" +4","Healing and shield increases have explicit positive deltas")
    check(preview._vitals({"hp":5,"block":2},{"hp":5,"block":2}).is_empty(),"Unchanged values disappear instead of showing zero deltas")
    check(preview._signed(-2) == "−2" and preview._signed(1) == "+1","Energy gains and costs share the same sign convention")
    preview.free()
    print("CARD_EFFECT_ICONS: ",checks," checks, ",failures," failures; ",views.size()," card faces")
    quit(0 if failures == 0 else 1)
