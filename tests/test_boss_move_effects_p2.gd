extends SceneTree
var checks:=0
var failures:=0
var catalog:=VisualCatalog.new()
func _initialize() -> void:call_deferred("run")
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func definition(key:String,species:int,level:=50) -> Dictionary:
    var p:=catalog.species(species)
    return {"id":species,"name":p["name"],"type":p["types"][0],"types":p["types"],"max_hp":PokemonStats.value(species,level,"hp"),"level":level}.merged(BossMoveEffectsP2.build(key,species))
func fixture(key:="gym:brock",species:=208,ally:=143,level:=50) -> TacticalBattle:
    var j:=TacticalJourney.new(7,"field_kit",[ally,6,9],true,8)
    for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
    var b:=TacticalBattle.new()
    b.start_with(j.party,j.deck,[definition(key,species,level)],712,"field_kit")
    b.full_type_chart=true
    for p:BattlePokemon in b.party+b.enemies:p.block=0
    return b
func select_move(b:TacticalBattle,id:int) -> void:
    b.opening().erase("effects_v3")
    for i in b.enemy_definitions[b.enemy_index]["intents"].size():
        if b.enemy_definitions[b.enemy_index]["intents"][i]["move_id"]==id:b.opening()["intent"]=i;return
    check(false,"Fixture contains move "+str(id))
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:
    var c:=BattleCardInstance.new(b._next_uid,TacticalMoves.key_for(id),b.active().uid if owner==0 else owner)
    b._next_uid+=1
    b.hand.append(c);b.energy=100
    return c
func step(b:TacticalBattle) -> void:b.events.clear();b.phase="enemy";b._enemy_action()
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var d:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(d),"P2 phase checkpoint validates")
    if not JourneySnapshot.validate(d):return null
    var r:=JourneySnapshot.restore(d)
    check(JourneySnapshot.encode(r)==d,"HP, field, trap, substitute, guard and RNG roundtrip")
    return r
