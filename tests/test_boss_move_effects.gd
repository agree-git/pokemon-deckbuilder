extends SceneTree
var checks := 0
var failures := 0
var catalog := VisualCatalog.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func definition(key: String,species: int,level := 50) -> Dictionary:
    var p := catalog.species(species)
    var d := {"id":species,"name":p["name"],"type":p["types"][0],"types":p["types"],"max_hp":PokemonStats.value(species,level,"hp"),"level":level}
    d.merge(BossMoveEffects.build(key,species),true)
    return d
func fixture(key := "elite:caitlin",species := 576,level := 50,ally := 143) -> TacticalBattle:
    var helper := TacticalJourney.new(7,"field_kit",[ally,6,9],true)
    for p: BattlePokemon in helper.party:
        p.level = level
        PokemonStats.apply(p,true)
    var b := TacticalBattle.new()
    b.start_with(helper.party,helper.deck,[definition(key,species,level)],712,"field_kit")
    b.full_type_chart = true
    return b
func select_move(b: TacticalBattle,id: int) -> void:
    for i in b.enemy_definitions[0]["intents"].size():
        if int(b.enemy_definitions[0]["intents"][i]["move_id"]) == id: b.opening()["intent"] = i; return
    check(false,"Fixture contains move "+str(id))
func direct(b: TacticalBattle) -> void:
    b.events.clear()
    BossMoveEffects.execute(b,b.intent())
func checkpoint(j: TacticalJourney) -> TacticalJourney:
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"P0 route/effects checkpoint validates")
    if not JourneySnapshot.validate(data): return null
    var restored := JourneySnapshot.restore(data)
    check(JourneySnapshot.encode(restored) == data,"P0 HP, stages, ailments, intent and draw RNG roundtrip")
    return restored
