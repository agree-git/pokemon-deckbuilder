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
    b.player_moves_version=19;HeldItems.initialize(b);b.enemy().hp=10000;b.enemy().max_hp=10000;return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Cast "+str(id));return v
func refused(b:TacticalBattle,id:int) -> void:
    var c:=card(b,id);var before:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Atomic refusal "+str(id))
func intent(b:TacticalBattle,id:int,kind:="attack",type_name:="normal") -> void:b.enemy_definitions[0]["intents"]=[{"kind":kind,"value":10,"move_id":id,"type":type_name}]
func statuses(p:BattlePokemon,source:int) -> void:p.statuses={"burn":{"turns":3,"source_uid":source},"seed":{"turns":3,"source_uid":source},"confusion":{"turns":3,"source_uid":source}}
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==27 and PlayerTechniques.version(27)==19,"v27 / effect19")
    var data:=PlayerMoveCompletion.data();var immutable:=var_to_bytes(data)
    check(data["audit"].size()==919 and data["moves"].size()==92 and data["pending"].is_empty(),"All919 classified,92 entries, no pending configuration")
    for key:String in data["moves"]:
        var b:=fixture();var c:=card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and b.card_view(c)==v and v["player_rules"]==19,"Pure completion preview "+key)
        c.upgraded=true;check(not CardEffectText.render(b.card_view(c)).is_empty(),"Upgraded completion text "+key)
    var b:=fixture();cast(b,268);check(PlayerMoveCompletion.read(b)["charged"].get(b.active().uid,false) and b.active().stat_stages.get("special_defense")==1,"Charge stores next attack and special defense")
    cast(b,33);check(PlayerMoveCompletion.read(b)["charged"].get(b.active().uid,false),"Nonelectric preserves Charge")
    var v:=cast(b,85);check(v["move_power"]==180 and not PlayerMoveCompletion.read(b)["charged"].has(b.active().uid),"Next electric power doubles and consumes Charge")
    var c:=card(b,85);check(b.card_view(c)["move_power"]==90,"Charge boost consumed once")
    b=fixture(true);cast(b,268);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,85);check(not PlayerMoveCompletion.read(b)["charged"].has(b.active().uid),"Blocked electric attack still spends Charge")
    b=fixture();c=card(b,205);var power:int=b.card_view(c)["move_power"];cast(b,111);v=cast(b,205);check(v["move_power"]==power*2,"Defense Curl doubles first Rollout")
    v=cast(b,205);check(v["move_power"]==power*4,"Defense Curl combines with existing chain")
    b=fixture();intent(b,23);var base:int=b.intent()["value"];cast(b,107);check(b.intent()["value"]==base*2,"Player Minimize doubles incoming stomp damage")
    b=fixture();PlayerMoveCompletion.write(b)["small"][b.enemy().uid]=true;c=card(b,34);v=b.card_view(c);check(v["move_power"]==170,"Opponent Minimize doubles Body Slam power")
    b=fixture();var weight:=PlayerMoveCompletion.weight(b,b.active());cast(b,475);check(PlayerMoveCompletion.weight(b,b.active())==maxi(1,weight-1000),"Autotomize reduces100kg")
    cast(b,475);cast(b,475);refused(b,475)
    var old_uid:=b.active().uid;b._change_active(b.party[1].uid,true);check(not PlayerMoveCompletion.read(b)["weight_loss"].has(old_uid),"Weight and volatile state clear on switch")
    b=fixture();PlayerMoveCompletion.write(b)["weight_loss"][b.enemy().uid]=3000;v=cast(b,67);check(v["move_power"]==100,"Low Kick uses changed target weight")
    c=card(b,447);check(b.card_view(c)["move_power"]==100,"Grass Knot shares live target weight")
    b=fixture();PlayerMoveCompletion.write(b)["weight_loss"][b.active().uid]=4500;v=cast(b,484);check(v["move_power"]==40,"Heavy Slam uses reduced user weight")
    for id:int in [364,467,566,593,621]:
        b=fixture(true);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";c=card(b,id);v=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Guard-break cast "+str(id))
        if v.get("preparing",false):
            check(BossBattleRules.read(b)["guards"].has(b.enemy().uid),"Preparation never breaks guard "+str(id));b.end_turn();BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";check(b.play_card(c.uid).is_empty(),"Release guard breaker "+str(id))
        check(not BossBattleRules.read(b)["guards"].has(b.enemy().uid),"Actual guard removed "+str(id))
    b=fixture(true);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,910);check(BossBattleRules.read(b)["guards"].has(b.enemy().uid),"Mighty Cleave keeps its bypass-only protection policy")
    for id:int in [252,660]:
        b=fixture();cast(b,id);refused(b,id)
        b=fixture();intent(b,182,"block");b.end_turn();refused(b,id);b._change_active(b.party[1].uid,true);cast(b,id)
    for id:int in [389,909]:
        b=fixture();cast(b,id)
        b=fixture();intent(b,182,"block");refused(b,id)
        b=fixture();intent(b,76,"prepare","grass");refused(b,id)
    b=fixture();refused(b,918);intent(b,98);cast(b,918)
    b=fixture();intent(b,100,"wait");v=cast(b,228);check(v["move_power"]==80,"Pursuit sees announced pivot")
    for id:int in [691,859,799]:
        b=fixture();cast(b,id);check(b.enemy().stat_stages.is_empty(),"No fabricated enemy stat drop "+str(id))
        check(b.active().stat_stages.get("speed" if id==859 else "defense",0)==(-2 if id==859 else -1),"Actual self drop "+str(id))
        if id==799:check(b.active().stat_stages.get("speed",0)==1,"Scale Shot self boost once per card")
    b=fixture();PlayerMoveAltitude.write(b)["gravity"]=5;v=cast(b,788);check(v["move_power"]==120,"Gravity boosts Grav Apple")
    for id:int in [732,741]:
        b=fixture();b.active().friendship=255;c=card(b,id);check(b.card_view(c)["move_power"]==102,"Friendship power "+str(id));c.upgraded=true;check(b.card_view(c)["move_power"]==117,"Friendship upgrade "+str(id))
    b=fixture();cast(b,736);check(PlayerMoveFields.read(b)["ally"]["screen"]==5,"Glitzy Glow Light Screen")
    b=fixture();cast(b,737);check(PlayerMoveFields.read(b)["ally"]["reflect"]==5,"Baddy Bad Reflect")
    b=fixture();cast(b,738);check(b.enemy().statuses.has("seed"),"Sappy Seed actually seeds")
    b=fixture();b.active().stat_stages["attack"]=2;b.enemy().stat_stages["defense"]=-2;b.party[1].stat_stages["speed"]=2;cast(b,739)
    check(b.active().stat_stages.is_empty() and b.enemy().stat_stages.is_empty() and b.party[1].stat_stages.get("speed",0)==2,"Freezy Frost only clears both combatants")
    b=fixture();statuses(b.party[1],b.enemy().uid);cast(b,740);check(not b.party[1].statuses.has("burn") and b.party[1].statuses.has("seed") and b.party[1].statuses.has("confusion"),"Sparkly Swirl cures only major status")
    b=fixture();b.active().held_item="oran_berry";HeldItems.initialize(b);cast(b,747)
    check(b.active().held_item.is_empty() and b.active().stat_stages.get("defense",0)==2 and PlayerMoveBulk.ate(b,b.active()),"Stuff Cheeks consumes real berry and enables Belch")
    cast(b,278);check(b.active().held_item=="oran_berry","Stuff Cheeks supports real Recycle")
    b=fixture();refused(b,747)
    for id:int in [505,666,676]:
        b=fixture();b.party[1].hp=b.party[1].max_hp/2;b.party[2].hp=b.party[2].max_hp/10;var hp:int=b.party[2].hp;var own:int=b.active().hp;v=cast(b,id)
        check(v.get("completion_heal_uid")==b.party[2].uid and b.party[2].hp>hp and b.active().hp==own and not v.has("damage"),"Deterministic injured ally heal "+str(id))
    b=fixture();var hp:int=b.enemy().hp;cast(b,676);check(b.enemy().hp<hp,"Healthy party Pollen Puff attacks")
    b=fixture();refused(b,505)
    b=fixture();b.party[1].hp=1;PlayerMoveTactics.write(b)["heal_block"][b.party[1].uid]=b.turn+3;refused(b,666)
    for id:int in [215,312,816,849]:
        b=fixture();statuses(b.party[1],b.enemy().uid);cast(b,id);check(not b.party[1].statuses.has("burn") and b.party[1].statuses.has("seed") and b.party[1].statuses.has("confusion"),"Party cure preserves volatile conditions "+str(id))
    b=fixture();b.active().hp/=2;statuses(b.active(),b.enemy().uid);cast(b,156);check(b.active().statuses.has("sleep") and b.active().statuses.has("seed") and b.active().statuses.has("confusion") and not b.active().statuses.has("burn"),"Rest preserves volatile conditions")
    b=fixture();statuses(b.active(),b.enemy().uid);cast(b,850);check(b.active().stat_stages.get("special_attack",0)==1 and b.active().stat_stages.get("special_defense",0)==1 and not b.active().statuses.has("burn") and b.active().statuses.has("seed"),"Take Heart boosts and cures only major status")
    b=fixture();b.enemy().statuses["confusion"]={"turns":3,"source_uid":b.active().uid};refused(b,685)
    b=fixture();statuses(b.enemy(),b.active().uid);cast(b,685);check(not b.enemy().statuses.has("burn") and b.enemy().statuses.has("seed") and b.enemy().statuses.has("confusion"),"Purify preserves target volatile conditions")
    b=fixture();b.active().hp/=4;hp=b.active().hp;PlayerMoveTactics.write(b)["heal_block"][b.active().uid]=b.turn+5;cast(b,202);check(b.active().hp==hp,"Healing block suppresses drain")
    b=fixture();intent(b,182,"block");b.active().hp/=2;hp=b.active().hp;cast(b,273);PlayerMoveTactics.write(b)["heal_block"][b.active().uid]=b.turn+5;b.end_turn();check(b.party[0].hp==hp and PlayerMoveRules.read(b)["wishes"].is_empty(),"Blocked Wish expires without healing")
    b=fixture();intent(b,182,"block");b.active().hp/=2;hp=b.active().hp;PlayerMoveRules.write(b)["rings"][b.active().uid]=true;PlayerMoveRules.write(b)["roots"][b.active().uid]=true;PlayerMoveTactics.write(b)["heal_block"][b.active().uid]=b.turn+5;b.end_turn();check(b.party[0].hp==hp,"Healing block suppresses Aqua Ring and Ingrain")
    b=fixture();b.active().hp/=2;hp=b.active().hp;PlayerMoveTactics.write(b)["heal_block"][b.active().uid]=b.turn+5;b._status_hit(b.enemy(),"seed",{"turns":3,"source_uid":b.active().uid});check(b.active().hp==hp,"Healing block suppresses seed recovery")
    b=fixture();cast(b,268);var frame:=BattleFrame.capture(b);frame["completion_context"]["charged"].clear();check(PlayerMoveCompletion.read(b)["charged"].get(b.active().uid,false),"Presentation state deeply detached")
    b=fixture();b.player_moves_version=18;cast(b,268);c=card(b,85);check(b.card_view(c)["move_power"]==90 and b.completion_context.is_empty(),"Frozen v26 Charge behavior unchanged")
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    for id:int in [268,111,475]:
        c=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid;check(j.battle.play_card(c.uid).is_empty(),"Actual expedition stateful move "+str(id))
    var state:=JourneySnapshot.encode(j);check(JourneySnapshot.validate(state),"Actual v27 context validates")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Actual v27 context exact restore")
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Same next action and RNG with volatile traits")
        for bad_group:String in ["charged","weight_loss","entered","entry_used"]:
            var bad:=state.duplicate(true);bad["battle"]["completion_context"][bad_group][j.party[0].uid]=-1;check(not JourneySnapshot.validate(bad),"Reject polluted context "+bad_group)
    var save:=JourneySave.new("user://completion-v27.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual v27 save envelope")
    var f:=FileAccess.open("/tmp/player-v26-before.bin",FileAccess.READ)
    if f!=null:
        var old:Dictionary=f.get_var();check(JourneySnapshot.validate(old["state"]),"Actual pre-edit v26 state valid")
        if JourneySnapshot.validate(old["state"]):
            var copy:=JourneySnapshot.restore(old["state"]);check(JourneySnapshot.encode(copy)==old["state"],"Actual v26 exact restore")
            copy.battle.end_turn();check(JourneySnapshot.encode(copy)==old["next"],"Actual v26 next input/RNG unchanged")
        check(JourneySave.compatible_content(old["fingerprint"]),"Actual previous fingerprint accepted")
        var bad:Dictionary=old["state"].duplicate(true);bad["battle"]["completion_context"]=PlayerMoveCompletion.DEFAULT.duplicate(true);check(not JourneySnapshot.validate(bad),"Old rules reject new context injection")
    else:print("Temporary previous capture absent; prior-state checks skipped")
    check(var_to_bytes(PlayerMoveCompletion.data())==immutable,"Completion data immutable")
    h.free();print("Player completion: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
