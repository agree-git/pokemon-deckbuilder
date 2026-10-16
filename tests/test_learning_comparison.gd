extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func cards_identity(cards: Array[BattleCardInstance], fresh_uid := 0) -> Array:
    return cards.map(func(c: BattleCardInstance): return [fresh_uid if c.uid == 0 else c.uid,c.key,c.owner_uid,c.upgraded,c.injury_owner_uid])
func run() -> void:
    for copies in [0,1,3]:
        for slot in 4:
            var j := LearningDeckFixture.make(copies == 0,copies)
            var before := JourneySnapshot.encode(j)
            var view := LearningComparison.describe(j,slot)
            check(not view.is_empty() and view["change"]["after"] == view["deck_after"].size(),"Hypothetical deck size agrees with the learning rule")
            check(view["before_cards"].size() == view["change"]["copies"] and view["after_cards"].size() == maxi(1,int(view["change"]["copies"])),"All actual departing and incoming copies are visible")
            check(view["after_cards"].all(func(v: Dictionary): return v["key"] == "move_55" and v["species_id"] == 7),"Incoming faces preserve the actual owner and selected move")
            var source := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == j.party[2].uid and c.key == j.party[2].learned_skills[slot])
            check(view["before_cards"].map(func(v: Dictionary): return v["name"]) == source.map(func(c: BattleCardInstance): return TacticalContent.definition(c)["name"]),"Current faces include every original upgrade")
            for c: BattleCardInstance in view["deck_after"]:
                check(not j.deck.has(c),"Every hypothetical instance is separate from live cards")
            check(JourneySnapshot.encode(j) == before,"Building all card faces and matchup rows cannot mutate skills, deck, IDs, XP, RNG, stats, captures or rewards")
            var uid := j._next_card_uid
            check(j.resolve_learning(slot).is_empty(),"Resolve the same choice through the public learning action")
            check(cards_identity(j.deck) == cards_identity(view["deck_after"],uid),"Every previewed key, owner, UID, upgrade and injury link matches actual confirmation")
            for row: Dictionary in view["coverage"]:
                var actual := EncounterPreparation.analyze(j,row["opponent"])
                check(row["attack"][1] == actual["groups"]["attack"].size() and row["strong"][1] == actual["strong"] and row["conditional"][1] == actual["groups"]["conditional"].size(),"Hypothetical coverage exactly matches the actually learned deck")
            check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"A compared choice remains a valid saved run")
    var j := LearningDeckFixture.make()
    var before := JourneySnapshot.encode(j)
    check(LearningComparison.describe(j,-1).is_empty() and LearningComparison.describe(j,99).is_empty() and JourneySnapshot.encode(j) == before,"Invalid comparisons are atomic")
    var view := LearningComparison.describe(j,1)
    check(view["change"]["copies"] == 0 and view["after_cards"].size() == 1 and view["after_cards"][0]["name"] == "물대포","A removed original yields a fresh unupgraded face without allocating a live UID")
    j.party[2].hp = 0
    j.party[2].knocked_out = true
    view = LearningComparison.describe(j,1)
    check(view["coverage"].all(func(row: Dictionary): return row["attack"][0] == row["attack"][1] and row["conditional"][0] == row["conditional"][1]),"A fainted learner's new cards are excluded from both sides equally")
    # Coverage-loss boundary: one Water Gun becomes Normal Rapid Spin before a Ghost gym.
    j = TacticalJourney.new(5,"field_kit",[7],true)
    j.step = 44
    j.phase = TacticalJourney.LEARN
    j.party[0].learned_skills.assign(["move_55","move_39","move_145","move_110"])
    j.pending_learning.assign([{"uid":7,"key":"move_229","level":23,"species":7}])
    j.deck.clear()
    j.deck.append(j._allocate_card("move_55",7))
    for i in 5: j.deck.append(j._allocate_card("guard",0))
    before = JourneySnapshot.encode(j)
    view = LearningComparison.describe(j,0)
    check(view["coverage"].size() == 6 and view["coverage"].all(func(row: Dictionary): return row["attack"] == [1,0]),"Losing the last effective attack is visible for each Ghost opponent")
    check(JourneySnapshot.encode(j) == before,"Coverage-loss inspection leaves the real attack intact")
    # A reserved rare target must be compared without investigating/reserving it again.
    j.rare_hunt = RareEncounter.initial(j.seed_value)
    j.rare_hunt["battle_step"] = 46
    view = LearningComparison.describe(j,0)
    check(view["coverage"].size() == 1 and view["coverage"][0]["opponent"]["id"] == j.rare_hunt["target"],"Comparison respects the exact reserved rare species")
    j.rare_hunt.clear()
    j.step = 136
    view = LearningComparison.describe(j,0)
    check(view["target"].is_empty() and view["coverage"].is_empty() and not view["after_cards"].is_empty(),"After the champion there is no invented next enemy, while card comparison still works")
    j.phase = TacticalJourney.REWARD
    check(LearningComparison.describe(j,0).is_empty(),"Comparison is only available for an actual pending learning choice")
    print("LEARNING_COMPARISON: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
