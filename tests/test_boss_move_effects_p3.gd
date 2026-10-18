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
    return {"id":species,"name":p["name"],"type":p["types"][0],"types":p["types"],"max_hp":PokemonStats.value(species,level,"hp"),"level":level}.merged(BossMoveEffectsP3.build(key,species))
func fixture(key:="gym:brock",species:=208,ally:=143,level:=50) -> TacticalBattle:
    var j:=TacticalJourney.new(7,"field_kit",[ally,6,9],true,9)
    for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
    var b:=TacticalBattle.new()
    b.start_with(j.party,j.deck,[definition(key,species,level)],712,"field_kit")
    b.full_type_chart=true
    for p:BattlePokemon in b.party+b.enemies:p.block=0
    return b
func select_move(b:TacticalBattle,id:int) -> void:
    if b.opening().has("effects_v4"):
        b.opening()["effects_v4"].merge({"charge":0,"recharge":false,"lock":0,"lock_left":0},true)
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
    check(JourneySnapshot.validate(d),"P3 phase checkpoint validates")
    if not JourneySnapshot.validate(d):return null
    var r:=JourneySnapshot.restore(d)
    check(JourneySnapshot.encode(r)==d,"HP, field, trap, substitute, guard and RNG roundtrip")
    return r
func run() -> void:
    check(CampaignRoute.VERSION>=9 and BossMoveEffectsP3.data()["profiles"].size()==138 and BossMoveEffectsP3.data()["moves"].size()==233,"Complete reviewed ace scope, separate from player919 mechanics")
    var b:=fixture("gym:clair",230);select_move(b,281)
    step(b);check(not b.active().statuses.has("sleep") and BossBattleEffectsP3.read(b)["drowsy"].has(b.active().uid),"Yawn is delayed rather than immediate sleep")
    b.end_turn();check(b.active().statuses.has("sleep"),"Yawn sleeps at end of next player turn")
    var c:=card(b,33);var before:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Drowsy sleep rejects owned techniques atomically")
    b=fixture("gym:clair",230);select_move(b,281);step(b)
    b.switch_to(b.party[1].uid);b.end_turn();check(not b.party[0].statuses.has("sleep"),"Switching removes Yawn before sleep")
    b=fixture("gym:clair",230);select_move(b,281);b.active().statuses["poison"]={"turns":3,"source_uid":-1}
    check(b.intent().get("failed_move",false),"Yawn fails against existing major ailment")
    b=fixture("gym:whitney",241);select_move(b,213);c=card(b,33);var full:int=b.card_view(c)["preview_damage"]
    step(b);check(b.card_view(c)["preview_damage"]==maxi(1,full/2),"Attract reduces source-targeted owned technique damage deterministically")
    b.switch_to(b.party[1].uid);check(not BossBattleEffectsP3.read(b)["infatuation"].has(b.party[0].uid),"Switch removes Attract")
    b=fixture("gym:whitney",241);select_move(b,156);b.enemy().hp/=2;step(b)
    check(b.enemy().statuses.get("sleep",{}).get("turns")==2,"Live Whitney Rest leaves two sleeping actions")
    var a:=b.intent();check(a.has("called_move") and a["called_move"] in [34,213],"Live sleeping Whitney calls one eligible own move")
    step(b);step(b);check(not b.enemy().statuses.has("sleep"),"Two live Sleep Talk actions allow Rest sleep to finish")
    b=fixture("gym:flannery",324);select_move(b,174);step(b)
    check(b.enemy().stat_stages=={"attack":1,"defense":1,"speed":-1},"Non-Ghost Curse raises Attack/Defense and lowers Speed")
    b=fixture("gym:bea",68);select_move(b,282);b.active().held_item="power_band"
    var power:int=b.intent()["base_power"];step(b)
    check(power==97 and b.active().held_item.is_empty(),"Knock Off boosts power and actually disables equipped item")
    b._damage(b.enemy(),b.enemy().hp,true);b._outcome()
    check(b.party[0].held_item=="power_band","Equipment is restored at battle completion")
    b=fixture("gym:norman",289);select_move(b,498);a=b.intent();b.active().stat_stages["defense"]=6
    check(b.intent()["value"]==a["value"],"Chip Away ignores target Defense changes, not a held-item effect")
    b=fixture("gym:marnie",861);select_move(b,663);a=b.intent();b.active().stat_stages["defense"]=-6
    check(b.intent()["value"]==a["value"],"Darkest Lariat ignores negative as well as positive Defense changes")
    b=fixture("gym:gordie",839);select_move(b,749);var affinity:=b.multiplier("fire",b.active());step(b)
    check(b.multiplier("fire",b.active())==affinity*2 and b.active().stat_stages.get("speed")==-1,"Tar Shot changes Fire effectiveness and Speed")
    b.switch_to(b.party[1].uid);check(not BossBattleEffectsP3.read(b)["tar"].has(b.party[0].uid),"Switch removes Tar Shot")
    b=fixture("gym:piers",862);select_move(b,675);step(b);c=card(b,304);before=var_to_bytes(b.snapshot())
    check(b.card_reason(c.uid).contains("음성") and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Throat Chop refuses sound cards with no cost")
    c=card(b,33);check(b.card_reason(c.uid).is_empty(),"Silence allows non-sound techniques")
    b=fixture("gym:avery",10172);select_move(b,826);c=card(b,33);b.play_card(c.uid);step(b);c=card(b,33)
    check(b.card_reason(c.uid).contains("섬뜩") and not b.play_card(c.uid).is_empty(),"Eerie Spell seals matching copies of last technique")
    c=card(b,53);check(b.card_reason(c.uid).is_empty(),"Eerie seal permits a different move")
    b=fixture("gym:klara",10165);select_move(b,801)
    b.enemy().stat_stages["attack"]=6;b.enemy().stat_stages["special_attack"]=-6
    check(b.intent()["damage_class"]=="physical","Shell Side Arm selects physical against actual staged defenses")
    b.enemy().stat_stages["attack"]=-6;b.enemy().stat_stages["special_attack"]=6
    check(b.intent()["damage_class"]=="special","Shell Side Arm can select special")
    b=fixture("gym:mustard",10191);select_move(b,818);a=b.intent()
    b.enemy().stat_stages["attack"]=-6;b.active().stat_stages["defense"]=6
    check(b.intent()["per_hit"]==a["per_hit"] and a["hits"]==3,"Guaranteed critical hits ignore adverse stages")
    b.enemy().statuses["burn"]={"turns":3,"source_uid":1}
    check(b.intent()["per_hit"]<a["per_hit"],"Guaranteed critical hits still respect burn damage reduction")
    var m:=BossMoveEffectsP3.view(818)
    check(a["per_hit"]==PokemonStats.damage(BossMoveEffectsP3._clone(fixture("gym:mustard",10191).enemy()),fixture("gym:mustard",10191).active(),m,1.0,0,1.5),"Surging Strikes includes fixed critical multiplier")
    b=fixture("gym:katy",901);select_move(b,838);step(b)
    check(b.enemy().stat_stages.get("defense")==-1 and b.enemy().stat_stages.get("special_defense")==-1,"Headlong Rush actually weakens both defenses")
    b=fixture("gym:olympia",10025);select_move(b,252);check(not b.intent().get("failed_move",false),"Fake Out succeeds if it is genuinely the first action")
    step(b);select_move(b,252);check(b.intent().get("failed_move",false),"Fake Out fails after acting without moving approved cycle")
    b=fixture("elite:glacia",365,143,50);select_move(b,329)
    check(b.intent().get("failed_move",false) and b.intent()["value"]==0,"Adapted OHKO fails against a higher-level target")
    b.active().level=50;PokemonStats.apply(b.active(),true);check(b.intent()["base_power"]==160 and b.intent()["value"]<b.active().max_hp,"OHKO is a normal visible strong move, not automatic knockout")
    b=fixture("elite:glacia",365,131,100);select_move(b,329);check(b.intent().get("failed_move",false),"Sheer Cold cannot affect Ice types")
    b=fixture("elite:marshal",620,94);select_move(b,136);var hp:=b.enemy().hp
    check(b.intent()["value"]==0 and b.intent().get("crash",0)==b.enemy().max_hp/2,"High Jump Kick advertises crash on Ghost immunity")
    step(b);check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/2),"Failed High Jump Kick pays the advertised piercing crash")
    b=fixture("elite:marshal",620);select_move(b,340);step(b)
    check(BossBattleEffectsP3.read(b)["airborne"].get(b.enemy().uid,false) and b.intent()["kind"]=="move","Bounce really prepares before attacking")
    c=card(b,34);hp=b.enemy().hp;b.play_card(c.uid);check(b.enemy().hp==hp and not b.enemy().statuses.has("paralysis"),"Airborne avoids ordinary damage and secondary effects")
    c=card(b,87);check(b.card_view(c)["preview_damage"]>0,"Thunder can hit an airborne enemy")
    step(b);check(not BossBattleEffectsP3.read(b)["airborne"].has(b.enemy().uid),"Bounce lands before its attacking action")
    b=fixture("champion:blue",18);select_move(b,143)
    check(b.intent()["kind"]=="prepare","Sky Attack has its explicit charging phase")
    step(b);check(b.intent()["value"]>0,"Sky Attack becomes a real attack after charging")
    b=fixture("champion:blue",18);select_move(b,119);check(b.intent().get("failed_move",false),"Mirror Move fails without a copyable attack")
    c=card(b,53);b.play_card(c.uid);a=b.intent()
    check(a["name"].contains("화염방사") and a["damage_class"]=="special","Mirror Move previews the actual last attack card")
    step(b);check(b.active().statuses.has("burn"),"Mirror Move carries copied basic secondary status")
    b=fixture("elite:kahili",733);select_move(b,690);c=card(b,33);b.play_card(c.uid)
    check(b.active().statuses.has("burn"),"Contact during Beak Blast telegraph actually burns")
    b=fixture("elite:kahili",733);select_move(b,690);c=card(b,53);b.play_card(c.uid)
    check(not b.active().statuses.has("burn"),"Non-contact attacks do not trigger Beak Blast burn")
    b=fixture("elite:poppy",959);select_move(b,893);step(b);select_move(b,893)
    check(b.intent().get("failed_move",false),"Gigaton Hammer cannot succeed twice consecutively")
    b=fixture("elite:hassel",998);select_move(b,862);c=card(b,33);full=b.card_view(c)["preview_damage"];step(b)
    check(b.card_view(c)["preview_damage"]==full*2,"Glaive Rush leaves actual double-damage vulnerability")
    step(b);check(not BossBattleEffectsP3.read(b)["vulnerable"].has(b.enemy().uid),"Glaive vulnerability expires at next own action")
    b=fixture("elite:crispin",257);select_move(b,915);check(b.intent()["base_power"]==75,"Temper Flare is normal power without previous failure")
    b.enemy().statuses["sleep"]={"turns":1,"source_uid":1};step(b);select_move(b,915)
    check(b.intent()["base_power"]==150 and not BossMoveEffectsP3.view(915).has("burn"),"Temper Flare doubles after failure; it is not Burning Jealousy")
    b=fixture("champion:nemona",923);select_move(b,892);step(b);select_move(b,892)
    check(b.intent().get("failed_move",false) and b.multiplier("ground",b.enemy())==1,"Double Shock consumes Electric typing in context and fails on reuse")
    check(b.enemy().types==catalog.species(923)["types"],"Permanent species types remain untouched for persistence")
    b=fixture("champion:kieran",1019);select_move(b,907)
    var strong:=0
    for i in 10:
        select_move(b,907)
        # Retain move-specific usage memory when selecting the same canonical slot.
        if i>0:b.opening()["effects_v4"]=a
        var next:=b.intent();if next["base_power"]==160:strong+=1
        b.active().hp=b.active().max_hp;step(b);a=BossMoveEffectsP3.state(b).duplicate(true)
    check(strong==3,"Fickle Beam exposes exactly three strong uses per deterministic10-use cycle")
    for key:String in ["champion:geeta","elite:lacey","champion:kieran"]:
        var species:int={"champion:geeta":970,"elite:lacey":530,"champion:kieran":1019}[key]
        b=fixture(key,species);select_move(b,851);step(b)
        check(not b.enemy().stat_stages.has("attack") and not b.enemy().stat_stages.has("special_attack"),"Non-Tera Tera Blast never applies Stellar stat drops")
    traps()
    destiny()
    matrix()
    saves()
    print("Boss move effects P3: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
func traps() -> void:
    for id in [611,746]:
        var b:=fixture("gym:nessa",834);func_move(b,id);step(b)
        check(BossBattleEffectsP3.trapped(b),"Live trapping move prevents escape")
        var c:=card(b,33,b.party[1].uid);var before:=var_to_bytes(b.snapshot())
        check(not b.switch_to(b.party[1].uid).is_empty() and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Manual and owned-card auto-switch are blocked atomically")
        c=card(b,33);check(b.card_reason(c.uid).is_empty(),"Trapped active Pokemon can still use its own techniques")
        c=card(b,229);b.play_card(c.uid);check(not BossBattleEffectsP3.trapped(b),"Rapid Spin releases the trapped player")
        func_move(b,id);step(b);b._damage(b.enemy(),b.enemy().hp,true)
        check(not BossBattleEffectsP3.trapped(b),"Trapper knockout immediately releases the player")
    var b:=fixture("gym:nessa",834,94);select_move(b,746);step(b)
    check(not BossBattleEffectsP3.trapped(b) and b.switch_reason(b.party[1].uid).is_empty(),"Ghost escape exception remains")
    b=fixture("gym:nessa",834);select_move(b,746);step(b)
    b._damage(b.active(),b.active().hp,true);b.phase=TacticalBattle.REPLACE;b._pending="player"
    check(b.switch_reason(b.party[1].uid).is_empty(),"Fainted trapped Pokemon never prevents mandatory replacement")
func destiny() -> void:
    var b:=fixture("gym:morty",94);select_move(b,194);step(b)
    var c:=card(b,247);b.enemy().block=0;b.enemy().hp=1;b.play_card(c.uid)
    check(not b.party[0].alive(),"Destiny Bond really knocks out direct technique attacker")
    b=fixture("gym:morty",94);select_move(b,194);step(b);b._damage(b.enemy(),b.enemy().hp,true)
    check(b.party[0].alive(),"Passive/recoil damage does not trigger Destiny Bond")
    b=fixture("gym:morty",94);select_move(b,194);step(b);step(b)
    check(not BossBattleEffectsP3.read(b)["destiny"].has(b.enemy().uid),"Destiny Bond expires before the next enemy action")
func func_move(b:TacticalBattle,id:int) -> void:
    # Isolated engine probe for conditional moves; this is not a saved trainer definition.
    b.enemy_definitions[b.enemy_index]["intents"]=[{"kind":"move","value":0,"move_id":id}]
    b.opening()["intent"]=0
    b.opening().erase("effects_v4")
func matrix() -> void:
    var pristine:=var_to_bytes(BossMoveEffectsP3.data())
    for key:String in BossMoveEffectsP3.data()["profiles"]:
        var p:Dictionary=BossMoveEffectsP3.data()["profiles"][key]
        for level in [18,50,100]:
            var b:=fixture(p["boss"],int(p["species"]),143,level)
            check(BossTactics.valid(b.enemy_definitions[0]),"Canonical P3 definition accepted")
            for i in p["intents"].size()+3:
                b.phase=TacticalBattle.PLAYER
                for member:BattlePokemon in b.party:member.hp=member.max_hp;member.knocked_out=false;member.statuses.clear()
                b.enemy().hp=maxi(1,b.enemy().max_hp/2);b.enemy().knocked_out=false;b.enemy().statuses.clear()
                var before:=var_to_bytes(b.snapshot());var a:=b.intent();var target:=b.active();var hp:=target.hp;var block:=target.block
                check(a==b.intent() and before==var_to_bytes(b.snapshot()),"Public preview never mutates field/state/RNG")
                check(not EnemyTactics.intent_text(a).is_empty(),"Every implemented phase has an explanation")
                step(b)
                if a["damage_class"]!="status":check(hp-target.hp==mini(hp,maxi(0,int(a["value"])-block)),"Conditional damage executes exactly as advertised")
                check(BossMoveEffectsP3.valid_state(b.opening(),b.enemy_definitions[0]),"Charge/recharge/lock counters remain canonical")
    check(pristine==var_to_bytes(BossMoveEffectsP3.data()),"Immutable engine data stays untouched")
func saves() -> void:
    var goldens:={1:"b338792fe7d43a39ece7abdccfd69493d5a9470123382ed6374356e8da527b53",712:"577e08cd6cd8aa2e87aec93d8d84a77ff5baec2c45d3269a53ce9a7c817d7a20",2026:"39fe98312983c02e8bb8ce7488e426f81f067c4b395927ca28b843e6e125b1e4"}
    for seed_value:int in goldens:
        var r:=CampaignRoute.new(seed_value,8);var defs:Array=[]
        for i in r.stops.size():
            if r.stops[i]["kind"]!="rest":defs.append(r.opponents(i))
        check(var_to_bytes(defs).hex_encode().sha256_text()==goldens[seed_value],"Pre-edit v8 all69 future definitions remain byte-equivalent")
        check(CampaignRoute.new(seed_value,9).signature==r.signature,"v9 preserves route RNG, approved parties, camps and encounters")
    var found:={}
    for seed_value in 500:
        var r:=CampaignRoute.new(seed_value,9)
        for i in r.stops.size():
            var stop:Dictionary=r.stops[i]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var boss:String=stop["kind"]+":"+str(stop["trainer"]["leader_id"] if stop["kind"]=="gym" else stop["trainer"]["id"])
            var aces:=BossParties.aces(boss)
            for index in aces.size():
                var k:=boss+":"+str(aces[index])
                if BossMoveEffectsP3.data()["profiles"].has(k) and not found.has(k):found[k]=[seed_value,i,stop["party"].size()-aces.size()+index]
        if found.size()==138:break
    check(found.size()==138,"All138 representatives reachable through unchanged seeded routes")
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
        j.battle.enemy().hp=maxi(1,j.battle.enemy().max_hp/2);j.battle._grant_turn_energy()
        for i in j.battle.enemy_definitions[j.battle.enemy_index]["intents"].size()+3:
            var restored:=checkpoint(j)
            if restored==null:break
            var before:=JourneySnapshot.encode(j)
            j.battle.end_turn();restored.battle.end_turn()
            check(JourneySnapshot.encode(j)==JourneySnapshot.encode(restored),"Field/trap/conditional action resumes exactly with same RNG")
            if j.phase!=TacticalJourney.BATTLE or j.battle.phase!=TacticalBattle.PLAYER:j=JourneySnapshot.restore(before)
            for member:BattlePokemon in j.party:member.hp=member.max_hp;member.knocked_out=false;member.statuses.clear()
        if k in ["gym:avery:10172","champion:blue:18","gym:bea:68"]:
            j.battle.phase=TacticalBattle.PLAYER
            j.battle.enemy().hp=j.battle.enemy().max_hp;j.battle.enemy().block=0;j.battle.enemy().statuses.clear()
            var owned:=card(j.battle,33)
            j.deck.append(owned);j._next_card_uid=maxi(j._next_card_uid,j.battle._next_uid)
            j.battle.play_card(owned.uid)
            if k=="gym:avery:10172":select_move(j.battle,826);step(j.battle)
            if k=="champion:blue:18":select_move(j.battle,119)
            if k=="gym:bea:68":
                j.battle.active().held_item="power_band"
                select_move(j.battle,282);step(j.battle)
            var resumed:=checkpoint(j)
            if resumed!=null:check(resumed.battle.boss_context==j.battle.boss_context,"Last move/copy/seal/temporary equipment markers persist exactly")
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
            BossBattleEffectsP3.write(j.battle)["rocks"]=true
            j.battle.party[1].hp=1
            j.battle.energy=3
            j.battle.switch_to(j.battle.party[1].uid)
            var resumed:=checkpoint(j)
            if resumed!=null:
                check(resumed.battle._pending=="hazard","Hazard-only deferred replacement validates and resumes")
                j.battle.switch_to(j.battle.party[0].uid);resumed.battle.switch_to(resumed.battle.party[0].uid)
                check(JourneySnapshot.encode(j)==JourneySnapshot.encode(resumed),"Hazard replacement restores without draw or energy duplication")
        var d:=JourneySnapshot.encode(j);var bad:=d.duplicate(true)
        bad["route_version"]=8;check(not JourneySnapshot.validate(bad),"Cannot inject v3 definitions into an old v7 save")
        bad=d.duplicate(true);bad["battle"]["boss_context"]=BossBattleEffectsP3.DEFAULT.duplicate(true);bad["battle"]["boss_context"]["screen"]=999
        check(not JourneySnapshot.validate(bad),"Reject forged field duration")
        bad=d.duplicate(true);bad["battle"]["boss_context"]=BossBattleEffectsP3.DEFAULT.duplicate(true);bad["battle"]["boss_context"]["traps"]={999:{"source":-1,"turns":3,"dot":true}}
        check(not JourneySnapshot.validate(bad),"Reject trap referencing a non-member")
    var context:=BossBattleEffectsP3.DEFAULT.duplicate(true)
    var foe:=definition("gym:morty",94)
    var shape:Dictionary={"enemy_definitions":[foe],"turn":1,"party":[1,2,3],"enemies":[-1]}
    check(BossBattleEffectsP3.valid_context(context,shape),"Canonical fresh v9 context validates")
    for group:String in ["drowsy","infatuation","silence","seals","curses","tar","removed_items","last_moves","destiny","vulnerable","airborne","spent_electric","mirror"]:
        var bad:=context.duplicate(true);bad[group][999]=true
        check(not BossBattleEffectsP3.valid_context(bad,shape),"Reject foreign UID in v9 marker: "+group)
    var bad_state:Dictionary={"intent":0,"effects_v4":BossMoveEffectsP3.INITIAL.duplicate(true)}
    bad_state["effects_v4"]["fickle"]=10
    check(not BossMoveEffectsP3.valid_state(bad_state,foe),"Reject forged Fickle cycle counter")
    bad_state["effects_v4"]["fickle"]=0;bad_state["effects_v4"]["actions"]=-1
    check(not BossMoveEffectsP3.valid_state(bad_state,foe),"Reject negative action count")
    if FileAccess.file_exists("/tmp/boss-effects-v8-snapshot.bin"):
        var f:=FileAccess.open("/tmp/boss-effects-v8-snapshot.bin",FileAccess.READ);var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()))
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v8 save restores exactly")
    check(JourneySave.compatible_content("36fe00197a9e4de42cae2a20b6dffe564f7478250f8659812a68790fc76bae08"),"Accept actual previous v8 content fingerprint")
