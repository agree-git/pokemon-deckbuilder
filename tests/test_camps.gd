extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func visit(j: TacticalJourney, step: int) -> void:
    j.phase = TacticalJourney.MAP
    j.step = step
    check(j.enter_next().is_empty() and j.phase == TacticalJourney.REST,"Enter actual camp")
func run() -> void:
    # Every growth group reaches 100 after the fourth Elite win, without setting levels.
    var catalog := VisualCatalog.new()
    for species: Dictionary in catalog.pokemon:
        var id := int(species["id"])
        var xp := float(TacticalGrowth.experience_floor(5,id))
        var ko := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        TacticalGrowth.initialize(ko)
        ko.hp = 0
        for i in CampaignBalance.CHAMPION_INDEX:
            var reward := CampaignBalance.experience_reward(i,id)
            check(reward > 0,"Every victory has positive species-scaled XP")
            xp += reward
            ko.gain_experience(reward)
            if i == CampaignBalance.CHAMPION_INDEX-2: check(TacticalGrowth.level_for(xp,id) < 100,"No premature Lv.100 before last Elite win")
        check(absf(xp-TacticalGrowth.experience_floor(100,id)) < 0.05,"Exact original Lv.100 XP budget: %d" % id)
        check(TacticalGrowth.level_for(xp+0.05,id) == 100 and TacticalGrowth.level_for(ko.experience,id) < 100,"Alive reaches 100; 30% KO awards keep growth penalty")
    var j := TacticalJourney.new(2026,"seed_relay",[1,4,7],true)
    var seen: Dictionary = {}
    for i in j.route.stops.size():
        var node := j.route.stops[i]
        if node["kind"] != "rest": continue
        check(node["camp"] == CampContent.generate(2026,i),"Camp outcome is independent and seed-reproducible")
        var key: String = node["camp"].get("id",node["camp"]["kind"])
        if seen.has(key): continue
        seen[key] = true
        visit(j,i)
        var state := j.camp()
        var snapshot := state.duplicate(true)
        if key == "merchant":
            var balls := j.balls
            var gold := j.gold
            check(j.buy("ball").is_empty() and j.balls == balls+1 and j.gold == gold-35,"Random merchant sells balls")
            var stock := j.shop_stock.duplicate()
            visit(j,i)
            check(j.shop_stock == stock,"Camp reentry cannot replenish merchant stock")
        else:
            var gold := j.gold
            var inventory := j.inventory.duplicate()
            check(not j.buy("potion").is_empty() and j.gold == gold and j.inventory == inventory,"No merchant means no purchases")
        if key == "lesson":
            j.gold = 0
            var deck := j.deck.duplicate()
            check(not j.resolve_camp(0).is_empty() and j.deck == deck and not state["resolved"],"Unaffordable lesson is atomic")
            j.gold = 100
            check(j.resolve_camp(0).is_empty() and j.gold == 50 and j.deck.size() == deck.size()+1,"Paid lesson adds one trainer card")
        elif key == "spring":
            j.party[0].hp = 1
            check(j.resolve_camp(0).is_empty() and j.party[0].hp > 1,"Spring heals the real party")
        elif key == "satchel":
            var balls := j.balls
            check(j.resolve_camp(0).is_empty() and j.balls == balls+2,"Satchel supplies reach capture inventory")
        elif key == "discovery":
            var item: String = state["item"]
            var count := j.quantity(item)
            check(j.resolve_camp(0).is_empty() and j.quantity(item) == count+int(state["quantity"]),"Found item enters bag")
        if key not in ["merchant","quiet"]:
            var gold := j.gold
            var items := j.inventory.duplicate()
            var balls := j.balls
            var cards := j.deck.size()
            check(not j.resolve_camp(0).is_empty() and j.gold == gold and j.inventory == items and j.balls == balls and j.deck.size() == cards,"Camp event can only pay out once")
            visit(j,i)
            check(j.camp()["resolved"],"Reentry preserves event choice")
        var before := j.party[0].hp
        check(j.rest().is_empty() and j.party[0].hp >= before,"Rest is available with every encounter kind")
        check(not j.rest().is_empty(),"Rest is once per visit")
        check(snapshot["kind"] == state["kind"],"Rest cannot reroll the encounter")
    check(seen.size() == 6,"Merchant, three events, discovery and quiet camps all exist")
    # Remaining event branches and skip must preserve their distinct outcomes.
    for event_id: String in ["satchel","lesson","spring"]:
        j.restart(2026)
        for i in j.route.stops.size():
            var node := j.route.stops[i]
            if node["kind"] != "rest" or node["camp"].get("id","") != event_id: continue
            visit(j,i)
            var coins := j.gold
            var potions := j.quantity("super_potion")
            var cards := j.deck.size()
            check(j.resolve_camp(1).is_empty(),"Second event choice is legal")
            match event_id:
                "satchel": check(j.gold == coins+60 and j.loot.back()["item"] == "","Selling salvage records a gold-only reward")
                "lesson": check(j.gold == coins-50 and j.deck.size() == cards+1 and j.deck.back().key == "counter","Second lesson teaches counter")
                "spring": check(j.quantity("super_potion") == potions+1,"Bottled spring enters inventory")
            break
    j.restart(2026)
    for i in j.route.stops.size():
        var node := j.route.stops[i]
        if node["kind"] != "rest" or node["camp"]["kind"] != "discovery": continue
        visit(j,i)
        var coins := j.gold
        var inventory := j.inventory.duplicate()
        var balls := j.balls
        check(not j.resolve_camp(99).is_empty() and not j.camp()["resolved"],"Invalid event choice cannot consume a discovery")
        check(j.resolve_camp(-1).is_empty() and j.camp()["resolved"] and j.gold == coins and j.inventory == inventory and j.balls == balls,"Skip consumes the opportunity without adding rewards")
        break
    var initial := j.route.stops.duplicate(true)
    j.restart(2026)
    check(j.camp_states.is_empty() and j.route.stops == initial,"Restart resets claims, preserving seeded encounters")
    print("CAMPS_AND_PACING: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
