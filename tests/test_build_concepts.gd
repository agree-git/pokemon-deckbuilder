extends "res://tests/test_build_synergies.gd"
func keys() -> Array[String]:
    var result: Array[String] = []
    for group: Array in BuildConceptContent.GROUPS.values(): result.append_array(group)
    return result
func relics() -> Array[String]:
    var result: Array[String] = []
    for group: Array in BuildConceptContent.RELICS.values(): result.append_array(group)
    return result
func safe(b: TacticalBattle) -> void:
    b.energy = 50
    b.enemy_definitions[0]["intents"] = [{"kind":"block","value":0,"move_id":115}]
    reserve(b)
func run() -> void:
    card_checks()
    relay_checks()
    ace_checks()
    status_checks()
    shield_checks()
    supply_checks()
    cycle_checks()
    save_checks_new()
    availability_checks_new()
    print("BUILD_CONCEPTS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func card_checks() -> void:
    check(keys().size() == 24 and relics().size() == 12,"Six complete concept sets contain 24 cards and 12 ordinary relics")
    for key: String in keys():
        for upgraded: bool in [false,true]:
            var b := fixture([[key,0],["tackle",4],["water_gun",7]],relics())
            safe(b)
            b.hand[0].upgraded = upgraded
            b.active().hp = maxi(1,b.active().hp-5)
            b.active().block = 8
            b.enemy().statuses = {"burn":{"turns":2,"source_uid":4},"poison":{"turns":2,"source_uid":4}}
            b.discard.assign([BattleCardInstance.new(81,"tackle",4),BattleCardInstance.new(82,"water_gun",7)])
            b.exhausted.assign([BattleCardInstance.new(83,"shield_cell",0)])
            b.turn_flags = {"technique_switch":true,"double_technique_4":true,"reshuffled":true}
            b.turn_actors.assign([4,7])
            var c := b.hand[0]
            var view := b.card_view(c)
            check(TacticalContent.can_upgrade(c) if not upgraded else not TacticalContent.can_upgrade(c),"Each published upgrade changes its intended fields: "+key)
            var before := b.snapshot()
            var preview := BattleCardPreview.analyze(b,c.uid)
            check(b.snapshot() == before and preview == BattleCardPreview.analyze(b,c.uid),"New preview is pure and deterministic: "+key)
            check(b.play_card(c.uid).is_empty(),"Base/upgraded concept card is playable: "+key)
            check(preview["actor_after"] == BattleFrame.member(b.active()) and preview["target_after"] == BattleFrame.member(b.enemy()) and preview["energy_after"] == b.energy,"Actual HP/shield/resource results match preview: "+key)
            check(not view["description"].is_empty() and not CardEffectText.render(view).contains("효과 없음"),"Face and full tooltip describe effect: "+key)
func relay_checks() -> void:
    var b := fixture([["relay_formation",0]])
    b.member(1).hp = 0
    b.active().held_item = "guard_charm"
    var original := b.active().block
    play(b,"relay_formation")
    check(b.active().block == original+PokemonStats.scale(b.active(),4) and b.member(1).block == PokemonStats.scale(b.member(1),5),"Party shield skips fainted members and held flat bonuses")
    b = fixture([["relay_accelerate",0]])
    reserve(b)
    play(b,"relay_accelerate")
    check(b.energy == 3 and b.hand.size() == 1,"Unqualified relay accelerator draws but cannot refund energy")
    b = fixture([["relay_cycle_plan",0],["water_gun",7],["ember",4],["relay_command",0]],["relay_signal"])
    safe(b)
    play(b,"relay_cycle_plan")
    var count := b.hand.size()
    play(b,"water_gun")
    check(b.hand.size() == count and b.turn_flags.has("relay_cycle"),"First automatic switch draws one from installed cycle plan")
    count = b.hand.size()
    play(b,"ember")
    check(b.hand.size() == count and b.turn_flags.has("relay_signal"),"Two distinct technique owners trigger the signal once")
    play(b,"relay_command")
    check(b.next_attack_bonus == 8,"Team command counts distinct owners once each")
    b = fixture([], ["manual_pin","ace_core"])
    check(b.manual_switch_cost() == 1,"Pin reduces core manual penalty by one")
    b.switch_to(7)
    check(b.energy == 2 and b.manual_switch_cost() == 2,"First manual switch spends the discount exactly once")
    b.phase = TacticalBattle.REPLACE
    b.turn_flags.erase("manual_pin")
    b._pending = "player"
    b.switch_to(1)
    check(not b.turn_flags.has("manual_pin"),"Forced switch cannot consume next turn's manual discount")
func ace_checks() -> void:
    var b := fixture([["ace_retrieve",0]])
    var own := BattleCardInstance.new(21,"tackle",4)
    var other := BattleCardInstance.new(22,"water_gun",7)
    b.discard.assign([own,other])
    play(b,"ace_retrieve")
    check(b.hand == [own] and b.discard == [other],"Dedicated retrieve returns only active-owner instances")
    b = fixture([["ace_precision",0]])
    b.turn_flags["double_technique_4"] = true
    play(b,"ace_precision")
    check(b.next_attack_bonus == 10,"Qualified precision adds both base and conditional next-attack units")
    b = fixture([["ace_reserve",0],["ace_reserve",0]],["ace_calm"])
    safe(b)
    b.hand[1].upgraded = true
    play(b,"ace_reserve")
    play(b,"ace_reserve")
    b.end_turn()
    check(b.energy == 6+b.turn_energy_bonus and not b.powers.has("energy_bank"),"Three banked energy applies once alongside speed")
    check(b.hand.size() == 6,"Stayed ace draws one after normal turn draw")
    b.end_turn()
    check(b.energy == 3+b.turn_energy_bonus,"Spent reserve does not regenerate on later turns")
    b = fixture([["ace_breathing",0],["growth",4],["tackle",4]])
    safe(b)
    play(b,"ace_breathing")
    var original := b.active().block
    play(b,"growth")
    play(b,"tackle")
    check(b.active().block == original+PokemonStats.scale(b.active(),5),"Ace guard uses only pinned owner's first technique, including non-attacks")
    b = fixture([["tackle",4],["tackle",4]],["ace_sight"])
    var plain := BattleCardPreview.copy_battle(b)
    plain.relics.erase("ace_sight")
    var damage := int(plain.card_view(plain.hand[0])["preview_damage"])
    check(b.card_view(b.hand[0])["preview_damage"] == maxi(1,floori(damage*1.25)),"Sight preview multiplies final first-hit damage")
    play(b,"tackle")
    check(b.turn_flags.has("ace_sight") and b.card_view(b.hand[0])["preview_damage"] == damage,"Further attacks cannot reuse the sight")
    b.energy = 0
    var before := b.snapshot()
    check(not b.play_card(b.hand[0].uid).is_empty() and b.snapshot() == before,"Later triggers cannot prepay an unaffordable attack")
func status_checks() -> void:
    var b := fixture([["status_catalyst",0]],["status_flask","status_dish"])
    b.enemy().statuses = {"burn":{"turns":100,"source_uid":4},"poison":{"turns":2,"source_uid":4},"sleep":{"turns":2,"source_uid":4}}
    play(b,"status_catalyst")
    check(b.enemy().statuses["burn"]["turns"] == 100 and b.enemy().statuses["poison"]["turns"] == 3 and b.enemy().statuses["sleep"]["turns"] == 2,"Duration extension respects stored bound and DOT-only selection")
    check(not b.turn_flags.has("status_flask") and not b.turn_flags.has("status_dish"),"Extending existing DOT is not new status application")
    b = fixture([["status_analysis",0]])
    reserve(b)
    b.enemy().statuses = {"burn":{"turns":1,"source_uid":4},"poison":{"turns":1,"source_uid":4}}
    play(b,"status_analysis")
    check(b.hand.size() == 3,"Two DOT kinds qualify analysis before use")
    b = fixture([["status_absorption",0],["status_pulse",0]],["status_ember","status_vial"])
    safe(b)
    b.active().hp = 1
    b.enemy().statuses = {"burn":{"turns":1,"source_uid":4},"poison":{"turns":1,"source_uid":4}}
    play(b,"status_absorption")
    play(b,"status_pulse")
    check(b.active().hp == 1+PokemonStats.scale(b.active(),2) and b.next_attack_bonus == 3,"Immediate positive DOT activates absorption and residue once")
    check(not b.turn_flags.has("status_vial"),"Immediate pulse cannot consume a natural expiration payoff")
    b._tick(b.enemy())
    check(b.turn_flags.has("status_vial") and b.hand.size() == 1,"Only natural expiration draws the vial card once")
func shield_checks() -> void:
    var b := fixture([["shield_lock",0]])
    safe(b)
    b.active().block = 60
    play(b,"shield_lock")
    b.end_turn()
    check(b.active().block == 60 and not b.turn_flags.has("keep_block_4"),"Pinned shield persists fully for exactly one turn boundary")
    b.end_turn()
    check(b.active().block == 0,"No permanent free shield retention remains")
    b = fixture([["shield_regroup",0]])
    reserve(b)
    b.active().block = 0
    play(b,"shield_regroup")
    check(b.hand.is_empty(),"Self-granted shield cannot retroactively satisfy the before-use condition")
    b = fixture([["guard",0],["guard",0]],["shield_pad"])
    var original := b.active().block
    var amount := int(b.card_view(b.hand[0])["preview_block"])
    play(b,"guard")
    check(b.active().block == original+amount and b.turn_flags.has("shield_pad"),"Pad live preview matches first card's actual extra shield")
    check(b.card_view(b.hand[0])["preview_block"] == PokemonStats.scale(b.active(),8),"Further shield cards cannot reuse pad")
    b = fixture([["shield_fortress",0]],["shield_badge"])
    safe(b)
    play(b,"shield_fortress")
    var old := b.active().block
    BuildConceptRules.end_turn(b)
    check(b.active().block == old+PokemonStats.scale(b.active(),6),"Fortress grants only the finishing member's turn-end shield")
    b.hand.clear()
    b.phase = "enemy"
    b.active().block = 100
    b._damage(b.active(),0)
    check(not b.turn_flags.has("shield_badge"),"Zero damage cannot charge the bulwark badge")
    b._damage(b.active(),1)
    b._damage(b.active(),1)
    b._start_player()
    check(b.hand.size() == 6 and not b.turn_flags.has("shield_badge"),"Multiple full guards add just one next-turn draw")
func supply_checks() -> void:
    var b := fixture([["supply_recycle",0]])
    var tool := BattleCardInstance.new(31,"ether_card",0)
    tool.upgraded = true
    var trainer := BattleCardInstance.new(32,"focus",0)
    b.exhausted.assign([tool,trainer])
    play(b,"supply_recycle")
    check(b.hand == [tool] and b.hand[0].upgraded and b.exhausted.has(trainer),"Recycling returns the actual latest tool and never an exhausting trainer")
    b = fixture([["ether_card",0],["supply_pack",0]],["tool_discount"])
    b.energy = 0
    play(b,"ether_card")
    check(b.turn_flags.has("tool_discount") and b.card_view(b.hand[0])["cost"] == 1,"A zero-cost first tool still spends precision tools")
    b = fixture([["supply_assembly",0],["supply_pack",0],["shield_cell",0]],["tool_pouch","supply_core"])
    safe(b)
    b.active().hp = 1
    play(b,"supply_assembly")
    play(b,"supply_pack")
    check(b.next_attack_bonus == 4 and b.turn_flags.has("tool_bonus") and b.turn_flags.has("tool_pouch") and b.turn_flags.has("supply_core"),"Assembly, first-tool healing and core all compose")
    play(b,"shield_cell")
    check(b.next_attack_bonus == 4,"Second exhausting tool cannot farm assembly")
func cycle_checks() -> void:
    var b := fixture([["cycle_filter",0],["tackle",4],["ether_card",0],["hold",0]])
    reserve(b)
    var target := b.hand[2]
    b.retained.assign([target.uid])
    play(b,"cycle_filter")
    check(b.discard.has(target) and not b.retained.has(target.uid) and b.hand.size() == 4,"Filter discards lowest cost with front-of-hand tie break, then draws")
    b = fixture([["cycle_preserve",0],["tackle",4],["water_gun",7]],["cycle_bookmark"])
    safe(b)
    var own := b.hand[1]
    var other := b.hand[2]
    play(b,"cycle_preserve")
    b.end_turn()
    check(b.hand.has(own) and b.hand.has(other) and b.retained.is_empty() and b.energy == 4+b.turn_energy_bonus,"Whole-hand retention preserves references and charges only one bookmark")
    b.end_turn()
    check(b.energy == 3+b.turn_energy_bonus,"Bookmark cannot pay again without newly retained cards")
    b = fixture([], ["cycle_spring"])
    b.powers["cycle_energy"] = 2
    b.discard.assign([BattleCardInstance.new(41,"guard",0),BattleCardInstance.new(42,"guard",0)])
    var old := b.active().block
    b._draw(1)
    check(b.energy == 5 and b.active().block == old+PokemonStats.scale(b.active(),4) and b.turn_flags.has("reshuffled"),"First shuffle activates engine stacks and spring without recursive draw")
    b.discard.append(BattleCardInstance.new(43,"guard",0))
    b._draw(2)
    check(b.energy == 5 and b.active().block == old+PokemonStats.scale(b.active(),4),"Repeated shuffle in same turn cannot farm either payoff")
func save_checks_new() -> void:
    var j := TacticalJourney.new(42,"field_kit",[4,1,7],true)
    j.relics.append_array(relics())
    j.deck.clear()
    for key: String in keys(): j.deck.append(BattleCardInstance.new(j.deck.size()+1,key,0))
    j._next_card_uid = j.deck.size()+1
    j.battle.start_with(j.party,j.deck,j.route.opponents(0),42,"field_kit",true,j.relics)
    j.battle.hand.clear()
    j.battle.draw_pile.assign(j.deck)
    j.battle.energy = 1000
    var store := JourneySave.new("user://tests/build_concepts/journey.json")
    for card_uid in range(1,25):
        j.battle.draw_pile.append_array(j.battle.hand)
        j.battle.hand.clear()
        j.battle.retained.clear()
        var requested: BattleCardInstance = j.deck[card_uid-1]
        for pile: Array in [j.battle.draw_pile,j.battle.discard,j.battle.exhausted]: pile.erase(requested)
        j.battle.hand.assign([requested])
        check(store.save(j).is_empty(),"Every new effect is checkpointed through v3 disk envelope")
        var resumed := store.load_journey()
        check(resumed != null,"Every new checkpoint can reload")
        if resumed == null: return
        check(j.battle.play_card(card_uid).is_empty() and resumed.battle.play_card(card_uid).is_empty(),"Replay each new card after a true disk load")
        check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Pending resources, triggers and RNG match uninterrupted play")
    check(store.save(j).is_empty(),"All six installed power types and banked energy validate together")
    var resumed := store.load_journey()
    if resumed == null: check(false,"Reload complete mixed concept checkpoint"); return
    j.battle.end_turn()
    resumed.battle.end_turn()
    check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Next-turn bonuses, retention and status expiration match after reload")
    var old := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    check(JourneySnapshot.validate(JourneySnapshot.encode(old)),"Old v3 field shape remains compatible")
    var invalid := JourneySnapshot.encode(old)
    invalid["battle"]["powers"]["unknown_concept"] = 1
    check(not JourneySnapshot.validate(invalid),"New power whitelist still rejects unknown effects")
func availability_checks_new() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.step = 12
    var reward := {}
    var shop := {}
    var relic := {}
    for seed_value in 512:
        j.seed_value = seed_value
        j._prepare_rewards()
        for offer: Dictionary in j.reward_options:
            if offer["kind"] == "card" and offer["owner_uid"] == 0: reward[offer["key"]] = true
            if offer["kind"] == "relic": relic[offer["key"]] = true
        for offer: Dictionary in MerchantContent.generate(seed_value,3,0,j.deck,j.party,j.relics):
            if offer["owner_uid"] == 0: shop[offer["key"]] = true
    for key: String in keys(): check(reward.has(key) and shop.has(key),"Every new card is reachable from ordinary rewards and shops: "+key)
    for key: String in relics(): check(relic.has(key),"Every new ordinary relic is reachable: "+key)
    for concept: String in BuildConceptContent.GROUPS:
        var acquired: Array[String] = [BuildConceptContent.RELICS[concept][0]]
        var related := TacticalContent.synergy_cards(j.deck,acquired)
        check(BuildConceptContent.GROUPS[concept].all(func(key: String): return key in related),"Each concept's relic discovers its four related new cards: "+concept)
