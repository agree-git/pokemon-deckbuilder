extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    var old := {
        1:{1:"9505db3a14e79f3cea27a0c3bb8b1ae9c1124055352adee5351426e0b85ad938",712:"a6392d79ec02723b2a4cb399b05120310f105bd16fd0830d06cc45bb47c7596d",2026:"10cfa5655e95e660b38c46239488a72dde5d47a0acb4691cea77164c4b3b8978"},
        2:{1:"d323f7b531c9a51a5ffedcb2beb6f16cb17a2adfdc799a0d1db1b8527b6dcb34",712:"2d19872aa49a25f35c0d2fc2eaf7c88d6055d4ad21a1c965e3f422aabf5c5963",2026:"8a1c8975eb2b4b7090f6dccbb7f7f403e6a516a010fd65f535851b16a85f7101"}}
    for version: int in old:
        for seed_value: int in old[version]:
            var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true,version)
            check(j.route.signature == old[version][seed_value],"Historical v%d route/RNG unchanged for%d" % [version,seed_value])
            var snapshot := JourneySnapshot.encode(j)
            check(JourneySnapshot.validate(snapshot),"Historical save accepted")
            var restored := JourneySnapshot.restore(snapshot)
            check(restored != null and restored.route.signature == j.route.signature and JourneySnapshot.encode(restored) == snapshot,"Historical route restores byte-equivalent snapshot")
    check(GymLeaders.all(false).size() == 82 and GymLeaders.all().size() == 86,"Frozen base gyms and expanded v3 pool")
    var seen := {}
    var shared_roles := false
    for seed_value in 600:
        var route := CampaignRoute.new(seed_value)
        var gyms := 0
        var elites := 0
        var champions := 0
        var encounters := {}
        var people := {}
        for stop: Dictionary in route.stops:
            if stop["kind"] not in ["gym","elite","champion"]: continue
            var trainer := TrainerDialogue.opponent(stop,stop["biome"])
            var key := TrainerDialogue.key(trainer)
            check(not encounters.has(key),"No duplicate role matchup in one route")
            encounters[key] = true
            seen[key] = true
            if people.has(trainer["id"]) and people[trainer["id"]] != trainer["kind"]: shared_roles = true
            people[trainer["id"]] = trainer["kind"]
            match stop["kind"]:
                "gym": gyms += 1
                "elite": elites += 1
                "champion": champions += 1
        check(route.generation == 16 and route.stops.size() == 137 and gyms == 8 and elites == 4 and champions == 1,"New69-battle route keeps8/4/1 progression")
    check(shared_roles,"Same person may appear in different roles in new runs")
    for key: String in BossExpansion.data()["tactics"]:
        check(seen.has(key),"New boss actually reachable in route pool: "+key)
    var current := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var checkpoint := JourneySnapshot.encode(current)
    check(JourneySnapshot.validate(checkpoint) and JourneySnapshot.encode(JourneySnapshot.restore(checkpoint)) == checkpoint,"New v3 run restores exact save and RNG state")
    print("Boss routes: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
