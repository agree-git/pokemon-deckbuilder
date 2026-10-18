extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,foe,boss);b.player_moves_version=12
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func select_move(b:TacticalBattle,id:int) -> void:
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==id:b.opening()["intent"]=i;return
    check(false,"Authored move exists: "+str(id))
func generic(b:TacticalBattle,id:int,type_name:String) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":type_name,"move_id":id}]
func ground(b:TacticalBattle) -> void:b.active().types.assign(["ground"]);b.active().type="ground"
func journey(v:=20) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,v)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey card executes")
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==20 and PlayerMoveReactions.data()["moves"].size()==3 and PlayerMoveReactions.data()["total_enhanced"]==426,"Three overlays /426 enhanced")
    var immutable:=var_to_bytes(PlayerMoveReactions.data())
    for id:int in [569,582,600]:
        var b:=fixture();var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==12 and not v.has("block"),"Changed card preview is pure; no placeholder shield")
        c.upgraded=true;var u:=b.card_view(c)
        check(u["reaction_rule"]==v["reaction_rule"] and u["cost"]==maxi(0,int(v["cost"])-1) and not CardEffectText.render(u).is_empty(),"Upgrade/text retain feature and reduce cost")
    var b:=fixture(74);var c:=card(b,33);check(b.card_view(c)["preview_damage"]>0,"Normal hit initially damages Rock/Ground")
    var types:=b.active().types.duplicate();cast(b,569);var v:=b.card_view(c);var hp:=b.enemy().hp;b.play_card(c.uid)
    check(v["type"]=="electric" and v["preview_damage"]==0 and b.enemy().hp==hp and b.active().types==types,"Plasma converts actual player hit and immunity without changing Pokemon types")
    check(b.card_view(card(b,53))["type"]=="fire" and b.card_view(card(b,165))["type"]=="normal","Plasma leaves non-Normal moves and typeless Struggle alone")
    b=fixture();cast(b,569);var own:=b.active();var reserve:=b.party[1];c=card(b,33,reserve.uid);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(v["type"]=="electric" and b.active()==reserve and hp-b.enemy().hp==v["preview_damage"] and PlayerMoveReactions.read(b)["plasma"],"Plasma survives owner-card automatic switch; real damage matches preview")
    b=fixture();ground(b);cast(b,569);v=b.intent();hp=b.active().hp;b.end_turn()
    check(v["type"]=="electric" and v["value"]==0 and b.party[0].hp==hp and b.reaction_context.is_empty(),"Generic Normal opponent converts and all marks expire after its action")
    check(b.intent()["value"]>0,"Next round returns to original Normal damage")
    b=fixture(241,"gym:whitney");select_move(b,34);ground(b);cast(b,569);v=b.intent();hp=b.active().hp;b.end_turn()
    check(v["type"]=="electric" and v["immune"] and b.party[0].hp==hp,"Authored Body Slam changes type before immunity and damage math")
    b=fixture();generic(b,53,"fire");ground(b);cast(b,582);v=b.intent();hp=b.active().hp;b.end_turn()
    check(v["type"]=="electric" and v["value"]==0 and b.party[0].hp==hp,"Electrify converts generic Fire move, not only Normal moves")
    for field:String in ["","electric","grassy"]:
        b=fixture(59,"gym:blaine");select_move(b,394);ground(b)
        if not field.is_empty():PlayerMoveFields.write(b)["terrain"]=field;PlayerMoveFields.write(b)["left"]=5
        cast(b,582);v=b.intent();hp=b.active().hp;b.end_turn()
        check(v["type"]=="electric" and v["value"]==0 and b.party[0].hp==hp,"Authored Electrify preserves converted immunity through field math")
    b=fixture();generic(b,805,"normal");PlayerMoveFields.write(b)["terrain"]="grassy";PlayerMoveFields.write(b)["left"]=5;cast(b,569)
    check(b.intent()["type"]=="grass" and b.card_view(card(b,805))["type"]=="grass","Terrain Pulse resolves terrain typing before global Normal conversion")
    b=fixture();generic(b,805,"normal");PlayerMoveFields.write(b)["terrain"]="grassy";PlayerMoveFields.write(b)["left"]=5;cast(b,582)
    check(b.intent()["type"]=="electric","Electrify overrides Terrain Pulse field typing")
    b=fixture();generic(b,614,"ground");ground(b);cast(b,582);v=b.intent();hp=b.active().hp;b.end_turn()
    check(v["type"]=="electric" and v["value"]==0 and b.party[0].hp==hp,"Electrified Thousand Arrows keeps Electric immunity through dedicated Arrow math")
    b=fixture(10191,"gym:mustard");select_move(b,818);b.active().types.assign(["flying"]);b.active().type="flying";PlayerMoveSeals.write(b)["ally"]=5;var base_hit:int=int(b.intent()["per_hit"])
    cast(b,582);v=b.intent();hp=b.active().hp;b.end_turn()
    check(v["type"]=="electric" and v["per_hit"]>base_hit and hp-b.party[0].hp==mini(hp,int(v["value"])),"Electrified Surging Strikes keeps Electric advantage through Lucky Chant and real multi-hit damage")
    b=fixture(59,"gym:blaine");select_move(b,394);cast(b,600);var foe:=b.enemy();hp=foe.hp;var player_hp:=b.active().hp;v=b.intent();var before:=var_to_bytes(b.snapshot())
    check(v.get("powdered",false) and v["value"]==0 and v==b.intent() and before==var_to_bytes(b.snapshot()),"Powder explosion preview is pure and cancels expected attack")
    b.end_turn();check(hp-foe.hp==maxi(1,foe.max_hp/4) and b.party[0].hp==player_hp and b.reaction_context.is_empty(),"Real Powder deals one quarter without Flare Blitz damage/recoil")
    check(b.opening()["effects_v4"]["actions"]==1 and b.opening()["effects_v4"]["last_failed"] and b.opening()["effects_v4"]["charge"]==0,"Powder cancellation advances authored action exactly once and clears charge")
    b=fixture();generic(b,53,"fire");cast(b,600);hp=b.enemy().hp;player_hp=b.active().hp;b.end_turn()
    check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/4) and b.party[0].hp==player_hp,"Generic Fire move also explodes and never attacks")
    b=fixture(59,"gym:blaine");select_move(b,394);ground(b);cast(b,600);cast(b,582);v=b.intent();hp=b.enemy().hp;b.end_turn()
    check(not v.get("powdered",false) and v["type"]=="electric" and b.enemy().hp==hp,"Electrified Fire is no longer Fire and never triggers Powder")
    b=fixture();cast(b,600);hp=b.enemy().hp;b.end_turn();check(b.enemy().hp==hp and b.reaction_context.is_empty(),"Non-Fire use consumes the one-action Powder window without explosion")
    b=fixture();generic(b,53,"fire");cast(b,600);b.enemy().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};hp=b.enemy().hp;b.end_turn()
    check(b.enemy().hp==hp and b.reaction_context.is_empty(),"Sleeping opponent never uses Fire or explodes; effect expires")
    for mode:String in ["protect","sub","grass","air"]:
        b=fixture(241,"gym:whitney")
        if mode=="protect":BossBattleRules.write(b)["guards"][b.enemy().uid]="protect"
        elif mode=="sub":BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000
        elif mode=="grass":b.enemy().types.assign(["grass"]);b.enemy().type="grass"
        else:BossBattleRules.write(b)["airborne"][b.enemy().uid]=true
        cast(b,600);check(PlayerMoveReactions.read(b)["powder"].has(b.enemy().uid)==(mode=="sub"),"Powder respects guard/Grass/aerial while authentic flag bypasses Substitute")
    b=fixture(241,"gym:whitney");BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000;cast(b,582)
    check(PlayerMoveReactions.read(b)["electric"].is_empty(),"Electrify does not inherit Powder's Substitute bypass")
    b=fixture();cast(b,569);cast(b,582);cast(b,600);var old:=b.enemy().uid;PlayerMoveReactions.on_switch(b,old)
    check(PlayerMoveReactions.read(b)["plasma"] and PlayerMoveReactions.read(b)["electric"].is_empty() and PlayerMoveReactions.read(b)["powder"].is_empty(),"Target departure clears only target marks, not global plasma")
    b=fixture();generic(b,53,"fire");cast(b,600);b.enemy().hp=1;player_hp=b.active().hp;b.end_turn()
    check(b.phase==TacticalBattle.WON and b.party[0].hp==player_hp and b.reaction_context.is_empty(),"Powder KO uses normal victory and cleanup without leaked attack")
    for id:int in [33,53,805,614]:
        b=fixture();c=card(b,id);v=b.card_view(c);b.player_moves_version=11
        check(v["preview_damage"]==b.card_view(c)["preview_damage"],"No reactions preserves selected v19 player damage")
    var j:=journey();jcast(j,195);jcast(j,199);jcast(j,569);jcast(j,582);jcast(j,600);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Live reaction/Perish/aim checkpoint validates")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state and copy.battle.snapshot()==j.battle.snapshot(),"Live reaction state restores exactly")
        var frame:=BattleFrame.capture(j.battle);var detached:=var_to_bytes(frame);j.battle.end_turn();copy.battle.end_turn()
        check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and var_to_bytes(frame)==detached,"Same next action/expiry after load; animation context stays detached")
    var save:=JourneySave.new("user://v20-reactions.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual save envelope reloads")
    var good:=JourneySnapshot.encode(j)
    for changes:Dictionary in [{"plasma":1,"electric":{},"powder":{}},{"plasma":false,"electric":{999999:true},"powder":{}},{"plasma":false,"electric":{},"powder":{j.party[0].uid:1}},{"plasma":false,"electric":{},"powder":{},"extra":true}]:
        var bad:=good.duplicate(true);bad["battle"]["reaction_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged reaction shape/UID/bool")
    var old_j:=journey(19);var old_state:=JourneySnapshot.encode(old_j)
    check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Frozen v19 journey remains exact")
    old_state["battle"]["reaction_context"]={};check(not JourneySnapshot.validate(old_state),"Old route rejects empty new context")
    var f:=FileAccess.open("/tmp/player-v19-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v19 Perish/aim checkpoint remains exact")
    check(JourneySave.compatible_content("e13a64f4566db33fd713fc49225bcc1d6e6eb52fd0aeb5c7fbfdae332853d478"),"Actual prior fingerprint accepted")
    check(var_to_bytes(PlayerMoveReactions.data())==immutable,"Definitions remain immutable")
    j.battle._clear_statuses();check(j.battle.reaction_context.is_empty(),"Cleanup clears all reactions")
    h.free();print("Player move reactions: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
