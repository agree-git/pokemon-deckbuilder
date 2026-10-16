extends SceneTree
const Policy = preload("res://tools/campaign_recruitment_policy.gd")
const Camp = preload("res://tools/campaign_camp_policy.gd")
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
        var file := FileAccess.open("user://recruitment_expected.bin",FileAccess.WRITE)
        file.store_buffer(var_to_bytes(JourneySnapshot.encode(j)))
    else: check(JourneySnapshot.encode(j) == bytes_to_var(FileAccess.get_file_as_bytes("user://recruitment_expected.bin")),"Fresh process restores every saved card, capture, RNG, resource and XP field exactly")
func run() -> void:
    var test_root := OS.get_environment("POKEMON_RECRUITMENT_TEST_ROOT")
    if test_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(test_root):
        push_error("Use tools/test_recruitment_process.py")
        quit(2)
        return
    var phase := OS.get_environment("POKEMON_RECRUITMENT_TEST_PHASE")
    var store := JourneySave.new("user://journey.json")
    if phase == "capture":
        var j := TacticalJourney.new(2026,"field_kit",[1],true)
        var policy := Policy.new()
        for i in 2000:
            if j.phase in [TacticalJourney.CAPTURE,TacticalJourney.FAILED]: break
            var error := ""
            match j.phase:
                TacticalJourney.BATTLE:
                    if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: error = j.settle()
                    else: error = policy.apply(j,policy.action(j))
                TacticalJourney.LEARN: error = j.resolve_learning(CampaignPolicy.learn(j))
                TacticalJourney.REWARD: error = j.choose_reward(CampaignPolicy.reward(j))
                TacticalJourney.MAP: error = j.enter_next()
                TacticalJourney.REST:
                    error = Camp.apply(j,"baseline")
                    if error.is_empty(): error = j.leave_camp()
            check(error.is_empty(),"Reach an actual capture using public actions and unchanged stats/resources")
            if not error.is_empty(): break
        check(j.phase == TacticalJourney.CAPTURE and j.pending_captures.size() == 1 and policy.captures.size() == 1,"A real ordinary catch is waiting for recruitment")
        check(j.pending_captures[0].species_id == 41 and j.captured_ids == [41],"The same seed actually captures Zubat without forcing an encounter")
        check(store.save(j).is_empty(),"Save the unconfirmed real capture")
        expected(j,true)
    else:
        var j := store.load_journey()
        check(j != null,"Load the real checkpoint in a new process")
        if j == null:
            quit(1)
            return
        expected(j,false)
        if phase == "join":
            var before := JourneySnapshot.encode(j)
            var view := RecruitmentPreview.describe(j,0)
            check(not view.is_empty() and JourneySnapshot.encode(j) == before,"Restored recruitment preview is pure")
            var caught := j.pending_captures[0]
            var balls := j.balls
            check(j.resolve_capture(0).is_empty() and j.party.size() == 2 and j.party[1] == caught and j.deck.size() == view["after"] and j.balls == balls,"Confirm exactly the restored recruit without a second capture charge")
            j.choose_reward(CampaignPolicy.reward(j))
            j.enter_next()
            Camp.apply(j,"baseline")
            j.leave_camp()
            j.enter_next()
            check(j.phase == TacticalJourney.BATTLE and CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"The recruited party enters the next actual encounter and takes a real action")
            check(store.save(j).is_empty(),"Persist the joined party and actual next encounter")
            expected(j,true)
        else:
            var before := JourneySnapshot.encode(j)
            check(not j.resolve_capture(0).is_empty() and JourneySnapshot.encode(j) == before,"Restored join cannot be confirmed or charged twice")
            for i in 600:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                check(CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"Continue the actual recruited-party battle with public actions")
            check(j.battle.phase == TacticalBattle.WON and j.settle().is_empty(),"The restored recruited party wins and settles real XP")
            check(j.party.size() == 2 and 41 in j.captured_ids and j.party[1].progression_initialized,"Capture unlock and recruited growth survive continued play")
            check(store.save(j).is_empty() and store.load_journey() != null,"Continued recruitment remains a valid checkpoint")
    print("RECRUITMENT_PROCESS ",phase,": ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
