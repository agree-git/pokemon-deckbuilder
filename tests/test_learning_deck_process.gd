extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func expected(j: TacticalJourney, write: bool) -> void:
    if write:
        var file := FileAccess.open("user://learning_expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else: check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://learning_expected.bin")),"Fresh process restores every pending offer, removed card, skill, XP, RNG and resource exactly")
func run() -> void:
    var test_root := OS.get_environment("POKEMON_LEARNING_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_learning_deck_process.py")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_LEARNING_TEST_PHASE")
    var store := JourneySave.new("user://journey.json")
    if phase == "offer":
        var j := LearningDeckFixture.make()
        check(j.phase == TacticalJourney.LEARN and j.learning_preview(1)["copies"] == 0,"The original move was actually removed before its level-up replacement")
        check(store.save(j).is_empty(),"Persist the unconfirmed learning offer")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the learning checkpoint in a fresh process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase == "learn":
            var uid := j._next_card_uid
            var count := j.deck.size()
            check(j.resolve_learning(1).is_empty() and j.deck.size() == count+1 and j.deck[-1].uid == uid and j.deck[-1].key == "move_55","Confirm the saved offer and allocate exactly one fresh technique")
            check(store.save(j).is_empty(),"Persist the learned skill and actual card")
            expected(j,true)
        else:
            var before := JourneySnapshot.encode(j)
            check(not j.resolve_learning(1).is_empty() and JourneySnapshot.encode(j) == before,"A saved accepted offer cannot create or charge a second card")
            j.choose_reward(-1)
            j.enter_next()
            j.rest()
            j.leave_camp()
            j.enter_next()
            for i in 600:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                check(CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"Play the restored shuffled encounter using public actions")
            check(int(j.battle.statistics["cards"].get("move_55",0)) > 0,"The learned Water Gun card is actually drawn and played after restarting")
            check(j.battle.phase == TacticalBattle.WON and j.settle().is_empty(),"The party wins and settles real XP after using the new technique")
            check(store.save(j).is_empty() and store.load_journey() != null,"Continued play remains a valid checkpoint")
    print("LEARNING_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
