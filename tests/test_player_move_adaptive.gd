extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:call_deferred("run")
func fixture(boss:=false) -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,241 if boss else 143,"gym:whitney" if boss else "")
    b.player_moves_version=18;HeldItems.initialize(b);return b
func types(p:BattlePokemon,values:Array[String]) -> void:p.types=values.duplicate();p.type=values[0]
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:BattleCardInstance=h.card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Cast "+str(id));return v
func stats(p:BattlePokemon,attack:int,special:int,defense:=100,spdef:=100) -> void:p.battle_stats={"attack":attack,"special_attack":special,"defense":defense,"special_defense":spdef,"speed":100}
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==26 and PlayerTechniques.version(26)==18 and PlayerMoveAdaptive.data()["moves"].size()==13,"New adaptive route/overlay catalog")
    var immutable:=var_to_bytes(PlayerMoveAdaptive.data())
    for key:String in PlayerMoveAdaptive.data()["moves"]:
        var b:=fixture();var c:BattleCardInstance=h.card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and b.card_view(c)==v and v["player_rules"]==18,"Pure dynamic preview "+key)
        c.upgraded=true;check(not CardEffectText.render(b.card_view(c)).is_empty(),"Upgraded dynamic description "+key)
    var b:=fixture();types(b.enemy(),["water"])
    check(b.multiplier("ice",b.enemy(),573)==2 and b.multiplier("ice",b.enemy(),58)==0.5,"Freeze Dry unique water matchup, ordinary ice unchanged")
    types(b.enemy(),["water","flying"]);check(b.multiplier("ice",b.enemy(),573)==4,"Freeze Dry dual type multiplication")
    types(b.enemy(),["water","steel"]);check(b.multiplier("ice",b.enemy(),573)==1,"Freeze Dry second-type resistance retained")
    types(b.enemy(),["water"]);var c:BattleCardInstance=h.card(b,573);var v:=b.card_view(c)
    var expected:=HeldItems.calculate(b,PlayerMoveFields.room_clone(b,b.active()),PlayerMoveFields.room_clone(b,b.enemy()),v,2.0)
    check(v["preview_damage"]==expected,"Freeze Dry uses proper pre-rounding affinity in damage math")
    var hp:=b.enemy().hp;b.play_card(c.uid);check(hp-b.enemy().hp==v["preview_hp_loss"] and hp>b.enemy().hp,"Freeze Dry execution matches preview")
    b=fixture(true);types(b.enemy(),["water"]);b.enemy().held_item="weakness_policy";HeldItems.initialize(b);cast(b,573)
    check(b.enemy().held_item.is_empty() and b.enemy().stat_stages.get("special_attack",0)==2,"Freeze Dry triggers actual super-effective Weakness Policy")
    b=fixture(true);types(b.enemy(),["water"]);BossBattleRules.write(b)["substitutes"][b.enemy().uid]=10000;hp=b.enemy().hp;cast(b,573)
    check(b.enemy().hp==hp and BossBattleRules.read(b)["substitutes"][b.enemy().uid]<10000,"Freeze Dry never bypasses Substitute")
    b=fixture(true);types(b.enemy(),["water"]);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";hp=b.enemy().hp;cast(b,573);check(b.enemy().hp==hp,"Freeze Dry respects Protect")
    b=fixture();types(b.active(),["water"]);b.enemy_definitions[0]["intents"]=[{"kind":"attack","type":"ice","move_id":573,"value":10}];var a:=b.intent();hp=b.active().hp;b.end_turn();check(a["value"]>0 and hp-b.party[0].hp==a["value"],"Incoming Freeze Dry same preview/execution")
    for id:int in [449,546,718]:
        b=fixture();b.active().held_item="mystic_water";HeldItems.initialize(b);types(b.enemy(),["ghost"]);v=cast(b,id)
        check(v["type"]=="water" and v["preview_damage"]>0,"Held type survives species fallback and immunity "+str(id))
    b=fixture();types(b.active(),["dark"]);types(b.enemy(),["ghost"])
    for id:int in [237,686]:v=cast(b,id);check(v["type"]=="dark" and v["preview_damage"]>0,"Current first-type attack "+str(id))
    b=fixture();BattleWeather.apply(b,"rain");types(b.enemy(),["ghost"]);v=cast(b,311);check(v["type"]=="water" and v["move_power"]==100 and v["preview_damage"]>0,"Rain Weather Ball has final water type and double power")
    b=fixture();b.active().held_item="oran_berry";HeldItems.initialize(b);types(b.enemy(),["ghost"]);v=cast(b,363);check(v["type"]==PlayerMoveBulk.BERRY_TYPES["oran_berry"] and b.active().held_item.is_empty(),"Berry type and actual permanent consumption retained")
    b=fixture();types(b.active(),["grass"]);PlayerMoveFields.write(b).merge({"terrain":"psychic","left":5},true);types(b.enemy(),["ghost"]);v=cast(b,805)
    check(v["type"]=="psychic" and v["preview_damage"]>0,"Terrain Pulse type resolves before immunity")
    b=fixture();types(b.enemy(),["ground"]);b.active().held_item="charcoal";HeldItems.initialize(b);PlayerMoveReactions.write(b)["electric"][b.active().uid]=true;hp=b.enemy().hp;v=cast(b,449)
    check(v["type"]=="electric" and b.enemy().hp==hp,"Electrification overrides item type and respects final immunity")
    b=fixture();stats(b.active(),100,120);b.active().held_item="choice_band";HeldItems.initialize(b);v=cast(b,722);check(v["damage_class"]=="physical","Photon Geyser includes offensive item modifiers")
    b=fixture();stats(b.active(),100,100);v=cast(b,722);check(v["damage_class"]=="special","Photon Geyser ties stay special")
    b=fixture();stats(b.active(),100,100);stats(b.enemy(),100,100,50,150);v=cast(b,801);check(v["damage_class"]=="physical" and PlayerMoveAdaptive.contact(v),"Shell Side Arm picks defensive ratio and contact")
    b=fixture();stats(b.active(),100,100);stats(b.enemy(),100,100,50,150);PlayerMoveFields.write(b)["wonder"]=5;v=cast(b,801);check(v["damage_class"]=="special" and not PlayerMoveAdaptive.contact(v),"Wonder Room changes category and contact together")
    for physical:bool in [true,false]:
        b=fixture(true);stats(b.active(),200 if physical else 50,100);stats(b.enemy(),100,100);b.enemy().held_item="rocky_helmet";HeldItems.initialize(b);hp=b.active().hp;v=cast(b,801)
        check(hp-b.party[0].hp==(maxi(1,b.party[0].max_hp/6) if physical else 0),"Shell Side Arm conditional Helmet "+str(physical))
        b=fixture(true);stats(b.active(),200 if physical else 50,100);stats(b.enemy(),100,100);BossBattleRules.write(b)["guards"][b.enemy().uid]="king";cast(b,801)
        check(b.active().stat_stages.get("attack",0)==(-2 if physical else 0),"Shell Side Arm conditional King's Shield "+str(physical))
    b=fixture();PlayerMoveBulk.write(b)["forms"][b.active().uid]={"species":6,"moves":[686]};types(b.active(),["fire","flying"]);v=cast(b,686);check(v["type"]=="fire","Transformed current type used by Revelation Dance")
    for id:int in [237,686]:
        b=fixture();types(b.active(),["electric"]);PlayerMoveRules.write(b)["spent_electric"][b.active().uid]=true;v=cast(b,id);check(v["type"]=="normal","Typeless first-type fallback "+str(id))
    for physical:bool in [true,false]:
        b=fixture();stats(b.enemy(),200 if physical else 50,100);stats(b.active(),100,100);b.active().held_item="rocky_helmet";HeldItems.initialize(b)
        b.enemy_definitions[0]["intents"]=[{"kind":"attack","type":"poison","move_id":801,"value":10}];hp=b.enemy().hp;b.end_turn()
        check(hp-b.enemy().hp==(maxi(1,b.enemy().max_hp/6) if physical else 0),"Incoming conditional Shell Side Arm Helmet "+str(physical))
        b=fixture();stats(b.enemy(),200 if physical else 50,100);stats(b.active(),100,100);b.enemy_definitions[0]["intents"]=[{"kind":"attack","type":"poison","move_id":801,"value":10}];cast(b,852);b.end_turn()
        check(b.enemy().stat_stages.get("speed",0)==(-1 if physical else 0),"Incoming conditional Shell Side Arm Silk Trap "+str(physical))
    b=fixture();b.player_moves_version=17;types(b.enemy(),["water"]);check(b.multiplier("ice",b.enemy(),573)==0.5,"Frozen v25 Freeze Dry affinity remains old")
    check(PlayerMoveAdaptive.contact({"move_id":214,"damage_class":"physical","copied_view":{"move_id":801,"damage_class":"special"}}),"Copied Shell Side Arm uses final category for contact")
    b=fixture();b.player_moves_version=17;b.active().held_item="mystic_water";HeldItems.initialize(b);c=h.card(b,449);check(b.card_view(c)["type"]=="normal","Frozen v25 item/species fallback remains old")
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    c=h.card(j.battle,722);j.deck.append(c);j._next_card_uid=j.battle._next_uid;check(j.battle.play_card(c.uid).is_empty(),"Actual adaptive expedition action")
    var state:=JourneySnapshot.encode(j);check(JourneySnapshot.validate(state),"Actual adaptive state valid")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Actual adaptive exact restore")
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"New next input and RNG same")
    var save:=JourneySave.new("user://adaptive-v26.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual v26 save envelope reload")
    var f:=FileAccess.open("/tmp/player-v25-before.bin",FileAccess.READ)
    if f!=null:
        var old:Dictionary=f.get_var();check(JourneySnapshot.validate(old["state"]),"Actual previous v25 checkpoint validates")
        if JourneySnapshot.validate(old["state"]):
            var copy:=JourneySnapshot.restore(old["state"]);check(JourneySnapshot.encode(copy)==old["state"],"Actual old exact restore")
            copy.battle.end_turn();check(JourneySnapshot.encode(copy)==old["next"],"Actual old next input/RNG unchanged")
        check(JourneySave.compatible_content(old["fingerprint"]),"Actual prior fingerprint accepted")
        var bad:Dictionary=old["state"].duplicate(true);bad["battle"]["player_moves_version"]=18;check(not JourneySnapshot.validate(bad),"Old route rejects forced new rules")
    else:print("Temporary pre-edit v25 capture absent; previous-state checks skipped")
    check(var_to_bytes(PlayerMoveAdaptive.data())==immutable,"Adaptive data immutable")
    h.free();print("Player adaptive: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
