extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[ally,6,9],true,12)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    j.battle._grant_turn_energy()
    return j
func card(j:TacticalJourney,id:int,owner:=0) -> BattleCardInstance:
    var c:BattleCardInstance=h.card(j.battle,id,owner);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    return c
func checkpoint(j:TacticalJourney,label:String) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var valid:=JourneySnapshot.validate(state)
    check(valid,"v12 checkpoint validates: "+label)
    if not valid:return null
    var copy:=JourneySnapshot.restore(state)
    check(JourneySnapshot.encode(copy)==state and copy.battle.snapshot()==j.battle.snapshot(),"Exact saved canonical data and derived combat view: "+label)
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    var played:=0
    for key:String in PlayerMoveExchange.data()["moves"]:
        var id:=int(key);var j:=fixture(59 if id==682 else 143);var b:=j.battle
        b.end_turn()
        if id in [102,119,383,166,176]:
            for _i in 12:
                var ready:=not PlayerMoveExchange.resistance(b,b.active()).is_empty() if id==176 else PlayerMoveExchange.choice(b,b.active(),"mirror-move" if id==119 else "mimic")>0
                if ready:break
                b.end_turn()
        if id==382:
            for _i in 6:
                if PlayerMoveExchange.choice(b,b.active(),"me-first")>0:break
                b.end_turn()
        if id==689:var prior:=card(j,33);b.play_card(prior.uid)
        if id==375:
            for status:String in ["burn","poison","paralysis"]:
                if not PlayerMoveExchange.immune(b,status,b.enemy()):b.active().statuses[status]={"turns":3,"source_uid":b.enemy().uid};break
        b.active().hp=mini(b.active().hp,b.active().max_hp*3/4)
        var c:=card(j,id,b.party[1].uid if id==355 else 0)
        var why:=b.play_card(c.uid);check(why.is_empty(),"Real saved v12 journey can play overlay: "+key+why)
        if not why.is_empty():continue
        played+=1;var copy:=checkpoint(j,key+" used")
        if copy==null:continue
        if id==487:
            var encoded:=JourneySnapshot.encode(j);var uid:=b.enemy().uid
            check(encoded["pokemon"][uid]["types"]==VisualCatalog.new().species(b.enemy().species_id)["types"] and b.enemy().types==["water"],"Saved Pokemon keeps canonical species types while battle context stores Soak")
        if id==682:check(b.active().types.is_empty() and copy.battle.active().types.is_empty(),"Typeless Burn Up survives real save/restore")
        if b.phase==TacticalBattle.PLAYER:
            b.end_turn();copy.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and b.snapshot()==copy.battle.snapshot(),"Restored type/stat/copy state produces the same enemy action: "+key)
            if b.phase==TacticalBattle.PLAYER:
                copy=checkpoint(j,key+" next turn")
                if copy==null:continue
                var next:=b.party.filter(func(p:BattlePokemon):return p!=b.active() and p.alive())[0] as BattlePokemon
                b.switch_to(next.uid);copy.battle.switch_to(next.uid)
                check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and b.snapshot()==copy.battle.snapshot(),"Restored temporary changes clear identically on switch: "+key)
    check(played==30,"All30 new cards exercised in real saved route encounters")
    var j:=fixture();var p:=j.battle.active();var original_types:=p.types.duplicate();var original_attack:=p.attack
    for id:int in [379,513]:var c:=card(j,id);j.battle.play_card(c.uid)
    var copy:=checkpoint(j,"combined stats and copied type")
    if copy!=null:
        j.battle._clear_statuses();copy.battle._clear_statuses()
        check(p.battle_stats.is_empty() and p.types==original_types and p.attack==original_attack and j.battle.snapshot()==copy.battle.snapshot(),"Battle cleanup restores native stats/types on both copies without changing HP or species")
    var first:=JourneySnapshot.encode(fixture())
    for field:String in PlayerMoveExchange.DEFAULT:
        var bad:=first.duplicate(true);bad["battle"]["exchange_context"]=PlayerMoveExchange.DEFAULT.duplicate(true);bad["battle"]["exchange_context"][field]={999:true}
        check(not JourneySnapshot.validate(bad),"Reject forged field/unknown UID: "+field)
    var bad:=first.duplicate(true);bad["battle"]["exchange_context"]=PlayerMoveExchange.DEFAULT.duplicate(true)
    var uid:int=bad["battle"]["party"][0];bad["battle"]["exchange_context"]["types"][uid]={"base":["water"],"primary":"water","core":["ghost"],"added":""}
    check(not JourneySnapshot.validate(bad),"Cannot forge the canonical type used to restore permanent Pokemon")
    bad=first.duplicate(true);bad["battle"]["exchange_context"]=PlayerMoveExchange.DEFAULT.duplicate(true);bad["battle"]["exchange_context"]["stats"][uid]={"hp":999}
    check(not JourneySnapshot.validate(bad),"Stat exchange cannot inject HP or arbitrary base attributes")
    bad=first.duplicate(true);bad["route_version"]=11;check(not JourneySnapshot.validate(bad),"Old routes reject v12 player rules")
    bad=JourneySnapshot.encode(TacticalJourney.new(712,"field_kit",[143,6,9],true,11));bad["battle"]["exchange_context"]={}
    check(not JourneySnapshot.validate(bad),"v11 rejects even an empty v12-only optional field")
    if FileAccess.file_exists("/tmp/player-v11-before.bin"):
        var f:=FileAccess.open("/tmp/player-v11-before.bin",FileAccess.READ);var old:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(old) and JourneySnapshot.encode(JourneySnapshot.restore(old))==old,"Actual pre-edit v11 save restores byte-for-byte logical state")
    check(JourneySave.compatible_content("efe331c4f45f549b9bba7dc032ae577acca0fff3eebdc0c154cf403e01069d52"),"Actual v11 fingerprint is explicitly accepted")
    for seed_value:int in [1,712,2026]:
        var old:=CampaignRoute.new(seed_value,11);var fresh:=CampaignRoute.new(seed_value,12)
        check(old.signature==fresh.signature,"New player traits leave route RNG unchanged")
        for i in old.stops.size():
            if old.stops[i]["kind"]!="rest":check(old.opponents(i)==fresh.opponents(i),"Every future boss/ordinary opponent keeps its approved definition")
    var save:=JourneySave.new("user://v12-exchange.json");check(save.save(j).is_empty() and save.load_journey()!=null,"New content envelope saves and loads through JourneySave")
    h.free();print("Player exchange saves: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