func run() -> void:
    check(CampaignRoute.VERSION == 6 and BossMoveEffects.data()["profiles"].size() == 19 and BossMoveEffects.data()["deferred"].size() == 119,"Explicit P0 rollout; no placeholder effects for119 representatives")
    var pristine := var_to_bytes(BossMoveEffects.data())
    for profile_key: String in BossMoveEffects.data()["profiles"]:
        var profile: Dictionary = BossMoveEffects.data()["profiles"][profile_key]
        var key: String = profile["boss"]
        var species := int(profile["species"])
        check(BossParties.aces(key).has(species),"Authored moves only belong to approved representatives")
        for level in [18,50,100]:
            var b := fixture(key,species,level)
            check(BossTactics.valid(b.enemy_definitions[0]),"Canonical authored definition accepted")
            for action_index in profile["intents"].size():
                b.opening()["intent"] = action_index
                b.enemy().hp = maxi(1,b.enemy().max_hp/2)
                b.enemy().stat_stages.clear()
                b.active().hp = b.active().max_hp
                b.active().statuses.clear()
                b.active().stat_stages.clear()
                var state := var_to_bytes([b.active().snapshot(),b.enemy().snapshot(),b.enemy_states,b._rng.state,b.energy,b.hand.map(func(c: BattleCardInstance):return c.uid)])
                var preview := b.intent()
                check(preview == b.intent() and state == var_to_bytes([b.active().snapshot(),b.enemy().snapshot(),b.enemy_states,b._rng.state,b.energy,b.hand.map(func(c: BattleCardInstance):return c.uid)]),"Repeated preview is pure, deterministic and does not draw RNG")
                check(not EnemyTactics.intent_text(preview).is_empty() and not EnemyTactics.description(b.enemy_definitions[0]).is_empty(),"Every move and generic guard have a usable explanation")
                var actor_hp := b.enemy().hp
                direct(b)
                check(b.enemy().hp <= b.enemy().max_hp and b.enemy().hp >= actor_hp,"Recovery caps at missing HP and never mutates target HP")
                if preview["kind"] == "move":
                    var move := BossMoveEffects.view(int(preview["move_id"]))
                    if b.active().alive() and not preview["immune"]:
                        for status: String in BossMoveEffects.STATUSES:
                            if move.has(status): check(int(b.active().statuses.get(status,{}).get("turns",0)) == int(move[status]),"Actual secondary status matches public preview")
                    if move.has("stat_changes"):
                        var target := b.enemy() if move["stat_target"] == "self" else b.active()
                        if target.alive() and not preview["immune"]:
                            for stat: String in move["stat_changes"]:
                                check(int(target.stat_stages.get(stat,0)) == int(move["stat_changes"][stat]),"Move-specific target and stat delta executed")
                else: check(b.enemy().block == preview["value"],"Generic guard applies the previewed protection without a fake Reflect move")
    check(var_to_bytes(BossMoveEffects.data()) == pristine,"Battle execution never mutates frozen move/profile content")
    var b := fixture()
    select_move(b,347)
    direct(b)
    check(b.enemy().stat_stages.get("special_attack") == 1 and b.enemy().stat_stages.get("special_defense") == 1 and b.enemy().strength == 0,"Calm Mind raises actual SpA and SpD, not generic strength")
    for i in 10: direct(b)
    check(b.enemy().stat_stages["special_attack"] == 6 and b.enemy().stat_stages["special_defense"] == 6 and EnemyTactics.intent_text(b.intent()).contains("+0단계"),"Stat cap and capped preview agree")
    b = fixture("elite:hala",740)
    select_move(b,370)
    var prior := b.active().stat_stages.duplicate()
    direct(b)
    check(b.enemy().stat_stages.get("defense") == -1 and b.enemy().stat_stages.get("special_defense") == -1 and b.active().stat_stages == prior,"Close Combat's defensive cost belongs to its user")
    select_move(b,665)
    direct(b)
    check(b.enemy().stat_stages.get("speed") == -1,"Ice Hammer speed cost belongs to its user")
    b = fixture("gym:misty",121,50,112)
    select_move(b,85)
    var hp := b.active().hp
    direct(b)
    check(b.active().hp == hp and not b.active().statuses.has("paralysis"),"Type immunity blocks direct damage and on-hit ailments")
    b = fixture("gym:iono",429,50,112)
    select_move(b,451)
    direct(b)
    check(b.enemy().stat_stages.get("special_attack",0)==0,"Immune Charge Beam does not grant an on-hit self boost")
    b = fixture("gym:winona",334)
    select_move(b,355)
    b.enemy().hp = b.enemy().max_hp-1
    direct(b)
    check(b.enemy().hp == b.enemy().max_hp and b.enemy().types == catalog.species(334)["types"],"Roost caps recovery and explicitly preserves types")
    b = fixture("gym:misty",121)
    select_move(b,58)
    b.end_turn()
    check(b.active().statuses.has("sleep"),"Enemy frozen-status adaptation blocks one player technique turn")
    var owned: BattleCardInstance = null
    for c: BattleCardInstance in b.hand:
        if c.owner_uid == b.active().uid: owned=c;break
    if owned == null:
        owned=BattleCardInstance.new(9999,"move_33",b.active().uid)
        b.hand.append(owned)
    var snapshot := var_to_bytes([b.hand,b.energy,b.active().snapshot(),b._rng.state])
    check(b.card_reason(owned.uid).contains("수면") and not b.play_card(owned.uid).is_empty() and snapshot == var_to_bytes([b.hand,b.energy,b.active().snapshot(),b._rng.state]),"Sleeping technique refusal consumes no card/energy/RNG")
    var another: BattleCardInstance = null
    for c: BattleCardInstance in b.hand:
        if c.owner_uid != 0 and c.owner_uid != b.active().uid and int(b.card_view(c)["cost"])<=b.energy: another=c;break
    if another == null:
        another=BattleCardInstance.new(9998,"move_33",b.party[1].uid)
        b.hand.append(another)
    check(b.play_card(another.uid).is_empty() and b.active().uid==another.owner_uid,"Awake teammate technique still switches and executes")
    b = fixture("gym:misty",121)
    select_move(b,58)
    b.active().hp=1
    b.active().block=0
    direct(b)
    check(not b.active().alive() and b.active().statuses.is_empty(),"On-hit ailment does not attach to a fainted ally or the replacement")
    b = fixture()
    b.enemy().statuses["sleep"]={"turns":1,"source_uid":b.active().uid}
    b.opening()["intent"]=b.enemy_definitions[0]["intents"].size()-1
    check(b.intent().get("asleep",false),"Sleeping guard preview also shows cancellation")
    b.end_turn()
    check(b.enemy().block==0 and not b.enemy().statuses.has("sleep"),"Sleeping enemy skips generic guard and expires sleep normally")
    # All current trainer parties are unchanged; only final representative definitions opt in.
    var route := CampaignRoute.new(712)
    var league: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var roster: Dictionary={"gym":GymLeaders.all(),"elite":league["elite"]+BossExpansion.data()["elite"],"champion":league["champions"]+BossExpansion.data()["champions"]}
    var authored_count:=0
    for role: String in roster:
        for trainer: Dictionary in roster[role]:
            trainer=BossParties.apply(role,trainer)
            var key:=role+":"+str(trainer.get("leader_id",trainer.get("id")))
            var ids:=BossParties.party(key)
            route.stops[14]={"kind":role,"trainer":trainer,"party":ids,"biome":catalog.biomes[0],"level":50}
            var defs:=route.opponents(14)
            check(defs.map(func(d:Dictionary):return d["id"])==ids,"No roster/order changes for "+key)
            for slot in defs.size():
                if defs[slot].has("boss_moves_version"):
                    authored_count+=1
                    check(slot==ids.size()-1 and BossMoveEffects.valid(defs[slot]),"Only exact last representative gets new effects, including duplicate Xatu")
    check(authored_count==19,"Exactly19 activated representatives across137 parties")
    # Captured from unmodified be8f5f5 before editing this feature.
    var old={1:["761176d92a3d7470b26e826612772b81762c0abd370a31649905cfada8e14e45","3adc6d15e0fd4d6c0d3cf8c8cbd950d6ef6aef8d65b87d8b07053f1d66b29840"],712:["b12e94787e42328636f355a55b5b7881fc98b23d61d6b35abd5bec771876313c","dfab6b1db43cbbe46920c6f560ffd5c28284abee63740ddb6367c4a5ad65bdeb"],2026:["668152d7a6a6a013a3bc9fbc67f298a90b350d834e3b74a991b7fdb6d0389e70","f390aba2c383039efdca1047bc317aa9b79dbf429bcf10d09cba1157d5ef8ec2"]}
    for seed_value: int in old:
        var historical:=CampaignRoute.new(seed_value,5)
        var fresh:=CampaignRoute.new(seed_value,6)
        var all_defs:Array=[]
        check(historical.signature==old[seed_value][0] and fresh.stops==historical.stops,"v5/v6 party, identity, camps and route RNG unchanged")
        for step in historical.stops.size():
            if historical.stops[step]["kind"]!="rest": all_defs.append(historical.opponents(step))
        check(var_to_bytes(all_defs).hex_encode().sha256_text()==old[seed_value][1],"Every future v5 opponent retains its exact historical move pattern")
    # Reach every rollout through a real seeded route, then save at each actual ace action.
    var found:Dictionary={}
    for seed_value in 350:
        var candidate:=CampaignRoute.new(seed_value)
        for step in candidate.stops.size():
            var stop:Dictionary=candidate.stops[step]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var key:=TrainerDialogue.key(TrainerDialogue.opponent(stop,stop["biome"]))
            if BossMoveEffects.profile(key,int(stop["party"][-1])).is_empty() or found.has(key):continue
            found[key]=[seed_value,step]
        if found.size()==19:break
    check(found.size()==19,"All19 representatives are reachable without altering route selection")
    for key: String in found:
        var j:=TacticalJourney.new(found[key][0],"field_kit",[3,6,9],true)
        j.step=found[key][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:
            j.badges=8;j.elite_wins=int(j.current()["league_index"])
            for stop:Dictionary in j.route.stops:
                if stop["kind"]=="gym": j.badge_records.append({"type":stop["biome"]["type"],"biome":stop["biome"]["id"],"leader_id":stop["trainer"]["leader_id"]})
        j.enter_next()
        j.battle.enemy_index=j.battle.enemies.size()-1
        for i in j.battle.enemy_index:j.battle.enemies[i].hp=0;j.battle.enemies[i].knocked_out=true
        j.battle._grant_turn_energy()
        for action_index in j.battle.enemy_definitions[-1]["intents"].size():
            j.battle.opening()["intent"]=action_index
            var restored:=checkpoint(j)
            if restored==null:continue
            var before:=JourneySnapshot.encode(j)
            restored.battle.end_turn();j.battle.end_turn()
            check(JourneySnapshot.encode(restored)==JourneySnapshot.encode(j),"Real enemy action matches after save restore")
            # Continue a valid endurance checkpoint without changing battle rules.
            if j.phase!=TacticalJourney.BATTLE or j.battle.phase!=TacticalBattle.PLAYER:
                j=JourneySnapshot.restore(before)
            for p:BattlePokemon in j.party:p.hp=p.max_hp;p.knocked_out=false;p.statuses.clear()
        var data:=JourneySnapshot.encode(j)
        var changed:=data.duplicate(true)
        changed["battle"]["enemy_definitions"][-1]["intents"][0]["move_id"]=165
        check(not JourneySnapshot.validate(changed),"Save rejects forged authored move rather than executing arbitrary effects")
        changed=data.duplicate(true)
        changed["battle"]["enemy_definitions"][-1]["intents"][0]["move_id"]=float(changed["battle"]["enemy_definitions"][-1]["intents"][0]["move_id"])
        check(not JourneySnapshot.validate(changed),"Save rejects float move IDs despite numeric equality")
        changed=data.duplicate(true);changed["route_version"]=5
        check(not JourneySnapshot.validate(changed),"New effects cannot be injected into a v5 save")
    var legacy:=TacticalJourney.new(712,"field_kit",[1,4,7],true,5)
    var path:="user://tests/old_boss_effects.json"
    var bytes:=var_to_bytes(JourneySnapshot.encode(legacy))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
    var file:=FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify({"version":1,"content":"8105ad5dafd74ab91cfd49421042e0281a9e15e0297f99563ea392faa3fc606e","payload":Marshalls.raw_to_base64(bytes),"sha256":bytes.hex_encode().sha256_text()}));file.close()
    var loaded:=JourneySave.new(path).load_journey()
    check(loaded!=null and JourneySnapshot.encode(loaded)==JourneySnapshot.encode(legacy),"Actual previous fingerprint envelope restores v5, not silently v6")
    print("Boss move effects: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
