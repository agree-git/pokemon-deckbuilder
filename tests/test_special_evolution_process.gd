extends "res://tests/test_special_evolution.gd"
func expected(j: TacticalJourney, write: bool) -> void:
    if write:
        var file := FileAccess.open("user://expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else: check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://expected.bin")),"A fresh process restores every conditional checkpoint field exactly")
func prepare(shed: bool) -> TacticalJourney:
    var starters: Array[int] = []
    starters.assign([290,4] if shed else [236,265,349])
    var j := fixture(starters)
    var levels := [19,19] if shed else [19,6,15]
    for i in j.party.size():
        var p := j.party[i]
        p.level = levels[i]
        p.progression_initialized = false
        TacticalGrowth.initialize(p)
        p.experience = TacticalGrowth.experience_floor(p.level+1,p.species_id)-0.1
    j.deck.assign(TacticalContent.starting_deck(j.party))
    j._next_card_uid = j.deck.size()+1
    j.battle.start_with(j.party,j.deck,j.route.opponents(0),j.seed_value,j.relic,true,j.relics)
    j.battle.full_type_chart = true
    if not shed:
        j.gold = 500
        check(j.choose_evolution(236,107).is_empty(),"Prepare the real Hitmonchan evolution choice")
        for i in 3: check(j.buy("blue_pokeblock").is_empty() and j.use_item("blue_pokeblock",2).is_empty(),"Purchase and feed beauty supplies before exit")
    return j
func run() -> void:
    var test_root := OS.get_environment("POKEMON_EVOLUTION_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_evolution_process.py --special")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_EVOLUTION_TEST_PHASE")
    var shed := phase.begins_with("shed_")
    var store := JourneySave.new("user://journey.json")
    if phase in ["prepare","shed_prepare"]:
        var j := prepare(shed)
        check(store.save(j).is_empty(),"Write the pre-level-up conditional checkpoint")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the real checkpoint in another Godot process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase in ["evolve","shed_evolve"]:
            j.leave_camp()
            check(j.enter_next().is_empty(),"Start the next actual battle after resume")
            for i in 500:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                check(TacticalPolicy.apply(j.battle,TacticalPolicy.action(j.battle)).is_empty(),"Use only public card, switch and turn actions")
            check(j.battle.phase == TacticalBattle.WON and j.settle().is_empty(),"Settle the earned victory")
            while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
            if shed:
                check(j.party.size() == 3 and j.party[0].species_id == 291 and j.party[2].species_id == 292 and j.balls == 1,"Restored Nincada creates exactly one additional member and spends one ball")
            else:
                check(j.party[0].species_id == 107 and j.party[1].species_id in [266,268] and j.party[2].species_id == 350,"Saved evolution choice, personality and beauty select the correct three evolutions")
            check(store.save(j).is_empty(),"Persist evolved forms, new ownership and spent resources")
            expected(j,true)
        else:
            var before := JourneySnapshot.encode(j)
            check(j.settle().is_empty() and JourneySnapshot.encode(j) == before,"A restarted victory cannot repeat rewards or additional births")
            if shed:
                check(j.party[2].uid == 1000 and j.party[2].types == ["bug","ghost"] and j.deck.any(func(c: BattleCardInstance): return c.owner_uid == 1000),"The restored child keeps its unique identity, full type and technique cards")
            else: check(j.party[0].evolution_choice == 107 and j.party[1].evolution_personality >= 0 and j.party[2].beauty == 180,"Preparation survives evolution and another process exit")
            j.choose_reward(-1)
            check(j.enter_next().is_empty() and j.phase == TacticalJourney.REST,"Proceed to the next camp normally")
            j.leave_camp()
            check(j.enter_next().is_empty() and j.battle.party == j.party and JourneySnapshot.validate(JourneySnapshot.encode(j)),"All evolved members and their cards enter the next encounter with a valid save")
    print("SPECIAL_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
