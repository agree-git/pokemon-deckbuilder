extends SceneTree
## Integration tests for actual imported assets, catalog routing, and UI actions.
## Run with Godot 4.7.2: --headless --path . --script res://tests/test_visuals.gd

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)
        push_error(message)

func _run() -> void:
    var catalog := VisualCatalog.new()
    check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920, "Viewport must be 1920 pixels wide")
    check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080, "Viewport must be 1080 pixels high")
    check(catalog.pokemon.size() == 151, "Expected exactly Kanto 151")
    check(catalog.moves.size() == 165, "Expected 165 first-generation moves")
    check(catalog.biomes.size() == 18, "Expected 18 biome definitions")
    check(catalog.types.size() == 18, "Expected 18 modern types")
    for id in range(1, 152):
        var species := catalog.species(id)
        check(not species.is_empty(), "Missing species %d" % id)
        for back: bool in [false, true]:
            var texture: Texture2D = load(VisualCatalog.sprite_path(id, back))
            check(texture != null and texture.get_size() == Vector2(96, 96), "Bad sprite %d/%s" % [id, back])
            if texture:
                var image := texture.get_image()
                check(image.detect_alpha() != Image.ALPHA_NONE, "Sprite must retain transparency: %d" % id)
    var encountered: Dictionary = {}
    var cells: Dictionary = {}
    for biome: Dictionary in catalog.biomes:
        var texture := VisualCatalog.biome_texture(biome)
        check(texture.atlas != null, "Missing background: " + biome["id"])
        check(texture.region.size.x > 0 and texture.region.end.y <= texture.atlas.get_height() + 0.1, "Invalid atlas region")
        var cell_key := "%s:%s" % [biome["background"], biome["cell"]]
        check(not cells.has(cell_key), "Background cell reused: " + cell_key)
        cells[cell_key] = true
        check(not biome["encounters"].is_empty(), "Empty biome " + biome["id"])
        var seen: Dictionary = {}
        for entry: Dictionary in biome["encounters"]:
            var id := int(entry["pokemon_id"])
            var species := catalog.species(id)
            check(not species.is_empty(), "Non-Kanto encounter")
            check(not seen.has(id), "Duplicate encounter in " + biome["id"])
            check(int(entry["weight"]) > 0, "Encounter weight must be positive")
            check(id not in [144, 145, 146, 150, 151], "Legendary/mythical must be event-only")
            if biome["encounter_mode"] == "type":
                check(biome["type"] in species["types"], "Type mismatch: %s/%s" % [biome["id"], species["name"]])
            else:
                check(biome["id"] == "dark" and "관동 원종에는 악타입이 없습니다" in biome["encounter_note"], "Themed exception must be explicit")
            encountered[id] = true
            seen[id] = true
        for entry: Dictionary in biome["landmarks"]:
            encountered[int(entry["pokemon_id"])] = true
    check(encountered.size() == 151, "All Kanto species need biome/event placement")
    for move: Dictionary in catalog.moves:
        check(VisualCatalog.EFFECT_NAMES.has(move["vfx"]["primary"]), "Unknown primary VFX")
        check(VisualCatalog.TYPE_COLORS.has(move["type"]), "Missing type palette")
        check(move["vfx"]["target"] in ["self", "opponent", "field"], "Invalid VFX target")
        check(move["vfx"]["secondary"].is_empty() or VisualCatalog.EFFECT_NAMES.has(move["vfx"]["secondary"]), "Unknown secondary VFX")
    check(catalog.move_by_id(105)["vfx"]["target"] == "self", "Recover must heal its user")
    check(catalog.move_by_id(73)["vfx"]["primary"] == "seed", "Leech Seed needs seed visuals")
    check(catalog.move_by_id(71)["vfx"]["primary"] == "drain", "Absorb needs reverse-flow visuals")
    check(catalog.move_by_id(45)["vfx"]["primary"] == "stat_down", "Growl needs debuff visuals")
    check(catalog.move_by_id(156)["vfx"]["secondary"] == "sleep", "Rest needs a self sleep overlay")
    check(catalog.move_by_id(50)["vfx"]["primary"] == "seal", "Disable must not display confusion")
    check(catalog.move_by_id(150)["vfx"]["primary"] == "splash", "Splash must not apply a status")
    check(catalog.move_by_id(160)["vfx"]["primary"] == "transform", "Conversion needs transformation visuals")
    var scene: PackedScene = load("res://scenes/art_lab.tscn")
    var lab: ArtLab = scene.instantiate()
    root.add_child(lab)
    await process_frame
    check(lab.stage.canvas.scale == Vector2.ONE, "Stage must render at native UI resolution")
    check(not lab.stage.get_child(0) is SubViewport, "Do not downsample the complete preview")
    check(lab.stage.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Preview must use nearest filtering")
    check(lab.source_select.item_count == 151 and lab.target_select.item_count == 151, "All sprites must be selectable")
    for i in catalog.biomes.size():
        lab.biome_buttons[i].pressed.emit()
        check(lab.biome_index == i, "Biome button routing failed")
        check(lab.encounter_buttons.size() == catalog.biomes[i]["encounters"].size(), "Encounter list did not refresh")
        lab.encounter_buttons[-1].pressed.emit()
        var expected := int(catalog.biomes[i]["encounters"][-1]["pokemon_id"])
        check(lab.target_id == expected and lab.target_select.get_selected_id() == expected, "Encounter selection did not update sprite")
    lab.move_search.text = "정말없는기술"
    lab.move_search.text_changed.emit(lab.move_search.text)
    check(lab.filtered_moves.is_empty() and lab.play_button.disabled, "Empty search must not replay stale moves")
    lab.move_search.text = "불꽃세례"
    lab.move_search.text_changed.emit(lab.move_search.text)
    check(lab.filtered_moves.size() == 1 and int(lab.selected_move["id"]) == 52, "Korean move search failed")
    lab.move_search.text = ""
    lab.move_search.text_changed.emit("")
    check(lab.filtered_moves.size() == 165, "Cleared search must restore all moves")
    lab.type_filter.select(10) # Fire in official type ID order.
    lab.type_filter.item_selected.emit(10)
    check(not lab.filtered_moves.is_empty(), "Type filter unexpectedly empty")
    for move: Dictionary in lab.filtered_moves:
        check(move["type"] == "fire", "Type filter leaked another type")
    lab.type_filter.select(0)
    lab.type_filter.item_selected.emit(0)
    var counts := {"impact": 0, "finished": 0}
    var effect := lab.stage.canvas.effect
    effect.set_process(false)
    effect.impact.connect(func(_move: Dictionary): counts["impact"] += 1)
    effect.finished.connect(func(_move: Dictionary): counts["finished"] += 1)
    for move: Dictionary in catalog.moves:
        effect.play(move, BattleCanvas.SOURCE, BattleCanvas.TARGET)
        effect._process(MoveEffect.DURATION * 0.6)
        check(effect.playing, "Effect ended before impact")
        # Let the actual renderer exercise every profile's draw path.
        await process_frame
        effect._process(MoveEffect.DURATION * 0.5)
        check(not effect.playing, "Effect failed to finish")
    check(counts["impact"] == 165 and counts["finished"] == 165, "Effects must emit impact/finish exactly once")
    effect.play(catalog.move_by_id(52), BattleCanvas.SOURCE, BattleCanvas.TARGET)
    effect.stop()
    effect._process(10)
    check(counts["impact"] == 165 and counts["finished"] == 165, "Cancelled effect emitted stale signals")
    effect.play(catalog.move_by_id(156), BattleCanvas.SOURCE, BattleCanvas.TARGET)
    effect._process(MoveEffect.DURATION * 0.6)
    check(lab.stage.canvas.status == "sleep" and lab.stage.canvas.status_on_self, "Rest overlay applied to opponent")
    lab._clear()
    check(lab.stage.canvas.status.is_empty() and not effect.playing, "Reset must remove effect and persistent status")
    lab.queue_free()
    await process_frame
    var session_battle: BattleState = root.get_node("BattleSession").get("battle")
    session_battle.restart(2026)
    var battle: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    check(battle.cards.size() == 5 and battle.party_buttons.size() == 2, "Battle needs a real opening hand and two allies")
    check(battle.stage.canvas.scale == Vector2.ONE and battle.stage.canvas.sprite_zoom == 4, "Native screen and integer sprite scaling")
    var requests := {"card": 0, "switch": 0, "turn": 0}
    battle.card_requested.connect(func(_definition: Dictionary): requests["card"] += 1)
    battle.switch_requested.connect(func(_id: int): requests["switch"] += 1)
    battle.end_turn_requested.connect(func(): requests["turn"] += 1)
    var chosen: BattleCard
    for card: BattleCard in battle.cards:
        if card.available:
            chosen = card
            break
    check(chosen != null, "Opening hand needs a usable card")
    var uid := int(chosen.definition["uid"])
    var cost := int(chosen.definition["cost"])
    var move_id := int(chosen.definition["move_id"])
    chosen.pressed.emit()
    check(requests["card"] == 1 and battle.animating and battle.stage.canvas.effect.playing, "Card starts a locked visual action")
    check(battle.battle.energy == 3 - cost and battle.battle._find_hand(uid) == null, "Card consumes actual energy and leaves hand")
    check(int(battle.stage.canvas.effect.move["id"]) == move_id, "Card selects the correct effect")
    var snapshot := battle.battle.snapshot()
    battle.card_requested.emit({"uid": uid})
    battle.end_turn_requested.emit()
    check(battle.battle.snapshot() == snapshot, "Input during animation must not duplicate actions")
    await create_timer(1.7).timeout
    check(not battle.animating, "Actual effect completion must unlock controls")
    battle.party_buttons[1].pressed.emit()
    check(requests["switch"] == 1 and battle.active_id == 1, "Ally slot routes real free switch")
    check(battle.battle.energy == 3 - cost and battle.ally_hp.text == "48 / 48", "Switch preserves energy and refreshes HP")
    for card: BattleCard in battle.cards:
        check(card.available == battle.battle.card_reason(int(card.definition["uid"])).is_empty(), "Card availability must match rules")
    battle.end_turn.pressed.emit()
    check(battle.battle.turn == 2 and battle.battle.energy == 3 and battle.battle.hand.size() == 5, "End turn resolves enemy and next draw")
    check(battle.animating and battle.stage.canvas.effect_from_enemy, "Enemy action animates in the opposite direction")
    battle.stage.canvas.effect._process(MoveEffect.DURATION)
    check(not battle.animating and not battle.end_turn.disabled, "Enemy animation unlocks player turn")
    check(battle._energy_label.text == str(battle.battle.energy) and battle._draw_count.text == str(battle.battle.draw_pile.size()), "HUD shows actual resource piles")
    for card: BattleCard in battle.cards:
        for ally_button: Button in battle.party_buttons:
            check(not ally_button.get_global_rect().intersects(card.get_global_rect()), "Hand obscures switch controls")
    battle.restart_battle()
    battle.battle.active().hp = 1
    battle.battle.active().statuses["burn"] = {"turns": 1, "source_uid": -1}
    battle.end_turn.pressed.emit()
    check(battle.battle.phase == BattleState.REPLACE and not battle.animating, "Player-end KO must ask for replacement before enemy")
    battle.party_buttons[1].pressed.emit()
    check(battle.active_id == 1 and battle.animating and battle.stage.canvas.effect.playing, "Forced switch must not cancel resumed enemy animation")
    battle.stage.canvas.effect._process(MoveEffect.DURATION)
    check(not battle.animating and battle.battle.phase == BattleState.PLAYER, "Forced switch must not leave input locked")
    battle.restart_battle()
    for i in range(180):
        check(battle.cards.size() == battle.battle.hand.size(), "Hand view/state count mismatch")
        if battle.battle.phase in [BattleState.WON, BattleState.LOST]:
            break
        if battle.battle.phase == BattleState.REPLACE:
            for button: Button in battle.party_buttons:
                if not button.disabled:
                    button.pressed.emit()
                    break
        else:
            var played := false
            for card: BattleCard in battle.cards:
                if card.available:
                    card.pressed.emit()
                    played = true
                    break
            if not played:
                var switched := false
                if not battle.battle.switched:
                    for button: Button in battle.party_buttons:
                        if not button.disabled:
                            button.pressed.emit()
                            switched = true
                            break
                if not switched:
                    battle.end_turn.pressed.emit()
        if battle.animating:
            battle.stage.canvas.effect._process(MoveEffect.DURATION)
    check(battle.battle.phase == BattleState.WON and battle._result.visible, "A complete UI-driven battle must reach visible victory")
    check(battle._result_title.text == "전투 승리" and battle._enemy_hp_bar.value == 0, "Victory HUD must match model")
    battle.restart_battle()
    check(not battle._result.visible and battle.battle.snapshot() == BattleState.new(2026).snapshot(), "Restart resets UI and model")
    battle.battle.party[0].hp = 1
    battle.battle.party[1].hp = 1
    battle.end_turn.pressed.emit()
    battle.stage.canvas.effect._process(MoveEffect.DURATION)
    check(battle.battle.phase == BattleState.REPLACE and not battle.party_buttons[1].disabled, "Enemy KO exposes live replacement button")
    battle.party_buttons[1].pressed.emit()
    battle.end_turn.pressed.emit()
    battle.stage.canvas.effect._process(MoveEffect.DURATION)
    battle.end_turn.pressed.emit()
    battle.stage.canvas.effect._process(MoveEffect.DURATION)
    check(battle.battle.phase == BattleState.LOST and battle._result.visible and battle._result_title.text == "전투 패배", "Defeat must show a restartable result")
    battle.restart_battle()
    battle.party_buttons[1].pressed.emit()
    snapshot = battle.battle.snapshot()
    battle.queue_free()
    await process_frame
    battle = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    check(battle.battle.snapshot() == snapshot and battle.active_id == 1, "Reopening the battle after the art lab must preserve state")
    battle.restart_battle()
    battle.queue_free()
    await process_frame
    if failures.is_empty():
        print("VISUAL_TESTS_OK: %d checks; 302 sprites, 18 biomes, 165 move lifecycles, native 1080p UI integration" % checks)
        quit(0)
    else:
        print("VISUAL_TESTS_FAILED: %d failures / %d checks" % [failures.size(), checks])
        quit(1)
