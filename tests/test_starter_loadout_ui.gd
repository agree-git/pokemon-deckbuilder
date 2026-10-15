extends "res://tests/test_start_ui.gd"
var keys := 0
func click(control: Control,local := Vector2(-1,-1)) -> void:
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.12).timeout
    await super.click(control,local)
func key(symbol: String) -> void:
    if native:
        print("OS_MOVE 20 100")
        await create_timer(0.16).timeout
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.12).timeout
        print("OS_KEY ",symbol)
        await create_timer(0.22).timeout
    else:
        for down: bool in [true,false]:
            var event := InputEventKey.new()
            event.keycode = OS.find_keycode_from_string(symbol)
            event.pressed = down
            root.push_input(event)
        await process_frame
    await process_frame
    settle()
    keys += 1
func wheel(control: Control,steps: int) -> void:
    var local := control.size*0.8
    var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    if native:
        print("OS_WHEEL ",roundi(at.x)," ",roundi(at.y)," ",steps)
        await create_timer(0.3).timeout
    else:
        for i in absi(steps):
            for down: bool in [true,false]:
                var event := InputEventMouseButton.new()
                event.position = at-Vector2(root.position)
                event.button_index = MOUSE_BUTTON_WHEEL_DOWN if steps > 0 else MOUSE_BUTTON_WHEEL_UP
                event.pressed = down
                root.push_input(event)
        await process_frame
    settle()
    await process_frame
func save(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/pokemon-loadout/"+label+".png")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.3).timeout
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-loadout")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    path = "user://tests/loadout_%d/collection.json" % Time.get_ticks_usec()
    var profile := PlayerProfile.new(path)
    profile.captured_ids.assign([63,129,144,150,151])
    profile.save()
    session.set("profile",profile)
    session.set("save_store",JourneySave.new(path.get_base_dir()+"/journey.json"))
    var paused := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    session.adopt_journey(paused)
    var paused_snapshot := JourneySnapshot.encode(paused)
    var collection := FileAccess.get_file_as_string(path)
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    await process_frame
    settle()
    await click(current_scene.start_button)
    var menu := current_scene as MainMenu
    check(menu.mode == "starters" and menu.loadout_button.disabled,"Empty selection cannot open a phantom deck")
    for id: int in [1,4,7]: await click(menu.species_buttons[id])
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)]:
        root.size = dimensions
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        await click(menu.search)
        await click(menu.loadout_button)
        var panel := menu.loadout_panel
        check(is_instance_valid(panel) and panel.card_grid.get_child_count() == 15,"Visible preview button opens real cards at "+str(dimensions))
        check(not menu.search.has_focus(),"Opening the modal releases underlying keyboard focus")
        var query := menu.search.text
        await key("a")
        check(menu.search.text == query,"Typing inside the modal cannot edit or refilter the hidden selection")
        check(panel.card_grid.get_children().all(func(c: TrainerActionCard): return c.disabled and not c.effect_label.text.is_empty()),"Read-only card faces show content instead of playable actions")
        await click(panel.filter_buttons[0])
        check(panel.card_grid.get_child_count() == 6 and panel.card_grid.get_children().all(func(c: TrainerActionCard): return c.definition["species_id"] == 0),"Common filter shows the six shared cards")
        await click(panel.filter_buttons[4])
        check(panel.card_grid.get_child_count() == 3 and panel.card_grid.get_children().all(func(c: TrainerActionCard): return c.definition["species_id"] == 4 and c.category_label.text.contains("파이리")),"Portrait row filters to the correct owned techniques")
        await key("Escape")
        check(not is_instance_valid(menu.loadout_panel) and menu.mode == "starters" and menu.selection == [1,4,7],"Esc closes only the deck and preserves selection order")
    root.size = Vector2i(1280,720)
    await process_frame
    await click(menu.loadout_button)
    var panel := menu.loadout_panel
    await save("starting-deck")
    await wheel(panel.scroll,8)
    check(panel.scroll.scroll_vertical > 0,"Physical wheel reaches cards below the first row")
    var last: TrainerActionCard = panel.card_grid.get_children().back()
    await wheel(panel.scroll,30)
    var before := JourneySnapshot.encode(paused)
    await click(last,last.visible_point())
    check(JourneySnapshot.encode(paused) == before and session.get("journey") == paused,"Clicking a preview card cannot play or alter a paused run")
    await click(menu.confirm_button)
    check(menu.mode == "starters" and session.get("journey") == paused,"The modal blocks the actual start button below it")
    await key("Escape")
    for id: int in [1,4,7]: await click(menu.species_buttons[id])
    for id: int in [63,129,150]: await click(menu.species_buttons[id])
    await click(menu.loadout_button)
    panel = menu.loadout_panel
    var note: Label = panel.find_child("PreparationNote",true,false)
    check(note.text.contains("캐이시") and note.text.contains("잉어킹") and note.text.contains("발버둥"),"Support-only party explains exactly which starters need fallback attacks")
    check(panel.filter_buttons[150].get_children().any(func(c: Node): return c is Label and c.text.contains("초전설")),"Unlocked rare starter retains its tier label")
    await click(panel.filter_buttons[63])
    check(panel.card_grid.get_children().any(func(c: TrainerActionCard): return c.key == "move_165" and c.definition["species_id"] == 63),"Abra's real fallback card has the owner's sprite")
    for uid: int in [63,129,150]:
        var row: Button = panel.filter_buttons[uid]
        for child: Node in row.get_children():
            if child is Label and child.text.begins_with("HP "):
                check(child.position.x >= 0 and child.scale == Vector2.ONE,"Every stat line stays inside its party row")
    await save("support-starters")
    var expected := panel.loadout.cards.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid])
    await click(panel.find_child("Close",true,false))
    check(JourneySnapshot.encode(paused) == paused_snapshot and FileAccess.get_file_as_string(path) == collection,"All browsing leaves current save, collection and draw RNG unchanged")
    await click(menu.confirm_button)
    if not current_scene is TacticalJourneyUI: await scene_changed
    await process_frame
    settle()
    check(current_scene is TacticalJourneyUI,"Normal confirmation still performs departure and enters the game")
    var j: TacticalJourney = session.get("journey")
    check(j.starter_ids == [63,129,150] and j.party[0].species_id == 63,"Confirmed party and lead match the preview")
    check(j.deck.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid]) == expected,"Actual starting deck has exactly the preview's cards and ownership")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)) and session.get("save_notice").is_empty(),"Normal startup autosaves a valid campaign")
    print("STARTER_LOADOUT_UI: ",checks," checks, ",failures," failures; ",clicks," pointer actions; ",keys," keys")
    quit(0 if failures == 0 else 1)
