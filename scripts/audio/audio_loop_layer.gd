class_name AudioLoopLayer
extends Node
## Two persistent voices. Repeated requests preserve position; fades use real time.
const FADE := 1.2
var players: Array[AudioStreamPlayer] = []
var player_keys: Array[String] = ["", ""]
var current_key := ""
var _active := -1
var _fade: Tween
var _silent := false
var _target_gain := 1.0
var muffled := false
var _muffle_filter: AudioEffectLowPassFilter
var _muffle_tween: Tween
var _bus_index := -1
var _muffle_index := -1

func setup(bus: String) -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if AudioServer.get_bus_index(bus) < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
        AudioServer.set_bus_send(AudioServer.get_bus_index(bus), "Game")
    _bus_index = AudioServer.get_bus_index(bus)
    _muffle_filter = AudioEffectLowPassFilter.new()
    _muffle_filter.cutoff_hz = 20000
    _muffle_filter.db = AudioEffectFilter.FILTER_12DB
    _muffle_index = AudioServer.get_bus_effect_count(_bus_index)
    AudioServer.add_bus_effect(_bus_index,_muffle_filter)
    AudioServer.set_bus_effect_enabled(_bus_index,_muffle_index,false)
    for i in 2:
        var player := AudioStreamPlayer.new()
        player.bus = bus
        player.volume_linear = 0
        add_child(player)
        players.append(player)

func set_muffled(value: bool) -> void:
    if value == muffled: return
    muffled = value
    if _muffle_tween != null and _muffle_tween.is_valid(): _muffle_tween.kill()
    AudioServer.set_bus_effect_enabled(_bus_index,_muffle_index,true)
    _muffle_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _muffle_tween.tween_property(_muffle_filter,"cutoff_hz",1200.0 if value else 20000.0,.25)
    if not value: _muffle_tween.tween_callback(_finish_unmuffle)

func _finish_unmuffle() -> void:
    if not muffled: AudioServer.set_bus_effect_enabled(_bus_index,_muffle_index,false)

func set_silent(value: bool) -> void:
    _silent = value
    for player: AudioStreamPlayer in players: player.stream_paused = value

func play_loop(key: String, stream: AudioStream, gain := 1.0) -> void:
    if key == current_key and is_equal_approx(gain, _target_gain): return
    current_key = key
    _target_gain = gain
    if _fade != null and _fade.is_valid(): _fade.kill()
    var selected := -1
    if stream != null:
        for i in 2:
            if player_keys[i] == key and (players[i].playing or players[i].stream_paused): selected = i
        if selected < 0:
            selected = 0 if _active < 0 else 1 - _active
            _halt_voice(selected)
            players[selected].stream = stream
            players[selected].volume_linear = 0
            players[selected].play()
            players[selected].stream_paused = _silent
            player_keys[selected] = key
    _active = selected
    _fade = create_tween().set_parallel(true).set_ignore_time_scale(true)
    for i in 2:
        _fade.tween_property(players[i], "volume_linear", gain if i == selected else 0.0, FADE)
        if i != selected:
            _fade.tween_callback(_halt_voice.bind(i)).set_delay(FADE)

func _halt_voice(index: int) -> void:
    players[index].stream_paused = false
    players[index].stop()
    players[index].stream = null
    player_keys[index] = ""

func stop_all() -> void:
    if _fade != null and _fade.is_valid(): _fade.kill()
    _fade = null
    for i in players.size():
        _halt_voice(i)
        players[i].volume_linear = 0
    current_key = ""
    _active = -1
    _target_gain = 1.0
