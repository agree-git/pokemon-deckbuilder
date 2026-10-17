extends "../test_battle.gd"
## Rule fixtures isolate action ordering; campaign tests exercise normal rewards.
func reserve(b: TacticalBattle) -> void:
    for i in 8: b.draw_pile.append(BattleCardInstance.new(100+i,"guard",0))
func play(b: TacticalBattle, key: String) -> void:
    check(b.play_card(by_key(b,key)).is_empty(),"Legal synergy card: "+key)
func run() -> void:
    var b := fixture([["water_gun",7],["ember",4],["relay_cover",0]], ["relay_cell"])
    reserve(b)
    check(not b.card_view(b._hand(by_key(b,"relay_cover")))["condition_active"],"Relay condition starts inactive")
    var granted := b.turn_energy_bonus
    play(b,"water_gun")
    check(b.energy == 3 and b.turn_flags.has("relay_cell"),"First technique switch grants one relic energy")
    check(b.turn_energy_bonus == granted,"Relay energy is independent of the frozen speed bonus")
    play(b,"ember")
    check(b.energy == 2,"Further technique switches cannot farm relic energy")
    var view := b.card_view(b._hand(by_key(b,"relay_cover")))
    check(view["condition_active"] and view["description"].contains("(충족)"),"Relay condition and description update live")
    var count := b.hand.size()
    var shield := b.active().block
    play(b,"relay_cover")
    check(b.hand.size() == count+1 and b.active().block == shield+PokemonStats.scale(b.active(),6),"Relay cover shields and draws two after a technique switch")
    b.end_turn()
    check(not b.turn_flags.has("relay_cell") and not b.turn_flags.has("technique_switch"),"Relay triggers reset only at next player turn")
    b = fixture([["relay_cover",0],["water_gun",7]], ["relay_cell"])
    reserve(b)
    b.switch_to(7)
    check(not b.turn_flags.has("relay_cell") and not b.turn_flags.has("technique_switch"),"Manual switching does not activate technique rewards")
    count = b.hand.size()
    play(b,"relay_cover")
    check(b.hand.size() == count-1,"Unqualified cover still shields but draws nothing")
    b = fixture([["water_gun",7]], ["relay_cell"])
    b.energy = 0
    var before := b.snapshot()
    check(not b.play_card(1).is_empty() and b.snapshot() == before,"Relic energy cannot prepay an unaffordable switching technique")
    b = fixture([["tackle",4],["tackle",4],["ace_order",0]], ["ace_emblem"])
    reserve(b)
    play(b,"tackle")
    check(not b.turn_flags.has("ace_emblem") and not b.card_view(b._hand(by_key(b,"ace_order")))["condition_active"],"First technique alone cannot trigger the ace payoff")
    play(b,"tackle")
    check(b.turn_flags.has("ace_emblem") and b.hand.size() == 2,"Second technique by one member draws one card once")
    view = b.card_view(b._hand(by_key(b,"ace_order")))
    check(view["condition_active"],"Two techniques activate concentration order")
    count = b.hand.size()
    play(b,"ace_order")
    check(b.hand.size() == count+1 and b.next_attack_bonus == 5,"Ace order adds a next-attack bonus and two draws")
    b = fixture([["tackle",4],["water_gun",7],["ace_order",0]], ["ace_emblem"])
    play(b,"tackle")
    play(b,"water_gun")
    check(not b.turn_flags.has("ace_emblem") and not b.card_view(b._hand(by_key(b,"ace_order")))["condition_active"],"One technique each from different owners is not an ace chain")
    b = fixture([["status_plan",0],["toxic_flask",0],["seed",1]], ["status_flask","status_lens"])
    check(b.card_view(b._hand(by_key(b,"toxic_flask")))["description"].contains("독 4회"),"Status duration preview includes the unspent relic")
    play(b,"status_plan")
    play(b,"toxic_flask")
    check(b.enemy().statuses["poison"]["turns"] == 4 and b.energy == 2,"Duration and energy relics compose on the same poison card")
    check(b.powers.get("attrition") == 1 and b.exhausted.size() == 2,"Power and capsule both leave the draw cycle")
    play(b,"seed")
    check(b.enemy().statuses["seed"]["turns"] == 3,"Only the first qualifying card gets extended duration")
    var hp := b.enemy().hp
    b.end_turn()
    check(b.enemy().hp == hp-2*PokemonStats.scale(b.enemy(),3),"Attrition adds one scaled point to each poison/seed tick")
    check(b.enemy().statuses["poison"]["turns"] == 3 and b.enemy().statuses["seed"]["turns"] == 2,"Stronger ticks consume the usual one duration")
    b = fixture([["status_plan",0],["status_plan",0]])
    play(b,"status_plan")
    play(b,"status_plan")
    check(b.status_damage(b.enemy(),"burn") == PokemonStats.scale(b.enemy(),4),"Multiple attrition plans stack")
    check(b.status_damage(b.active(),"burn") == PokemonStats.scale(b.active(),2) and b.status_damage(b.enemy(),"confusion") == PokemonStats.scale(b.enemy(),2),"Attrition does not increase allied ailments or confusion")
    b = fixture([["move_147",4],["toxic_flask",0]], ["status_flask"])
    play(b,"move_147")
    check(not b.turn_flags.has("status_flask"),"Sleep cannot spend the DOT duration relic")
    play(b,"toxic_flask")
    check(b.enemy().statuses["poison"]["turns"] == 4,"Poison still gets extension after sleep")
    b = fixture([["shield_cell",0],["shield_strike",0],["rally",0]], ["tool_belt"])
    reserve(b)
    b.powers["supply"] = 1
    b.active().held_item = "guard_charm"
    shield = b.active().block
    play(b,"shield_cell")
    check(b.active().block == shield+PokemonStats.scale(b.active(),6)+PokemonStats.scale(b.active(),4)+PokemonStats.scale(b.active(),5),"Battery composes with held shield and supply power")
    check(b.turn_flags.has("tool_belt") and b.exhausted[0].key == "shield_cell","Battery counts as one exhausting tool for relics")
    play(b,"rally")
    shield = b.active().block
    b.enemy().block = 3
    hp = b.enemy().hp
    view = b.card_view(b._hand(by_key(b,"shield_strike")))
    check(view["preview_damage"] == shield,"Shield conversion previews the exact shield without attack or type modifiers")
    play(b,"shield_strike")
    check(b.active().block == 0 and b.enemy().hp == hp-maxi(0,shield-3),"Conversion consumes allied shield and respects enemy shield")
    check(b.next_attack_bonus == 7,"Conversion does not consume a technique attack bonus")
    check(b.events.any(func(e: Dictionary): return e["kind"] == "shield_spent" and e["frame"]["party"][0]["block"] == 0),"Conversion records shield loss before enemy damage")
    b = fixture([["shield_strike",0]])
    b.active().block = 0
    hp = b.enemy().hp
    play(b,"shield_strike")
    check(b.enemy().hp == hp,"Zero shield cannot create conversion damage")
    for key: String in ["relay_cover","ace_order","status_plan","shield_strike","toxic_flask","shield_cell"]:
        var card := BattleCardInstance.new(1,key,0)
        var original := TacticalContent.definition(card)
        check(TacticalContent.can_upgrade(card),"New card has a meaningful upgrade: "+key)
        card.upgraded = true
        view = TacticalContent.definition(card)
        check(original != view and not view["description"].is_empty(),"Upgrade and description resolve: "+key)
    boundary_checks()
    save_checks()
    reward_checks()
    print("BUILD_SYNERGIES: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func boundary_checks() -> void:
    var b := fixture([["water_gun",7],["tackle",7],["tackle",4],["tackle",4]], ["relay_cell","ace_emblem"])
    reserve(b)
    b.energy = 12
    play(b,"water_gun")
    play(b,"tackle")
    var count := b.hand.size()
    play(b,"tackle")
    play(b,"tackle")
    check(b.hand.size() == count-2,"A second party member cannot trigger the emblem again in the same turn")
    var flags := b.turn_flags.duplicate()
    var energy := b.energy
    var next := BattlePokemon.new(TacticalContent.ENEMIES[1],-2)
    PokemonStats.apply(next,true)
    b.enemies.append(next)
    b.enemy_definitions.append(TacticalContent.ENEMIES[1].duplicate(true))
    b.enemy_states.append({"intent":0})
    b._damage(b.enemy(),9999,true)
    b._outcome()
    check(b.enemy_index == 1 and b.turn_flags == flags and b.energy == energy,"Opponent replacement preserves the current turn's spent triggers")
    b.end_turn()
    check(not b.turn_flags.has("ace_emblem") and not b.turn_flags.has("relay_cell"),"New turn clears both relic limits")
    b = fixture([["guard",0]], ["relay_cell"])
    b._damage(b.active(),9999,true)
    b.phase = TacticalBattle.REPLACE
    b._pending = "player"
    check(b.switch_to(7).is_empty() and not b.turn_flags.has("relay_cell") and not b.turn_flags.has("technique_switch"),"Forced replacement does not count as a technique switch")
    b = fixture([["status_plan",0]])
    play(b,"status_plan")
    var members: Array[BattlePokemon] = b.party.duplicate()
    b.start_with(members,[],TacticalContent.ENEMIES,71,"field_kit")
    check(b.powers.is_empty() and b.turn_flags.is_empty(),"New combat removes powers and all turn conditions")
func save_checks() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.relics.append_array(["relay_cell","ace_emblem","status_flask"])
    j.deck.clear()
    for spec: Array in [["status_plan",0],["move_33",7],["move_33",7],["toxic_flask",0],["ace_order",0],["relay_cover",0]]:
        j.deck.append(BattleCardInstance.new(j.deck.size()+1,spec[0],spec[1]))
    j._next_card_uid = 7
    j.battle.start_with(j.party,j.deck,j.route.opponents(0),42,"field_kit",true,j.relics)
    j.battle.full_type_chart = true
    j.battle.hand.assign(j.deck)
    j.battle.draw_pile.clear()
    j.battle.energy = 20
    j.battle.play_card(1)
    j.battle.play_card(2)
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"New power and once-per-turn flags validate in an actual run snapshot")
    if not JourneySnapshot.validate(data): return
    var store := JourneySave.new("user://tests/build_synergies_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Write a checkpoint containing new cards, powers and trigger limits")
    var resumed := store.load_journey()
    check(resumed != null,"New content also loads through the real on-disk envelope")
    if resumed == null: return
    check(JourneySnapshot.encode(resumed) == data,"New content roundtrips without a ruleset reset")
    for uid in [3,4,5,6]:
        check(j.battle.play_card(uid).is_empty() and resumed.battle.play_card(uid).is_empty(),"Continue both copies with the same public action")
        check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Reload preserves condition checks, relic limits, duration and draw RNG")
    # Old v3 saves have no new powers or turn keys; both remain optional.
    j = TacticalJourney.new(42,"field_kit",[1,4,7],true)
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Untouched old-shape v3 runs remain valid")
func reward_checks() -> void:
    var deck: Array[BattleCardInstance] = [BattleCardInstance.new(1,"guard",0)]
    var acquired: Array[String] = ["relay_cell"]
    var related := TacticalContent.synergy_cards(deck,acquired)
    check(related.has("relay_cover") and not related.has("toxic_flask"),"Relay relic discovers relay support without implying unrelated builds")
    acquired.assign(["ace_emblem"])
    check(TacticalContent.synergy_cards(deck,acquired).has("ace_order"),"Ace relic discovers its payoff")
    acquired.clear()
    deck.append(BattleCardInstance.new(2,"move_92",1))
    check(TacticalContent.synergy_cards(deck,acquired).has("status_plan"),"Original learned status moves discover attrition support")
    deck.assign([BattleCardInstance.new(1,"shield_strike",0)])
    check(TacticalContent.synergy_cards(deck,acquired).has("shield_cell"),"Shield conversion discovers shield-generating tools")
    var j := TacticalJourney.new(42,"field_kit",[7],true)
    j.relics.append("relay_cell")
    related = TacticalContent.synergy_cards(j.deck,j.relics)
    var matched := 0
    var seen := {}
    for seed_value in 256:
        j.seed_value = seed_value # Reward-generator fixture; route is not advanced.
        j._prepare_rewards()
        var offers := j.reward_options.duplicate(true)
        j._prepare_rewards()
        check(j.reward_options == offers,"Reward candidates are seedable and do not reroll")
        var key: String = offers[0]["key"]
        if key in related: matched += 1
        for offer: Dictionary in offers:
            if offer["kind"] == "card" and offer["owner_uid"] == 0: seen[offer["key"]] = true
        check(offers[2]["kind"] != "card" or offers[2]["key"] != key,"Common-card options do not duplicate each other")
    check(matched > 120 and matched < 220,"Rewards favor the established build while still offering alternatives")
    for key: String in ["relay_cover","ace_order","status_plan","shield_strike","toxic_flask","shield_cell"]:
        check(seen.has(key),"New card is available through ordinary seeded battle rewards: "+key)
