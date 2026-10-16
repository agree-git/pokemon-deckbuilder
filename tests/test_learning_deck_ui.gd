extends "res://tests/test_upgrade_preview_ui.gd"
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/learning_deck_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/learning_deck_journey.json"))
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
    for i in quantities.size():
        var copies: int = quantities[i]
        var j := LearningDeckFixture.make(copies == 0,copies)
        session.adopt_journey(j)
        ui.journey = j
        ui.refresh()
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        var before := JourneySnapshot.encode(j)
        var face: TrainerActionCard = ui.page.find_child("LearningCard",true,false)
        check(face != null and face.key == "move_55" and face.definition["species_id"] == 7 and face.definition["owner_name"] == j.party[2].display_name,"Learning shows the new real card face, owner and sprite")
        var button: Button = ui.page.find_child("LearnSlot_1",true,false)
        var caption := " ".join(button.find_children("*","Label",true,false).map(func(l: Label): return l.text))
        check(caption.contains("새 카드 1장 추가") if copies == 0 else caption.contains("덱 사본 %d장 교체" % copies),"The selected slot clearly states fresh card versus replacing actual copies")
        check(button.tooltip_text.contains("덱 %d → %d장" % [j.deck.size(),j.deck.size()+(1 if copies == 0 else 0)]) and JourneySnapshot.encode(j) == before,"Tooltip shows exact deck change without learning or consuming resources")
        if i == 0: await picture("learning-new-card")
        if i == 2: await picture("learning-existing-copies")
        await click(button,[0.08,0.5,0.92][i])
        check(j.phase != TacticalJourney.LEARN and j.party[2].learned_skills[1] == "move_55","Top/center/bottom clicks work at three window ratios")
        var gained := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == j.party[2].uid and c.key == "move_55")
        check(gained.size() == maxi(1,copies) and j.deck.size() == before["run"]["deck"].size()+(1 if copies == 0 else 0),"Real UI learning grants one card only when the old source was absent")
        if copies == 0: check(not gained[0].upgraded,"A fresh card receives no inherited upgrade")
        else: check(gained[0].upgraded,"An actual upgraded old copy retains its upgrade")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Learning autosaves exact skills, card IDs, XP and pending rewards")
    var j := LearningDeckFixture.make()
    session.adopt_journey(j)
    ui.journey = j
    ui.refresh()
    await process_frame
    var count := j.deck.size()
    var skills := j.party[2].learned_skills.duplicate()
    await click(ui.actions.back())
    check(j.phase != TacticalJourney.LEARN and j.deck.size() == count and j.party[2].learned_skills == skills,"Declining learns and creates nothing")
    print("LEARNING_DECK_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs")
    quit(0 if failures == 0 else 1)
