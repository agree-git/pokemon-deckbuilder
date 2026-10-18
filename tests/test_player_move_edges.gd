extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:
    var h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    var b:TacticalBattle=h.fixture();var c:BattleCardInstance
    h.cast(b,254);h.cast(b,254)
    check(PlayerMoveRules.read(b)["stocks"].get(b.active().uid)==2 and b.active().stat_stages.get("defense")==2,"Stockpile records two real defense-bearing stocks")
    b.active().hp=1;var hp:=b.active().hp;c=h.card(b,256);var v:=b.card_view(c);b.play_card(c.uid)
    check(v["heal"]==24 and b.active().hp==hp+PokemonStats.scale(b.active(),24) and not PlayerMoveRules.read(b)["stocks"].has(b.active().uid) and b.active().stat_stages.get("defense",0)==0,"Swallow consumes stocks, heals50%, and removes only stock defense")
    b=h.fixture();h.cast(b,254);c=h.card(b,255);check(b.card_view(c)["move_power"]==100,"Spit Up power uses actual stocks")
    b=h.fixture();b.active().hp/=2;hp=b.active().hp;h.cast(b,273);check(b.active().hp==hp,"Wish is delayed rather than immediate Recover")
    b.end_turn();check(b.active().hp>hp and not PlayerMoveRules.read(b)["wishes"].has(b.active().uid),"Wish resolves once on next player turn")
    b=h.fixture(6);h.cast(b,275);c=h.card(b,33,b.party[2].uid)
    var before:=var_to_bytes(b.snapshot());check(not b.switch_to(b.party[2].uid).is_empty() and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Ingrain prevents manual and owned-card automatic switch atomically")
    check(b.multiplier("ground",b.active())==2,"Rooted Charizard is grounded without changing species types")
    b=h.fixture(94);h.cast(b,275);check(b.switch_reason(b.party[1].uid).is_empty(),"Ghost Pokemon can escape their own roots")
    b=h.fixture();h.cast(b,213);var full:int=b.intent()["value"]
    b.switch_to(b.party[1].uid);check(not PlayerMoveRules.read(b)["infatuation"].has(b.enemy().uid),"Attract ends when its player source leaves the field")
    b=h.fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"normal","move_id":304}]
    h.cast(b,675);check(b.intent().get("player_sealed",false),"Throat Chop publicly seals sound-based enemy moves")
    hp=b.active().hp;b.end_turn();check(b.active().hp==hp,"Sealed sound attack really loses its enemy action")
    b=h.fixture();b.end_turn();h.cast(b,826)
    check(b.intent().get("player_sealed",false),"Eerie Spell seals the actual last enemy technique")
    b=h.fixture();var affinity:=b.multiplier("fire",b.enemy());h.cast(b,749)
    check(b.multiplier("fire",b.enemy())==affinity*2 and b.enemy().stat_stages.get("speed")==-1,"Tar Shot changes real Fire effectiveness and Speed")
    b=h.fixture();h.cast(b,194);b.active().hp=1;b.end_turn()
    check(not b.party[0].alive() and not b.enemies[0].alive(),"Player Destiny Bond knocks out the actual direct attacker")
    b=h.fixture(923);h.cast(b,892);c=h.card(b,892)
    check(b.card_view(c).get("failed",false) and b.multiplier("ground",b.active())==1,"Double Shock consumes Electric type and fails on repeat")
    b.switch_to(b.party[1].uid);b.switch_to(b.party[0].uid);c=h.card(b,892)
    check(not b.card_view(c).get("failed",false) and b.multiplier("ground",b.active())==2,"Switching restores the consumed Electric type")
    b=h.fixture();full=b.intent()["value"];h.cast(b,862)
    check(b.intent()["value"]==full*2,"Player Glaive Rush exposes its user to double incoming damage")
    h.cast(b,33);check(not PlayerMoveRules.read(b)["vulnerable"].has(b.active().uid),"The next owned technique ends Glaive vulnerability")
    b=h.fixture();h.cast(b,893);c=h.card(b,893);check(b.card_view(c).get("failed",false),"Player Gigaton Hammer cannot be used consecutively after success")
    b=h.fixture();h.cast(b,690);b.end_turn();check(b.enemy().statuses.has("burn"),"Player Beak Blast burns a real contact attacker")
    b=h.fixture();h.cast(b,19);hp=b.active().hp;b.end_turn()
    check(b.active().hp==hp,"Fly's actual charging phase evades ordinary enemy attacks")
    check(not b.intent().get("player_airborne",false),"Keeping a ready Fly card does not grant permanent evasion")
    b=h.fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"ground","move_id":89}];full=b.intent()["value"];h.cast(b,91)
    check(b.intent()["value"]==full*2,"Earthquake doubles against a player using Dig")
    b=h.fixture(143,230,"gym:clair");h.cast(b,219);b.end_turn()
    check(not b.boss_context.get("drowsy",{}).has(b.party[0].uid),"Player Safeguard blocks authored boss Yawn's delayed marker")
    b=h.fixture(143,94,"gym:morty");h.cast(b,164)
    b.opening()["intent"]=1;var stage:=b.active().stat_stages.duplicate();b.end_turn()
    check(b.active().stat_stages==stage,"Player Substitute blocks authored Shadow Ball's secondary SpDef drop")
    b=h.fixture(143,545,"gym:roxie")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==182:b.opening()["intent"]=i
    b.end_turn();h.cast(b,281)
    check(not PlayerMoveRules.read(b)["yawn"].has(b.enemy().uid),"Player Yawn respects authored boss Protect")
    b=h.fixture(143,94,"gym:morty");b.opening()["intent"]=3;b.end_turn();b.enemy().block=0;b.enemy().hp=1;b.active().hp/=2;h.cast(b,202)
    check(not b.party[0].alive(),"Real player drain never revives its owner after enemy Destiny Bond")
    b=h.fixture();h.cast(b,182);c=h.card(b,182);before=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"A second Protect in the same turn is rejected with no resources spent")
    b=h.fixture(143,94,"gym:morty");b.enemy().statuses["poison"]={"turns":3,"source_uid":b.active().uid}
    BossBattleRules.write(b)["substitutes"][b.enemy().uid]=20;b.active().hp/=2;hp=b.active().hp
    h.cast(b,685)
    check(b.active().hp==hp and b.enemy().statuses.has("poison"),"Purify cannot heal through a target's Substitute")
    b=h.fixture();h.cast(b,596);h.cast(b,826)
    PlayerMoveRules.write(b)["seals"][b.enemy().uid]={"move":33,"until":b.turn+2}
    hp=b.enemy().hp;b.end_turn()
    check(b.enemy().hp==hp,"A sealed contact move never triggers Spiky Shield contact retaliation")
    b=h.fixture();b.relics.append("shield_core");b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"type":"normal","move_id":150}]
    b.active().hp/=2;hp=b.active().hp;h.cast(b,392);b.end_turn()
    check(b.active().hp==hp+floori(maxi(1,b.active().max_hp/16)*0.5),"Aqua Ring respects the existing Shield Core healing penalty")
    b=h.fixture(143,94,"gym:morty");BossBattleRules.write(b)["safeguard"]=5;h.cast(b,281)
    check(not PlayerMoveRules.read(b)["yawn"].has(b.enemy().uid),"Enemy Safeguard blocks the player's delayed Yawn marker")
    b=h.fixture(143,94,"gym:morty");BossBattleRules.write(b)["airborne"][b.enemy().uid]=true;h.cast(b,213)
    check(not PlayerMoveRules.read(b)["infatuation"].has(b.enemy().uid),"A targeted player Attract cannot reach an airborne boss")
    h.free()
    print("Player move edges: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
