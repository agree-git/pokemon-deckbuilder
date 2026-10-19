extends SceneTree
## One real-input tutorial run, including settings persistence and untouched campaign.
var checks:=0
var failures:=0
var clicks:=0
var folder:="/tmp/pokemon-tutorial-review"
var session:Node
var protected:Dictionary
var saved:PackedByteArray
var captures:Array
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func click(control:Control) -> void:
    print("OS_MOVE 960 70")
    await create_timer(.35).timeout
    check(is_instance_valid(control) and control.is_visible_in_tree() and not (control is BaseButton and control.disabled),"Available click target")
    if not is_instance_valid(control):return
    var at:=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*Vector2(.5,.35 if control is TrainerActionCard else .5)))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(at.x)," ",roundi(at.y));clicks+=1
    await create_timer(.4).timeout
func key(symbol:String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol);await create_timer(.4).timeout
func until(condition:Callable,message:String) -> void:
    for i in 300:
        if condition.call():break
        await create_timer(.05).timeout
    check(condition.call(),message)
    if not condition.call():
        await shot("failure-"+str(checks))
        if current_scene is TutorialUI:print("FAILED_STEP ",tutorial().step," energy=",tutorial().practice.battle.energy," active=",tutorial().practice.battle.active().species_id)
        quit(1)
        await create_timer(1).timeout
