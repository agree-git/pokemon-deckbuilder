extends AudioLoopLayer
## Scene themes and biome exploration music share one persistent crossfade layer.
signal theme_changed(key: String)
const BUS := "Music"
const THEMES: Array[String] = ["title", "camp", "battle", "boss", "champion"]
const TRACKS := {
    "title": preload("res://assets/audio/music/title.wav"),
    "camp": preload("res://assets/audio/music/camp.wav"),
    "battle": preload("res://assets/audio/music/battle.wav"),
    "boss": preload("res://assets/audio/music/boss.wav"),
    "champion": preload("res://assets/audio/music/champion.wav"),
}
var streams: Dictionary = TRACKS.duplicate()
var preferences: Node

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    setup(BUS)
    preferences.changed.connect(apply_mix)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.music_volume)))
    var silent: bool = preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.music_volume <= 0.0
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), silent)
    set_silent(silent)

func play_camp(biome: Dictionary) -> void:
    var type := BiomeAudio.key(biome)
    if type.is_empty():
        play_theme("camp")
        return
    var key := "camp_" + type
    if not streams.has(key): streams[key] = load(BiomeAudio.music_path(type))
    play_theme(key)

func play_theme(key: String) -> void:
    if not streams.has(key) or key == current_key: return
    play_loop(key, streams[key])
    theme_changed.emit(key)

func stop_music() -> void:
    stop_all()

static func for_battle(kind: String) -> String:
    if kind == "champion": return "champion"
    return "boss" if kind in ["gym", "elite"] else "battle"
