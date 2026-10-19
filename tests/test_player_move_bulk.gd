extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,143,boss);b.player_moves_version=15;HeldItems.initialize(b);return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int,owner:=0) -> Dictionary:
    var c:=card(b,id,owner);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"Cast %d: %s" % [id,why]);return v
func setup(b:TacticalBattle,id:int) -> void:
    if id==180:PlayerMoveTactics.write(b)["last"][b.enemy().uid]=33
    if id==863:b.party[2].hp=0;b.party[2].knocked_out=true
    if id in [363,562,752]:
        b.active().held_item="sitrus_berry";b.enemy().held_item="oran_berry";HeldItems.initialize(b)
        if id==562:HeldItems.consume(b,b.active(),"sitrus_berry")
    if id==507:b.enemy().species_id=25
    if id==809:b.enemy().held_item="leftovers";HeldItems.initialize(b)
    if id==387:
        PlayerMoveBulk.write(b)["used"][b.active().uid]={}
        for key:String in b.active().learned_skills:PlayerMoveBulk.write(b)["used"][b.active().uid][int(TacticalMoves.definition(key)["move_id"])]=1
    if id==704:PlayerMoveRules.write(b)["received"][b.active().uid]={"turn":b.turn,"damage":10,"kind":"physical","source":b.enemy().uid}
    if id==868:b.active().hp=b.active().max_hp
func generic(b:TacticalBattle,id:int,kind:="attack") -> void:
    b.enemy_definitions[0]["intents"]=[{"kind":kind,"value":10,"type":"normal","move_id":id}]
