extends "res://tests/test_action_preview_ui.gd"
const W = preload("res://scripts/ui/combat_widgets.gd")
## Real card interaction plus a native rendered catalogue, never a player save.
func _initialize() -> void:
    native = true
    super._initialize()
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-card-icons")
    ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",30.0)
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    root.position = Vector2i.ZERO
    await fixture(true)
    var b := journey.battle
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    await create_timer(0.2).timeout
    var card: TrainerActionCard = ui.trainer_buttons[9200]
    await point(card,card.visible_point())
    check(root.gui_get_hovered_control() == card and ui.action_preview.visible,"Inline images preserve real native card hover and forecast")
    check(card.effect_label.text.contains("/attack.svg"),"Attack face actually contains the red sword")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("/tmp/pokemon-card-icons/battle.png") == OK,"Capture native 1920x1080 icon combat")
    # Cover the inline icon description itself. Forced tween completion can clear
    # Godot's hover cache, so verify delivered input and committed state below.
    await point(card,card.visible_point(0.82))
    check(card._has_point(card.visible_point(0.82)),"Expanded icon description remains inside the card input envelope")
    var delivery := {"down":0,"up":0,"pressed":0}
    card.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton:
            delivery["down" if event.pressed else "up"] += 1)
    card.pressed.connect(func(): delivery["pressed"] += 1)
    var before := b.snapshot()
    await point(card,card.visible_point(0.82),true)
    # X11 delivery can lag behind a software-rendered screenshot; never click twice.
    for i in 50:
        if not b.hand.any(func(c: BattleCardInstance): return c.uid == 9200): break
        await create_timer(0.02).timeout
    check(b.snapshot() != before and not b.hand.any(func(c: BattleCardInstance): return c.uid == 9200),"Native click on the enlarged icon card commits once")
    check(delivery == {"down":1,"up":1,"pressed":1},"Native mouse delivers exactly one press and release to the card")
    ui.finish_presentation()
    await point(ui,Vector2(1900,80))
    await point(ui.help_button,ui.help_button.size/2,true)
    check(ui.help_panel.visible,"Native help button opens the icon and status legend")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("/tmp/pokemon-card-icons/help.png") == OK,"Capture complete in-game icon legend")
    ui.free()
    var keys := ["guard","potion_card","smoke_card","ether_card","toxic_flask","antidote_card","relay_cover","ace_order","shield_strike","relay_plan","status_plan","status_cash","redraw","hold","retrieve","move_276","move_246","move_73","analysis","focus","rally","counter","boost_card","ace_plan","tool_plan","shield_cell","injury","move_52","move_79","move_86","move_109","move_105"]
    var owners := {"move_276":260,"move_246":138,"move_73":1,"move_52":4,"move_79":1,"move_86":25,"move_109":41,"move_105":64}
    var catalog := VisualCatalog.new()
    for page in 2:
        var gallery := Control.new()
        root.add_child(gallery)
        W.panel(gallery,Rect2(0,0,1920,1080),Color("0b1d24"))
        W.label(gallery,"카드 효과 · 아이콘과 설명으로 읽기 (%d/2)" % (page+1),Rect2(230,12,1460,40),26,W.GOLD)
        CardEffectText.legend(gallery,Rect2(230,56,1460,52))
        for i in range(page*18,mini(keys.size(),(page+1)*18)):
            var owner := int(owners.get(keys[i],0))
            var instance := BattleCardInstance.new(i,keys[i],owner)
            var face := CardStackView.new()
            face.definition = TacticalContent.definition(instance)
            if owner != 0:
                face.definition["species_id"] = owner
                face.definition["owner_name"] = catalog.species(owner)["name"]
            face.key = keys[i]
            var slot := i-page*18
            face.position = Vector2(230+(slot%6)*244,112+floori(slot/6.0)*310)
            gallery.add_child(face)
            check(not face.tooltip_text.is_empty(),"Catalogue keeps full description")
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var name := "catalogue.png" if page == 0 else "catalogue-2.png"
        check(root.get_texture().get_image().save_png("/tmp/pokemon-card-icons/"+name) == OK,"Capture native readable card catalogue")
        gallery.free()
    print("CARD_ICONS_NATIVE: ",checks," checks, ",failures," failures; ",moves," pointer moves, ",clicks," clicks")
    quit(0 if failures == 0 else 1)
