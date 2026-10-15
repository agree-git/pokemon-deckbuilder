extends SceneTree
var failures := 0
var checks := 0
var clicks := 0
var native := false
var choose_evolution := false
var ui: TacticalJourneyUI
var captured: Dictionary = {}
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    if is_instance_valid(ui.battle_ui): TacticalUIPlayer.finish(ui.battle_ui)
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
func click(control: Control) -> void:
    settle()
    if control is TrainerActionCard and is_instance_valid(ui.battle_ui):
        ui.battle_ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        settle()
    if native:
        var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.28).timeout
    else:
        TacticalUIPlayer.click(self,control)
        await process_frame
    clicks += 1
    settle()
    await process_frame
    if native: await create_timer(0.12).timeout
func capture(label: String) -> void:
    if DisplayServer.get_name() == "headless" or captured.has(label): return
    captured[label] = true
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await RenderingServer.frame_post_draw
    var output := "/workspace/.cloud-setup/pokemon-deckbuilder/previews"
    DirAccess.make_dir_recursive_absolute(output)
    check(root.get_texture().get_image().save_png(output+"/journey_"+label+".png") == OK,"Save rendered journey screen: "+label)
    root.size = prior
    await process_frame
    if native: await create_timer(0.18).timeout
func verify_page() -> void:
    var phase := ui.journey.phase
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        await process_frame
        settle()
        for control: Button in ui.actions:
            check(Rect2(Vector2.ZERO,ui.size).encloses(control.get_global_rect()),"Journey action remains inside logical viewport at %s" % dimensions)
        await click(ui.deck_button)
        check(ui.deck_open,"Deck opens at %s" % dimensions)
        await click(ui.actions[0])
        check(ui.deck_open and ui.journey.phase == phase,"Deck modal blocks underlying progression")
        await click(ui.deck_close)
        check(not ui.deck_open and ui.journey.phase == phase,"Deck closes without changing progress")
    root.size = Vector2i(1280,720)
    await process_frame
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    var session := root.get_node("BattleSession")
    session.set("journey",TacticalJourney.new())
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    var pages_checked: Dictionary = {}
    for guard in 600:
        if ui.journey.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
        if ui.journey.phase == TacticalJourney.BATTLE:
            var battle := ui.journey.battle
            await capture("gym" if ui.journey.step == 4 else "battle")
            if battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                check(ui.battle_ui.result.visible,"Every encounter opens result via rendered battle UI")
                await click(ui.battle_ui.result_next)
            else:
                await click(TacticalUIPlayer.button(ui.battle_ui,JourneyPolicy.action(battle)))
        else:
            if choose_evolution and ui.journey.phase == TacticalJourney.REST and ui.journey.step == 3:
                await verify_page()
                await capture("evolution_choice")
                var pokemon := ui.journey.party[0]
                var uid := pokemon.uid
                check(pokemon.level == 16 and pokemon.learned_skills.size() == 4 and not ui.actions[4].disabled,"Second camp offers first evolution and learned fourth move")
                await click(ui.actions[4])
                check(pokemon.species_id == 5 and pokemon.uid == uid and ui.journey.phase == TacticalJourney.MAP,"Pointer evolves correct member and consumes camp")
                await capture("evolution")
                continue
            if not pages_checked.has(ui.journey.phase):
                await verify_page()
                await capture(ui.journey.phase)
                pages_checked[ui.journey.phase] = true
            await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.CLEARED and ui.journey.badges == 1 and ui.journey.wins == 3,"Complete journey wins gym badge through pointer actions only")
    if choose_evolution:
        check(ui.journey.party[0].species_id == 5 and ui.journey.party[0].level >= 16,"Evolved member and level persist through gym victory")
    await capture("result")
    var retained := ui.journey
    ui.free()
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(ui.journey == retained and ui.journey.phase == TacticalJourney.CLEARED,"Scene reentry retains final run state")
    await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.BATTLE and ui.journey.badges == 0 and ui.journey.deck.size() == 10,"Result restart resets entire journey")
    # Run-specific menu restart must also reset the expedition, with selected trait.
    await click(ui.battle_ui.menu_button)
    await click(ui.battle_ui.relic_buttons["switch_power"])
    check(ui.journey.relic == "switch_power" and ui.battle_ui.battle == ui.journey.battle and ui.journey.step == 0,"Trait menu restarts the run and binds new battle")
    if not native:
        # Failure fixture still takes actual pointer path to result and new run.
        for pokemon: BattlePokemon in ui.journey.party: ui.journey.battle._damage(pokemon,999,true)
        ui.journey.battle._outcome()
        ui.battle_ui._refresh()
        await click(ui.battle_ui.result_next)
        check(ui.journey.phase == TacticalJourney.FAILED,"Loss result opens failed journey summary")
        var old_seed := ui.journey.seed_value
        await click(ui.actions[1])
        check(ui.journey.phase == TacticalJourney.BATTLE and ui.journey.seed_value != old_seed,"New-seed button begins clean expedition")
        # Training fixture verifies the second rest action, not the healing path.
        ui.journey.phase = TacticalJourney.REST
        ui.journey.step = 1
        ui.refresh()
        var hp := ui.journey.party[0].max_hp
        await click(ui.actions[1])
        check(ui.journey.phase == TacticalJourney.MAP and ui.journey.party[0].max_hp == hp+8,"Training selection grows correct party member via pointer")
    ui.free()
    print("JOURNEY_UI: ",checks," checks, ",failures," failures; ",clicks," pointer actions; OS input ",native)
    quit(0 if failures == 0 else 1)
