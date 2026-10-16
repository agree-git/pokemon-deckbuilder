extends "res://tests/test_upgrade_preview_ui.gd"
func faces() -> Array[Node]:
    return ui.page.find_children("DeckStack_*" if ui.deck_action.is_empty() else "Card_*","Button",true,false)
func count(cards: Array) -> int:
    return cards.reduce(func(total: int, card: CardStackView): return total+card.stack_count,0)
func fixture() -> TacticalJourney:
    var j := RemovalFixture.make()
    var injury := j._allocate_card("injury",0)
    injury.injury_owner_uid = 1
    j.deck.append(injury)
    return j
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/deck_filters_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/deck_filters_journey.json"))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = fixture()
    session.adopt_journey(ui.journey)
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    for i in 3:
        var j := fixture()
        session.adopt_journey(j)
        ui.journey = j
        ui.deck_open = false
        ui.camp_tab = "rest"
        ui.refresh()
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        await process_frame
        settle()
        var before := JourneySnapshot.encode(j)
        await click(ui.deck_button)
        check(count(faces()) == j.deck.size() and faces().all(func(card: Button): return card.disabled),"Inspection shows the complete deck as passive card stacks")
        check(ui.page.find_children("DeckFilter_*","Button",true,false).size() == 5,"All/common and each actual party member have a filter")
        for uid: int in [0,1,4,7,-1]:
            await click(ui.page.find_child("DeckFilter_%d" % uid,true,false),[0.08,0.5,0.92][i])
            var expected := j.deck.filter(func(card: BattleCardInstance): return uid < 0 or card.owner_uid == uid).size()
            check(ui.deck_owner_filter == uid and count(faces()) == expected and faces().all(func(card: CardStackView): return uid < 0 or card.definition["owner_uid"] == uid),"Each filter shows only its owner and preserves actual copy counts")
            check(JourneySnapshot.encode(j) == before,"Filtering cannot change cards, resources, camp allowance, stock, statistics or RNG")
        await click(ui.rest_button)
        check(JourneySnapshot.encode(j) == before and ui.deck_open,"Filtered browser blocks the camp action underneath")
        await escape()
        check(not ui.deck_open and ui.deck_owner_filter == -1,"Esc closes the browser and resets its transient filter")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == before,"Browsing never changes the saved checkpoint")
        await click(ui.page.find_child("Upgrade",true,false))
        check(ui.page.find_child("Card_%d" % j.deck[0].uid,true,false).disabled and ui.page.find_child("Card_%d" % j.deck.back().uid,true,false).disabled,"Already upgraded cards and injuries remain unselectable")
        await click(ui.page.find_child("DeckFilter_1",true,false))
        var target := j.deck[6]
        var twins := j.deck.filter(func(c: BattleCardInstance): return c.key == target.key and c.owner_uid == target.owner_uid)
        var face: CardStackView = ui.page.find_child("Card_%d" % target.uid,true,false)
        check(face.stack_count == 2 and face.tooltip_text.contains("1장만 강화") and not face.tooltip_text.contains("1장만 제거"),"A duplicate upgrade stack explicitly selects one copy for upgrading")
        if i == 0: await picture("upgrade-filtered-stack")
        await click(face,[0.08,0.5,0.92][i])
        check(ui.upgrade_preview_uid == target.uid and JourneySnapshot.encode(j) == before,"Face-edge clicks open the actual instance comparison at three window ratios")
        await click(ui.page.find_child("UpgradeCancel",true,false))
        check(ui.deck_owner_filter == 1 and ui.deck_open and count(faces()) == 3 and JourneySnapshot.encode(j) == before,"Cancelling a comparison returns to the same filtered card stacks")
        await click(ui.page.find_child("Card_%d" % target.uid,true,false))
        await click(ui.page.find_child("UpgradeConfirm",true,false),[0.08,0.5,0.92][i])
        check(target.upgraded and twins.filter(func(c: BattleCardInstance): return c.upgraded).size() == 1 and j.step in j.rested_steps,"Confirmation upgrades one selected UID, leaves its twin unchanged and consumes one camp action")
        saved = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"The exact single-instance upgrade autosaves")
        await click(ui.deck_button)
        await click(ui.page.find_child("DeckFilter_1",true,false))
        check(faces().size() == 3 and count(faces()) == 3 and faces().any(func(card: CardStackView): return card.definition["name"].ends_with(" +")),"Reopening shows the upgraded copy separately from the remaining plain copy")
        await click(ui.deck_close)
        check(not ui.deck_open,"The current close button stays usable after filter rebuilds")
        await click(ui.camp_tabs["shop"])
        before = JourneySnapshot.encode(j)
        await click(ui.page.find_child("Remove",true,false))
        await click(ui.page.find_child("DeckFilter_0",true,false))
        target = j.deck[1]
        face = ui.page.find_child("Card_%d" % target.uid,true,false)
        check(face.stack_count == 3 and face.tooltip_text.contains("1장만 제거"),"Merchant selection uses the same common-card filter with the correct removal action")
        await click(face)
        await click(ui.page.find_child("RemovalCancel",true,false))
        check(ui.deck_owner_filter == 0 and JourneySnapshot.encode(j) == before,"Cancelling removal preserves its filter, gold and exact run state")
        await click(ui.page.find_child("Card_%d" % target.uid,true,false))
        await click(ui.page.find_child("RemovalConfirm",true,false))
        check(not j.deck.has(target) and j.deck.filter(func(c: BattleCardInstance): return c.key == "guard" and not c.upgraded).size() == 2 and j.gold == 450,"Filtered removal prunes exactly one plain copy without removing its upgraded counterpart")
        saved = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Filtered removal autosaves the actual remaining deck and budget")
    # Valid empty-common boundary: owned techniques can fill a deck without shared cards.
    var j := fixture()
    j.deck.assign(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid != 0))
    session.adopt_journey(j)
    ui.journey = j
    ui.refresh()
    var before := JourneySnapshot.encode(j)
    await click(ui.deck_button)
    await click(ui.page.find_child("DeckFilter_0",true,false))
    var empty: Label = ui.page.find_child("DeckEmpty",true,false)
    check(faces().is_empty() and empty != null and empty.is_visible_in_tree() and empty.size.x > 700,"Empty filters show a readable explanation rather than phantom cards")
    check(JourneySnapshot.encode(j) == before,"An empty filter does not generate, remove or repair cards")
    if native: await picture("deck-empty-filter")
    await click(ui.deck_close)
    print("DECK_FILTERS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs; 3 Esc keys")
    quit(0 if failures == 0 else 1)
