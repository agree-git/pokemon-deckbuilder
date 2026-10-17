extends SceneTree
const Policy = preload("/workspace/.repo-cleanup/tactical_policy.gd")
var checks := 0
var failures := 0
var clicks := 0
var native := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    if current_scene is TacticalJourneyUI and is_instance_valid(current_scene.battle_ui): current_scene.battle_ui.finish_presentation()
    UiMotion.finish_tree(current_scene)
    UiMotion.finish_tree(current_scene)
func click(control: Control) -> void:
    settle()
    await process_frame
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    var at := root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    if native:
        print("OS_CLICK ",roundi(at.x+root.position.x)," ",roundi(at.y+root.position.y))
        await create_timer(0.22).timeout
    else:
        var motion := InputEventMouseMotion.new()
        motion.position = at
        root.push_input(motion)
        for down in [true,false]:
            var event := InputEventMouseButton.new()
            event.position = at
            event.button_index = MOUSE_BUTTON_LEFT
            event.pressed = down
            root.push_input(event)
        await process_frame
    clicks += 1
    settle()
func shot(label: String) -> void:
    if not native: return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("/workspace/.repo-cleanup/"+label+".png") == OK,"Capture "+label)
func wait_journey() -> void:
    for tick in 650:
        if current_scene is TacticalJourneyUI: return
        await create_timer(0.01).timeout
    check(false,"Travel reaches campaign scene")
func run() -> void:
    native = DisplayServer.get_name() != "headless"
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    root.get_node("Preferences").battle_speed = 2.0
    var session := root.get_node("BattleSession")
    session.has_journey = false
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.15).timeout
    var menu := current_scene as MainMenu
    check(menu != null and menu.full_campaign,"Main entry is full campaign menu")
    await shot("main-title")
    await click(menu.start_button)
    check(menu.mode == "starters" and menu.confirm_button.disabled,"New game opens empty starter selection")
    for id in [1,4,7]: await click(menu.species_buttons[id])
    check(menu.selection.size() == 3 and not menu.confirm_button.disabled,"Three starters can start")
    await click(menu.confirm_button)
    check(menu.starting and is_instance_valid(menu.departure),"Departure loading exists")
    await wait_journey()
    settle()
    var ui := current_scene as TacticalJourneyUI
    if ui == null:
        quit(1)
        return
    var j := ui.journey
    check(j.full_campaign and j.party.size() == 3 and j.phase == TacticalJourney.BATTLE,"Campaign battle opens with chosen party")
    check(j.route.stops.filter(func(s: Dictionary): return s["kind"] != "rest").size() == 69,"69 battle stops retained")
    check(j.route.stops.filter(func(s: Dictionary): return s["kind"] == "rest").size() == 68,"68 camp stops retained")
    await process_frame
    settle()
    await shot("main-battle")
    for action_index in 90:
        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var action := Policy.action(j.battle)
        var control: Control
        match action[0]:
            "card": control = ui.battle_ui.trainer_buttons[action[1]]
            "switch":
                for i in j.party.size():
                    if j.party[i].uid == action[1]: control = ui.battle_ui.party_buttons[i]
            _: control = ui.battle_ui.end_button
        await click(control)
        await process_frame
    check(j.battle.phase == TacticalBattle.WON,"Legal UI actions win first battle")
    if j.battle.phase != TacticalBattle.WON:
        quit(1)
        return
    await click(ui.battle_ui.result_next)
    for tick in 30:
        if j.phase == TacticalJourney.REST: break
        if j.phase == TacticalJourney.LEARN: await click(ui.actions.back())
        elif j.phase in [TacticalJourney.REWARD,TacticalJourney.MAP]: await click(ui.actions[0])
        else: await process_frame
        await create_timer(0.05).timeout
    check(j.phase == TacticalJourney.REST,"Reward and travel reach camp")
    settle()
    await shot("main-camp")
    check(session.checkpoint().is_empty(),"Autosave succeeds")
    var before := JourneySnapshot.encode(j)
    var restored: TacticalJourney = session.save_store.load_journey()
    check(restored != null and JourneySnapshot.encode(restored) == before,"Disk restore preserves run and RNG")
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    menu = current_scene as MainMenu
    check(is_instance_valid(menu.continue_button),"Title offers Continue")
    await click(menu.continue_button)
    await wait_journey()
    ui = current_scene as TacticalJourneyUI
    check(ui != null and ui.journey == j and JourneySnapshot.encode(j) == before,"Continue preserves same camp")
    var active := current_scene
    current_scene = null
    active.free()
    root.get_node("GameAudio").stop_all()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.2).timeout
    print("MAIN_CLEANUP native=",native,": ",checks," checks, ",failures," failures; ",clicks," clicks")
    quit(0 if failures == 0 else 1)
