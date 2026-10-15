extends SceneTree
## OS pointer companion; every action is injected by XTest, not a Button signal.
var failures := 0
var clicks := 0
var ui: TacticalUI
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control,local := Vector2(-1,-1)) -> void:
    if local.x < 0: local = control.visible_point() if control is TrainerActionCard else control.size/2
    var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
    clicks += 1
    await create_timer(0.22).timeout
    TacticalUIPlayer.finish(ui)
    await process_frame
    await create_timer(0.34).timeout
func analysis_button() -> Button:
    for card: BattleCardInstance in ui.battle.hand:
        if card.key == "analysis": return ui.trainer_buttons[card.uid]
    return null
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    await create_timer(0.3).timeout
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,900)]:
        root.size = dimensions
        root.position = Vector2i(20,20)
        await create_timer(0.2).timeout
        for position_index in 3:
            for kind: String in ["history","end","switch","skill","card","trait","restart","help","draw"]:
                ui.restart("seed_relay")
                await create_timer(0.48).timeout
                if kind in ["trait","restart"]:
                    await click(ui.menu_button)
                var button: Button
                match kind:
                    "help": button = ui.help_button
                    "draw": button = ui.draw_button
                    "history": button = ui.history_button
                    "end": button = ui.end_button
                    "switch": button = ui.party_buttons[0]
                    "skill": button = ui.skills[1]
                    "card": button = analysis_button()
                    "trait": button = ui.relic_buttons["break_focus"]
                    "restart":
                        ui.battle.use_skill("growth")
                        ui._refresh()
                        button = ui.restart_button
                var local: Vector2 = button.visible_point(position_index*0.5) if button is TrainerActionCard else [Vector2(button.size.x/2,3),button.size/2,Vector2(button.size.x/2,button.size.y-3)][position_index]
                await click(button,local)
                var valid := false
                match kind:
                    "help": valid = ui.help_panel.visible
                    "draw": valid = ui.pile_panel.visible
                    "history": valid = ui.log_panel.visible
                    "end": valid = ui.battle.turn == 2
                    "switch": valid = ui.battle.active().uid == 4
                    "skill": valid = ui.battle.enemy().statuses.has("seed")
                    "card": valid = ui.battle.opening()["analyzed"]
                    "trait": valid = ui.battle.relic == "break_focus"
                    "restart": valid = ui.battle.active().strength == 0
                check(valid,"Real OS click missed %s in %s at local %s" % [kind,dimensions,local])
    ui.restart("seed_relay")
    while ui.battle.hand.size() < 10: ui.battle.hand.append(ui.battle._new_card("guard"))
    ui._refresh()
    await create_timer(0.6).timeout
    ui.hand_scroll.scroll_horizontal = int(ui.hand_row.size.x)
    await process_frame
    var last: int = ui.battle.hand.back().uid
    await click(ui.trainer_buttons[last])
    check(not ui.trainer_buttons.has(last),"OS input hits scrolled extra hand card")
    root.size = Vector2i(1280,720)
    await create_timer(0.2).timeout
    ui.restart("seed_relay")
    await create_timer(0.48).timeout
    for guard in 100:
        if ui.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        await click(TacticalUIPlayer.button(ui,TacticalPolicy.action(ui.battle)))
    check(ui.battle.phase == TacticalBattle.WON and ui.result.visible,"Entire battle wins through real OS pointer")
    await click(ui.result_restart)
    check(ui.battle.phase == TacticalBattle.PLAYER and not ui.result.visible,"OS modal restart")
    ui.free()
    print("NATIVE_TACTICAL: ",failures," failures, ",clicks," real OS clicks; 3 window sizes and full encounter")
    quit(0 if failures == 0 else 1)
