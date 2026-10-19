extends SceneTree
const Evolution := preload("res://scripts/tactics/enemy_evolution.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func roundtrip(j: TacticalJourney,label_text: String) -> void:
    var state := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),label_text+" valid snapshot")
    if not JourneySnapshot.validate(state): return
    var restored := JourneySnapshot.restore(state)
    check(JourneySnapshot.encode(restored)==state,label_text+" exact active battle/UID/RNG restore")
    j.battle.end_turn(); restored.battle.end_turn()
    check(JourneySnapshot.encode(restored)==JourneySnapshot.encode(j),label_text+" identical next turn after restore")
func run() -> void:
    # Explicit boundary expectations, including an item/trade evolution's earlier level gate.
    var cases := [[6,15,4],[6,16,5],[6,35,5],[6,36,6],[3,31,2],[3,32,3],
        [149,29,147],[149,30,148],[149,54,148],[149,55,149],
        [635,49,633],[635,50,634],[635,63,634],[635,64,635],
        [637,58,636],[637,59,637],[248,54,247],[248,55,248],
        [31,15,29],[31,16,31],[94,24,92],[94,25,94],
        [462,29,81],[462,30,462],[134,1,134],[26,1,26],[208,1,208],
        [10115,27,104],[10115,28,10115],[10233,35,156],[10233,36,10233],
        [10092,19,10091],[10092,20,10092],[10093,19,10091],[10093,20,10093],
        [10116,35,657],[10116,36,10116],[10149,27,104],[10149,28,10149],
        [30551,34,667],[30551,35,30551],[10146,34,782],[10146,35,783],[10146,45,10146],
        [791,42,789],[791,43,790],[791,52,790],[791,53,791]]
    for row: Array in cases:
        check(Evolution.at_level(row[0],row[1])==row[2],"Evolution boundary "+str(row))
    var graph_ok := true
    for entry: Dictionary in PokedexExpansion.data()["pokemon"]:
        var id := int(entry["id"])
        var minimum := Evolution.minimum_level(id)
        graph_ok = graph_ok and Evolution.at_level(id,minimum)==id and Evolution.at_level(id,100)==id
        if minimum>1:
            var prior := Evolution.at_level(id,minimum-1)
            graph_ok = graph_ok and prior!=id and Evolution.minimum_level(prior)<minimum
    check(graph_ok,"Every national/regional/permanent form respects its boundary")
    var corrected := {"wild":0,"trainer":0,"veteran":0,"gym":0}
    for seed_value: int in [0,42,2026]:
        var route := CampaignRoute.new(seed_value,28)
        var baseline := CampaignRoute.new(seed_value,27)
        var signature := route.signature
        var original := var_to_bytes(route.stops)
        check(original==var_to_bytes(baseline.stops) and signature==baseline.signature,"Unchanged seed/route/approved roster/level/camp RNG")
        for step in range(0,137,2):
            var node := route.stops[step]
            var old := route.opponents(step)
            var actual := route.opponents(step,true)
            check(old.size()==actual.size(),"Party size and slot order preserved")
            for i in actual.size():
                var d: Dictionary = actual[i]
                var entry := PokedexExpansion.species(d["id"])
                check(Evolution.minimum_level(d["id"])<=d["level"],"No underlevel evolution in new encounter")
                check(d["level"]==old[i]["level"] and d["name"]==entry["name"] and d["types"]==entry["types"] and d["max_hp"]==PokemonStats.value(d["id"],d["level"],"hp"),"Resolved identity/type/HP/level agree")
                check(CampaignChallenge.valid(d,route,step),"Difficulty guard is based on resolved HP")
                if d["id"]!=old[i]["id"]:
                    corrected[node["kind"]] += 1
                    check(not d.has("boss_moves_version"),"Earlier stage does not inherit final ace-only moves")
                else: check(d==old[i],"Eligible species/ace keeps exact tactics")
            if node["kind"] in ["gym","elite","champion"]:
                var key: String = node["kind"]+":"+str(node["trainer"].get("leader_id",node["trainer"].get("id","")))
                check(node["party"]==BossParties.party(key),"Approved boss roster source remains untouched")
        check(var_to_bytes(route.stops)==original and route.signature==signature,"Resolving encounters cannot mutate route/signature")
    for kind: String in corrected: check(corrected[kind]>0,"Real generated correction coverage: "+kind)
    print("CORRECTED_SLOTS ",corrected)
    # All optional rare hunts are already gated beyond their evolution thresholds.
    var rare_ok := true
    for id: int in RareEncounter.IDS:
        var earliest := CampaignBalance.enemy_level(RareEncounter.requirement(id)*8)+int(RareEncounter.rule(id)["level_bonus"])
        rare_ok = rare_ok and Evolution.minimum_level(id)<=earliest
    check(rare_ok,"Rare identity/clue/level gates need no change")
    var fresh := TacticalJourney.new(0,"field_kit",[1,4,7],true)
    check(fresh.battle.enemy_definitions==fresh.opponents_at(0),"Opening battle uses corrected species")
    roundtrip(fresh,"Corrected opening")
    var gym := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    gym.step=14; gym.phase=TacticalJourney.MAP
    check(gym.enter_next().is_empty(),"Enter corrected first gym")
    roundtrip(gym,"Corrected gym")
    # Capture must grant the actual previous stage, not the original pool candidate.
    var capture := TacticalJourney.new(0,"field_kit",[1,4,7],true)
    var target := capture.battle.enemy().species_id
    capture.battle.enemy().hp=1
    check(capture.capture().is_empty() and capture.pending_captures[0].species_id==target,"Capture grants displayed corrected species")
    var legacy: Array = FileAccess.open("/tmp/pre-challenge-v27.bin",FileAccess.READ).get_var()
    for record: Dictionary in legacy:
        var state: Dictionary = record["state"]
        check(JourneySnapshot.validate(state),"Actual pre-patch v27 snapshot valid")
        var restored := JourneySnapshot.restore(state)
        check(JourneySnapshot.encode(restored)==state,"Actual v27 battle preserved exactly")
        check(var_to_bytes(restored.route.opponents(restored.step)).hex_encode().sha256_text()==record["opponents_hash"],"v27 future opponents stay frozen")
    var saved: Dictionary = FileAccess.open("/tmp/pokemon-challenge-review/results/seed-2026-false-boss-136.bin",FileAccess.READ).get_var()
    check(JourneySnapshot.validate(saved),"Actual pre-fix v28 snapshot valid")
    var old_run := JourneySnapshot.restore(saved)
    check(JourneySnapshot.encode(old_run)==saved,"Existing v28 active battle is not replaced")
    var store := JourneySave.new("user://enemy-evolution.json")
    check(store.save(old_run).is_empty(),"Existing v28 save file writes")
    var loaded := store.load_journey()
    check(loaded!=null and JourneySnapshot.encode(loaded)==saved,"Existing v28 save file restores exactly")
    if loaded!=null:
        old_run.battle.end_turn(); loaded.battle.end_turn()
        check(JourneySnapshot.encode(old_run)==JourneySnapshot.encode(loaded),"Existing v28 next action/RNG unchanged")
    print("ENEMY_EVOLUTION ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
