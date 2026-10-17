class_name RareTestSupport
extends RefCounted
## Mid-campaign boundary fixtures; no claim that skipped victories were played.
static func fixture(seed_value: int) -> TacticalJourney:
    var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
    var required := RareEncounter.requirement(RareEncounter.target(seed_value))
    for i in required:
        j.step = 1+i*2
        j.phase = TacticalJourney.MAP
        j.enter_next()
        j.investigate()
    for i in required:
        var step := i*16+14
        var stop: Dictionary = j.route.stops[step]
        j.badge_records.append({"type":stop["biome"]["type"],"biome":stop["biome"]["id"],"leader_id":stop["trainer"]["leader_id"],"leader":stop["trainer"]["leader"],"step":step})
    j.badges = required
    j.step = required*16-1
    j.phase = TacticalJourney.MAP
    j.enter_next()
    j.balls = int(RareEncounter.rule(RareEncounter.target(seed_value))["balls"])
    for p: BattlePokemon in j.party:
        p.level = int(j.route.stops[j.step+1]["level"])
        p.progression_initialized = false
        TacticalGrowth.initialize(p)
    j.deck.assign(TacticalContent.starting_deck(j.party))
    j._next_card_uid = j.deck.size()+1
    return j
static func enter(j: TacticalJourney) -> void:
    j.challenge_rare()
    j.leave_camp()
    j.enter_next()
static func ready_capture(j: TacticalJourney) -> void:
    j.battle.enemy().hp = floori(j.battle.enemy().max_hp*int(RareEncounter.rule(j.battle.enemy().species_id)["hp_percent"])/100.0)
    j.battle.energy = int(RareEncounter.rule(j.battle.enemy().species_id)["energy"])
