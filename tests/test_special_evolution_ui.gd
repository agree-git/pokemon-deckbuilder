extends "res://tests/test_friendship_ui.gd"
func click(control: Control) -> void:
    await process_frame
    settle()
    if control is TrainerActionCard:
        ui.battle_ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        settle()
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.22).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
    clicks += 1
    settle()
    await process_frame
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.18).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/pokemon-special/"+label+".png")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.14).timeout
func setup(starters: Array[int], levels: Array[int]) -> TacticalJourney:
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",starters,true)
        if j.route.stops[1]["camp"]["kind"] != "merchant": continue
        for i in j.party.size():
            var p := j.party[i]
            p.level = levels[i]
            p.progression_initialized = false
            TacticalGrowth.initialize(p)
            p.experience = TacticalGrowth.experience_floor(p.level+1,p.species_id)-0.1
        j.deck.assign(TacticalContent.starting_deck(j.party))
        j._next_card_uid = j.deck.size()+1
        j.battle.start_with(j.party,j.deck,j.route.opponents(0),seed_value,j.relic,true,j.relics)
        j.battle.full_type_chart = true
        j.phase = TacticalJourney.MAP
        j.step = 1
        j.enter_next()
        return j
    check(false,"Find a seeded merchant fixture")
    return null
func adopt(j: TacticalJourney, name: String) -> void:
    if is_instance_valid(ui): ui.free()
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/special_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/special_ui_"+name+".json"))
    session.adopt_journey(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    settle()
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.18).timeout
func win_next(j: TacticalJourney) -> void:
    await click(ui.actions[0])
    await click(ui.actions[0])
    settle()
    for i in 300:
        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var before := j.battle.snapshot()
        await battle_action(TacticalPolicy.action(j.battle))
        check(j.battle.snapshot() != before,"Actual pointer/key actions advance a conditional evolution battle")
    check(j.battle.phase == TacticalBattle.WON,"Win the real battle without overriding HP, resources or outcome")
    await click(ui.battle_ui.result_next)
    while j.phase == TacticalJourney.LEARN: await click(ui.actions.back())
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-special")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var j := setup([236,265,349],[19,6,15])
    j.gold = 500
    await adopt(j,"branches")
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var expected := 266 if ((SpecialEvolution.personality(j.party[1])>>16)%10) < 5 else 268
    var personality := j.party[1].evolution_personality
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.12).timeout
        await click(ui.page.find_child("SpecialEvolution",true,false))
        var target: int = [106,237,107][i]
        await click(ui.page.find_child("Evolution_236_"+str(target),true,false))
        check(SpecialEvolution.choice(j.party[0]) == target and ui.page.find_child("Evolution_236_"+str(target),true,false).disabled,"Three window ratios select and show the chosen evolution")
        check(ui.page.find_child("SpecialSummary_236",true,false).text.contains(["시라소몬","카포에라","홍수몬"][i]),"Preview names the chosen level-up evolution")
        check(j.party[1].evolution_personality == personality and j.rested_steps.is_empty(),"Training and previews do not reroll personality or spend rest")
        await key("Escape")
        check(not ui.special_open,"Esc closes preparation without leaving camp")
    root.size = Vector2i(1280,720)
    await process_frame
    await click(ui.page.find_child("SpecialEvolution",true,false))
    await picture("preparation")
    var checkpoint := JourneySnapshot.encode(j)
    await click(ui.actions[0])
    check(JourneySnapshot.encode(j) == checkpoint and j.phase == TacticalJourney.REST,"Preparation modal blocks the underlying departure button")
    if ui.special_open: await key("Escape")
    await click(ui.camp_tabs["shop"])
    for i in 3: await click(ui.page.find_child("Buy_blue_pokeblock",true,false))
    check(j.gold == 320 and j.quantity("blue_pokeblock") == 3 and j.shop_stock["blue_pokeblock"] == 0,"The real merchant sells three finite beauty foods at their visible price")
    await picture("beauty-stock")
    await click(ui.camp_tabs["bag"])
    for i in 3:
        await click(ui.page.find_child("Bag_blue_pokeblock",true,false))
        check(ui.page.find_child("Use_blue_pokeblock_0",true,false).disabled and not ui.page.find_child("Use_blue_pokeblock_2",true,false).disabled,"Feeding popup selects only Feebas")
        if i == 2: await picture("beauty-target")
        await click(ui.page.find_child("Use_blue_pokeblock_2",true,false))
    check(j.party[2].beauty == 180 and j.party[2].species_id == 349 and j.quantity("blue_pokeblock") == 0,"Three target clicks reach the threshold while waiting for level-up")
    check(ui.page.find_child("Growth_349",true,false).text.contains("아름다움 180/170"),"The party displays beauty progress compactly")
    var saved: TacticalJourney = root.get_node("BattleSession").get("save_store").load_journey()
    check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Training, fixed personality, beauty and sold stock autosave together")
    await win_next(j)
    check(j.party[0].species_id == 107 and j.party[1].species_id == expected and j.party[2].species_id == 350,"A real earned level applies trained, personality and beauty evolutions together")
    check(j.party[0].evolution_choice == 107 and j.party[1].evolution_personality == personality and j.party[2].beauty == 180,"Evolution retains all conditional preparation")
    await picture("conditional-results")
    var shed := setup([290,4],[19,19])
    await adopt(shed,"shedinja")
    await click(ui.page.find_child("SpecialEvolution",true,false))
    check(ui.page.find_child("SpecialSummary_290",true,false).text.contains("현재 파티 2/3"),"Nincada preparation exposes actual free slots and ball requirements")
    await key("Escape")
    var balls := shed.balls
    var birth := shed._next_pokemon_uid
    await win_next(shed)
    check(shed.party.size() == 3 and shed.party[0].species_id == 291 and shed.party[2].species_id == 292 and shed.balls == balls-1,"Ninjask evolution adds Shedinja to the free slot and consumes exactly one ball")
    check(shed.party[2].uid == birth and shed.deck.any(func(c: BattleCardInstance): return c.owner_uid == birth),"The added member receives its own usable technique cards")
    check(ui.page.find_children("*","Label",true,false).any(func(n: Label): return n.text.contains("껍질몬 합류")),"Growth summary visibly announces the additional member")
    await picture("shedinja-result")
    saved = root.get_node("BattleSession").get("save_store").load_journey()
    check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(shed),"The new member, cards and consumed ball are automatically persisted")
    print("SPECIAL_EVOLUTION_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs, ",keys," key inputs")
    quit(0 if failures == 0 else 1)
