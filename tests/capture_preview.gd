extends SceneTree
## Capture real rendered scenes. Requires a graphical display, not --headless.
## Optional output directory is the first argument after --.

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var args := OS.get_cmdline_user_args()
    var output := args[0] if not args.is_empty() else "res://.godot/previews"
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1920, 1080)
    var lab: ArtLab = load("res://scenes/art_lab.tscn").instantiate()
    root.add_child(lab)
    await create_timer(0.4).timeout
    for config: Array in [[3, 52, "forest"], [1, 53, "volcano"], [13, 109, "ghost"], [17, 105, "fairy"],
            [2,55,"johto_starters",158,160,0], [3,22,"hoenn_starters",252,254,0],
            [13,109,"ghost_gym",200,356,1], [14,82,"dragon_gym",371,373,1],
            [15,44,"dark_gym",197,359,1], [10,93,"deoxys",280,386,0]]:
        lab.roster_select.select(int(config[5]) if config.size() > 5 else 0)
        lab.select_biome(config[0])
        if config.size() > 3:
            lab.source_id = int(config[3])
            lab.target_id = int(config[4])
            lab.source_select.select(lab.source_id-1)
            lab.target_select.select(lab.target_id-1)
            lab._update_species()
        lab.select_move(config[1])
        lab.play_selected()
        # Fix the sampled animation phase for reproducible screenshot review.
        lab.stage.canvas.effect.set_process(false)
        lab.stage.canvas.effect._process(0.72)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        var path := output.path_join(config[2] + ".png")
        var error := image.save_png(path)
        if error != OK:
            push_error("Screenshot failed: " + path)
            quit(1)
            return
        print("CAPTURE_OK: " + path)
    lab.queue_free()
    await process_frame
    var battle: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(battle)
    await create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(output.path_join("battle_ui.png")) != OK:
        quit(1)
        return
    print("CAPTURE_OK: " + output.path_join("battle_ui.png"))
    var chosen: BattleCard
    for card: BattleCard in battle.cards:
        if card.available:
            chosen = card
            break
    chosen.mouse_entered.emit()
    await create_timer(0.2).timeout
    await RenderingServer.frame_post_draw
    if not _save(output, "battle_ui_hover"):
        return
    chosen.pressed.emit()
    await create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    if not _save(output, "battle_action"):
        return
    if battle.animating:
        battle.stage.canvas.effect._process(MoveEffect.DURATION)
    for i in range(180):
        if battle.battle.phase in [BattleState.WON, BattleState.LOST]:
            break
        if battle.battle.phase == BattleState.REPLACE:
            for button: Button in battle.party_buttons:
                if not button.disabled:
                    button.pressed.emit()
                    break
        else:
            var acted := false
            for card: BattleCard in battle.cards:
                if card.available:
                    card.pressed.emit()
                    acted = true
                    break
            if not acted:
                if not battle.battle.switched:
                    for button: Button in battle.party_buttons:
                        if not button.disabled:
                            button.pressed.emit()
                            acted = true
                            break
                if not acted:
                    battle.end_turn.pressed.emit()
        if battle.animating:
            battle.stage.canvas.effect._process(MoveEffect.DURATION)
        await process_frame
    if battle.battle.phase != BattleState.WON:
        push_error("UI-driven capture battle did not win")
        quit(1)
        return
    await RenderingServer.frame_post_draw
    if not _save(output, "battle_victory"):
        return
    battle._reward_cards.get_child(0).grab_focus()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "reward_focus"):
        return
    battle._reward_cards.get_child(0).pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "reward_claimed"):
        return
    battle.restart_battle()
    # Explicit fixture for inspecting the real forced-replacement UI branch.
    battle.battle.active().hp = 1
    battle.battle.active().statuses["burn"] = {"turns": 1, "source_uid": -1}
    battle.end_turn.pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "battle_replacement"):
        return
    battle.restart_battle()
    battle.battle.enemy.hp = 16
    battle._refresh()
    await RenderingServer.frame_post_draw
    if not _save(output, "capture_ready"):
        return
    battle.capture_button.pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "capture_joined"):
        return
    battle._next_button.pressed.emit()
    await process_frame
    battle.expedition.action_buttons[0].pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "capture_party"):
        return
    battle.battle.enemy.hp = 13
    battle._refresh()
    battle.capture_button.pressed.emit()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(output, "capture_replace"):
        return
    battle.restart_battle()
    battle.battle.active().experience = 0.3
    battle._refresh()
    await RenderingServer.frame_post_draw
    if not _save(output, "fractional_xp"):
        return
    quit(0)

func _save(output: String, name_text: String) -> bool:
    var image := root.get_texture().get_image()
    if image.get_size() != Vector2i(1920, 1080):
        push_error("Screenshot must be native 1920x1080")
        quit(1)
        return false
    var path := output.path_join(name_text + ".png")
    if image.save_png(path) != OK:
        quit(1)
        return false
    print("CAPTURE_OK: " + path)
    return true
