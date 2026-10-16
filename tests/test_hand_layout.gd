extends SceneTree
## Overlap, animated hover and actual card selection at multiple window ratios.
var native := false
var checks := 0
var failures := 0
var moves := 0
var clicks := 0
var ui: TacticalUI
var output := "/tmp/pokemon-hand-layout"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func point(card: Control,local: Vector2,click := false) -> void:
    var at := root.get_final_transform()*(card.get_global_transform_with_canvas()*local)
    moves += 1
    if click: clicks += 1
    if native:
        at += Vector2(root.position)
        print("OS_CLICK " if click else "OS_MOVE ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.22).timeout
    else:
        var event := InputEventMouseMotion.new()
        event.position = at
        root.push_input(event)
        if click:
            for down in [true,false]:
                var button := InputEventMouseButton.new()
                button.position = at
                button.button_index = MOUSE_BUTTON_LEFT
                button.pressed = down
                root.push_input(button)
        await process_frame
    UiMotion.finish_tree(ui)
    await process_frame
func fixture(count: int) -> void:
    if is_instance_valid(ui): ui.free()
    var b := TacticalBattle.new(2026)
    b.enemy().max_hp = 500
    b.enemy().hp = 500
    b.energy = 50
    b.hand.clear()
    var keys := ["move_52","guard","focus","move_55","rally","analysis","move_22","counter","potion_card","hold"]
    for i in count:
        b.hand.append(BattleCardInstance.new(101+i,keys[i],{0:4,3:7,6:1}.get(i,0)))
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    await process_frame
    UiMotion.finish_tree(ui)
    await process_frame
func picture(name_text: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(name_text+".png")) == OK,"Save actual hand capture")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        root.position = Vector2i.ZERO
        await create_timer(0.1).timeout
        for count in [5,6,8,10]:
            await fixture(count)
            var before := ui.battle.snapshot()
            var cards: Array[TrainerActionCard] = []
            for c: BattleCardInstance in ui.battle.hand: cards.append(ui.trainer_buttons[c.uid])
            check(ui.hand_scroll.get_h_scroll_bar().visible == false,"No scrolling required for %d cards" % count)
            var area := ui.hand_row.get_global_rect()
            for card: TrainerActionCard in cards:
                check(area.encloses(card.face.get_global_rect()),"All %d card faces fit hand area at %s" % [count,dimensions])
            var spacing := cards[1].position.x-cards[0].position.x
            check((spacing < TrainerActionCard.FACE_SIZE.x) == (count > 5),"Only large hands overlap")
            if count != 10: continue
            if dimensions == Vector2i(1920,1080): await picture("ten-cards")
            for card: TrainerActionCard in cards:
                await point(card,TrainerActionCard.HOME+Vector2(card.hand_exposed_width/2,200))
                check(root.gui_get_hovered_control() == card,"Every exposed card remains selectable: %s uid=%d actual=%s pointer=%s" % [dimensions,card.uid,root.gui_get_hovered_control(),root.get_mouse_position()])
                check(card._hovered and card.z_index > 0 and card.face.scale.x > 1.05 and card.face.position.y < TrainerActionCard.HOME.y-20,"Hover raises, enlarges and brings the selected card forward: %s uid=%d" % [dimensions,card.uid])
                check(area.encloses(card.face.get_global_rect()),"Enlarged face fits the visible hand area")
            var chosen := cards[4]
            await point(chosen,TrainerActionCard.HOME+Vector2(chosen.hand_exposed_width/2,200))
            var base_step := (ui.hand_row.size.x-2*BattleHandLayout.EDGE-TrainerActionCard.SLOT_SIZE.x)/9.0
            check(cards[3].position.x < BattleHandLayout.EDGE+3*base_step and cards[5].position.x > BattleHandLayout.EDGE+5*base_step,"Both adjacent cards move sideways to make room for the hovered face")
            if dimensions == Vector2i(1920,1080): await picture("ten-cards-hover")
            await point(chosen,chosen.visible_point(0.0))
            check(root.gui_get_hovered_control() == chosen,"Raised top edge remains clickable")
            check(ui.battle.snapshot() == before,"Hover/layout cannot mutate cards, resources, piles or RNG")
            var uid := chosen.uid
            await point(chosen,chosen.visible_point(0.0),true)
            check(not ui.battle.hand.any(func(c: BattleCardInstance): return c.uid == uid) and ui.battle.hand.size() == 9,"Click plays the selected overlapped card exactly once")
            ui.finish_presentation()
            UiMotion.finish_tree(ui)
            await process_frame
            check(ui.trainer_buttons.size() == 9,"Hand reflows after playing a card")
    await fixture(5)
    var draw := ui.battle.hand[2]
    # Draw through the normal card rule, without injecting extra hand entries.
    var draw_button: TrainerActionCard = ui.trainer_buttons[draw.uid]
    await point(draw_button,draw_button.visible_point(),true)
    check(ui.battle.hand.size() == 6,"Actual draw card grows hand beyond five")
    ui.finish_presentation()
    UiMotion.finish_tree(ui)
    await process_frame
    check(ui.trainer_buttons.size() == 6,"Newly drawn cards enter the overlapping layout")
    ui.free()
    print("HAND_LAYOUT native=",native,": ",checks," checks, ",failures," failures; ",moves," pointer moves, ",clicks," clicks")
    quit(1 if failures else 0)
