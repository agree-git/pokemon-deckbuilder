extends AudioLoopLayer
## Quiet outdoor soundscapes; independent of effects, music and combat speed.
const BUS := "Ambience"
var preferences: Node
var streams: Dictionary = {}

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    setup(BUS)
    preferences.changed.connect(apply_mix)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.ambience_volume)))
    var silent: bool = preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.ambience_volume <= 0.0
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), silent)
    set_silent(silent)

func play_biome(biome: Dictionary, in_battle := false) -> void:
    var key := BiomeAudio.key(biome)
    if key.is_empty():
        clear()
        return
    if not streams.has(key): streams[key] = load(BiomeAudio.ambience_path(key))
    # Gain changes preserve this biome's playback position, even mid-crossfade.
    play_loop(key, streams[key], 0.28 if in_battle else 0.65)

func clear() -> void:
    play_loop("", null)

func stop_ambience() -> void:
    stop_all()
