extends "res://tests/test_enemy_tactics_ui.gd"
func click(control: Control) -> void:
    var ui: Node = control
    while not ui is TacticalUI: ui = ui.get_parent()
    TacticalUIPlayer.finish(ui)
    UiMotion.finish_tree(root)
    await process_frame
    if control is TrainerActionCard:
        ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        UiMotion.finish_tree(root)
        ui.hand_scroll.ensure_control_visible(control)
        await process_frame
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
    var before: Dictionary = ui.battle.snapshot()
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        # X11 delivery and rendering can span several frames on a software GPU.
        for i in 50:
            await create_timer(0.02).timeout
            if ui.battle.snapshot() != before: break
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
    check(ui.battle.snapshot() != before,"Boss test click reaches an actual battle action")
    clicks += 1
    TacticalUIPlayer.finish(ui)
    UiMotion.finish_tree(root)
    await process_frame
    UiMotion.finish_tree(root)
func boss_ui(key: String, slot := 0) -> TacticalUI:
    var catalog := VisualCatalog.new()
    var roster: Array = []
    var role := key.get_slice(":",0)
    var id := key.get_slice(":",1)
    if role == "gym":
        for entry: Dictionary in catalog.gyms:
            if entry["leader_id"] == id: roster = entry["party"]
    else:
        var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
        for entry: Dictionary in league["elite" if role == "elite" else "champions"]:
            if entry["id"] == id: roster = entry["party"]
    var members: Array[BattlePokemon] = []
    for species in [9,65,143]:
        var p := BattlePokemon.new(TacticalContent.member_definition(species,catalog),species)
        p.level = 50
        members.append(p)
    var enemies: Array = []
    for i in roster.size():
        var species := int(roster[i])
        var d := TacticalContent.member_definition(species,catalog)
        d["level"] = 50
        d["types"] = catalog.species(species)["types"]
        d.merge(EnemyTactics.build(species,50,d["types"],role,i,roster.size()))
        d.merge(BossTactics.build(key,i,species,50,d["types"]),true)
        enemies.append(d)
    var cards: Array[BattleCardInstance] = [BattleCardInstance.new(101,"move_33",9),BattleCardInstance.new(102,"move_55",9),BattleCardInstance.new(103,"antidote_card",0)]
    var b := TacticalBattle.new()
    b.start_with(members,cards,enemies,42,"field_kit")
    b.full_type_chart = true
    b.enemy_index = slot # Roster fixture; actions below use the real input path.
    b.hand.assign(cards)
    b.draw_pile.clear()
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    return ui
func click_timed(control: Control) -> void:
    UiMotion.finish_tree(control)
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size/2))
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.12).timeout
    else:
        TacticalUIPlayer.click(self,control)
        await process_frame
    clicks += 1
func wait_kind(ui: TacticalUI, kind: String, count := 1) -> void:
    for i in 400:
        if ui.playback_kinds.count(kind) >= count: return
        await create_timer(0.01).timeout
    check(false,"Timed playback reaches "+kind)
