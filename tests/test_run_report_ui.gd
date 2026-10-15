extends "res://tests/test_merchant_ui.gd"
func labels(node: Node) -> String:
    var text: Array[String] = []
    for label: Label in node.find_children("*","Label",true,false): text.append(label.text)
    return "\n".join(text)
func report() -> RunReport:
    return ui.page.get_node("RunReport")
func advance(j: TacticalJourney) -> void:
    match j.phase:
        TacticalJourney.BATTLE:
            if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: j.settle()
            else: CampaignPolicy.apply(j,CampaignPolicy.action(j))
        TacticalJourney.LEARN: j.resolve_learning(CampaignPolicy.learn(j))
        TacticalJourney.REWARD: j.choose_reward(CampaignPolicy.reward(j))
        TacticalJourney.MAP: j.enter_next()
        TacticalJourney.REST:
            CampaignPolicy.camp(j)
            j.leave_camp()
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    for limit in 2000:
        if j.phase == TacticalJourney.REST and j.camp()["kind"] == "merchant": break
        advance(j)
    check(j.phase == TacticalJourney.REST and not j.statistics["battles"].is_empty(),"Reach a real measured merchant through public actions")
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/report_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/report_ui_journey.json"))
    session.adopt_journey(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    await click(ui.camp_tabs["shop"])
    var cheapest := 0
    for i in 3:
        if j.shop_cards()[i]["price"] < j.shop_cards()[cheapest]["price"]: cheapest = i
    var name := str(j.reward_view(j.shop_cards()[cheapest])["name"])
    await click(ui.page.find_child("BuyCard_%d" % cheapest,true,false))
    check(j.statistics["counts"]["cards_bought"] == 1,"Real purchase is counted once before opening reports")
    var saved: TacticalJourney = session.get("save_store").load_journey()
    check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"UI transaction autosaves the new measurements")
    var before := JourneySnapshot.encode(j)
    await click(ui.page.get_node("OpenReport"))
    check(ui.report_open and labels(report()).contains("총 지출"),"Report opens from the existing camp page with economy summary")
    check(report().find_children("Battle_*","Control",true,false).size() == j.statistics["battles"].size(),"Every settled encounter appears once")
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.1).timeout
        await click(report().tabs[["battles","choices","build"][i]],[0.08,0.5,0.92][i])
        check(report().tab == ["battles","choices","build"][i],"Report tabs respond at three window ratios and button edges")
        if i == 1: check(labels(report()).contains(name) and labels(report()).contains("상인 카드 구매"),"Choices identify the purchased card and its transaction")
        if i == 2: check(labels(report()).contains("탐험 구급함") and labels(report()).contains("사용한 카드"),"Build tab lists actual card uses and relic triggers")
    check(JourneySnapshot.encode(j) == before,"Report opening and tab browsing do not mutate counters or RNG")
    await picture("run-report-build")
    await click(report().tabs["choices"])
    await click(ui.page.find_child("BuyCard_1",true,false))
    check(JourneySnapshot.encode(j) == before,"Modal report blocks purchases through its body")
    await picture("run-report-choices")
    await click(report().body.get_node("Close"))
    check(not ui.report_open,"Close returns to the original camp")
    await click(ui.page.get_node("OpenReport"))
    if native:
        print("OS_KEY Escape")
        await create_timer(0.2).timeout
    else:
        var escape := InputEventKey.new()
        escape.keycode = KEY_ESCAPE
        escape.pressed = true
        root.push_input(escape)
        await process_frame
    settle()
    check(not ui.report_open and JourneySnapshot.encode(j) == before,"Escape closes only the report without leaving the run or mutating measurements")
    # The full campaign below exercises model aggregation; disk persistence has
    # already been checked above and is covered across all stops separately.
    session.set("save_store",JourneySave.new(""))
    for limit in 20000:
        if j.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
        advance(j)
    check(j.phase == TacticalJourney.CLEARED and j.wins == 69,"Recorded campaign reaches the real champion ending")
    check(j.statistics["battles"].size() == 69 and RunStatistics.valid_run(j.statistics),"All 69 records aggregate into a consistent complete run")
    ui.refresh()
    await process_frame
    settle()
    check(labels(ui).contains("상세 내용은 원정 기록"),"Ending presents measured totals and report access")
    await click(ui.page.get_node("OpenReport"))
    check(report().find_children("Battle_*","Control",true,false).size() == 69,"Champion report retains every encounter in a scrollable list")
    await picture("run-report-champion")
    await click(report().tabs["choices"])
    check(labels(report()).contains("상인 카드 구매") and labels(report()).contains("보상"),"Ending retains earlier shop and reward decisions")
    await click(report().body.get_node("Close"))
    # Defeat fixture checks the same report entry point on the other ending.
    j.restart(2026)
    for p: BattlePokemon in j.party: j.battle._damage(p,99999,true)
    j.battle._outcome()
    j.settle()
    ui.refresh()
    await process_frame
    await click(ui.page.get_node("OpenReport"))
    check(j.phase == TacticalJourney.FAILED and labels(report()).contains("패배") and j.statistics["combat"]["knockouts"] == 3,"Defeat also exposes its actual damage and knockout record")
    await picture("run-report-defeat")
    await click(report().body.get_node("Close"))
    var old := JourneySnapshot.encode(j)
    old["run"].erase("statistics")
    old["battle"].erase("statistics")
    ui.journey = JourneySnapshot.restore(old)
    ui.refresh()
    await process_frame
    await click(ui.page.get_node("OpenReport"))
    check(labels(report()).contains("업데이트 이후 기록만 집계") and labels(report()).contains("아직 정산한 전투 기록이 없습니다"),"Legacy runs clearly identify missing historical coverage")
    ui.free()
    print("RUN_REPORT_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
