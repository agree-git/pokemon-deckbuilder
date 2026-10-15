extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func reload(j: TacticalJourney) -> TacticalJourney:
    var encoded := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(encoded),"Validate new deck/relic/item state at "+j.phase+" / "+str(j.step))
    if not JourneySnapshot.validate(encoded): return j
    var next := JourneySnapshot.restore(encoded)
    check(JourneySnapshot.encode(next) == encoded,"Snapshot preserves owner/upgrades/powers/retained cards and RNG")
    return next
func fixture() -> TacticalJourney:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.battle.enemy().hp = 1 # Capture threshold fixture, not a simulated victory.
    check(j.capture().is_empty(),"Capture still pays ball and energy under card combat")
    j.settle()
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    return j
func run() -> void:
    var powered := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    powered.relics.append("tool_belt")
    powered.deck.clear()
    for specification: Array in [["relay_plan",0],["boost_card",0],["hold",0],["guard",0],["move_10",4],["focus",0]]:
        powered.deck.append(BattleCardInstance.new(powered.deck.size()+1,specification[0],specification[1]))
    powered._next_card_uid = powered.deck.size()+1
    powered.battle.start_with(powered.party,powered.deck,powered.route.opponents(0),2026,powered.relic,true,powered.relics)
    powered.battle.full_type_chart = true
    powered.battle.hand.assign(powered.deck)
    powered.battle.draw_pile.clear()
    for uid: int in [1,2,3]: powered.battle.play_card(uid)
    check(not powered.battle.powers.is_empty() and not powered.battle.retained.is_empty() and not powered.battle.temporary_strength.is_empty(),"Fixture reaches persistent plan, retained hand, temporary boost and relic trigger state")
    var restored_power := reload(powered)
    powered.battle.play_card(5)
    restored_power.battle.play_card(5)
    check(JourneySnapshot.encode(powered) == JourneySnapshot.encode(restored_power),"Restored automatic switch resolves boosts and persistent effects identically")
    var j := fixture()
    check(j.phase == TacticalJourney.CAPTURE,"Captured member is offered after settlement")
    j = reload(j)
    var leaving := j.party[0].uid
    j.party[0].held_item = "power_band"
    var caught := j.pending_captures[0]
    check(j.resolve_capture(0).is_empty(),"Capture party replacement is legal")
    check(not j.deck.any(func(card: BattleCardInstance): return card.owner_uid == leaving),"Leaving member's techniques are removed")
    check(j.deck.any(func(card: BattleCardInstance): return card.owner_uid == caught.uid) and "power_band" in j.held_inventory,"New member gets techniques; old held item returns to bag")
    check(j.reward_options.size() == 3,"One mixed reward set is offered per encounter")
    var options := j.reward_options.duplicate(true)
    j = reload(j)
    check(j.reward_options == options,"Reload never rerolls mixed rewards")
    j.reward_options[0] = {"kind":"relic","key":"tool_belt"}
    var count := j.deck.size()
    check(j.choose_reward(0).is_empty() and "tool_belt" in j.relics and j.deck.size() == count,"Relic reward does not add a card")
    var seed := j.seed_value
    check(not j.choose_reward(0).is_empty() and j.seed_value == seed,"Reward pays once")
    j.enter_next()
    check(j.phase == TacticalJourney.REST,"Every battle still leads to camp")
    check(j.equip_held("power_band",caught.uid).is_empty() and j.party[0].held_item == "power_band" and j.held_inventory.is_empty(),"Equip consumes exactly one bag item")
    j.held_inventory.append("guard_charm")
    check(j.equip_held("guard_charm",caught.uid).is_empty() and "power_band" in j.held_inventory,"Replacing equipment returns previous item")
    var card := j.deck[0]
    var before_hp := j.party.map(func(p: BattlePokemon): return p.hp)
    check(j.rest("upgrade",card.uid).is_empty() and card.upgraded,"Camp upgrades selected instance")
    check(not j.rest().is_empty() and j.party.map(func(p: BattlePokemon): return p.hp) == before_hp,"Upgrade consumes the same action as rest")
    j = reload(j)
    check(not j.rest("upgrade",card.uid).is_empty(),"Reload cannot grant a second camp action")
    j.leave_camp()
    j.enter_next()
    check(j.battle.relics == j.relics and j.battle.member(caught.uid).held_item == "guard_charm","Equipment and acquired relics apply to the next combat")
    check(not j.equip_held("power_band",caught.uid).is_empty(),"Equipment cannot be shuffled mid-combat")
    # Resolve a real victory later in the complete campaign below. Merchant fixture
    # isolates permanent removal cost, last-owner-card protection and persistence.
    j.phase = TacticalJourney.MAP
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] == "rest" and j.route.stops[i]["camp"]["kind"] == "merchant":
            j.step = i
            break
    j.enter_next()
    var removable := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == 0)[0] as BattleCardInstance
    var price := j.removal_price()
    var gold := j.gold
    count = j.deck.size()
    check(j.remove_card(removable.uid).is_empty() and j.gold == gold-price and j.deck.size() == count-1,"Merchant removal spends gold and permanently prunes a card")
    check(not j.remove_card(j.deck[0].uid).is_empty(),"Merchant removes at most one card per visit")
    j = reload(j)
    check(j.camp()["removed"] and j.removal_price() == price+25,"Removal receipt and escalating price survive reload")
    var singleton := TacticalJourney.new(71,"field_kit",[129],true)
    check(singleton.deck.any(func(c: BattleCardInstance): return c.key == "move_165"),"Support-only starters receive a drawn Struggle card")
    check(JourneySnapshot.validate(JourneySnapshot.encode(singleton)),"Support-only starter deck validates")
    var seen := {}
    var path := "user://tests/deck_run_%d/journey.json" % Time.get_ticks_usec()
    var store := JourneySave.new(path)
    for run_seed in [0,42,2026]:
        j = TacticalJourney.new(run_seed,"field_kit",[1,4,7],true)
        var guard := 0
        var selected := 0
        var purchases := 0
        while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and guard < 20000:
            guard += 1
            if not seen.has(j.phase):
                seen[j.phase] = true
                j = reload(j)
            var reason := ""
            match j.phase:
                TacticalJourney.BATTLE:
                    if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: reason = j.settle()
                    else: reason = CampaignPolicy.apply(j,CampaignPolicy.action(j))
                TacticalJourney.LEARN: reason = j.resolve_learning(CampaignPolicy.learn(j))
                TacticalJourney.REWARD:
                    var index := -1
                    for i in j.reward_options.size():
                        if j.reward_options[i]["kind"] in ["relic","held"]: index = i
                    if index < 0 and selected < 3:
                        index = 1
                        selected += 1
                    reason = j.choose_reward(index)
                    if j.step%16 == 1:
                        check(store.save(j).is_empty(),"Checkpoint mixed rewards to disk")
                        var resumed := store.load_journey()
                        check(resumed != null and JourneySnapshot.encode(resumed) == JourneySnapshot.encode(j),"File reload preserves selected reward and RNG")
                TacticalJourney.MAP: reason = j.enter_next()
                TacticalJourney.REST:
                    CampaignPolicy.camp(j)
                    if purchases < 3 and j.camp()["kind"] == "merchant":
                        for i in j.shop_cards().size():
                            var offer: Dictionary = j.shop_cards()[i]
                            var view := j.reward_view(offer)
                            var useful: bool = offer["key"] in ["guard","counter","potion_card","boost_card","ether_card","focus","analysis"] or (int(offer["owner_uid"]) != 0 and view.has("damage"))
                            if not useful or not j.shop_card_reason(i).is_empty(): continue
                            var purchase_gold := j.gold
                            var purchase_count := j.deck.size()
                            check(j.buy_shop_card(i).is_empty() and j.gold == purchase_gold-int(offer["price"]) and j.deck.size() == purchase_count+1,"Real campaign buys a useful quote for the exact price")
                            purchases += 1
                            j = reload(j)
                            break
                    if not j.held_inventory.is_empty(): j.equip_held(j.held_inventory[0],j.party[0].uid)
                    if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty(): j.resolve_camp(0)
                    if j.step%16 == 1: j = reload(j)
                    reason = j.leave_camp()
            if not reason.is_empty():
                check(false,"Public run action failed: "+reason)
                break
        print("DECK_RUN seed=",run_seed," phase=",j.phase," wins=",j.wins," relics=",j.relics.size()," deck=",j.deck.size()," purchases=",purchases," actions=",guard)
        check(purchases == 3,"Complete campaign purchases three finite shop cards through public actions")
        check(j.statistics["battles"].size() == 69 and RunStatistics.valid_run(j.statistics),"All encounters produce consistent, unique statistics across reloads")
        check(j.gold == 100+int(j.statistics["counts"]["gold_earned"])-RunStatistics.spent(j.statistics),"Recorded income and all spending reconcile to the final wallet")
        var measured_cards := 0
        for amount: int in j.statistics["cards"].values(): measured_cards += amount
        check(measured_cards == j.statistics["combat"]["cards_played"] and j.statistics["relics"].get("field_kit") == 69,"Per-card uses and party-wide relic triggers sum correctly")
        check(j.phase == TacticalJourney.CLEARED and j.wins == 69 and j.badges == 8 and j.elite_wins == 4,"69-battle run completes with mixed rewards, equipment and saved state")
    print("DECK_RUN: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
