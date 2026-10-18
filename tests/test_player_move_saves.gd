extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:call_deferred("run")
func checkpoint(j:TacticalJourney,label:String) -> TacticalJourney:
    var encoded:=JourneySnapshot.encode(j)
    var valid:=JourneySnapshot.validate(encoded)
    check(valid,"Player-card checkpoint validates: "+label)
    if not valid:return null
    var copy:=JourneySnapshot.restore(encoded)
    check(JourneySnapshot.encode(copy)==encoded,"Charge/recharge/fields/UID/RNG exact roundtrip: "+label)
    return copy
func run() -> void:
    var h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    var count:=0
    for key:String in PlayerMoveCards.data()["enhanced"]:
        var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,10)
        for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
        j.battle._grant_turn_energy()
        var b:=j.battle
        var c:BattleCardInstance=h.card(b,int(key));j.deck.append(c);j._next_card_uid=b._next_uid
        b.active().hp=maxi(1,b.active().max_hp*3/4)
        if int(key)==214:b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};b.active().learned_skills.assign(["move_33","move_214"])
        if int(key) in [255,256]:h.cast(b,254)
        # h.cast is an engine fixture; register its concrete card in the permanent deck too.
        for pile:Array in [b.hand,b.draw_pile,b.discard,b.exhausted]:
            for card:BattleCardInstance in pile:
                if card.owner_uid!=0 and card not in j.deck:j.deck.append(card)
        j._next_card_uid=maxi(j._next_card_uid,b._next_uid)
        var why:=b.play_card(c.uid)
        if not why.is_empty():continue
        count+=1
        var copy:=checkpoint(j,key+" played")
        if copy==null:continue
        if b.phase==TacticalBattle.PLAYER and j.phase==TacticalJourney.BATTLE:
            b.end_turn();copy.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restored next enemy action remains exact: "+key)
            if b.phase==TacticalBattle.PLAYER and j.phase==TacticalJourney.BATTLE:
                copy=checkpoint(j,key+" next turn")
                if copy!=null and PlayerMoveRules.keep_charge(b,c.uid):
                    check(b.card_view(c)["cost"]==0,"Saved prepared card is free when ready")
                    b.play_card(c.uid);copy.battle.play_card(c.uid)
                    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Saved charged release is identical")
    check(count>=300,"Over300 characteristic moves exercised in saved real journeys")
    var old:={1:"d9f075fd95e3af1fa691d0f97690805553787511b4e5bec375b953df00e9077d",712:"86318c9ac79a41af733979c6ab014909b98e126a0a6e17f87331fb4ac4ec8d8b",2026:"89c2efd5a7f184655c0f6d7a62a69add5172150990be93966e12315463d6b476"}
    for seed_value:int in old:
        var r:=CampaignRoute.new(seed_value,9);var definitions:Array=[];var fresh:=CampaignRoute.new(seed_value,10)
        for i in r.stops.size():
            if r.stops[i]["kind"]!="rest":definitions.append(r.opponents(i));check(fresh.opponents(i)==r.opponents(i),"v10 does not alter approved opponents or their frozen tactics")
        check(var_to_bytes(definitions).hex_encode().sha256_text()==old[seed_value],"Pre-edit v9 future69 battles preserve exact definitions")
        check(r.signature==fresh.signature,"v10 path RNG is unchanged")
    if FileAccess.file_exists("/tmp/boss-effects-v9-snapshot.bin"):
        var f:=FileAccess.open("/tmp/boss-effects-v9-snapshot.bin",FileAccess.READ);var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v9 save restores without new required fields")
    check(JourneySave.compatible_content("f823671d51317f3d0352a807005558ef2c9e4accc868fdc17b91c25d619e2d43"),"Actual old v9 fingerprint is accepted")
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,10);var original:=JourneySnapshot.encode(j)
    for field:String in PlayerMoveRules.DEFAULT:
        var bad:=original.duplicate(true);bad["battle"]["move_context"]=PlayerMoveRules.DEFAULT.duplicate(true)
        if bad["battle"]["move_context"][field] is Dictionary:bad["battle"]["move_context"][field]={999:true}
        else:bad["battle"]["move_context"][field]=1000001
        check(not JourneySnapshot.validate(bad),"Reject forged field/foreign UID in "+field)
    var wrong:=original.duplicate(true);wrong["battle"]["player_moves_version"]=1
    check(not JourneySnapshot.validate(wrong),"Cannot silently downgrade a v10 save to old card rules")
    wrong=original.duplicate(true);wrong["route_version"]=9
    check(not JourneySnapshot.validate(wrong),"Cannot inject new card rules into old routes")
    var save:=JourneySave.new("user://player-move-roundtrip.json")
    check(save.save(j).is_empty() and save.load_journey()!=null,"New content fingerprint envelope can be loaded")
    h.free()
    print("Player move saves: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
