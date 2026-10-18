extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=7
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"v15 card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func power(b:TacticalBattle,id:int) -> int:return int(b.card_view(card(b,id))["preview_damage"])
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveAltitude.data()["total_enhanced"]==396,"396 distinct enhanced moves")
    var immutable:=var_to_bytes(PlayerMoveAltitude.data())
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:=card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c),"Pure repeated preview/UID/RNG: "+key)
        check(v["player_rules"]==7 and not v["description"].is_empty() and not CardEffectText.render(v).is_empty(),"Full/compact v15 explanation: "+key)
        b.player_moves_version=6;check(v.get("preview_damage",-1)==b.card_view(c).get("preview_damage",-1),"Unmodified v14 damage without altitude effects: "+key)
    var b:=fixture(18,6);quiet(b);var types:=b.enemy().types.duplicate();check(power(b,89)==0,"Flying starts immune to Ground")
    cast(b,356);check(power(b,89)>0 and b.enemy().types==types and PlayerMoveAltitude.grounded(b,b.active()),"Gravity removes Flying Ground immunity while preserving actual types")
    for id:int in [19,26,136,150,340,393,477,507,560,731]:
        var c:=card(b,id);var state:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Gravity atomically refuses each pinned airborne move: "+str(id))
    cast(b,356);check(PlayerMoveAltitude.read(b)["gravity"]==5,"Gravity refreshes rather than toggles off")
    for i in 5:b.end_turn()
    check(power(b,89)==0 and PlayerMoveAltitude.read(b)["gravity"]==0,"Gravity expires after five enemy actions")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"ground","move_id":89}];var incoming:int=b.intent()["value"];cast(b,393)
    check(incoming>0 and b.intent()["value"]==0 and not PlayerMoveAltitude.grounded(b,b.active()),"Magnet Rise gives real Ground immunity and loses grounding")
    var hp:=b.active().hp;b.end_turn();check(b.active().hp==hp,"Lifted player takes no actual Ground attack damage")
    for i in 4:b.end_turn()
    check(b.intent()["value"]>0 and PlayerMoveAltitude.read(b)["rise"].is_empty(),"Magnet Rise expires exactly after five enemy actions")
    b=fixture();quiet(b);cast(b,393);cast(b,604);var plain:=power(b,85);check(not b.card_view(card(b,147)).has("sleep"),"Grounded foe retains Electric Terrain sleep protection")
    cast(b,356);check(power(b,85)>plain and PlayerMoveAltitude.read(b)["rise"].is_empty(),"Gravity cancels Rise and restores terrain attack boost")
    b=fixture();quiet(b);cast(b,393);cast(b,580);b.active().hp-=40;hp=b.active().hp;b.end_turn();check(b.active().hp==hp,"Floating player gets no Grassy Terrain recovery")
    cast(b,356);b.end_turn();check(b.active().hp>hp,"Grounding restores actual Grassy Terrain recovery")
    b=fixture();cast(b,393);cast(b,604);b.enemy_definitions[0]["intents"]=[{"kind":"status","value":2,"status":"burn","move_id":261}];cast(b,581);b.end_turn()
    check(b.active().statuses.has("burn"),"Floating player remains vulnerable to new statuses under Misty Terrain")
    b=fixture();cast(b,477);check(power(b,89)==0 and power(b,33)>0 and not PlayerMoveAltitude.grounded(b,b.enemy()),"Telekinesis lifts opponent without granting generic evasion")
    cast(b,678);check(b.card_reason(card(b,98).uid).is_empty(),"Floating target loses Psychic Terrain priority protection")
    cast(b,604);check(b.card_view(card(b,147)).has("sleep"),"Floating target loses Electric Terrain sleep protection")
    cast(b,581);check(b.card_view(card(b,261)).has("burn"),"Floating target loses Misty Terrain status protection")
    quiet(b)
    for i in 3:b.end_turn()
    check(PlayerMoveAltitude.read(b)["lift"].is_empty() and power(b,89)>0,"Telekinesis expires after three enemy actions")
    b=fixture();cast(b,393);b.energy=100;check(b.switch_to(b.party[1].uid).is_empty() and PlayerMoveAltitude.read(b)["rise"].is_empty(),"Voluntary switch clears outgoing Rise")
    b=fixture();cast(b,393);cast(b,275);check(PlayerMoveAltitude.read(b)["rise"].is_empty() and PlayerMoveAltitude.grounded(b,b.active()),"Ingrain cancels floating and forces grounding")
    var c:=card(b,393);var state:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Rooted user cannot Rise atomically")
    b=fixture();cast(b,477);cast(b,479);check(PlayerMoveAltitude.read(b)["lift"].is_empty() and PlayerMoveAltitude.grounded(b,b.enemy()),"Successful Smack Down cancels Telekinesis and grounds the target")
    b=fixture(143,241,"gym:whitney");BossBattleRules.write(b)["substitutes"][b.enemy().uid]=20;cast(b,477);check(PlayerMoveAltitude.read(b)["lift"].is_empty(),"Telekinesis respects opposing Substitute")
    BossBattleRules.write(b)["substitutes"].clear();BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,477);check(PlayerMoveAltitude.read(b)["lift"].is_empty(),"Telekinesis respects Protect")
    b=fixture(18);quiet(b);c=card(b,19);b.play_card(c.uid);check(PlayerMoveRules.read(b)["charges"].has(b.active().uid) and c.uid in b.retained,"Fly actually starts and retains its card")
    var gravity_card:=card(b,356,b.party[1].uid);b.play_card(gravity_card.uid)
    check(PlayerMoveRules.read(b)["charges"].is_empty() and c.uid not in b.retained,"Gravity clears air charge/retention after another owner's automatic switch")
    b=fixture();quiet(b);PlayerMoveRules.write(b)["charges"][b.party[1].uid]={"move":19,"ready":b.turn+1,"card":b.hand[0].uid};b.retained.append(b.hand[0].uid);cast(b,356)
    check(PlayerMoveRules.read(b)["charges"].is_empty(),"Global Gravity clears queued air charges across actors")
    b=fixture(18);cast(b,356);PlayerMoveFields.write(b)["hazards"]={"rocks":0,"spikes":3,"toxic":2,"web":1};var reserve:=b.party[1];hp=reserve.hp;b.energy=100;b.switch_to(reserve.uid)
    check(reserve.hp==hp-maxi(1,reserve.max_hp/4) and reserve.statuses.has("poison") and reserve.stat_stages.get("speed")==-1,"Gravity grounds Flying entrants for real Spikes/Toxic Spikes/Web")
    b=fixture(18,65,"gym:sabrina");cast(b,393);b.end_turn()
    check(b.boss_context.get("gravity",0)>0 and PlayerMoveAltitude.read(b)["rise"].is_empty() and PlayerMoveAltitude.grounded(b,b.active()),"Actual boss Gravity cancels new Rise")
    b=fixture(143,620,"elite:marshal");cast(b,356);hp=b.active().hp;var foe_hp:=b.enemy().hp
    check(b.intent().get("player_sealed",false),"Player Gravity previews authored NPC High Jump Kick cancellation")
    b.end_turn();check(b.active().hp==hp and b.enemy().hp==foe_hp,"Gravity-cancelled authored jump causes no damage or crash recoil")
    b=fixture(143,620,"elite:marshal")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==340:b.opening()["intent"]=i
    b.end_turn();check(b.boss_context.get("airborne",{}).get(b.enemy().uid,false),"Authored Bounce actually enters airborne preparation")
    cast(b,356);check(not b.boss_context.get("airborne",{}).has(b.enemy().uid) and b.intent().get("player_sealed",false),"Player Gravity cancels NPC airborne preparation and its queued attack")
    hp=b.active().hp;b.end_turn();check(b.active().hp==hp,"Cancelled NPC airborne attack never executes")
    b=fixture();cast(b,477);b.active().learned_skills.assign(["move_89","move_214"]);b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid}
    var called:=b.card_view(card(b,214));check(called["move_id"]==89 and called["player_rules"]==7 and called["preview_damage"]==0,"Sleep Talk inherits v15 Ground immunity and version")
    b=fixture();quiet(b);cast(b,356);PlayerMoveTactics.write(b)["hazards"]={"rocks":0,"spikes":3,"toxic":2,"web":1}
    var next:=BattlePokemon.new({"id":6,"name":"리자몽","type":"fire","types":["fire","flying"],"level":50,"max_hp":138},-2);PokemonStats.apply(next,true)
    b.enemies.append(next);b.enemy_definitions.append(b.enemy_definitions[0].duplicate(true));b.enemy_states.append(b.enemy_states[0].duplicate(true));hp=next.hp
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(b.enemy()==next and next.hp==hp-maxi(1,next.max_hp/4) and next.statuses.has("poison") and next.stat_stages.get("speed")==-1,"Gravity grounds the next Flying enemy for all three entry hazards")
    b=fixture(242,10191,"gym:mustard");cast(b,381);cast(b,477);cast(b,604)
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==818:b.opening()["intent"]=i
    check(b.intent().get("critical_blocked",false),"Air field adapter retains Lucky Chant's authored critical suppression")
    var frame:=BattleFrame.capture(b);check(frame["altitude_context"]==b.altitude_context,"Presentation snapshot includes detached altitude context")
    b._clear_statuses();check(b.altitude_context.is_empty() and b.party[0].types==["normal"],"Cleanup clears altitude without changing permanent types")
    check(var_to_bytes(PlayerMoveAltitude.data())==immutable,"Definitions stay immutable")
    h.free();print("Player move altitude: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
