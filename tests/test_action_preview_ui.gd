extends SceneTree
var native := false
var checks := 0
var failures := 0
var moves := 0
var clicks := 0
var ui: TacticalUI
var journey: TacticalJourney
const OUTPUT := "/tmp/pokemon-action-preview"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func point(control: Control,local: Vector2,click := false) -> void:
    var at := root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    moves += 1
    if click: clicks += 1
    if native:
        at += Vector2(root.position)
        print("OS_CLICK " if click else "OS_MOVE ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.22).timeout
    else:
        var motion := InputEventMouseMotion.new()
        motion.position = at
        root.push_input(motion)
        if click:
            for down: bool in [true,false]:
                var event := InputEventMouseButton.new()
                event.position = at
                event.button_index = MOUSE_BUTTON_LEFT
                event.pressed = down
                root.push_input(event)
        await process_frame
    UiMotion.finish_tree(ui)
    await process_frame
func fixture() -> void:
    if is_instance_valid(ui): ui.free()
    journey = TacticalJourney.new(42,"field_kit",[1,4,7],true)
    journey.enter_next()
    var b := journey.battle
    b.party[2].hp = maxi(1,b.party[2].hp-3)
    b.party[2].held_item = "relay_ribbon"
    b.relics.append_array(["switch_power","relay_cell"])
    b.powers["relay"] = 1
    b.energy = 4
    b.hand.assign([BattleCardInstance.new(9100,"move_33",b.party[2].uid),BattleCardInstance.new(9101,"guard",0),BattleCardInstance.new(9102,"potion_card",0),BattleCardInstance.new(9103,"shield_strike",0)])
    b.enemy().block = 0
    var damage := int(b.card_view(b.hand[0])["preview_damage"])
    b.enemy().hp = damage+floori(b.enemy().max_hp*0.25)
    ui = TacticalUI.new()
    ui.battle = b
    ui.run_mode = true
    ui.run_journey = journey
    ui.run_biome = journey.biome()
    ui.run_background = BattleBackdrops.for_stop(journey.current(),journey.biome())
    ui.run_title = journey.progress_title()
    ui.capture_status = func(): return {"wild":true,"balls":journey.balls,"reason":journey.capture_reason(),"help":journey.capture_help()}
    root.add_child(ui)
    await process_frame
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
    await process_frame
func picture() -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUTPUT.path_join("card-hover-preview.png")) == OK,"Save real 1920x1080 forecast capture")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
        root.size = dimensions
        await create_timer(0.1).timeout
        await fixture()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.15).timeout
        await point(ui,Vector2(1900,80))
        var before := JourneySnapshot.encode(journey)
        var card: TrainerActionCard = ui.trainer_buttons[9100]
        await point(card,card.visible_point())
        check(root.gui_get_hovered_control() == card,"Pointer reaches the actual card at "+str(dimensions))
        check(ui.action_preview.visible,"Hover shows an immediate outcome forecast")
        check(ui.action_preview.title.text.contains("자동 교대"),"Other owner is explicitly identified as an automatic switch")
        check(ui.action_preview.result["target_after"]["hp"] == floori(journey.battle.enemy().max_hp*0.25),"The forecast uses real post-switch attack damage")
        check(ui.action_preview.capture.text.contains("포획 가능"),"The remaining HP/energy and balls allow capture")
        check(ui.action_preview.enemy_forecast.visible,"Enemy HP bar shows the damage portion")
        check(not ui.action_preview.ally_forecast.visible,"A bench owner's health is never overlaid on the current ally's bar")
        check(JourneySnapshot.encode(journey) == before,"Hover never changes journey, RNG, hand, resources or statistics")
        var area := ui.action_preview.get_rect()
        var clear_hand := true
        for button: TrainerActionCard in ui.trainer_buttons.values(): clear_hand = clear_hand and not area.intersects(button.face.get_global_rect())
        check(clear_hand and not area.intersects(ui.ally_label.get_rect()) and not area.intersects(ui.enemy_label.get_rect()),"Temporary panel clears actual enlarged card faces and both HP names")
        if dimensions == Vector2i(1920,1080): await picture()
        await point(ui,Vector2(1900,80))
        check(not ui.action_preview.visible and not ui.action_preview.enemy_forecast.visible,"Leaving the hand removes forecasts")
        await point(card,card.visible_point())
        await point(ui.help_button,ui.help_button.size/2,true)
        check(ui.help_panel.visible and not ui.action_preview.visible,"Opening help clears the forecast")
        ui._close_overlays(true)
        await point(ui,Vector2(1900,80))
        card = ui.trainer_buttons[9100]
        await point(card,card.visible_point())
        var expected := ui.action_preview.result.duplicate(true)
        await point(card,card.visible_point(),true)
        check(not journey.battle.hand.any(func(c: BattleCardInstance): return c.uid == 9100),"A hovered card is played exactly once")
        check(not ui.action_preview.visible,"Card execution clears the forecast during playback")
        ui.finish_presentation()
        check(journey.battle.enemy().hp == expected["target_after"]["hp"] and journey.battle.energy == expected["energy_after"],"Real click commits the displayed HP/energy result")
        check(BattleFrame.member(journey.battle.active()) == expected["actor_after"],"Full actor state including friendship matches the actual click")
    # User-adjusted floors move the HUD. Check the real bounds of every HUD
    # element, including currently hidden shields, in all 48 background cells.
    var descriptors: Array[Dictionary] = []
    descriptors.assign(ui.catalog.biomes)
    for group: String in ["elite","champions"]:
        for room: Dictionary in BattleBackdrops.data()[group].values(): descriptors.append(room)
    descriptors.append(BattleBackdrops.data()["fallback_champion"])
    var unchanged := JourneySnapshot.encode(journey)
    for descriptor: Dictionary in descriptors:
        ui.stage.canvas.set_backdrop(descriptor)
        ui._position_combat_hud()
        for item: Dictionary in ui._hud_positions:
            check(not ui.action_preview.get_rect().intersects(item["node"].get_rect()),"Forecast clears every movable HP/shield/status element in "+str(descriptor))
    check(JourneySnapshot.encode(journey) == unchanged,"Background/HUD preview checks cannot mutate the run")
    ui.free()
    print("ACTION_PREVIEW_UI native=",native,": ",checks," checks, ",failures," failures; ",moves," pointer moves, ",clicks," clicks")
    quit(1 if failures else 0)
