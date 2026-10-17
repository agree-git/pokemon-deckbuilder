extends SceneTree
const TacticalPolicy = preload("support/tactical_policy.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(specs: Array, relics: Array[String] = []) -> TacticalBattle:
    var members: Array[BattlePokemon] = []
    for definition: Dictionary in TacticalContent.PARTY: members.append(BattlePokemon.new(definition,definition["uid"]))
    var cards: Array[BattleCardInstance] = []
    for spec: Array in specs: cards.append(BattleCardInstance.new(cards.size()+1,spec[0],spec[1]))
    var enemy := {"id":43,"name":"뚜벅쵸","type":"grass","max_hp":200,"intents":[{"kind":"attack","value":8,"type":"normal","move_id":33}]}
    var b := TacticalBattle.new()
    b.start_with(members,cards,[enemy],71,"field_kit",true,relics)
    b.energy = 3 # Fixed budget isolates shared-deck rules; speed grants have dedicated tests.
    b.enemy().max_hp = 200
    b.enemy().hp = 200
    b.hand.assign(cards)
    b.draw_pile.clear()
    return b
func by_key(b: TacticalBattle,key: String) -> int:
    for card: BattleCardInstance in b.hand:
        if card.key == key: return card.uid
    return -1
func run() -> void:
    var b := fixture([["ember",4],["water_gun",7],["guard",0]])
    var before := b.snapshot()
    check(not b.play_card(999).is_empty() and b.snapshot() == before,"Invalid card is an atomic no-op")
    check(not b.use_skill("flame").is_empty() and b.snapshot() == before,"Fixed skills cannot bypass drawn cards")
    check(b.play_card(by_key(b,"water_gun")).is_empty() and b.active().uid == 7 and b.energy == 2,"Inactive owner switches immediately for only card cost")
    check(b.play_card(by_key(b,"ember")).is_empty() and b.active().uid == 4 and b.energy == 1,"Multiple automatic switches stay free")
    var uid := by_key(b,"guard")
    check(b.play_card(uid).is_empty() and b.energy == 0,"Trainer shares the same energy")
    before = b.snapshot()
    check(not b.switch_to(7).is_empty() and b.snapshot() == before,"Manual switch cannot spend unavailable energy")
    check(b.enemy_states[0].keys() == ["intent"],"Enemy state has no opening or break system")
    b = fixture([["guard",0],["water_gun",7]])
    b.play_card(by_key(b,"guard"))
    var protected := b.active().block
    b.play_card(by_key(b,"water_gun"))
    check(b.member(4).block == protected and b.member(7).block == PokemonStats.scale(b.member(7),5),"Protection stays on its owner through auto-switch")
    var hp := b.member(7).hp
    var incoming := int(b.intent()["value"])
    var blocked := b.member(7).block
    b.end_turn()
    check(b.member(7).hp == hp-maxi(0,incoming-blocked) and b.member(4).hp == b.member(4).max_hp,"Last active member receives the telegraphed attack")
    check(b.member(4).block == 0 and b.member(7).block == 0,"Old protection expires at next player turn")
    b = fixture([["flame",4],["guard",0]])
    var expensive := b.hand[0].uid
    b.energy = 1
    before = b.snapshot()
    check(not b.play_card(expensive).is_empty() and b.snapshot() == before,"Unaffordable technique cannot switch or mutate RNG/piles")
    b.energy = 3
    b.play_card(expensive)
    check(b.energy == 1,"Technique charges its displayed cost")
    b = fixture([["focus",0],["ember",4],["hold",0],["flame",4],["potion_card",0],["water_gun",7]])
    b.hand.resize(5)
    b.draw_pile.assign([BattleCardInstance.new(6,"water_gun",7)])
    b.member(4).hp = 2
    b.play_card(by_key(b,"potion_card"))
    check(b.member(4).hp == mini(b.member(4).max_hp,2+PokemonStats.scale(b.member(4),16)) and b.exhausted.size() == 1,"Healing tool heals once and exhausts")
    b.play_card(by_key(b,"hold"))
    var retained := b.retained.duplicate()
    check(retained.size() == 1 and b._hand(retained[0]).key == "flame","Retain selects highest-cost remaining card")
    b.end_turn()
    check(b.hand.any(func(card: BattleCardInstance): return card.uid in retained),"Retained instance survives turn discard")
    for i in 8: b.end_turn()
    check(not b.hand.any(func(card: BattleCardInstance): return card.key == "potion_card"),"Exhausted healing never reshuffles into the fight")
    b = fixture([["relay_plan",0],["water_gun",7],["boost_card",0],["ember",4]], ["switch_power","tool_belt"])
    b.play_card(by_key(b,"relay_plan"))
    check(b.powers.get("relay",0) == 1 and b.exhausted[0].key == "relay_plan","Persistent plan installs and leaves draw cycle")
    b.play_card(by_key(b,"water_gun"))
    check(b.member(7).block == PokemonStats.scale(b.member(7),5)+PokemonStats.scale(b.member(7),3) and not b.switch_bonus.has(7),"Relay power grants protection and baton is consumed by the attack")
    var strength := b.member(7).strength
    b.play_card(by_key(b,"boost_card"))
    check(b.member(7).strength == strength+4 and b.turn_flags.has("tool_belt"),"Tool boost and party relic both trigger")
    b.play_card(by_key(b,"ember"))
    check(b.member(7).strength == strength,"Temporary boost ends when its owner switches out")
    b = fixture([["ace_plan",0],["guard",0]], ["ace_focus"])
    b.active().held_item = "ace_band"
    b.play_card(by_key(b,"ace_plan"))
    b.play_card(by_key(b,"guard"))
    b.end_turn()
    check(b.active().strength == 4,"Persistent plan, relic and held item compose on a retained ace")
    b = fixture([["ember",4],["seed",1],["status_cash",0]], ["status_lens"])
    b.play_card(by_key(b,"ember"))
    check(b.energy == 3,"First new ailment refunds energy via its own relic")
    b.play_card(by_key(b,"seed"))
    check(b.energy == 2,"Status relic triggers once per turn, across party members")
    hp = b.enemy().hp
    b.play_card(by_key(b,"status_cash"))
    check(b.enemy().hp == hp-PokemonStats.scale(b.enemy(),24) and b.enemy().statuses.is_empty(),"Status cash-out trades remaining ticks for damage without break")
    b = fixture([["ember",4],["water_gun",7],["vine",1]], ["relay_draw"])
    b.draw_pile.append(BattleCardInstance.new(10,"guard",0))
    b.draw_pile.append(BattleCardInstance.new(11,"counter",0))
    for key: String in ["ember","water_gun","vine"]: b.play_card(by_key(b,key))
    check(b.turn_flags.has("relay_draw") and b.hand.size() == 2,"Three different actors activate relay draw once")
    b = fixture([["ember",4],["water_gun",7]])
    b.active().held_item = "power_band"
    var view := b.card_view(b.hand[0])
    hp = b.enemy().hp
    b.play_card(b.hand[0].uid)
    check(b.enemy().hp == hp-int(view["preview_damage"]),"Damage preview includes held item and matchup")
    b._damage(b.member(7),999,true)
    check(not b.hand.any(func(card: BattleCardInstance): return card.owner_uid == 7) and b.exhausted.any(func(card: BattleCardInstance): return card.owner_uid == 7),"KO suspends owner cards without permanently removing them")
    check(b.discard.filter(func(card: BattleCardInstance): return card.key == "injury").size() == 1,"KO creates exactly one injury")
    b = fixture([["water_gun",7],["guard",0]])
    b.hand[0].upgraded = true
    view = b.card_view(b.hand[0])
    check(int(view["move_power"]) == int(TacticalMoves.definition("water_gun")["move_power"])+15 and view["name"].ends_with(" +"),"Upgrade changes real card effects and display")
    b = fixture([["hold",0],["flame",4],["water_gun",7],["redraw",0],["guard",0]])
    b.hand[0].upgraded = true
    b.play_card(by_key(b,"hold"))
    check(b.retained.size() == 2,"Upgraded retain preserves two different cards")
    var splash := BattleCardInstance.new(100,"move_150",4)
    check(not TacticalContent.can_upgrade(splash),"Do not offer a no-op upgrade for Splash")
    var redraw := b._hand(by_key(b,"redraw"))
    redraw.upgraded = true
    b.play_card(redraw.uid)
    check(b.hand.size() == 4 and b.exhausted.has(redraw),"Upgraded redraw draws one extra card through a reshuffle and exhausts")
    var catalog := VisualCatalog.new()
    for id in range(1,387):
        var pokemon := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        TacticalGrowth.initialize(pokemon)
        var members: Array[BattlePokemon] = [pokemon]
        var deck := TacticalContent.starting_deck(members)
        check(deck.size() >= 15 and deck.any(func(card: BattleCardInstance): return card.owner_uid == id and TacticalMoves.definition(card.key).has("damage")),"Every species can start with a usable technique deck: %d" % id)
    for seed_value in 12:
        b = TacticalBattle.new(seed_value)
        for limit in 400:
            if b.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
            var action := TacticalPolicy.action(b)
            check(TacticalPolicy.apply(b,action).is_empty(),"Policy uses only legal card actions")
        check(b.phase == TacticalBattle.WON,"Starter battle is winnable across draws: %d" % seed_value)
    print("DECK_COMBAT: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
