extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(boss:=false) -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,241 if boss else 143,"gym:whitney" if boss else "")
    b.player_moves_version=17;HeldItems.initialize(b);return b
func types(p:BattlePokemon,values:Array[String]) -> void:p.types=values.duplicate();p.type=values[0]
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:BattleCardInstance=h.card(b,id);var v:=b.card_view(c)
    check(b.play_card(c.uid).is_empty(),"Cast "+str(id));return v
func refused(b:TacticalBattle,id:int,owner:=0) -> void:
    var c:BattleCardInstance=h.card(b,id,owner);var before:=var_to_bytes(b.snapshot())
    check(not b.card_reason(c.uid).is_empty() and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Atomic condition refusal "+str(id))
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==25 and PlayerTechniques.version(25)==17 and PlayerMoveSupport.data()["moves"].size()==16,"New support version/catalog")
    var immutable:=var_to_bytes(PlayerMoveSupport.data())
    for key:String in PlayerMoveSupport.data()["moves"]:
        var b:=fixture();var c:BattleCardInstance=h.card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==17,"Pure support preview "+key)
        c.upgraded=true;check(not CardEffectText.render(b.card_view(c)).is_empty(),"Upgraded support description "+key)
    var b:=fixture();cast(b,74);check(b.active().stat_stages.get("attack",0)==1 and b.active().stat_stages.get("special_attack",0)==1,"Normal Growth")
    b=fixture();BattleWeather.apply(b,"sun");cast(b,74);check(b.active().stat_stages.get("attack",0)==2 and b.active().stat_stages.get("special_attack",0)==2,"Sunny Growth")
    b=fixture();BattleWeather.apply(b,"rain");b.active().stat_stages["attack"]=6;cast(b,74);check(b.active().stat_stages["attack"]==6 and b.active().stat_stages["special_attack"]==1,"Rain and stage cap")
    b=fixture(true);types(b.active(),["grass"]);types(b.enemy(),["grass"]);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000
    cast(b,563);check(b.active().stat_stages.get("attack",0)==1 and b.enemy().stat_stages.get("attack",0)==1 and b.party[1].stat_stages.is_empty(),"Rototiller boosts both eligible field combatants through guard/Substitute, no reserves")
    b=fixture();types(b.active(),["grass"]);types(b.enemy(),["grass","flying"]);cast(b,563);check(b.active().stat_stages.get("attack",0)==1 and b.enemy().stat_stages.is_empty(),"Flying grass excluded from Rototiller")
    PlayerMoveAltitude.write(b)["gravity"]=5;cast(b,563);check(b.enemy().stat_stages.get("attack",0)==1,"Gravity grounds flying grass for Rototiller")
    b=fixture();types(b.active(),["grass"]);types(b.enemy(),["grass"]);PlayerMoveAltitude.write(b)["rise"][b.enemy().uid]=3;cast(b,563);check(b.enemy().stat_stages.is_empty(),"Magnet Rise excludes Rototiller")
    b=fixture();types(b.enemy(),["grass","flying"]);cast(b,579);check(b.enemy().stat_stages.get("defense",0)==1 and b.active().stat_stages.is_empty(),"Flower Shield requires grass but not grounding")
    b=fixture(true);types(b.enemy(),["grass"]);BossBattleRules.write(b)["airborne"][b.enemy().uid]=true;refused(b,579)
    for id:int in [563,579,602,674]:b=fixture();refused(b,id)
    for id:int in [597,777,811]:
        b=fixture(true);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,id)
        var changes:Dictionary=PlayerMoveSupport.overlay(id)["support_changes"]
        check(b.active().stat_stages.is_empty() and b.enemy().stat_stages.is_empty() and b.party[1].stat_stages==changes and b.party[2].stat_stages==changes,"Other allies only "+str(id))
        b=fixture();b.party[1].hp=0;b.party[2].hp=0;refused(b,id)
    for id:int in [602,674]:
        b=fixture();types(b.active(),["electric"]);types(b.party[1],["steel"]);types(b.party[2],["grass"]);cast(b,id)
        var changes:Dictionary=PlayerMoveSupport.overlay(id)["support_changes"]
        check(b.active().stat_stages==changes and b.party[1].stat_stages==changes and b.party[2].stat_stages.is_empty() and b.enemy().stat_stages.is_empty(),"Magnetic support type adaptation "+str(id))
    b=fixture();types(b.party[1],["electric"]);b.party[1].hp=0;refused(b,602)
    b=fixture();refused(b,599)
    b=fixture();b.enemy().statuses["poison"]={"turns":3};cast(b,599);check(b.enemy().stat_stages.get("attack",0)==-1 and b.enemy().stat_stages.get("speed",0)==-1,"Venom Drench requires and uses poison")
    for mode:String in ["guard","sub","mist","amulet"]:
        b=fixture(true);b.enemy().statuses["poison"]={"turns":3}
        match mode:
            "guard":BossBattleRules.write(b)["guards"][b.enemy().uid]="protect"
            "sub":BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000
            "mist":PlayerMoveFields.write(b)["foe"]["mist"]=3
            "amulet":b.enemy().held_item="clear_amulet";HeldItems.initialize(b)
        cast(b,599);check(b.enemy().stat_stages.values().all(func(n:Variant):return int(n)==0),"Venom Drench respects "+mode)
    for id:int in [77,78,79,147,178,600,750]:
        b=fixture();types(b.enemy(),["grass"]);refused(b,id,b.party[1].uid)
        b=fixture();types(b.active(),["grass"]);b.enemy_definitions[0]["intents"]=[{"kind":"status","value":3,"status":"poison","type":"poison","move_id":id}]
        check(b.intent().has("support_cancel") and b.intent()["value"]==0,"Incoming powder preview immune "+str(id));b.end_turn()
        check(b.party[0].statuses.is_empty() and b.opening()["intent"]==1,"Incoming powder executes no effect and advances once "+str(id))
    b=fixture();cast(b,147);check(b.enemy().statuses.has("sleep"),"Spore works on non-grass")
    b=fixture();cast(b,178);check(b.enemy().stat_stages.get("speed",0)==-2,"Cotton Spore works on non-grass")
    b=fixture();cast(b,750);check(PlayerMoveCards.effective_types(b,b.enemy())==["psychic"],"Magic Powder retains type conversion")
    for flag:String in ["asleep","player_sealed","bulk_cancel"]:
        b=fixture();types(b.active(),["grass"]);var action:Dictionary={"move_id":147,"kind":"status","value":0};action[flag]="reflect" if flag=="bulk_cancel" else true
        check(PlayerMoveSupport.enemy_preview(b,b.active(),action)==action and not action.has("support_cancel"),"Preserve preexisting action cancellation "+flag)
    b=fixture();types(b.enemy(),["grass"]);cast(b,92);check(b.enemy().statuses.has("poison"),"Nonpowder poison still affects grass")
    b=fixture();b.player_moves_version=16;types(b.enemy(),["grass"]);cast(b,147);check(b.enemy().statuses.has("sleep"),"Frozen v24 powder behavior preserved")
    b=fixture();b.player_moves_version=16;BattleWeather.apply(b,"sun");cast(b,74);check(b.active().stat_stages.get("attack",0)==1,"Frozen v24 Growth preserved")
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    var c:BattleCardInstance=h.card(j.battle,777);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real support expedition action")
    var state:=JourneySnapshot.encode(j);check(JourneySnapshot.validate(state),"Actual v25 support state validates")
    if JourneySnapshot.validate(state):
        var restored:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(restored)==state,"Actual support recipient stages restore")
        j.battle.end_turn();restored.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(restored),"Same next opponent action and RNG after restore")
    var save:=JourneySave.new("user://support-v25.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Real new envelope reload")
    var file:=FileAccess.open("/tmp/player-v24-before.bin",FileAccess.READ)
    if file==null:print("No temporary pre-edit v24 capture; previous-state checks skipped")
    if file!=null:
        var old:Dictionary=file.get_var();check(JourneySnapshot.validate(old["state"]),"Actual v24 checkpoint validates")
        if JourneySnapshot.validate(old["state"]):
            var restored:=JourneySnapshot.restore(old["state"]);check(JourneySnapshot.encode(restored)==old["state"],"Old exact roundtrip")
            restored.battle.end_turn();check(JourneySnapshot.encode(restored)==old["next"],"Old next action and RNG preserved")
        check(JourneySave.compatible_content(old["fingerprint"]),"Actual previous fingerprint accepted")
        var bad:Dictionary=old["state"].duplicate(true);bad["battle"]["player_moves_version"]=17;check(not JourneySnapshot.validate(bad),"Reject forced v17 on old route")
    check(var_to_bytes(PlayerMoveSupport.data())==immutable,"Support data immutable")
    h.free();print("Player support: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
