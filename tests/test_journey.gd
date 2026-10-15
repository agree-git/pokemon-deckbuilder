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
func run() -> void:
    var runs := 0
    for seed_value in 30:
        for relic: String in TacticalContent.RELICS:
            var j := TacticalJourney.new(seed_value,relic)
            var before := j.battle.snapshot()
            check(not j.enter_next().is_empty() and not j.leave_camp().is_empty() and not j.buy("potion").is_empty() and j.battle.snapshot() == before,"Combat rejects stale camp actions atomically")
            for guard in 2000:
                if j.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
                match j.phase:
                    TacticalJourney.BATTLE:
                        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                            j.settle()
                        else:
                            check(TacticalPolicy.apply(j.battle,JourneyPolicy.action(j.battle)).is_empty(),"Public tactical action is legal")
                    TacticalJourney.LEARN:
                        j.resolve_learning(-1)
                    TacticalJourney.REWARD: j.choose_reward(seed_value%3)
                    TacticalJourney.MAP:
                        j.enter_next()
                        if j.phase == TacticalJourney.BATTLE and j.step == 4:
                            check(j.battle.enemies.size() == 6 and j.battle.enemies.all(func(p: BattlePokemon): return p.type == "grass" and p.level == 14),"Gym has six stage-scaled Pokemon")
                    TacticalJourney.REST:
                        j.rest()
                        j.leave_camp()
            check(j.phase == TacticalJourney.CLEARED and j.badges == 1 and j.wins == 3,"Seed %d / %s completes scaled expedition (%s)" % [seed_value,relic,j.phase])
            var xp := j.party.map(func(p: BattlePokemon): return p.experience)
            var coins := j.gold
            j.settle()
            check(j.gold == coins and j.party.map(func(p: BattlePokemon): return p.experience) == xp and j.loot.size() == 3,"Repeated settlement cannot duplicate loot, badge or growth")
            check(j.party.all(func(p: BattlePokemon): return p.level >= 5 and p.level < 25 and p.learned_skills.size() <= 4),"Progress stays within first-biome difficulty band without forced levels")
            runs += 1
    print("TACTICAL_JOURNEY: ",checks," checks, ",failures," failures; ",runs," complete run attempts")
    quit(0 if failures == 0 else 1)
