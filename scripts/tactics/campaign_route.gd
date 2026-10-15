class_name CampaignRoute
extends RefCounted
## Route RNG is independent from battle draws and card rewards.
var stops: Array[Dictionary] = []
var biomes: Array[Dictionary] = []
var elite: Array[Dictionary] = []
var champion: Dictionary = {}
var _catalog := VisualCatalog.new()
var _rng := RandomNumberGenerator.new()
var _battle_index := 0
var _run_seed: int
func _init(run_seed: int) -> void:
    _run_seed = run_seed
    _rng.seed = run_seed ^ 7046029254386353131
    var candidates := _catalog.biomes.duplicate()
    _shuffle(candidates)
    biomes.assign(candidates.slice(0,8))
    # Lv.5 starters have Normal attacks. Defer resistant/immune opening regions.
    for i in biomes.size():
        if biomes[i]["type"] not in ["ghost","rock","steel"]:
            var first := biomes[0]
            biomes[0] = biomes[i]
            biomes[i] = first
            break
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    champion = league["champions"][_rng.randi_range(0,league["champions"].size()-1)].duplicate(true)
    var excluded: Array[String] = [champion["id"]]
    for chapter in 8:
        var biome := biomes[chapter]
        var gym: Dictionary
        for entry: Dictionary in _catalog.gyms:
            if entry["type"] == biome["type"]: gym = entry
        excluded.append(gym["leader_id"])
        for encounter in CampaignBalance.BATTLES_PER_REGION:
            var kind := str(CampaignBalance.REGIONAL_KINDS[encounter])
            if kind == "wild":
                _append("야생 조우 %d" % (encounter+1),kind,chapter,biome,[_wild(biome,chapter == 0 and encounter < 2)])
            elif kind == "gym":
                _append(str(gym["name"])+" · "+str(gym["leader"]),kind,chapter,biome,gym["party"],gym)
            else:
                var pool: Array = biome["encounters"].duplicate()
                _shuffle(pool)
                var trainer: Array[int] = []
                for i in (3 if kind == "veteran" else 2): trainer.append(int(pool[i]["pokemon_id"]))
                _append("엘리트 트레이너" if kind == "veteran" else "지역 트레이너",kind,chapter,biome,trainer)
            _append("리그 출발 야영지" if chapter == 7 and encounter == 7 else "야영지 %d" % (encounter+1),"rest",chapter,biome)
    var pool: Array = league["elite"].filter(func(entry: Dictionary): return entry["id"] not in excluded)
    _shuffle(pool)
    elite.assign(pool.slice(0,4))
    for i in 4:
        var trainer := elite[i]
        var biome := _biome(trainer["type"])
        _append("사천왕 %d · %s" % [i+1,trainer["name"]],"elite",8,biome,trainer["party"],trainer,i)
        _append("리그 야영지","rest",8,biome,[],{},i+1)
    _append("챔피언 · "+str(champion["name"]),"champion",8,_biome(champion["type"]),champion["party"],champion,4)
func _shuffle(values: Array) -> void:
    for i in range(values.size()-1,0,-1):
        var j := _rng.randi_range(0,i)
        var value: Variant = values[i]
        values[i] = values[j]
        values[j] = value
func _biome(type: String) -> Dictionary:
    for biome: Dictionary in _catalog.biomes:
        if biome["type"] == type: return biome
    return _catalog.biomes[0]
func _wild(biome: Dictionary, opening: bool) -> int:
    var pool: Array = biome["encounters"].filter(func(entry: Dictionary):
        var species := _catalog.species(int(entry["pokemon_id"]))
        return not species["is_legendary"] and not species["is_mythical"] and (not opening or ("ghost" not in species["types"] and entry["tier"] == "common")))
    var total := 0
    for entry: Dictionary in pool: total += int(entry["weight"])
    var roll := _rng.randi_range(1,total)
    for entry: Dictionary in pool:
        roll -= int(entry["weight"])
        if roll <= 0: return int(entry["pokemon_id"])
    return int(pool[0]["pokemon_id"])
func _append(title: String, kind: String, chapter: int, biome: Dictionary, ids: Array = [], trainer: Dictionary = {}, league_index := -1) -> void:
    var node := {"name":title,"kind":kind,"icon":"heal" if kind == "rest" else biome["type"],"chapter":chapter,"biome":biome,"party":ids.duplicate(),"trainer":trainer.duplicate(true),"league_index":league_index,"battle_index":_battle_index,"level":CampaignBalance.enemy_level(_battle_index)}
    if kind == "rest": node["camp"] = CampContent.generate(_run_seed,stops.size())
    stops.append(node)
    if kind != "rest": _battle_index += 1
func opponents(step: int) -> Array:
    var node := stops[step]
    var result: Array = []
    var boss: bool = node["kind"] in ["gym","elite","champion"]
    var veteran: bool = node["kind"] == "veteran"
    for i in node["party"].size():
        var id := int(node["party"][i])
        var species := _catalog.species(id)
        var level := int(node["level"])
        var hp: int = (32+i*4 if boss else 30+i*6)+floori((level-6)*0.65)
        var power: int = (10+floori(i/2.0) if boss else 6+i)+floori((level-6)/8.0)
        if veteran:
            hp += 8
            power += 2
        var attack := "normal"
        var move := 33
        for learned: Dictionary in TacticalGrowth.species_data(id)["learnset"]:
            var definition := TacticalMoves.definition(TacticalMoves.key_for(int(learned["move"])))
            if int(learned["level"]) <= level and definition.has("damage") and definition["type"] in species["types"]:
                attack = definition["type"]
                move = int(learned["move"])
        result.append({"id":id,"name":species["name"],"type":species["types"][0],"types":species["types"],"max_hp":hp,"level":level,"intents":[
            {"kind":"charge","value":power,"type":attack,"move_id":move},
            {"kind":"block","value":6+floori(level/10.0),"move_id":115},
            {"kind":"attack","value":maxi(1,power-2),"type":attack,"move_id":move}]})
    return result
func experience_reward(step: int,species_id := 1) -> float:
    return 0.0 if stops[step]["kind"] == "rest" else CampaignBalance.experience_reward(int(stops[step]["battle_index"]),species_id)
