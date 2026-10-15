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
    var catalog := VisualCatalog.new()
    check(TacticalGrowth.data()["species"].size() == 386 and TacticalGrowth.data()["moves"].size() == 354,"Original data covers all generation 1–3 species and moves")
    for move_id in range(1,355):
        var battle := TacticalBattle.new()
        var key := TacticalMoves.key_for(move_id)
        battle.active().learned_skills.assign([key])
        check(battle.use_skill(key).is_empty(),"Every canonical move can execute through battle rules")
    var asleep := TacticalBattle.new()
    asleep.active().learned_skills.assign(["move_95"])
    var hp := asleep.active().hp
    asleep.use_skill("move_95")
    check(asleep.intent().get("asleep",false),"Sleep is reflected in enemy intent")
    asleep.end_turn()
    check(asleep.active().hp == hp and not asleep.enemy().statuses.has("sleep"),"Sleep cancels one action and expires")
    for id in range(1,387):
        var entries: Array = TacticalGrowth.species_data(id)["learnset"]
        check(not entries.is_empty(),"Every species has original level-up data")
        for entry: Dictionary in entries:
            check(not TacticalMoves.definition(TacticalMoves.key_for(int(entry["move"]))).is_empty(),"Every learnable move has an executable tactical definition")
        var previous := 0
        for level in range(2,101):
            var experience := TacticalGrowth.experience_floor(level,id)
            check(experience > previous,"Original species growth curve increases")
            previous = experience
    var p := BattlePokemon.new(TacticalContent.PARTY[0],987)
    TacticalGrowth.initialize(p)
    check(p.level == 5 and p.learned_skills == ["move_10","move_45"] and p.experience == 135,"Charmander starts with original Lv.5 moves and species XP baseline")
    p.hp = 20
    TacticalGrowth.award(p,TacticalGrowth.experience_floor(6,4)-p.experience)
    check(p.level == 6 and "move_52" not in p.learned_skills,"No early Ember or universal Lv.10 grant")
    TacticalGrowth.award(p,TacticalGrowth.experience_floor(7,4)-p.experience)
    check(p.level == 7 and "move_52" in p.learned_skills and p.hp == 22,"Original level seven learns Ember without full-healing")
    var report := TacticalGrowth.award(p,TacticalGrowth.experience_floor(16,4)-p.experience)
    check(p.level == 16 and p.species_id == 5 and p.uid == 987 and report["evolutions"].size() == 1,"Reached level automatically evolves Charmander while retaining identity")
    check(p.learned_skills == ["move_10","move_45","move_52","move_108"],"Evolution keeps known moves and original level thirteen Smokescreen")
    var ko := BattlePokemon.new(TacticalContent.PARTY[0],988)
    TacticalGrowth.initialize(ko)
    var initial := ko.experience
    ko.hp = 0
    ko.knocked_out = true
    report = TacticalGrowth.award(ko,10000)
    check(ko.experience-initial == 3000 and ko.species_id == 5 and ko.hp == 0 and ko.knocked_out,"KO earns thirty percent, auto-evolves at earned level, and stays KO")
    var fractional := BattlePokemon.new(TacticalContent.PARTY[0],989)
    TacticalGrowth.initialize(fractional)
    initial = fractional.experience
    fractional.hp = 0
    for i in 10: TacticalGrowth.award(fractional,1)
    check(fractional.experience-initial == 3,"Fractional KO experience remains exact")
    report = TacticalGrowth.award(fractional,875)
    check(report["xp"] == 262.5 and fractional.hp == 0,"Stage experience retains its exact fractional thirty percent award")
    var caterpie := BattlePokemon.new(TacticalContent.member_definition(10,catalog),990)
    TacticalGrowth.initialize(caterpie)
    report = TacticalGrowth.award(caterpie,TacticalGrowth.experience_floor(12,10)-caterpie.experience)
    check(caterpie.species_id == 12 and caterpie.level == 12 and report["evolutions"].size() == 2,"Bulk experience applies each intermediate evolution and species learnset in order")
    var stone := BattlePokemon.new(TacticalContent.member_definition(58,catalog),991)
    TacticalGrowth.initialize(stone)
    TacticalGrowth.award(stone,TacticalGrowth.experience_floor(40,58)-stone.experience)
    check(stone.species_id == 58,"Stone evolution is never treated as automatic level evolution")
    var capped := BattlePokemon.new(TacticalContent.PARTY[0],992)
    TacticalGrowth.award(capped,2000000)
    var maximum := capped.max_hp
    TacticalGrowth.award(capped,2000000)
    check(capped.level == 100 and capped.max_hp == maximum and TacticalGrowth.progress_text(capped) == "MAX","Level cap prevents extra HP inflation")
    check(TacticalJourneyContent.experience_reward(0) == 400 and TacticalJourneyContent.experience_reward(2) == 875 and TacticalJourneyContent.experience_reward(4) == 1500,"Stage multiplier and encounter multiplier control experience separately from level curves")
    var slow := BattlePokemon.new(TacticalContent.member_definition(147,catalog),993)
    var fast := BattlePokemon.new(TacticalContent.member_definition(39,catalog),994)
    TacticalGrowth.award(slow,400)
    TacticalGrowth.award(fast,400)
    check(slow.level != fast.level,"Same reward can produce different levels in different growth groups")
    var skipped := TacticalJourney.new()
    var grass := skipped.party[1]
    report = TacticalGrowth.award(grass,TacticalGrowth.experience_floor(16,1)-grass.experience)
    skipped.pending_learning.assign(report["offers"])
    skipped.phase = TacticalJourney.LEARN
    var original_moves := grass.learned_skills.duplicate()
    var pending := skipped.pending_learning.size()
    skipped.resolve_learning(-1)
    check(grass.learned_skills == original_moves and skipped.pending_learning.size() == pending-1,"Declining one level-up move retains current moves and advances the queue")
    var j := TacticalJourney.new()
    var water := j.party[2]
    TacticalGrowth.award(water,TacticalGrowth.experience_floor(12,7)-water.experience)
    j.step = 2
    j.battle.phase = TacticalBattle.WON # Isolated reward/learn fixture.
    j.settle()
    check(j.phase == TacticalJourney.LEARN and j.pending_learning[0]["key"] == "move_55","Four moves open replacement for original Water Gun at level thirteen")
    var before := water.snapshot()
    var offers := j.pending_learning.duplicate(true)
    check(not j.resolve_learning(99).is_empty() and water.snapshot() == before and j.pending_learning == offers,"Invalid replacement is atomic")
    var retained := water.learned_skills.slice(1)
    j.resolve_learning(0)
    check(water.learned_skills[0] == "move_55" and water.learned_skills.slice(1) == retained and water.learned_skills.size() == 4,"Replacement changes only selected slot and never exceeds four moves")
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    var xp := water.experience
    var coins := j.gold
    j.settle()
    check(j.gold == coins and water.experience == xp and j.loot.size() == 1,"Reopening settlement cannot duplicate XP, currency, loot or learning")
    j.choose_reward(-1)
    j.enter_next()
    check(j.phase == TacticalJourney.REST and j.shop_stock["potion"] == 3,"Camp opens with persistent visit stock")
    j.party[0].hp = 0
    j.party[0].knocked_out = true
    var injury := BattleCardInstance.new(1000,"injury",0)
    injury.injury_owner_uid = j.party[0].uid
    j.deck.append(injury)
    check(j.rest().is_empty() and j.phase == TacticalJourney.REST and j.party[0].hp > 0 and not j.deck.has(injury),"Rest heals/revives without leaving camp and removes injuries")
    before = j.party[0].snapshot()
    check(not j.rest().is_empty() and j.party[0].snapshot() == before,"Free rest cannot be repeated in one visit")
    var quantity := int(j.inventory["potion"])
    var stock := int(j.shop_stock["potion"])
    coins = j.gold
    check(j.buy("potion").is_empty() and j.gold == coins-30 and j.inventory["potion"] == quantity+1 and j.shop_stock["potion"] == stock-1,"Purchasing updates currency, bag and stock together after rest")
    check(j.use_item("potion",0).is_empty() and j.phase == TacticalJourney.REST,"Bag use remains available after rest and purchases")
    quantity = j.inventory["potion"]
    check(not j.use_item("potion",99).is_empty() and j.inventory["potion"] == quantity,"Invalid item target consumes nothing")
    j.gold = 0
    check(not j.buy("super_potion").is_empty() and j.inventory["potion"] == quantity,"Insufficient currency cannot purchase items")
    j.gold = 200
    while int(j.shop_stock["potion"]) > 0: j.buy("potion")
    coins = j.gold
    quantity = j.inventory["potion"]
    check(not j.buy("potion").is_empty() and j.gold == coins and j.inventory["potion"] == quantity,"Sold-out stock cannot consume currency or grant another item")
    j.leave_camp()
    check(j.phase == TacticalJourney.MAP and not j.leave_camp().is_empty(),"Only explicit departure advances camp")
    j.enter_next()
    j.party[0].hp -= 5
    var energy := j.battle.energy
    check(j.use_item("potion",0).is_empty() and j.battle.energy == energy-1,"Battle bag charges energy for useful healing")
    j.inventory["revive"] = 1
    check(not j.use_item("revive",0).is_empty() and j.inventory["revive"] == 1,"Revive cannot be wasted on a living member")
    j.party[1].hp = 0
    j.party[1].knocked_out = true
    check(j.use_item("revive",1).is_empty() and j.party[1].hp == ceili(j.party[1].max_hp*0.5) and not j.party[1].knocked_out,"Revive restores a KO member through the combat bag")
    j.battle.energy = 0
    quantity = j.inventory["super_potion"]
    check(not j.use_item("super_potion",0).is_empty() and j.inventory["super_potion"] == quantity,"Energy failure cannot consume an item")
    j.restart()
    check(j.gold == 100 and j.loot.is_empty() and j.pending_learning.is_empty() and j.party[0].species_id == 4 and j.party[0].level == 5 and j.inventory["potion"] == 1,"Restart clears run currency, loot, learned moves and evolved forms")
    print("GROWTH: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
