extends SceneTree
var failures := 0
var checks := 0
var clicks := 0
var native := false
var verify_camp := false
var bag_checked := false
var camp_checked := false
var learning_checked := false
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
        check(ui.journey.phase == phase,"Deck modal blocks underlying progression even when outside click dismisses it")
        if ui.deck_open: await click(ui.deck_close)
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
                if verify_camp and not bag_checked and battle.phase == TacticalBattle.PLAYER and battle.energy >= 1 and ui.journey.inventory["potion"] > 0:
                    for index in battle.party.size():
                        var pokemon := battle.party[index]
                        if pokemon.alive() and pokemon.hp < pokemon.max_hp:
                            var hp := pokemon.hp
                            var energy := battle.energy
                            await click(ui.battle_ui.menu_button)
                            await click(ui.battle_ui.bag_button)
                            await click(ui.battle_ui.bag_panel.get_node("Body/Items/Use_potion_%d" % index))
                            check(pokemon.hp == hp and battle.energy == energy,"Battle bag cannot bypass the tool-card hand")
                            await click(ui.battle_ui.bag_panel.get_node("Body/Close"))
                            bag_checked = true
                            break
                await click(TacticalUIPlayer.button(ui.battle_ui,JourneyPolicy.action(battle)))
        else:
            if not pages_checked.has(ui.journey.phase):
                await verify_page()
                await capture(ui.journey.phase)
                pages_checked[ui.journey.phase] = true
            if ui.journey.phase == TacticalJourney.REST:
                if verify_camp and not camp_checked:
                    await click(ui.rest_button)
                    check(ui.journey.phase == TacticalJourney.REST and ui.journey.step in ui.journey.rested_steps,"Rest keeps camp open for other services")
                    await click(ui.camp_tabs["shop"])
                    var coins := ui.journey.gold
                    var count := int(ui.journey.inventory["potion"])
                    await click(ui.page.find_child("Buy_potion",true,false))
                    check(ui.journey.gold == coins-30 and ui.journey.inventory["potion"] == count+1,"Shop purchase uses gold and enters bag")
                    await capture("shop")
                    await click(ui.camp_tabs["bag"])
                    check(ui.camp_tab == "bag","Bag remains available after resting and buying")
                    await capture("bag")
                    await click(ui.camp_tabs["gear"])
                    check(not ui.camp_tabs.has("loot") and ui.camp_tab == "gear","Equipment remains accessible and the redundant loot tab is removed")
                    await capture("equipment")
                    camp_checked = true
                elif ui.journey.step not in ui.journey.rested_steps:
                    await click(ui.rest_button)
                await click(ui.actions[0])
            elif ui.journey.phase == TacticalJourney.LEARN:
                if verify_camp and not learning_checked:
                    var offer := ui.journey.pending_learning[0]
                    var member: BattlePokemon
                    for pokemon: BattlePokemon in ui.journey.party:
                        if pokemon.uid == int(offer["uid"]): member = pokemon
                    await click(ui.learn_buttons[0])
                    check(member.learned_skills[0] == offer["key"] and member.learned_skills.size() == 4,"Learn screen replaces selected move and keeps four slots")
                    learning_checked = true
                else: await click(ui.actions.back())
            else: await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.CLEARED and ui.journey.badges == 1 and ui.journey.wins == 3,"Complete journey wins gym badge through pointer actions only")
    if verify_camp:
        check(ui.journey.party[0].species_id == 5 and ui.journey.party[0].level >= 16,"Experience automatically evolves the member at the original level without camp actions")
    await capture("result")
    var retained := ui.journey
    ui.free()
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(ui.journey == retained and ui.journey.phase == TacticalJourney.CLEARED,"Scene reentry retains final run state")
    await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.BATTLE and ui.journey.badges == 0 and ui.journey.deck.size() == TacticalContent.starting_deck(ui.journey.party).size(),"Result restart resets entire journey")
    # Run-specific menu restart must also reset the expedition, with selected trait.
    await click(ui.battle_ui.menu_button)
    await click(ui.battle_ui.restart_button)
    check(ui.journey.relic == "field_kit" and ui.battle_ui.battle == ui.journey.battle and ui.journey.step == 0,"Menu restart resets acquired items and binds new battle")
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
    ui.free()
    print("JOURNEY_UI: ",checks," checks, ",failures," failures; ",clicks," pointer actions; OS input ",native)
    quit(0 if failures == 0 else 1)
