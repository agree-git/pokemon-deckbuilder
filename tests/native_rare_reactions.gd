extends SceneTree
## Optional X11 interaction regression. Requires a separate test user profile.
const Support = preload("support/rare_fixture.gd")
var checks := 0
var failures := 0
var clicks := 0
var output_dir := OS.get_environment("RARE_REACTION_REVIEW_DIR")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control, ratio := Vector2(.5,.5)) -> void:
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*ratio))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(.28).timeout
func key(value: String) -> void:
    print("OS_KEY ",value)
    await create_timer(.3).timeout
func shot(id: int, phase: String) -> void:
    if output_dir.is_empty(): return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output_dir.path_join(str(id)+"-"+phase+".png")) == OK,"Screenshot "+phase)
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    if not output_dir.is_empty(): DirAccess.make_dir_recursive_absolute(output_dir)
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var seeds := {}
    for candidate in 5000:
        var id := RareEncounter.target(candidate)
        if not seeds.has(id): seeds[id] = candidate
    for id: int in [151,643,10169]:
        var j := Support.fixture(seeds[id])
        Support.enter(j)
        Support.ready_capture(j)
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        # Boundary fixture skips the already-tested intro; capture input is real.
        ui.battle_ui.finish_presentation()
        await create_timer(.3).timeout
        await key("c")
        ui.battle_ui.finish_presentation()
        await create_timer(.25).timeout
        check(j.rare_hunt["captured"] and ui.battle_ui.capture_quote.visible,"OS C captures rare and displays own reaction")
        await shot(id,"captured")
        await click(ui.battle_ui.result_next)
        for attempt in 32:
            if j.phase != TacticalJourney.LEARN: break
            await click(ui.actions.back())
        check(j.phase == TacticalJourney.CAPTURE and ui.page.find_child("RareCaptureQuote",true,false) != null,"Actual continue/learning clicks reach choice")
        await shot(id,"choice")
        if id == 643:
            await click(ui.page.find_child("ReleaseCapture",true,false))
        else:
            var before_preview := JourneySnapshot.encode(j)
            await click(ui.page.find_child("Recruit_0",true,false))
            await click(ui.page.find_child("RecruitCancel",true,false))
            check(JourneySnapshot.encode(j) == before_preview and ui.rare_reaction.is_empty(),"OS cancel leaves choice pending")
            await click(ui.page.find_child("Recruit_0",true,false))
            await click(ui.page.find_child("RecruitConfirm",true,false))
        var panel := ui.page.find_child("RareReactionPanel",true,false) as RareReactionPanel
        var event := "released" if id == 643 else "joined"
        check(panel != null and panel.event == event and panel.quote.text == RareCaptureReaction.line(id,event),"Actual choice opens correct species reaction")
        var chosen := JourneySnapshot.encode(j)
        await click(panel,Vector2(.05,.05))
        check(ui.page.find_child("RareReactionPanel",true,false) == panel and JourneySnapshot.encode(j) == chosen,"Backdrop click cannot alter or dismiss decision")
        await shot(id,event)
        if id == 151: await click(panel.continue_button)
        else: await key("Escape" if id == 643 else "Return")
        check(ui.is_inside_tree() and ui.rare_reaction.is_empty() and ui.page.find_child("RareReactionPanel",true,false) == null and JourneySnapshot.encode(j) == chosen,"Mouse/Escape/Enter acknowledges without replay or home navigation")
        check(id in root.get_node("BattleSession").profile.captured_ids,"Permanent capture retained after joined/released reaction")
        ui.free()
        await process_frame
    root.get_node("GameMusic").stop_music()
    root.get_node("GameAmbience").stop_ambience()
    root.get_node("GameCries").stop_all()
    root.get_node("GameAudio").stop_all()
    await create_timer(.2).timeout
    print("NATIVE_RARE_REACTIONS: ",checks," checks / ",failures," failures; ",clicks," clicks")
    quit(0 if failures == 0 else 1)
