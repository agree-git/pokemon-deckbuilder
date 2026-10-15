extends "res://tests/test_friendship.gd"
func expected(j: TacticalJourney, write: bool) -> void:
    if write:
        var file := FileAccess.open("user://expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else:
        check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://expected.bin")),"A fresh process restores the exact friendship checkpoint")
func run() -> void:
    var test_root := OS.get_environment("POKEMON_EVOLUTION_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_evolution_process.py --friendship with isolated user directories")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_EVOLUTION_TEST_PHASE")
    var store := JourneySave.new("user://journey.json")
    if phase == "prepare":
        var j := camp_fixture()
        for p: BattlePokemon in j.party:
            p.level = 15
            p.progression_initialized = false
            TacticalGrowth.initialize(p)
            p.experience = TacticalGrowth.experience_floor(16,p.species_id)-0.1
        j.party[0].friendship = 215
        j.deck.assign(TacticalContent.starting_deck(j.party))
        j._next_card_uid = j.deck.size()+1
        j.battle.start_with(j.party,j.deck,j.route.opponents(0),2026,j.relic,true,j.relics)
        j.battle.full_type_chart = true
        check(j.rest().is_empty() and j.party[0].friendship == 220,"Prepare enough friendship with the real camp rest action")
        check(j.set_time("night").is_empty() and j.party[0].species_id == 133,"Choose night without evolving or granting levels")
        check(store.save(j).is_empty(),"Persist a threshold-ready Eevee and time before quitting")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the real save in a new Godot process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase == "evolve":
            check(j.party[0].species_id == 133 and j.party[0].friendship == 220 and j.current_time() == "night","Resume the ready Eevee without rerolling time or evolving during load")
            j.leave_camp()
            j.enter_next()
            for i in 500:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                check(TacticalPolicy.apply(j.battle,TacticalPolicy.action(j.battle)).is_empty(),"Only public battle actions advance to level-up")
            check(j.battle.phase == TacticalBattle.WON and j.settle().is_empty(),"Settle an actual battle after resume")
            while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
            check(j.party[0].species_id == 197 and j.party[0].friendship == 230 and j.party[0].level == 16,"The saved night selects Umbreon on the earned level-up")
            check(store.save(j).is_empty(),"Persist the evolved Pokemon, friendship and settlement")
            expected(j,true)
        else:
            check(j.party[0].species_id == 197 and j.party[0].friendship == 230 and j.current_time() == "night","Another restart keeps the resulting species and exact friendship")
            var before := JourneySnapshot.encode(j)
            check(j.settle().is_empty() and JourneySnapshot.encode(j) == before,"Reopening the restored victory cannot repeat friendship, XP or evolution")
            j.choose_reward(-1)
            check(j.enter_next().is_empty() and j.phase == TacticalJourney.REST and j.party[0].species_id == 197,"Continue normally to the next camp with the evolved member")
    print("FRIENDSHIP_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
