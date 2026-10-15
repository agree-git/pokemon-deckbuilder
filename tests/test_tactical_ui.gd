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
    TacticalUIPlayer.settle(ui)
func hover_edges(control: Button,dimensions: Vector2i) -> void:
    for local: Vector2 in [Vector2(control.size.x/2,3),control.size/2,Vector2(control.size.x/2,control.size.y-3)]:
        if control is TrainerActionCard: local = control.visible_point(clampf(local.y/control.size.y,0,1))
        var event := InputEventMouseMotion.new()
        event.position = root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        root.push_input(event)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(root.gui_get_hovered_control() == control,"Rendered hit area %s / %s / %s" % [dimensions,control.tooltip_text,local])
func verify_animation_input() -> void:
    ui.restart("seed_relay")
    await process_frame
    await create_timer(0.52).timeout
    var card: TrainerActionCard
    for instance: BattleCardInstance in ui.battle.hand:
        if instance.key == "analysis": card = ui.trainer_buttons[instance.uid]
    var uid := card.uid
    var rest := card.face.get_global_rect()
    var root_rect := card.get_global_rect()
    var untouched: Dictionary = ui.trainer_buttons.duplicate()
    var move := InputEventMouseMotion.new()
    move.position = root.get_final_transform()*(card.get_global_transform_with_canvas()*card.visible_point())
    root.push_input(move)
    await create_timer(0.18).timeout
    check(card.face.get_global_rect().position.y < rest.position.y and card.get_global_rect() == root_rect,"Hover lifts card artwork while its input slot stays fixed")
    TacticalUIPlayer.click(self,card,card.visible_point(0))
    await process_frame
    check(not ui.trainer_buttons.has(uid) and ui.battle.opening()["analyzed"],"Raised card top plays the selected trainer card")
    check(ui.card_effects.get_child_count() > 0,"Played card has a temporary flight visual")
    for other: int in ui.trainer_buttons:
        check(ui.trainer_buttons[other] == untouched[other],"Unplayed cards keep identity through action and VFX refresh")
    var committed := ui.battle.snapshot()
    key(KEY_2)
    check(ui.battle.snapshot() == committed,"Card flight cannot allow a second gameplay action during VFX")
    await create_timer(0.76).timeout
    check(ui.card_effects.get_child_count() == 0 and not ui.busy,"Flight visuals clean up and input returns")
    ui._open_overlay(ui.menu_panel)
    UiMotion.close(ui.menu_panel)
    ui._open_overlay(ui.menu_panel)
    await create_timer(0.25).timeout
    check(ui.menu_panel.visible and is_equal_approx(ui.menu_panel.modulate.a,1),"Rapid modal reopen cancels its old closing callback")
    committed = ui.battle.snapshot()
    UiMotion.close(ui.menu_panel)
    key(KEY_2)
    check(ui.battle.snapshot() == committed,"Closing overlay shields gameplay input until fade ends")
    await create_timer(0.16).timeout
    check(not ui.menu_panel.visible,"Closing fade releases the modal")
    ui.battle._damage(ui.battle.active(),5)
    ui._refresh()
    var target := ui.ally_bar.size.x*ui.battle.active().hp/ui.battle.active().max_hp
    check(not is_equal_approx(ui.ally_bar.get_child(0).size.x,target),"Health bar animates toward authoritative HP")
    await create_timer(0.3).timeout
    check(is_equal_approx(ui.ally_bar.get_child(0).size.x,target),"Health animation settles at exact model HP")
    for instance: BattleCardInstance in ui.battle.hand:
        if ui.battle.card_reason(instance.uid).is_empty():
            ui._card(instance.uid)
            break
    ui.restart("seed_relay")
    await create_timer(0.6).timeout
    check(ui.battle.snapshot() == TacticalBattle.new().snapshot() and ui.card_effects.get_child_count() == 0,"Restart during flight discards visuals and stale callbacks without changing fresh state")
    while ui.battle.hand.size() < 10: ui.battle.hand.append(ui.battle._new_card("guard"))
    ui._refresh()
    await create_timer(0.6).timeout
    ui.hand_scroll.scroll_horizontal = int(ui.hand_row.size.x)
    await process_frame
    var last: int = ui.battle.hand.back().uid
    TacticalUIPlayer.click(self,ui.trainer_buttons[last])
    await process_frame
    check(not ui.trainer_buttons.has(last),"Scrolled extra hand cards retain their visible click area")
    TacticalUIPlayer.finish(ui)
    ui.restart("seed_relay")
    await process_frame
    TacticalUIPlayer.settle(ui)

