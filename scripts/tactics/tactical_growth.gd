class_name TacticalGrowth
extends RefCounted
## Original species growth curves and level-up learnsets; run-only state.
const START_LEVEL := 5
const MAX_LEVEL := 100
static var _rules: Array = []
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
    return _data
static func species_data(id: int) -> Dictionary:
    return data()["species"][str(id)]
static func experience_floor(level: int,species_id: int = 1) -> int:
    return int(data()["curves"][str(int(species_data(species_id)["growth_rate"]))][clampi(level,1,MAX_LEVEL)])
static func level_for(experience: float,species_id: int = 1) -> int:
    var level := 1
    while level < MAX_LEVEL and experience >= experience_floor(level+1,species_id): level += 1
    return level
static func progress(pokemon: BattlePokemon) -> float:
    if pokemon.level >= MAX_LEVEL: return 1.0
    var floor_xp := experience_floor(pokemon.level,pokemon.species_id)
    return clampf((pokemon.experience-floor_xp)/(experience_floor(pokemon.level+1,pokemon.species_id)-floor_xp),0,1)
static func progress_text(pokemon: BattlePokemon) -> String:
    if pokemon.level >= MAX_LEVEL: return "MAX"
    var floor_xp := experience_floor(pokemon.level,pokemon.species_id)
    return "%s / %d XP" % [String.num(pokemon.experience-floor_xp,1).trim_suffix(".0"),experience_floor(pokemon.level+1,pokemon.species_id)-floor_xp]
static func initialize(pokemon: BattlePokemon) -> void:
    if pokemon.progression_initialized: return
    PokemonStats.apply(pokemon)
    pokemon.progression_initialized = true
    pokemon.experience = experience_floor(pokemon.level,pokemon.species_id)
    pokemon.learned_skills.clear()
    for entry: Dictionary in species_data(pokemon.species_id)["learnset"]:
        var key := TacticalMoves.key_for(int(entry["move"]))
        if int(entry["level"]) <= pokemon.level and key not in pokemon.learned_skills:
            pokemon.learned_skills.append(key)
            if pokemon.learned_skills.size() > 4: pokemon.learned_skills.pop_front()
static func _learn_at(pokemon: BattlePokemon,level: int,report: Dictionary) -> void:
    for entry: Dictionary in species_data(pokemon.species_id)["learnset"]:
        var key := TacticalMoves.key_for(int(entry["move"]))
        if int(entry["level"]) != level or key in pokemon.learned_skills or report["offers"].any(func(offer: Dictionary): return offer["key"] == key): continue
        if pokemon.learned_skills.size() < 4:
            pokemon.learned_skills.append(key)
            report["learned"].append(TacticalMoves.definition(key)["name"])
        else:
            report["offers"].append({"uid":pokemon.uid,"key":key,"level":level,"species":pokemon.species_id})
static func award(pokemon: BattlePokemon,base: float) -> Dictionary:
    initialize(pokemon)
    var before := pokemon.level
    var previous_max_hp := pokemon.max_hp
    var experience := pokemon.experience
    pokemon.gain_experience(base)
    var target := maxi(before,level_for(pokemon.experience,pokemon.species_id))
    var report := {"uid":pokemon.uid,"id":pokemon.species_id,"name":pokemon.display_name,"before":before,"after":target,
        "xp":pokemon.experience-experience,"hp":target-before,"learned":[],"offers":[],"evolutions":[]}
    var catalog: VisualCatalog = null
    while pokemon.level < target:
        pokemon.level += 1
        PokemonStats.apply(pokemon)
        _learn_at(pokemon,pokemon.level,report)
        for rule: Dictionary in rules_for(pokemon.species_id):
            if pokemon.level >= int(rule["level"]):
                if catalog == null: catalog = VisualCatalog.new()
                var previous := pokemon.species_id
                evolve(pokemon,int(rule["to"]),catalog)
                report["evolutions"].append({"from":previous,"to":pokemon.species_id,"name":pokemon.display_name,"level":pokemon.level})
                _learn_at(pokemon,pokemon.level,report)
                break
    report["hp"] = pokemon.max_hp-previous_max_hp
    return report
static func rules_for(species_id: int) -> Array:
    if _rules.is_empty(): _rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolutions.json"))
    return _rules.filter(func(rule: Dictionary): return int(rule["from"]) == species_id)
static func evolve(pokemon: BattlePokemon,target: int,catalog: VisualCatalog) -> void:
    var species := catalog.species(target)
    pokemon.species_id = target
    pokemon.display_name = species["name"]
    pokemon.type = species["types"][0]
    pokemon.types.assign(species["types"])
    PokemonStats.apply(pokemon)
