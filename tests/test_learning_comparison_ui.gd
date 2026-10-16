extends "res://tests/test_upgrade_preview_ui.gd"
var keys := 0
func keypress(code: int, symbol: String) -> void:
    if native:
        print("OS_MOVE 20 100")
        await create_timer(0.15).timeout
        print("OS_KEY ",symbol)
        await create_timer(0.2).timeout
    else:
        var event := InputEventKey.new()
        event.keycode = code
        event.pressed = true
        root.push_input(event)
        await process_frame
    keys += 1
    settle()
    await process_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/learning_comparison_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/learning_comparison_journey.json"))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = LearningDeckFixture.make()
    session.adopt_journey(ui.journey)
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var quantities := [0,1,3]
    for i in 3:
        var copies: int = quantities[i]
        var j := LearningDeckFixture.make(copies == 0,copies)
        if i == 2: j.step = 12 # Six-foe comparison boundary, not a manual campaign claim.
        session.adopt_journey(j)
        ui.journey = j
        ui.learning_compare_slot = -1
        ui.refresh()
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        await process_frame
        settle()
        var before := JourneySnapshot.encode(j)
        await click(ui.page.find_child("LearningCompare",true,false),[0.08,0.5,0.92][i])
        check(ui.learning_compare_slot == 0 and JourneySnapshot.encode(j) == before,"Comparison opens at three window ratios without accepting a skill")
        await click(ui.page.find_child("ComparisonSlot_1",true,false),[0.92,0.5,0.08][i])
        check(ui.learning_compare_slot == 1 and JourneySnapshot.encode(j) == before,"Slot selection only changes the comparison")
        await keypress(KEY_R,"r")
        check(ui.learning_compare_slot == 3 and JourneySnapshot.encode(j) == before,"R selects the fourth comparison without learning it")
        await keypress(KEY_W,"w")
        var view := LearningComparison.describe(j,1)
        var current := ui.page.find_children("ComparisonBeforeCard_*","Button",true,false)
        var replacement := ui.page.find_children("ComparisonAfterCard_*","Button",true,false)
        check(current.size() == CardStacks.group(view["before_cards"]).size() and replacement.size() == CardStacks.group(view["after_cards"]).size(),"Both sides group identical copies and keep upgrades separate")
        check(current.reduce(func(total: int, face: CardStackView): return total+face.stack_count,0) == copies and replacement.reduce(func(total: int, face: CardStackView): return total+face.stack_count,0) == maxi(1,copies),"Stack counts preserve every real before/after copy, including a missing original")
        check(replacement[0].definition["name"] == view["after_cards"][0]["name"] and replacement[0].definition["species_id"] == 7,"Incoming face preserves the actual learner and inherited upgrade")
        check(ui.page.find_child("ComparisonDeckSummary",true,false).text.contains("%d → %d" % [view["change"]["before"],view["change"]["after"]]),"Deck count shows the exact confirmed change")
        for k in view["coverage"].size():
            check(ui.page.find_child("Comparison_attack_%d" % k,true,false).text.ends_with("%d → %d" % [view["coverage"][k]["attack"][0],view["coverage"][k]["attack"][1]]),"Displayed next-opponent coverage matches the actual hypothetical deck")
        if i == 0:
            var empty: Label = ui.page.find_child("ComparisonBeforeEmpty",true,false)
            check(empty != null and empty.is_visible_in_tree() and empty.size.x > 500,"A zero-copy source has a visible explanation rather than a clipped empty label")
            await picture("learning-comparison-fresh")
        if i == 2:
            await picture("learning-comparison-boss")
            for scroll_name: String in ["ComparisonBefore","ComparisonAfter"]:
                var scroll: ScrollContainer = ui.page.find_child(scroll_name,true,false)
                check(not scroll.get_h_scroll_bar().visible,"Three copies fit as two stacks without scrolling")
                var stack: CardStackView = scroll.find_child("*Card_1",true,false)
                check(stack.stack_count == 2 and stack.count_label.text == "×2" and stack.backs.size() == 1,"Plain duplicates have visible depth and an exact count beside the separate upgrade")
        await click(ui.learn_buttons[0])
        check(ui.learning_compare_slot == 1 and JourneySnapshot.encode(j) == before,"Comparison blocks immediate learning buttons underneath")
        await keypress(KEY_ENTER,"Return")
        check(JourneySnapshot.encode(j) == before,"Enter cannot accidentally accept an unconfirmed comparison")
        await click(ui.page.find_child("ComparisonCancel",true,false))
        check(ui.learning_compare_slot == -1 and JourneySnapshot.encode(j) == before,"Cancel returns to the pending learning choice")
        await click(ui.page.find_child("LearningCompare",true,false))
        await escape()
        check(ui.learning_compare_slot == -1 and JourneySnapshot.encode(j) == before,"Esc closes only the comparison")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == before,"Browsing preserves the exact saved learning checkpoint")
        await click(ui.page.find_child("LearningCompare",true,false))
        await click(ui.page.find_child("ComparisonSlot_1",true,false))
        await click(ui.page.find_child("ComparisonConfirm",true,false),[0.08,0.5,0.92][i])
        check(ui.learning_compare_slot == -1 and j.phase != TacticalJourney.LEARN and j.party[2].learned_skills[1] == "move_55" and j.deck.size() == view["change"]["after"],"Confirmation applies only the compared slot and exact card count")
        saved = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Confirmed comparison autosaves the actual learned deck")
    var j := LearningDeckFixture.make()
    session.adopt_journey(j)
    ui.journey = j
    ui.refresh()
    await process_frame
    await keypress(KEY_W,"w")
    check(j.phase != TacticalJourney.LEARN and j.party[2].learned_skills[1] == "move_55","Outside comparison W performs the displayed direct learning choice")
    print("LEARNING_COMPARISON_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs; ",keys," keys")
    quit(0 if failures == 0 else 1)
