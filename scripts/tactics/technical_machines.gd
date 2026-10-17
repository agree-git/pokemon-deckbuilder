class_name TechnicalMachines
extends RefCounted
## Consumable machines, using real machine-only compatibility and a private camp RNG.
const PATH := "res://data/technical_machines.json"
const PRICE := 100
static var _compatibility: Dictionary = {}
static var _pool: Array[int] = []
static func moves(species: int) -> Array[int]:
    if _compatibility.is_empty():
        _compatibility = JSON.parse_string(FileAccess.get_file_as_string(PATH))["compatibility"]
    var result: Array[int] = []
    for move: int in _compatibility.get(str(species),[]): result.append(move)
    return result
static func pool() -> Array[int]:
    if _pool.is_empty():
        moves(1)
        for row: Array in _compatibility.values():
            for move: int in row:
                if move not in _pool: _pool.append(move)
        _pool.sort()
    return _pool
static func valid(move: Variant) -> bool: return move is int and move in pool()
static func generate(seed_value: int,step: int,party: Array[BattlePokemon],merchant: bool) -> Array[Dictionary]:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ (step*13007+77577911)
    var result: Array[Dictionary] = []
    if not merchant and rng.randi_range(1,100) > 25: return result
    var useful: Array[int] = []
    for p: BattlePokemon in party:
        for move: int in moves(p.species_id):
            if move not in useful and TacticalMoves.key_for(move) not in p.learned_skills: useful.append(move)
    useful.sort()
    for i in (2 if merchant else 1):
        var candidates := useful if i == 0 and not useful.is_empty() else pool().duplicate()
        candidates = candidates.filter(func(move: int): return not result.any(func(row: Dictionary): return row["move"] == move))
        if candidates.is_empty(): break
        result.append({"move":candidates[rng.randi_range(0,candidates.size()-1)],"taken":false})
    return result
static func valid_offers(value: Variant,merchant: bool) -> bool:
    if not value is Array or value.size() > (2 if merchant else 1): return false
    var seen := []
    for row: Variant in value:
        if not row is Dictionary or not valid(row.get("move")) or not row.get("taken") is bool or row["move"] in seen: return false
        seen.append(row["move"])
    return true
