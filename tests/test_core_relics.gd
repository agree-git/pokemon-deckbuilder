extends "res://tests/test_build_synergies.gd"
func effects() -> void:
    for core: String in CoreRelics.KEYS:
        var j := TacticalJourney.new(42,core,[1,4,7],true)
        check(j.battle.hand.size() == (4 if core in ["relay_core","supply_core"] else 5),"Opening draw applies the core's exact tradeoff: "+core)
        check(j.battle.energy == 3+j.battle.turn_energy_bonus,"Cores do not change the speed energy rule")
    var b := fixture([["water_gun",7],["ember",4]], ["relay_core"])
    reserve(b)
    var count := b.hand.size()
    play(b,"water_gun")
    check(b.hand.size() == count+1 and b.turn_flags.has("relay_core") and b.statistics["relics"]["relay_core"] == 1,"First automatic switch draws two and records one activation")
    count = b.hand.size()
    play(b,"ember")
    check(b.hand.size() == count-1 and b.statistics["relics"]["relay_core"] == 1,"Further automatic switches cannot repeat the draw")
    b.end_turn()
    check(not b.turn_flags.has("relay_core") and b.hand.size() == 4,"Next turn resets the trigger and draws only four")
    b = fixture([["water_gun",7]], ["relay_core"])
    reserve(b)
    b.switch_to(7)
    check(not b.turn_flags.has("relay_core") and b.draw_pile.size() == 8,"Manual switching grants no core draw")
    b = fixture([["tackle",4],["tackle",4],["water_gun",7]], ["ace_core"])
    b.energy = 0
    check(b.card_view(b.hand[0])["cost"] == 0 and b.card_view(b.hand[2])["cost"] == 1,"Only the turn-start owner's first technique gets a discount")
    var snapshot := b.snapshot()
    b.card_view(b.hand[0])
    check(b.snapshot() == snapshot,"Discount preview cannot consume the benefit")
    play(b,"tackle")
    check(b.energy == 0 and b.card_view(b.hand[0])["cost"] == 1 and b.turn_flags.has("ace_core"),"The discounted card really costs zero and consumes this turn's benefit")
    snapshot = b.snapshot()
    check(not b.play_card(b.hand[0].uid).is_empty() and b.snapshot() == snapshot,"A second technique cannot reuse the discount")
    b.energy = 1
    snapshot = b.snapshot()
    check(not b.switch_to(7).is_empty() and b.snapshot() == snapshot,"Manual switching cannot bypass the two-energy cost")
    b.energy = 2
    check(b.switch_to(7).is_empty() and b.energy == 0,"Manual switch pays exactly two")
    check(b.card_view(b.hand[1])["cost"] == 1,"Switching does not reroll the frozen discount owner")
    b.phase = TacticalBattle.REPLACE
    var spent: int = b.statistics["counts"]["energy_spent"]
    check(b.switch_to(1).is_empty() and b.statistics["counts"]["energy_spent"] == spent and b.energy == 3+b.turn_energy_bonus,"Forced switching spends nothing and grants only the actual next turn's energy")
    b = fixture([["growth",4],["tackle",4]], ["ace_core"])
    play(b,"growth")
    check(b.card_view(b.hand[0])["cost"] == 1 and not b.statistics["relics"].has("ace_core"),"A zero-cost first technique consumes its slot without inventing energy savings")
    b = fixture([["ember",4]], ["status_core"])
    var ordinary := fixture([["ember",4]])
    var view := b.card_view(b.hand[0])
    var base := ordinary.attack_damage(ordinary.card_view(ordinary.hand[0]),ordinary.active())
    check(view["preview_damage"] == maxi(1,floori(base*0.8)),"Direct technique damage shows the -20% penalty")
    var hp := b.enemy().hp
    play(b,"ember")
    check(b.enemy().hp == hp-int(view["preview_damage"]),"The displayed penalty equals applied damage")
    check(b.status_damage(b.enemy(),"burn") == floori(PokemonStats.scale(b.enemy(),2)*1.5),"Enemy damage-over-time gains fifty percent")
    check(b.status_damage(b.active(),"burn") == PokemonStats.scale(b.active(),2) and b.status_damage(b.enemy(),"confusion") == PokemonStats.scale(b.enemy(),2),"Allied ailments and confusion keep normal damage")
    b.enemy().statuses["poison"] = {"turns":2,"source_uid":4}
    hp = b.enemy().hp
    b.end_turn()
    check(hp-b.enemy().hp == 2*floori(PokemonStats.scale(b.enemy(),2)*1.5),"Actual burn and poison ticks both apply the bonus")
    b.powers["attrition"] = 2
    check(b.status_damage(b.enemy(),"burn") == floori(PokemonStats.scale(b.enemy(),4)*1.5),"The catalyst composes with attrition before rounding")
    b = fixture([["move_84",4]], ["status_core"])
    b.full_type_chart = true
    b.enemy().types.assign(["ground"])
    check(b.card_view(b.hand[0])["preview_damage"] == 0,"The direct damage penalty never bypasses type immunity")
    b = fixture([["potion_card",0]], ["shield_core"])
    b.active().hp = 1
    view = b.card_view(b.hand[0])
    var expected := maxi(1,floori(PokemonStats.scale(b.active(),16)*0.5))
    check(view["preview_heal"] == expected,"Recovery preview includes the halved card healing")
    play(b,"potion_card")
    check(b.active().hp == 1+expected,"Actual recovery matches the reduced preview")
    b.active().block = 11
    b.party[1].block = 5
    b.enemy().statuses["sleep"] = {"turns":2,"source_uid":4}
    b.end_turn()
    check(b.active().block == 5 and b.party[1].block == 2,"Each living ally retains half its remaining shield, rounded down")
    b = fixture([["potion_card",0],["boost_card",0]], ["supply_core","tool_belt"])
    reserve(b)
    b.active().hp = 1
    count = b.hand.size()
    play(b,"potion_card")
    check(b.energy == 3 and b.hand.size() == count+2 and b.statistics["relics"]["supply_core"] == 1,"First exhaust tool refunds one energy and draws two, composing with the ordinary tool relic")
    count = b.hand.size()
    play(b,"boost_card")
    check(b.energy == 3 and b.hand.size() == count-1 and b.statistics["relics"]["supply_core"] == 1,"Second tool cannot repeat the bonus")
    b = fixture([["focus",0],["potion_card",0]], ["supply_core"])
    reserve(b)
    play(b,"focus")
    check(not b.turn_flags.has("supply_core"),"Exhausting a trainer is not a tool trigger")
    b.energy = 0
    snapshot = b.snapshot()
    check(not b.play_card(by_key(b,"potion_card")).is_empty() and b.snapshot() == snapshot,"Supply energy cannot prepay an unaffordable tool")
