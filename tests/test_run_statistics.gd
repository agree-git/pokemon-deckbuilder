extends "res://tests/test_deck_combat.gd"
func play(b: TacticalBattle, key: String) -> void:
    check(b.play_card(by_key(b,key)).is_empty(),"Legal measured card: "+key)
func combat_checks() -> void:
    var b := fixture([["water_gun",7],["guard",0]], ["relay_cell"])
    check(b.statistics["counts"]["drawn"] == 2 and b.statistics["counts"]["turns_started"] == 1,"Initial draw and first turn count once")
    check(b.statistics["relics"].get("field_kit") == 1,"Party-wide starting relic counts once, not once per member")
    var before := b.snapshot()
    for card: BattleCardInstance in b.hand: b.card_view(card)
    check(b.snapshot() == before,"Previewing cards changes no counters or RNG")
    check(not b.play_card(999).is_empty() and b.snapshot() == before,"Invalid inputs do not count attempts")
    var hp := b.enemy().hp
    play(b,"water_gun")
    var counts: Dictionary = b.statistics["counts"]
    check(counts["cards_played"] == 1 and counts["techniques"] == 1 and counts["auto_switches"] == 1,"Technique use and automatic switch are distinct measured actions")
    check(counts["energy_spent"] == 1 and b.energy == 3 and b.statistics["relics"].get("relay_cell") == 1,"Spent energy stays one despite a relic refund")
    check(counts["damage_dealt"] == hp-b.enemy().hp,"Outgoing damage counts actual HP loss")
    var protection := b.active().block
    hp = b.active().hp
    b._damage(b.active(),protection)
    check(b.active().hp == hp and counts["damage_taken"] == 0 and counts["shield_absorbed"] == protection,"Fully blocked damage counts prevention without HP damage")
    b._damage(b.active(),999,true)
    check(counts["damage_taken"] == hp and counts["knockouts"] == 1,"Lethal overkill counts remaining HP and one knockout")
    b._damage(b.active(),999,true)
    check(counts["damage_taken"] == hp and counts["knockouts"] == 1,"Already-fainted targets cannot inflate damage or knockouts")
    b = fixture([["potion_card",0]])
    b.active().hp -= 1
    play(b,"potion_card")
    check(b.statistics["counts"]["healing"] == 1 and b.statistics["counts"]["tools"] == 1,"Healing counts actual recovery after the max-HP cap")
    b = fixture([["seed",1]])
    b.member(1).hp = 1
    play(b,"seed")
    hp = b.member(1).hp
    b._tick(b.enemy())
    check(b.statistics["counts"]["healing"] == b.member(1).hp-hp and b.statistics["counts"]["healing"] > 0,"Seed drain contributes its actual recovery exactly once")
    b = fixture([["guard",0]])
    b.enemy().hp = 1
    check(b.capture_enemy().is_empty() and b.statistics["counts"]["captures"] == 1 and b.statistics["counts"]["damage_dealt"] == 0,"Capture is tracked separately from attack damage")
    b = fixture([["guard",0]])
    check(b.switch_to(7).is_empty(),"Measured manual switch")
    check(b.statistics["counts"]["manual_switches"] == 1 and b.statistics["counts"]["auto_switches"] == 0 and b.statistics["counts"]["energy_spent"] == 1,"Manual switch is charged and categorized once")
    b._damage(b.active(),999,true)
    b.phase = TacticalBattle.REPLACE
    b._pending = "player"
    check(b.switch_to(4).is_empty() and b.statistics["counts"]["forced_switches"] == 1 and b.statistics["counts"]["energy_spent"] == 1,"Forced replacement is free and separately recorded")
    b = fixture([["guard",0]])
    b.end_turn()
    check(b.statistics["counts"]["unused_energy"] == 3 and b.statistics["counts"]["turns_started"] == 2,"Turn-end leftover energy is recorded before the new grant")
    check(b.statistics["counts"]["reshuffles"] == 1 and b.statistics["counts"]["drawn"] == 2,"Only actual reshuffles and received cards count")
