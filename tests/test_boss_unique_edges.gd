extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:
    var h=load(get_script().resource_path.get_base_dir().path_join("test_boss_move_effects_p3.gd")).new()
    var b:TacticalBattle=h.fixture("elite:marshal",620)
    h.select_move(b,340)
    var c:BattleCardInstance=h.card(b,239);var full:int=b.card_view(c)["preview_damage"]
    h.step(b);check(b.card_view(c)["preview_damage"]==full*2,"Twister doubles against airborne Bounce")
    c=h.card(b,479);b.play_card(c.uid)
    check(not BossBattleEffectsP3.read(b)["airborne"].has(b.enemy().uid) and b.intent().get("failed_move",false),"Smack Down cancels the airborne attack")
    var hp:=b.active().hp;h.step(b)
    check(b.active().hp==hp and not BossMoveEffectsP3.state(b)["air_cancel"],"Canceled Bounce never attacks or charges again in that action")
    b=h.fixture("gym:morty",94);h.select_move(b,194);h.step(b)
    b.enemies.append(BattlePokemon.new(h.definition("gym:morty",94),-2));b.enemy_definitions.append(h.definition("gym:morty",94));b.enemy_states.append({"intent":0})
    b.enemy().hp=1;c=h.card(b,247);b.play_card(c.uid)
    check(b.phase==TacticalBattle.REPLACE and b._pending=="card","Direct Destiny Bond double knockout requests immediate same-turn replacement")
    var energy:=b.energy;var turn:=b.turn;var cards:=b.hand.size();b.switch_to(b.party[1].uid)
    check(b.phase==TacticalBattle.PLAYER and b.energy==energy and b.turn==turn and b.hand.size()==cards,"Card knockout replacement never grants energy, turn or cards twice")
    b=h.fixture("gym:whitney",241);h.select_move(b,213);h.step(b)
    b.end_turn()
    check(BossBattleEffectsP3.read(b)["infatuation"].has(b.active().uid),"Attract remains through the second following player turn")
    b.end_turn();check(not BossBattleEffectsP3.read(b)["infatuation"].has(b.active().uid),"Attract expires at the end of its final player turn")
    b=h.fixture("gym:piers",862);h.select_move(b,675);h.step(b);b.end_turn();b.end_turn()
    c=h.card(b,304);check(b.card_reason(c.uid).is_empty(),"Throat Chop releases sound cards after two player-end ticks")
    b=h.fixture("gym:nessa",834);h.select_move(b,746);h.step(b)
    b.enemies.append(BattlePokemon.new(h.definition("gym:nessa",834),-2));b.enemy_definitions.append(h.definition("gym:nessa",834));b.enemy_states.append({"intent":0})
    b.enemy().hp=1;b.energy=3
    check(b.capture_enemy().is_empty() and not BossBattleEffectsP3.trapped(b) and BossBattleEffectsP3.read(b)["traps"].is_empty(),"Capturing the trapper also releases all traps immediately")
    b=h.fixture("elite:marshal",620);h.select_move(b,136)
    BossBattleEffectsP3.write(b)["gravity"]=5
    var own_hp:=b.enemy().hp;h.step(b)
    check(b.enemy().hp==own_hp,"Gravity makes High Jump Kick unavailable without a crash")
    b=h.fixture("gym:morty",94);h.select_move(b,194);h.step(b)
    b.enemy().hp=1;b.active().hp/=2;c=h.card(b,202)
    check(b.card_view(c).has("heal"),"Destiny Bond regression uses a real draining card")
    b.play_card(c.uid)
    check(b.party[0].hp==0 and b.party[0].knocked_out,"A draining card cannot revive its user after Destiny Bond knockout")
    var board:=BossBattleEffectsP3.DEFAULT.duplicate(true)
    var shape:Dictionary={"enemy_definitions":[h.definition("gym:nessa",834)],"party":[1],"enemies":[-1],"turn":1}
    board["bond_pending"]=1
    check(not BossBattleEffectsP3.valid_context(board,shape),"Saved checkpoints cannot inject a pending forced knockout")
    board["bond_pending"]=0;board["card_attacker"]=1
    check(not BossBattleEffectsP3.valid_context(board,shape),"Saved checkpoints cannot claim a card is still executing")
    h.free()
    print("Boss unique edges: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
