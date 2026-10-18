extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=4
    return b
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:BattleCardInstance=h.card(b,id);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"v12 public card executes: "+str(id)+why)
    return v
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveExchange.data()["moves"].size()==30 and PlayerMoveExchange.data()["total_enhanced"]==371,"30 more cards and371 distinct enhanced moves")
    var unchanged:=var_to_bytes(PlayerMoveExchange.data());var old:TacticalBattle=h.fixture();old.player_moves_version=3
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:BattleCardInstance=h.card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c),"v12 card preview preserves state/UID/RNG: "+key)
        check(v["player_rules"]==4 and not v["description"].is_empty() and not CardEffectText.render(v).is_empty(),"Every v12 card has full and compact explanations: "+key)
        if not PlayerMoveExchange.data()["moves"].has(key):check(v.get("preview_damage",-1)==old.card_view(c).get("preview_damage",-1),"Unchanged attacks preserve v11 damage without modifiers: "+key)
    var b:=fixture();b.active().stat_stages={"attack":2,"special_attack":-1,"speed":1};b.enemy().stat_stages={"attack":-3,"special_attack":4,"speed":-2};cast(b,384)
    check(b.active().stat_stages["attack"]==-3 and b.active().stat_stages["special_attack"]==4 and b.enemy().stat_stages["attack"]==2 and b.active().stat_stages["speed"]==1,"Power Swap exchanges both signs of offense stages only")
    cast(b,391);check(b.active().stat_stages.get("speed")==-2 and b.enemy().stat_stages.get("speed")==1,"Heart Swap includes Speed and preserves separate stage maps")
    cast(b,244);var other:=b.enemy().stat_stages.duplicate();b.active().stat_stages["attack"]=6;check(b.enemy().stat_stages==other,"Psych Up copies values without sharing the enemy dictionary")
    cast(b,576);check(b.enemy().stat_stages.get("attack")==-int(other.get("attack",0)),"Topsy Turvy inverts stages rather than giving a shield")
    b=fixture();var a:=b.active().attack;var d:=b.active().defense;var hp:=b.active().hp;b.active().stat_stages["attack"]=2;cast(b,379)
    check(b.active().attack==d and b.active().defense==a and b.active().stat_stages["attack"]==2 and b.active().hp==hp,"Power Trick swaps actual base combat stats while keeping HP and stages")
    var frame:=BattleFrame.capture(b);var visible:=BattleFrame.restore(frame["party"][0]);check(visible.battle_stats==b.active().battle_stats and visible.attack==b.active().attack,"Presentation frames retain modified stat values")
    b.switch_to(b.party[1].uid);check(b.party[0].attack==a and b.party[0].battle_stats.is_empty(),"Leaving the field restores original species/level stats")
    b=fixture(213,143);a=b.active().attack;d=b.enemy().attack;cast(b,471)
    check(b.active().attack==(a+d)/2 and b.enemy().attack==(a+d)/2,"Power Split averages actual Attack values on both sides")
    a=b.active().defense;d=b.enemy().defense;cast(b,470);check(b.active().defense==(a+d)/2 and b.enemy().defense==(a+d)/2,"Guard Split averages real Defense values")
    var speed:=b.active().speed;var foe_speed:=b.enemy().speed;var cached:=b.turn_speed_actor;cast(b,683)
    check(b.active().speed==foe_speed and b.enemy().speed==speed and b.turn_speed_actor==cached,"Speed Swap changes future speed comparisons without granting energy again")
    b=fixture(143,487);b.enemy().stat_stages={"attack":1,"defense":2,"speed":1};var c:BattleCardInstance=h.card(b,712);var v:=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(hp-b.enemy().hp==v["preview_hp_loss"] and b.active().stat_stages.get("attack")==1 and b.enemy().stat_stages.get("defense",0)==0,"Spectral Thief steals positive stages before its previewed actual attack")
    b=fixture(143,6);b.enemy_definitions[0]["intents"][0]={"kind":"attack","value":10,"type":"fire","move_id":52};var incoming:int=b.intent()["value"];hp=b.enemy().hp;cast(b,487)
    check(b.enemy().types==["water"] and b.multiplier("ground",b.enemy())==1 and b.enemy().hp==hp and b.intent()["value"]<incoming,"Soak changes actual type immunity and enemy STAB without changing HP")
    cast(b,567);cast(b,571);check(b.enemy().types==["water","grass"],"Newly added third type replaces the previous added type")
    b=fixture(143,6);cast(b,567);check(b.enemy().types==["fire","flying","ghost"],"Trick-or-Treat supports three actual combat types")
    cast(b,571);check(b.enemy().types==["fire","flying","grass"],"Forest's Curse replaces the additional type and keeps native types")
    b=fixture(143,3);var native:=b.enemy().types.duplicate();cast(b,750);check(b.enemy().types==native,"Grass Pokemon block Magic Powder")
    b=fixture(143,25);c=h.card(b,85);var plain:int=b.card_view(c)["preview_damage"];cast(b,513)
    check(b.active().types==["electric"] and b.card_view(c)["preview_damage"]>plain,"Reflect Type immediately changes the user's real STAB")
    b.switch_to(b.party[1].uid);check(b.party[0].types==["normal"],"Switching clears temporary type copying")
    b=fixture();b.active().learned_skills.assign(["move_85"]);cast(b,160)
    check(b.active().types==["electric"],"Conversion uses the first learned move's actual type")
    b=fixture();b.enemy_definitions[0]["intents"][0]={"kind":"attack","value":10,"type":"normal","move_id":165};b.end_turn();c=h.card(b,176);var blocked_state:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and blocked_state==var_to_bytes(b.snapshot()),"Conversion2 cannot claim resistance to this game's typeless Struggle")
    b=fixture(6);b.active().hp/=2;cast(b,355);check(b.multiplier("ground",b.active())==2,"Roost grounds Charizard for the enemy action")
    b.end_turn();check(b.multiplier("ground",b.active())==0 and b.active().types==["fire","flying"],"Roost restores Flying before the next player turn")
    b=fixture(59);cast(b,682);check(b.active().types.is_empty(),"Burn Up can leave a pure Fire user typeless")
    c=h.card(b,682);var before:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Burn Up without Fire is an atomic refusal")
    BattleWeather.apply(b,"sun");cast(b,293);check(b.active().types==["fire"],"Camouflage restores a usable Fire type in sun")
    b=fixture();b.active().statuses["burn"]={"turns":3,"source_uid":b.enemy().uid};cast(b,375)
    check(not b.active().statuses.has("burn") and b.enemy().statuses.has("burn"),"Psycho Shift transfers a real primary status and cures its user")
    b=fixture(143,6);b.active().statuses["burn"]={"turns":3,"source_uid":b.enemy().uid};c=h.card(b,375);before=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Status transfer respects current type immunity atomically")
    cast(b,487);cast(b,375);check(b.enemy().statuses.has("burn"),"Soak removes Fire status immunity for subsequent Psycho Shift")
    b=fixture();b.end_turn();c=h.card(b,102);v=b.card_view(c);var next_uid:=b._next_uid;var hand:=b.hand.size();b.play_card(c.uid)
    check(v["move_id"]==33 and v["key"]=="move_102" and b._next_uid==next_uid and b.hand.size()==hand-1 and c in b.discard,"Mimic executes the copied move using the original card and UID")
    v=cast(b,119);check(v["move_id"]==33,"Mirror Move copies an eligible last enemy attack")
    v=cast(b,383);check(v["move_id"]==33,"Copycat reads the actual last used attack on either side")
    v=cast(b,689);check(v["move_id"]==33,"Instruct repeats this user's actual previous attack")
    b=fixture();b.enemy_definitions[0]["intents"][0]={"kind":"attack","value":10,"type":"fire","move_id":52};c=h.card(b,382);v=b.card_view(c)
    check(v["move_id"]==52 and v.get("copy_boost",false),"Me First uses the publicly telegraphed attack with its distinct bonus")
    b=fixture();b.end_turn();cast(b,166);b.enemy_definitions[0]["intents"][0]={"kind":"attack","value":10,"type":"fire","move_id":52};b.end_turn();c=h.card(b,166)
    check(b.card_view(c)["move_id"]==33 and b.card_view(c).get("exhaust",false),"Sketch remembers its first attack for this battle and exhausts")
    c=h.card(b,102);check(b.card_view(c)["move_id"]==52,"Mimic follows the changed enemy record instead of Sketch's locked record")
    b=fixture();c=h.card(b,118);v=b.card_view(c);before=var_to_bytes(b.snapshot());check(v==b.card_view(c) and before==var_to_bytes(b.snapshot()),"Metronome's public selection is stable while browsing")
    b.play_card(c.uid);c=h.card(b,118);check(b.card_view(c)["move_id"]!=v["move_id"] and PlayerMoveExchange.read(b)["calls"].get(b.active().uid)==1,"Metronome advances only when used")
    b=fixture();BattleWeather.apply(b,"rain");c=h.card(b,267);check(b.card_view(c)["move_id"]==57,"Nature Power calls Surf in rain")
    b.party[1].learned_skills.assign(["move_55"]);c=h.card(b,274);v=b.card_view(c);check(v["move_id"]==55 and v["owner_uid"]==b.active().uid,"Assist borrows a living ally's learned attack while keeping its current user")
    b=fixture();b.enemy_definitions[0]["intents"][0]={"kind":"attack","value":10,"type":"normal","move_id":20};b.end_turn();cast(b,102)
    check(PlayerMoveTactics.read(b)["binds"].has(b.enemy().uid),"Copied attacks keep their v11 binding effects")
    b=fixture();b.active().learned_skills.assign(["move_712","move_214"]);b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};b.enemy().types.assign(["ghost"]);b.enemy().stat_stages["attack"]=1
    cast(b,214);check(b.active().stat_stages.get("attack")==1,"Sleep Talk preserves the new Spectral Thief identity")
    b=fixture(213,10191,"gym:mustard")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==818:b.opening()["intent"]=i
    var original_incoming:int=b.intent()["value"];cast(b,470);var changed_incoming:int=b.intent()["value"]
    check(changed_incoming>original_incoming,"Authored guaranteed critical multi-hit respects Guard Split after cloning its target")
    b.active().block=10000;var actor_uid:=b.active().uid;b.end_turn();var actual:=0
    for e:Dictionary in b.events:
        if e["kind"]=="damage" and e.get("target",0)==actor_uid:actual+=int(e.get("amount",0))+int(e.get("blocked",0))
    check(actual==changed_incoming,"Recomputed critical preview is exactly what the frozen enemy engine executes")
    b=fixture(892);c=h.card(b,817);var original_critical:int=b.card_view(c)["preview_damage"];cast(b,379)
    check(b.card_view(c)["preview_damage"]<original_critical,"Player critical cloning retains temporary base Attack changes")
    check(unchanged==var_to_bytes(PlayerMoveExchange.data()),"Exchange data is immutable across previews and execution")
    h.free();print("Player move exchange: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
