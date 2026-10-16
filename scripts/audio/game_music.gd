extends Node
## Two persistent voices crossfade between scene themes, independently of combat speed.
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
const FADE := 0.55
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var player_keys: Array[String] = ["", ""]
var current_key := ""
var _active := -1
var _fade: Tween
var _pending := false
var preferences: Node

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    if AudioServer.get_bus_index(BUS) < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
        AudioServer.set_bus_send(AudioServer.get_bus_index(BUS), "Game")
    for key: String in THEMES:
        var stream: AudioStreamWAV = TRACKS[key]
        streams[key] = stream
    for i in 2:
        var player := AudioStreamPlayer.new()
        player.bus = BUS
        player.volume_linear = 0
        add_child(player)
        players.append(player)
    preferences.changed.connect(apply_mix)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.music_volume)))
    var silent: bool = preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.music_volume <= 0.0
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), silent)
    for player: AudioStreamPlayer in players: player.stream_paused = silent

func play_theme(key: String) -> void:
    if not streams.has(key) or key == current_key: return
    current_key = key
    theme_changed.emit(key)
    if not _pending:
        _pending = true
        call_deferred("_apply_theme")

func _apply_theme() -> void:
    if not _pending: return
    _pending = false
    var key := current_key
    if _fade != null and _fade.is_valid(): _fade.kill()
    var selected := -1
    for i in 2:
        if player_keys[i] == key and players[i].playing: selected = i
    if selected < 0:
        selected = 0 if _active < 0 else 1 - _active
        _halt_voice(selected)
        players[selected].stream = streams[key]
        players[selected].volume_linear = 0
        players[selected].play()
        player_keys[selected] = key
    _active = selected
    apply_mix()
    _fade = create_tween().set_parallel(true).set_ignore_time_scale(true)
    for i in 2:
        _fade.tween_property(players[i], "volume_linear", 1.0 if i == selected else 0.0, FADE)
    var old := 1 - selected
    _fade.chain().tween_callback(_stop_voice.bind(old))

func _halt_voice(index: int) -> void:
    players[index].stream_paused = false
    players[index].stop()
    players[index].stream = null

func _stop_voice(index: int) -> void:
    _halt_voice(index)
    player_keys[index] = ""

func stop_music() -> void:
    _pending = false
    if _fade != null and _fade.is_valid(): _fade.kill()
    _fade = null
    for i in 2:
        _halt_voice(i)
        players[i].volume_linear = 0
    player_keys.assign(["", ""])
    current_key = ""
    _active = -1

static func for_battle(kind: String) -> String:
    if kind == "champion": return "champion"
    return "boss" if kind in ["gym", "elite"] else "battle"
