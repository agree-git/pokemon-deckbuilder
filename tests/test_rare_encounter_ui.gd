extends "res://tests/test_special_evolution_ui.gd"
var profile_path := ""
func click(control: Control) -> void:
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    await super.click(control)
func key(symbol: String) -> void:
    if native and symbol == "Escape":
        # A hovered disabled-button tooltip is a Window and handles Esc first.
        # Move the actual pointer away before testing the modal shortcut.
        print("OS_MOVE 20 100")
        await create_timer(0.2).timeout
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.25).timeout
        await process_frame
    await super.key(symbol)
    await process_frame
    if native: await create_timer(0.18).timeout
    settle()
    await process_frame
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.18).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/pokemon-rare/"+label+".png")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.3).timeout
        await process_frame
        settle()
func adopt(j: TacticalJourney,_name: String) -> void:
    if is_instance_valid(ui): ui.free()
    var session := root.get_node("BattleSession")
    profile_path = "user://tests/rare_ui_%d/collection.json" % Time.get_ticks_usec()
    session.set("profile",PlayerProfile.new(profile_path))
    session.set("save_store",JourneySave.new(profile_path.get_base_dir()+"/journey.json"))
    session.adopt_journey(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    settle()
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.18).timeout
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-rare")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var chosen_seed := 0
    for seed_value in 400:
        if RareEncounter.target(seed_value) == 144:
            chosen_seed = seed_value
            break
    var j := RareTestSupport.fixture(chosen_seed)
    var last: int = j.rare_hunt["clues"].pop_back()
    j.rested_steps.erase(last)
    await adopt(j,"rare")
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.12).timeout
        var before := JourneySnapshot.encode(j)
        await click(ui.page.find_child("RareEncounter",true,false))
        check(ui.rare_open and ui.page.find_child("RareProgress",true,false).text.contains("2 / 3"),"Rare modal opens at the visible button in three window ratios")
        check(JourneySnapshot.encode(j) == before,"Viewing the target neither rerolls it nor grants clues")
        check(ui.page.find_child("ChallengeRare",true,false).disabled,"Missing clue visibly blocks challenge")
        await key("Escape")
        check(not ui.rare_open and j.phase == TacticalJourney.REST,"Escape closes only the hunt modal")
    root.size = Vector2i(1280,720)
    await process_frame
    await click(ui.page.find_child("RareEncounter",true,false))
    await picture("conditions")
    var before := JourneySnapshot.encode(j)
    await click(ui.actions[0])
    check(JourneySnapshot.encode(j) == before and j.phase == TacticalJourney.REST,"Modal blocks the camp departure button below it")
    if not ui.rare_open: await click(ui.page.find_child("RareEncounter",true,false))
    await click(ui.page.find_child("InvestigateRare",true,false))
    check(j.rare_hunt["clues"].size() == 3 and j.step in j.rested_steps,"Visible investigation consumes exactly one camp action")
    check(ui.rest_button.disabled and ui.page.find_child("Upgrade",true,false).disabled and ui.page.find_child("InvestigateRare",true,false).disabled,"Investigation locks rest, upgrade and another investigation")
    check(not ui.page.find_child("ChallengeRare",true,false).disabled,"Clues, badges and balls enable the explicit challenge")
    await click(ui.page.find_child("ChallengeRare",true,false))
    check(j.rare_hunt["battle_step"] == j.step+1 and j.balls == 3,"Reservation consumes the one challenge while keeping balls for capture")
    check(ui.page.find_child("ChallengeRare",true,false).disabled,"Repeated challenge visibly blocked")
    await picture("reserved")
    await key("Escape")
    check(not ui.rare_open,"Escape closes the reserved hunt before departure")
    await click(ui.actions[0])
    check(j.phase == TacticalJourney.MAP and ui.actions[0].get_children().any(func(child: Node): return child is Label and child.text.contains("프리져")),"Travel previews the actual rare target")
    await picture("map")
    await click(ui.actions[0])
    check(j.phase == TacticalJourney.BATTLE and j.battle.enemy().species_id == 144,"Actual travel enters the reserved battle")
    if not is_instance_valid(ui.battle_ui):
        ui.free()
        quit(1)
        return
    check(ui.battle_ui.capture_button.disabled and ui.battle_ui.capture_button.tooltip_text.contains("15%") and ui.battle_ui.capture_button.tooltip_text.contains("3개"),"Battle exposes the exceptional capture conditions")
    # Boundary fixture: verify presentation/capture, not an earned full boss victory.
    RareTestSupport.ready_capture(j)
    j.battle.energy = 1
    ui.refresh()
    await process_frame
    settle()
    check(ui.battle_ui.capture_button.disabled,"One energy cannot click through the rare gate")
    j.battle.energy = 2
    ui.refresh()
    await process_frame
    settle()
    check(not ui.battle_ui.capture_button.disabled,"Exact HP, balls and energy thresholds enable capture")
    await picture("capture-ready")
    await key("C")
    check(j.battle.phase == TacticalBattle.WON and j.balls == 0 and j.battle.energy == 0,"Capture shortcut applies the visible three-ball/two-energy cost")
    check(j.pending_captures.size() == 1 and 144 in PlayerProfile.new(profile_path).captured_ids,"Successful capture saves its unlock before the party decision")
    await click(ui.battle_ui.result_next)
    while j.phase == TacticalJourney.LEARN: await click(ui.actions.back())
    check(j.phase == TacticalJourney.CAPTURE,"Settlement shows the normal sprite party replacement choices")
    await picture("party-choice")
    await click(ui.actions.back())
    check(j.phase == TacticalJourney.REWARD and j.party.size() == 3 and 144 in PlayerProfile.new(profile_path).unlocked_starters(VisualCatalog.new()),"Releasing the capture keeps the unlocked starter")
    await click(ui.actions.back())
    await click(ui.actions[0])
    await click(ui.page.find_child("RareEncounter",true,false))
    check(ui.page.find_child("RareProgress",true,false).text.contains("포획 성공") and ui.page.find_child("ChallengeRare",true,false).disabled,"Following camps show a completed hunt and no extra challenge")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Full UI flow retains a valid campaign save")
    check(root.get_node("BattleSession").get("save_notice").is_empty(),"Automatic checkpoints complete without errors")
    await picture("completed")
    for target_id: int in [151,150]:
        var chosen := 0
        for seed_value in 400:
            if RareEncounter.target(seed_value) == target_id:
                chosen = seed_value
                break
        var next := RareTestSupport.fixture(chosen)
        var rule := RareEncounter.rule(target_id)
        await adopt(next,"tier")
        await click(ui.page.find_child("RareEncounter",true,false))
        check(ui.page.find_child("RareTarget",true,false).text.contains(rule["name"]),"Mythical and superlegendary names use their own tier")
        check(ui.page.find_child("RareProgress",true,false).text.contains("%d / %d" % [rule["required"],rule["required"]]),"The modal shows the tier's saved clue and badge gates")
        var description: String = ui.page.find_child("RareConditions",true,false).text
        check(description.contains("HP %d%%" % rule["hp_percent"]) and description.contains("몬스터볼 %d개 + 에너지 %d" % [rule["balls"],rule["energy"]]),"Modal costs and HP thresholds agree with the rules")
        await picture("tier-%d" % target_id)
        await key("Escape")
        next.balls = int(rule["balls"])-1
        ui.refresh()
        await process_frame
        await click(ui.page.find_child("RareEncounter",true,false))
        check(ui.page.find_child("ChallengeRare",true,false).disabled,"One fewer ball disables even a fully investigated challenge")
        await key("Escape")
        next.balls += 1
        ui.refresh()
        await process_frame
        await click(ui.page.find_child("RareEncounter",true,false))
        await click(ui.page.find_child("ChallengeRare",true,false))
        await key("Escape")
        await click(ui.actions[0])
        await click(ui.actions[0])
        check(next.phase == TacticalJourney.BATTLE and next.battle.enemy().species_id == target_id,"The selected rarity enters its own real opponent")
        if not is_instance_valid(ui.battle_ui):
            ui.free()
            quit(1)
            return
        check(ui.battle_ui.capture_button.tooltip_text.contains(rule["name"]) and ui.battle_ui.capture_button.tooltip_text.contains("몬스터볼 %d개" % rule["balls"]),"Combat preserves the tier's name and cost")
        check(ui.battle_ui.capture_button.get_node("Title").text.contains("%d/%d" % [rule["balls"],rule["balls"]]),"Capture button exposes available/required balls directly")
        RareTestSupport.ready_capture(next)
        ui.refresh()
        await process_frame
        settle()
        check(not ui.battle_ui.capture_button.disabled,"Each tier's exact capture boundaries work through the UI")
        await picture("tier-battle-%d" % target_id)
    ui.free()
    print("RARE_UI: ",checks," checks, ",failures," failures; ",clicks," pointer actions; ",keys," keys")
    quit(0 if failures == 0 else 1)