func run() -> void:
    check(CampaignRoute.VERSION>=8 and BossMoveEffectsP2.data()["profiles"].size()==105,"Explicit P2 rollout105, no unsupported placeholder moves")
    var b:=fixture("gym:crasher_wake",419);select_move(b,362)
    b.active().hp=b.active().max_hp
    var a:=b.intent();b.active().hp=b.active().max_hp/2
    check(b.intent()["base_power"]==130 and a["base_power"]==65,"Brine actual HP half threshold changes power")
    b=fixture("gym:lt_surge",26,143);select_move(b,447)
    check(b.intent()["base_power"]==120,"Grass Knot uses target's frozen weight")
    b=fixture("gym:peony",879,143);select_move(b,484)
    var own:=int(BossMoveEffectsP2.data()["weights"]["879"]);var target:=int(BossMoveEffectsP2.data()["weights"]["143"])
    check(b.intent()["base_power"]==(120 if own>=target*5 else (100 if own>=target*4 else (80 if own>=target*3 else (60 if own>=target*2 else 40)))),"Heavy Slam weight ratio table")
    b=fixture("elite:lucian",437);select_move(b,360)
    a=b.intent();b.enemy().statuses["paralysis"]={"turns":3,"source_uid":1}
    check(b.intent()["base_power"]>=a["base_power"] and b.intent()["base_power"]<=150,"Gyro Ball reads real staged/paralysed speed and caps150")
    b=fixture("gym:raihan",1018);select_move(b,776);a=b.intent()
    b.enemy().stat_stages["attack"]=6;check(b.intent()["value"]==a["value"],"Body Press ignores Attack stages")
    b.enemy().stat_stages["defense"]=2;check(b.intent()["value"]>a["value"],"Body Press actually uses Defense and its stages")
    b=fixture("gym:roxie",545);select_move(b,474)
    var base:int=b.intent()["base_power"];b.active().statuses["poison"]={"turns":3,"source_uid":-1}
    check(b.intent()["base_power"]==base*2,"Venoshock requires real poison")
    b=fixture("elite:phoebe",477);select_move(b,506)
    base=b.intent()["base_power"];b.active().statuses["confusion"]={"turns":3,"source_uid":-1}
    check(b.intent()["base_power"]==base,"Hex does not treat confusion as a major status")
    b.active().statuses["sleep"]={"turns":1,"source_uid":-1};check(b.intent()["base_power"]==base*2,"Hex doubles on sleep")
    b=fixture("gym:byron",411);select_move(b,368)
    check(b.intent()["value"]==0,"Metal Burst fails without a real hit this turn")
    b.enemy().block=999
    var c:=card(b,33);b.play_card(c.uid);check(b.intent()["value"]==0,"Blocked HP damage cannot fuel Metal Burst")
    b.enemy().block=0;c=card(b,33);var hp:=b.enemy().hp;b.play_card(c.uid)
    var lost:=hp-b.enemy().hp
    check(b.intent()["value"]==floori(lost*1.5),"Metal Burst updates to150% of actual last HP damage")
    b=fixture("elite:olivia",10126);select_move(b,68)
    c=card(b,53);b.play_card(c.uid);check(b.intent()["value"]==0,"Counter cannot reflect a special attack")
    c=card(b,33);hp=b.enemy().hp;b.play_card(c.uid);check(b.intent()["value"]==(hp-b.enemy().hp)*2,"Counter reflects actual last physical hit twice")
    b=fixture("gym:chuck",62);select_move(b,164);step(b)
    var pool:int=BossBattleEffects.read(b)["substitutes"].get(b.enemy().uid,0)
    check(pool>0 and b.enemy().hp==b.enemy().max_hp-pool,"Substitute pays HP once and stores separate pool")
    select_move(b,264);hp=b.enemy().hp;c=card(b,33);b.play_card(c.uid)
    check(b.enemy().hp==hp and not b.intent().get("failed_move",false),"Substitute protects HP and does not interrupt Focus Punch")
    BossBattleEffects.write(b)["substitutes"][b.enemy().uid]=1;c=card(b,33);b.play_card(c.uid)
    check(b.enemy().hp==hp and BossBattleEffects.read(b)["substitutes"][b.enemy().uid]==0,"Breaking substitute hit cannot overflow into owner")
    c=card(b,33);b.play_card(c.uid)
    check(b.intent()["value"]==0 and b.intent().get("failed_move",false),"Actual HP hit interrupts Focus Punch and updates preview")
    b=fixture("gym:roxie",545);select_move(b,182);step(b)
    b.next_attack_bonus=5
    hp=b.enemy().hp;c=card(b,34);b.play_card(c.uid)
    check(b.enemy().hp==hp and not b.enemy().statuses.has("paralysis"),"Protect blocks direct damage and secondary status")
    check(b.next_attack_bonus==0,"Protected attack still consumes its one-use attack bonus")
    var shield_card:=BattleCardInstance.new(b._next_uid,"shield_strike",0)
    b._next_uid+=1;b.hand.append(shield_card);b.active().block=50
    hp=b.enemy().hp;b.play_card(shield_card.uid)
    check(b.active().block==0 and b.enemy().hp==hp,"Protected shield conversion consumes its own shield and deals no HP damage")
    select_move(b,398);step(b);check(BossBattleEffects.read(b)["guards"].is_empty(),"Protect expires before the next own action")
    b=fixture("elite:wikstrom",681);select_move(b,588);step(b)
    c=card(b,33);b.play_card(c.uid)
    check(b.active().stat_stages.get("attack")==-2,"King's Shield uses actual contact flag to lower attack")
    check(b.enemy().species_id==681,"King's Shield preserves permanent form; no battle transform")
    b=fixture("gym:tate_liza",337);select_move(b,113);c=card(b,53)
    var full:int=b.card_view(c)["preview_damage"];step(b)
    check(BossBattleEffects.read(b)["screen"]==5 and b.card_view(c)["preview_damage"]==maxi(1,full/2),"Light Screen applies to actual player special damage for five future turns")
    c=card(b,280);b.play_card(c.uid);check(BossBattleEffects.read(b)["screen"]==0,"Brick Break removes screen before attacking")
    b=fixture("champion:lance",149);select_move(b,219);step(b)
    c=card(b,92);b.play_card(c.uid);check(not b.enemy().statuses.has("poison"),"Safeguard blocks player status cards")
    b=fixture("gym:sabrina",65,6);select_move(b,356)
    check(b.multiplier("ground",b.active())==0,"Flying normally immune to Ground")
    step(b)
    check(b.multiplier("ground",b.active())==2 and b.active().types.has("flying"),"Gravity grounds without changing types")
    c=card(b,19);var before:=var_to_bytes(b.snapshot());check(b.card_reason(c.uid).contains("중력") and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Gravity refuses aerial card atomically")
    b=fixture("gym:brock",208);select_move(b,446);step(b)
    var ally:=b.party[1];hp=ally.hp;var energy:=b.energy;var turn:=b.turn
    var loss:=BossBattleEffects.entry_damage(b,ally)
    check(loss==mini(ally.hp,maxi(1,ally.max_hp/2)),"Charizard's4x Rock weakness causes half-max-HP entry damage")
    b.switch_to(ally.uid)
    check(ally.hp==hp-loss and b.energy==energy-1 and b.turn==turn,"Manual switch pays once, hazards pierce shields, no speed energy regrant")
    var next:=b.party[2];next.hp=1;c=card(b,33,next.uid);before=var_to_bytes(b.snapshot())
    check(b.card_reason(c.uid).contains("스텔스록") and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Auto-switch into hazard KO is a clear atomic refusal")
    b.switch_to(next.uid)
    check(b.phase==TacticalBattle.REPLACE and b._pending=="hazard","Manual hazard KO requests replacement in the same player turn")
    energy=b.energy;turn=b.turn;var hand:=b.hand.size();b.switch_to(b.party[0].uid)
    check(b.phase==TacticalBattle.PLAYER and b.energy==energy and b.turn==turn and b.hand.size()==hand,"Hazard replacement preserves hand, turn and energy")
    c=card(b,432);b.play_card(c.uid);check(not BossBattleEffects.read(b)["rocks"],"Defog removes installed hazards")
    b=fixture("gym:jasmine",208);select_move(b,446);step(b);select_move(b,46)
    energy=b.energy;hp=b.party[1].hp;step(b)
    check(b.active().uid==b.party[1].uid and b.active().hp<hp,"Roar forces announced alive reserve and applies rocks")
    b=fixture("gym:viola",666);select_move(b,611);step(b)
    check(BossBattleEffects.trapped(b),"Infestation binds after its actual hit")
    c=card(b,33,b.party[1].uid);before=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and not b.switch_reason(b.party[1].uid).is_empty() and before==var_to_bytes(b.snapshot()),"Bind blocks manual and automatic switches without costs")
    for i in 4:
        hp=b.active().hp;b._tick(b.active());check(b.active().hp==maxi(0,hp-maxi(1,b.active().max_hp/8)),"Infestation damage tick equals maxHP/8")
    check(not BossBattleEffects.trapped(b),"Binding ends after exactly four ticks")
    b=fixture("gym:nessa",834);select_move(b,746);step(b)
    check(BossBattleEffects.trapped(b),"Jaw Lock binds without fake poison damage")
    b._damage(b.enemy(),b.enemy().hp,true);check(not BossBattleEffects.trapped(b),"Source KO immediately releases Jaw Lock")
    b=fixture("gym:candice",460);select_move(b,275);b.enemy().hp=1;step(b)
    check(b.enemy().hp==1+maxi(1,b.enemy().max_hp/16),"Ingrain heals once at own end of action")
    b=fixture("gym:tate_liza",338);select_move(b,241);step(b)
    check(BattleWeather.kind(b.powers)=="sun" and BattleWeather.remaining(b.powers)==4,"Enemy Sunny Day uses the existing shared weather timing")
    extra_conditions()
    matrix()
    saves()
    print("Boss move effects P2: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
func extra_conditions() -> void:
    var b:=fixture()
    func_move(b,175)
    b.enemy().hp=1;check(b.intent()["base_power"]==200,"Flail low HP table reaches200")
    b.enemy().hp=b.enemy().max_hp;check(b.intent()["base_power"]==20,"Flail full HP table is20")
    func_move(b,912)
    check(b.intent()["base_power"]==100,"Hard Press full target HP yields100")
    b.active().hp=1;check(b.intent()["base_power"]==1,"Hard Press low target HP floors at1")
    b.active().hp=b.active().max_hp
    func_move(b,216);check(b.intent()["base_power"]==102,"Return uses declared NPC friendship255 baseline")
    func_move(b,263)
    b.enemy().statuses["burn"]={"turns":3,"source_uid":1}
    var move:=BossMoveEffectsP2.view(263).duplicate(true);move["move_power"]=140
    var actor:=BossMoveEffectsP2._clone(b.enemy());actor.statuses.clear()
    check(b.intent()["value"]==PokemonStats.damage(actor,b.active(),move,b.multiplier("normal",b.active())),"Facade doubles and avoids burn's physical damage penalty")
    b.enemy().statuses.clear();func_move(b,228)
    check(b.intent()["base_power"]==40,"Pursuit no-switch condition stays40")
    b.switch_to(b.party[1].uid);check(b.intent()["base_power"]==80,"Pursuit checks an actual current-round switch")
    func_move(b,371)
    check(b.intent()["base_power"]==50,"Payback is not doubled just by fixed turn order")
    var c:=card(b,33);b.play_card(c.uid);check(b.intent()["base_power"]==100,"Payback doubles only after the current actor actually plays a card")
    func_move(b,372)
    check(b.intent()["base_power"]==60,"Assurance requires actual previous HP loss this round")
    b._damage(b.active(),1,true);check(b.intent()["base_power"]==120,"Assurance sees real earlier HP damage")
    b=fixture("gym:pryce",473);select_move(b,419)
    c=card(b,33);b.play_card(c.uid);check(b.intent()["base_power"]==120,"Avalanche doubles after actual direct HP damage")
    b=fixture("gym:lenora",505)
    b.enemies.append(BattlePokemon.new(definition("gym:lenora",505),-2));b.enemies[-1].species_stats=true
    b.enemy_definitions.append(definition("gym:lenora",505));b.enemy_states.append({"intent":0})
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome();select_move(b,514)
    check(b.intent()["base_power"]==140,"Retaliate observes a real earlier teammate KO")
    b.turn+=2;check(b.intent()["base_power"]==70,"Retaliate bonus expires after its stated turn window")
    b=fixture("gym:tate_liza",337);select_move(b,113);step(b)
    for i in 4:
        select_move(b,347);step(b)
    check(BossBattleEffects.read(b)["screen"]==1,"Light Screen remains for the fifth following player turn")
    step(b);check(BossBattleEffects.read(b)["screen"]==0,"Light Screen expires after exactly five following player turns")
    b=fixture("gym:nessa",834,94);select_move(b,746);step(b)
    check(not BossBattleEffects.trapped(b) and b.switch_reason(b.party[1].uid).is_empty(),"Ghost Pokemon retain escape from trapping effects")
func func_move(b:TacticalBattle,id:int) -> void:
    # Isolated engine probe for conditional moves; this is not a saved trainer definition.
    b.enemy_definitions[b.enemy_index]["intents"]=[{"kind":"move","value":0,"move_id":id}]
    b.opening()["intent"]=0
    b.opening().erase("effects_v3")
func matrix() -> void:
    var pristine:=var_to_bytes(BossMoveEffectsP2.data())
    for key:String in BossMoveEffectsP2.data()["profiles"]:
        var p:Dictionary=BossMoveEffectsP2.data()["profiles"][key]
        for level in [18,50,100]:
            var b:=fixture(p["boss"],int(p["species"]),143,level)
            check(BossTactics.valid(b.enemy_definitions[0]),"Canonical P2 definition accepted")
            for i in p["intents"].size()+3:
                b.phase=TacticalBattle.PLAYER
                for member:BattlePokemon in b.party:member.hp=member.max_hp;member.knocked_out=false;member.statuses.clear()
                b.enemy().hp=maxi(1,b.enemy().max_hp/2);b.enemy().knocked_out=false;b.enemy().statuses.clear()
                var before:=var_to_bytes(b.snapshot());var a:=b.intent();var target:=b.active();var hp:=target.hp;var block:=target.block
                check(a==b.intent() and before==var_to_bytes(b.snapshot()),"Public preview never mutates field/state/RNG")
                check(not EnemyTactics.intent_text(a).is_empty(),"Every implemented phase has an explanation")
                step(b)
                if a["damage_class"]!="status":check(hp-target.hp==mini(hp,maxi(0,int(a["value"])-block)),"Conditional damage executes exactly as advertised")
                check(BossMoveEffectsP2.valid_state(b.opening(),b.enemy_definitions[0]),"Charge/recharge/lock counters remain canonical")
    check(pristine==var_to_bytes(BossMoveEffectsP2.data()),"Immutable engine data stays untouched")
func saves() -> void:
    var goldens:={1:"d4551ec7fb9e435be6aed77479e8ab75569b01a57025a0393b90c7ea1bb4f73c",712:"163c8a5c994bdd7c01ffb8729bd0c2d318bd130724adeefbc3a47c5fcbb21b51",2026:"acd46e5d8e97564aaf4cd874528da4bedd9b4eb6f644ab3708b00078f1f8efb0"}
    for seed_value:int in goldens:
        var r:=CampaignRoute.new(seed_value,7);var defs:Array=[]
        for i in r.stops.size():
            if r.stops[i]["kind"]!="rest":defs.append(r.opponents(i))
        check(var_to_bytes(defs).hex_encode().sha256_text()==goldens[seed_value],"Pre-edit v7 all69 future definitions remain byte-equivalent")
        check(CampaignRoute.new(seed_value,8).signature==r.signature,"v8 preserves route RNG, approved parties, camps and encounters")
    var found:={}
    for seed_value in 500:
        var r:=CampaignRoute.new(seed_value,8)
        for i in r.stops.size():
            var stop:Dictionary=r.stops[i]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var boss:String=stop["kind"]+":"+str(stop["trainer"]["leader_id"] if stop["kind"]=="gym" else stop["trainer"]["id"])
            var aces:=BossParties.aces(boss)
            for index in aces.size():
                var k:=boss+":"+str(aces[index])
                if BossMoveEffectsP2.data()["profiles"].has(k) and not found.has(k):found[k]=[seed_value,i,stop["party"].size()-aces.size()+index]
        if found.size()==105:break
    check(found.size()==105,"All105 representatives reachable through unchanged seeded routes")
    for k:String in found:
        var j:=TacticalJourney.new(found[k][0],"field_kit",[3,6,9],true,8)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[k][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:
            j.badges=8;j.elite_wins=int(j.current()["league_index"])
            for stop:Dictionary in j.route.stops:
                if stop["kind"]=="gym":j.badge_records.append({"type":stop["biome"]["type"],"biome":stop["biome"]["id"],"leader_id":stop["trainer"]["leader_id"]})
        j.enter_next();j.battle.enemy_index=found[k][2]
        for i in j.battle.enemy_index:j.battle.enemies[i].hp=0;j.battle.enemies[i].knocked_out=true
        j.battle.enemy().hp=maxi(1,j.battle.enemy().max_hp/2);j.battle._grant_turn_energy()
        for i in j.battle.enemy_definitions[j.battle.enemy_index]["intents"].size()+3:
            var restored:=checkpoint(j)
            if restored==null:break
            var before:=JourneySnapshot.encode(j)
            j.battle.end_turn();restored.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(restored),"Field/trap/conditional action resumes exactly with same RNG")
            if j.phase!=TacticalJourney.BATTLE or j.battle.phase!=TacticalBattle.PLAYER:j=JourneySnapshot.restore(before)
            for member:BattlePokemon in j.party:member.hp=member.max_hp;member.knocked_out=false;member.statuses.clear()
        if k=="gym:byron:411":
            j.battle.enemy().hp=j.battle.enemy().max_hp
            j.battle.enemy().block=0;j.battle.enemy().statuses.clear()
            select_move(j.battle,368)
            var owned:=card(j.battle,33)
            j.deck.append(owned);j._next_card_uid=maxi(j._next_card_uid,j.battle._next_uid)
            j.battle.play_card(owned.uid)
            var resumed:=checkpoint(j)
            if resumed!=null:check(resumed.battle.intent()["value"]==j.battle.intent()["value"] and resumed.battle.intent()["value"]>0,"Actual received hit and counter prediction survive save")
        if k=="gym:brock:208":
            j.battle.phase=TacticalBattle.PLAYER
            BossBattleEffects.write(j.battle)["rocks"]=true
            j.battle.party[1].hp=1
            j.battle.energy=3
            j.battle.switch_to(j.battle.party[1].uid)
            var resumed:=checkpoint(j)
            if resumed!=null:
                check(resumed.battle._pending=="hazard","Hazard-only deferred replacement validates and resumes")
                j.battle.switch_to(j.battle.party[0].uid);resumed.battle.switch_to(resumed.battle.party[0].uid)
                check(JourneySnapshot.encode(j)==JourneySnapshot.encode(resumed),"Hazard replacement restores without draw or energy duplication")
        var d:=JourneySnapshot.encode(j);var bad:=d.duplicate(true)
        bad["route_version"]=7;check(not JourneySnapshot.validate(bad),"Cannot inject v3 definitions into an old v7 save")
        bad=d.duplicate(true);bad["battle"]["boss_context"]=BossBattleEffects.DEFAULT.duplicate(true);bad["battle"]["boss_context"]["screen"]=999
        check(not JourneySnapshot.validate(bad),"Reject forged field duration")
        bad=d.duplicate(true);bad["battle"]["boss_context"]=BossBattleEffects.DEFAULT.duplicate(true);bad["battle"]["boss_context"]["traps"]={999:{"source":-1,"turns":3,"dot":true}}
        check(not JourneySnapshot.validate(bad),"Reject trap referencing a non-member")
    if FileAccess.file_exists("/tmp/boss-effects-v7-snapshot.bin"):
        var f:=FileAccess.open("/tmp/boss-effects-v7-snapshot.bin",FileAccess.READ);var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v7 save restores exactly")
    check(JourneySave.compatible_content("5de9a69473977ace2c89e2ba54e0951ca8c436ce9a47d611ac61b636f7acbf30"),"Accept actual previous v7 content fingerprint")
