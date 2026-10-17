extends "res://tests/test_build_synergies.gd"
func calm(b: TacticalBattle) -> void:
    b.enemy_definitions[b.enemy_index]["intents"] = [{"kind":"block","value":0,"move_id":115}]
    reserve(b)
func run() -> void:
    definitions()
    damage_rules()
    lifecycle()
    sand_checks()
    save_checks_weather()
    availability()
    print("WEATHER: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func definitions() -> void:
    for key: String in BattleWeather.KINDS:
        for upgraded: bool in [false,true]:
            var b := fixture([["weather_"+key,0],["water_gun",7]])
            b.hand[0].upgraded = upgraded
            var card := b.hand[0]
            var view := b.card_view(card)
            check(view["cost"] == (0 if upgraded else 1),"Weather upgrade reduces cost: "+key)
            var snapshot := b.snapshot()
            var preview := BattleCardPreview.analyze(b,card.uid)
            check(snapshot == b.snapshot() and preview["reason"].is_empty(),"Weather preview is pure: "+key)
            play(b,"weather_"+key)
            check(BattleWeather.kind(b.powers) == key and BattleWeather.remaining(b.powers) == 5,"Weather card applies one finite global state: "+key)
            check(b.events.any(func(e: Dictionary): return e["kind"] == "weather" and BattleWeather.kind(e["frame"]["powers"]) == key),"Weather event has staged powers: "+key)
            check(view["description"].contains("양쪽") and view["description"].contains("교대") and CardEffectText.render(view).contains("5턴"),"Weather description includes duration and recipients: "+key)
    for id: int in BattleWeather.MOVES:
        var key: String = BattleWeather.MOVES[id]
        var raw := TacticalMoves.definition(TacticalMoves.key_for(id))
        check(raw.get("weather","") == key and not raw.has("block"),"Original weather move has actual weather, no fallback shield: "+str(id))
        var b := fixture([[TacticalMoves.key_for(id),7]])
        play(b,TacticalMoves.key_for(id))
        check(b.active().uid == 7 and BattleWeather.kind(b.powers) == key and b.energy == 2,"Owned weather technique auto-switches and consumes only its own energy")
func damage_rules() -> void:
    var b := fixture([["water_gun",7],["ember",4]])
    for key: String in ["rain","sun","snow","sand"]:
        for type: String in ["water","fire","normal"]:
            var move := {"type":type,"move_id":55,"move_power":80,"damage_class":"special"}
            var normal := PokemonStats.damage(b.active(),b.enemy(),move,1.0)
            var actual := PokemonStats.damage(b.active(),b.enemy(),move,1.0,0,1.0,key)
            check(actual == maxi(1,floori(normal*BattleWeather.attack_factor(key,type))) or absi(actual-roundi(normal*BattleWeather.attack_factor(key,type))) <= 1,"Weather multiplier only changes fire/water in rain/sun")
    b.enemy().types.assign(["ice","water"])
    var physical := {"type":"normal","move_power":100,"damage_class":"physical"}
    var special := {"type":"normal","move_power":100,"damage_class":"special"}
    check(PokemonStats.damage(b.active(),b.enemy(),physical,1.0,0,1.0,"snow") < PokemonStats.damage(b.active(),b.enemy(),physical,1.0),"Snow increases ice physical defense")
    check(PokemonStats.damage(b.active(),b.enemy(),special,1.0,0,1.0,"snow") == PokemonStats.damage(b.active(),b.enemy(),special,1.0),"Snow does not change special defense")
    b.enemy().types.assign(["rock","ground"])
    check(PokemonStats.damage(b.active(),b.enemy(),special,1.0,0,1.0,"sand") < PokemonStats.damage(b.active(),b.enemy(),special,1.0),"Sand increases rock special defense")
    check(PokemonStats.damage(b.active(),b.enemy(),physical,1.0,0,1.0,"sand") == PokemonStats.damage(b.active(),b.enemy(),physical,1.0),"Sand does not change physical defense")
    check(PokemonStats.damage(b.active(),b.enemy(),special,0.0,0,1.0,"sun") == 0,"Weather never defeats immunity")
    b = fixture([["water_gun",7]])
    BattleWeather.apply(b,"rain")
    var view := b.card_view(b.hand[0])
    var preview := BattleCardPreview.analyze(b,b.hand[0].uid)
    play(b,"water_gun")
    check(preview["target_after"] == BattleFrame.member(b.enemy()) and view["preview_damage"] == 200-b.enemy().hp,"Rain preview matches damage after technique auto-switch")
    b.enemy_definitions[0]["intents"] = [{"kind":"attack","value":8,"type":"water","move_id":55}]
    var hp := b.active().hp
    b.active().block = 0
    var expected := int(b.intent()["value"])
    b.end_turn()
    check(b.member(7).hp == maxi(0,hp-expected),"Enemy intent and actual weather damage agree")
func lifecycle() -> void:
    var b := fixture([])
    calm(b)
    BattleWeather.apply(b,"rain")
    b.switch_to(7)
    check(BattleWeather.remaining(b.powers) == 5,"Manual switch does not shorten weather")
    for i in 4:
        b.end_turn()
        check(BattleWeather.remaining(b.powers) == 4-i,"One complete enemy phase consumes exactly one weather turn")
    BattleWeather.apply(b,"rain")
    check(BattleWeather.remaining(b.powers) == 5,"Recasting same weather refreshes duration")
    BattleWeather.apply(b,"snow")
    check(not b.powers.has("weather_rain") and BattleWeather.kind(b.powers) == "snow","Different weather replaces earlier weather")
    var hp := b.active().hp
    for i in 5: b.end_turn()
    check(BattleWeather.kind(b.powers).is_empty() and hp == b.active().hp,"Snow expires without chip damage")
    BattleWeather.apply(b,"sun")
    b._damage(b.enemy(),99999,true)
    b._outcome()
    check(b.phase == TacticalBattle.WON and BattleWeather.kind(b.powers).is_empty(),"Weather clears on victory")
func sand_checks() -> void:
    for types: Array in [["fire"],["rock"],["water","ground"],["steel","flying"],["ice"]]:
        var b := fixture([])
        calm(b)
        b.active().types.assign(types)
        b.active().block = 100
        var hp := b.active().hp
        var bench := b.member(7).hp
        BattleWeather.apply(b,"sand")
        b.end_turn()
        var immune := types.any(func(t: String): return t in ["rock","ground","steel"])
        check(b.active().hp == hp-(0 if immune else maxi(1,floori(b.active().max_hp/16.0))),"Sand only damages vulnerable active members, through shield: "+str(types))
        check(b.member(7).hp == bench and not b.turn_flags.has("status_ember"),"Bench and DOT relics do not receive sand damage")
    var b := fixture([])
    calm(b)
    b.active().hp = 1
    BattleWeather.apply(b,"sand")
    b.end_turn()
    check(b.phase == TacticalBattle.REPLACE and b._pending == "player" and BattleWeather.remaining(b.powers) == 4,"Sand KO waits for forced replacement after one weather tick")
    b.switch_to(7)
    check(b.phase == TacticalBattle.PLAYER and b.turn == 2 and BattleWeather.remaining(b.powers) == 4,"Forced replacement cannot tick weather again")
    b = fixture([])
    calm(b)
    var extra := BattlePokemon.new({"id":43,"name":"다음 상대","type":"grass","max_hp":60},-2)
    b.enemies.append(extra)
    b.enemy_states.append({"intent":0})
    b.enemy_definitions.append(b.enemy_definitions[0].duplicate(true))
    b.enemy().hp = 1
    BattleWeather.apply(b,"sand")
    b.end_turn()
    check(b.enemy_index == 1 and b.enemy().hp == 60 and BattleWeather.remaining(b.powers) == 4,"Sand KO switches foe without hitting newly entered foe")
    b = fixture([])
    calm(b)
    for p: BattlePokemon in b.party: p.hp = 0
    b.active().hp = 1
    b.enemy().hp = 1
    BattleWeather.apply(b,"sand")
    b.end_turn()
    check(b.phase == TacticalBattle.LOST and b.enemy().hp == 0,"Simultaneous final sand KO follows existing party-loss priority")
func save_checks_weather() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    var store := JourneySave.new("user://weather-rules.dat")
    for key: String in BattleWeather.KINDS:
        BattleWeather.apply(j.battle,key)
        check(store.save(j).is_empty(),"Weather checkpoint saves to disk: "+key)
        var resumed := store.load_journey()
        check(resumed != null,"Weather checkpoint reloads: "+key)
        if resumed == null: continue
        j.battle.end_turn()
        resumed.battle.end_turn()
        check(JourneySnapshot.encode(j) == JourneySnapshot.encode(resumed),"Weather damage, duration, RNG match uninterrupted play: "+key)
    var invalid := JourneySnapshot.encode(j)
    invalid["battle"]["powers"]["weather_sun"] = 6
    check(not JourneySnapshot.validate(invalid),"Save rejects impossible weather duration")
    invalid = JourneySnapshot.encode(j)
    invalid["battle"]["powers"]["weather_rain"] = 2
    invalid["battle"]["powers"]["weather_snow"] = 2
    check(not JourneySnapshot.validate(invalid),"Save rejects simultaneous multiple weather")

func availability() -> void:
    var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    j.step = 12
    var rewards := {}
    var shops := {}
    for seed_value in 512:
        j.seed_value = seed_value
        j._prepare_rewards()
        for offer: Dictionary in j.reward_options:
            if offer["kind"] == "card" and offer["owner_uid"] == 0: rewards[offer["key"]] = true
        for offer: Dictionary in MerchantContent.generate(seed_value,3,0,j.deck,j.party,j.relics):
            if offer["owner_uid"] == 0: shops[offer["key"]] = true
    for key: String in BattleWeather.KINDS:
        check(rewards.has("weather_"+key) and shops.has("weather_"+key),"Weather card is reachable through real rewards and merchants: "+key)