func rewards_and_saves() -> void:
    var seen := {}
    for seed_value in 40:
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        j.step = 14 # First gym reward boundary; growth/combat tested separately.
        j.battle.phase = TacticalBattle.WON
        j._settled = j.battle
        j._prepare_rewards()
        check(j.reward_options.size() == 3 and j.reward_options.all(func(o: Dictionary): return o["key"] in CoreRelics.KEYS),"First gym offers three core relics")
        var choices := {}
        for option: Dictionary in j.reward_options:
            choices[option["key"]] = true
            seen[option["key"]] = true
        check(choices.size() == 3,"Core choices never duplicate")
        var graph := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(graph) and JourneySnapshot.encode(JourneySnapshot.restore(graph)) == graph,"Unchosen alternatives restore without rerolling")
        var key: String = j.reward_options[0]["key"]
        check(j.choose_reward(0).is_empty() and CoreRelics.selected(j.relics) == key and CoreRelics.valid(j.relics),"Choosing grants exactly one core")
        j.step = 30
        j._prepare_rewards()
        check(j.reward_options.all(func(o: Dictionary): return o["key"] not in CoreRelics.KEYS),"Later rewards cannot grant another core")
        j.reward_options[0] = {"kind":"relic","key":"status_core" if key != "status_core" else "ace_core"}
        graph = JourneySnapshot.encode(j)
        check(not j.choose_reward(0).is_empty() and JourneySnapshot.encode(j) == graph,"A forged second-core choice is atomic")
        check(not JourneySnapshot.validate(graph),"Save validation rejects a second core offer")
    check(seen.size() == 5,"Every core appears across seeded offers")
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.step = 14
    j._prepare_rewards()
    check(j.choose_reward(-1).is_empty() and CoreRelics.selected(j.relics).is_empty(),"Skipping never chooses a random core")
    j.step = 30
    j._prepare_rewards()
    check(j.reward_options.all(func(o: Dictionary): return o["key"] in CoreRelics.KEYS),"The next gym offers a choice again after skipping")
    # Compatible pre-core gym reward: keep the already displayed alternatives.
    j = TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.step = 14
    j.phase = TacticalJourney.REWARD
    j.battle.phase = TacticalBattle.WON
    j._settled = j.battle
    j.reward_options.assign([{"kind":"card","key":"guard","owner_uid":0,"upgraded":false},{"kind":"card","key":"move_33","owner_uid":1,"upgraded":true},{"kind":"relic","key":"ace_focus"}])
    var legacy := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(legacy),"An ordinary gym reward from before core relics remains valid")
    var resumed := JourneySnapshot.restore(legacy)
    check(JourneySnapshot.encode(resumed) == legacy,"Loading does not replace saved rewards with core alternatives")
    resumed.choose_reward(2)
    resumed.step = 30
    resumed._prepare_rewards()
    check(resumed.reward_options.all(func(o: Dictionary): return o["key"] in CoreRelics.KEYS),"An existing run without a core receives its choice at the next gym")
    for core: String in CoreRelics.KEYS:
        j = TacticalJourney.new(42,core,[1,4,7],true)
        for c: BattleCardInstance in j.battle.hand:
            if c.owner_uid != 0 and j.battle.card_reason(c.uid).is_empty():
                j.battle.play_card(c.uid)
                break
        var graph := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(graph),"Core combat snapshot validates: "+core)
        var store := JourneySave.new("user://tests/core_%d_%s.json" % [Time.get_ticks_usec(),core])
        check(store.save(j).is_empty(),"Core writes through the real save API")
        var copy := store.load_journey()
        check(copy != null and JourneySnapshot.encode(copy) == graph,"Core, frozen speed owner, piles and spent benefit restore exactly")
        if copy != null:
            j.battle.end_turn()
            copy.battle.end_turn()
            check(JourneySnapshot.encode(j) == JourneySnapshot.encode(copy),"Resumed core next turn matches uninterrupted play")
        graph["run"]["relics"].append("status_core" if core != "status_core" else "ace_core")
        check(not JourneySnapshot.validate(graph),"Save cannot stack two core relics")
func run() -> void:
    effects()
    rewards_and_saves()
    print("CORE_RELICS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
