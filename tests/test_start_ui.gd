extends SceneTree
var failures := 0
var checks := 0
var clicks := 0
var native := false
var path := ""
var saved_profile: PlayerProfile
var captured: Dictionary = {}
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    if current_scene is TacticalJourneyUI and is_instance_valid(current_scene.battle_ui): TacticalUIPlayer.finish(current_scene.battle_ui)
    UiMotion.finish_tree(current_scene)
    UiMotion.finish_tree(current_scene)
func click(control: Control,local := Vector2(-1,-1)) -> void:
    settle()
    if control is TrainerActionCard and current_scene is TacticalJourneyUI and is_instance_valid(current_scene.battle_ui):
        current_scene.battle_ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        settle()
    if local.x < 0: local = control.visible_point() if control is TrainerActionCard else control.size/2
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.28).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
    clicks += 1
    await process_frame
    settle()
    if native: await create_timer(0.12).timeout
func save(label: String) -> void:
    if DisplayServer.get_name() == "headless" or captured.has(label): return
    captured[label] = true
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await RenderingServer.frame_post_draw
    var output := "/workspace/.cloud-setup/pokemon-deckbuilder/previews/start"
    DirAccess.make_dir_recursive_absolute(output)
    check(root.get_texture().get_image().save_png(output+"/"+label+".png") == OK,"Save rendered screen: "+label)
    root.size = prior
    await process_frame
    if native: await create_timer(0.18).timeout
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    var session := root.get_node("BattleSession")
    saved_profile = session.get("profile")
    path = "user://tests/start_ui_%d.json" % Time.get_ticks_usec()
    session.set("profile",PlayerProfile.new(path))
    session.set("has_journey",false)
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    await save("title")
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        await process_frame
        var menu := current_scene as MainMenu
        menu.full_campaign = false
        await click(menu.start_button,Vector2(menu.start_button.size.x/2,3))
        check(menu.mode == "starters" and menu.confirm_button.disabled,"Start opens empty selection at %s" % dimensions)
        for id: int in [4,1,7]: await click(menu.species_buttons[id])
        check(menu.selection == [4,1,7] and not menu.confirm_button.disabled,"Three choices retain lead order")
        await save("starters")
        await click(menu.species_buttons[7])
        check(menu.selection == [4,1],"Clicking selected Pokemon removes it")
        await click(menu.back_button)
        check(menu.mode == "title","Selection can return to title without starting")
    root.size = Vector2i(1280,720)
    await process_frame
    var menu := current_scene as MainMenu
    menu.full_campaign = false
    await click(menu.start_button)
    for id: int in [4,1,7]: await click(menu.species_buttons[id])
    await click(menu.confirm_button)
    check(current_scene is TacticalJourneyUI,"Confirm enters real expedition")
    var ui := current_scene as TacticalJourneyUI
    check(ui.journey.starter_ids == [4,1,7] and ui.journey.battle.active().species_id == 4,"Chosen party reaches battle with correct lead")
    check(ui.battle_ui.old_button == null and ui.battle_ui.lab_button == null,"Normal battle menu has no old modes or art lab")
    # Bring Oddish into capture range with the starter's real level-five attack.
    for guard in 100:
        if ui.journey.battle.capture_reason().is_empty(): break
        if ui.journey.battle.enemy().strength > -6 and ui.journey.battle.skill_reason("move_45").is_empty(): await click(ui.battle_ui.skills[1])
        elif ui.journey.battle.skill_reason("move_10").is_empty(): await click(ui.battle_ui.skills[0])
        else: await click(ui.battle_ui.end_button)
    check(not ui.battle_ui.capture_button.disabled,"Low HP activates capture button")
    if ui.battle_ui.capture_button.disabled:
        quit(1)
        return
    await save("capture_ready")
    await click(ui.battle_ui.capture_button)
    var profile: PlayerProfile = session.get("profile")
    check(profile.captured_ids == [43] and 43 in PlayerProfile.new(path).unlocked_starters(VisualCatalog.new()),"Real capture persists starter unlock immediately")
    await click(ui.battle_ui.menu_button)
    await click(ui.battle_ui.home_button)
    menu = current_scene as MainMenu
    menu.full_campaign = false
    check(menu != null and is_instance_valid(menu.continue_button),"Returning home offers resume")
    var retained: TacticalJourney = session.get("journey")
    var snapshot := retained.battle.snapshot()
    await click(menu.collection_button)
    await click(menu.species_buttons[43])
    await save("collection")
    await click(menu.back_button)
    await click(menu.continue_button)
    ui = current_scene as TacticalJourneyUI
    check(ui.journey == retained and ui.journey.battle.snapshot() == snapshot,"Resume preserves combat and does not reroll")
    for guard in 600:
        if ui.journey.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
        match ui.journey.phase:
            TacticalJourney.BATTLE:
                if ui.journey.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: await click(ui.battle_ui.result_next)
                else: await click(TacticalUIPlayer.button(ui.battle_ui,JourneyPolicy.action(ui.journey.battle)))
            TacticalJourney.LEARN:
                await click(ui.actions.back()) # Keep original moves for this capture regression.
            TacticalJourney.REST:
                if ui.journey.step not in ui.journey.rested_steps: await click(ui.rest_button)
                else: await click(ui.actions[0])
            TacticalJourney.CAPTURE:
                await save("join")
                await click(ui.actions[1]) # Replace Bulbasaur with captured Oddish.
                check(ui.journey.party[1].species_id == 43,"Captured member joins through the replacement screen")
            _:
                await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.CLEARED,"Chosen starters and captured replacement complete gym journey")
    await save("cleared")
    # Reopen title as a new instance: disk profile still exposes the caught starter.
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    menu = current_scene as MainMenu
    menu.full_campaign = false
    await click(menu.start_button)
    check(menu.species_buttons.has(43),"Captured starter is selectable next run")
    await click(menu.species_buttons[43])
    await save("unlocked_starter")
    await click(menu.confirm_button)
    ui = current_scene as TacticalJourneyUI
    check(ui.journey.party.size() == 1 and ui.journey.party[0].species_id == 43,"Unlocked starter can begin solo run")
    await click(ui.battle_ui.skills[0])
    check(ui.journey.battle.used_skills.has("43:move_71"),"Newly unlocked starter's skills are functional")
    session.set("profile",saved_profile)
    for suffix: String in ["",".bak",".tmp"]:
        var file_path := ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(file_path): DirAccess.remove_absolute(file_path)
    print("START_UI: ",checks," checks, ",failures," failures; ",clicks," pointer actions; OS input ",native)
    quit(0 if failures == 0 else 1)
