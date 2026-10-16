extends SceneTree
## Timed animation checks plus actual GUI input. The native subclass uses XTest.
var native := false
var checks := 0
var failures := 0
var clicks := 0
var output := "/tmp/pokemon-presentation"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control) -> void:
    UiMotion.finish_tree(control)
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    clicks += 1
    if native:
        var point := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
        await create_timer(0.16).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
func wait_kind(ui: TacticalUI, kind: String) -> void:
    for i in 200:
        if kind in ui.playback_kinds: return
        await create_timer(0.01).timeout
    check(false,"Playback reached "+kind)
func finish(ui: TacticalUI) -> void:
    for i in 400:
        if not ui.busy: return
        await create_timer(0.01).timeout
    check(false,"Timed presentation completes")
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.12).timeout
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    Engine.max_fps = 60
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(0,0)
    var b := TacticalBattle.new(71)
    b.energy = 8
    b.enemy().max_hp = 500
    b.enemy().hp = 500
    b.hand.assign([BattleCardInstance.new(101,"move_55",7),BattleCardInstance.new(102,"guard",0),BattleCardInstance.new(103,"move_52",4)])
    b.draw_pile.clear()
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    await process_frame
    UiMotion.finish_tree(ui)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.15).timeout
    await click(ui.trainer_buttons[101])
    await wait_kind(ui,"switch")
    var resolved := b.snapshot()
    check(ui.busy and b.active().uid == 7 and ui._view_active().uid == 4,"Rules commit atomically while the outgoing Pokemon remains visible")
    if native: await create_timer(0.10).timeout
    else:
        var tracks: Dictionary = ui.motion.get_meta(UiMotion.META)
        tracks["ball"].custom_step(0.10)
    check(ui.stage.canvas.source_factor < 1 and ui.motion.mode == "recall","Outgoing Pokemon shrinks into the recall beam and ball")
    check(ui._view_enemy().hp == 500,"HP does not jump to final damage before the attack")
    await create_timer(0.17).timeout
    check(ui.motion.mode == "release" and ui._view_active().uid == 7,"New Pokemon appears during the ball release phase")
    await picture("ball-release")
    await wait_kind(ui,"skill")
    await create_timer(0.06).timeout
    check(ui.stage.canvas.source_motion.x > 0,"Player attack has a visible forward motion")
    check(ui._view_enemy().hp == 500,"Attack windup precedes damage application")
    await wait_kind(ui,"damage")
    check(ui._view_enemy().hp == b.enemy().hp and ui._view_enemy().hp < 500,"Damage applies at its own playback step")
    await finish(ui)
    check(b.snapshot() == resolved,"Playing visual frames never changes rules, RNG or recorded frames")
    var old_shield := b.active().block
    UiMotion.finish_tree(ui)
    await click(ui.trainer_buttons[102])
    check(ui.busy and ui._view_active().block == old_shield,"Shield gain waits for its action step")
    await wait_kind(ui,"shield")
    check(ui.shield_badges[0].visible and ui.shield_values[0].text == str(b.active().block),"Large blue shield badge agrees with the resolved protection")
    check(ui.damage_layer.get_children().any(func(n: Node): return n is RichTextLabel and n.text.contains("/shield.svg") and n.text.contains("+")),"Shield gain floats as a shield icon and a positive number")
    check(ui.damage_layer.get_children().all(func(n: Node): return not n is Control or n.mouse_filter == Control.MOUSE_FILTER_IGNORE),"Animated numbers never steal battle input")
    await picture("shield-gain")
    await finish(ui)
    await click(ui.end_button)
    await wait_kind(ui,"enemy_action")
    await create_timer(0.06).timeout
    check(ui.stage.canvas.target_motion.x < 0,"Enemy attack has a visible forward motion")
    await finish(ui)
    b.member(4).hp = 1
    b.member(4).statuses["burn"] = {"turns":2,"source_uid":-1}
    await click(ui.end_button)
    await finish(ui)
    check(b.member(4).hp == 0 and ui.stage.canvas.target_factor == 1 and ui.stage.canvas.source_factor == 1,"A benched DOT knockout never hides either active sprite")
    b.enemy().hp = 1
    b.enemy().block = 0
    b.energy = 8
    b.hand.assign([BattleCardInstance.new(104,"move_55",7)])
    ui._refresh()
    await process_frame
    UiMotion.finish_tree(ui)
    await click(ui.trainer_buttons[104])
    await wait_kind(ui,"enemy_switch")
    check(ui._view_enemy().uid == -1 and ui.busy,"Defeated enemy remains until replacement playback")
    await finish(ui)
    check(b.enemy_index == 1 and ui._view_enemy().uid == -2 and b.energy == 7 and is_equal_approx(ui.stage.canvas.target_factor,1),"Enemy replacement releases the next Pokemon without regranting energy")
    ui.free()
    # Use an actual camp, with controlled injury/HP to test target eligibility.
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],false)
    j.phase = TacticalJourney.MAP
    j.step = 1
    j.enter_next()
    j.party[0].hp = 1
    j.party[1].hp = 0
    j.party[1].knocked_out = true
    j.inventory["potion"] = 2
    j.inventory["revive"] = 1
    var camp: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    camp.journey = j
    root.add_child(camp)
    await process_frame
    UiMotion.finish_tree(camp)
    check(not camp.camp_tabs.has("loot"),"Redundant camp loot tab is removed")
    if native: print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    await click(camp.camp_tabs["bag"])
    await process_frame
    UiMotion.finish_tree(camp)
    check(camp.camp_tab == "bag","Bag tab receives the actual pointer")
    if camp.camp_tab != "bag":
        quit(1)
        return
    check(camp.page.find_children("Use_*","Button",true,false).is_empty(),"Bag shows item tiles before choosing a target")
    await picture("camp-bag")
    await click(camp.page.find_child("Bag_potion",true,false))
    await process_frame
    UiMotion.finish_tree(camp)
    var picker: Control = camp.page.get_node("ItemPicker")
    check(picker.find_children("Use_*","Button",true,false).size() == 3,"Item popup shows the full sprite party list")
    check(picker.find_child("Use_potion_1",true,false).disabled and picker.find_child("Use_potion_2",true,false).disabled,"Healing cannot target fainted or full-health members")
    await picture("camp-item-target")
    var untouched := j.party[2].hp
    await click(picker.find_child("Use_potion_0",true,false))
    await process_frame
    check(j.inventory["potion"] == 1 and j.party[0].hp > 1 and j.party[2].hp == untouched and camp.bag_item.is_empty(),"One click consumes one item and heals only the chosen member")
    UiMotion.finish_tree(camp)
    await click(camp.page.find_child("Bag_revive",true,false))
    await process_frame
    check(not camp.page.find_child("Use_revive_1",true,false).disabled and camp.page.find_child("Use_revive_0",true,false).disabled,"Revive popup targets fainted members only")
    UiMotion.finish_tree(camp)
    await click(camp.page.get_node("ItemPicker/Body/Close"))
    await process_frame
    check(camp.bag_item.is_empty() and j.inventory["revive"] == 1,"Cancelling popup consumes no item")
    camp.free()
    # First departure uses the same input-blocking travel as later stops.
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/presentation_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/presentation_journey.json"))
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    current_scene = menu
    await process_frame
    UiMotion.finish_tree(menu)
    await click(menu.start_button)
    await process_frame
    await click(menu.species_buttons[1])
    await process_frame
    await click(menu.confirm_button)
    check(menu.starting and is_instance_valid(menu.departure) and menu.departure.visible,"First party confirmation shows the departure screen")
    var first_run: TacticalJourney = session.get("journey")
    menu._start()
    check(session.get("journey") == first_run,"Repeated start during loading cannot create a second run")
    await create_timer(0.16).timeout
    check(menu.departure.progress > 0 and menu.departure.progress < 1,"First departure animates before battle begins")
    await picture("first-departure")
    await scene_changed
    check(current_scene is TacticalJourneyUI and current_scene.journey == first_run,"Departure arrives in the selected party's real battle")
    print("PRESENTATION native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
