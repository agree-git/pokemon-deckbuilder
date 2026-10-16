class_name LearningDeckFixture
extends RefCounted
## Explicit level/XP/funds boundary fixture. Removal, settlement and learning use public actions.
static func make(removed := true, copies := 1) -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var water := j.party[2]
    TacticalGrowth.award(water,TacticalGrowth.experience_floor(12,7)-water.experience)
    for key: String in water.learned_skills:
        if not j.deck.any(func(c: BattleCardInstance): return c.owner_uid == water.uid and c.key == key):
            j.deck.append(j._allocate_card(key,water.uid))
    water.experience = TacticalGrowth.experience_floor(13,7)-1
    for i in j.route.stops.size():
        var stop: Dictionary = j.route.stops[i]
        if stop["kind"] == "rest" and stop["camp"]["kind"] == "merchant":
            j.phase = TacticalJourney.MAP
            j.step = i
            j.enter_next()
            break
    j.gold = 500
    var source: BattleCardInstance
    for card: BattleCardInstance in j.deck:
        if card.owner_uid == water.uid and card.key == "move_39": source = card
    if removed: j.remove_card(source.uid)
    else:
        source.upgraded = true
        for i in range(1,copies): j.deck.append(j._allocate_card("move_39",water.uid))
    j.leave_camp()
    j.enter_next()
    j.battle.phase = TacticalBattle.WON # Isolated experience boundary; no manual battle victory claim.
    j.settle()
    return j
