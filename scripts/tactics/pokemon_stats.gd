class_name PokemonStats
extends RefCounted
## Species and level only. No individual values, effort values or nature modifiers.
const BASIS := "species-level-v1"
const NAMES := ["hp","attack","defense","special_attack","special_defense","speed"]
const TITLES := {"hp":"체력","attack":"공격","defense":"방어","special_attack":"특공","special_defense":"특방","speed":"스피드"}
const STAT_IDS := {2:"attack",3:"defense",4:"special_attack",5:"special_defense",6:"speed"}
const DAMAGE_SCALE := 0.6
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/base_stats.json"))
    return _data
static func base(species: int) -> Dictionary: return data()["species"][str(species)]
static func value(species: int, level: int, stat: String) -> int:
    if stat == "hp" and species == 292: return 1
    level = clampi(level,1,100)
    var calculated := floori(2*int(base(species)[stat])*level/100.0)
    return calculated+(level+10 if stat == "hp" else 5)
static func apply(pokemon: BattlePokemon, full := false) -> void:
    var previous := pokemon.max_hp
    var alive := pokemon.alive()
    var was_full := pokemon.hp == previous
    pokemon.species_stats = true
    pokemon.max_hp = value(pokemon.species_id,pokemon.level,"hp")
    pokemon.hp = pokemon.max_hp if full or was_full else (clampi(pokemon.hp+pokemon.max_hp-previous,1,pokemon.max_hp) if alive else 0)
    pokemon.knocked_out = not pokemon.alive()
static func effective(pokemon: BattlePokemon, stat: String) -> int:
    var stage := clampi(int(pokemon.stat_stages.get(stat,0)),-6,6)
    var ratio := (2.0+stage)/2.0 if stage >= 0 else 2.0/(2.0-stage)
    var result := floori(value(pokemon.species_id,pokemon.level,stat)*ratio)
    if stat == "speed" and pokemon.statuses.has("paralysis"): result = floori(result*0.5)
    return maxi(1,result)
static func scale(pokemon: BattlePokemon, points: int) -> int:
    # Support cards keep a stable fraction of the original 48HP combat budget.
    if points <= 0: return 0
    return maxi(1,roundi(points*pokemon.max_hp/48.0))
static func percent(points: int) -> String:
    return String.num(points*100.0/48.0,1).trim_suffix(".0")+"%"
static func damage(actor: BattlePokemon, target: BattlePokemon, move: Dictionary, affinity: float, flat_bonus := 0, pressure := 1.0, weather := "") -> int:
    if affinity <= 0: return 0
    var special: bool = move.get("damage_class","physical") == "special"
    var offense := effective(actor,"special_attack" if special else "attack")
    var defense := maxi(1,floori(effective(target,"special_defense" if special else "defense")*BattleWeather.defense_factor(weather,target,special)))
    var power := maxi(1,int(move.get("move_power",40)))
    var level_factor := floori(2*actor.level/5.0)+2
    var raw := floori(floori(level_factor*power*offense/float(defense))/50.0)+2
    var struggle: bool = int(move.get("move_id",0)) == 165
    var stab := 1.5 if not struggle and move.get("type","normal") in actor.types else 1.0
    var tactical := maxf(0.4,1.0+actor.strength*0.1)
    var burn := 0.5 if not special and actor.statuses.has("burn") else 1.0
    return maxi(1,floori((raw*DAMAGE_SCALE*tactical*burn+scale(actor,flat_bonus))*stab*affinity*pressure*BattleWeather.attack_factor(weather,str(move.get("type","normal")))))
static func summary(pokemon: BattlePokemon) -> String:
    return "HP %d · 공격 %d · 방어 %d\n특공 %d · 특방 %d · 스피드 %d" % [pokemon.max_hp,effective(pokemon,"attack"),effective(pokemon,"defense"),effective(pokemon,"special_attack"),effective(pokemon,"special_defense"),effective(pokemon,"speed")]
