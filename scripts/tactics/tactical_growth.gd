class_name TacticalGrowth
extends RefCounted
## Run-only progression; capture collection never stores levels or evolved forms.
const START_LEVEL := 5
const MAX_LEVEL := 100
const EVOLUTION_HP := 12
static var _rules: Array = []

static func experience_floor(level: int) -> int:
    var steps := clampi(level,START_LEVEL,MAX_LEVEL)-START_LEVEL
    return 2*steps*(steps+9)
static func level_for(experience: float) -> int:
    var level := START_LEVEL
    while level < MAX_LEVEL and experience >= experience_floor(level+1): level += 1
    return level
static func progress(pokemon: BattlePokemon) -> float:
    if pokemon.level >= MAX_LEVEL: return 1.0
    var floor_xp := experience_floor(pokemon.level)
    return clampf((pokemon.experience-floor_xp)/(experience_floor(pokemon.level+1)-floor_xp),0,1)
static func progress_text(pokemon: BattlePokemon) -> String:
    if pokemon.level >= MAX_LEVEL: return "MAX"
    var current := pokemon.experience-experience_floor(pokemon.level)
    return "%s / %d XP" % [String.num(current,1).trim_suffix(".0"),experience_floor(pokemon.level+1)-experience_floor(pokemon.level)]
static func attack_bonus(pokemon: BattlePokemon) -> int:
    return maxi(0,floori((pokemon.level-START_LEVEL)/5.0))+pokemon.evolution_power
static func initialize(pokemon: BattlePokemon) -> void:
    if pokemon.learned_skills.is_empty(): pokemon.learned_skills.assign(TacticalContent.skills_for(pokemon))
static func award(pokemon: BattlePokemon,base: int) -> Dictionary:
    initialize(pokemon)
    var before := pokemon.level
    var experience := pokemon.experience
    pokemon.gain_experience(base)
    pokemon.level = maxi(before,level_for(pokemon.experience))
    var increase := pokemon.level-before
    pokemon.max_hp += increase
    if pokemon.alive(): pokemon.hp += increase
    var learned := ""
    if pokemon.level >= 10 and pokemon.learned_skills.size() < 4:
        var extra: String = {"fire":"fire_spin","water":"bubble_beam","grass":"razor_leaf"}.get(pokemon.type,"fire_guard")
        for key: String in [extra,"tackle","guard","growth"]:
            if key not in pokemon.learned_skills:
                pokemon.learned_skills.append(key)
                learned = str(BattleContent.CARDS[key]["name"])
                break
    return {"uid":pokemon.uid,"id":pokemon.species_id,"name":pokemon.display_name,
        "before":before,"after":pokemon.level,"xp":pokemon.experience-experience,"hp":increase,"learned":learned}
static func rules_for(species_id: int) -> Array:
    if _rules.is_empty(): _rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolutions.json"))
    return _rules.filter(func(rule: Dictionary): return int(rule["from"]) == species_id)
static func evolution_reason(pokemon: BattlePokemon,target: int) -> String:
    if not pokemon.alive(): return "기절한 포켓몬은 먼저 회복하세요."
    for rule: Dictionary in rules_for(pokemon.species_id):
        if int(rule["to"]) == target:
            return "Lv.%d부터 진화할 수 있습니다." % int(rule["level"]) if pokemon.level < int(rule["level"]) else ""
    return "현재 지원하는 레벨 진화가 아닙니다."
static func evolve(pokemon: BattlePokemon,target: int,catalog: VisualCatalog) -> String:
    var reason := evolution_reason(pokemon,target)
    if not reason.is_empty(): return reason
    var species := catalog.species(target)
    if species.is_empty(): return "진화할 포켓몬 정보가 없습니다."
    initialize(pokemon)
    pokemon.species_id = target
    pokemon.display_name = species["name"]
    pokemon.type = species["types"][0]
    pokemon.max_hp += EVOLUTION_HP
    pokemon.hp += EVOLUTION_HP
    pokemon.evolution_power += 1
    return ""
