class_name RemovalFixture
extends RefCounted
## Explicit camp/funds/deck boundary fixtures; no claim of earning this position.
static func make(lost_attack := false) -> TacticalJourney:
    var starters: Array[int] = []
    starters.assign([7] if lost_attack else [1,4,7])
    var j := TacticalJourney.new(42,"field_kit",starters,true)
    j.phase = TacticalJourney.MAP
    j.step = 13
    j.enter_next() # Actual seeded merchant immediately before a six-member gym.
    j.gold = 500
    if lost_attack:
        var p := j.party[0]
        TacticalGrowth.award(p,TacticalGrowth.experience_floor(13,7)-p.experience)
        p.learned_skills.assign(["move_55","move_39","move_145","move_110"])
        j.deck.clear()
        for key: String in ["move_55","move_39","move_110"]: j.deck.append(j._allocate_card(key,p.uid))
        for i in 3: j.deck.append(j._allocate_card("guard",0))
    else:
        j.deck[0].upgraded = true
        for i in 2: j.deck.append(j._allocate_card("guard",0))
    return j
