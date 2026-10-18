extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(version:=15) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,version)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    j.battle._grant_turn_energy()
    return j
func cast(j:TacticalJourney,id:int) -> void:
    var c:BattleCardInstance=h.card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey plays altitude: "+str(id))
func checkpoint(j:TacticalJourney,label:String) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state)
    check(JourneySnapshot.validate(state),"Save validates: "+label)
    if not JourneySnapshot.validate(state):return null
    var copy:=JourneySnapshot.restore(state)
    check(bytes==var_to_bytes(state) and state==JourneySnapshot.encode(copy) and j.battle.snapshot()==copy.battle.snapshot(),"Save restores exact state without mutating input: "+label)
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    for id:int in [356,393,477]:
        var j:=fixture();j.party[0].held_item="power_band";cast(j,id);var copy:=checkpoint(j,str(id))
        if copy==null:continue
        j.battle.end_turn();copy.battle.end_turn()
        check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and j.battle.snapshot()==copy.battle.snapshot(),"Next action/timer exactly matches after restoration")
        copy=checkpoint(j,str(id)+" next action")
        if copy!=null:
            var uid:=j.party[1].uid;var before:=JourneySnapshot.encode(j);var why:=j.battle.switch_to(uid);var other:=copy.battle.switch_to(uid)
            check(why==other and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Next switch succeeds or refuses identically")
            check(why.is_empty(),"Ordinary switching remains legal after restoration")
    var j:=fixture()
    for id:int in [379,513,433,472,604,366,54,478,381,393,477,356]:cast(j,id)
    j.battle.end_turn();cast(j,433);var copy:=checkpoint(j,"combined derived stats/types, fields/rooms/altitudes and cached energy")
    check(copy!=null and j.battle.turn_speed_inverted,"v15 saves cached reversed energy even after room cancellation")
    if copy!=null:
        j.battle._clear_statuses();copy.battle._clear_statuses()
        check(j.battle.altitude_context.is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Cleanup preserves item ownership and clears contexts identically")
    var state:=JourneySnapshot.encode(fixture());var valid:=PlayerMoveAltitude.DEFAULT.duplicate(true)
    for value:Variant in [-1,6,"1",true,{},null]:
        var bad:=state.duplicate(true);bad["battle"]["altitude_context"]=valid.duplicate(true);bad["battle"]["altitude_context"]["gravity"]=value
        check(not JourneySnapshot.validate(bad),"Reject invalid Gravity timer")
    for group:String in ["rise","lift","down"]:
        for value:Variant in [-1,6,"1",false,{},null]:
            var bad:=state.duplicate(true);bad["battle"]["altitude_context"]=valid.duplicate(true);bad["battle"]["altitude_context"][group]={j.party[0].uid:value}
            check(not JourneySnapshot.validate(bad),"Reject invalid floating timer/ground marker")
        var bad:=state.duplicate(true);bad["battle"]["altitude_context"]=valid.duplicate(true);bad["battle"]["altitude_context"][group]={999999:1}
        check(not JourneySnapshot.validate(bad),"Reject unknown actor UID")
    var bad:=state.duplicate(true);bad["battle"]["altitude_context"]=valid.duplicate(true);bad["battle"]["altitude_context"]["rise"]={j.party[0].uid:2};bad["battle"]["altitude_context"]["gravity"]=5
    check(not JourneySnapshot.validate(bad),"Reject floating effect coexisting with Gravity")
    bad["battle"]["altitude_context"]=[];check(not JourneySnapshot.validate(bad),"Reject non-dictionary altitude")
    for v in range(10,15):
        bad=JourneySnapshot.encode(fixture(v));bad["battle"]["altitude_context"]={};check(not JourneySnapshot.validate(bad),"Frozen earlier version rejects new context even if empty")
    var f:=FileAccess.open("/tmp/player-v14-before.bin",FileAccess.READ)
    if f!=null:
        var old:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(old) and JourneySnapshot.encode(JourneySnapshot.restore(old))==old,"Actual pre-edit v14 checkpoint restores frozen rules")
    check(JourneySave.compatible_content("63e395f964d9bdd53c02abcb4ed70ade1718c7a609b6caafdca76833520fcbbf"),"Actual v14 fingerprint remains accepted")
    for n:int in [1,712,2026]:
        var old:=CampaignRoute.new(n,14);var fresh:=CampaignRoute.new(n,15)
        check(old.signature==fresh.signature,"Route RNG/signature unchanged")
        for i in old.stops.size():
            if old.stops[i]["kind"]!="rest":check(old.opponents(i)==fresh.opponents(i),"All69 future encounters preserve approved opponents")
    j=fixture();cast(j,393);cast(j,477);cast(j,356);var save:=JourneySave.new("user://v15-altitude.json")
    check(save.save(j).is_empty(),"Real new content envelope saves")
    copy=save.load_journey();check(copy!=null and JourneySnapshot.encode(copy)==JourneySnapshot.encode(j),"Real envelope reload retains altitudes, items, UIDs and RNG")
    h.free();print("Player altitude saves: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
