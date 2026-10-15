extends "res://tests/test_evolution_items.gd"
func expected(j: TacticalJourney, write: bool) -> void:
    if write:
        var file := FileAccess.open("user://expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else:
        check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://expected.bin")),"A fresh process restores the exact previous evolution checkpoint")
func run() -> void:
    var test_root := OS.get_environment("POKEMON_EVOLUTION_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_evolution_process.py with isolated user directories")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_EVOLUTION_TEST_PHASE")
    var store := JourneySave.new("user://journey.json")
    if phase == "purchase":
        var j := fixture(25)
        j.gold = 180
        check(j.buy("thunder_stone").is_empty(),"Purchase a relevant material")
        j.deck.back().upgraded = true
        check(store.save(j).is_empty(),"Persist material, sold stock and upgraded cards before quitting")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the real save in a separate Godot process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase == "evolve":
            check(j.party[0].species_id == 25 and j.quantity("thunder_stone") == 1 and j.shop_stock["thunder_stone"] == 0,"Resume the exact purchased, unused material")
            check(j.use_item("thunder_stone",0).is_empty() and j.party[0].species_id == 26,"The resumed material performs the same evolution")
            check(store.save(j).is_empty(),"Persist the evolved species and consumed material")
            expected(j,true)
        else:
            check(j.party[0].species_id == 26 and j.quantity("thunder_stone") == 0 and j.shop_stock["thunder_stone"] == 0,"Another restart keeps the evolution and sold/consumed material")
            var before := JourneySnapshot.encode(j)
            check(not j.use_item("thunder_stone",0).is_empty() and JourneySnapshot.encode(j) == before,"A restarted action cannot evolve or spend twice")
            var p := j.party[0]
            j.leave_camp()
            check(j.enter_next().is_empty() and j.battle.party[0] == p and p.species_id == 26,"A restored evolved member enters the next real battle")
    print("EVOLUTION_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
