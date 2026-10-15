extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture() -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] == "rest" and j.route.stops[i]["camp"]["kind"] == "merchant":
            j.phase = TacticalJourney.MAP
            j.step = i
            check(j.enter_next().is_empty(),"Enter a seeded merchant camp")
            return j
    check(false,"Fixture has a merchant")
    return j
func snapshot(j: TacticalJourney) -> Dictionary:
    return JourneySnapshot.encode(j)
func run() -> void:
    var j := fixture()
    check(j.shop_cards().size() == 3,"Merchant has three actual card offers")
    var quotes := j.shop_cards().duplicate(true)
    var before := snapshot(j)
    for i in 3: j.reward_view(j.shop_cards()[i])
    check(snapshot(j) == before,"Reading card faces/prices is pure and allocates no card UID")
    check(not j.buy_shop_card(-1).is_empty() and not j.buy_shop_card(3).is_empty() and snapshot(j) == before,"Invalid quote indices are atomic no-ops")
    j.gold = 0
    before = snapshot(j)
    check(not j.buy_shop_card(0).is_empty() and snapshot(j) == before,"Unaffordable purchases preserve money, stock, RNG and UIDs")
    j.gold = int(quotes[0]["price"])
    var deck_size := j.deck.size()
    var next_uid := j._next_card_uid
    check(j.buy_shop_card(0).is_empty(),"Exact-price purchase succeeds")
    check(j.gold == 0 and j.deck.size() == deck_size+1 and j.deck.back().uid == next_uid and j._next_card_uid == next_uid+1,"Purchase charges the quoted price and allocates one instance")
    check(j.deck.back().key == quotes[0]["key"] and j.shop_cards()[0]["sold"],"Bought card matches its preview and sells out")
    before = snapshot(j)
    check(not j.buy_shop_card(0).is_empty() and snapshot(j) == before,"Repeated purchase cannot duplicate a sold card")
    check(not j.remove_card_reason(j.deck[0].uid).is_empty() and not j.buy_reason("ball").is_empty(),"Spending all gold rules out removal and supplies")
    check(j.rest("upgrade",j.deck.back().uid).is_empty(),"Card purchase does not consume the camp's rest/upgrade action")
    check(j.deck.back().upgraded and j.step in j.rested_steps,"Newly bought card can use the one camp upgrade")
    j.gold = 500
    var owner := int(quotes[2]["owner_uid"])
    check(j.buy_shop_card(2).is_empty() and j.deck.back().owner_uid == owner and j.deck.back().key == quotes[2]["key"],"Technique purchase preserves the learned move and owner")
    check(j.shop_cards()[0]["sold"] and not j.shop_cards()[1]["sold"] and j.shop_cards()[2]["sold"],"Each offer has independent finite stock")
    var old_step := j.step
    j.phase = TacticalJourney.MAP
    j.enter_next()
    check(j.shop_cards()[0]["sold"] and j.shop_cards()[2]["sold"] and j.shop_cards()[1] == quotes[1],"Reentering cannot refill stock, replace quotes or reroll a sale")
    check(JourneySnapshot.validate(snapshot(j)),"Purchased, upgraded and owner-bound cards validate")
    var store := JourneySave.new("user://tests/merchant_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Write shop quotes, receipts and card identities to disk")
    var resumed := store.load_journey()
    check(resumed != null,"Read actual merchant checkpoint")
    if resumed != null:
        check(snapshot(resumed) == snapshot(j),"Disk reload preserves exact stock, price, deck and RNG")
        check(j.buy_shop_card(1).is_empty() and resumed.buy_shop_card(1).is_empty() and snapshot(j) == snapshot(resumed),"Resumed last purchase matches uninterrupted purchase")
        check(not resumed.buy_shop_card(0).is_empty(),"Reload never grants another sold copy")
    check(j.leave_camp().is_empty(),"Leave shop normally")
    before = snapshot(j)
    check(not j.buy_shop_card(0).is_empty() and snapshot(j) == before,"Stale shop inputs cannot purchase after departure")
    check(j.enter_next().is_empty() and j.phase == TacticalJourney.BATTLE,"Purchased deck proceeds into the next battle")
    var piles: Array = j.battle.hand+j.battle.draw_pile+j.battle.discard+j.battle.exhausted
    check(piles.size() == j.deck.size() and j.deck.all(func(c: BattleCardInstance): return c in piles),"Next battle contains every purchased card instance exactly once")
    check(j.camp_states[old_step]["card_offers"][0]["sold"],"Leaving preserves historical purchase receipts")
    generation_checks()
    compatibility_checks()
    print("MERCHANT_CARDS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func generation_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.relics.append("relay_cell")
    var themes := TacticalContent.synergy_cards(j.deck,j.relics)
    var seen := {}
    var sales := {}
    var rng_state := j.battle._rng.state
    for seed_value in 128:
        var offers := MerchantContent.generate(seed_value,3,0,j.deck,j.party,j.relics)
        check(offers == MerchantContent.generate(seed_value,3,0,j.deck,j.party,j.relics),"Shop generation is independently seeded")
        check(MerchantContent.valid_offers(offers,0),"Every sampled stock satisfies the saved quote schema")
        check(offers[0]["key"] in themes and offers[1]["key"] not in themes,"First offer supports the build; second explores another direction")
        check(offers[0]["key"] != offers[1]["key"],"Common slots do not duplicate each other")
        check(offers.filter(func(o: Dictionary): return o["sale"]).size() == 1,"Exactly one finite offer is discounted")
        for i in 3:
            seen[offers[i]["key"]] = true
            if offers[i]["sale"]: sales[i] = true
        var owner: BattlePokemon
        for member: BattlePokemon in j.party:
            if member.uid == offers[2]["owner_uid"]: owner = member
        check(owner != null and offers[2]["key"] in TacticalContent.skills_for(owner),"Technique stock belongs to a party member's actual learned moves")
    check(j.battle._rng.state == rng_state,"Generating shop stock never consumes battle RNG")
    check(sales.size() == 3 and seen.size() > 15,"Seeds vary discount slots and common stock")
    var common := TacticalContent.definition(BattleCardInstance.new(0,"guard",0))
    check(MerchantContent.list_price(common,0) == 60 and MerchantContent.list_price(common,8) == 100,"Common prices scale by five per region, bounded at league tier")
    var power := TacticalContent.definition(BattleCardInstance.new(0,"ace_plan",0))
    check(MerchantContent.list_price(power,0) == 90,"Persistent powers are priced above ordinary cards")
    var catalog := VisualCatalog.new()
    for id in range(1,387):
        var pokemon := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        TacticalGrowth.initialize(pokemon)
        var party: Array[BattlePokemon] = [pokemon]
        var offers := MerchantContent.generate(id,1,8,TacticalContent.starting_deck(party),party,[])
        check(MerchantContent.valid_offers(offers,8) and offers[2]["owner_uid"] == id,"Every Gen 1–3 starter can receive a legal technique quote")
func compatibility_checks() -> void:
    var j := fixture()
    var step := j.step
    var data := snapshot(j)
    for edit: Dictionary in [{"price":0},{"price":"free"},{"key":"missing"},{"key":"injury"},{"sold":1},{"sale":1},{"kind":4}]:
        var broken := data.duplicate(true)
        broken["run"]["camp_states"][step]["card_offers"][0].merge(edit,true)
        check(not JourneySnapshot.validate(broken),"Reject malformed or free quotes safely")
    var broken := data.duplicate(true)
    broken["run"]["camp_states"][step]["card_offers"].pop_back()
    check(not JourneySnapshot.validate(broken),"Reject incomplete stock")
    broken = data.duplicate(true)
    broken["run"]["camp_states"][step]["card_offers"][2]["owner_uid"] = 0
    check(not JourneySnapshot.validate(broken),"Reject an ownerless technique quote")
    # Historic owners may have left the party later; receipts must remain loadable.
    broken = data.duplicate(true)
    broken["run"]["camp_states"][step]["card_offers"][2]["owner_uid"] = 999999
    check(JourneySnapshot.validate(broken),"Historical quotes do not require a released Pokemon to remain in the save")
    data["run"]["camp_states"][step].erase("card_offers")
    check(JourneySnapshot.validate(data),"Existing v3 merchants without card stock remain compatible")
    var resumed := JourneySnapshot.restore(data)
    check(resumed.shop_cards().is_empty() and snapshot(resumed) == data,"Loading an old visited shop never silently rerolls inventory")
    var before := snapshot(resumed)
    check(not resumed.buy_shop_card(0).is_empty() and snapshot(resumed) == before,"Legacy supplies-only shop rejects absent card quotes")
    resumed.phase = TacticalJourney.MAP
    resumed.enter_next()
    check(resumed.shop_cards().is_empty(),"Reentry also preserves the legacy shop")