func shot(name_text:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
func preserved() -> void:
    check(session.has_journey and JourneySnapshot.encode(session.journey)==protected,"Actual existing expedition/RNG remains unchanged")
    check(FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Existing expedition save file is byte-identical")
    check(session.profile.captured_ids==captures,"Tutorial capture does not unlock collection")
func tutorial() -> TutorialUI:return current_scene as TutorialUI
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty() or not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    if OS.get_environment("TUTORIAL_REVIEW_PHASE")=="layout":
        var t:TutorialUI=load("res://scenes/tutorial.tscn").instantiate()
        root.add_child(t);current_scene=t
        for lesson:int in TutorialUI.LESSONS.size():
            t.step=lesson
            if lesson>=8:t._camp(lesson==10)
            else:t._build_coach()
            await create_timer(.1).timeout
            check(t.body_label.get_line_count()*t.body_label.get_line_height()<=t.body_label.size.y,"Complete readable coach text "+str(lesson))
            if lesson==8:await shot("04-camp-rest")
        current_scene.free()
        for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name_text).stop_all()
        await create_timer(.3).timeout
        print("TUTORIAL_LAYOUT ",checks," checks / ",failures," failures")
        quit(0 if failures==0 else 1);return
    var preferences:=root.get_node("Preferences")
    preferences.set_battle_speed(2.0);preferences.set_tutorial_status("new")
    session=root.get_node("BattleSession")
    var starters:Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Protected real campaign created")
    protected=JourneySnapshot.encode(session.journey);saved=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH);captures=session.profile.captured_ids.duplicate()
    var menu:MainMenu
    if OS.get_environment("TUTORIAL_REVIEW_PHASE")=="camp":
        var t:TutorialUI=load("res://scenes/tutorial.tscn").instantiate()
        root.add_child(t);current_scene=t
        t.step=8;t._camp()
        await create_timer(.5).timeout
        preserved();await shot("04-camp-rest")
    else:
        menu=load("res://scenes/main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
        await create_timer(.5).timeout
        await click(menu.start_button)
        check(menu.mode=="title" and is_instance_valid(menu.tutorial_prompt),"First new-run click offers optional practice before starters")
        await shot("01-first-offer")
        await click(menu.tutorial_prompt.find_child("OfferPractice",true,false))
        await until(func():return current_scene is TutorialUI,"Practice scene entered")
        check(not session.tracks(tutorial().practice),"Practice is never the autosaved campaign")
        var before:=JourneySnapshot.encode(tutorial().practice)
        await key("Return")
        check(tutorial().step==0 and JourneySnapshot.encode(tutorial().practice)==before,"Premature keyboard end-turn cannot bypass lesson")
        await click(tutorial().next_button);await click(tutorial().next_button)
        await until(func():return tutorial().step==2,"Card lesson reached")
        var card:Control=tutorial().battle_view.trainer_buttons[TutorialLesson.FIRST_CARD]
        var at:=root.get_final_transform()*(card.get_global_transform_with_canvas()*(card.size*.5))
        print("OS_MOVE ",roundi(at.x)," ",roundi(at.y));await create_timer(.5).timeout
        check(tutorial().battle_view._preview_uid==TutorialLesson.FIRST_CARD and tutorial().battle_view.action_preview.visible,"Actual hover shows current-state preview")
        await shot("02-card-preview")
        var energy:=tutorial().practice.battle.energy
        await click(card)
        await until(func():return tutorial().step==3,"Real first card advances lesson")
        check(tutorial().practice.battle.energy==energy-1,"First card consumes its actual one-energy cost")
        energy=tutorial().practice.battle.energy
        await click(tutorial().battle_view.trainer_buttons[TutorialLesson.SWITCH_CARD])
        await until(func():return tutorial().step==4,"Real other-owner card advances lesson")
        check(tutorial().practice.battle.active().species_id==7 and tutorial().practice.battle.energy==energy-1,"Auto switch changes actor without an extra fee")
        await click(tutorial().battle_view.trainer_buttons[TutorialLesson.GUARD_CARD])
        await until(func():return tutorial().step==5,"Actual guard card advances lesson")
        check(tutorial().practice.battle.active().block>0,"Guard affects last active companion")
        await shot("03-guard-and-intent")
        await click(tutorial().battle_view.end_button)
        await until(func():return tutorial().step==6,"Real enemy turn and next hand complete")
        check(tutorial().practice.battle.turn==2 and tutorial().practice.battle.energy>=3 and tutorial().practice.battle.hand.size()==5,"Next turn refills hand and energy")
        await click(tutorial().next_button)
        await until(func():return tutorial().step==7,"Clearly separate low-HP capture fixture")
        check(tutorial().practice.capture_reason().is_empty(),"Actual capture HP/energy/ball requirements met")
        await click(tutorial().battle_view.capture_button)
        await until(func():return tutorial().step==8,"Actual capture leads to camp lesson")
        preserved()
        await shot("04-camp-rest")
    var hp:=tutorial().practice.party[0].hp
    await click(tutorial().camp_view.rest_button)
    await until(func():return tutorial().step==9,"Actual camp rest completes task")
    check(tutorial().practice.party[0].hp>hp and tutorial().camp_view.rest_button.disabled,"Camp heal changes HP and consumes action")
    await click(tutorial().next_button)
    await click(tutorial().camp_view.page.find_child("Upgrade",true,false))
    await until(func():return tutorial().camp_view.deck_open,"Actual upgrade deck browser")
    await click(tutorial().camp_view.page.find_child("Card_103",true,false))
    await until(func():return tutorial().camp_view.upgrade_preview_uid==103,"Actual before-after upgrade preview")
    await shot("05-upgrade-preview")
    await click(tutorial().camp_view.page.find_child("UpgradeConfirm",true,false))
    await until(func():return tutorial()._finishing,"Real upgrade finishes tutorial")
    check(tutorial().practice.deck.any(func(c:BattleCardInstance):return c.uid==103 and c.upgraded),"Practice card was really upgraded")
    check(preferences.tutorial_status=="completed","Completion is recorded only in presentation preferences")
    preferences.load_preferences();check(preferences.tutorial_status=="completed","Completion survives preference reload")
    preserved();await shot("06-completed")
    await click(tutorial().stage_view.find_child("TutorialStartJourney",true,false))
    await until(func():return current_scene is MainMenu,"Completion returns to menu")
    menu=current_scene
    check(menu.mode=="starters" and not session.open_starter_selection,"Explicit completion choice opens starter selection only")
    preserved()
    await key("Escape")
    await click(menu.tutorial_button)
    await until(func():return current_scene is TutorialUI,"Tutorial can be replayed after completion")
    await click(tutorial().exit_button)
    await until(func():return current_scene is MainMenu,"Early exit returns safely")
    preserved();check(preferences.tutorial_status=="completed","Aborting replay preserves previous completion")
    menu=current_scene;preferences.set_tutorial_status("new")
    await click(menu.start_button);await click(menu.tutorial_prompt.find_child("OfferSkip",true,false))
    check(menu.mode=="starters" and preferences.tutorial_status=="skipped","Optional skip selects starters without starting a campaign")
    preferences.load_preferences();check(preferences.tutorial_status=="skipped","Skip survives preference reload")
    await key("Escape");await click(menu.start_button)
    check(menu.mode=="starters" and not is_instance_valid(menu.tutorial_prompt),"Offer does not repeat after explicit skip")
    preserved()
    current_scene.free()
    for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name_text).stop_all()
    await create_timer(.3).timeout
    print("NATIVE_TUTORIAL ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)
