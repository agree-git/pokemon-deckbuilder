class_name TutorialLesson
extends RefCounted
## Disposable practice fixtures; never adopted by BattleSession or written as a run.
const SEED := 20261019
const FIRST_CARD := 101
const SWITCH_CARD := 102
const GUARD_CARD := 103
static func battle_practice(capture := false) -> TacticalJourney:
    var j := TacticalJourney.new(SEED,"field_kit",[4,7,1],true)
    j.party[0].learned_skills.assign(["move_52","move_10","move_45"])
    j.party[1].learned_skills.assign(["move_55","move_33","move_39"])
    j.deck.assign([
        BattleCardInstance.new(FIRST_CARD,"move_52",j.party[0].uid),
        BattleCardInstance.new(SWITCH_CARD,"move_55",j.party[1].uid),
        BattleCardInstance.new(GUARD_CARD,"guard",0),
        BattleCardInstance.new(104,"focus",0),BattleCardInstance.new(105,"analysis",0),
        BattleCardInstance.new(106,"move_33",j.party[2].uid),BattleCardInstance.new(107,"guard",0),
        BattleCardInstance.new(108,"potion_card",0),BattleCardInstance.new(109,"move_33",j.party[1].uid),BattleCardInstance.new(110,"guard",0)])
    var opponent := {"id":133,"name":"이브이","type":"normal","types":["normal"],"max_hp":40,"level":10,"intents":[{"kind":"attack","value":40,"type":"normal","move_id":33}]}
    j.battle.start_with(j.party,j.deck,[opponent],SEED,"field_kit",true,j.relics)
    # A fixed opening hand lets every learner perform the same three real actions.
    j.battle.hand.assign(j.deck.slice(0,5))
    j.battle.draw_pile.assign(j.deck.slice(5))
    j.battle.discard.clear()
    if capture:j.battle.enemy().hp=maxi(1,floori(j.battle.enemy().max_hp/4.0))
    return j
static func camp_practice(upgrade := false) -> TacticalJourney:
    var j := battle_practice()
    j.step=3 if upgrade else 1
    j.phase=TacticalJourney.REST
    for p:BattlePokemon in j.party:
        p.hp=p.max_hp if upgrade else maxi(1,floori(p.max_hp*.3))
        p.block=0
    return j
