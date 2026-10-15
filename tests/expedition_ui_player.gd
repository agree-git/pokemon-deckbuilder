extends RefCounted
## Runs the same legal policy through rendered controls and viewport mouse input.
const Policy = preload("res://tests/expedition_policy.gd")
static func button_for(ui: BattleUI) -> Button:
    var run := ui.run
    var button: Button
    if run.phase == RunState.MAP:
        button = ui.expedition.action_buttons[Policy.choose_route(run)]
    elif run.phase == RunState.REST:
        var action := Policy.rest_action(run)
        if action["kind"] == "heal":
            button = ui.expedition.heal_button
        elif action["kind"] == "upgrade":
            button = ui.expedition.upgrade_button
        else:
            for i in run.party.size():
                if run.party[i].uid == int(action["uid"]):
                    button = ui.expedition.evolve_buttons[i]
    elif run.phase in [RunState.CLEARED,RunState.FAILED]:
        return null
    elif ui.battle.phase in [BattleState.WON,BattleState.CAPTURED]:
        if run.pending_capture != null:
            var index := run.party.size()
            for i in run.party.size():
                if run.party[i].uid == 1:
                    index = i
            button = ui._capture_choices.get_child(index)
        elif run.reward_pending:
            var index := Policy.resolve_reward(run)
            button = ui._reward_skip if index == -1 else ui._reward_cards.get_child(index)
        else:
            button = ui._next_button
    else:
        var action := Policy.decision(run)
        match action["kind"]:
            "card":
                for card: BattleCard in ui.cards:
                    if int(card.definition["uid"]) == int(action["uid"]):
                        button = card
            "switch":
                for i in ui.battle.party.size():
                    if ui.battle.party[i].uid == int(action["uid"]):
                        button = ui.party_buttons[i]
            "capture": button = ui.capture_button
            "end": button = ui.end_turn
    return button

static func step(ui: BattleUI, tree: SceneTree) -> String:
    var run := ui.run
    if run.phase in [RunState.CLEARED,RunState.FAILED]:
        return "finished"
    var button := button_for(ui)
    if button == null or button.disabled or not button.is_visible_in_tree():
        return "Unavailable control in %s step %d" % [run.phase,run.step]
    click(tree,button)
    await tree.process_frame
    if ui.animating:
        ui.stage.canvas.effect._process(MoveEffect.DURATION)
    await tree.process_frame
    return ""

static func click(tree: SceneTree, button: Control) -> void:
    var at := tree.root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size/2))
    var motion := InputEventMouseMotion.new()
    motion.position = at
    tree.root.push_input(motion)
    for down: bool in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        tree.root.push_input(event)
