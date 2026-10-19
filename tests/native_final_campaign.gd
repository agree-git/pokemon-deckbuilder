extends SceneTree
## Inspect terminal UI from the real69-win run, then restart the engine before a new run.
var checks:=0
var failures:=0
var clicks:=0
var keys:=0
var folder:=OS.get_environment("FINAL_CAMPAIGN_DIR")
var session:Node
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func focus() -> void:print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
func click(control:Control) -> void:
    check(is_instance_valid(control) and control.is_visible_in_tree() and not (control is BaseButton and control.disabled),"Visible OS click target exists")
    if not is_instance_valid(control):return
    var at:=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    focus();print("OS_CLICK ",roundi(at.x)," ",roundi(at.y));clicks+=1
    await create_timer(.45).timeout
func key(symbol:String) -> void:
    print("OS_MOVE 960 80");await create_timer(.2).timeout
    focus();print("OS_KEY ",symbol);keys+=1
    await create_timer(.4).timeout
func shot(label_text:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(label_text+".png"))==OK,"Screenshot "+label_text)
func labels(node:Node) -> String:
    var result:=""
    if node is Label:result=node.text+"\n"
    for child:Node in node.get_children():result+=labels(child)
    return result
func completed() -> void:
    var state:Dictionary=FileAccess.open(folder.path_join("final.bin"),FileAccess.READ).get_var()
    check(JourneySnapshot.validate(state),"Real completed public-action run snapshot validates")
    var j:=JourneySnapshot.restore(state)
    session.adopt_journey(j)
    check(session.save_notice.is_empty() and session.save_store.load_journey()==null,"Terminal marker blocks unfinished backup revival")
    var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.6).timeout
    var text:=labels(ui.page)
    check(j.phase==TacticalJourney.CLEARED and text.contains("69승") and text.contains("배지 8 / 8") and text.contains("사천왕 4 / 4") and text.contains("명예의 전당"),"Completed screen shows actual69 wins/badges/league/champion")
    await shot("final-01-champion-cleared")
    var before:=JourneySnapshot.encode(j)
    await click(ui.find_child("OpenReport",true,false))
    var report:RunReport=ui.find_child("RunReport",true,false)
    check(report!=null and report.content.get_node("Scroll/Rows").get_child_count()==69 and labels(report).contains("정산한 69전투"),"Actual report click displays all69 battle rows")
    await shot("final-02-all-battles-report")
    focus();print("OS_WHEEL 1450 820 12")
    await create_timer(.4).timeout
    check((report.content.get_node("Scroll") as ScrollContainer).scroll_vertical>0,"Actual wheel scrolls completed campaign history")
    await click(report.tabs["choices"])
    check(report.tab=="choices" and report.content.get_node("Scroll/Rows").get_child_count()>0,"Choice/gold report tab works")
    await click(report.tabs["build"])
    check(report.tab=="build" and report.content.get_node("Scroll/Rows").get_child_count()>2,"Card/relic report tab works")
    await key("Escape")
    check(not ui.report_open and JourneySnapshot.encode(j)==before,"Report browsing/close preserves completed state/RNG")
    await click(ui.actions[2])
    var menu:MainMenu=current_scene
    check(not is_instance_valid(menu.continue_button),"Returning to title hides completed run continuation")
    await shot("final-03-title-after-clear")
func new_run() -> void:
    check(not session.has_journey and session.save_notice.is_empty(),"Fresh process does not restore completed run or its backup")
    var menu:MainMenu=load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu);current_scene=menu
    await create_timer(.5).timeout
    check(not is_instance_valid(menu.continue_button),"Fresh title omits completed-run continue")
    await click(menu.start_button)
    for id:int in [1,4,7]:await click(menu.species_buttons[id])
    check(menu.selection.size()==3 and not menu.confirm_button.disabled,"Actual starter selection permits3 owned base species")
    await shot("final-04-new-starters")
    await click(menu.confirm_button)
    for i in 200:
        if current_scene is TacticalJourneyUI:break
        await create_timer(.05).timeout
    var ui:TacticalJourneyUI=current_scene
    for i in 200:
        if not ui.battle_ui.busy:break
        await create_timer(.05).timeout
    var j:TacticalJourney=session.journey
    var old:Dictionary=FileAccess.open(folder.path_join("final.bin"),FileAccess.READ).get_var()
    check(j.run_id!=old["run"]["run_id"] and j.wins==0 and j.badges==0 and j.route.generation==27 and j.battle.player_moves_version==19,"New run starts fresh identity/progression with current rules")
    var restored:TacticalJourney=session.save_store.load_journey()
    check(restored!=null and JourneySnapshot.encode(restored)==JourneySnapshot.encode(j) and session.save_notice.is_empty(),"New run replaces terminal marker with exact resumable save")
    await create_timer(.65).timeout
    await shot("final-05-new-run")
func cap_review() -> void:
    var state:Dictionary=FileAccess.open(folder.path_join("final.bin"),FileAccess.READ).get_var()
    var j:=JourneySnapshot.restore(state)
    var before:=JourneySnapshot.encode(j)
    var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.6).timeout
    var text:=labels(ui.page)
    check(j.growth_reports.all(func(report:Dictionary):return report["after"]==100) and text.count("최대 레벨에 도달했습니다.")==3 and not text.contains("다음 레벨을 향해!"),"Actual level100 completion report uses cap guidance for all3 members")
    check(JourneySnapshot.encode(j)==before,"Cap guidance rendering preserves actual progression/XP/save/RNG")
    await shot("final-06-max-level-guidance")
func run() -> void:
    if DisplayServer.get_name()=="headless" or folder.is_empty():quit(2);return
    if OS.get_environment("XDG_DATA_HOME").is_empty() or not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):
        push_error("Isolated XDG_DATA_HOME required");quit(2);return
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    session=root.get_node("BattleSession")
    var phase:=OS.get_environment("FINAL_CAMPAIGN_PHASE")
    if phase=="new":await new_run()
    elif phase=="cap":await cap_review()
    else:await completed()
    if is_instance_valid(current_scene):current_scene.free()
    for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name_text).stop_all()
    await create_timer(.3).timeout
    print("NATIVE_FINAL ",checks," checks / ",failures," failures / ",clicks," OS clicks / ",keys," OS keys")
    quit(0 if failures==0 else 1)