func win(j: TacticalJourney) -> void:
    for limit in 500:
        if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        check(TacticalPolicy.apply(j.battle,TacticalPolicy.action(j.battle)).is_empty(),"Reach a real measured victory through public combat actions")
    check(j.battle.phase == TacticalBattle.WON,"Measured starter encounter is won")
func merchant(j: TacticalJourney) -> void:
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] == "rest" and j.route.stops[i]["camp"]["kind"] == "merchant":
            j.phase = TacticalJourney.MAP
            j.step = i
            check(j.enter_next().is_empty(),"Location fixture enters an actual seeded merchant")
            return
func run_checks() -> void:
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    win(j)
    var combat := j.battle.statistics.duplicate(true)
    check(j.settle().is_empty(),"Settle a measured battle")
    check(j.statistics["battles"].size() == 1 and j.statistics["combat"] == combat["counts"] and j.statistics["cards"] == combat["cards"],"Settlement aggregates the complete battle once")
    check(j.statistics["counts"]["gold_earned"] == 40,"Battle income excludes the initial wallet")
    var data := JourneySnapshot.encode(j)
    check(j.settle().is_empty() and JourneySnapshot.encode(j) == data,"Repeated settlement cannot double counts or rows")
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    var name := str(j.reward_view(j.reward_options[0])["name"])
    check(j.choose_reward(0).is_empty() and j.statistics["counts"]["reward_card"] == 1 and j.statistics["choices"].back().contains(name),"Reward choice records category and actual card name")
    merchant(j)
    j.gold = 500 # Budget fixture; all measured changes below use public rules.
    var offer: Dictionary = j.shop_cards()[0].duplicate(true)
    check(j.buy_shop_card(0).is_empty() and j.statistics["counts"]["gold_cards"] == offer["price"] and j.statistics["counts"]["cards_bought"] == 1,"Card purchase records the discounted quote rather than list price")
    var bought: int = j.deck.back().uid
    check(j.rest("upgrade",bought).is_empty() and j.statistics["counts"]["cards_upgraded"] == 1,"Purchased card upgrade records one camp decision")
    var before := JourneySnapshot.encode(j)
    check(not j.buy_shop_card(0).is_empty() and not j.rest().is_empty() and JourneySnapshot.encode(j) == before,"Sold purchases and repeated camp actions never inflate counts")
    check(j.buy("ball").is_empty() and j.statistics["counts"]["gold_supplies"] == 35 and j.statistics["counts"]["supplies_bought"] == 1,"Supply spending uses the same wallet with separate counters")
    check(j.remove_card(j.deck[0].uid).is_empty() and j.statistics["counts"]["gold_removal"] == 50 and j.statistics["counts"]["cards_removed"] == 1,"Removal price and decision count are measured once")
    j.party[0].hp = 1
    var recovered := mini(j.party[0].max_hp-1,PokemonStats.scale(j.party[0],20))
    check(j.use_item("potion",0).is_empty() and j.statistics["counts"]["items_used"] == 1 and j.statistics["counts"]["camp_healing"] == recovered,"Bag healing counts actual HP separately from battle healing")
    check(RunStatistics.spent(j.statistics) == int(offer["price"])+85,"Total spending includes cards, supplies and removal")
    data = JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"Measured combat, shop and camp state validates")
    var store := JourneySave.new("user://tests/records_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Write a real recorded checkpoint")
    var resumed := store.load_journey()
    check(resumed != null,"Read recorded checkpoint")
    if resumed != null:
        check(JourneySnapshot.encode(resumed) == data,"Reload preserves exact aggregates, rows and choices")
        check(j.buy_shop_card(1).is_empty() and resumed.buy_shop_card(1).is_empty() and JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Future measurements match uninterrupted continuation")
    var broken := data.duplicate(true)
    broken["run"]["statistics"]["counts"]["cards_bought"] = -1
    check(not JourneySnapshot.validate(broken),"Reject negative economic counters")
    broken = data.duplicate(true)
    broken["run"]["statistics"]["combat"]["damage_taken"] += 1
    check(not JourneySnapshot.validate(broken),"Reject aggregates inconsistent with battle records")
    broken = data.duplicate(true)
    broken["battle"]["statistics"]["cards"]["unknown_card"] = 1
    check(not JourneySnapshot.validate(broken),"Reject unknown card identities in measurements")
    broken = data.duplicate(true)
    broken["run"]["statistics"]["battles"].append(broken["run"]["statistics"]["battles"][0].duplicate(true))
    check(not JourneySnapshot.validate(broken),"Reject duplicate settled locations")
    j.restart(2026)
    check(j.statistics["battles"].is_empty() and j.statistics["choices"].is_empty() and j.statistics["counts"]["gold_earned"] == 0,"New run resets economic and settled history")
func choice_checks() -> void:
    for kind: String in ["card","relic","held","skip"]:
        var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
        j.phase = TacticalJourney.REWARD # Isolate each legal mixed reward branch.
        j.reward_options.assign([{"kind":"card","key":"guard","owner_uid":0,"upgraded":false},{"kind":"relic","key":"tool_belt"},{"kind":"held","key":"power_band"}])
        var index: int = {"card":0,"relic":1,"held":2,"skip":-1}[kind]
        check(j.choose_reward(index).is_empty() and j.statistics["counts"]["reward_"+kind] == 1,"Reward category/skip is tracked distinctly")
        var before := JourneySnapshot.encode(j)
        check(not j.choose_reward(index).is_empty() and JourneySnapshot.encode(j) == before,"Repeat reward clicks do not inflate choice counts")
    for event_id: String in ["lesson","satchel"]:
        var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
        for i in j.route.stops.size():
            var node := j.route.stops[i]
            if node["kind"] != "rest" or node["camp"].get("id","") != event_id: continue
            j.phase = TacticalJourney.MAP
            j.step = i
            j.enter_next()
            var coins := j.gold
            check(j.resolve_camp(1).is_empty(),"Measured alternate event option is legal")
            if event_id == "lesson":
                check(j.statistics["counts"]["gold_events"] == 50 and j.gold == coins-50 and j.statistics["choices"].back().contains("전술 수업"),"Paid lesson records event spending and learned card")
            else:
                check(j.statistics["counts"]["gold_earned"] == 60 and j.gold == coins+60,"Salvage sale records actual event income")
            var before := JourneySnapshot.encode(j)
            check(not j.resolve_camp(1).is_empty() and JourneySnapshot.encode(j) == before,"Resolved events do not double their economic totals")
            break
func compatibility_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    var old := JourneySnapshot.encode(j)
    old["run"].erase("statistics")
    old["battle"].erase("statistics")
    check(JourneySnapshot.validate(old),"Existing v3 checkpoints without measurements remain valid")
    var resumed := JourneySnapshot.restore(old)
    check(JourneySnapshot.encode(resumed) == old and resumed.statistics.is_empty() and resumed.battle.statistics.is_empty(),"Reading old saves does not invent past measurements")
    var before := JourneySnapshot.encode(resumed)
    resumed.battle.play_card(99999)
    check(JourneySnapshot.encode(resumed) == before,"Invalid actions on an old save do not start counters")
    win(resumed)
    resumed.settle()
    check(resumed.statistics["partial"] and resumed.statistics["battles"][0]["partial"],"Continuation explicitly marks partial battle/run coverage")
    check(JourneySnapshot.validate(JourneySnapshot.encode(resumed)),"Partial measurements are persistable")
func run() -> void:
    combat_checks()
    run_checks()
    choice_checks()
    compatibility_checks()
    print("RUN_STATISTICS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
