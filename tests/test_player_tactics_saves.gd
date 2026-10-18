extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func checkpoint(j:TacticalJourney,label:String) -> TacticalJourney:
    var saved:=JourneySnapshot.encode(j);var valid:=JourneySnapshot.validate(saved)
    check(valid,"v11 effect checkpoint validates: "+label)
    if not valid:return null
    var copy:=JourneySnapshot.restore(saved)
    check(JourneySnapshot.encode(copy)==saved,"Exact state/UID/RNG restore: "+label)
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    var played:=0
    for key:String in PlayerMoveTactics.data()["moves"]:
        var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,11)
        for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
        var b:=j.battle;b._grant_turn_energy();b.active().hp=b.active().max_hp*3/4
        if int(key) in [227,50,259]:b.end_turn()
        var card:BattleCardInstance=h.card(b,int(key));j.deck.append(card);j._next_card_uid=b._next_uid
        var why:=b.play_card(card.uid);check(why.is_empty(),"Real v11 journey can use selected overlay: "+key+why)
        if not why.is_empty():continue
        played+=1;var copy:=checkpoint(j,key+" cast")
        if copy==null:continue
        if b.phase==TacticalBattle.PLAYER:
            if int(key) in [226,880]:
                var next:=b.party[1].uid;b.switch_to(next);copy.battle.switch_to(next)
                check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Saved Baton/Shed transfer resolves identically")
            b.end_turn();copy.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restored restriction/DOT action is identical: "+key)
            checkpoint(j,key+" next turn")
    check(played==32,"All32 overlay effects exercised in real saved journeys")
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,11)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:
            j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    check(j.battle.enemies.size()>1,"Hazard save fixture uses a real multi-Pokemon route encounter")
    for id:int in [446,191,390,564]:
        var card:BattleCardInstance=h.card(j.battle,id);j.deck.append(card);j._next_card_uid=j.battle._next_uid;j.battle.play_card(card.uid)
    var copy:=checkpoint(j,"all hazards")
    if copy!=null:
        j.battle._damage(j.battle.enemy(),j.battle.enemy().hp,true);copy.battle._damage(copy.battle.enemy(),copy.battle.enemy().hp,true)
        j.battle._outcome();copy.battle._outcome()
        check(j.battle.enemy_index>0 and j.battle.phase==TacticalBattle.PLAYER,"Saved hazard fixture actually advances to another living enemy")
        check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Saved natural enemy entry applies hazards once with the same result")
        checkpoint(j,"after hazards and replacement")
    var original:=JourneySnapshot.encode(TacticalJourney.new(712,"field_kit",[143,6,9],true,11))
    for field:String in PlayerMoveTactics.DEFAULT:
        var bad:=original.duplicate(true);bad["battle"]["technique_context"]=PlayerMoveTactics.DEFAULT.duplicate(true);bad["battle"]["technique_context"][field]={999:true}
        check(not JourneySnapshot.validate(bad),"Reject unknown UID or forged hazard/pass map: "+field)
    var bad:=original.duplicate(true);bad["route_version"]=10
    check(not JourneySnapshot.validate(bad),"Old journeys cannot silently gain v11 mechanics")
    bad=original.duplicate(true);bad["battle"]["player_moves_version"]=2
    check(not JourneySnapshot.validate(bad),"New journeys cannot silently downgrade rules")
    var old:=TacticalJourney.new(712,"field_kit",[143,6,9],true,10);bad=JourneySnapshot.encode(old);bad["battle"]["technique_context"]={}
    check(not JourneySnapshot.validate(bad),"v10 rejects even an empty v11-only state field")
    if FileAccess.file_exists("/tmp/player-v10-before.bin"):
        var f:=FileAccess.open("/tmp/player-v10-before.bin",FileAccess.READ);var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v10 save restores exactly")
    check(JourneySave.compatible_content("7dfcdedd7bc0ccd814d896a7a0dc71e3ebbaf79a127c08a94d37713a1d1c106f"),"Actual v10 fingerprint remains loadable")
    var gold:={1:"d9f075fd95e3af1fa691d0f97690805553787511b4e5bec375b953df00e9077d",712:"86318c9ac79a41af733979c6ab014909b98e126a0a6e17f87331fb4ac4ec8d8b",2026:"89c2efd5a7f184655c0f6d7a62a69add5172150990be93966e12315463d6b476"}
    for seed_value:int in gold:
        var r:=CampaignRoute.new(seed_value,10);var fresh:=CampaignRoute.new(seed_value,11);var all:Array=[]
        for i in r.stops.size():
            if r.stops[i]["kind"]!="rest":all.append(r.opponents(i));check(fresh.opponents(i)==r.opponents(i),"v11 preserves every approved future opponent definition")
        check(var_to_bytes(all).hex_encode().sha256_text()==gold[seed_value] and r.signature==fresh.signature,"Frozen v10 future69 battles and path/RNG remain exact")
    var save:=JourneySave.new("user://v11-save.json");check(save.save(j).is_empty() and save.load_journey()!=null,"New fingerprint envelope really saves and reloads")
    h.free();print("Player tactics saves: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
