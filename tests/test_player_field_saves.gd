extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture() -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,13)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    j.battle._grant_turn_energy()
    return j
func cast(j:TacticalJourney,id:int) -> void:
    var c:BattleCardInstance=h.card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    var why:=j.battle.play_card(c.uid);check(why.is_empty(),"Real v13 saved journey plays field card: "+str(id)+why)
func checkpoint(j:TacticalJourney,label:String) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state);var valid:=JourneySnapshot.validate(state)
    check(valid,"Field checkpoint validates: "+label)
    if not valid:return null
    var copy:=JourneySnapshot.restore(state)
    check(var_to_bytes(state)==bytes and JourneySnapshot.encode(copy)==state and copy.battle.snapshot()==j.battle.snapshot(),"Save input and exact derived combat state preserved: "+label)
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    var played:=0
    for key:String in PlayerMoveFields.data()["moves"]:
        var id:=int(key);var j:=fixture();var b:=j.battle
        if id==694:cast(j,258)
        if id in [798,805,804]:cast(j,604)
        if id==797:cast(j,678)
        if id in [803,861,432]:cast(j,580)
        if id==802:cast(j,581)
        if id==756:
            for setup:int in [113,115,219,366,54,446,191,390,564]:cast(j,setup)
        cast(j,id);played+=1;var copy:=checkpoint(j,key+" used")
        if copy==null:continue
        if b.phase==TacticalBattle.REPLACE:
            var next:BattlePokemon=b.party.filter(func(p:BattlePokemon):return p.alive())[0];b.switch_to(next.uid);copy.battle.switch_to(next.uid)
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Self-KO replacement resumes the same turn/field after save")
        if b.phase==TacticalBattle.PLAYER:
            b.end_turn();copy.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and b.snapshot()==copy.battle.snapshot(),"Restored terrain/room/side timers produce exactly the same next action: "+key)
            copy=checkpoint(j,key+" next action")
            if copy!=null and b.phase==TacticalBattle.PLAYER:
                var next:BattlePokemon=b.party.filter(func(p:BattlePokemon):return p!=b.active() and p.alive())[0]
                var why:=b.switch_to(next.uid);var other:=copy.battle.switch_to(next.uid)
                check(why==other and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and b.snapshot()==copy.battle.snapshot(),"Restored side hazards/rooms give the same next switch: "+key)
    check(played==20,"All20 overlays exercised through real route save flow")
    var j:=fixture()
    for id:int in [379,513,433,472,604,366,54,191,113,756]:cast(j,id)
    var copy:=checkpoint(j,"combined v12 stats/types and v13 rooms/terrain/Court Change")
    if copy!=null:
        j.battle._clear_statuses();copy.battle._clear_statuses()
        check(j.battle.field_context.is_empty() and j.battle.exchange_context.is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Battle cleanup clears field and derived type/stat changes identically")
    j=fixture();cast(j,433);j.battle.end_turn();check(j.battle.turn_speed_inverted,"Room's comparison direction is cached at the next energy grant")
    cast(j,433);copy=checkpoint(j,"Trick Room toggled off after inverted energy grant")
    check(copy!=null and PlayerMoveFields.read(j.battle)["trick"]==0 and j.battle.turn_speed_inverted,"Saved energy comparison survives same-turn room cancellation")
    j.battle._clear_statuses();copy=checkpoint(j,"field cleared while current energy grant remains inverted")
    var cached:=JourneySnapshot.encode(j);cached["battle"]["turn_speed_inverted"]="true";check(not JourneySnapshot.validate(cached),"Reject nonboolean cached speed direction")
    var first:=JourneySnapshot.encode(fixture());var valid:=PlayerMoveFields.DEFAULT.duplicate(true)
    for key:String in ["left","trick","wonder","mud","water"]:
        var bad:=first.duplicate(true);bad["battle"]["field_context"]=valid.duplicate(true);bad["battle"]["field_context"][key]=6
        check(not JourneySnapshot.validate(bad),"Reject out-of-range timer: "+key)
        bad["battle"]["field_context"][key]="5";check(not JourneySnapshot.validate(bad),"Reject noninteger field timer: "+key)
    for key:String in ["ally","foe"]:
        var bad:=first.duplicate(true);bad["battle"]["field_context"]=valid.duplicate(true);bad["battle"]["field_context"][key]["veil"]=7
        check(not JourneySnapshot.validate(bad),"Reject forged side duration")
    var bad:=first.duplicate(true);bad["battle"]["field_context"]=valid.duplicate(true);bad["battle"]["field_context"]["terrain"]="fire";bad["battle"]["field_context"]["left"]=5
    check(not JourneySnapshot.validate(bad),"Reject unknown terrain")
    bad["battle"]["field_context"]["terrain"]="electric";bad["battle"]["field_context"]["left"]=0
    check(not JourneySnapshot.validate(bad),"Reject terrain without active duration")
    bad["battle"]["field_context"]=valid.duplicate(true);bad["battle"]["field_context"]["hazards"]["spikes"]=4
    check(not JourneySnapshot.validate(bad),"Reject excessive incoming hazard layers")
    bad["battle"]["field_context"]=valid.duplicate(true);bad["battle"]["field_context"]["party"]={999:true}
    check(not JourneySnapshot.validate(bad),"Reject unknown field or UID registry injection")
    bad=JourneySnapshot.encode(TacticalJourney.new(712,"field_kit",[143,6,9],true,12));bad["battle"]["field_context"]={}
    check(not JourneySnapshot.validate(bad),"Frozen v12 rejects even empty v13-only context")
    if FileAccess.file_exists("/tmp/player-v12-before.bin"):
        var f:=FileAccess.open("/tmp/player-v12-before.bin",FileAccess.READ);var old:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(old) and JourneySnapshot.encode(JourneySnapshot.restore(old))==old,"Actual pre-edit v12 save restores with its frozen rules and logical state")
    check(JourneySave.compatible_content("e96129c17840469e6ef32ed0996be6e535a7cad0f9fd0eb186259c893ac9ac5a"),"Actual v12 fingerprint explicitly accepted")
    var golden:Dictionary={1:"d9f075fd95e3af1fa691d0f97690805553787511b4e5bec375b953df00e9077d",712:"86318c9ac79a41af733979c6ab014909b98e126a0a6e17f87331fb4ac4ec8d8b",2026:"89c2efd5a7f184655c0f6d7a62a69add5172150990be93966e12315463d6b476"}
    for n:int in golden:
        var old:=CampaignRoute.new(n,12);var fresh:=CampaignRoute.new(n,13);var defs:Array=[]
        check(old.signature==fresh.signature,"Route signature and RNG remain unchanged")
        for i in old.stops.size():
            if old.stops[i]["kind"]!="rest":check(old.opponents(i)==fresh.opponents(i),"Every future opponent preserves its approved definition");defs.append(old.opponents(i))
        check(var_to_bytes(defs).hex_encode().sha256_text()==golden[n],"Frozen v12 future69 encounters retain actual pre-edit hash")
    var save:=JourneySave.new("user://v13-fields.json");check(save.save(j).is_empty() and save.load_journey()!=null,"v13 content envelope saves/loads through JourneySave")
    h.free();print("Player field saves: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
