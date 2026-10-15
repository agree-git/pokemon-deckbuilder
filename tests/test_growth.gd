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
        if not TacticalPolicy.apply(j.battle,JourneyPolicy.action(j.battle)).is_empty():
            check(false,"Public policy action is legal")
            return
    check(false,"Battle terminates")
func run() -> void:
    var catalog := VisualCatalog.new()
    var p := BattlePokemon.new(TacticalContent.PARTY[0],987)
    p.hp = 20
    var report := TacticalGrowth.award(p,150)
    check(p.level == 10 and p.max_hp == 50 and p.hp == 25 and p.experience == 150,"Multi-level reward adds HP without full-healing")
    check(report["before"] == 5 and report["after"] == 10 and report["learned"] == "회오리불꽃","Growth report exposes level and new skill")
    check(p.learned_skills == ["ember","flame","fire_guard","fire_spin"],"Level ten appends R without replacing QWE")
    check(TacticalGrowth.progress_text(p) == "10 / 40 XP" and is_equal_approx(TacticalGrowth.progress(p),0.25),"XP bar displays progress within current level")
    var skills := p.learned_skills.duplicate()
    TacticalGrowth.award(p,350)
    check(p.level == 16 and p.learned_skills == skills and TacticalGrowth.attack_bonus(p) == 2,"Later levels preserve four skills and add attack power")
    var identity := p.uid
    var xp := p.experience
    var hp := p.hp
    var maximum := p.max_hp
    check(TacticalGrowth.evolve(p,5,catalog).is_empty(),"Level sixteen Charmander can evolve")
    check(p.species_id == 5 and p.display_name == "리자드" and p.uid == identity and p.experience == xp and p.level == 16,"Evolution preserves instance, experience and level")
    check(p.hp == hp+12 and p.max_hp == maximum+12 and p.learned_skills == skills and TacticalGrowth.attack_bonus(p) == 3,"Evolution keeps damage and skills while adding HP/power")
    var before := p.snapshot()
    check(not TacticalGrowth.evolve(p,6,catalog).is_empty() and p.snapshot() == before,"Second evolution rejects insufficient level atomically")
    var b := TacticalBattle.new()
    b.start_with([p],b.hand+b.draw_pile,TacticalContent.ENEMIES,42,"seed_relay",true)
    var damage := int(b.skill_view("fire_spin")["preview_damage"])
    hp = b.enemy().hp
    check(b.use_skill("fire_spin").is_empty() and hp-b.enemy().hp == damage and damage == 16,"Preview and actual damage include permanent growth and evolution bonuses")
    var ko := BattlePokemon.new(TacticalContent.PARTY[2],988)
    ko.hp = 0
    ko.knocked_out = true
    report = TacticalGrowth.award(ko,150)
    check(ko.experience == 45 and ko.level == 7 and ko.hp == 0 and ko.knocked_out,"KO receives thirty percent, can level up, and stays KO")
    check(not TacticalGrowth.evolve(ko,8,catalog).is_empty(),"KO cannot evolve")
    var fractional := BattlePokemon.new(TacticalContent.PARTY[1],989)
    fractional.hp = 0
    for i in 10: TacticalGrowth.award(fractional,1)
    check(fractional.experience == 3.0 and fractional.hp == 0,"Fractional KO awards remain exact under growth")
    var capped := BattlePokemon.new(TacticalContent.PARTY[1],990)
    TacticalGrowth.award(capped,999999)
    check(capped.level == 100 and TacticalGrowth.progress(capped) == 1 and TacticalGrowth.progress_text(capped) == "MAX","Large awards stop at level cap")
    maximum = capped.max_hp
    TacticalGrowth.award(capped,999999)
    check(capped.max_hp == maximum,"Further XP at cap cannot inflate HP")
    var caught_evolution := BattlePokemon.new(TacticalContent.member_definition(8,catalog),991)
    TacticalGrowth.award(caught_evolution,150)
    check(caught_evolution.learned_skills.size() == 4 and caught_evolution.learned_skills.count("bubble_beam") == 1,"Already known fourth-move candidate falls back to another unique move")
    var rules: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolutions.json"))
    check(rules.size() == 135,"Pinned content includes 135 unconditional level evolutions")
    for rule: Dictionary in rules:
        var source := catalog.species(int(rule["from"]))
        var target := catalog.species(int(rule["to"]))
        check(not source.is_empty() and not target.is_empty() and int(target["evolves_from"]) == int(source["id"]) and rule["level"] > 0 and rule["level"] <= 100,"Evolution rule stays in supported generation and correct family")
    for id: int in [25,44,58,64,133,172,236,265]:
        check(TacticalGrowth.rules_for(id).is_empty(),"Stone, trade, friendship and special/random conditions cannot masquerade as plain level evolution")
    # Actual expedition: level, camp evolution, badge and fresh-run reset.
    var j := TacticalJourney.new(2026)
    check(not j.evolve(0,5).is_empty(),"Cannot evolve during combat")
    finish_battle(j)
    j.settle()
    check(j.party[0].level == 10 and j.growth_reports.size() == 3,"Wild victory settles growth once for the whole party")
    var reports := j.growth_reports.duplicate(true)
    j.settle()
    check(j.growth_reports == reports and j.party[0].experience == 150,"Reopening rewards cannot duplicate levels or learning")
    j.choose_reward(-1)
    j.enter_next()
    before = j.party[0].snapshot()
    check(not j.evolve(0,5).is_empty() and j.party[0].snapshot() == before and j.phase == TacticalJourney.REST,"Unavailable evolution does not consume camp")
    j.rest("heal")
    j.enter_next()
    finish_battle(j)
    j.settle()
    j.choose_reward(-1)
    j.enter_next()
    check(j.party[0].level == 16 and j.evolve(0,5).is_empty() and j.phase == TacticalJourney.MAP,"Second camp offers real first evolution before gym")
    check(not j.rest("heal").is_empty() and not j.evolve(1,2).is_empty(),"Evolution consumes the single camp action")
    j.enter_next()
    check(j.battle.active().species_id == 5 or j.battle.party[0].species_id == 5,"Evolved form persists into gym battle")
    finish_battle(j)
    j.settle()
    check(j.phase == TacticalJourney.CLEARED and j.badges == 1,"Grown and evolved party completes gym without health/result mutations")
    j.restart()
    check(j.party[0].species_id == 4 and j.party[0].level == 5 and j.party[0].experience == 0 and j.party[0].learned_skills.size() == 3 and j.last_evolution.is_empty(),"New run resets levels, skills and evolution")
    # Isolate permanent training and injury identity from the successful run.
    j.phase = TacticalJourney.REST
    j.step = 3
    TacticalGrowth.award(j.party[0],500)
    j.party[0].max_hp += 8
    j.party[0].hp += 8
    maximum = j.party[0].max_hp
    var injury := BattleCardInstance.new(1000,"injury",0)
    injury.injury_owner_uid = j.party[0].uid
    j.deck.append(injury)
    j.evolve(0,5)
    check(j.party[0].max_hp == maximum+12 and j.deck.has(injury) and injury.injury_owner_uid == j.party[0].uid,"Evolution preserves training and injury ownership without replacing the deck")
    print("GROWTH: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
