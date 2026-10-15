extends SceneTree
var failures := 0
var checks := 0
var native := false
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    root.gui_embed_subwindows = true
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    TacticalUIPlayer.settle(ui)
    var skill := ui.skills[0]
    # Tooltip windows and other helper Nodes are not CanvasItems. Place another
    # visual after them to detect an aborted traversal, not only the error log.
    var popup := PopupPanel.new()
    skill.add_child(popup)
    var helper := Timer.new()
    skill.add_child(helper)
    var trailing := Label.new()
    trailing.text = "tooltip regression"
    trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    skill.add_child(trailing)
    skill.disabled = true
    CombatWidgets.fade(skill)
    check(is_equal_approx(trailing.modulate.a,0.43),"Disabled fade reaches visuals after PopupPanel and Timer")
    skill.disabled = false
    CombatWidgets.fade(skill)
    check(is_equal_approx(trailing.modulate.a,1.0),"Enabled fade restores visuals past nonvisual children")
    popup.free()
    helper.free()
    trailing.free()
    # The OS input probe also opens Godot's own tooltip, rather than a fixture.
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
        var hovered := ui.skills[0]
        var at := Vector2(root.position)+root.get_final_transform()*(hovered.get_global_transform_with_canvas()*(hovered.size/2))
        print("OS_MOVE ",roundi(at.x)," ",roundi(at.y))
        await create_timer(1.6).timeout
        var tooltip: PopupPanel
        for child: Node in hovered.get_children(true):
            if child is PopupPanel: tooltip = child
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("/tmp/pokemon-tooltip.png")
        check(is_instance_valid(tooltip) and tooltip.visible,"Hover creates the engine's real skill tooltip")
    var before := ui.battle.snapshot()
    ui._refresh()
    check(ui.battle.snapshot() == before,"Refreshing a hovered skill preserves the battle")
    ui._skill_slot(0)
    await process_frame
    TacticalUIPlayer.finish(ui)
    check(not ui.battle.skill_reason(TacticalContent.skills_for(ui.battle.active())[0]).is_empty(),"Hovered skill still executes and becomes unavailable")
    ui.queue_free()
    await process_frame
    print("TOOLTIPS: ",checks," checks, ",failures," failures; OS input ",native)
    quit(0 if failures == 0 else 1)
