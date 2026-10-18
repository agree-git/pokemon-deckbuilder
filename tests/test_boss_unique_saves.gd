extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:
    var h=load(get_script().resource_path.get_base_dir().path_join("test_boss_move_effects_p3.gd")).new()
    var wanted:={"gym:whitney:241":213,"gym:morty:94":194,"gym:clair:230":281,"gym:bea:68":282,"gym:avery:10172":826,"champion:blue:18":119,"elite:marshal:620":340,"champion:nemona:923":892,"gym:gordie:839":749,"gym:piers:862":675,"elite:hassel:998":862,"champion:kieran:1019":907}
    var found:={}
    for seed_value in 500:
        var route:=CampaignRoute.new(seed_value,9)
        for step in route.stops.size():
            var stop:Dictionary=route.stops[step]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var boss:String=stop["kind"]+":"+str(stop["trainer"]["leader_id"] if stop["kind"]=="gym" else stop["trainer"]["id"])
            var aces:=BossParties.aces(boss)
            for i in aces.size():
                var k:=boss+":"+str(aces[i])
                if wanted.has(k) and not found.has(k):found[k]=[seed_value,step,stop["party"].size()-aces.size()+i]
        if found.size()==wanted.size():break
    check(found.size()==wanted.size(),"Every special persistence scenario uses a real canonical seeded encounter")
    for k:String in found:
        var j:=TacticalJourney.new(found[k][0],"field_kit",[3,6,9],true,9)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[k][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:
            j.badges=8;j.elite_wins=int(j.current()["league_index"])
            for stop:Dictionary in j.route.stops:
                if stop["kind"]=="gym":j.badge_records.append({"type":stop["biome"]["type"],"biome":stop["biome"]["id"],"leader_id":stop["trainer"]["leader_id"]})
        j.enter_next();j.battle.enemy_index=found[k][2]
        for i in j.battle.enemy_index:j.battle.enemies[i].hp=0;j.battle.enemies[i].knocked_out=true
        j.battle._grant_turn_energy();j.battle.enemy().block=0
        h.select_move(j.battle,int(wanted[k]))
        if k in ["gym:avery:10172","champion:blue:18"]:
            var card:BattleCardInstance=h.card(j.battle,33)
            j.deck.append(card);j._next_card_uid=j.battle._next_uid
            j.battle.play_card(card.uid)
        if k=="gym:bea:68":j.battle.active().held_item="power_band"
        if k!="champion:blue:18":h.step(j.battle)
        var original:=JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(original),"Canonical special state validates: "+k)
        if not JourneySnapshot.validate(original):continue
        var r:=JourneySnapshot.restore(original)
        check(JourneySnapshot.encode(r)==original,"Full UID/RNG/state roundtrip: "+k)
        if k=="gym:avery:10172":
            var sealed:=JourneySnapshot.restore(original)
            var card:BattleCardInstance=h.card(sealed.battle,33)
            check(sealed.battle.card_reason(card.uid).contains("섬뜩"),"Resumed last-move seal refuses another copy")
        if k=="gym:bea:68":
            check(r.battle.active().held_item.is_empty(),"Removed equipment stays disabled after loading")
            r.battle._damage(r.battle.enemy(),r.battle.enemy().hp,true);r.battle._outcome()
            check(r.party[0].held_item=="power_band","Loaded equipment returns when the battle ends")
        if k=="champion:blue:18":check(r.battle.intent()["name"].contains("몸통박치기"),"Mirror copy memory still resolves the same move after load")
        j.battle.end_turn();r.battle.end_turn()
        if k!="gym:bea:68":check(JourneySnapshot.encode(j)==JourneySnapshot.encode(r),"Following public action remains identical: "+k)
        var bad:=original.duplicate(true);bad["route_version"]=8
        check(not JourneySnapshot.validate(bad),"Reject v9 effects in an old route: "+k)
    h.free()
    print("Boss unique saves: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
