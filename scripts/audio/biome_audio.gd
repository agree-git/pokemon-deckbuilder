class_name BiomeAudio
extends RefCounted
## The route biome is the only input. Never infer an undiscovered rare species.
const TYPES: Array[String] = ["normal", "fire", "water", "grass", "electric", "ice", "fighting", "poison", "ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]

static func key(biome: Dictionary) -> String:
    var value := str(biome.get("type", ""))
    return value if value in TYPES else ""

static func music_path(type: String) -> String:
    return "res://assets/audio/biomes/%s_music.ogg" % type

static func ambience_path(type: String) -> String:
    return "res://assets/audio/biomes/%s_ambience.ogg" % type
