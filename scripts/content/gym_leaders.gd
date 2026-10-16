class_name GymLeaders
extends RefCounted
## Mainline Gym Leaders, including version variants and named former leaders.
## One shared six-member party for Tate/Liza; Blue has no type specialty.
static var _leaders: Array = []

static func all() -> Array:
    if _leaders.is_empty():
        _leaders = JSON.parse_string(FileAccess.get_file_as_string("res://data/gym_leaders.json"))["leaders"]
    return _leaders

static func candidates(type: String,excluded: Array = []) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for leader: Dictionary in all():
        if leader["type"] != type and leader["type"] != "mixed": continue
        if leader["person_ids"].any(func(id: String): return id in excluded): continue
        result.append(leader.duplicate(true))
    return result

static func choose(type: String,rng: RandomNumberGenerator,excluded: Array = []) -> Dictionary:
    var pool := candidates(type,excluded)
    var total := 0.0
    for leader: Dictionary in pool: total += 1.0/18 if leader["type"] == "mixed" else 1.0
    var roll := rng.randf()*total
    for leader: Dictionary in pool:
        roll -= 1.0/18 if leader["type"] == "mixed" else 1.0
        if roll <= 0: return leader
    return pool.back()
