extends Node
## Original short effects only. This service never reads or mutates a battle.
signal cue_played(key: String)
const BUS := "Effects"
const MASTER_BUS := "Game"
const VOICES := 6
const KEYS: Array[String] = ["ui_click", "card_play", "attack", "hit", "block", "shield", "heal", "recall", "release", "status", "knockout", "capture", "turn", "victory", "defeat"]
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var click_voice := AudioStreamPlayer.new()
var _next_voice := 0
var preferences: Node

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    if AudioServer.get_bus_index(MASTER_BUS) < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, MASTER_BUS)
        AudioServer.set_bus_send(AudioServer.get_bus_index(MASTER_BUS), "Master")
    if AudioServer.get_bus_index(BUS) < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
        AudioServer.set_bus_send(AudioServer.get_bus_index(BUS), MASTER_BUS)
    for key: String in KEYS:
        streams[key] = load("res://assets/audio/effects/%s.wav" % key)
    for i in VOICES:
        var voice := AudioStreamPlayer.new()
        voice.bus = BUS
        add_child(voice)
        voices.append(voice)
    click_voice.bus = BUS
    add_child(click_voice)
    preferences.changed.connect(apply_mix)
    get_tree().scene_changed.connect(stop_all)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), linear_to_db(maxf(0.0001, preferences.master_volume)))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.effects_volume)))
    var silent: bool = preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.effects_volume <= 0.0
    AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), preferences.audio_muted or preferences.master_volume <= 0.0)
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), preferences.effects_volume <= 0.0)
    if silent: stop_all()

func play(key: String) -> void:
    if not streams.has(key) or preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.effects_volume <= 0.0: return
    var voice := click_voice
    if key != "ui_click":
        voice = voices[_next_voice]
        for candidate: AudioStreamPlayer in voices:
            if not candidate.playing:
                voice = candidate
                break
        _next_voice = (voices.find(voice) + 1) % VOICES
    voice.stop()
    voice.stream = streams[key]
    voice.pitch_scale = 1.0
    voice.play()
    cue_played.emit(key)

func stop_all() -> void:
    click_voice.stop()
    for voice: AudioStreamPlayer in voices: voice.stop()
