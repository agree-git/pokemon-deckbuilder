extends "res://tests/test_core_relics_ui.gd"
func expected(j: TacticalJourney, write: bool) -> void:
    if write:
        var file := FileAccess.open("user://core_expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else: check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://core_expected.bin")),"Fresh process restores every saved choice, card, core and spent turn field exactly")
func run() -> void:
    var test_root := OS.get_environment("POKEMON_CORE_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_core_relics_process.py")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_CORE_TEST_PHASE")
    var store := JourneySave.new("user://journey.json")
    if phase == "offer":
        var j := gym(42)
        check(j != null and j.reward_options.size() == 3,"Reach a real first gym reward")
        if j == null:
            quit(1)
            return
        check(store.save(j).is_empty(),"Save the unchosen core alternatives")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the real checkpoint in another process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase == "choose":
            var key: String = j.reward_options[0]["key"]
            check(j.choose_reward(0).is_empty() and CoreRelics.selected(j.relics) == key,"Choose exactly the saved first alternative")
            j.enter_next()
            CampaignPolicy.camp(j)
            j.leave_camp()
            j.enter_next()
            check(j.battle.relics.has(key) and j.battle.hand.size() == CoreRelics.draw_count(j.relics),"Chosen core applies at the next real encounter")
            check(CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"Spend a real action before exiting")
            check(store.save(j).is_empty(),"Persist the selected core and actual combat state")
            expected(j,true)
        else:
            var key := CoreRelics.selected(j.relics)
            for i in 600:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                check(CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"Restored encounter uses only public card, switch and turn actions")
            check(j.battle.phase == TacticalBattle.WON and j.settle().is_empty(),"Continue restored core combat to a real victory")
            var before := JourneySnapshot.encode(j)
            check(j.settle().is_empty() and JourneySnapshot.encode(j) == before,"Victory cannot pay or grant a second core twice")
            check(CoreRelics.selected(j.relics) == key and CoreRelics.valid(j.relics),"The selected core remains exclusive after continuation")
            check(store.save(j).is_empty() and store.load_journey() != null,"The continued victory remains a valid checkpoint")
    print("CORE_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
