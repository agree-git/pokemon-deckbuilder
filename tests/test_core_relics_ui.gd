extends "res://tests/test_merchant_ui.gd"
func gym(seed_value: int) -> TacticalJourney:
    var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
    for i in 2000:
        if j.phase == TacticalJourney.REWARD and j.current()["kind"] == "gym": return j
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
            _:
                check(false,"Reach a gym reward through real public actions")
                return null
    return null
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/core_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/core_ui_journey.json"))
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        var j := gym([0,42,2026][i])
        check(j != null and j.badges == 1,"Actual first gym victory offers the core choice")
        if j == null:
            quit(1)
            return
        session.adopt_journey(j)
        if is_instance_valid(ui):
            ui.queue_free()
            await process_frame
        ui = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.15).timeout
        var graph := JourneySnapshot.encode(j)
        var choices := j.reward_options.duplicate(true)
        check(ui.page.find_children("CoreReward_*","Button",true,false).size() == 3 and ui.page.find_child("CoreRewardTitle",true,false) != null,"Reward page shows three exclusive options and their selection rule")
        for k in 3:
            var option: Button = ui.page.find_child("CoreReward_%d" % k,true,false)
            var definition: Dictionary = TacticalContent.RELICS[choices[k]["key"]]
            check(option.tooltip_text.contains(definition["benefit"]) and option.tooltip_text.contains(definition["tradeoff"]),"Every offer exposes its benefit and tradeoff")
        ui.refresh()
        await process_frame
        settle()
        check(JourneySnapshot.encode(j) == graph,"Redrawing the choice neither rerolls nor grants anything")
        if i == 0: await picture("core-relic-choice")
        var key: String = choices[i]["key"]
        await click(ui.page.find_child("CoreReward_%d" % i,true,false),[0.08,0.5,0.92][i])
        check(j.phase == TacticalJourney.MAP and CoreRelics.selected(j.relics) == key and CoreRelics.valid(j.relics),"Visible top/center/bottom choice grants exactly the selected core at three ratios")
        var loaded: TacticalJourney = session.get("save_store").load_journey()
        check(loaded != null and JourneySnapshot.encode(loaded) == JourneySnapshot.encode(j),"Actual core choice autosaves without reroll or duplicate reward")
        j.enter_next()
        j.leave_camp()
        j.enter_next()
        ui.refresh()
        await process_frame
        TacticalUIPlayer.finish(ui.battle_ui)
        check(ui.battle_ui.battle.relics.has(key),"The chosen core reaches the next actual battle")
        await click(ui.battle_ui.menu_button)
        var scroll: ScrollContainer = ui.battle_ui.menu_panel.find_child("RelicScroll",true,false)
        check(scroll != null and scroll.get_child(0).get_child(0).find_children("*","Label",true,false).any(func(label: Label): return label.text.begins_with("핵심 · ")),"Battle menu lists the chosen core first in a scrollable relic list")
        check(ui.battle_ui.relic_chip.tooltip_text.contains(TacticalContent.RELICS[key]["description"]),"Battle HUD keeps the full core benefit and price available")
        if i == 0: await picture("core-relic-menu")
    # Endgame display fixture: one core plus all ten ordinary relics.
    var endgame := ui.journey
    for key: String in TacticalContent.RELICS:
        if key not in CoreRelics.KEYS and key not in endgame.relics: endgame.relics.append(key)
    endgame.battle.relics.assign(endgame.relics)
    ui.refresh()
    await process_frame
    TacticalUIPlayer.finish(ui.battle_ui)
    await click(ui.battle_ui.menu_button)
    var scroll: ScrollContainer = ui.battle_ui.menu_panel.find_child("RelicScroll",true,false)
    var list := scroll.get_child(0)
    check(list.get_child_count() == 11,"One core and all ordinary relics fit the endgame menu")
    if native:
        var point := root.get_final_transform()*(scroll.get_global_transform_with_canvas()*(scroll.size*0.5))+Vector2(root.position)
        print("OS_WHEEL ",roundi(point.x)," ",roundi(point.y)," 6")
        await create_timer(0.25).timeout
    else: scroll.ensure_control_visible(list.get_child(10))
    await process_frame
    check(scroll.scroll_vertical > 0 and list.get_child(10).get_global_rect().end.y <= scroll.get_global_rect().end.y+1,"The last relic remains reachable inside the scroll viewport")
    check(scroll.get_global_rect().end.y < ui.battle_ui.restart_button.get_global_rect().position.y,"Relics never overlap the restart action")
    await picture("core-relic-endgame-menu")
    print("CORE_RELICS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer inputs")
    quit(0 if failures == 0 else 1)