func run() -> void:
    root.mode = Window.MODE_WINDOWED
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    TacticalUIPlayer.settle(ui)
    for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        await process_frame
        TacticalUIPlayer.settle(ui)
        await process_frame
        TacticalUIPlayer.settle(ui)
        ui.restart()
        var analysis: Button
        for c: BattleCardInstance in ui.battle.hand:
            if c.key == "analysis": analysis = ui.trainer_buttons[c.uid]
        check(not ui.menu_panel.visible and not ui.help_panel.visible,"Rules and trial settings stay hidden during combat")
        for control: Button in [ui.history_button,ui.menu_button,ui.help_button,ui.draw_button,ui.discard_button,ui.end_button,ui.party_buttons[0],ui.skills[1],analysis]:
            await hover_edges(control,dimensions)
        TacticalUIPlayer.click(self,ui.history_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.log_panel.visible,"History icon opens log via pointer")
        var unchanged := ui.battle.snapshot()
        key(KEY_2)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.battle.snapshot() == unchanged,"Modal blocks gameplay hotkeys")
        close_overlay(ui.log_panel)
        TacticalUIPlayer.click(self,ui.help_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.help_panel.visible,"Help icon opens rules")
        # Clicking a covered skill dismisses the help, without playing through it.
        TacticalUIPlayer.click(self,ui.skills[1])
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.battle.snapshot() == unchanged,"Help prevents click-through to gameplay")
        key(KEY_ESCAPE)
        await process_frame
        TacticalUIPlayer.settle(ui)
        # Escape closes help if it covered the target, otherwise opens the menu.
        ui._close_overlays(true)
        TacticalUIPlayer.click(self,ui.draw_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.pile_panel.visible and ui.battle.snapshot() == unchanged,"Draw-pile inspection does not change state or random order")
        close_overlay(ui.pile_panel)
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.menu_panel.visible,"Menu icon reveals secondary actions")
        await hover_edges(ui.restart_button,dimensions)
        await hover_edges(ui.relic_buttons["break_focus"],dimensions)
        close_overlay(ui.menu_panel)
        TacticalUIPlayer.click(self,ui.skills[1])
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.battle.enemy().statuses.has("seed") and ui.busy,"Pointer plays fixed skill and locks animation")
        var before := ui.battle.snapshot()
        TacticalUIPlayer.click(self,ui.end_button)
        check(ui.battle.snapshot() == before,"Animation blocks duplicate gameplay input")
        TacticalUIPlayer.finish(ui)
        await process_frame
        TacticalUIPlayer.settle(ui)
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        TacticalUIPlayer.click(self,ui.relic_buttons["break_focus"])
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.battle.relic == "break_focus" and ui.battle.turn == 1 and ui.battle.energy == 3,"Trait click starts fresh deterministic trial")
        check(not ui.menu_panel.visible,"Trait selection returns to clean battle view")
        TacticalUIPlayer.click(self,ui.menu_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        TacticalUIPlayer.click(self,ui.restart_button)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(ui.battle.relic == "break_focus","Restart keeps selected trait")
    await verify_animation_input()
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
        TacticalUIPlayer.settle(ui)
        TacticalUIPlayer.finish(ui)
        await process_frame
        TacticalUIPlayer.settle(ui)
    check(ui.battle.phase == TacticalBattle.WON and ui.result.visible,"Full pointer battle reaches victory modal")
    key(KEY_F1)
    await process_frame
    TacticalUIPlayer.settle(ui)
    check(not ui.help_panel.visible,"Help shortcut cannot open an invisible modal behind the result")
    for local: Vector2 in [Vector2(ui.result_restart.size.x/2,3),ui.result_restart.size/2,Vector2(ui.result_restart.size.x/2,ui.result_restart.size.y-3)]:
        var event := InputEventMouseMotion.new()
        event.position = root.get_final_transform()*(ui.result_restart.get_global_transform_with_canvas()*local)
        root.push_input(event)
        await process_frame
        TacticalUIPlayer.settle(ui)
        check(root.gui_get_hovered_control() == ui.result_restart,"Victory modal has top-to-bottom hit priority")
    TacticalUIPlayer.click(self,ui.result_restart)
    await process_frame
    TacticalUIPlayer.settle(ui)
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
        TacticalUIPlayer.settle(ui)
        TacticalUIPlayer.finish(ui)
        await process_frame
        TacticalUIPlayer.settle(ui)
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
    TacticalUIPlayer.settle(ui)
    check(ui.battle.snapshot() == saved and old_run.battle.snapshot() == old_snapshot,"Scene re-entry preserves separate tactical and expedition state")
    ui._refresh()
    current_scene = ui
    TacticalUIPlayer.click(self,ui.menu_button)
    await process_frame
    TacticalUIPlayer.settle(ui)
    TacticalUIPlayer.click(self,ui.lab_button)
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    check(current_scene is ArtLab,"F2 button enters art lab")
    TacticalUIPlayer.click(self,find_button(current_scene,"전투 UI로 돌아가기 · F2"))
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    ui = current_scene as TacticalUI
    check(ui != null and ui.battle.snapshot() == saved,"Art lab returns to tactical mode with state intact")
    TacticalUIPlayer.click(self,ui.menu_button)
    await process_frame
    TacticalUIPlayer.settle(ui)
    TacticalUIPlayer.click(self,ui.old_button)
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    check(current_scene is BattleUI,"F3 button enters original expedition")
    check(old_run.battle.snapshot() == old_snapshot,"Opening original mode preserves its existing expedition")
    var old_ui := current_scene as BattleUI
    old_ui._open_lab()
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    TacticalUIPlayer.click(self,find_button(current_scene,"전투 UI로 돌아가기 · F2"))
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    check(current_scene is BattleUI,"Art lab also returns to original mode when opened there")
    TacticalUIPlayer.click(self,find_button(current_scene,"전술 시험 · F3"))
    await scene_changed
    await process_frame
    TacticalUIPlayer.settle(ui)
    ui = current_scene as TacticalUI
    check(ui != null and ui.battle.snapshot() == saved,"F3 comparison round trip preserves tactical progress")
    ui.restart()
    ui.free()
    print("TACTICAL_UI: ",checks," checks, ",failures," failures; ",actions," pointer actions to victory at 4 viewport sizes")
    quit(0 if failures == 0 else 1)
