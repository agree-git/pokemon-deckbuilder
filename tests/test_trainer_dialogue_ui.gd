extends "res://tests/test_enemy_tactics_ui.gd"
var view: TacticalUI
var keys := 0
var catalog := VisualCatalog.new()
var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
var output := "/tmp/pokemon-trainer-dialogue"
func make_boss(key: String) -> TacticalUI:
    var role := key.get_slice(":",0)
    var id := key.get_slice(":",1)
    var pool: Array = GymLeaders.all() if role == "gym" else league["elite" if role == "elite" else "champions"]
    var trainer: Dictionary = pool.filter(func(p: Dictionary): return p.get("leader_id",p.get("id","")) == id)[0]
    var stop := {"kind":role,"trainer":trainer,"party":trainer["party"],"level":30}
    var route := CampaignRoute.new(42)
    route.stops[0] = stop
    var members: Array[BattlePokemon] = []
    for species in [4,7,1]:
        var p := BattlePokemon.new(TacticalContent.member_definition(species,catalog),species)
        p.level = 30
        PokemonStats.apply(p,true)
        members.append(p)
    var cards: Array[BattleCardInstance] = [BattleCardInstance.new(101,"move_165",4),BattleCardInstance.new(102,"move_165",4),BattleCardInstance.new(103,"guard",0)]
    var b := TacticalBattle.new()
    b.start_with(members,cards,route.opponents(0),42,"field_kit")
    b.full_type_chart = true
    b.energy = 3
    b.hand.assign(cards)
    b.draw_pile.clear()
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    ui.run_mode = true
    var biome: Dictionary = catalog.biomes.filter(func(entry: Dictionary): return entry["type"] == trainer["type"])[0]
    ui.run_biome = biome
    ui.run_background = BattleBackdrops.for_stop(stop,biome)
    ui.opponent_trainer = TrainerDialogue.opponent(stop,biome)
    ui.run_title = TrainerDialogue.title(ui.opponent_trainer)+" · 대사 연출 검토"
    root.add_child(ui)
    if role in ["elite","champion"]:
        ui.get_node("StageTitle").text = (catalog.type_name(trainer["type"])+" 배틀 룸") if role == "elite" else (str(trainer["region"])+" 챔피언 룸")
        ui.get_node("StageTitle").add_theme_font_size_override("font_size",18)
    return ui
func wait_line(phase: String) -> void:
    for i in 500:
        if view.trainer_speech.visible and view.trainer_speech.phase == phase: return
        await create_timer(0.01).timeout
    check(false,"Timed battle playback reaches speech phase: "+phase)
func key_input(code: Key,label: String) -> void:
    if native:
        print("OS_KEY ",label)
        await create_timer(0.15).timeout
    else:
        var event := InputEventKey.new()
        event.keycode = code
        event.pressed = true
        root.push_input(event)
        await process_frame
    keys += 1
func press(control: Control) -> void:
    await process_frame
    UiMotion.finish_tree(view)
    await process_frame
    var at: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    if native:
        var screen: Vector2 = Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*at)
        print("OS_CLICK ",roundi(screen.x)," ",roundi(screen.y))
        await create_timer(0.16).timeout
    else:
        TacticalUIPlayer.click(self,control,at)
        await process_frame
    clicks += 1
