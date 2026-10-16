extends "res://tests/test_upgrade_preview_ui.gd"
func fixture(starters: Array[int]) -> TacticalJourney:
    var j := TacticalJourney.new(42,"field_kit",starters,true)
    j.battle.enemy().hp = 1 # Capture-boundary fixture; all decisions below use real UI.
    j.capture()
    j.settle()
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    j.party[0].held_item = "power_band"
    for c: BattleCardInstance in j.deck:
        if c.owner_uid == j.party[0].uid: c.upgraded = true
    if starters.size() == 3:
        for i in 7:
            j.deck.append(j._allocate_card(TacticalContent.skills_for(j.party[0])[0],j.party[0].uid))
        var injury := j._allocate_card("injury",0)
        injury.injury_owner_uid = j.party[0].uid
        j.deck.append(injury)
    return j
func adopt(j: TacticalJourney) -> void:
    root.get_node("BattleSession").adopt_journey(j)
    ui.journey = j
    ui.recruit_index = -1
    ui.refresh()
    await process_frame
    settle()
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/recruitment_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/recruitment_journey.json"))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = fixture([1,4,7])
    session.adopt_journey(ui.journey)
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    for i in 3:
        var j := fixture([1,4,7])
        await adopt(j)
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        await process_frame
        settle()
        var before := JourneySnapshot.encode(j)
        var change := RecruitmentPreview.describe(j,i)
        await click(ui.page.find_child("Recruit_%d" % i,true,false),[0.08,0.5,0.92][i])
        check(ui.recruit_index == i and JourneySnapshot.encode(j) == before,"Top/center/bottom opens the preview at three window ratios without changing the run")
        var face: TrainerActionCard = ui.page.find_child("RecruitCard_0",true,false)
        var caught: BattlePokemon = change["incoming"]
        check(face != null and face.definition["species_id"] == caught.species_id and face.definition["owner_name"] == caught.display_name,"Incoming cards show their real owner sprite and name")
        check(ui.page.find_child("RecruitDeckSummary",true,false).text.contains("%d → %d" % [change["before"],change["after"]]),"The displayed deck count matches actual consequences")
        if i == 0: await picture("recruitment-added")
        await click(ui.page.find_child("RecruitTab_removed",true,false))
        face = ui.page.find_child("RecruitCard_0",true,false)
        check(ui.recruit_tab == "removed" and face != null and face.definition["name"] == change["removed"][0]["name"],"Removed tab displays exact actual card faces, including upgrades")
        if i == 0:
            var scroll: ScrollContainer = ui.page.find_child("RecruitCards",true,false)
            var faces := scroll.find_children("RecruitCard_*","Button",true,false)
            check(not scroll.get_h_scroll_bar().visible and faces.size() < change["removed"].size(),"Duplicate departing copies fit without scrolling")
            check(faces.reduce(func(total: int, card: CardStackView): return total+card.stack_count,0) == change["removed"].size(),"Recruitment stacks preserve all departing copies, upgrades and injuries")
            await picture("recruitment-removed")
        await click(ui.actions.back()) # Release is underneath the modal.
        check(j.phase == TacticalJourney.CAPTURE and JourneySnapshot.encode(j) == before,"Preview blocks the release button underneath")
        await click(ui.page.find_child("RecruitCancel",true,false))
        check(ui.recruit_index == -1 and JourneySnapshot.encode(j) == before,"Cancel keeps the captured Pokémon and party decision pending")
        await click(ui.page.find_child("Recruit_%d" % i,true,false))
        await escape()
        check(ui.recruit_index == -1 and JourneySnapshot.encode(j) == before,"Esc closes only the preview and spends no resources")
        await click(ui.page.find_child("Recruit_%d" % i,true,false))
        await click(ui.page.find_child("RecruitConfirm",true,false),[0.92,0.5,0.08][i])
        check(ui.recruit_index == -1 and j.phase == TacticalJourney.REWARD and j.party[i] == caught and j.deck.size() == change["after"],"Confirmation applies the previewed party and deck exactly once")
        if i == 0: check("power_band" in j.held_inventory,"Confirmed replacement returns held equipment")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Confirmed recruitment autosaves the exact party, cards, costs and remaining rewards")
    var j := fixture([1])
    await adopt(j)
    await click(ui.page.find_child("Recruit_0",true,false))
    await click(ui.page.find_child("RecruitTab_removed",true,false))
    check(ui.page.find_child("RecruitCard_0",true,false) == null,"Joining a vacant slot shows no departing cards")
    await click(ui.page.find_child("RecruitConfirm",true,false))
    check(j.party.size() == 2 and j.party[0].species_id == 1 and j.party[0].held_item == "power_band","Vacant-slot confirmation appends without replacing the starter or equipment")
    print("RECRUITMENT_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs")
    quit(0 if failures == 0 else 1)
