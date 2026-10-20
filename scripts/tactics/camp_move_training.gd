extends RefCounted
## Complete legal training catalog, with fixed prices independent of camp actions.
const PRICE := 100
const OTHER_PRICE := 200
static func level_moves(pokemon: BattlePokemon) -> Array[int]:
    var result: Array[int] = []
    for row: Dictionary in TacticalGrowth.species_data(pokemon.species_id,pokemon.content_version >= 2)["learnset"]:
        var move := int(row["move"])
        if int(row["level"]) <= pokemon.level and move not in result: result.append(move)
    result.sort()
    return result
static func offers(_seed_value: int,_step: int,pokemon: BattlePokemon) -> Array[int]:
    # Include known moves for reference; mutation guards reject learning them again.
    return NationalEvolution.teachable_moves(pokemon)
static func price(pokemon: BattlePokemon,move: int) -> int:
    return PRICE if move in level_moves(pokemon) else OTHER_PRICE
