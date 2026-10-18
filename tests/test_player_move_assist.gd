extends SceneTree
# Focused identification/aim/team cases and actual save compatibility only.
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=10
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func power(b:TacticalBattle,id:int,owner:=0) -> int:return int(b.card_view(card(b,id,owner))["preview_damage"])
func journey(v:=18) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,v)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey card executes")
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state);check(JourneySnapshot.validate(state),"Live assistance checkpoint validates")
    if not JourneySnapshot.validate(state):return null
    var copy:=JourneySnapshot.restore(state)
    check(var_to_bytes(state)==bytes and JourneySnapshot.encode(copy)==state and j.battle.snapshot()==copy.battle.snapshot(),"Restored state matches exactly without input mutation")
    return copy
func bounce(b:TacticalBattle) -> void:
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==340:b.opening()["intent"]=i
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveAssist.data()["moves"].size()==8 and PlayerMoveAssist.data()["total_enhanced"]==419,"Eight overlays /419 enhanced")
    var immutable:=var_to_bytes(PlayerMoveAssist.data())
    for id:int in [170,193,199,270,316,357,495,511]:
        var b:=fixture();var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==10,"Changed card preview is pure/repeatable")
        c.upgraded=true;check(b.card_view(c)["assist_rule"]==v["assist_rule"] and not CardEffectText.render(v).is_empty(),"Upgrade and compact text retain feature")
    for id:int in [193,316]:
        var b:=fixture(143,94);var types:=b.enemy().types.duplicate();check(power(b,33)==0 and power(b,280)==0,"Ghost starts immune to Normal/Fighting")
        cast(b,id);check(power(b,33)>0 and power(b,280)>0 and b.enemy().types==types,"Identification removes only Ghost immunities without changing types")
    var b:=fixture(143,442);cast(b,193);check(power(b,33)>0 and power(b,94)==0,"Ghost identification leaves Dark Psychic immunity intact")
    cast(b,357);check(power(b,94)>0 and b.enemy().types==["ghost","dark"],"Miracle Eye independently removes Dark immunity")
    b=fixture(143,620,"elite:marshal");bounce(b);cast(b,199);b.end_turn();check(b.boss_context["airborne"].has(b.enemy().uid),"NPC Bounce really prepares after Lock-On")
    var c:=card(b,33);var v:=b.card_view(c);var hp:=b.enemy().hp;b.play_card(c.uid)
    check(v.get("aimed",false) and b.enemy().hp<hp and b.assist_context["aim"].is_empty(),"Aimed attack hits actual aerial evasion and consumes mark")
    check(b.boss_context["airborne"].has(b.enemy().uid),"Ordinary aimed hit does not itself force landing")
    b=fixture(143,241,"gym:whitney");cast(b,170);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";hp=b.enemy().hp;cast(b,33)
    check(b.enemy().hp==hp and b.assist_context["aim"].is_empty(),"Aim preserves Protect and is consumed by attack attempt")
    b=fixture(143,94);cast(b,199);check(power(b,33)==0,"Lock-On never removes type immunity")
    b=fixture(143,241,"gym:whitney");cast(b,199);BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000;hp=b.enemy().hp;cast(b,33)
    check(b.enemy().hp==hp and b.boss_context["substitutes"][b.enemy().uid]<1000,"Aim preserves Substitute absorption")
    b=fixture();quiet(b);cast(b,170);b.end_turn();check(not b.assist_context["aim"].is_empty(),"Aim remains for one next player turn")
    b.end_turn();check(b.assist_context["aim"].is_empty(),"Aim expires after exactly two enemy actions")
    cast(b,199);b.energy=100;b.switch_to(b.party[1].uid);check(b.assist_context["aim"].is_empty(),"Source switching clears its aim")
    b=fixture(143,620,"elite:marshal");bounce(b);cast(b,199);b.end_turn();c=card(b,615);hp=b.enemy().hp;b.play_card(c.uid)
    check(b.enemy().hp<hp and b.boss_context["airborne"].has(b.enemy().uid),"Aimed Thousand Waves hits without confusing Waves with landing Arrow")
    b=fixture();var own:=power(b,33);var reserve:=b.party[1];var base:=power(b,33,reserve.uid);cast(b,270)
    check(power(b,33)==own and power(b,33,reserve.uid)==maxi(1,floori(base*1.5)),"Helping Hand boosts only another owner's next attack")
    c=card(b,33,reserve.uid);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(hp-b.enemy().hp==v["preview_damage"] and b.assist_context["help"]==0,"Help survives automatic switch and preview equals real damage")
    b=fixture();cast(b,495);c=card(b,33);check(not b.card_view(c).has("assist_discount"),"After You does not discount source's own card")
    c=card(b,33,b.party[1].uid);v=b.card_view(c);check(v["cost"]==0 and v.get("assist_discount")==1,"After You represents ally order with cost-1")
    b.play_card(c.uid);check(b.assist_context["after"]==0,"Other owner's technique consumes one discount")
    b=fixture();quiet(b);cast(b,270);cast(b,495);b.end_turn();check(b.assist_context["help"]==0 and b.assist_context["after"]==0,"Unused team assistance expires at turn end")
    b=fixture();b.party[1].hp=0;b.party[2].hp=0;c=card(b,270);var state:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"No living recipient is an atomic refusal")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182},{"kind":"attack","value":10,"type":"normal","move_id":33}];var first:=b.enemy_index;cast(b,511)
    check(b.opening()["intent"]==1 and b.enemy_index==first,"Quash advances intent while preserving opponent/party order")
    c=card(b,511);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Quash respects the once-per-target-turn restriction")
    for id:int in [33,614,374]:
        b=fixture();b.active().held_item="power_band";c=card(b,id);var now:=b.card_view(c);b.player_moves_version=9
        check(now["preview_damage"]==b.card_view(c)["preview_damage"],"No assistance keeps selected v17 attack damage unchanged")
    for version:int in [5,6]:
        b=fixture();b.player_moves_version=version;PlayerMoveFields.write(b)["terrain"]="electric";PlayerMoveFields.write(b)["left"]=5
        v=b.card_view(card(b,85))
        var expected:=PlayerMoveFields.raw_damage(b,b.active(),b.enemy(),v,0)
        check(PlayerTechniques.raw_damage(b,b.active(),b.enemy(),v,0)==expected and expected!=PlayerMoveExchange.raw_damage(b,b.active(),b.enemy(),v,0),"Published v13/v14 terrain damage still uses frozen field engine")
    var j:=journey();j.party[0].held_item="power_band"
    for id:int in [193,357,199,270,495,393,381]:jcast(j,id)
    var copy:=checkpoint(j)
    if copy!=null:
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restore preserves aim expiry/team clearing with existing float/Chant")
        copy=checkpoint(j)
        if copy!=null:
            j.battle._clear_statuses();copy.battle._clear_statuses();check(j.battle.assist_context.is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Cleanup clears assistance identically")
    j=journey();jcast(j,270);jcast(j,495);copy=checkpoint(j)
    if copy!=null:
        var a:BattleCardInstance=h.card(j.battle,33,j.party[1].uid);j.deck.append(a);j._next_card_uid=j.battle._next_uid
        var d:BattleCardInstance=h.card(copy.battle,33,copy.party[1].uid);copy.deck.append(d);copy._next_card_uid=copy.battle._next_uid
        j.battle.play_card(a.uid);copy.battle.play_card(d.uid);check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Loaded ally boost/discount gives identical next card result")
    var save:=JourneySave.new("user://v18-assist.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual new content envelope saves and reloads")
    var good:=JourneySnapshot.encode(j)
    for changes:Dictionary in [{"ghost":{999999:true},"dark":{},"aim":{},"help":0,"after":0},{"ghost":{},"dark":{},"aim":{j.party[0].uid:{"target":j.battle.enemy().uid,"left":3}},"help":0,"after":0},{"ghost":{},"dark":{},"aim":{},"help":"0","after":0},{"ghost":{},"dark":{},"aim":{},"help":0,"after":0,"extra":true}]:
        var bad:=good.duplicate(true);bad["battle"]["assist_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged assistance shape/UID/type/duration")
    var old:=journey(17);var old_state:=JourneySnapshot.encode(old);check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Frozen v17 save remains exact")
    old_state["battle"]["assist_context"]={};check(not JourneySnapshot.validate(old_state),"Old route rejects empty new context")
    var f:=FileAccess.open("/tmp/player-v17-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v17 item checkpoint remains exact")
    check(JourneySave.compatible_content("b1c96f6fc30d2cf0c5ba183957856f7d68437e2ebd6f42776b465e059d92b2e8"),"Actual prior fingerprint accepted")
    check(var_to_bytes(PlayerMoveAssist.data())==immutable,"Definitions remain immutable")
    h.free();print("Player move assist: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
