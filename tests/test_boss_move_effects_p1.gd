extends SceneTree
var checks:=0
var failures:=0
var catalog:=VisualCatalog.new()
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func definition(key:String,species:int,level:=50) -> Dictionary:
    var p:=catalog.species(species)
    return {"id":species,"name":p["name"],"type":p["types"][0],"types":p["types"],"max_hp":PokemonStats.value(species,level,"hp"),"level":level}.merged(BossMoveEffectsP1.build(key,species))
func fixture(key:="champion:cynthia",species:=445,ally:=143,level:=50) -> TacticalBattle:
    var helper:=TacticalJourney.new(7,"field_kit",[ally,6,9],true)
    for p:BattlePokemon in helper.party:p.level=level;PokemonStats.apply(p,true)
    var b:=TacticalBattle.new()
    b.start_with(helper.party,helper.deck,[definition(key,species,level)],712,"field_kit")
    b.full_type_chart=true
    for p:BattlePokemon in b.party+b.enemies:p.block=0
    return b
func select_move(b:TacticalBattle,id:int,kind:="move") -> void:
    b.opening().erase("effects_v2")
    for i in b.enemy_definitions[0]["intents"].size():
        var a:Dictionary=b.enemy_definitions[0]["intents"][i]
        if a["move_id"]==id and a["kind"]==kind:b.opening()["intent"]=i;return
    check(false,"Fixture contains move "+str(id))
func refill(b:TacticalBattle) -> void:
    for p:BattlePokemon in b.party:p.hp=p.max_hp;p.knocked_out=false;p.statuses.clear();p.stat_stages.clear()
func step(b:TacticalBattle) -> void:
    b.events.clear();b._enemy_action()
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var d:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(d),"P1 phase checkpoint validates")
    if not JourneySnapshot.validate(d):return null
    var restored:=JourneySnapshot.restore(d)
    check(JourneySnapshot.encode(restored)==d,"Charge, lock, recharge, HP, status and draw RNG roundtrip")
    return restored
