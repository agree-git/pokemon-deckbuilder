extends SceneTree
var native := false
var checks := 0
var failures := 0
var clicks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    if current_scene is TacticalJourneyUI and is_instance_valid(current_scene.battle_ui): TacticalUIPlayer.finish(current_scene.battle_ui)
    if current_scene != null:
        UiMotion.finish_tree(current_scene)
        UiMotion.finish_tree(current_scene)
func click(control: Control) -> void:
    settle()
    if control is TrainerActionCard and current_scene is TacticalJourneyUI:
        current_scene.battle_ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        settle()
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    if native:
        var at: Vector2 = Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.28).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
    clicks += 1
    await process_frame
    await process_frame
    settle()
func save_picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await RenderingServer.frame_post_draw
    var output := "/workspace/.cloud-setup/pokemon-deckbuilder/previews/save_"+label+".png"
    check(root.get_texture().get_image().save_png(output) == OK,"Save rendered persistence screen")
    root.size = prior
    await process_frame
func expected(j: TacticalJourney, write_file: bool) -> void:
    var path := "user://expected.bin"
    if write_file:
        var file := FileAccess.open(path,FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else:
        check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes(path)),"Fresh process restores the exact previous checkpoint")
func run() -> void:
    # The runner supplies an isolated XDG directory; never touch a real player's save.
    var test_root := OS.get_environment("POKEMON_SAVE_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Run through tools/test_save_process.py with an isolated user directory")
        quit(1)
        return
    var stage := OS.get_environment("POKEMON_SAVE_TEST_PHASE")
    var session := root.get_node("BattleSession")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var menu := current_scene as MainMenu
    if stage == "write":
        check(not session.get("has_journey"),"First process has no existing journey")
        await click(menu.start_button)
        for id: int in [1,4,7]: await click(menu.species_buttons[id])
        await click(menu.confirm_button)
        if not current_scene is TacticalJourneyUI: await scene_changed
        await process_frame
        var ui := current_scene as TacticalJourneyUI
        check(ui != null and ui.journey.full_campaign,"Normal title flow starts saved full campaign")
        var drawn := ui.journey.battle.hand[0]
        await click(ui.battle_ui.trainer_buttons[drawn.uid])
        check(not ui.journey.battle.hand.has(drawn),"Saved mid-turn contains the exact played card and spent resources")
        var saved: TacticalJourney = session.get("save_store").load_journey()
        check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(ui.journey),"Actions autosave before process exits")
        expected(ui.journey,true)
        await save_picture("before_exit")
    else:
        check(session.get("has_journey") and is_instance_valid(menu.continue_button),"Fresh process exposes Continue")
        var j: TacticalJourney = session.get("journey")
        if stage != "recover": expected(j,false)
        await save_picture("title_"+stage)
        await click(menu.continue_button)
        var ui := current_scene as TacticalJourneyUI
        check(ui != null and ui.journey == j,"Continue opens restored journey")
        if stage == "read":
            check(ui.journey.battle.turn == 1 and ui.journey.battle.energy <= 4,"Continue retains the exact saved mid-turn")
            var reference := JourneySnapshot.restore(JourneySnapshot.encode(j))
            for i in 3:
                reference.battle.end_turn()
                await click(ui.battle_ui.end_button)
                check(JourneySnapshot.encode(j) == JourneySnapshot.encode(reference),"Future turns and reshuffle match uninterrupted play")
            expected(j,true)
            await save_picture("resumed_battle")
        elif stage == "camp_write":
            # Public-rule prelude only; the actual camp actions use UI input.
            for guard in 20000:
                if j.phase == TacticalJourney.REST and j.camp()["kind"] == "merchant": break
                match j.phase:
                    TacticalJourney.BATTLE:
                        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: j.settle()
                        else: CampaignPolicy.apply(j,CampaignPolicy.action(j))
                    TacticalJourney.LEARN: j.resolve_learning(CampaignPolicy.learn(j))
                    TacticalJourney.REWARD: j.choose_reward(-1)
                    TacticalJourney.MAP: j.enter_next()
                    TacticalJourney.REST:
                        j.rest()
                        j.leave_camp()
            ui.refresh()
            await process_frame
            check(j.phase == TacticalJourney.REST and j.camp()["kind"] == "merchant","Reach a seeded merchant through public rules")
            await click(ui.rest_button)
            await click(ui.camp_tabs["shop"])
            await click(ui.page.find_child("Buy_ball",true,false))
            expected(j,true)
            await save_picture("camp_before_exit")
        elif stage == "camp_read":
            check(j.phase == TacticalJourney.REST and ui.rest_button.disabled,"Restart cannot repeat camp rest")
            await click(ui.camp_tabs["shop"])
            check(j.shop_stock["ball"] == 3,"Merchant stock survives process restart")
            var reference := JourneySnapshot.restore(JourneySnapshot.encode(j))
            reference.buy("ball")
            await click(ui.page.find_child("Buy_ball",true,false))
            check(JourneySnapshot.encode(j) == JourneySnapshot.encode(reference),"Resumed purchase preserves stock/inventory aliases and gold")
            expected(j,true)
            await save_picture("resumed_camp")
        elif stage == "recover":
            check(not str(session.get("save_notice")).is_empty(),"Backup recovery is visible in the title and save status")
            await click(ui.save_button)
            check(str(session.get("save_notice")).is_empty(),"Recovered run can be saved again")
            await save_picture("recovered")
    print("SAVE_PROCESS: stage=",stage," checks=",checks," failures=",failures," pointer_inputs=",clicks," native=",native)
    quit(0 if failures == 0 else 1)
