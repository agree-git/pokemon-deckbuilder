extends "res://tests/test_campaign_ui.gd"
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/pokemon-friendship/"+label+".png")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.14).timeout
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-friendship")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var j := TacticalJourney.new(2026,"field_kit",[133,172,298],true)
    # Controlled pre-level-up camp fixture. Battles below use public GUI actions.
    for p: BattlePokemon in j.party:
        p.level = 15
        p.progression_initialized = false
        TacticalGrowth.initialize(p)
        p.experience = TacticalGrowth.experience_floor(16,p.species_id)-0.1
        p.friendship = 215
    j.deck.assign(TacticalContent.starting_deck(j.party))
    j._next_card_uid = j.deck.size()+1
    j.battle.start_with(j.party,j.deck,j.route.opponents(0),2026,j.relic,true,j.relics)
    j.battle.full_type_chart = true
    j.phase = TacticalJourney.MAP
    j.step = 1
    j.enter_next()
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/friendship_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/friendship_ui_journey.json"))
    session.adopt_journey(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.page.find_child("Growth_133",true,false).text.contains("친밀 215/220"),"An eligible party member displays its threshold progress compactly")
    var before := j.party.map(func(p: BattlePokemon): return p.friendship)
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.12).timeout
        var value: String = "day" if i == 1 else "night"
        var button: Button = ui.page.find_child("Time_"+value,true,false)
        check(not button.disabled and button.tooltip_text.contains("블래키"),"The desired time and its branch are visible at each window ratio")
        await click(button)
        check(j.current_time() == value and ui.page.find_child("Time_"+value,true,false).disabled,"Real pointer selection saves the displayed time")
        check(j.party.map(func(p: BattlePokemon): return p.friendship) == before and j.rested_steps.is_empty(),"Changing time neither farms friendship nor consumes rest")
    root.size = Vector2i(1280,720)
    await process_frame
    await picture("camp-time")
    await click(ui.rest_button)
    check(j.party.all(func(p: BattlePokemon): return p.friendship == 220) and j.party[0].species_id == 133,"Rest reaches the threshold but still waits for a real level-up")
    check(ui.page.find_child("Growth_133",true,false).text.contains("220/220"),"Rest refreshes the visible friendship value")
    var checkpoint := JourneySnapshot.encode(j)
    await click(ui.rest_button)
    check(JourneySnapshot.encode(j) == checkpoint,"Disabled rest cannot grant another friendship reward")
    var resumed: TacticalJourney = session.get("save_store").load_journey()
    check(resumed != null and JourneySnapshot.encode(resumed) == checkpoint and resumed.current_time() == "night","Real camp input autosaves friendship and chosen night")
    await click(ui.actions[0])
    await click(ui.actions[0])
    settle()
    check(j.phase == TacticalJourney.BATTLE and j.current_time() == "night","Departure carries the selected time into the next wild battle")
    var count := 0
    for i in 200:
        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var state := j.battle.snapshot()
        await battle_action(TacticalPolicy.action(j.battle))
        check(j.battle.snapshot() != state,"An actual hand, switch or end-turn input advances combat")
        count += 1
    check(j.battle.phase == TacticalBattle.WON and count > 0,"Complete a real battle without fabricating its result")
    await click(ui.battle_ui.result_next)
    check(j.party[0].species_id == 197 and j.party[1].species_id == 25 and j.party[2].species_id == 183,"The saved night and level-up evolve Eevee, Pichu and Azurill through normal settlement")
    check(j.party.all(func(p: BattlePokemon): return p.friendship == 230 and p.level == 16),"Victory plus one earned level contributes exactly ten friendship")
    var after := j.party.map(func(p: BattlePokemon): return p.friendship)
    while j.phase == TacticalJourney.LEARN:
        await click(ui.actions.back())
    check(j.phase == TacticalJourney.REWARD and j.growth_reports.all(func(r: Dictionary): return not r["evolutions"].is_empty()),"All automatic evolutions reach the existing growth summary")
    check(ui.page.find_children("*","Label",true,false).any(func(n: Label): return n.text.contains("블래키")),"The result visibly names the new Eevee form")
    await picture("night-evolution")
    resumed = session.get("save_store").load_journey()
    check(resumed != null and JourneySnapshot.encode(resumed) == JourneySnapshot.encode(j),"Post-evolution cards, moves, XP and friendship autosave exactly")
    await click(ui.actions.back())
    check(j.party.map(func(p: BattlePokemon): return p.friendship) == after,"Reward and map transitions do not repeat the friendship award")
    print("FRIENDSHIP_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs, ",keys," key inputs")
    quit(0 if failures == 0 else 1)
