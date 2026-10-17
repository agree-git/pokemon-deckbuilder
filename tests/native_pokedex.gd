extends SceneTree
var checks := 0
var failures := 0
var clicks := 0
var folder := OS.get_environment("POKEDEX_REVIEW_DIR")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func click(control: Control) -> void:
    check(control != null,"Native target exists")
    if control == null: return
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(.35).timeout
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    await create_timer(.2).timeout
func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Native screenshot "+name)
func run() -> void:
    if DisplayServer.get_name() == "headless" or folder.is_empty(): quit(2); return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var j := TacticalJourney.new(712,"field_kit",[906,909,912],true)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.7).timeout
    check(ui.battle_ui != null and j.party.all(func(p: BattlePokemon): return p.content_version == 2),"Actual Gen9 battle scene and modern starter moves")
    await shot("gen9-starters")
    ui.free()
    await process_frame
    j = TacticalJourney.new(712,"field_kit",[906,479,133],true)
    j.step = 1
    j.phase = TacticalJourney.MAP
    j.enter_next()
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.4).timeout
    await click(ui.find_child("PokedexWorkshopButton",true,false))
    check(is_instance_valid(ui.workshop),"Actual pointer opens camp workshop")
    var w := ui.workshop
    await shot("evolution-preparation")
    await click(w.find_child("WorkshopRow_907",true,false).find_child("WorkshopAction",true,false))
    check(j.party[0].evolution_prepared == 907 and j.rested_steps.is_empty(),"Normal evolution branch selection preserves camp action")
    await click(w.find_child("WorkshopTab_forms",true,false))
    await click(w.find_child("WorkshopParty_1",true,false))
    await click(w.find_child("WorkshopRow_10009",true,false).find_child("WorkshopAction",true,false))
    check(j.party[1].species_id == 10009,"Actual pointer selects Wash Rotom with correct permanent form")
    await shot("rotom-form")
    await click(w.find_child("WorkshopTab_moves",true,false))
    await click(w.find_child("WorkshopParty_2",true,false))
    await click(w.find_child("WorkshopSearch",true,false))
    await key("1")
    await key("2")
    await key("9")
    check(w.rows.get_child_count() == 1,"Actual keyboard filters legal Swift training")
    await click(w.rows.get_child(0).find_child("WorkshopAction",true,false))
    check(j.party[2].learned_skills[0] == "move_129" and j.step in j.rested_steps,"Actual training click changes selected owner/slot and spends action")
    await shot("legal-move-training")
    await key("Escape")
    check(not is_instance_valid(ui.workshop) and JourneySnapshot.validate(JourneySnapshot.encode(j)),"Esc closes workshop; form/training state remains saveable")
    ui.free()
    var session := root.get_node("BattleSession")
    var original: PlayerProfile = session.profile
    var profile := PlayerProfile.new("")
    profile.captured_ids.assign([869])
    session.profile = profile
    var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    menu._open_collection()
    await process_frame
    check(menu.species_buttons.size() >= 63,"Alcremie cosmetic forms appear from collection knowledge")
    menu._select(30494)
    await shot("alcremie-collection")
    menu.free()
    session.profile = original
    for name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]: root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native National Dex: %d checks / %d failures; %d OS clicks" % [checks,failures,clicks])
    quit(1 if failures else 0)
