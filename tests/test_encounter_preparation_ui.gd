extends "res://tests/test_upgrade_preview_ui.gd"
func fixture(index: int, camp: bool) -> TacticalJourney:
    var j := TacticalJourney.new(5,"field_kit",[1,4,7],true)
    j.phase = TacticalJourney.MAP
    j.step = index
    if camp: j.enter_next()
    # Long deck and conditional-effect fixtures; no claim of earning these rewards.
    for i in 7: j.deck.append(j._allocate_card("move_33",j.party[0].uid))
    for key: String in ["move_22","move_52","move_55","move_84","move_93","move_44","move_89"]:
        j.deck.append(j._allocate_card(key,j.party[0].uid))
    for key: String in ["shield_strike","status_cash","toxic_flask"]: j.deck.append(j._allocate_card(key,0))
    return j
func scroll_right(scroll: ScrollContainer) -> void:
    var bar := scroll.get_h_scroll_bar()
    var local := Vector2(bar.size.x-3,bar.size.y/2)
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(bar.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.2).timeout
    else:
        TacticalUIPlayer.click(self,bar,local)
        await process_frame
    clicks += 1
    settle()
    await process_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/preparation_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/preparation_journey.json"))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = fixture(13,true)
    session.adopt_journey(ui.journey)
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    for i in 3:
        var j := fixture([13,46,135][i],i != 1)
        if i == 2:
            j.party[0].hp = 0
            j.party[0].knocked_out = true
        session.adopt_journey(j)
        ui.journey = j
        ui.preparation_open = false
        ui.refresh()
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        await process_frame
        settle()
        var before := JourneySnapshot.encode(j)
        await click(ui.page.find_child("EncounterPreparation",true,false),[0.08,0.5,0.92][i])
        check(ui.preparation_open and JourneySnapshot.encode(j) == before,"Top/center/bottom opens preparation at three window ratios without changing the run")
        var panel: EncounterPreparationPanel = ui.page.find_child("PreparationEnemy_0",true,false).get_parent().get_parent().get_parent()
        check(ui.page.find_children("PreparationEnemy_*","Button",true,false).size() == 6,"All six actual boss opponents are individually selectable")
        var expected := EncounterPreparation.describe(j)
        var row: Dictionary = expected["enemies"][0]
        var summary: Label = ui.page.find_child("PreparationSummary",true,false)
        check(summary.text.contains("공격 %d장" % row["groups"]["attack"].size()) if not row["groups"]["attack"].is_empty() else summary.text.contains("직접 공격 없음"),"Summary uses the actual permanent deck rather than species or known moves")
        if row["groups"]["attack"].is_empty():
            var empty: Label = ui.page.find_child("PreparationEmpty",true,false)
            check(empty != null and empty.is_visible_in_tree() and empty.size.x > 500,"An empty attack group has a visible explanation")
        if i == 0:
            await picture("preparation-attacks")
            var scroll: ScrollContainer = ui.page.find_child("PreparationCards",true,false)
            check(scroll.get_h_scroll_bar().visible,"A long deck has a horizontal scrollbar")
            await scroll_right(scroll)
            check(scroll.scroll_horizontal > 0,"Actual pointer scrolling reveals attack cards beyond the first row")
        await click(ui.page.find_child("PreparationEnemy_5",true,false),[0.92,0.5,0.08][i])
        check(panel.selected == 5 and JourneySnapshot.encode(j) == before,"Selecting the sixth enemy is read-only")
        await click(ui.page.find_child("PreparationTab_immune",true,false))
        check(panel.group == "immune" and ui.page.find_children("PreparationCard_*","Button",true,false).reduce(func(total: int, face: CardStackView): return total+face.stack_count,0) == expected["enemies"][5]["groups"]["immune"].size(),"Immune tab shows actual cards for the selected opponent")
        if i == 1: await picture("preparation-immune")
        await click(ui.page.find_child("PreparationTab_conditional",true,false))
        check(panel.group == "conditional" and ui.page.find_children("PreparationCard_*","Button",true,false).reduce(func(total: int, face: CardStackView): return total+face.stack_count,0) == expected["enemies"][5]["groups"]["conditional"].size(),"Status damage and setup-dependent cards have their own group")
        if i == 1: await picture("preparation-conditional")
        if i == 2: check(ui.page.find_child("PreparationNote",true,false).text.contains("기절한 동료의 기술"),"Fainted owners are excluded with recovery guidance")
        await click(ui.actions[0]) # Departure is underneath the modal.
        check(ui.preparation_open and JourneySnapshot.encode(j) == before,"Preparation blocks underlying departure and resource changes")
        await click(ui.page.find_child("PreparationClose",true,false))
        check(not ui.preparation_open and JourneySnapshot.encode(j) == before,"Closing returns to the same map or camp")
        await click(ui.page.find_child("EncounterPreparation",true,false))
        await escape()
        check(not ui.preparation_open and JourneySnapshot.encode(j) == before,"Esc closes only preparation without leaving or saving new gameplay state")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == before,"Inspection preserves the exact autosave")
        if i == 2:
            await click(ui.rest_button)
            check(j.party[0].alive(),"Preparation leaves actual camp recovery usable")
            await click(ui.page.find_child("EncounterPreparation",true,false))
            check(not ui.page.find_child("PreparationNote",true,false).text.contains("기절한 동료"),"Reopening after real recovery includes the revived owner's cards")
            await click(ui.page.find_child("PreparationClose",true,false))
    print("ENCOUNTER_PREPARATION_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs")
    quit(0 if failures == 0 else 1)
