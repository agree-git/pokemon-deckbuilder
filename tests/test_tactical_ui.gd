extends SceneTree
var failures := 0
var checks := 0
var ui: TacticalUI
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func find_button(node: Node,title: String) -> Button:
    if node is Button and node.text == title: return node
    for child: Node in node.get_children():
        var found := find_button(child,title)
        if found != null: return found
    return null

func key(code: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = true
    root.push_input(event)
func close_overlay(overlay: Control) -> void:
    TacticalUIPlayer.click(self,overlay.get_node("Body/Close"))
func hover_edges(control: Button,dimensions: Vector2i) -> void:
    for local: Vector2 in [Vector2(control.size.x/2,3),control.size/2,Vector2(control.size.x/2,control.size.y-3)]:
        var event := InputEventMouseMotion.new()
        event.position = root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        root.push_input(event)
        await process_frame
        check(root.gui_get_hovered_control() == control,"Rendered hit area %s / %s / %s" % [dimensions,control.tooltip_text,local])
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        await process_frame
        await process_frame
        ui.restart()
        var analysis: Button
        for c: BattleCardInstance in ui.battle.hand:
            if c.key == "analysis": analysis = ui.trainer_buttons[c.uid]
        check(not ui.menu_panel.visible and not ui.help_panel.visible,"Rules and trial settings stay hidden during combat")
        for control: Button in [ui.history_button,ui.menu_button,ui.help_button,ui.draw_button,ui.discard_button,ui.end_button,ui.party_buttons[0],ui.skills[1],analysis]:
            await hover_edges(control,dimensions)
        TacticalUIPlayer.click(self,ui.history_button)
        await process_frame
        check(ui.log_panel.visible,"History icon opens log via pointer")
        var unchanged := ui.battle.snapshot()
        key(KEY_2)
        await process_frame
        check(ui.battle.snapshot() == unchanged,"Modal blocks gameplay hotkeys")
        close_overlay(ui.log_panel)
        TacticalUIPlayer.click(self,ui.help_button)
        await process_frame
        check(ui.help_panel.visible,"Help icon opens rules")
        # Clicking a covered skill dismisses the help, without playing through it.
        TacticalUIPlayer.click(self,ui.skills[1])
        await process_frame
        check(ui.battle.snapshot() == unchanged,"Help prevents click-through to gameplay")
        key(KEY_ESCAPE)
        await process_frame
        # Escape closes help if it covered the target, otherwise opens the menu.
        ui._close_overlays()
        TacticalUIPlayer.click(self,ui.draw_button)
        await process_frame
        check(ui.pile_panel.visible and ui.battle.snapshot() == unchanged,"Draw-pile inspection does not change state or random order")
        close_overlay(ui.pile_panel)
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        check(ui.menu_panel.visible,"Menu icon reveals secondary actions")
        await hover_edges(ui.restart_button,dimensions)
        await hover_edges(ui.relic_buttons["break_focus"],dimensions)
        close_overlay(ui.menu_panel)
        TacticalUIPlayer.click(self,ui.skills[1])
        await process_frame
        check(ui.battle.enemy().statuses.has("seed") and ui.busy,"Pointer plays fixed skill and locks animation")
        var before := ui.battle.snapshot()
        TacticalUIPlayer.click(self,ui.end_button)
        check(ui.battle.snapshot() == before,"Animation blocks duplicate gameplay input")
        TacticalUIPlayer.finish(ui)
        await process_frame
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        TacticalUIPlayer.click(self,ui.relic_buttons["break_focus"])
        await process_frame
        check(ui.battle.relic == "break_focus" and ui.battle.turn == 1 and ui.battle.energy == 3,"Trait click starts fresh deterministic trial")
        check(not ui.menu_panel.visible,"Trait selection returns to clean battle view")
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        TacticalUIPlayer.click(self,ui.restart_button)
        await process_frame
        check(ui.battle.relic == "break_focus","Restart keeps selected trait")
    # An entire legal battle through rendered controls, without calling action handlers.
    ui.restart("seed_relay")
    var actions := 0
    for guard in 100:
        if ui.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var step := TacticalPolicy.action(ui.battle)
        var target := TacticalUIPlayer.button(ui,step)
        check(not target.disabled,"Strategy selects available rendered control")
        for chip: Control in ui.enemy_statuses.get_children():
            check(not ui.skills.any(func(button: Button): return button.get_global_rect().intersects(chip.get_global_rect())),"Status icons must remain visible beside the skill controls")
        TacticalUIPlayer.click(self,target)
        actions += 1
        await process_frame
        TacticalUIPlayer.finish(ui)
        await process_frame
    check(ui.battle.phase == TacticalBattle.WON and ui.result.visible,"Full pointer battle reaches victory modal")
    key(KEY_F1)
    await process_frame
    check(not ui.help_panel.visible,"Help shortcut cannot open an invisible modal behind the result")
    for local: Vector2 in [Vector2(ui.result_restart.size.x/2,3),ui.result_restart.size/2,Vector2(ui.result_restart.size.x/2,ui.result_restart.size.y-3)]:
        var event := InputEventMouseMotion.new()
        event.position = root.get_final_transform()*(ui.result_restart.get_global_transform_with_canvas()*local)
        root.push_input(event)
        await process_frame
        check(root.gui_get_hovered_control() == ui.result_restart,"Victory modal has top-to-bottom hit priority")
    TacticalUIPlayer.click(self,ui.result_restart)
    await process_frame
    check(ui.battle.phase == TacticalBattle.PLAYER and not ui.result.visible,"Modal restart resets battle")
    for guard in 80:
        if ui.battle.phase == TacticalBattle.LOST: break
        var target := ui.end_button
        if ui.battle.phase == TacticalBattle.REPLACE:
            for button: Button in ui.party_buttons:
                if not button.disabled:
                    target = button
                    break
        TacticalUIPlayer.click(self,target)
        await process_frame
        TacticalUIPlayer.finish(ui)
        await process_frame
    check(ui.battle.phase == TacticalBattle.LOST and ui.result.visible,"No-action defeat and forced replacements complete through pointer")
    ui.restart()
    ui.battle.use_skill("growth")
    var saved := ui.battle.snapshot()
    var old_run: RunState = root.get_node("BattleSession").get("run")
    var old_snapshot := old_run.battle.snapshot()
    ui.free()
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(ui.battle.snapshot() == saved and old_run.battle.snapshot() == old_snapshot,"Scene re-entry preserves separate tactical and expedition state")
    ui._refresh()
    current_scene = ui
    TacticalUIPlayer.click(self,ui.menu_button)
    await process_frame
    TacticalUIPlayer.click(self,ui.lab_button)
    await scene_changed
    await process_frame
    check(current_scene is ArtLab,"F2 button enters art lab")
    TacticalUIPlayer.click(self,find_button(current_scene,"전투 UI로 돌아가기 · F2"))
    await scene_changed
    await process_frame
    ui = current_scene as TacticalUI
    check(ui != null and ui.battle.snapshot() == saved,"Art lab returns to tactical mode with state intact")
    TacticalUIPlayer.click(self,ui.menu_button)
    await process_frame
    TacticalUIPlayer.click(self,ui.old_button)
    await scene_changed
    await process_frame
    check(current_scene is BattleUI,"F3 button enters original expedition")
    check(old_run.battle.snapshot() == old_snapshot,"Opening original mode preserves its existing expedition")
    var old_ui := current_scene as BattleUI
    old_ui._open_lab()
    await scene_changed
    await process_frame
    TacticalUIPlayer.click(self,find_button(current_scene,"전투 UI로 돌아가기 · F2"))
    await scene_changed
    await process_frame
    check(current_scene is BattleUI,"Art lab also returns to original mode when opened there")
    TacticalUIPlayer.click(self,find_button(current_scene,"전술 시험 · F3"))
    await scene_changed
    await process_frame
    ui = current_scene as TacticalUI
    check(ui != null and ui.battle.snapshot() == saved,"F3 comparison round trip preserves tactical progress")
    ui.restart()
    ui.free()
    print("TACTICAL_UI: ",checks," checks, ",failures," failures; ",actions," pointer actions to victory at 4 viewport sizes")
    quit(0 if failures == 0 else 1)
