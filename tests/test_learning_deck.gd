extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func identity(cards: Array[BattleCardInstance]) -> Array:
    return cards.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid,c.upgraded,c.injury_owner_uid])
func run() -> void:
    for copies in [0,1,3]:
        var j := LearningDeckFixture.make(copies == 0,copies)
        var p := j.party[2]
        check(j.phase == TacticalJourney.LEARN and j.pending_learning[0]["key"] == "move_55" and p.learned_skills[1] == "move_39","A real settlement offers Water Gun over an existing four-move learnset")
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"The public-removal/level fixture is a valid pending-learning checkpoint")
        var before := JourneySnapshot.encode(j)
        var view := j.learning_preview(1)
        check(view["copies"] == copies and view["after"] == j.deck.size()+(1 if copies == 0 else 0),"Learning preview counts exact source copies and any new card")
        check(view["incoming"]["species_id"] == 7 and view["incoming"]["owner_name"] == p.display_name,"New technique preview belongs to the actual learner")
        check(j.learning_preview(-1).is_empty() and j.learning_preview(99).is_empty() and JourneySnapshot.encode(j) == before,"All previews are read-only, including invalid slots")
        var source := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == p.uid and c.key == "move_39")
        var old_ids := identity(source)
        var other := identity(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid != p.uid or c.key != "move_39"))
        var skills := p.learned_skills.duplicate()
        var xp := p.experience
        var next_uid := j._next_card_uid
        check(not j.resolve_learning(99).is_empty() and JourneySnapshot.encode(j) == before,"An invalid choice is atomic")
        check(j.resolve_learning(1).is_empty(),"Accept the actual level-up offer")
        var gained := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == p.uid and c.key == "move_55")
        check(p.learned_skills.size() == 4 and p.learned_skills[1] == "move_55" and p.learned_skills[0] == skills[0] and p.learned_skills.slice(2) == skills.slice(2),"Only the chosen move slot changes")
        check(gained.size() == maxi(1,copies) and j.deck.size() == view["after"],"A zero-copy source grants exactly one usable new card; real copies replace in place")
        check(identity(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid != p.uid or c.key != "move_55")) == other,"Other allies, shared cards and deliberately removed techniques remain unchanged")
        check(p.experience == xp and j.gold == before["run"]["gold"] and j._next_card_uid == next_uid+(1 if copies == 0 else 0),"Only a genuinely new card allocates a UID; learning spends no extra XP or gold")
        if copies == 0:
            check(not gained[0].upgraded and gained[0].uid == next_uid,"The new card has a fresh ID and no free upgrade")
        else:
            for i in source.size(): check([source[i].uid,source[i].upgraded] == [old_ids[i][0],old_ids[i][3]],"Replacement preserves every existing card identity and upgrade")
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Confirmed learning remains a valid save")
        before = JourneySnapshot.encode(j)
        check(not j.resolve_learning(1).is_empty() and JourneySnapshot.encode(j) == before,"A completed learning choice cannot create cards twice")
        # The new skill reaches the real shuffled battle deck, not only the known-move list.
        j.choose_reward(-1)
        j.enter_next()
        j.leave_camp()
        j.enter_next()
        var actual: Array[BattleCardInstance] = []
        for pile: Array in [j.battle.hand,j.battle.draw_pile,j.battle.discard,j.battle.exhausted]: actual.append_array(pile)
        check(actual.any(func(c: BattleCardInstance): return c.owner_uid == p.uid and c.key == "move_55"),"Learned technique is playable in the next real encounter")
    var j := LearningDeckFixture.make()
    var p := j.party[2]
    var cards := identity(j.deck)
    var known := p.learned_skills.duplicate()
    var next_uid := j._next_card_uid
    check(j.resolve_learning(-1).is_empty() and identity(j.deck) == cards and p.learned_skills == known and j._next_card_uid == next_uid,"Declining a move creates or restores no card")
    print("LEARNING_DECK: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
