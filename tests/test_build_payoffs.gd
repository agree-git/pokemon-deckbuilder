extends "res://tests/test_build_synergies.gd"
const NEW_CARDS := ["relay_retrieve","ace_finisher","status_pulse","shield_double"]
const NEW_RELICS := ["relay_cloak","ace_medal","status_dish","shield_battery"]
func run() -> void:
    retrieval_checks()
    finisher_checks()
    pulse_checks()
    relic_checks()
    block_limit_checks()
    persistence_checks()
    availability_checks()
    for key: String in NEW_CARDS:
        var card := BattleCardInstance.new(1,key,0)
        var original := TacticalContent.definition(card)
        check(TacticalContent.can_upgrade(card),"Payoff has an effective upgrade: "+key)
        card.upgraded = true
        var upgraded := TacticalContent.definition(card)
        check(upgraded.get("retrieve_count",0) == 3 if key == "relay_retrieve" else upgraded["cost"] == 0,"Upgrade matches published rule: "+key)
        check(not CardEffectText.render(original).contains("효과 없음") and not CardEffectText.render(upgraded).contains("효과 없음"),"Both faces describe their actions: "+key)
    print("BUILD_PAYOFFS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func retrieval_checks() -> void:
    var b := fixture([["relay_retrieve",0]])
    var old := BattleCardInstance.new(11,"water_gun",7)
    var active_card := BattleCardInstance.new(12,"ember",4)
    var recent := BattleCardInstance.new(13,"seed",1)
    recent.upgraded = true
    b.discard.assign([old,active_card,BattleCardInstance.new(14,"guard",0),recent])
    play(b,"relay_retrieve")
    check(b.hand == [recent,old] and recent.upgraded,"Recover the actual two most recent reserve techniques, preserving identity/upgrade")
    check(b.discard.size() == 2 and b.discard.has(active_card) and b.exhausted[0].key == "relay_retrieve","Recovery excludes active/common cards and exhausts itself")
    b = fixture([["relay_retrieve",0]])
    b.party[2].hp = 0
    b.discard.assign([old,active_card,recent])
    play(b,"relay_retrieve")
    check(b.hand == [recent] and b.discard.has(old),"Fainted owners cannot be recovered")
    b = fixture([["relay_retrieve",0]])
    for i in 9: b.hand.append(BattleCardInstance.new(30+i,"guard",0))
    b.discard.assign([old,recent])
    play(b,"relay_retrieve")
    check(b.hand.size() == 10 and b.hand.back() == recent and b.discard == [old],"Playing at ten cards frees just one slot; excess stays discarded")
    b = fixture([["relay_retrieve",0]])
    b.hand[0].upgraded = true
    b.discard.assign([old,recent,BattleCardInstance.new(15,"tackle",7)])
    play(b,"relay_retrieve")
    check(b.hand.size() == 3,"Upgraded recovery returns three reserve techniques")
    b = fixture([["relay_retrieve",0]])
    play(b,"relay_retrieve")
    check(b.hand.is_empty() and b.exhausted.size() == 1,"Empty discard is a legal, finite no-op")
func finisher_checks() -> void:
    var b := fixture([["ace_finisher",0],["ace_finisher",0],["growth",4],["tackle",4],["tackle",4]])
    b.energy = 20
    var baseline := int(b.card_view(b._hand(by_key(b,"tackle")))["preview_damage"])
    play(b,"ace_finisher")
    play(b,"ace_finisher")
    check(b.card_view(b._hand(by_key(b,"tackle")))["preview_damage"] == baseline*2,"Repeated finisher refreshes instead of multiplying repeatedly")
    play(b,"growth")
    check(b.turn_flags.get("finisher_4",false),"Non-damaging techniques do not consume finisher")
    var card := b._hand(by_key(b,"tackle"))
    var amount := int(b.card_view(card)["preview_damage"])
    var before := b.snapshot()
    var preview := BattleCardPreview.analyze(b,card.uid)
    check(b.snapshot() == before and preview["target_before"]["hp"]-preview["target_after"]["hp"] == amount,"Preview is pure and matches doubled damage")
    var hp := b.enemy().hp
    play(b,"tackle")
    check(b.enemy().hp == hp-amount and not b.turn_flags.has("finisher_4"),"Exactly one attacking technique consumes finisher")
    b = fixture([["ace_finisher",0],["water_gun",7],["tackle",4]])
    b.energy = 20
    play(b,"ace_finisher")
    var other_damage := int(b.card_view(b._hand(by_key(b,"water_gun")))["preview_damage"])
    hp = b.enemy().hp
    play(b,"water_gun")
    check(b.enemy().hp == hp-other_damage and b.turn_flags.get("finisher_4",false),"Another owner's technique cannot steal the pending attack")
    play(b,"tackle")
    check(not b.turn_flags.has("finisher_4"),"Returning to the marked owner can spend it this turn")
    b = fixture([["ace_finisher",0],["tackle",4]])
    b.full_type_chart = true
    b.enemy().types.assign(["ghost"])
    play(b,"ace_finisher")
    hp = b.enemy().hp
    check(b.card_view(b._hand(by_key(b,"tackle")))["preview_damage"] == 0,"Finisher preserves type immunity")
    play(b,"tackle")
    check(b.enemy().hp == hp and not b.turn_flags.has("finisher_4"),"Immune attack still spends the one-use marker")
    b = fixture([["ace_finisher",0]])
    play(b,"ace_finisher")
    b.end_turn()
    check(not b.turn_flags.has("finisher_4"),"Unused finisher expires at the next player turn")
func pulse_checks() -> void:
    var b := fixture([["status_pulse",0]], ["status_core","status_flask"])
    b.powers["attrition"] = 1
    b.enemy().statuses = {"burn":{"turns":2,"source_uid":4},"seed":{"turns":3,"source_uid":1},"poison":{"turns":4,"source_uid":4},"sleep":{"turns":2,"source_uid":4}}
    b.member(1).hp = maxi(1,floori(b.member(1).max_hp*0.5))
    b.enemy().block = 50
    var durations := b.enemy().statuses.duplicate(true)
    var tick := b.status_damage(b.enemy(),"burn")
    var own_hp := b.member(1).hp
    var hp := b.enemy().hp
    var before := b.snapshot()
    var preview := BattleCardPreview.analyze(b,1)
    check(b.snapshot() == before and preview["target_after"]["hp"] == hp-3*tick,"Pulse preview includes attrition/core damage without touching live state")
    play(b,"status_pulse")
    check(b.enemy().hp == hp-3*tick and b.enemy().block == 50,"Pulse triggers each DOT once and bypasses shields")
    check(b.enemy().statuses == durations and not b.turn_flags.has("status_flask"),"Pulse preserves all durations and is not a new status application")
    check(b.member(1).hp == mini(b.member(1).max_hp,own_hp+tick),"Immediate seed heals its actual living source")
    b = fixture([["status_pulse",0]], ["seed_relay"])
    var next := BattlePokemon.new(TacticalContent.ENEMIES[1],-2)
    PokemonStats.apply(next,true)
    b.enemies.append(next)
    b.enemy_definitions.append(TacticalContent.ENEMIES[1].duplicate(true))
    b.enemy_states.append({"intent":0})
    b.enemy().hp = 1
    b.enemy().statuses = {"burn":{"turns":2,"source_uid":4},"seed":{"turns":3,"source_uid":1},"poison":{"turns":4,"source_uid":4}}
    hp = next.hp
    play(b,"status_pulse")
    check(b.enemy_index == 1 and next.hp == hp and next.statuses.has("seed"),"Pulse stops at the original target's KO; no spillover into the replacement")
    b = fixture([["status_pulse",0]])
    b.member(1).hp = 0
    b.enemy().statuses["seed"] = {"turns":1,"source_uid":1}
    play(b,"status_pulse")
    check(b.member(1).hp == 0,"Seed pulse cannot revive a fainted source")
    b = fixture([["status_pulse",0]])
    hp = b.enemy().hp
    play(b,"status_pulse")
    check(b.enemy().hp == hp and b.exhausted.size() == 1,"No ailments means no invented pulse damage")
func relic_checks() -> void:
    var b := fixture([["water_gun",7],["ember",4]],["relay_cloak","relay_cell","relay_core"])
    b.active().block = 17
    var old_new := b.member(7).block
    play(b,"water_gun")
    check(b.member(4).block == 0 and b.member(7).block == old_new+17,"First technique switch moves, rather than copies, outgoing shield")
    check(b.turn_flags.has("relay_cell") and b.turn_flags.has("relay_core"),"Mantle composes with existing switch triggers")
    play(b,"ember")
    check(b.member(7).block == old_new+17 and b.member(4).block == 0,"More switches cannot transfer the mantle repeatedly")
    b = fixture([["water_gun",7]],["relay_cloak"])
    b.switch_to(1)
    check(not b.turn_flags.has("relay_cloak"),"Manual switching cannot spend the mantle")
    b.active().block = 0
    play(b,"water_gun")
    check(b.turn_flags.has("relay_cloak"),"The first technique switch spends the mantle even with zero shield")
    b = fixture([["tackle",4],["tackle",4],["tackle",4],["tackle",4]],["ace_medal"])
    b.energy = 10
    play(b,"tackle")
    play(b,"tackle")
    check(not b.turn_flags.has("ace_medal") and b.energy == 8,"Medal waits for three techniques by one owner")
    play(b,"tackle")
    check(b.turn_flags.has("ace_medal") and b.energy == 8,"Third technique refunds one energy after payment")
    play(b,"tackle")
    check(b.energy == 7,"Fourth technique cannot repeat the refund")
    b = fixture([["toxic_flask",0],["toxic_flask",0],["seed",1]],["status_dish"])
    reserve(b)
    play(b,"toxic_flask")
    play(b,"toxic_flask")
    check(not b.turn_flags.has("status_dish"),"Reapplying one ailment is not a second distinct DOT")
    var count := b.hand.size()
    play(b,"seed")
    check(b.turn_flags.has("status_dish") and b.hand.size() == count+1,"Second distinct DOT draws two, once for the party")
    b = fixture([["shield_double",0]],["shield_battery"])
    b.active().held_item = "guard_charm"
    b.active().block = 20
    play(b,"shield_double")
    check(b.active().block == 40,"Compression doubles current shield without another held-item flat bonus")
    b.end_turn()
    check(b.energy == 4+b.turn_energy_bonus and int(b.statistics["relics"].get("shield_battery",0)) == 1,"Full guard awards precisely one extra energy next turn, alongside speed")
    check(not b.turn_flags.has("shield_battery"),"Delivered charge is cleared at turn start")
    b = fixture([["shield_double",0]],["shield_battery"])
    b.active().block = 0
    play(b,"shield_double")
    check(b.active().block == 0,"Compression cannot create shield from zero")
    b.end_turn()
    check(b.energy == 3+b.turn_energy_bonus,"Unblocked damage cannot charge energy")
    b = fixture([],["shield_battery"])
    b.phase = "enemy"
    b.active().block = 100
    b._damage(b.active(),0)
    check(not b.turn_flags.has("shield_battery"),"Zero-power attack is not a successful shield absorption")
    b._damage(b.active(),1,true)
    check(not b.turn_flags.has("shield_battery"),"Piercing DOT cannot charge the battery")
    b._damage(b.active(),2)
    b._damage(b.active(),2)
    b._start_player()
    check(b.energy == 4+b.turn_energy_bonus,"Multiple fully blocked hits still charge once")
func block_limit_checks() -> void:
    var b := fixture([["shield_double",0],["guard",0],["water_gun",7]],["relay_cloak"])
    b.energy = 10
    b.active().block = 75000
    b.member(7).block = 99000
    var shell := BattleCardInstance.new(90,"shell",7)
    b.hand.append(shell)
    check(b.card_view(b.hand[0])["preview_block_gain"] == 25000 and b.card_view(shell)["preview_block"] == 0,"Shield previews respect the save bound including imminent mantle transfer")
    play(b,"shield_double")
    check(b.active().block == TacticalBattle.MAX_BLOCK and b.events.any(func(e: Dictionary): return e["kind"] == "shield" and e["amount"] == 25000),"Compression saturates safely and records only actual gain")
    play(b,"guard")
    check(b.active().block == TacticalBattle.MAX_BLOCK,"Subsequent shield cards cannot exceed the v3 storage bound")
    b.member(7).block = 99000
    play(b,"water_gun")
    check(b.member(7).block == TacticalBattle.MAX_BLOCK and b.member(4).block == 0,"Mantle transfer also saturates rather than invalidating saves")
func persistence_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[4,1,7],true)
    j.relics.append_array(NEW_RELICS)
    j.deck.clear()
    for spec: Array in [["ace_finisher",0],["move_10",4],["move_10",4],["move_10",4],["relay_retrieve",0],["status_pulse",0],["shield_double",0]]:
        j.deck.append(BattleCardInstance.new(j.deck.size()+1,spec[0],spec[1]))
    j._next_card_uid = 8
    j.battle.start_with(j.party,j.deck,j.route.opponents(0),42,"field_kit",true,j.relics)
    j.battle.hand.assign(j.deck)
    j.battle.draw_pile.clear()
    j.battle.energy = 20
    j.battle.enemy().block = 500
    j.battle.play_card(1)
    j.battle.turn_flags["shield_battery"] = true
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"New IDs and pending per-owner/energy flags validate in v3")
    var store := JourneySave.new("user://tests/build_payoffs/journey.json")
    check(store.save(j).is_empty(),"Save new payoff content through the real disk envelope")
    var resumed := store.load_journey()
    check(resumed != null,"Reload new payoff checkpoint")
    if resumed == null: return
    check(JourneySnapshot.encode(resumed) == data,"Reload preserves exact identities, pending markers and RNG")
    for uid in [2,3,4,5,6,7]:
        check(j.battle.play_card(uid).is_empty() and resumed.battle.play_card(uid).is_empty(),"Continue new cards in both timelines")
        check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Resumed payoff result matches uninterrupted play")
    j.battle.end_turn()
    resumed.battle.end_turn()
    check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Pending charge and turn limits survive reload then reset identically")
    check(JourneySnapshot.validate(JourneySnapshot.encode(TacticalJourney.new(42,"field_kit",[1,4,7],true))),"Existing v3 shape needs no migration or reset")
func availability_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.step = 12 # Actual veteran stage: guaranteed ordinary relic slot.
    var cards := {}
    var relics := {}
    var shop := {}
    for seed_value in 192:
        j.seed_value = seed_value
        j._prepare_rewards()
        for offer: Dictionary in j.reward_options:
            if offer["kind"] == "card" and offer["owner_uid"] == 0: cards[offer["key"]] = true
            if offer["kind"] == "relic": relics[offer["key"]] = true
        var offers := MerchantContent.generate(seed_value,3,0,j.deck,j.party,j.relics)
        for offer: Dictionary in offers:
            if offer["owner_uid"] == 0: shop[offer["key"]] = true
    for key: String in NEW_CARDS: check(cards.has(key) and shop.has(key),"New card is reachable through ordinary reward and merchant pools: "+key)
    for key: String in NEW_RELICS: check(relics.has(key),"New relic is reachable through ordinary rewards: "+key)
    for pair: Array in [["relay_cloak","relay_retrieve"],["ace_medal","ace_finisher"],["status_dish","status_pulse"],["shield_battery","shield_double"]]:
        var acquired: Array[String] = [pair[0]]
        check(TacticalContent.synergy_cards(j.deck,acquired).has(pair[1]),"Existing build discovery includes the new payoff")
