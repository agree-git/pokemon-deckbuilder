extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var catalog := VisualCatalog.new()
    var identities := {}
    var people := {}
    var regions := {}
    var expected := {"관동":10,"성도":8,"호연":9,"신오":8,"하나":14,"칼로스":8,"가라르":16,"팔데아":9}
    for leader: Dictionary in GymLeaders.all():
        var id: String = leader["leader_id"]
        check(not identities.has(id),"Unique candidate identity: "+id)
        identities[id] = true
        for person: String in leader["person_ids"]:
            check(not people.has(person),"Co-leaders share one encounter, without duplicate people")
            people[person] = true
        regions[leader["region"]] = int(regions.get(leader["region"],0))+1
        check(leader["party"].size() == 6 and leader["party"].duplicate().reduce(func(seen: Dictionary,species: Variant): seen[species]=true; return seen,{}).size() == 6,"Six distinct species per gym")
        check(leader["styles"].size() == 6 and leader["styles"].all(func(style: String): return BossTactics.STYLES.has(style)),"All six slots have supported tactical commands")
        for species: float in leader["party"]:
            var p := catalog.species(int(species))
            check(not p.is_empty() and int(species) <= 386 and not p["is_legendary"] and not p["is_mythical"],"Only supported, non-rare species")
            check(leader["type"] == "mixed" or leader["type"] in p["types"],"Specialist team follows its actual type")
    check(identities.size() == 82 and people.size() == 83 and regions == expected,"All eight gym regions, 82 teams / 83 people")
    for id: String in ["janine","blue","juan","chili","cilan","cress","iris","cheren","roxie","marlon","bea","allister","gordie","melony","bede","marnie","klara","avery","mustard","peony","tate_liza","tyme"]:
        check(identities.has(id),"Include version, former, joint and successor leaders: "+id)
    for type: String in VisualCatalog.TYPE_COLORS:
        var candidates := catalog.gym_candidates_for_type(type)
        check(candidates.size() >= 3,"Every biome has multiple specialist candidates plus mixed Blue")
        check(candidates.any(func(row: Dictionary): return row["leader_id"] == "blue"),"Mixed Blue is eligible in every biome")
        var excluding := catalog.gym_candidates_for_type(type,["blue","koga","larry","iris","wallace"])
        check(excluding.all(func(row: Dictionary): return row["leader_id"] not in ["blue","koga","larry","iris","wallace"]),"Exclude people already assigned to other roles")
        candidates[0]["party"][0] = -1
        check(catalog.gym_candidates_for_type(type)[0]["party"][0] > 0,"Candidate preview cannot mutate content")
    var encountered := {}
    for seed_value in 512:
        var route := CampaignRoute.new(seed_value)
        check(route.signature == CampaignRoute.new(seed_value).signature,"Same seed preserves all gym draws")
        var used: Array[String] = [route.champion["id"]]
        for stop: Dictionary in route.stops:
            if stop["kind"] != "gym": continue
            var trainer: Dictionary = stop["trainer"]
            check(trainer["type"] == "mixed" or trainer["type"] == stop["biome"]["type"],"Selected leader fits the current biome")
            check(stop["party"] == trainer["party"] and stop["name"].contains(trainer["region"]),"Actual encounter uses the selected six and region label")
            for id: String in trainer["person_ids"]:
                check(id not in used,"No repeated gym/champion person")
                used.append(id)
            encountered[trainer["leader_id"]] = true
        for trainer: Dictionary in route.elite:
            check(trainer["id"] not in used,"Gym/Elite/champion dual roles never repeat")
            used.append(trainer["id"])
    check(encountered.size() == 82,"Every candidate is reachable through real seeded routes")
    var signatures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gym-candidates/legacy-route-signatures.json"))
    for seed_text: String in signatures:
        check(CampaignRoute.new(int(seed_text),1).signature == signatures[seed_text],"Frozen legacy route exactly matches pre-change signature")
    var store := JourneySave.new("res://tests/fixtures/gym-candidates/legacy-run.json")
    var old := store._read(store.path)
    check(not old.is_empty() and not old.has("route_version"),"Read genuine pre-change v3 envelope")
    var resumed := store.load_journey()
    check(resumed != null,"Previous save remains loadable through the normal save API")
    if resumed != null:
        check(resumed.route.generation == 1 and JourneySnapshot.encode(resumed) == old,"Legacy resume preserves route, cards, RNG and the complete snapshot")
        resumed.restart(42,"field_kit",[1,4,7])
        check(resumed.route.generation == 2,"A new attempt uses expanded candidates")
    var fresh := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    var snapshot := JourneySnapshot.encode(fresh)
    check(snapshot.get("route_version") == 2 and JourneySnapshot.validate(snapshot),"New route version is explicit and validates")
    var restored := JourneySnapshot.restore(snapshot)
    check(restored.route.signature == fresh.route.signature and JourneySnapshot.encode(restored) == snapshot,"New save round trip preserves every candidate and state")
    snapshot["route_version"] = 99
    check(not JourneySnapshot.validate(snapshot),"Unknown future route rules are rejected")
    print("GYM_CANDIDATES ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
