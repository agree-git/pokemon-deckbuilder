extends SceneTree
var checks := 0
var failures := 0
var clicks := 0
const FOLDER := "/tmp/pokemon-workshop-compact"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1;push_error(message)
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func click(control: Control) -> void:
    if not is_instance_valid(control) or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
        check(false,"Available actual click target");quit(2);return
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y));clicks+=1
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func shot(filename: String) -> void:
    print("OS_MOVE 960 40")
    await create_timer(.5).timeout
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(FOLDER.path_join(filename))==OK,"Screenshot "+filename)
func row_bounds(workshop: PokedexWorkshop) -> bool:
    for panel: Control in workshop.rows.get_children():
        if not panel is Panel: continue
        var action: Control=panel.get_node_or_null("WorkshopAction")
        if action==null:action=panel.get_node("AutomaticEvolution")
        if action.size.x>184.1 or not Rect2(Vector2.ZERO,panel.size).encloses(action.get_rect()):return false
        for child: Node in panel.get_children():
            if child is Label and child.get_rect().intersects(action.get_rect()):return false
    return true
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(FOLDER)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var session:=root.get_node("BattleSession")
    var starters: Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Isolated actual expedition starts")
    var actual: TacticalJourney=session.journey
    var baseline:=JourneySnapshot.encode(actual)
    var saved:=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var camp:=TutorialLesson.camp_practice()
    camp.machines[53]=1;camp.machines[85]=1
    var before:=JourneySnapshot.encode(camp)
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=camp;root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    await click(ui.page.find_child("PokedexWorkshopButton",true,false))
    var workshop: PokedexWorkshop=ui.workshop
    check(workshop.content.size==Vector2(1280,920) and Rect2(0,0,1920,1080).encloses(workshop.content.get_global_rect()),"Compact workshop is centered and bounded")
    var last: Control
    for i in camp.party.size():
        var party: Control=workshop.content.get_node("WorkshopParty_%d"%i)
        check(party.size==Vector2(232,88) and party.position.x==32,"Party choice uses a compact portrait tile")
        if last!=null:check(party.position.y-last.get_rect().end.y>=24,"Party tiles have 24px vertical gutters")
        last=party
    var previous: Control
    for mode: String in ["evolution","forms","moves","machines"]:
        var tab: Control=workshop.content.get_node("WorkshopTab_"+mode)
        check(tab.size.x<=160 and tab.position.x>=312,"Research tabs use short text-width buttons")
        if previous!=null:check(tab.position.x-previous.get_rect().end.x>=24,"Compact tabs retain 24px gutters")
        previous=tab
    check(workshop.rows.get_child_count()>0 and row_bounds(workshop),"Evolution rows separate descriptions and compact actions")
    await shot("01-evolution.png")
    await click(workshop.content.get_node("WorkshopParty_2"))
    check(workshop.selected==2 and workshop.current()==camp.party[2],"Actual sidebar choice selects intended companion")
    await click(workshop.content.get_node("WorkshopParty_0"))
    await click(workshop.content.get_node("WorkshopTab_moves"))
    check(workshop.mode=="moves","Actual compact tab opens technique training")
    var search: Control=workshop.content.get_node("WorkshopSearch")
    check(search.size.x==528 and search.get_rect().end.x<workshop.content.size.x-32,"Search field no longer spans dialog width")
    previous=null
    for i in 4:
        var button: Control=workshop.content.get_node("WorkshopSlot_%d"%i)
        check(button.size.x==176 and button.position.y-search.get_rect().end.y>=24,"Move slots are compact and clear of search")
        if previous!=null:check(button.position.x-previous.get_rect().end.x>=24,"Move slot gutters stay at 24px")
        previous=button
    check(workshop.rows.get_child_count()>0 and row_bounds(workshop),"Training text and 184px actions stay separate")
    var scroll: Control=workshop.content.get_node("WorkshopScroll")
    check(scroll.position.y-previous.get_rect().end.y>=24 and scroll.get_rect().end.y<840,"Result list clears move selection and notice footer")
    await shot("02-moves.png")
    await click(search);await key("z")
    check(workshop.query=="z" and workshop.empty_label.visible and not workshop.rows.get_children().any(func(panel:Control):return panel is Panel and panel.visible),"Actual search displays bounded empty result")
    await key("BackSpace")
    check(workshop.query.is_empty() and workshop.rows.get_child_count()>0,"Clearing search restores available techniques")
    await click(workshop.content.get_node("WorkshopTab_forms"))
    check(workshop.mode=="forms" and row_bounds(workshop),"Permanent form tab remains accessible")
    await click(workshop.content.get_node("WorkshopTab_machines"))
    check(workshop.mode=="machines" and workshop.rows.get_child_count()>=2 and row_bounds(workshop),"Owned TM rows fit short actions with descriptions")
    await shot("03-machines.png")
    await click(workshop.content.get_node("WorkshopSearch"));await key("Escape")
    check(not is_instance_valid(ui.workshop) and ui.is_inside_tree() and not is_instance_valid(ui.pause_menu),"Esc from focused search closes research without leaving camp")
    check(JourneySnapshot.encode(camp)==before and JourneySnapshot.encode(actual)==baseline and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"UI selection/search preserve fixture, actual campaign, UID/RNG and save bytes")
    ui.queue_free();await process_frame
    root.get_node("GameMusic").stop_music();root.get_node("GameAmbience").stop_ambience()
    await create_timer(.2).timeout
    print("WORKSHOP_COMPACT: ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)
