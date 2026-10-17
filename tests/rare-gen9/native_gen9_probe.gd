extends SceneTree
const Support = preload("rare_test_support.gd")
var checks := 0
var failures := 0
var clicks := 0
var seeds := {}
var output_dir := OS.get_environment("RARE_REVIEW_DIR") if not OS.get_environment("RARE_REVIEW_DIR").is_empty() else "/tmp/pokemon-rare-gen9"
var manifest: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control) -> void:
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size/2))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(0.38).timeout
    await process_frame
func shot(label_text: String,id: int,phase: String) -> void:
    await RenderingServer.frame_post_draw
    var file_name := label_text+".png"
    check(root.get_texture().get_image().save_png(output_dir.path_join(file_name)) == OK,"Screenshot "+file_name)
    manifest.append({"id":id,"phase":phase,"file":file_name})
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    DirAccess.make_dir_recursive_absolute(output_dir)
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    for s in 5000:
        var target := RareEncounter.target(s)
        if not seeds.has(target): seeds[target] = s
    # Real OS interaction from anonymous research through travel and natural arrival.
    for id: int in [10169,1025,1007]:
        var j := Support.fixture(seeds[id])
        j.rare_hunt["clues"].pop_back()
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        await create_timer(0.25).timeout
        await click(ui.page.find_child("RareEncounter",true,false))
        check(ui.rare_open and ui.page.find_child("RareTarget",true,false).text.contains("???") and ui.page.find_child("UnknownRarePortrait",true,false) != null,"Research identity hidden")
        await shot(str(id)+"-hidden",id,"research")
        await click(ui.page.find_child("InvestigateRare",true,false))
        for tick in 100:
            if j.rare_info()["clues"].size() == RareEncounter.requirement(id): break
            await create_timer(0.01).timeout
        check(j.rare_info()["clues"].size() == RareEncounter.requirement(id),"Investigation earns last clue")
        await click(ui.page.find_child("ChallengeRare",true,false))
        check(j.rare_hunt["battle_step"] == j.step+1,"Reservation works via actual pointer")
        print("OS_KEY Escape")
        await create_timer(0.22).timeout
        await click(ui.actions[0])
        check(j.phase == TacticalJourney.MAP and j.progress_title().contains("???"),"Map identity hidden")
        await click(ui.page.find_child("EncounterPreparation",true,false))
        check(ui.find_child("PreparationUnknown",true,false) != null,"Preparation shows anonymous encounter")
        await shot(str(id)+"-preparation",id,"preparation")
        await click(ui.find_child("PreparationClose",true,false))
        await click(ui.actions[0])
        check(ui.travelling,"Travel starts")
        await shot(str(id)+"-travel",id,"travel")
        for tick in 400:
            if not ui.travelling: break
            await create_timer(0.01).timeout
        var view := ui.battle_ui
        var before := JourneySnapshot.encode(j)
        check(view != null and view.busy and view._rare_hidden and not view.enemy_roster.visible,"Identity waits for entrance effect")
        await click(view.end_button)
        check(JourneySnapshot.encode(j) == before,"Locked end turn cannot mutate battle")
        for tick in 800:
            if not view.busy: break
            await create_timer(0.01).timeout
        check(not view.busy and not view._rare_hidden and view.enemy_roster.visible and view.stage.canvas.target_factor == 1,"Natural playback restores sprite and controls")
        check(JourneySnapshot.encode(j) == before,"Natural intro is state and RNG neutral")
        await shot(str(id)+"-ready",id,"ready")
        ui.free()
        await process_frame
        await process_frame
    for id: int in [789,790]:
        var j := Support.fixture(seeds[id])
        check(RareEncounter.requirement(id) == 7 and j.badges == 7,"Early form uses the superlegendary gate")
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        ui.rare_open = true
        root.add_child(ui)
        await create_timer(0.25).timeout
        await shot(str(id)+"-hidden",id,"family_gate")
        ui.free()
        await process_frame
        await process_frame
    # Capture every bespoke effect at reproducible anticipation/reveal keyframes.
    var index := 0
    for id: int in RareEntrance.KINDS.keys():
        var j := Support.fixture(seeds[id])
        Support.enter(j)
        var before := JourneySnapshot.encode(j)
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.get_node("Preferences").battle_speed = [1.0,1.5,2.0][index%3]
        index += 1
        root.add_child(ui)
        var view := ui.battle_ui
        check(view.rare_entrance != null and view.rare_entrance.species_id == id,"Correct unique arrival "+str(id))
        view._sequence.pause()
        await create_timer(0.35).timeout
        check(view.get_node("RunTitle").text.contains("???") and not view.get_node("RunTitle").text.contains(j.battle.enemy().display_name),"Anticipation title remains anonymous")
        view.rare_entrance.progress = 0.40
        await process_frame
        await shot(str(id)+"-anticipation",id,"anticipation")
        view._reveal_rare()
        view.rare_speech.modulate.a = 1
        UiMotion.finish_tree(view.stage.canvas.target_sprite)
        view.stage.canvas.target_sprite.modulate.a = 1
        view.rare_entrance.progress = 0.67
        await process_frame
        await shot(str(id)+"-reveal",id,"reveal")
        view.finish_presentation()
        check(not view.busy and not view._rare_hidden and view.rare_entrance == null,"Finish cleans effect "+str(id))
        check(JourneySnapshot.encode(j) == before,"Effect does not alter rules or RNG "+str(id))
        ui.refresh()
        check(ui.battle_ui.rare_entrance == null and not ui.battle_ui.busy,"Refresh does not repeat introduction")
        ui.free()
        await process_frame
        await process_frame
    var session := root.get_node("BattleSession")
    session.profile = PlayerProfile.new("")
    session.journey = null
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    await create_timer(0.25).timeout
    await click(menu.collection_button)
    await click(menu.show_locked)
    menu.search.text = "???"
    menu._filter()
    await process_frame
    check(menu.species_buttons.size() == 103,"Unknown rare collection query has no silhouettes")
    await shot("collection-hidden",0,"collection")
    menu.free()
    await process_frame
    await process_frame
    FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
    for name_text in ["GameAudio","GameMusic","GameCries"]: root.get_node(name_text).call("stop_all" if name_text != "GameMusic" else "stop_music")
    await process_frame
    await create_timer(0.2).timeout
    print("NATIVE_GEN9 ",checks," checks / ",failures," failures / ",clicks," actual OS clicks")
    quit(0 if failures == 0 else 1)
