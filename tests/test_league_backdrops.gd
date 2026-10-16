extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func inspect_room(descriptor: Dictionary) -> void:
    check(ResourceLoader.exists(descriptor["background"]),"Room asset exists")
    var texture := VisualCatalog.biome_texture(descriptor)
    check(texture.atlas != null and texture.region.size.x > 0 and texture.region.size.y > 0 and int(descriptor["cell"]) in range(6),"Room selects a valid atlas cell")
func run() -> void:
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var catalog := VisualCatalog.new()
    var rooms := {}
    for trainer: Dictionary in league["elite"]:
        var stop := {"kind":"elite","trainer":trainer}
        var room := BattleBackdrops.for_stop(stop,catalog.biomes[0])
        check(room == BattleBackdrops.data()["elite"][trainer["type"]],"Elite room follows trainer specialty even when biome differs")
        inspect_room(room)
        rooms[trainer["type"]] = room
    check(rooms.size() == 14,"All fourteen currently used Elite Four types are covered")
    var distinct := {}
    for trainer: Dictionary in league["champions"]:
        var room := BattleBackdrops.for_stop({"kind":"champion","trainer":trainer},catalog.biomes[0])
        check(room["region"] == trainer["region"] and room["name"] == trainer["name"],"Champion room preserves the actual trainer and home region")
        inspect_room(room)
        distinct[str([room["background"],room["cell"]])] = true
    check(distinct.size() == 11,"Eleven champions have distinct room variants across eight regions")
    for kind in ["wild","trainer","veteran","gym","rest"]:
        var biome: Dictionary = catalog.biomes[3].duplicate(true)
        var result := BattleBackdrops.for_stop({"kind":kind},biome)
        check(result == biome,"Regional stages and camp keep their biome artwork")
        result["cell"] = 99
        check(int(biome["cell"]) != 99,"Returned descriptors cannot mutate biome content")
    inspect_room(BattleBackdrops.for_stop({"kind":"champion","trainer":{"id":"unknown"}},catalog.biomes[0]))
    for seed_value in [0,3,42,2026]:
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        var before := JourneySnapshot.encode(j)
        for stop: Dictionary in j.route.stops:
            var descriptor := BattleBackdrops.for_stop(stop,stop["biome"])
            if stop["kind"] in ["elite","champion"]: check(str(descriptor["background"]).begins_with("res://assets/league/"),"Actual league encounters use an indoor stage")
        check(JourneySnapshot.encode(j) == before,"Room selection cannot change route, cards, battle state or RNG")
    print("LEAGUE_BACKDROPS ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
