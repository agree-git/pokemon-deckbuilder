extends SceneTree
var native := false
var checks := 0
var failures := 0
var clicks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control) -> void:
    UiMotion.finish_tree(root)
    if native:
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size/2))
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.18).timeout
    else:
        TacticalUIPlayer.click(self,control)
        await process_frame
    clicks += 1
    UiMotion.finish_tree(root)
    await process_frame
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    UiMotion.finish_tree(root)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/pokemon-tactics/"+label+".png")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.12).timeout
func make_ui(id: int, slot: int) -> TacticalUI:
    var catalog := VisualCatalog.new()
    var members: Array[BattlePokemon] = []
    for species in [65,9]:
        var p := BattlePokemon.new(TacticalContent.member_definition(species,catalog),species)
        p.level = 50
        TacticalGrowth.initialize(p)
        members.append(p)
    var foe := TacticalContent.member_definition(id,catalog)
    foe["types"] = catalog.species(id)["types"]
    foe["level"] = 50
    foe.merge(EnemyTactics.build(id,50,foe["types"],"gym",slot,6))
    var b := TacticalBattle.new()
    b.start_with(members,[],[foe],42,"field_kit")
    b.full_type_chart = true
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    return ui
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    root.mode = Window.MODE_WINDOWED
    var ui := make_ui(68,5)
    await process_frame
    UiMotion.finish_tree(ui)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.get_node("Intent/Tactic").text == "강화형" and ui.intent_label.text == "+20%","Setup intent shows its role and actual percentage")
    check(ui.get_node("Intent").tooltip_text.contains("강화 → 공격 → 강공격 → 방어"),"Tooltip explains the complete visible pattern")
    check(ui.enemy_slots[0].tooltip_text.contains("강화형"),"Enemy party roster exposes its assigned role")
    var before := ui.battle.snapshot()
    ui._refresh()
    check(ui.battle.snapshot() == before,"Showing tactics never mutates the enemy")
    await picture("setup-intent")
    await click(ui.end_button)
    check(ui.battle.enemy().strength == 2 and ui.battle.intent()["kind"] == "attack","Enemy really spends its first turn setting up")
    check(ui.intent_label.text == str(ui.battle.intent()["value"]),"Next damage forecast includes the installed buff")
    var move := TacticalMoves.definition(TacticalMoves.key_for(ui.battle.intent()["move_id"]))
    check(ui.get_node("Intent").tooltip_text.contains(move["name"]),"Forecast names the actual selected attack")
    var energy := ui.battle.energy
    await click(ui.party_buttons[1])
    check(ui.battle.active().uid == 9 and ui.battle.energy == energy-1,"Switch button still spends only the manual cost")
    check(ui.get_node("Intent/Tactic").text == "강화형" and ui.intent_label.text == str(ui.battle.intent()["value"]),"Switch updates defense matchup while retaining the same pattern")
    await picture("buffed-attack")
    ui.free()
    ui = make_ui(213,0)
    await process_frame
    UiMotion.finish_tree(ui)
    check(ui.get_node("Intent/Tactic").text == "수비형" and ui.get_node("Intent/Title").text == "방어","Guardian publicly starts with defense")
    var shield: int = ui.battle.intent()["value"]
    await click(ui.end_button)
    check(ui.battle.enemy().block == shield and ui.shield_badges[1].visible and ui.shield_values[1].text == str(shield),"Guardian resolves exactly the advertised large shield")
    check(ui.shield_badges[1].tooltip_text.contains("다음 적 행동"),"Enemy shield tooltip uses the correct expiration timing")
    await picture("guardian-shield")
    ui.free()
    ui = make_ui(65,1)
    await process_frame
    UiMotion.finish_tree(ui)
    check(ui.get_node("Intent/Tactic").text == "속공형" and ui.battle.intent()["kind"] == "attack","Striker starts with attack")
    await click(ui.end_button)
    check(ui.battle.intent()["kind"] == "charge" and ui.get_node("Intent/Title").text == "강공격","Striker announces its second consecutive attack")
    await click(ui.end_button)
    check(ui.battle.intent()["kind"] == "block","Striker then offers a preparation turn")
    ui.free()
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.phase = TacticalJourney.MAP
    j.step = 14
    var map: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    map.journey = j
    root.add_child(map)
    await process_frame
    UiMotion.finish_tree(map)
    var gym: Control = map.page.get_node("Encounter_14")
    var opponents := j.route.opponents(14)
    check(gym.mouse_filter == Control.MOUSE_FILTER_PASS and gym.tooltip_text.contains(BossTactics.heading(opponents[0])) and gym.tooltip_text.contains(EnemyTactics.pattern_text(opponents[5])),"Map exposes the next gym's named plan and full party sequence")
    await picture("next-gym-tactics")
    map.free()
    print("ENEMY_TACTICS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
