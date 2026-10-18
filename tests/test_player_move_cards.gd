extends SceneTree
var checks:=0
var failures:=0
var catalog:=VisualCatalog.new()
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:call_deferred("run")
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var j:=TacticalJourney.new(712,"field_kit",[ally,6,9],true,10)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    var s:=catalog.species(foe)
    var d:Dictionary={"id":foe,"name":s["name"],"type":s["types"][0],"types":s["types"],"level":50,"max_hp":PokemonStats.value(foe,50,"hp"),"intents":[{"kind":"attack","value":10,"type":"normal","move_id":33}]}
    if not boss.is_empty():d.merge(BossMoveEffectsP3.build(boss,foe),true)
    var b:=TacticalBattle.new();b.player_moves_version=2;b.start_with(j.party,j.deck,[d],712,"field_kit");b.full_type_chart=true
    for p:BattlePokemon in b.party+b.enemies:p.block=0
    return b
func card(b:TacticalBattle,id:int,owner:=0,upgraded:=false) -> BattleCardInstance:
    var c:=BattleCardInstance.new(b._next_uid,TacticalMoves.key_for(id),b.active().uid if owner==0 else owner)
    c.upgraded=upgraded;b._next_uid+=1;b.hand.append(c);b.energy=100
    return c
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"Canonical card can be played: "+str(id)+" "+why)
    return v
