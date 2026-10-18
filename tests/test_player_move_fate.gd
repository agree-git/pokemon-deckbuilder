extends SceneTree
# One focused suite: residual/KO/replacement effects and actual journey saves.
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,foe,boss);b.player_moves_version=11
    return b
func card(b:TacticalBattle,id:int) -> BattleCardInstance:return h.card(b,id)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func sleep_on(b:TacticalBattle,left:=5) -> void:b.enemy().statuses["sleep"]={"turns":left,"source_uid":b.active().uid}
func extend(b:TacticalBattle) -> void:
    b.enemy_definitions.append(b.enemy_definitions[0].duplicate(true))
    var p:=BattlePokemon.new(b.enemy_definitions[1],-2);PokemonStats.apply(p,true)
    b.enemies.append(p);b.enemy_states.append({"intent":0})
func journey(v:=19) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,v)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey card executes")
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state)
    check(JourneySnapshot.validate(state),"Live fate checkpoint validates")
    if not JourneySnapshot.validate(state):return null
    var copy:=JourneySnapshot.restore(state)
    check(JourneySnapshot.encode(copy)==state and j.battle.snapshot()==copy.battle.snapshot() and var_to_bytes(state)==bytes,"Restore matches without mutating input")
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==19 and PlayerMoveFate.data()["moves"].size()==4 and PlayerMoveFate.data()["total_enhanced"]==423,"Four overlays /423 enhanced")
    var immutable:=var_to_bytes(PlayerMoveFate.data())
    for id:int in [171,195,361,461]:
        var b:=fixture();sleep_on(b);var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==11 and not v.has("block"),"Changed card preview is pure and removes placeholder shield")
        c.upgraded=true;var upgraded:=b.card_view(c)
        check(upgraded["fate_rule"]==v["fate_rule"] and upgraded["cost"]==maxi(0,int(v["cost"])-1) and not CardEffectText.render(upgraded).is_empty(),"Upgrade/text retain feature and reduce cost")
    var b:=fixture();var c:=card(b,171);var before:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Awake Nightmare is an atomic refusal")
    sleep_on(b,2);cast(b,171);var hp:=b.enemy().hp;var hit:=maxi(1,b.enemy().max_hp/4)
    b.end_turn();check(hp-b.enemy().hp==hit and PlayerMoveFate.read(b)["nightmare"].has(b.enemy().uid),"Nightmare deals maxHP quarter while sleeping")
    hp=b.enemy().hp;b.end_turn();check(hp-b.enemy().hp==hit and not b.enemy().statuses.has("sleep") and PlayerMoveFate.read(b)["nightmare"].is_empty(),"Final sleeping tick deals damage then wakes and clears mark")
    hp=b.enemy().hp;b.end_turn();check(b.enemy().hp==hp,"Waking stops further Nightmare damage")
    b=fixture();sleep_on(b);cast(b,171);b.switch_to(b.party[1].uid);hp=b.enemy().hp;b.end_turn()
    check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/4),"Source switching does not remove target's Nightmare")
    b.enemy().statuses.erase("sleep");hp=b.enemy().hp;b.end_turn();check(b.enemy().hp==hp and PlayerMoveFate.read(b)["nightmare"].is_empty(),"External sleep cure stops and removes Nightmare")
    for mode:String in ["protect","sub","air"]:
        b=fixture(241,"gym:whitney");sleep_on(b)
        if mode=="protect":BossBattleRules.write(b)["guards"][b.enemy().uid]="protect"
        elif mode=="sub":BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000
        else:BossBattleRules.write(b)["airborne"][b.enemy().uid]=true
        cast(b,171);check(PlayerMoveFate.read(b)["nightmare"].is_empty(),"Nightmare application respects guard/substitute/aerial evasion")
    b=fixture(241,"gym:whitney");sleep_on(b);cast(b,171);b.enemy().block=1000;BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000;hp=b.enemy().hp;b._tick(b.enemy())
    check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/4) and b.enemy().block==1000 and b.boss_context["substitutes"][b.enemy().uid]==1000,"Installed Nightmare residual bypasses shield/substitute")
    b=fixture();quiet(b);cast(b,195);var source:=b.active();var foe:=b.enemy()
    check(PlayerMoveFate.read(b)["perish"]=={source.uid:3,foe.uid:3},"Perish marks both currently present members")
    b.end_turn();cast(b,195);check(PlayerMoveFate.read(b)["perish"][source.uid]==2 and PlayerMoveFate.read(b)["perish"][foe.uid]==2,"Recasting does not reset existing countdown")
    b.switch_to(b.party[1].uid);check(not PlayerMoveFate.read(b)["perish"].has(source.uid) and PlayerMoveFate.read(b)["perish"][foe.uid]==2,"Switching clears only departing member's Perish counter")
    b.end_turn();check(foe.alive() and PlayerMoveFate.read(b)["perish"][foe.uid]==1,"Perish remains through second round")
    b.end_turn();check(not foe.alive() and b.phase==TacticalBattle.WON and b.active().alive(),"Third round causes KO, not direct attack damage")
    b=fixture(94,"gym:morty");BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";BossBattleRules.write(b)["substitutes"][b.enemy().uid]=1000;BossBattleRules.write(b)["airborne"][b.enemy().uid]=true;cast(b,195)
    check(PlayerMoveFate.read(b)["perish"].size()==2,"Global sound ignores Protect/substitute/aerial and Normal type immunity")
    b=fixture();quiet(b);extend(b);cast(b,195);source=b.active();foe=b.enemy()
    for i in 3:b.end_turn()
    check(not source.alive() and not foe.alive() and b.enemy_index==1 and b.phase==TacticalBattle.REPLACE and b._pending=="player","Simultaneous Perish resolves both before advancing enemy and forced replacement")
    b.switch_to(b.party[1].uid);check(b.phase==TacticalBattle.PLAYER and b.turn==4 and PlayerMoveFate.read(b)["perish"].is_empty(),"Forced replacement resumes once; next foe inherits no count")
    b=fixture();quiet(b);b.party[1].hp=0;b.party[2].hp=0;cast(b,195);source=b.active();foe=b.enemy()
    for i in 3:b.end_turn()
    check(not source.alive() and not foe.alive() and b.phase==TacticalBattle.LOST,"Final simultaneous KO preserves existing player-loss priority")
    for id:int in [361,461]:
        b=fixture();source=b.active();var ally:=b.party[1];ally.hp=1;ally.statuses["poison"]={"turns":3,"source_uid":b.enemy().uid};c=card(b,id);b.play_card(c.uid)
        check(not source.alive() and b.phase==TacticalBattle.REPLACE and b._pending=="card" and c in b.exhausted and PlayerMoveFate.read(b)["wish"]==id,"Healing sacrifice KOs owner and preserves replacement wish/played card")
        b.switch_to(ally.uid);check(ally.hp==ally.max_hp and ally.statuses.is_empty() and b.phase==TacticalBattle.PLAYER and PlayerMoveFate.read(b)["wish"]==0,"Next living ally receives healing/cure and resumes same turn")
        ally.hp-=5;b.switch_to(b.party[2].uid);b.switch_to(ally.uid);check(ally.hp==ally.max_hp-5,"Wish is consumed exactly once")
        b=fixture();b.party[1].hp=0;b.party[2].hp=0;c=card(b,id);before=var_to_bytes(b.snapshot())
        check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Sacrifice cannot revive dead reserves or spend last living ally")
    b=fixture();b.relics.append("shield_core");var ally:=b.party[1];ally.hp=1;hp=ally.hp;cast(b,361);b.switch_to(ally.uid)
    check(ally.hp==hp+floori((ally.max_hp-hp)*0.5),"Replacement healing preserves existing healing-reduction relic")
    b=fixture();ally=b.party[1];ally.hp=1;PlayerMoveTactics.write(b)["heal_block"][ally.uid]=b.turn+4;cast(b,461);b.switch_to(ally.uid)
    check(ally.hp==1 and PlayerMoveFate.read(b)["wish"]==0,"Heal Block prevents HP recovery and consumes wish without revival")
    b=fixture(241,"gym:whitney");BossBattleRules.write(b)["rocks"]=true;b.party[1].hp=1;b.party[2].hp=1;cast(b,361);b.switch_to(b.party[1].uid)
    check(not b.party[1].alive() and b.phase==TacticalBattle.REPLACE and PlayerMoveFate.read(b)["wish"]==361,"Entry hazard KO keeps wish pending for a surviving replacement")
    b.party[2].hp=b.party[2].max_hp/2;b.switch_to(b.party[2].uid)
    check(b.party[2].hp==b.party[2].max_hp and PlayerMoveFate.read(b)["wish"]==0,"Entry hazards resolve before healing first surviving ally")
    var j:=journey();sleep_on(j.battle);jcast(j,171);jcast(j,195);jcast(j,199);jcast(j,270);var copy:=checkpoint(j)
    if copy!=null:
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Loaded Nightmare/Perish and existing aim/team aid yield identical next turn")
        var frame:=BattleFrame.capture(j.battle);var detached:=var_to_bytes(frame);j.battle.fate_context["perish"].clear();check(var_to_bytes(frame)==detached,"Animation frame detaches fate context")
    j=journey();j.party[1].hp=1;jcast(j,361);copy=checkpoint(j)
    if copy!=null:
        j.battle.switch_to(j.party[1].uid);copy.battle.switch_to(copy.party[1].uid);check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Saved forced replacement consumes identical wish once")
    var save:=JourneySave.new("user://v19-fate.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual content envelope saves and reloads")
    var good:=JourneySnapshot.encode(j)
    for changes:Dictionary in [{"nightmare":{999999:true},"perish":{},"wish":0},{"nightmare":{},"perish":{j.party[0].uid:0},"wish":0},{"nightmare":{},"perish":{},"wish":true},{"nightmare":{},"perish":{},"wish":999},{"nightmare":{},"perish":{},"wish":0,"extra":true}]:
        var bad:=good.duplicate(true);bad["battle"]["fate_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged fate shape/UID/count/type/wish ID")
    var old:=journey(18);var old_state:=JourneySnapshot.encode(old);check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Frozen v18 journey remains exact")
    old_state["battle"]["fate_context"]={};check(not JourneySnapshot.validate(old_state),"Old route rejects empty new context")
    var f:=FileAccess.open("/tmp/player-v18-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v18 assistance checkpoint remains exact")
    check(JourneySave.compatible_content("a12580b45c2f0d34f9d04225a0871750400b91cd3242c9df48a4292f1e44eb22"),"Actual prior fingerprint accepted")
    check(var_to_bytes(PlayerMoveFate.data())==immutable,"Definitions remain immutable")
    j.battle._clear_statuses();check(j.battle.fate_context.is_empty(),"Battle cleanup removes pending fate state")
    h.free();print("Player move fate: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
