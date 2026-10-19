extends SceneTree
var checks := 0
var failures := 0
var clicks := 0
var keys := 0
const OUT := "/tmp/pokemon-ending-credits"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func wait_ui() -> void:
    await create_timer(.4).timeout
    await process_frame
    await process_frame
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol);keys+=1
    await wait_ui()
func click(control: Control) -> void:
    if not is_instance_valid(control): check(false,"Click target exists");return
    var p := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(p.x)," ",roundi(p.y));clicks+=1
    await wait_ui()
func shot(filename: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUT.path_join(filename))==OK,"Screenshot saved")
func labels(node: Node) -> String:
    var result: String = node.text+"\n" if node is Label else ""
    for child: Node in node.get_children(): result += labels(child)
    return result
func run() -> void:
    if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().begins_with(OUT): quit(2);return
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var state: Dictionary=FileAccess.open("/tmp/pokemon-final-20261019/review/final.bin",FileAccess.READ).get_var()
    check(JourneySnapshot.validate(state),"Previously completed real public-action campaign is valid")
    var j := JourneySnapshot.restore(state)
    var session := root.get_node("BattleSession")
    session.adopt_journey(j)
    var before := JourneySnapshot.encode(j)
    var saved := FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await wait_ui()
    var credits=ui.credits
    check(is_instance_valid(credits) and j.phase==TacticalJourney.CLEARED,"Full campaign ending automatically opens credits")
    if not is_instance_valid(credits): quit(1);return
    check(labels(credits).contains("DO\n") and not labels(credits).contains("agree-git"),"Approved creator name DO")
    check(labels(credits).contains("69승") and labels(credits).contains("명예의 전당"),"Real completion totals displayed")
    for pokemon: BattlePokemon in j.party:check(labels(credits).contains(pokemon.display_name),"Actual final companion shown")
    check(credits.viewport_panel.clip_contents and credits.viewport_panel.get_rect().end.x<=1920,"Roll is clipped within screen")
    await click(ui.actions[0])
    check(j.phase==TacticalJourney.CLEARED and JourneySnapshot.encode(j)==before,"Credits blocks click on underlying restart")
    await key("space")
    var at: float=credits.elapsed_distance
    await wait_ui()
    check(credits.paused and credits.elapsed_distance==at,"Actual Space pauses automatic roll")
    await key("Down")
    check(credits.elapsed_distance>at and credits.paused,"Manual scroll works while paused")
    credits._advance(-credits.travel_distance)
    await shot("01-ending.png")
    await click(credits.pause_button)
    check(not credits.paused and credits.elapsed_distance>0,"Actual button resumes roll")
    credits._advance(credits.travel_distance)
    check(credits.finished and credits.pause_button.text=="처음부터","Natural end stops and offers replay")
    var last: Label=credits.roll.get_child(credits.roll.get_child_count()-1)
    check(credits.viewport_panel.get_global_rect().encloses(last.get_global_rect()),"Final thanks remains fully visible")
    await shot("02-thank-you.png")
    await click(credits.pause_button)
    check(not credits.finished and credits.elapsed_distance<100,"Finished roll can replay")
    await key("Escape")
    check(not is_instance_valid(ui.credits) and not is_instance_valid(ui.pause_menu),"Esc returns to results without opening menu")
    ui.refresh();await wait_ui()
    check(not is_instance_valid(ui.credits),"Results refresh does not replay automatically")
    await click(ui.find_child("ReplayCredits",true,false))
    check(is_instance_valid(ui.credits),"Result replay button opens credits")
    await key("Return")
    check(not is_instance_valid(ui.credits),"Enter exits credits")
    check(JourneySnapshot.encode(j)==before and saved==FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH),"Credits/replay/skip preserve exact state, RNG and saved bytes")
    await click(ui.actions[2])
    var menu: MainMenu=current_scene
    check(not is_instance_valid(menu.continue_button),"Completed run remains unavailable for continuation")
    await click(menu.find_child("OpenCredits",true,false))
    check(is_instance_valid(menu.credits),"Title credits button opens independent credits")
    await shot("03-title-credits.png")
    await click(menu.credits.close_button)
    check(not is_instance_valid(menu.credits),"Title credits close button works")
    menu.free();current_scene=null
    for phase: String in [TacticalJourney.CLEARED,TacticalJourney.FAILED]:
        var sample := TacticalJourney.new(2026,"field_kit",[1,4,7],phase!=TacticalJourney.CLEARED)
        sample.phase=phase
        var screen: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
        screen.journey=sample;root.add_child(screen);await wait_ui()
        check(not is_instance_valid(screen.credits),"Short clear / failed campaign does not trigger ending")
        screen.free()
    for node_name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(node_name).stop_all()
    await wait_ui()
    print("NATIVE_ENDING ",checks," checks / ",failures," failures / ",clicks," clicks / ",keys," keys")
    quit(0 if failures==0 else 1)
