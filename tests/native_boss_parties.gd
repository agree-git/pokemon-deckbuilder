extends SceneTree
var checks := 0
var failures := 0
var keys := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func wait_ui(ui: TacticalUI) -> void:
    for i in 300:
        if not ui.busy: return
        await create_timer(.05).timeout
    check(false,"Boss presentation finished within 15 seconds")
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    keys += 1
    await create_timer(.3).timeout
func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OS.get_environment("BOSS_PARTY_REVIEW_DIR").path_join(name+".png")) == OK,"Capture "+name)
func run() -> void:
    var folder := OS.get_environment("BOSS_PARTY_REVIEW_DIR")
    if DisplayServer.get_name() == "headless" or folder.is_empty(): quit(2); return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var targets := ["gym:brock","gym:tate_liza","elite:olivia","elite:drayton","champion:cynthia","champion:red"]
    var found := {}
    for seed_value in 200:
        var route := CampaignRoute.new(seed_value)
        for step in route.stops.size():
            var stop: Dictionary = route.stops[step]
            if stop["kind"] not in ["gym","elite","champion"]: continue
            var boss := TrainerDialogue.key(TrainerDialogue.opponent(stop,stop["biome"]))
            if boss in targets and not found.has(boss): found[boss] = [seed_value,step]
        if found.size() == targets.size(): break
    check(found.size() == targets.size(),"All representative cases reached through actual seeded routes")
    for boss: String in targets:
        if not found.has(boss): continue
        var j := TacticalJourney.new(found[boss][0],"field_kit",[3,6,9],true)
        j.step = found[boss][1]
        j.phase = TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:
            j.badges = 8
            j.elite_wins = int(j.current()["league_index"])
        check(j.enter_next().is_empty(),"Enter actual v5 "+boss)
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        await create_timer(.5).timeout
        check(TrainerDialogue.key(ui.battle_ui.opponent_trainer) == boss and ui.battle_ui.trainer_intro != null,"Correct portrait/intro for "+boss)
        check(j.battle.enemies.map(func(p: BattlePokemon): return p.species_id) == BossParties.party(boss),"Actual ordered new party "+boss)
        check(root.get_node("GameMusic").current_key.begins_with(boss+":"),"Original dedicated music retained "+boss)
        await shot(boss.replace(":","-")+"-entrance")
        await wait_ui(ui.battle_ui)
        # Deterministic knockouts drive the real switch-event animation to the ace.
        for slot in j.battle.enemies.size()-1:
            ui.battle_ui._action_before = BattleFrame.capture(j.battle)
            j.battle.events.clear()
            j.battle._damage(j.battle.enemy(),j.battle.enemy().hp,true)
            j.battle._outcome()
            ui.battle_ui._present("")
            await wait_ui(ui.battle_ui)
        check(j.battle.enemy().species_id == BossParties.aces(boss)[-1],"Final fixed representative "+boss)
        check(ui.battle_ui.queue_label.text == "%d / %d" % [j.battle.enemies.size(),j.battle.enemies.size()],"Visible enemy queue reaches final slot "+boss)
        await shot(boss.replace(":","-")+"-ace")
        if boss == "champion:cynthia":
            var before := JourneySnapshot.encode(j)
            await key("Escape")
            check(ui.battle_ui.menu_panel.visible and root.get_node("GameMusic").muffled,"Actual pause muffles new boss party scene")
            await key("Escape")
            check(not root.get_node("GameMusic").muffled and JourneySnapshot.encode(j) == before,"Pause resumes without changing boss/save state")
        ui.free()
        await process_frame
    for name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]: root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native boss parties: %d checks / %d failures; %d OS keys" % [checks,failures,keys])
    quit(1 if failures else 0)