func journey() -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    j.party[0].held_item="sitrus_berry"
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real expedition casts "+str(id))
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==23 and PlayerTechniques.version(23)==15 and PlayerMoveBulk.data()["moves"].size()==156 and PlayerMoveBulk.data()["audit"].size()==919,"One batch156 / complete919 audit")
    var immutable:=var_to_bytes(PlayerMoveBulk.data())
    for key:String in PlayerMoveBulk.data()["moves"]:
        var id:=int(key);var b:=fixture();setup(b,id);var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==15,"Pure definition/preview "+key)
        c.upgraded=true;var u:=b.card_view(c);check(not CardEffectText.render(u).is_empty() and int(u["cost"])>=0,"Upgrade and text "+key);c.upgraded=false
        check(b.play_card(c.uid).is_empty(),"Execute batch card "+key)
    for id:int in [144,180,230,266,272,277,285,286,288,289,380,388,476,493,494,502,561,603,606,607,671,673,743,752,849,863,867,883,913]:
        var b:=fixture();setup(b,id);var c:=card(b,id);check(not b.card_view(c).has("block"),"Former placeholder removed "+str(id))
        b.player_moves_version=14;check(b.card_view(c).get("block")==5,"Old v22 placeholder remains frozen "+str(id))
    var b:=fixture();cast(b,883);check(BattleWeather.kind(b.powers)=="snow" and BattleWeather.remaining(b.powers)==5,"Snowscape sets shared five-round snow")
    b=fixture();b.active().hp=b.active().max_hp/2;b.party[1].hp=1;b.party[1].statuses["poison"]={"turns":3,"source_uid":b.enemy().uid};var hp:=b.party[1].hp;cast(b,849)
    check(b.party[1].hp==hp+maxi(1,b.party[1].max_hp/4) and b.party[1].statuses.is_empty(),"Lunar Blessing heals/cures living party")
    b=fixture();var dead:=b.party[1];var owned:=card(b,33,dead.uid);b._damage(dead,dead.hp,true)
    check(owned in b.exhausted and not dead.alive(),"KO captures exactly its live cards")
    cast(b,863);check(dead.hp==maxi(1,dead.max_hp/2) and not dead.knocked_out and owned in b.discard and owned not in b.exhausted,"Revival restores halfHP and only KO-exhausted cards")
    var c:=card(b,863);var before:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Revival restriction is atomic")
    b=fixture();b.active().held_item="sitrus_berry";b.enemy().held_item="oran_berry";HeldItems.initialize(b);b.active().hp/=2;b.enemy().hp/=2;hp=b.active().hp;cast(b,752)
    check(b.active().hp==hp+maxi(1,b.active().max_hp/4) and b.active().held_item.is_empty() and b.enemy().held_item.is_empty() and HeldItems.read(b)["used"].size()==2,"Teatime applies both berries and consumes unique original tokens")
    cast(b,278);check(b.active().held_item=="sitrus_berry","Recycle reverses own Teatime consumption")
    b=fixture();var original:=b.active().species_id;var types:=b.active().types.duplicate();b.enemy().types.assign(["water"]);b.enemy().type="water";b.enemy().stat_stages["defense"]=2;cast(b,144)
    check(b.active().species_id==original and b.active().types==b.enemy().types and PlayerMoveBulk.visual_species(b.bulk_context,b.active())==b.enemy().species_id and b.active().stat_stages["defense"]==2,"Transform copies combat stats/type/visual while preserving permanent identity")
    c=card(b,53);var v:=b.card_view(c);check(v["move_id"]==33 and v["key"]==c.key,"Transformed owned card maps to opponent move and retains card identity")
    b.play_card(c.uid);c=card(b,33,b.party[1].uid);b.play_card(c.uid);check(b.party[0].types==types and not b.bulk_context["forms"].has(b.party[0].uid),"Switch restores transform and original types")
    b=fixture();cast(b,286);generic(b,int(TacticalMoves.definition(b.active().learned_skills[0])["move_id"]));check(b.intent().get("player_sealed",false),"Imprison seals own learned shared moves")
    b=fixture();cast(b,266);var a:=b.intent();hp=b.active().hp;b.end_turn();check(hp-b.party[0].hp==a["value"],"Team cover actual generic damage equals preview")
    b=fixture();cast(b,561);hp=b.active().hp;b.end_turn();check(b.party[0].hp==hp,"Mat Block cancels first turn generic attack")
    b=fixture();cast(b,288);b.active().hp=1;b.end_turn();check(b.phase==TacticalBattle.REPLACE and 33 in PlayerMoveBulk.read(b)["blocked"].get(b.enemy().uid,[]),"Direct KO under Grudge seals the actual foe move")
    b=fixture();generic(b,14,"fortify");b.enemy_definitions[0]["intents"][0].merge({"stat":"attack"},true);cast(b,289);hp=b.enemy().hp;b.end_turn()
    check(b.party[0].stat_stages.get("attack",0)==2 and b.enemy().stat_stages.get("attack",0)==0 and b.enemy().hp==hp,"Snatch takes opponent's self stat boost without executing it")
    b=fixture();generic(b,45,"status");b.enemy_definitions[0]["intents"][0].merge({"status":"poison"},true);cast(b,277);b.end_turn()
    check(b.enemy().stat_stages.get("attack",0)==-1 and b.party[0].stat_stages.get("attack",0)==0,"Magic Coat reflects debuff and cancels original")
    b=fixture();b.active().stat_stages["attack"]=6;b.enemy().hp=5;v=cast(b,206);check(b.enemy().hp==1 and v["preview_hp_loss"]==4,"False Swipe stops at1 in preview and execution")
    b=fixture();b.enemy().stat_stages["defense"]=6;b.enemy().stat_stages["special_defense"]=-6;c=card(b,473);var physical_defense_damage:int=b.card_view(c)["preview_damage"];b.enemy().stat_stages["defense"]=-6;b.enemy().stat_stages["special_defense"]=6
    check(b.card_view(c)["preview_damage"]>physical_defense_damage,"Psyshock uses physical Defense while retaining special offense")
    b=fixture();c=card(b,33);var base:int=b.card_view(c)["preview_damage"];PlayerMoveFields.write(b)["foe"]["reflect"]=5;c=card(b,280);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(hp-b.enemy().hp==v["preview_hp_loss"] and PlayerMoveFields.read(b)["foe"]["reflect"]==0,"Screen breaker pure preview equals actual hit and removes screen")
    b=fixture();cast(b,200);c=card(b,53);before=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Rampage rejects different own move atomically")
    cast(b,200);cast(b,200);check(b.active().statuses.has("confusion") and b.bulk_context["rampage"].is_empty(),"Three rampage casts end in confusion")
    b=fixture();cast(b,864);hp=b.enemy().hp;b.end_turn();check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/8),"Salt Cure adds correct end-action DOT")
    b=fixture();cast(b,248);hp=b.enemy().hp;b.end_turn();check(b.enemy().hp==hp and b.bulk_context["future"].size()==1,"Future attack waits through first foe action")
    b.end_turn();check(b.enemy().hp<hp and b.bulk_context["future"].is_empty(),"Future attack fires after second foe action")
    b=fixture();c=card(b,901);b.play_card(c.uid);c=card(b,901);before=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Blood Moon cannot repeat without another move")
    var j:=journey();jcast(j,248);jcast(j,493);jcast(j,388);jcast(j,144);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Combined transform/delay/timers/items state validates")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Combined live state restores exactly")
        var frame:=BattleFrame.capture(j.battle);var detached:=var_to_bytes(frame);j.battle.end_turn();copy.battle.end_turn()
        check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and var_to_bytes(frame)==detached,"Same next input and detached animation state")
    var save:=JourneySave.new("user://bulk-v23.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual save envelope reloads")
    for bad_context:Dictionary in [{"extra":true},PlayerMoveBulk.DEFAULT.merged({"cover":999999},true),PlayerMoveBulk.DEFAULT.merged({"forms":{999999:{"species":143,"moves":[33]}}},true)]:
        var bad:=state.duplicate(true);bad["battle"]["bulk_context"]=bad_context;check(not JourneySnapshot.validate(bad),"Reject forged bulk shape/timer/UID")
    var f:=FileAccess.open("/tmp/player-v22-before.bin",FileAccess.READ)
    if f!=null:
        var old:Dictionary=f.get_var();check(JourneySnapshot.validate(old["state"]),"Actual pre-edit v22 checkpoint validates")
        if JourneySnapshot.validate(old["state"]):
            var restored:=JourneySnapshot.restore(old["state"]);check(JourneySnapshot.encode(restored)==old["state"],"Actual v22 restores exactly")
            restored.battle.end_turn();check(JourneySnapshot.encode(restored)==old["next"],"Actual v22 preserves next input/RNG/effects")
        check(JourneySave.compatible_content(old["fingerprint"]),"Actual previous content fingerprint accepted")
    check(var_to_bytes(PlayerMoveBulk.data())==immutable,"Batch definitions remain immutable")
    j.battle._clear_statuses();check(j.battle.bulk_context.is_empty() and j.battle.bulk_action.is_empty(),"All new state clears on battle cleanup")
    h.free();print("Player bulk: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
