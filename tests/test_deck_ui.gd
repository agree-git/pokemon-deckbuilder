extends SceneTree
var native := false
var capture_images := false
var failures := 0
var checks := 0
var clicks := 0
var keys := 0
var ui: TacticalJourneyUI
var output := "/tmp/pokemon-deck-previews"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    if ui.battle_ui != null: TacticalUIPlayer.finish(ui.battle_ui)
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
func click(control: Control,vertical := 0.5) -> void:
    settle()
    var local: Vector2 = control.visible_point(vertical) if control is TrainerActionCard else Vector2(control.size.x/2,lerpf(3,control.size.y-3,vertical))
    var at := root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    clicks += 1
    if native:
        at += Vector2(root.position)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.24).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
    settle()
    await process_frame
func key(symbol: String,code: Key) -> void:
    keys += 1
    if native:
        print("OS_KEY ",symbol)
        await create_timer(0.24).timeout
    else:
        var event := InputEventKey.new()
        event.keycode = code
        event.pressed = true
        root.push_input(event)
        await process_frame
    settle()
    await process_frame
func picture(name_text: String) -> void:
    if not native and not capture_images: return
    settle()
    var previous := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(name_text+".png")) == OK,"Save graphical inspection capture")
    root.size = previous
    await process_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i(0,0)
    root.size = Vector2i(1920,1080)
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/deck_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/deck_ui_journey.json"))
    session.adopt_journey(TacticalJourney.new(0,"field_kit",[1,4,7],true))
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.3).timeout
    var j := ui.journey
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        root.position = Vector2i(0,0)
        await create_timer(0.1).timeout
        for vertical in [0.0,0.5,1.0]:
            j.restart(0,"field_kit")
            ui.refresh()
            await process_frame
            settle()
            var card := j.battle.hand[0]
            await click(ui.battle_ui.trainer_buttons[card.uid],vertical)
            check(not j.battle.hand.has(card),"Card face click at top/middle/bottom hits its visible position in %s" % dimensions)
        await click(ui.battle_ui.help_button)
        var before := j.battle.snapshot()
        await key("Return",KEY_ENTER)
        check(j.battle.snapshot() == before and ui.battle_ui.help_panel.visible,"Modal blocks battle keys")
        await key("Escape",KEY_ESCAPE)
        check(not ui.battle_ui.help_panel.visible,"Escape closes help")
    root.size = Vector2i(1920,1080)
    j.restart(0,"field_kit")
    ui.refresh()
    await process_frame
    settle()
    check(ui.battle_ui.speed_label.text == ("스피드 +1" if j.battle.turn_energy_bonus == 1 else "기본 에너지 3"),"Visible energy caption reflects the captured turn-start speed bonus")
    check(ui.battle_ui.ally_label.tooltip_text == PokemonStats.summary(j.battle.active()),"Combatant tooltip shows all six original stats")
    check(ui.battle_ui.skills.is_empty() and not ui.battle_ui.has_node("Break"),"Unified hand replaces fixed skills and break HUD")
    await picture("unified-battle")
    if native:
        root.size = Vector2i(1280,720)
        await process_frame
    var first := j.battle.hand[0]
    await key("q",KEY_Q)
    check(not j.battle.hand.has(first),"Q plays first card instead of a fixed technique")
    var wins := 0
    for guard in 500:
        if j.phase == TacticalJourney.BATTLE:
            if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                if j.battle.phase == TacticalBattle.LOST:
                    check(false,"Graphical run lost")
                    break
                await click(ui.battle_ui.result_next)
                wins += 1
            else:
                var action := TacticalPolicy.action(j.battle)
                await click(TacticalUIPlayer.button(ui.battle_ui,action))
        elif j.phase == TacticalJourney.LEARN:
            await click(ui.actions.back())
        elif j.phase == TacticalJourney.REWARD:
            await picture("mixed-rewards")
            var option := j.reward_options[2].duplicate(true)
            await click(ui.actions[2])
            check(j.phase == TacticalJourney.MAP,"Mixed reward selection advances once")
            if option["kind"] == "held": check(option["key"] in j.held_inventory,"Held item reward enters equipment bag")
            if option["kind"] == "relic": check(option["key"] in j.relics,"Relic reward enters party collection")
        elif j.phase == TacticalJourney.MAP:
            await click(ui.actions[0])
            if ui.travelling:
                if native: await create_timer(1.0).timeout
                else: UiMotion.finish_tree(ui.travel)
                await process_frame
        elif j.phase == TacticalJourney.REST:
            check(j.wins == wins,"Real input completes combat and its settlement")
            await click(ui.actions.filter(func(button: Button): return button.name == "Upgrade")[0])
            check(ui.deck_open,"Camp opens explicit card-upgrade selector")
            var candidates: Array = ui.page.find_children("Card_*","Button",true,false).filter(func(button: Button): return not button.disabled)
            var uid := int(candidates[0].name.trim_prefix("Card_"))
            await click(candidates[0])
            check(not ui.deck_open and j.deck.any(func(card: BattleCardInstance): return card.uid == uid and card.upgraded),"Upgrade pointer selects the intended card instance")
            check(ui.rest_button.disabled,"Upgrade disables the alternative rest action")
            await picture("camp-upgrade")
            await click(ui.camp_tabs["gear"])
            await picture("camp-equipment")
            if not j.held_inventory.is_empty():
                var item_key := j.held_inventory[0]
                await click(ui.page.find_child("Equipment_%d" % j.party[0].uid,true,false))
                check(ui.gear_open_for == j.party[0].uid,"Equipment opens an in-scene item selector")
                await click(ui.page.find_child("Equip_"+item_key,true,false))
                check(j.party[0].held_item == item_key and ui.gear_open_for == 0,"Equipment selector equips through actual pointer")
                await picture("camp-equipped")
            check(session.get("save_store").load_journey() != null,"UI actions produce a resumable disk checkpoint")
            break
    check(wins == 1 and j.phase == TacticalJourney.REST,"One complete battle, mixed reward, travel and camp through input")
    if native:
        root.size = Vector2i(1920,1080)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        check(image.get_size() == Vector2i(1920,1080),"Graphics are rendered at native 1920x1080")
    ui.free()
    print("DECK_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions, ",keys," keys")
    quit(0 if failures == 0 else 1)