func run() -> void:
    check(CampaignRoute.VERSION==10 and PlayerMoveCards.data()["moves"].size()==919,"All919 cards use versioned definitions for new journeys")
    var b:=fixture();var c:=card(b,24);b.enemy().block=10
    var v:=b.card_view(c);var hp:=b.enemy().hp;b.play_card(c.uid)
    check(b.events.filter(func(e:Dictionary):return e["kind"]=="damage" and e.get("target",0)==b.enemy().uid).size()==2,"Double Kick deals two actual shield-consuming hits")
    check(hp-b.enemy().hp==v["preview_hp_loss"],"Multi-hit HP preview accounts for shields")
    b=fixture();b.enemy().hp=1;c=card(b,860);b.play_card(c.uid)
    check(b.events.filter(func(e:Dictionary):return e["kind"]=="damage" and e.get("target",0)<0).size()==1,"Population Bomb stops immediately on KO; no hits on next enemy")
    b=fixture();b.active().hp/=2;b.enemy().hp=7;v=cast(b,202)
    check(b.party[0].hp==b.party[0].max_hp/2+4,"Giga Drain heals half actual7HP, not full potential damage")
    b=fixture();b.active().hp/=2;b.enemy().block=10000;hp=b.active().hp;cast(b,202)
    check(b.active().hp==hp,"Fully shielded drain heals nothing")
    b=fixture();b.enemy().hp=6;hp=b.active().hp;cast(b,413)
    check(hp-b.party[0].hp==2,"Brave Bird recoil uses actual6HP overkill-capped loss")
    b=fixture();b.enemy().block=10000;hp=b.active().hp;cast(b,457)
    check(b.active().hp==hp,"Recoil is zero when only a shield was damaged")
    b=fixture();b.active().hp/=4;hp=b.active().hp;v=cast(b,105)
    check(b.active().hp==mini(b.active().max_hp,hp+PokemonStats.scale(b.active(),24)),"Recover restores50% maxHP rather than generic fixed support")
    b=fixture();b.active().hp=1;BattleWeather.apply(b,"sun");v=cast(b,235)
    check(v["heal"]==32,"Synthesis sunny healing is2/3maxHP")
    b=fixture();c=card(b,76);v=b.card_view(c);hp=b.enemy().hp;var bonus:=b.next_attack_bonus;b.play_card(c.uid)
    check(v.get("preparing",false) and b.enemy().hp==hp and c in b.hand and c.uid in b.retained and b.next_attack_bonus==bonus,"Solar Beam prepares without damage, consumes no attack bonus and keeps its card")
    var before:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Replaying charge in same turn is an atomic refusal")
    b.end_turn();v=b.card_view(c)
    check(v["cost"]==0 and not v.get("preparing",false),"Preserved Solar Beam releases free on following player turn")
    b.play_card(c.uid);check(b.enemy().hp<hp and c not in b.hand,"Charged card really attacks and leaves hand")
    b=fixture();BattleWeather.apply(b,"sun");c=card(b,76);check(not b.card_view(c).get("preparing",false),"Sunny Solar Beam skips preparation")
    b=fixture();BattleWeather.apply(b,"rain");c=card(b,905);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(b.active().stat_stages.get("special_attack")==1 and hp-b.enemy().hp==v["preview_hp_loss"],"Rain Electro Shot boosts once before its immediate predicted attack")
    b=fixture();c=card(b,63);b.play_card(c.uid);c=card(b,33)
    check(b.card_reason(c.uid).contains("재충전"),"Hyper Beam blocks remaining same-actor techniques")
    b.end_turn();check(b.card_reason(c.uid).contains("손패") or b.card_reason(c.uid).contains("재충전"),"Recharge persists into the next player turn")
    c=card(b,33,b.party[1].uid);check(b.card_reason(c.uid).is_empty(),"Recharge permits another Pokemon's card")
    b.end_turn();c=card(b,33);check(b.card_reason(c.uid).is_empty(),"Recharge releases after next player turn ends")
    b=fixture(143,3);c=card(b,362);check(b.card_view(c)["move_power"]==65,"Brine baseline power")
    b.enemy().hp/=2;check(b.card_view(c)["move_power"]==130,"Brine doubles on actual half HP threshold")
    b=fixture();c=card(b,776);v=b.card_view(c);b.active().stat_stages["attack"]=6
    check(b.card_view(c)["preview_damage"]==v["preview_damage"],"Body Press ignores Attack stages")
    b.active().stat_stages["defense"]=2;check(b.card_view(c)["preview_damage"]>v["preview_damage"],"Body Press uses real Defense stages")
    b=fixture();c=card(b,69);v=b.card_view(c);b.enemy().stat_stages["defense"]=6;b.active().stat_stages["attack"]=-6
    check(v["preview_damage"]==50 and b.card_view(c)["preview_damage"]==50,"Seismic Toss is genuinely fixed level damage")
    b=fixture();b.active().hp/=2;cast(b,156)
    check(b.active().hp==b.active().max_hp and b.active().statuses.get("sleep",{}).get("turns")==3,"Rest fully heals then reserves two future player turns of sleep")
    b.active().learned_skills.assign(["move_34","move_156","move_214"]);c=card(b,214)
    check(b.card_view(c)["name"].contains("누르기") and b.play_card(c.uid).is_empty(),"Sleep Talk calls an owned eligible move while asleep")
    b=fixture();cast(b,182);hp=b.active().hp;b.end_turn()
    check(b.active().hp==hp,"Protect prevents an actual enemy attack")
    c=card(b,182);check(b.card_reason(c.uid).is_empty(),"Protect can be selected again on the following player turn")
    b=fixture();cast(b,164);hp=b.active().hp;var pool:int=PlayerMoveRules.read(b)["substitutes"][b.active().uid];b.end_turn()
    check(b.active().hp==hp and PlayerMoveRules.read(b)["substitutes"][b.active().uid]<=pool,"Player Substitute absorbs enemy damage into separate HP pool")
    b=fixture();var full:int=b.intent()["value"];cast(b,115)
    check(b.intent()["value"]==maxi(1,full/2),"Reflect changes actual enemy preview to half physical damage")
    hp=b.active().hp;b.end_turn();check(hp-b.active().hp==maxi(1,full/2),"Reflect's displayed reduction is executed once")
    b=fixture();full=b.intent()["value"];cast(b,29)
    check(b.intent()["value"]==maxi(1,floori(full*0.8)),"Headbutt flinch is visible20% attack suppression instead of a hidden roll")
    b=fixture();b.end_turn();c=card(b,68)
    check(b.card_view(c)["preview_damage"]>0,"Counter uses real last enemy-turn physical HP loss")
    b=fixture();b.active().block=10000;b.end_turn();c=card(b,68)
    check(b.card_view(c)["preview_damage"]==0,"Shield-only damage cannot fuel Counter")
    b=fixture();cast(b,370)
    check(b.active().stat_stages.get("defense")==-1 and b.active().stat_stages.get("special_defense")==-1 and not b.enemy().stat_stages.has("defense"),"Close Combat weakens its user, never the opponent")
    b=fixture();cast(b,369);check(b.manual_switch_cost()==0,"U-turn grants visible optional free manual switch")
    b=fixture();cast(b,116);c=card(b,33);check(b.card_view(c).get("critical",false),"Focus Energy gives next owned attack a guaranteed critical")
    matrix()
    print("Player move cards: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
func matrix() -> void:
    var pristine:=var_to_bytes(PlayerMoveCards.data())
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:=card(b,int(key));b.active().hp=maxi(1,b.active().max_hp*3/4)
        if int(key)==214:b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};b.active().learned_skills.assign(["move_33","move_214"])
        var before:=var_to_bytes(b.snapshot());var a:=b.card_view(c)
        check(a==b.card_view(c) and before==var_to_bytes(b.snapshot()),"Card browsing/preview is pure: "+key)
        check(not a["description"].is_empty() and not CardEffectText.render(a).is_empty(),"Every card has detailed and compact explanations: "+key)
        if PlayerMoveCards.data()["enhanced"].has(key):
            var why:=b.play_card(c.uid)
            check(why.is_empty() or not PlayerMoveRules.reason(b,b.active(),a).is_empty(),"Enhanced card executes or reports its real condition: "+key+why)
            check(b.party.all(func(p:BattlePokemon):return p.hp>=0 and p.hp<=p.max_hp) and b.enemies.all(func(p:BattlePokemon):return p.hp>=0 and p.hp<=p.max_hp),"All card HP side effects respect bounds: "+key)
    check(pristine==var_to_bytes(PlayerMoveCards.data()),"Frozen player-card data never mutates")
