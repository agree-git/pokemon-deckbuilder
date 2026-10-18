extends SceneTree
# Focused v16 checks only: effects, their direct interactions, old/new save parity.
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=8
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func journey(v:=16) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,v)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey plays "+str(id))
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state)
    check(JourneySnapshot.validate(state),"Real checkpoint validates")
    if not JourneySnapshot.validate(state):return null
    var copy:=JourneySnapshot.restore(state)
    check(var_to_bytes(state)==bytes and JourneySnapshot.encode(copy)==state and copy.battle.snapshot()==j.battle.snapshot(),"Restore is exact and leaves input unchanged")
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveTraps.data()["total_enhanced"]==403 and PlayerMoveTraps.data()["moves"].size()==7,"Seven overlays /403 distinct enhanced")
    var immutable:=var_to_bytes(PlayerMoveTraps.data())
    for id:int in [169,212,335,753,746,748,615]:
        var b:=fixture();var c:=card(b,id);var state:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(state==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==8,"Changed preview is pure/repeatable: "+str(id))
        c.upgraded=true;check(b.card_view(c)["trap_rule"]==v["trap_rule"] and not CardEffectText.render(v).is_empty(),"Upgrade and compact explanation preserve trap: "+str(id))
    for id:int in [169,212,335]:
        var b:=fixture();cast(b,id);check(PlayerMoveTraps.blocked(b,b.enemy()) and not PlayerMoveTraps.blocked(b,b.active()),"One-way lock targets only foe")
        b.energy=100;b.switch_to(b.party[1].uid);check(b.trap_context["links"].is_empty(),"Source switching clears its link")
    var b:=fixture();quiet(b);cast(b,753);check(b.enemy().stat_stages.is_empty(),"Octolock has no immediate drop")
    b.end_turn();check(b.enemy().stat_stages.get("defense")==-1 and b.enemy().stat_stages.get("special_defense")==-1,"Octolock lowers both defenses after actual enemy action")
    PlayerMoveFields.write(b)["foe"]["mist"]=5;b.end_turn();check(b.enemy().stat_stages.get("defense")==-1,"Mist blocks continuing opposing Octolock drops")
    b=fixture(143,94);quiet(b);cast(b,753);check(not PlayerMoveTraps.blocked(b,b.enemy()),"Ghost can leave a trapping effect")
    b.end_turn();check(b.enemy().stat_stages.get("defense")==-1,"Ghost still receives Octolock stage drops")
    b=fixture();cast(b,746);check(PlayerMoveTraps.blocked(b,b.active()) and PlayerMoveTraps.blocked(b,b.enemy()),"Jaw Lock binds both sides")
    var c:=card(b,33,b.party[1].uid);var state:=var_to_bytes(b.snapshot())
    check(not b.switch_to(b.party[1].uid).is_empty() and state==var_to_bytes(b.snapshot()),"Manual refusal is atomic")
    check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Owner-card automatic refusal is atomic")
    c=card(b,226);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Baton Pass cannot bypass a link")
    b._damage(b.enemy(),b.enemy().hp,true);check(not PlayerMoveTraps.blocked(b,b.active()),"Source knockout immediately releases the other side")
    b=fixture(94);cast(b,746);b.energy=100;check(b.switch_to(b.party[1].uid).is_empty() and b.trap_context["links"].is_empty(),"Ghost Jaw Lock user can leave and releases both links")
    b=fixture();cast(b,748);check(b.active().stat_stages.values()==[1,1,1,1,1] and PlayerMoveTraps.blocked(b,b.active()),"No Retreat preserves five stage boosts and adds self lock")
    c=card(b,748);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Repeated No Retreat refuses before costs or stat changes")
    b._damage(b.active(),b.active().hp,true);b.phase=TacticalBattle.REPLACE;b._pending="player"
    check(b.switch_to(b.party[1].uid).is_empty() and b.trap_context["stand"].is_empty(),"Mandatory KO replacement clears self lock")
    b=fixture();cast(b,746);BossBattleEffectsP3.force_switch(b)
    check(b.active()==b.party[1] and b.trap_context["links"].is_empty(),"Opponent-forced switch bypasses and clears links")
    for id:int in [212,335,169]:
        b=fixture(143,241,"gym:whitney");BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,id)
        check(PlayerMoveTraps.blocked(b,b.enemy())==(id!=169),"Pinned Protect flags distinguish Look/Block from Spider Web")
    b=fixture(143,241,"gym:whitney");BossBattleRules.write(b)["substitutes"][b.enemy().uid]=10;cast(b,212)
    check(not PlayerMoveTraps.blocked(b,b.enemy()),"Substitute prevents new Mean Look")
    b=fixture();cast(b,615);check(PlayerMoveTraps.blocked(b,b.enemy()) and not PlayerMoveAltitude.read(b)["down"].has(b.enemy().uid),"Thousand Waves traps without grounding")
    b=fixture(143,620,"elite:marshal")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==340:b.opening()["intent"]=i
    b.end_turn();c=card(b,615);var hp:=b.enemy().hp;b.play_card(c.uid)
    check(b.enemy().hp==hp and b.boss_context["airborne"].has(b.enemy().uid) and not PlayerMoveTraps.blocked(b,b.enemy()),"Waves misses prepared Bounce and does not land/trap it")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"ground","move_id":615}];c=card(b,19);b.play_card(c.uid);hp=b.active().hp
    b.end_turn();check(b.active().hp==hp and PlayerMoveRules.read(b)["charges"].has(b.active().uid),"Enemy Waves misses Fly without cancelling retained charge")
    b=fixture(143,834,"gym:nessa")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==746:b.opening()["intent"]=i
    b.active().block=10000;b.end_turn()
    check(PlayerMoveTraps.blocked(b,b.active()) and PlayerMoveTraps.blocked(b,b.enemy()) and not b.switch_reason(b.party[1].uid).is_empty(),"Actual Nessa Jaw Lock uses mutual link and prevents player switching")
    var frame:=BattleFrame.capture(b);check(frame["trap_context"]==b.trap_context,"Presentation frame carries trap links")
    b._clear_statuses();check(b.trap_context.is_empty() and not frame["trap_context"].is_empty(),"Cleanup clears links while prior presentation stays detached")
    var j:=journey()
    for id:int in [753,748,393,381,433]:jcast(j,id)
    var copy:=checkpoint(j)
    if copy!=null:
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restored Octolock/No Retreat with old fields/rooms/float gives same next action")
        copy=checkpoint(j)
        if copy!=null:
            var before:=JourneySnapshot.encode(j);var why:=j.battle.switch_to(j.party[1].uid);var other:=copy.battle.switch_to(copy.party[1].uid)
            check(not why.is_empty() and why==other and before==JourneySnapshot.encode(j) and before==JourneySnapshot.encode(copy),"Restored switch refusal preserves complete state")
    var save:=JourneySave.new("user://v16-traps.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Real content envelope saves/loads")
    var good:=JourneySnapshot.encode(j)
    for changes:Dictionary in [{"links":[{"source":999999,"target":j.battle.enemy().uid,"move":212}],"stand":{}},{"links":[],"stand":{j.party[0].uid:"true"}},{"links":[{"source":j.party[0].uid,"target":j.party[1].uid,"move":212}],"stand":{}},{"links":[],"stand":{},"extra":0}]:
        var bad:=good.duplicate(true);bad["battle"]["trap_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged trap UID/shape/value")
    var old:=journey(15);var old_state:=JourneySnapshot.encode(old);check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Frozen v15 roundtrip stays exact")
    old_state["battle"]["trap_context"]={};check(not JourneySnapshot.validate(old_state),"Old route rejects even empty new context")
    var f:=FileAccess.open("/tmp/player-v15-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v15 float checkpoint remains compatible")
    check(JourneySave.compatible_content("35c5ec489bd3a780d557a8d5ec580f1d2cb2ec416e2e56a5905e3c73e868b593"),"Prior actual content fingerprint accepted")
    var old_route:=CampaignRoute.new(712,15);var fresh:=CampaignRoute.new(712,16)
    check(old_route.signature==fresh.signature and old_route.opponents(0)==fresh.opponents(0),"Unchanged route inputs preserve signature and first encounter")
    check(var_to_bytes(PlayerMoveTraps.data())==immutable,"Definitions stay immutable")
    h.free();print("Player move traps: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
