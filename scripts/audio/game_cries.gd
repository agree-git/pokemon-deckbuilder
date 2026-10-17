extends Node
## Species cries are presentation only. One voice per side, with a bounded LRU.
signal cry_played(species_id: int, on_ally: bool)
const BUS := "Cries"
const CACHE_LIMIT := 12
const VOICE_GAIN := 0.35 # Leave room for music, ball effects and the other side.
var preferences: Node
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var _recent: Array[int] = []

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    if AudioServer.get_bus_index(BUS) < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
        AudioServer.set_bus_send(AudioServer.get_bus_index(BUS), "Game")
    for i in 2:
        var voice := AudioStreamPlayer.new()
        voice.bus = BUS
        voice.volume_linear = VOICE_GAIN
        add_child(voice)
        voices.append(voice)
        voice.finished.connect(_clear_voice.bind(voice))
    preferences.changed.connect(apply_mix)
    get_tree().scene_changed.connect(stop_all)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.cries_volume)))
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), preferences.cries_volume <= 0)
    if _silent(): stop_all()

func _silent() -> bool:
    return preferences.audio_muted or preferences.master_volume <= 0 or preferences.cries_volume <= 0

func play(species_id: int, on_ally := true) -> void:
    if not VisualCatalog.supports(species_id) or _silent(): return
    if not streams.has(species_id):
        streams[species_id] = load("res://assets/audio/cries/%d.ogg" % species_id)
    _recent.erase(species_id)
    _recent.append(species_id)
    while _recent.size() > CACHE_LIMIT:
        streams.erase(_recent.pop_front())
    var voice := voices[0 if on_ally else 1]
    voice.stop()
    voice.stream = streams[species_id]
    voice.pitch_scale = 1.0
    voice.play()
    cry_played.emit(species_id, on_ally)

func _clear_voice(voice: AudioStreamPlayer) -> void:
    voice.stream = null

func stop_side(on_ally: bool) -> void:
    var voice := voices[0 if on_ally else 1]
    voice.stop()
    _clear_voice(voice)

func stop_all() -> void:
    for on_ally: bool in [true, false]: stop_side(on_ally)
