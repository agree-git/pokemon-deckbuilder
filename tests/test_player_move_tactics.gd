extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=3
    return b
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:BattleCardInstance=h.card(b,id);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"v11 public card executes: "+str(id)+why)
    return v
func add(b:TacticalBattle,id:int) -> BattlePokemon:
    var s:=VisualCatalog.new().species(id)
    var d:Dictionary={"id":id,"name":s["name"],"types":s["types"],"type":s["types"][0],"max_hp":PokemonStats.value(id,50,"hp"),"level":50,"intents":[{"kind":"attack","value":10,"type":"normal","move_id":33}]}
    var p:=BattlePokemon.new(d,-1-b.enemies.size());b.enemies.append(p);b.enemy_definitions.append(d);b.enemy_states.append({"intent":0})
    return p
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveTactics.data()["moves"].size()==32 and PlayerMoveTactics.data()["total_enhanced"]==342,"32 overlay cards and342 enhanced move identities")
    var pristine:=var_to_bytes(PlayerMoveCards.data());var extra:=var_to_bytes(PlayerMoveTactics.data())
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:BattleCardInstance=h.card(b,int(key));var before:=var_to_bytes(b.snapshot());var view:=b.card_view(c)
        check(view==b.card_view(c) and before==var_to_bytes(b.snapshot()),"v11 card preview is pure and repeatable: "+key)
        check(view["player_rules"]==3 and not view["description"].is_empty() and not CardEffectText.render(view).is_empty(),"Overlay has actual rules, compact explanation, and tooltip: "+key)
        var old:=TacticalContent.definition(c,2)
        check(old["player_rules"]==2 and not old.has("extension"),"A v10 card never gains v11 mechanics: "+key)
    var b:=fixture();cast(b,446);cast(b,191);cast(b,390);cast(b,564)
    check(b.enemy().hp==b.enemy().max_hp,"Installing fields does not damage the current enemy")
    var next:=add(b,143);var maximum:=next.max_hp;var energy:=b.energy;var turn:=b.turn;var hand:=b.hand.duplicate()
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(next.hp==maximum-maxi(1,maximum/8)*2 and next.statuses.get("poison",{}).get("turns")==3 and next.stat_stages.get("speed")==-1,"Natural next enemy receives real Rock/Spikes/Poison/Web effects")
    check(b.energy==energy and b.turn==turn and b.hand==hand,"Entry hazards preserve player hand, turn and remaining energy")
    b=fixture();cast(b,446);cast(b,191);cast(b,390);cast(b,564);next=add(b,6);maximum=next.max_hp
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(next.hp==maximum-maxi(1,maximum/2) and not next.statuses.has("poison") and not next.stat_stages.has("speed"),"Flying Charizard takes fourfold Rock damage and avoids grounded hazards")
    b=fixture();cast(b,390);next=add(b,89);b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(PlayerMoveTactics.read(b)["hazards"]["toxic"]==0 and not next.statuses.has("poison"),"Grounded Poison entrant removes Toxic Spikes")
    b=fixture();cast(b,390);cast(b,390);next=add(b,143);b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(next.statuses.get("poison",{}).get("turns")==5,"Two Toxic Spikes layers use explicitly adapted five poison ticks")
    b=fixture();cast(b,446);var c:BattleCardInstance=h.card(b,446);var before:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Hazard cap refuses duplicate atomically")
    cast(b,432);check(PlayerMoveTactics.read(b)["hazards"]==PlayerMoveTactics.DEFAULT["hazards"],"Defog actually removes the new opposing fields")
    b=fixture();cast(b,446);add(b,6).hp=1;add(b,6).hp=1;next=add(b,143);energy=b.energy;turn=b.turn
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(b.enemy()==next and b.enemy_index==3 and b.phase==TacticalBattle.PLAYER and b.energy==energy and b.turn==turn,"Consecutive entry KOs finish before returning without extra actions or rewards")
    b=fixture();cast(b,20);var hp:=b.enemy().hp
    b.end_turn();check(b.enemy().hp==hp-maxi(1,b.enemy().max_hp/8),"Bind causes actual end-of-action fixed HP damage")
    b.switch_to(b.party[1].uid);check(PlayerMoveTactics.read(b)["binds"].is_empty(),"Binding ends when its player source switches")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"block","value":10,"type":"normal","move_id":182},{"kind":"attack","value":10,"type":"normal","move_id":33}]
    cast(b,269);check(b.intent().get("player_sealed",false),"Taunt visibly prevents an actual status move")
    hp=b.active().hp;b.end_turn();check(b.active().hp==hp and b.enemy().block==0 and not b.intent().get("player_sealed",false),"Taunted status action really fails while the next attack remains usable")
    b=fixture();b.end_turn();cast(b,50);check(b.intent().get("player_sealed",false),"Disable seals the last actual enemy move")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"normal","move_id":33},{"kind":"attack","value":10,"type":"fire","move_id":52}]
    b.end_turn();cast(b,227);check(b.intent().get("player_sealed",false),"Encore permits only the previous move rather than inventing a new action order")
    b.end_turn();check(not b.intent().get("player_sealed",false),"Encore allows the required last move when the authored pattern reaches it")
    b=fixture();b.end_turn();cast(b,259);check(b.intent().get("player_sealed",false),"Torment prevents consecutive successful use")
    b=fixture(143,830,"gym:milo");b.enemy().hp/=2
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==202:b.opening()["intent"]=i
    cast(b,377);hp=b.enemy().hp;b.end_turn()
    check(b.enemy().hp==hp,"Heal Block stops actual authored Giga Drain recovery while its damage still executes")
    b=fixture(143,350,"gym:wallace");b.enemy().hp/=2
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==105:b.opening()["intent"]=i
    cast(b,377);hp=b.enemy().hp;b.end_turn();check(b.enemy().hp==hp,"Pure Recover is blocked before it can heal")
    b=fixture();b.active().stat_stages={"attack":2,"defense":-1};cast(b,164);var pool:int=PlayerMoveRules.read(b)["substitutes"][b.active().uid]
    cast(b,226);check(b.manual_switch_cost()==0,"Baton Pass makes the next voluntary switch free")
    b.switch_to(b.party[1].uid)
    check(b.active().stat_stages=={"attack":2,"defense":-1} and PlayerMoveRules.read(b)["substitutes"].get(b.active().uid)==pool and PlayerMoveTactics.read(b)["pass"].is_empty(),"Baton Pass transfers both signs of stages and real substitute HP exactly once")
    b=fixture();hp=b.active().hp;cast(b,880);var payer:=b.active();b.switch_to(b.party[1].uid)
    check(payer.hp==hp-maxi(1,payer.max_hp/2) and PlayerMoveRules.read(b)["substitutes"].get(b.active().uid)==maxi(1,payer.max_hp/4),"Shed Tail really pays half HP and transfers a quarter-HP substitute")
    b=fixture();cast(b,881);check(BattleWeather.kind(b.powers)=="snow" and b.manual_switch_cost()==0,"Chilly Reception combines real snow and the optional pivot")
    b=fixture();b.active().hp=20;b.enemy().hp=80;cast(b,220)
    check(b.active().hp==50 and b.enemy().hp==50,"Pain Split equalizes actual HP rather than adding a generic shield")
    b=fixture();b.active().hp=1;var attack:=PokemonStats.effective(b.enemy(),"attack");cast(b,668)
    check(b.active().hp==mini(b.active().max_hp,1+attack) and b.enemy().stat_stages.get("attack")==-1,"Strength Sap heals from the original real Attack and then lowers it")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"normal","move_id":33},{"kind":"attack","value":10,"type":"fire","move_id":52}]
    var defs:=b.enemy_definitions.duplicate(true);cast(b,46)
    check(b.intent()["move_id"]==52 and b.enemy_definitions==defs,"Phasing advances the real intent while preserving the approved party definitions")
    c=h.card(b,18);before=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"One tactical shove per foe per player turn is enforced atomically")
    b=fixture();b.active().learned_skills.assign(["move_20","move_214"]);b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid}
    cast(b,214);check(PlayerMoveTactics.read(b)["binds"].has(b.enemy().uid),"Sleep Talk preserves the called move's new binding identity")
    b=fixture(143,545,"gym:roxie");BossBattleRules.write(b)["guards"][b.enemy().uid]="protect"
    cast(b,575);check(not PlayerMoveRules.pivot_free(b),"Parting Shot blocked by Protect cannot grant a free pivot after its stat fields are filtered")
    PlayerMoveTactics.write(b)["hazards"]["rocks"]=1;PlayerMoveRules.write(b)["screen"]=3
    cast(b,432);check(PlayerMoveTactics.read(b)["hazards"]["rocks"]==1 and PlayerMoveRules.read(b)["screen"]==3,"Blocked Defog cannot erase either side of the new field rules")
    b=fixture(143,208,"gym:jasmine");b.active().stat_stages["attack"]=2;cast(b,226)
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==46:b.opening()["intent"]=i
    b.end_turn();check(b.active()!=b.party[0] and not b.active().stat_stages.has("attack"),"Ending the player turn expires Baton transfer before an enemy's forced switch")
    b=fixture(143,460,"gym:candice");cast(b,377);b.enemy().hp/=2;hp=b.enemy().hp
    BossBattleRules.write(b)["roots"][b.enemy().uid]=true;PlayerMoveRules.write(b)["curses"][b.enemy().uid]=b.active().uid
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==275:b.opening()["intent"]=i
    b.end_turn();check(b.enemy().hp==hp-maxi(1,b.enemy().max_hp/4),"Heal Block removes root healing before later Curse damage can hide the HP gain")
    check(pristine==var_to_bytes(PlayerMoveCards.data()) and extra==var_to_bytes(PlayerMoveTactics.data()),"All shared input data remains immutable")
    h.free();print("Player move tactics: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
