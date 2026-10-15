extends "res://tests/test_journey_ui.gd"
var travel_checked := false
func begin_movement(button: Button) -> void:
    settle()
    if native:
        var local := button.size/2
        var at := Vector2(root.position)+root.get_final_transform()*(button.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.12).timeout
    else:
        TacticalUIPlayer.click(self,button)
        await process_frame
    check(ui.travelling and is_instance_valid(ui.travel),"Map entry starts real walking animation")
    var step := ui.journey.step
    var battle := ui.journey.battle
    # Input over the old deck button is blocked during movement.
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(ui.deck_button.get_global_transform_with_canvas()*(ui.deck_button.size/2))
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.12).timeout
    else:
        TacticalUIPlayer.click(self,ui.deck_button)
        await process_frame
    check(not ui.deck_open and ui.journey.step == step and ui.journey.battle == battle,"Walking blocks underlying controls and duplicate progression")
    if DisplayServer.get_name() != "headless":
        var prior := root.size
        root.size = Vector2i(1920,1080)
        await process_frame
        await RenderingServer.frame_post_draw
        var output := "/workspace/.cloud-setup/pokemon-deckbuilder/previews/camp_travel.png"
        check(root.get_texture().get_image().save_png(output) == OK,"Capture real movement frame")
        root.size = prior
    await create_timer(JourneyTravel.DURATION+0.1).timeout
    check(not ui.travelling and ui.travel == null and ui.journey.phase == TacticalJourney.REST,"Walking finishes naturally at camp")
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = TacticalJourney.new(2026,"seed_relay",[1,4,7],true)
    root.add_child(ui)
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var kinds: Dictionary = {}
    for i in ui.journey.route.stops.size():
        var node := ui.journey.route.stops[i]
        if node["kind"] != "rest": continue
        var kind: String = node["camp"].get("id",node["camp"]["kind"])
        if kinds.has(kind): continue
        kinds[kind] = true
        # Location fixture only: all services and movement use actual UI input.
        ui.journey.phase = TacticalJourney.MAP
        ui.journey.step = i
        ui.refresh()
        await process_frame
        if not travel_checked:
            await verify_page()
            await begin_movement(ui.actions[0])
            travel_checked = true
        else: await click(ui.actions[0])
        check(ui.journey.phase == TacticalJourney.REST,"Arrival opens correct camp")
        await click(ui.rest_button)
        check(ui.journey.step in ui.journey.rested_steps,"Rest remains available for every random arrival")
        if kind == "merchant":
            await click(ui.camp_tabs["shop"])
            var count := ui.journey.balls
            var gold := ui.journey.gold
            await click(ui.page.find_child("Buy_ball",true,false))
            check(ui.journey.balls == count+1 and ui.journey.gold == gold-35,"Random merchant purchase through real input")
            await capture("camp_merchant")
        else:
            check(not ui.camp_tabs.has("shop"),"Merchant shop is absent at other encounters")
            await click(ui.camp_tabs["encounter"])
            await capture("camp_"+kind)
            if kind != "quiet":
                await click(ui.encounter_buttons[1] if kind == "spring" else ui.encounter_buttons[0])
                check(ui.journey.camp()["resolved"] and ui.encounter_buttons.is_empty(),"Event choice resolves once and removes choice buttons")
                await click(ui.camp_tabs["bag"])
                await click(ui.camp_tabs["encounter"])
                check(ui.journey.camp()["resolved"] and ui.encounter_buttons.is_empty(),"Tab changes cannot reroll event")
        await click(ui.camp_tabs["loot"])
        await capture("camp_loot")
        await click(ui.actions[0])
        check(ui.journey.phase == TacticalJourney.MAP and ui.journey.step == i+1,"Departure advances exactly one stop")
        if kinds.size() == 6: break
    check(kinds.size() == 6 and travel_checked,"Exercise all random camp encounters and movement")
    print("CAMP_UI: ",checks," checks, ",failures," failures; ",clicks," pointer inputs; OS input ",native)
    quit(0 if failures == 0 else 1)