func shot(name_text: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(name_text+".png")) == OK,"Capture actual trainer dialogue phase")
func run() -> void:
    Engine.max_fps = 60
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    var preferences := root.get_node("Preferences")
    var old_speed: float = preferences.battle_speed
    var speeds: Array[float] = [1.0,1.5,2.0]
    var role_index := 0
    for key: String in ["gym:brock","elite:lance","champion:cynthia","gym:iono","elite:larry"]:
        preferences.battle_speed = speeds[role_index % speeds.size()]
        role_index += 1
        view = make_boss(key)
        await process_frame
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.12).timeout
        var before := view.battle.snapshot()
        await wait_line("intro")
        await create_timer(0.18).timeout
        check(view.busy and view.trainer_intro.visible and view.stage.canvas.target_factor == 0,"Boss speaks before throwing the first ball")
        check(view.trainer_speech.quote.text == TrainerDialogue.line(view.opponent_trainer,"intro"),"Entrance selects this actual boss's own introduction")
        check(view.end_button.disabled and view.trainer_buttons.values().all(func(c: Button): return c.disabled),"Dialogue locks battle actions without an extra modal")
        await key_input(KEY_Q,"q")
        check(view.battle.snapshot() == before,"Key input and opening speech cannot change energy, cards or RNG")
        var expected_art := TrainerSprites.texture(view.opponent_trainer)
        check(view.trainer_intro.portrait == expected_art,"Entrance uses mapped original pixels or explicit generic fallback")
        if expected_art != null:
            check(view.trainer_intro.portrait_rect().end.x <= 1620,"Trainer portrait clears the right roster")
            check(absf(view.trainer_intro.portrait_rect().end.y-view.trainer_intro.trainer_foot().y) <= 1,"Opaque portrait feet meet the calibrated floor")
        await shot(key.replace(":","-")+"-intro")
        if expected_art != null:
            for tick in 500:
                if view.trainer_intro.projectile: break
                await create_timer(0.01).timeout
            await create_timer(0.10).timeout
            check(view.trainer_intro.pose == "throw" and view.trainer_intro.projectile and view.trainer_intro.throw_progress > 0 and view.trainer_intro.throw_progress < 1,"Original sprite retains timed ball flight before Pokemon release")
            await shot(key.replace(":","-")+"-throw")
        view.finish_presentation()
        await process_frame
        check(not view.busy and not view.trainer_speech.visible and view.stage.canvas.target_factor == 1,"Finishing entrance restores Pokemon, hand and input")
        check(view.dialogue_history.size() == 1,"Opening line occurs exactly once")
        # Scene fixture: previous foes defeated; one legal attack sends out the last.
        var b := view.battle
        b.enemy_index = b.enemies.size()-2
        b.turn = 2
        for i in b.enemy_index:
            b.enemies[i].hp = 0
            b.enemies[i].knocked_out = true
        b.enemy().hp = 1
        b.enemy().block = 0
        b.enemies[-1].hp = 1
        b.enemies[-1].block = 0
        view._refresh()
        UiMotion.finish_tree(view)
        await process_frame
        await press(view.trainer_buttons[101])
        before = b.snapshot()
        check(b.enemy_index == b.enemies.size()-1,"Actual drawn attack legally sends out the last foe")
        await wait_line("last")
        await create_timer(0.18).timeout
        check(not view.get_node("Intent").visible,"Dialogue temporarily hides the intent instead of overlapping it")
        check(view.busy and view.trainer_speech.quote.text == TrainerDialogue.line(view.opponent_trainer,"last"),"Last-Pokemon speech follows the real ball release")
        check("enemy_switch" in view.playback_kinds and view._view_enemy().uid == b.enemy().uid,"Speech uses the newly displayed foe, not an early final-state HUD")
        await key_input(KEY_ENTER,"Return")
        check(b.snapshot() == before,"Last-Pokemon dialogue and blocked Enter never advance combat")
        await shot(key.replace(":","-")+"-last")
        var mid_battle := BattleCardPreview.copy_battle(b)
        view.finish_presentation()
        await press(view.trainer_buttons[103])
        view.finish_presentation()
        check(view.dialogue_history.size() == 2 and not view.trainer_speech.visible,"Following cards do not replay the last-Pokemon speech")
        await process_frame
        await press(view.trainer_buttons[102])
        view.finish_presentation()
        await process_frame
        UiMotion.finish_tree(view)
        check(b.phase == TacticalBattle.WON and view.result.visible,"Real final attack reaches the normal victory result")
        check(view.result_speech.visible and view.result_speech.quote.text == TrainerDialogue.line(view.opponent_trainer,"defeat"),"Defeated boss's own line remains readable in results")
        check(not view.result_speech.get_rect().intersects(view.result_next.get_rect()) and not view.result_speech.get_rect().intersects(view.result_restart.get_rect()),"Result quote clears both existing result buttons")
        check(view.result_speech.quote.get_line_count()*view.result_speech.quote.get_line_height() <= view.result_speech.quote.size.y,"Full defeat line fits result text area")
        await shot(key.replace(":","-")+"-defeat")
        var opponent := view.opponent_trainer.duplicate(true)
        var victory := BattleCardPreview.copy_battle(b)
        view.free()
        # Reconstructed checkpoints never replay already resolved presentation events.
        for saved: TacticalBattle in [mid_battle,victory]:
            before = saved.snapshot()
            var resumed := TacticalUI.new()
            resumed.battle = saved
            resumed.opponent_trainer = opponent
            root.add_child(resumed)
            await process_frame
            check(not resumed.busy and resumed.dialogue_history.is_empty() and not resumed.trainer_speech.visible,"Resumed mid/final checkpoint does not replay opening or last speech")
            check(saved.snapshot() == before,"Restoring dialogue UI preserves battle checkpoint exactly")
            check(resumed.result_speech.visible == (saved.phase == TacticalBattle.WON),"Victory quote reconstructs directly from saved outcome")
            resumed.free()
    preferences.battle_speed = old_speed
    await actual_route_identity()
    for role: String in ["trainer","veteran"]:
        var generic := TacticalUI.new()
        generic.battle = TacticalBattle.new()
        generic.opponent_trainer = {"kind":role,"name":"일반 상대","type":"fire"}
        root.add_child(generic)
        await process_frame
        generic.finish_presentation()
        check(generic.dialogue_history.is_empty() and not generic.trainer_speech.visible,"Ordinary trainers retain the short generic entrance")
        generic.free()
    root.get_node("GameAudio").stop_all()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.2).timeout
    print("TRAINER_DIALOGUE_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," clicks, ",keys," keys")
    quit(0 if failures == 0 else 1)
func actual_route_identity() -> void:
    for role: String in ["gym","elite","champion"]:
        var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
        for i in j.route.stops.size():
            if j.route.stops[i]["kind"] == role:
                j.step = i
                break
        j.phase = TacticalJourney.MAP
        if role in ["elite","champion"]:
            j.badges = 8
            j.elite_wins = int(j.current()["league_index"])
        check(j.enter_next().is_empty(),"Enter an actual campaign boss encounter")
        var before := JourneySnapshot.encode(j)
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        await process_frame
        check(ui.battle_ui.opponent_trainer == TrainerDialogue.opponent(j.current(),j.biome()),"Journey passes stable trainer ID, region and actual specialty")
        ui.battle_ui.finish_presentation()
        check(JourneySnapshot.encode(j) == before,"Complete boss introduction leaves real campaign snapshot unchanged")
        ui.refresh()
        await process_frame
        check(not ui.battle_ui.busy and ui.battle_ui.dialogue_history.is_empty(),"Refreshing same campaign battle cannot replay its intro")
        ui.free()
