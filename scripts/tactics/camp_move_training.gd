extends RefCounted
## Limited level-move reminders. Private RNG never consumes campaign/battle RNG.
const PRICE := 100
const OFFER_COUNT := 3
static func level_moves(pokemon: BattlePokemon) -> Array[int]:
    var result: Array[int] = []
    for row: Dictionary in TacticalGrowth.species_data(pokemon.species_id,pokemon.content_version >= 2)["learnset"]:
        var move := int(row["move"])
        if int(row["level"]) <= pokemon.level and move not in result: result.append(move)
    result.sort()
    return result
static func offers(seed_value: int,step: int,pokemon: BattlePokemon) -> Array[int]:
    var pool := level_moves(pokemon)
    # Rank the full legal pool before hiding known moves; relearning cannot reroll it.
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ (step*32452843+pokemon.uid*104729+7919)
    var result: Array[int] = []
    while not pool.is_empty() and result.size() < OFFER_COUNT:
        var index := rng.randi_range(0,pool.size()-1)
        var move: int = pool[index]
        pool.remove_at(index)
        if TacticalMoves.key_for(move) not in pokemon.learned_skills: result.append(move)
    return result
