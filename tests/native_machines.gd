extends SceneTree
var checks := 0
var failures := 0
var clicks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func click(control: Control) -> void:
    check(control != null,"Native TM target exists")
    if control == null: return
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(.4).timeout
func camp(merchant: bool) -> TacticalJourney:
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",[133,129],true)
        j.step = 1
        j.phase = TacticalJourney.MAP
        j.enter_next()
        if (j.camp()["kind"] == "merchant") == merchant and not j.camp()["machine_offers"].is_empty(): return j
    return null
func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    var folder := OS.get_environment("TM_REVIEW_DIR")
    DirAccess.make_dir_recursive_absolute(folder)
    check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"TM screenshot "+name)
func run() -> void:
    if DisplayServer.get_name() == "headless" or OS.get_environment("TM_REVIEW_DIR").is_empty(): quit(2); return
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var j := camp(true)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.6).timeout
    await shot("camp-machine-entry")
    await click(ui.find_child("CampMachinesButton",true,false))
    check(is_instance_valid(ui.workshop) and ui.workshop.mode == "machines","Camp TM button opens the correct workshop tab")
    var w := ui.workshop
    var move := int(j.camp()["machine_offers"][0]["move"])
    await shot("machine-merchant")
    await click(w.find_child("MachineOffer_0",true,false).find_child("WorkshopAction",true,false))
    check(j.gold == 0 and j.machines.get(move,0) == 1,"Actual purchase click charges gold and adds one TM")
    await click(w.find_child("WorkshopParty_1",true,false))
    check(w.find_child("MachineOwned_%d" % move,true,false).find_child("WorkshopAction",true,false).disabled,"Incompatible Magikarp has disabled use button")
    await shot("machine-incompatible")
    await click(w.find_child("WorkshopParty_0",true,false))
    await click(w.find_child("WorkshopSlot_1",true,false))
    await click(w.find_child("MachineOwned_%d" % move,true,false).find_child("WorkshopAction",true,false))
    check(j.party[0].learned_skills[1] == TacticalMoves.key_for(move) and j.machines[move] == 0 and j.rested_steps.is_empty(),"Actual TM click changes chosen slot and consumes only item")
    await shot("machine-taught")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Native TM state validates")
    ui.free()
    j = camp(false)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.4).timeout
    await click(ui.find_child("CampMachinesButton",true,false))
    await shot("machine-discovery")
    await click(ui.workshop.find_child("MachineOffer_0",true,false).find_child("WorkshopAction",true,false))
    check(j.gold == 100 and j.machines.size() == 1 and not j.camp()["resolved"],"Actual discovery click grants free TM without resolving ordinary event")
    ui.free()
    for name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]: root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native machines: %d checks / %d failures; %d OS clicks" % [checks,failures,clicks])
    quit(1 if failures else 0)
