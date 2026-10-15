extends "res://tests/test_journey_ui.gd"
## Entire full campaign through UI input, using a deterministic public-action policy.
var keys := 0
var camp_services_checked := false
func click(control: Control) -> void:
    settle()
    if control is TrainerActionCard and is_instance_valid(ui.battle_ui):
        ui.battle_ui.hand_scroll.ensure_control_visible(control)
        await process_frame
        settle()
    if native:
        var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size/2
        var at := Vector2(root.position)+root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.12).timeout
    else:
        TacticalUIPlayer.click(self,control)
    clicks += 1
    await process_frame
    settle()
func key(symbol: String) -> void:
    settle()
    if native:
        print("OS_KEY ",symbol)
        await create_timer(0.12).timeout
    else:
        for down: bool in [true,false]:
            var event := InputEventKey.new()
            event.keycode = KEY_ENTER if symbol == "Return" else OS.find_keycode_from_string(symbol)
            event.pressed = down
            root.push_input(event)
        await process_frame
    keys += 1
    settle()
func battle_action(action_value: Array) -> void:
    var battle := ui.journey.battle
    match action_value[0]:
        "skill": await key("QWER"[TacticalContent.skills_for(battle.active()).find(action_value[1])])
        "switch":
            for i in battle.party.size():
                if battle.party[i].uid == action_value[1]: await key(str(i+1))
        "end": await key("Return")
        "item":
            await click(ui.battle_ui.menu_button)
            await click(ui.battle_ui.bag_button)
            await click(ui.battle_ui.bag_panel.get_node("Body/Items/Use_%s_%d" % [action_value[1],action_value[2]]))
            await click(ui.battle_ui.bag_panel.get_node("Body/Close"))
        _: await click(TacticalUIPlayer.button(ui.battle_ui,action_value))
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i(20,20)
    var session := root.get_node("BattleSession")
    var starters: Array[int] = [1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Normal new game starts full campaign")
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.journey.full_campaign and ui.journey.battle.full_type_chart,"Normal gameplay uses full campaign and full type chart")
    var viewed: Dictionary = {}
    for guard in 2400:
        var j := ui.journey
        if j.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
        if guard % 100 == 0: print("CAMPAIGN_UI progress: input=",guard," step=",j.step," badges=",j.badges," elite=",j.elite_wins)
        if j.phase == TacticalJourney.BATTLE:
            var b := j.battle
            var kind: String = j.current()["kind"]
            if not viewed.has(kind):
                await capture("campaign_"+kind)
                viewed[kind] = true
            if b.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                check(ui.battle_ui.result.visible,"Encounter result is actionable")
                for row: Button in ui.battle_ui.party_buttons:
                    check(Rect2(Vector2.ZERO,row.size).encloses(row.get_child(0).get_rect()),"Evolved ally portrait fits roster row")
                for row: Button in ui.battle_ui.enemy_slots:
                    check(Rect2(Vector2.ZERO,row.size).encloses(row.get_child(0).get_rect()),"Large opponent portrait fits roster row")
                await click(ui.battle_ui.result_next)
            else:
                var before := b.snapshot()
                await battle_action(CampaignPolicy.action(j))
                check(b.snapshot() != before,"UI action changes combat state")
                if b.snapshot() == before:
                    quit(1)
                    return
        elif j.phase == TacticalJourney.LEARN:
            var slot := CampaignPolicy.learn(j)
            await click(ui.learn_buttons[slot] if slot >= 0 else ui.actions.back())
        elif j.phase == TacticalJourney.REWARD:
            await click(ui.actions.back())
        elif j.phase == TacticalJourney.MAP:
            if not viewed.has("map"):
                await verify_page()
                await capture("campaign_map")
                viewed["map"] = true
            if int(j.current()["chapter"]) == 8 and not viewed.has("league_map"):
                await capture("campaign_league_map")
                viewed["league_map"] = true
            await click(ui.actions[0])
        elif j.phase == TacticalJourney.REST:
            if j.step not in j.rested_steps: await click(ui.rest_button)
            if not camp_services_checked:
                await click(ui.camp_tabs["shop"])
                var coins := j.gold
                var balls_before := j.balls
                await click(ui.page.find_child("Buy_ball",true,false))
                check(j.balls == balls_before+1 and j.gold == coins-35,"Camp buys capture ball through UI")
                await capture("campaign_shop")
                await click(ui.camp_tabs["bag"])
                await capture("campaign_bag")
                await click(ui.camp_tabs["loot"])
                await capture("campaign_loot")
                camp_services_checked = true
            # Same optional healing decisions as model policy, via bag controls.
            for i in j.party.size():
                for item: String in ["revive","super_potion","potion"]:
                    if j.quantity(item) == 0 and j.party[i].hp < j.party[i].max_hp/2.0 and j.buy_reason(item).is_empty():
                        await click(ui.camp_tabs["shop"])
                        await click(ui.page.find_child("Buy_"+item,true,false))
                    if j.item_reason(item,i).is_empty():
                        await click(ui.camp_tabs["bag"])
                        await click(ui.page.find_child("Use_%s_%d" % [item,i],true,false))
            await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.CLEARED and ui.journey.badges == 8 and ui.journey.elite_wins == 4 and ui.journey.wins == 29,"Finish 29 encounters and become champion through input")
    check(camp_services_checked and viewed.has("champion"),"Camp and league pages exercised")
    await capture("campaign_ending")
    await verify_page()
    await click(ui.actions[0])
    check(ui.journey.phase == TacticalJourney.BATTLE and ui.journey.badges == 0 and ui.journey.elite_wins == 0 and ui.journey.full_campaign,"Ending restarts full campaign")
    print("CAMPAIGN_UI: ",checks," checks, ",failures," failures; ",clicks," pointer inputs, ",keys," key inputs")
    quit(0 if failures == 0 else 1)