func run() -> void:
    check(CampaignRoute.VERSION==7 and BossMoveEffectsP1.data()["profiles"].size()==41 and BossMoveEffectsP1.data()["deferred"].size()==97,"Versioned, bounded P1 rollout")
    var pristine:=var_to_bytes(BossMoveEffectsP1.data())
    for k:String in BossMoveEffectsP1.data()["profiles"]:
        var p:Dictionary=BossMoveEffectsP1.data()["profiles"][k]
        for level in [18,50,100]:
            var b:=fixture(p["boss"],int(p["species"]),143,level)
            check(BossTactics.valid(b.enemy_definitions[0]),"Canonical P1 profile validates")
            for cycle in 2:
                for i in p["intents"].size()+2:
                    refill(b);b.enemy().hp=maxi(1,b.enemy().max_hp/2)
                    var before:=var_to_bytes([b.enemy_states,b.enemy().snapshot(),b.active().snapshot(),b._rng.state])
                    var a:=b.intent()
                    check(a==b.intent() and before==var_to_bytes([b.enemy_states,b.enemy().snapshot(),b.active().snapshot(),b._rng.state]),"Repeated preview is pure and deterministic")
                    check(not EnemyTactics.intent_text(a).is_empty() and not EnemyTactics.description(b.enemy_definitions[0]).is_empty(),"Every P1 phase has readable public intent")
                    var hp:=b.active().hp
                    var actor_hp:=b.enemy().hp
                    var block:=b.active().block
                    step(b)
                    check(b.active().hp>=0 and b.enemy().hp<=b.enemy().max_hp,"HP bounds after atomic P1 action")
                    if not a.get("asleep",false) and a["damage_class"]!="status":
                        check(hp-b.active().hp==mini(hp,maxi(0,int(a["value"])-block)),"Attack/series actual HP damage equals public total")
                    elif a["kind"] in ["prepare","recharge","wait"] or a.get("asleep",false):check(b.active().hp==hp,"Charging, sleep and recovery turns do not attack")
                    if a.has("hp_cost"):check(actor_hp-b.enemy().hp==a["hp_cost"],"Recoil/drain preview equals actual capped HP change")
                    check(BossMoveEffectsP1.valid_state(b.opening(),b.enemy_definitions[0]),"All executed phase state remains structurally valid")
    check(pristine==var_to_bytes(BossMoveEffectsP1.data()),"Execution never mutates frozen definitions")
    var b:=fixture("champion:leon",6)
    select_move(b,76,"prepare")
    var hp:=b.active().hp
    step(b)
    check(b.active().hp==hp and BossMoveEffectsP1.state(b)["charge"]==76,"Solar Beam first turn only prepares")
    var prediction:=b.intent()
    check(prediction["value"]>0 and not prediction.get("failed_charge",false),"Prepared Solar Beam exposes actual next damage")
    step(b)
    check(hp-b.active().hp==prediction["value"] and BossMoveEffectsP1.state(b)["charge"]==0,"Second turn fires once and consumes charge")
    b=fixture("champion:leon",6);select_move(b,76,"prepare");b.powers["weather_sun"]=5
    check(b.intent()["kind"]=="move" and b.intent()["advance"]==2,"Sun exposes same-turn attack and skip")
    step(b)
    check(b.active().hp<b.active().max_hp and b.intent()["move_id"]==246,"Sun skips the redundant second Solar Beam action")
    b=fixture("champion:leon",6);select_move(b,76,"prepare");b.enemy().statuses["sleep"]={"turns":1,"source_uid":1}
    step(b);hp=b.active().hp
    check(b.intent().get("failed_charge",false),"Sleep-cancelled preparation cannot invent a charged strike")
    step(b);check(b.active().hp==hp,"Cancelled Solar Beam deals no damage on next action")
    b=fixture("champion:leon",6);select_move(b,76,"prepare");b.powers["weather_rain"]=5
    step(b)
    var weakened:=BossMoveEffectsP1.view(76).duplicate(true);weakened["move_power"]=60
    check(b.intent()["value"]==PokemonStats.damage(b.enemy(),b.active(),weakened,b.multiplier("grass",b.active()),0,1.0,"rain"),"Adverse weather halves Solar Beam raw power at strike time")
    b=fixture("elite:drayton",1018);select_move(b,905,"prepare");hp=b.active().hp;step(b)
    check(b.enemy().stat_stages.get("special_attack")==1 and b.active().hp==hp,"Electro Shot raises SpA at charge time")
    step(b);check(b.enemy().stat_stages.get("special_attack")==1,"Electro Shot does not grant the boost again when firing")
    b=fixture("elite:drayton",1018,112);select_move(b,905,"prepare");b.powers["weather_rain"]=5
    step(b)
    check(b.active().hp==b.active().max_hp and b.enemy().stat_stages.get("special_attack")==1 and b.intent()["move_id"]==406,"Rain boosts Electro Shot once even into Ground immunity and skips charge action")
    b=fixture();select_move(b,416);step(b)
    check(b.intent()["kind"]=="recharge" and BossMoveEffectsP1.state(b)["recharge"],"Giga Impact creates a real recovery action")
    hp=b.active().hp;step(b)
    check(b.active().hp==hp and not BossMoveEffectsP1.state(b)["recharge"],"Recharge turn cannot attack and clears once")
    b=fixture("gym:juan",230);select_move(b,156);b.enemy().hp=1;b.enemy().statuses={"burn":{"turns":3,"source_uid":1},"poison":{"turns":3,"source_uid":1},"paralysis":{"turns":3,"source_uid":1}}
    step(b)
    check(b.enemy().hp==b.enemy().max_hp and b.enemy().statuses.size()==1 and b.enemy().statuses["sleep"]["turns"]==2,"Rest fully heals and cures major ailments, leaving two future sleeping actions")
    for i in 2:
        hp=b.active().hp;check(b.intent().get("asleep",false),"Both sleep actions are publicly cancelled");step(b);check(b.active().hp==hp,"Rest costs an actual action")
    check(not b.enemy().statuses.has("sleep"),"Rest wakes after exactly two future actions")
    select_move(b,156);step(b);check(not b.enemy().statuses.has("sleep"),"Rest at full HP fails without imposing sleep")
    # Sleep Talk engine fixture: Whitney remains deferred until Attract is supported.
    b=fixture("gym:juan",230)
    b.enemy_definitions[0]["intents"]=[{"kind":"move","move_id":156,"value":0},{"kind":"move","move_id":214,"value":0},{"kind":"move","move_id":214,"value":0},{"kind":"move","move_id":58,"value":0},{"kind":"move","move_id":352,"value":0}]
    b.enemy().hp=1;step(b)
    for i in 2:
        var a:=b.intent();hp=b.active().hp
        check(a.has("called_move") and not a.get("asleep",false) and a==b.intent(),"Sleeping Sleep Talk reveals its deterministic called attack")
        step(b);check(b.active().hp<hp,"Sleep Talk bypasses sleep cancellation and executes the called move")
    b.opening()["intent"]=1
    hp=b.active().hp;step(b);check(b.active().hp==hp,"Awake Sleep Talk fails without attacking")
    b=fixture("gym:cilan",512);select_move(b,154);b.active().block=7
    var a:=b.intent();hp=b.active().hp;step(b)
    check(a["hits"]==3 and hp-b.active().hp==maxi(0,int(a["value"])-7),"Three hits consume one shared shield sequentially")
    b=fixture("champion:iris",612);select_move(b,530);b.active().hp=1
    var reserve_hp:=b.party[1].hp;step(b)
    check(b.phase==TacticalBattle.REPLACE and b.party[1].hp==reserve_hp and b.events.filter(func(e:Dictionary):return e["kind"]=="enemy_hit").is_empty(),"Multi-hit stops on KO without hitting the replacement")
    for shield in [0,999]:
        b=fixture("gym:blaine",59);select_move(b,394);b.active().hp=3;b.active().block=shield;b.enemy().block=99
        a=b.intent();hp=b.enemy().hp;BossMoveEffectsP1.execute(b,a)
        check(hp-b.enemy().hp==(1 if shield==0 else 0),"Recoil uses real HP loss, excludes shield and overkill, pierces own shield")
    b=fixture("gym:koga",49);select_move(b,72);b.enemy().hp=b.enemy().max_hp-1
    a=b.intent();BossMoveEffectsP1.execute(b,a);check(b.enemy().hp==b.enemy().max_hp and a["hp_cost"]==-1,"Absorption caps at missing HP")
    b=fixture("gym:blaine",59);select_move(b,200)
    step(b);check(BossMoveEffectsP1.state(b)["lock_left"]==1 and b.intent()["move_id"]==200,"Outrage remains locked for its second action")
    refill(b);step(b);check(BossMoveEffectsP1.state(b)["lock_left"]==0 and b.enemy().statuses.get("confusion",{}).get("turns")==2,"Two-action lock ends with existing three-tick confusion, including immediate tick")
    # Atomic double KO, including a remaining enemy which must not inherit damage/ticks.
    b=fixture("gym:blaine",59);select_move(b,394);b.active().hp=1;b.enemy().hp=1
    for p:BattlePokemon in b.party.slice(1):p.hp=0;p.knocked_out=true
    step(b);check(b.phase==TacticalBattle.LOST and b.enemy().hp==0,"Last-party recoil double KO resolves loss only after both HP changes")
    b=fixture("gym:blaine",59);select_move(b,394);b.enemy().hp=1
    var next:=definition("elite:caitlin",576)
    b.enemies.append(BattlePokemon.new(next,-99));b.enemies[-1].species_stats=true
    b.enemy_definitions.append(next);b.enemy_states.append({"intent":0})
    b.enemies[-1].statuses["poison"]={"turns":3,"source_uid":1}
    hp=b.enemies[-1].hp;step(b)
    check(b.enemy_index==1 and b.enemy().hp==hp and b.enemy().statuses["poison"]["turns"]==3,"Recoil KO cannot damage or tick the replacement opponent")
    await saves_and_compatibility()
    print("Boss move effects P1: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
func saves_and_compatibility() -> void:
    var goldens:={1:"d04a36405426faac6ea4e4af01e8ab73b482eee2f6b064012d6b9841a663dcbd",712:"1b04d2289fda6497293b67baab45937c6a5fd8b434643e560efb0f907cef6601",2026:"9d72888f9d89bb1ce6b7e0f1c0ab4b58bb03b82fd72fdab9bd7d888f1e948c0e"}
    for seed_value:int in goldens:
        var route:=CampaignRoute.new(seed_value,6)
        var definitions:Array=[]
        for i in route.stops.size():
            if route.stops[i]["kind"]!="rest":definitions.append(route.opponents(i))
        check(var_to_bytes(definitions).hex_encode().sha256_text()==goldens[seed_value],"Captured pre-P1 v6 all69 future definitions unchanged")
        var fresh:=CampaignRoute.new(seed_value,7)
        check(route.signature==fresh.signature and route.stops==fresh.stops,"v7 keeps routes, approved parties, encounter selection and RNG")
    var found:={}
    for seed_value in 450:
        var r:=CampaignRoute.new(seed_value,7)
        for i in r.stops.size():
            if r.stops[i]["kind"] not in ["gym","elite","champion"]:continue
            var d:Dictionary=r.opponents(i)[-1]
            if d.get("boss_moves_version")!=2:continue
            var k:String=d["boss"]+":"+str(d["id"])
            if not found.has(k):found[k]=[seed_value,i]
        if found.size()==41:break
    check(found.size()==41,"All41 implemented representatives reachable through seeded routes")
    for k:String in found:
        var j:=TacticalJourney.new(found[k][0],"field_kit",[3,6,9],true,7)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[k][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:
            j.badges=8;j.elite_wins=int(j.current()["league_index"])
            for stop:Dictionary in j.route.stops:
                if stop["kind"]=="gym":j.badge_records.append({"type":stop["biome"]["type"],"biome":stop["biome"]["id"],"leader_id":stop["trainer"]["leader_id"]})
        j.enter_next();j.battle.enemy_index=j.battle.enemies.size()-1
        for i in j.battle.enemy_index:j.battle.enemies[i].hp=0;j.battle.enemies[i].knocked_out=true
        j.battle._grant_turn_energy()
        j.battle.enemy().hp=maxi(1,j.battle.enemy().max_hp/2)
        for i in j.battle.enemy_definitions[-1]["intents"].size()+3:
            var restored:=checkpoint(j)
            if restored==null:break
            var before:=JourneySnapshot.encode(j)
            j.battle.end_turn();restored.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(restored),"Real P1 next action, phase and RNG match after resume")
            if j.phase!=TacticalJourney.BATTLE or j.battle.phase!=TacticalBattle.PLAYER:j=JourneySnapshot.restore(before)
            refill(j.battle)
        var d:=JourneySnapshot.encode(j)
        var bad:=d.duplicate(true);bad["route_version"]=6
        check(not JourneySnapshot.validate(bad),"v2 effects cannot be injected into an old v6 route")
        bad=d.duplicate(true);bad["battle"]["enemy_states"][-1]["effects_v2"]={"charge":905.0,"recharge":false,"lock":0,"lock_left":0}
        check(not JourneySnapshot.validate(bad),"Reject float charge counters")
        bad=d.duplicate(true);bad["battle"]["enemy_states"][-1]["effects_v2"]={"charge":0,"recharge":false,"lock":200,"lock_left":99}
        check(not JourneySnapshot.validate(bad),"Reject forged lock duration")
        bad=d.duplicate(true);bad["battle"]["enemy_definitions"][-1]["intents"][0]["move_id"]=165
        check(not JourneySnapshot.validate(bad),"Reject forged v7 authored move")
    var file:=FileAccess.open("/tmp/boss-effects-v6-snapshot.bin",FileAccess.READ)
    if file!=null:
        var captured:Dictionary=bytes_to_var(file.get_buffer(file.get_length()))
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v6 snapshot restores byte-equivalent state")
    var legacy:=TacticalJourney.new(712,"field_kit",[1,4,7],true,6)
    var bytes:=var_to_bytes(JourneySnapshot.encode(legacy))
    var path:="user://tests/v6_boss_effects_envelope.json"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
    var envelope:=FileAccess.open(path,FileAccess.WRITE)
    envelope.store_string(JSON.stringify({"version":1,"content":"6c3446b61b27f5743982dd04b96f2882dd5a994615edf785ae87160c2ea3da4e","payload":Marshalls.raw_to_base64(bytes),"sha256":bytes.hex_encode().sha256_text()}));envelope.close()
    var loaded:=JourneySave.new(path).load_journey()
    check(loaded!=null and JourneySnapshot.encode(loaded)==JourneySnapshot.encode(legacy),"Actual previous-v6 fingerprint envelope resumes without migrating to v7")
    check(JourneySave.compatible_content("6c3446b61b27f5743982dd04b96f2882dd5a994615edf785ae87160c2ea3da4e"),"Previous actual v6 fingerprint is explicitly compatible")
