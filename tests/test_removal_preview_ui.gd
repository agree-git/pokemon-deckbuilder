extends "res://tests/test_upgrade_preview_ui.gd"
func enter_key() -> void:
    if native:
        print("OS_MOVE 20 100")
        await create_timer(0.15).timeout
        print("OS_KEY Return")
        await create_timer(0.2).timeout
    else:
        var event := InputEventKey.new()
        event.keycode = KEY_ENTER
        event.pressed = true
        root.push_input(event)
        await process_frame
    settle()
    await process_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/removal_preview_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/removal_preview_journey.json"))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = RemovalFixture.make()
    session.adopt_journey(ui.journey)
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    for i in 3:
        var j := RemovalFixture.make(i == 2)
        session.adopt_journey(j)
        ui.journey = j
        ui.deck_open = false
        ui.removal_preview_uid = 0
        ui.camp_tab = "shop"
        ui.refresh()
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        await process_frame
        settle()
        var target := j.deck[1 if i == 0 else 0]
        var view := RemovalPreview.describe(j,target.uid)
        var before := JourneySnapshot.encode(j)
        await click(ui.page.find_child("Remove",true,false))
        var face: CardStackView = ui.page.find_child("Card_%d" % target.uid,true,false)
        check(face != null and not face.disabled and face.stack_count == view["copies_before"],"Removal chooser uses actual grouped card faces")
        if i == 0: await picture("removal-selector")
        await click(face,[0.08,0.5,0.92][i])
        check(ui.removal_preview_uid == target.uid and JourneySnapshot.encode(j) == before,"Three window ratios and face-edge clicks open comparison without removing a card")
        var selected: TrainerActionCard = ui.page.find_child("RemovalCard",true,false)
        check(selected.definition["name"] == view["card"]["name"] and selected.definition["uid"] == target.uid,"Confirmation shows the exact selected card and upgrade")
        check(ui.page.find_child("RemovalCopies",true,false).text.contains("%d → %d" % [view["copies_before"],view["copies_after"]]) and ui.page.find_child("RemovalDeck",true,false).text.contains("%d → %d" % [view["before"],view["after"]]),"Copy and permanent deck changes include every actual instance")
        check(ui.page.find_child("RemovalGold",true,false).text.contains("%d → %d" % [j.gold,view["gold_after"]]),"Gold change uses the actual merchant removal quote")
        for k in view["coverage"].size():
            check(ui.page.find_child("Removal_attack_%d" % k,true,false).text.ends_with("%d → %d" % [view["coverage"][k]["attack"][0],view["coverage"][k]["attack"][1]]),"Every opponent's displayed attack coverage matches the hypothetical deck")
        if i == 2:
            check(ui.page.find_child("RemovalWarning",true,false).text.begins_with("직접 공격 소실"),"The last effective attack receives a visible warning without an invented prohibition")
            await picture("removal-last-attack")
        await click(ui.deck_close)
        check(ui.removal_preview_uid == target.uid and JourneySnapshot.encode(j) == before,"Confirmation blocks underlying deck close and camp inputs")
        await enter_key()
        check(JourneySnapshot.encode(j) == before,"Enter cannot accidentally confirm removal")
        await click(ui.page.find_child("RemovalCancel",true,false))
        check(ui.removal_preview_uid == 0 and ui.deck_open and JourneySnapshot.encode(j) == before,"Cancel returns to the chooser without gold or action changes")
        await click(ui.page.find_child("Card_%d" % target.uid,true,false))
        await escape()
        check(ui.removal_preview_uid == 0 and ui.deck_open and JourneySnapshot.encode(j) == before,"Esc closes one level without removing a card")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == before,"Browsing and cancellation preserve the exact saved merchant checkpoint")
        await click(ui.page.find_child("Card_%d" % target.uid,true,false))
        await click(ui.page.find_child("RemovalConfirm",true,false),[0.08,0.5,0.92][i])
        check(not ui.deck_open and ui.removal_preview_uid == 0 and j.deck.size() == view["after"] and j.gold == view["gold_after"] and not j.deck.has(target),"Confirmation removes exactly the selected instance and spends the previewed quote once")
        check(ui.page.find_child("Remove",true,false).disabled and j.step not in j.rested_steps,"Merchant allowance is consumed while the main camp action stays available")
        saved = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Actual confirmed removal autosaves every card, stock, gold and remaining camp action")
    # Explicit stale-confirmation boundary: the public action must recheck funds.
    var j := RemovalFixture.make()
    session.adopt_journey(j)
    ui.journey = j
    ui.refresh()
    await process_frame
    await click(ui.page.find_child("Remove",true,false))
    await click(ui.page.find_child("Card_%d" % j.deck[0].uid,true,false))
    j.gold = 0
    var before := JourneySnapshot.encode(j)
    await click(ui.page.find_child("RemovalConfirm",true,false))
    check(JourneySnapshot.encode(j) == before and ui.removal_preview_uid != 0,"A stale confirmation rechecks funds and cannot remove or charge")
    check(ui.page.find_child("RemovalConfirm",true,false).disabled and ui.page.find_child("RemovalReason",true,false).text.contains("비용이 부족"),"Unavailable confirmation explains why it cannot proceed")
    check(not ui.page.find_child("RemovalGold",true,false).text.contains("→ -"),"Insufficient funds never imply a possible negative gold balance")
    await click(ui.page.find_child("RemovalCancel",true,false))
    await escape()
    # Actual limits remain visible on the grouped selector.
    j.gold = 500
    var last := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == 1)[0] as BattleCardInstance
    j.deck.assign(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid != 1 or c.uid == last.uid))
    session.adopt_journey(j)
    ui.refresh()
    await click(ui.page.find_child("Remove",true,false))
    var protected: CardStackView = ui.page.find_child("Card_%d" % last.uid,true,false)
    check(protected.disabled and protected.tooltip_text.contains("마지막 기술"),"A member's last technique stays visibly unavailable")
    await escape()
    j.deck.resize(5)
    session.adopt_journey(j)
    ui.refresh()
    await click(ui.page.find_child("Remove",true,false))
    check(ui.page.find_children("Card_*","Button",true,false).all(func(card: Button): return card.disabled and card.tooltip_text.contains("최소 5장")),"A five-card deck disables every removal with the actual limit")
    print("REMOVAL_PREVIEW_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs; 3 Enter keys and 6 Esc keys")
    quit(0 if failures == 0 else 1)