func finish(ui: TacticalUI) -> void:
    for i in 500:
        if not ui.busy: return
        await create_timer(0.01).timeout
    check(false,"Boss action playback completes")
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var ui := boss_ui("gym:jasmine")
    await process_frame
    UiMotion.finish_tree(ui)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.get_node("Intent/Tactic").text == "철벽형" and ui.get_node("Intent/Title").text == "방벽","Jasmine shows a concrete defensive command")
    check(ui.get_node("Intent").tooltip_text.contains("규리 · 강철 성벽") and ui.get_node("Intent").tooltip_text.contains("방어 +1단계"),"Forecast explains the trainer plan and exact stage gain")
    check(ui.enemy_slots[1].tooltip_text.contains("특방형"),"The six-member sidebar exposes the next Pokemon's distinct role")
    var physical: int = ui.battle.card_view(ui.battle._hand(101))["preview_damage"]
    var special: int = ui.battle.card_view(ui.battle._hand(102))["preview_damage"]
    var shield: int = ui.battle.intent()["value"]
    await picture("boss-jasmine-forecast")
    await click(ui.end_button)
    check(ui.battle.enemy().stat_stages["defense"] == 1 and ui.shield_values[1].text == "보호막 %d" % shield,"Fortification displays both the real stage and shield")
    check(ui.battle.card_view(ui.battle._hand(101))["preview_damage"] < physical and ui.battle.card_view(ui.battle._hand(102))["preview_damage"] == special,"Physical and special card forecasts expose the way around a physical wall")
    var next := ui.battle.intent()
    await click(ui.party_buttons[1])
    check(ui.battle.intent()["kind"] == next["kind"] and ui.battle.intent()["move_id"] == next["move_id"],"Defender switching never changes the hidden identity of the next attack")
    ui.free()
    ui = boss_ui("gym:brawly",1)
    await process_frame
    UiMotion.finish_tree(ui)
    await click(ui.end_button)
    var action := ui.battle.intent()
    check(action["kind"] == "barrage" and ui.intent_label.text == "%d×2" % action["per_hit"],"Barrage UI exposes per-hit damage and count")
    check(ui.get_node("Intent").tooltip_text.contains("총 피해 %d" % action["value"]),"Tooltip also exposes total damage for shield planning")
    await picture("boss-barrage-forecast")
    var hp := ui.battle.active().hp
    await click_timed(ui.end_button)
    await wait_kind(ui,"enemy_action")
    var committed := ui.battle.snapshot()
    check(ui.busy and ui._view_active().hp == hp,"Atomic rules finish while the first windup still shows the old HP")
    await wait_kind(ui,"enemy_hit")
    check(ui._view_active().hp == hp-int(action["per_hit"]),"First damage is visible before the second windup")
    await create_timer(0.06).timeout
    check(ui.stage.canvas.target_motion.x < 0,"Second hit has its own forward attack motion")
    await wait_kind(ui,"damage",2)
    check(ui._view_active().hp == ui.battle.active().hp,"Second damage frame reaches exactly the committed HP")
    await finish(ui)
    check(ui.battle.snapshot() == committed,"Timed replay never repeats damage or measurements")
    ui.free()
    ui = boss_ui("gym:koga")
    await process_frame
    UiMotion.finish_tree(ui)
    check(ui.intent_label.text == "2회" and ui.get_node("Intent/Title").text == "독","Poison command is legible before applying")
    await click(ui.party_buttons[1])
    await click(ui.end_button)
    check(ui.battle.active().uid == 65 and ui.battle.active().statuses["poison"]["turns"] == 2 and not ui.battle.party[0].statuses.has("poison"),"Only the chosen final defender receives the advertised status")
    await picture("boss-koga-poison")
    await click(ui.trainer_buttons[103])
    check(not ui.battle.active().statuses.has("poison"),"An existing treatment card provides real counterplay")
    ui.free()
    ui = boss_ui("gym:whitney")
    await process_frame
    UiMotion.finish_tree(ui)
    await click(ui.end_button)
    check(ui.battle.intent()["kind"] == "recover" and ui.intent_label.text == "+0","Full-health healing openly shows zero recovery")
    await click(ui.trainer_buttons[101])
    check(ui.battle.enemy().block > 0 and ui.intent_label.text == "+0","Blocked damage does not invent missing HP for recovery")
    await click(ui.trainer_buttons[102])
    var heal: int = ui.battle.intent()["value"]
    check(heal > 0 and ui.intent_label.text == "+%d" % heal,"Damaging the opponent updates its actual heal forecast")
    await picture("boss-whitney-recover")
    var enemy_hp := ui.battle.enemy().hp
    await click(ui.end_button)
    check(ui.battle.enemy().hp == enemy_hp+heal and ui.battle.statistics["counts"]["healing"] == 0,"Enemy recovery is staged and stays out of allied healing totals")
    ui.free()
    ui = boss_ui("gym:erika")
    await process_frame
    UiMotion.finish_tree(ui)
    await click(ui.end_button)
    await click(ui.trainer_buttons[101])
    enemy_hp = ui.battle.enemy().hp
    await click(ui.end_button)
    var seed_ok: bool = ui.battle.enemy().hp > enemy_hp and "heal" in ui.playback_kinds and ui.battle.statistics["counts"]["healing"] == 0
    if not seed_ok: print("SEED_DIAGNOSTIC hp_before=",enemy_hp," hp_after=",ui.battle.enemy().hp," ally_status=",ui.battle.active().statuses," phase=",ui.battle.phase," playback=",ui.playback_kinds)
    check(seed_ok,"Enemy seed drain has a visible healing step and correct owner")
    await picture("boss-erika-seed")
    ui.free()
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.phase = TacticalJourney.MAP
    j.step = 136
    j.badges = 8
    j.elite_wins = 4
    var map: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    map.journey = j
    root.add_child(map)
    await process_frame
    UiMotion.finish_tree(map)
    var node: Control = map.page.get_node("Encounter_136")
    var opponents := j.route.opponents(136)
    check(node.tooltip_text.contains(BossTactics.heading(opponents[0])) and node.tooltip_text.contains(EnemyTactics.pattern_text(opponents[5])),"Champion map reveals its named plan and entire roster's patterns")
    await picture("boss-champion-map")
    map.free()
    print("BOSS_TACTICS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
