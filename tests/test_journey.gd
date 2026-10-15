extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func finish_battle(j: TacticalJourney) -> void:
    for guard in 600:
        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: return
        check(TacticalPolicy.apply(j.battle,JourneyPolicy.action(j.battle)).is_empty(),"Policy action is legal")
    check(false,"Battle terminates")
func run() -> void:
    var j := TacticalJourney.new()
    var before := j.battle.snapshot()
    check(not j.enter_next().is_empty() and not j.rest("heal").is_empty() and not j.choose_reward(0).is_empty() and j.battle.snapshot() == before,"Unfinished battles reject travel, rest and rewards")
    finish_battle(j)
    check(j.settle().is_empty() and j.phase == TacticalJourney.REWARD,"Victory opens trainer rewards")
    var choices := j.reward_options.duplicate()
    var experience := j.party[0].experience
    var turns := j.total_turns
    j.settle()
    check(j.wins == 1 and j.total_turns == turns and j.reward_options == choices and j.party[0].experience == experience,"Settlement is idempotent")
    var size := j.deck.size()
    check(not j.choose_reward(3).is_empty() and j.phase == TacticalJourney.REWARD and j.deck.size() == size,"Invalid reward rejects atomically")
    check(j.choose_reward(0).is_empty() and j.deck.size() == size+1,"Selected trainer card joins persistent deck")
    check(not j.choose_reward(0).is_empty() and j.deck.size() == size+1,"Reward cannot be claimed twice")
    check(j.enter_next().is_empty() and j.phase == TacticalJourney.REST,"Map leads to rest")
    j.party[0].hp = 0
    var injury := BattleCardInstance.new(1000,"injury",0)
    injury.injury_owner_uid = j.party[0].uid
    j.deck.append(injury)
    check(j.rest("heal").is_empty() and j.party[0].hp == 23 and not j.deck.has(injury),"Healing revives with rounded half HP and removes injuries")
    check(not j.rest("train",0).is_empty(),"Rest cannot be repeated")
    var health: Array = j.party.map(func(p: BattlePokemon): return p.hp)
    var ids: Array = j.deck.map(func(c: BattleCardInstance): return c.uid)
    j.enter_next()
    check(j.battle.party.map(func(p: BattlePokemon): return p.hp) == health,"HP persists into next encounter")
    var next_ids: Array = []
    for pile: Array in [j.battle.hand,j.battle.draw_pile,j.battle.discard,j.battle.exhausted]:
        next_ids.append_array(pile.map(func(c: BattleCardInstance): return c.uid))
    next_ids.sort()
    ids.sort()
    check(next_ids == ids,"All persistent cards, including exhausted cards, return exactly once")
    check(j.battle.turn == 1 and j.battle.energy == 3 and j.battle.used_skills.is_empty() and j.battle.party.all(func(p: BattlePokemon): return p.block == 0 and p.strength == 0 and p.statuses.is_empty()),"Combat-only state resets")
    # Explicit failure path; no rewards/badge/travel after total party KO.
    for pokemon: BattlePokemon in j.party: j.battle._damage(pokemon,999,true)
    j.battle._outcome()
    j.settle()
    check(j.phase == TacticalJourney.FAILED and j.badges == 0 and j.wins == 1,"Party wipe ends run without extra rewards")
    check(not j.enter_next().is_empty(),"Failed runs cannot advance")
    j.restart()
    check(j.deck.size() == 10 and j.party.all(func(p: BattlePokemon): return p.hp == p.max_hp) and j.wins == 0,"Restart resets party, deck and progress")
    j.phase = TacticalJourney.REST
    j.step = 1
    var trained := j.party[1]
    var maximum := trained.max_hp
    check(not j.rest("train",99).is_empty() and trained.max_hp == maximum and j.phase == TacticalJourney.REST,"Invalid training target cannot consume rest")
    j.party[0].hp = 0
    check(not j.rest("train",0).is_empty() and j.phase == TacticalJourney.REST,"KO Pokemon cannot train")
    check(j.rest("train",1).is_empty() and trained.max_hp == maximum+8 and trained.hp == maximum+8,"Training permanently adds eight max and current HP")
    j.enter_next()
    check(j.battle.member(trained.uid).max_hp == maximum+8,"Training survives next battle initialization")
    var runs := 0
    for run_seed in 30:
        for relic: String in TacticalContent.RELICS:
            j = TacticalJourney.new(run_seed,relic)
            for guard in 20:
                match j.phase:
                    TacticalJourney.BATTLE:
                        if j.step == 4:
                            check(j.battle.enemies.size() == 6 and j.battle.enemies.all(func(p: BattlePokemon): return p.species_id <= 151 and p.type == "grass"),"Gym fields six Kanto grass Pokemon")
                        finish_battle(j)
                        j.settle()
                    TacticalJourney.REWARD: j.choose_reward(run_seed%3)
                    TacticalJourney.MAP: j.enter_next()
                    TacticalJourney.REST: j.rest("heal")
                    _: break
            check(j.phase == TacticalJourney.CLEARED and j.badges == 1 and j.wins == 3,"Seed %d / %s completes entire run (phase %s, step %d)" % [run_seed,relic,j.phase,j.step])
            var deck_size := j.deck.size()
            j.settle()
            check(j.badges == 1 and j.deck.size() == deck_size,"Final settlement cannot duplicate badge or deck")
            runs += 1
    print("TACTICAL_JOURNEY: ",checks," checks, ",failures," failures; ",runs," complete run attempts")
    quit(0 if failures == 0 else 1)
