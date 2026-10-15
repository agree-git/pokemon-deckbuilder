class_name TacticalUIPlayer
extends RefCounted
static func button(ui: TacticalUI,step: Array) -> Button:
    match step[0]:
        "skill": return ui.skills[TacticalContent.SKILLS[ui.battle.active().species_id].find(step[1])]
        "card": return ui.trainer_buttons[step[1]]
        "switch":
            for i in ui.battle.party.size():
                if ui.battle.party[i].uid == step[1]: return ui.party_buttons[i]
    return ui.end_button
static func click(tree: SceneTree,control: Control,local := Vector2(-1,-1)) -> void:
    if local.x < 0: local = control.visible_point() if control is TrainerActionCard else control.size/2
    var at := tree.root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    var motion := InputEventMouseMotion.new()
    motion.position = at
    tree.root.push_input(motion)
    for down: bool in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        tree.root.push_input(event)
static func finish(ui: TacticalUI) -> void:
    if ui.busy: ui.stage.canvas.effect._process(MoveEffect.DURATION)

static func settle(ui: Variant) -> void:
    if not is_instance_valid(ui): return
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
