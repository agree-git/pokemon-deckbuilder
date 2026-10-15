extends "res://tests/test_rare_encounter.gd"
func expected(j: TacticalJourney,write: bool) -> void:
    if write:
        var file := FileAccess.open("user://expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else: check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://expected.bin")),"A fresh process restores the exact quest, capture receipt, piles and RNG")
func run() -> void:
    var phase := OS.get_environment("POKEMON_RARE_PHASE")
    var target_id := int(OS.get_environment("POKEMON_RARE_TARGET"))
    var session := root.get_node("BattleSession")
    if phase == "finished":
        check(not session.get("has_journey"),"A failed expedition cannot be revived by its backup")
        check(target_id in PlayerProfile.new().unlocked_starters(VisualCatalog.new()),"Collection remains unlocked on the next app startup")
        var starters: Array[int] = [target_id]
        check(session.start_journey(starters,2026).is_empty(),"The normal starter flow accepts the newly captured rare")
        var started: TacticalJourney = session.get("journey")
        check(started.party[0].species_id == target_id and started.party[0].level == 5 and started.rare_hunt.is_empty(),"The rare starts at level five with a fresh expedition quest")
        print("RARE_PROCESS ",target_id," ",phase,": ",checks," checks, ",failures," failures")
        quit(0 if failures == 0 else 1)
        return
    var j: TacticalJourney
    if phase == "prepare":
        var chosen_seed := 0
        for seed_value in 400:
            if RareEncounter.target(seed_value) == target_id:
                chosen_seed = seed_value
                break
        j = RareTestSupport.fixture(chosen_seed)
        var last: int = j.rare_hunt["clues"].pop_back()
        j.rested_steps.erase(last)
        session.adopt_journey(j)
        check(j.investigate().is_empty(),"Investigation auto-saves through the normal BattleSession")
        check(j.step in j.rare_hunt["clues"] and j.step in j.rested_steps,"Persist final clue and shared action receipt")
    else:
        check(session.get("has_journey"),"Normal app startup restored the active campaign")
        if not session.get("has_journey"):
            quit(1)
            return
        j = session.get("journey")
        expected(j,false)
        match phase:
            "reserve":
                unchanged(j,j.investigate,"Restart does not grant another investigation")
                check(j.challenge_rare().is_empty(),"Restored clues and badges reserve the encounter")
                j.leave_camp()
                check(j.enter_next().is_empty() and j.battle.enemy().species_id == target_id,"Travel reaches the deterministic target")
                RareTestSupport.ready_capture(j) # Explicit threshold fixture.
                j.notify_changed()
            "capture":
                check(j.capture_reason().is_empty() and j.capture().is_empty(),"Restored threshold state permits one capture")
                check(j.balls == 0 and j.battle.energy == 0,"Exactly the tier's saved resources are consumed")
                check(target_id in PlayerProfile.new().captured_ids,"Normal autosave persists collection before settlement")
            "continue":
                unchanged(j,j.capture,"Restarted success cannot be captured twice")
                check(j.rare_hunt["captured"] and target_id in PlayerProfile.new().unlocked_starters(VisualCatalog.new()),"Rare starter unlock survives process exit before party choice")
                j.settle()
                while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
                check(j.resolve_capture(-1).is_empty(),"Releasing a full-party capture does not undo its collection")
                j.choose_reward(-1)
                j.enter_next()
                unchanged(j,j.challenge_rare,"A later camp cannot grant a second attempt")
            "failure":
                # Loss boundary fixture: the previously earned permanent unlock survives.
                for p: BattlePokemon in j.party: p.hp = 0
                j.leave_camp()
                j.enter_next()
                j.battle.phase = TacticalBattle.LOST
                j.settle()
                check(target_id in PlayerProfile.new().unlocked_starters(VisualCatalog.new()),"Run loss keeps the rare collection unlock")
    check(session.get("save_notice").is_empty(),"All production autosaves succeed")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Process boundary has a valid snapshot")
    expected(j,true)
    print("RARE_PROCESS ",target_id," ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
