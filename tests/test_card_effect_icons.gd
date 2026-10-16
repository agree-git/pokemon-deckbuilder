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
            check(not button.tooltip_text.is_empty() and button.tooltip_text.contains(view["name"]),"Full textual tooltip survives for "+str(view.get("key")))
            check(button.effect_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Icons do not intercept card hover/click")
            for field: String in ["block","heal","bonus"]:
                if view.has(field) and not view.has("preview_"+field): check(button.effect_label.text.contains(PokemonStats.percent(int(view[field]))),"Unbound support effect keeps HP percentage")
            for status: String in CardEffectText.STATUS_ICONS:
                if view.has(status): check(button.effect_label.text.contains("/"+str(CardEffectText.STATUS_ICONS[status])+".svg"),"Status retains distinct icon")
            button.free()
        cards.clear()
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
