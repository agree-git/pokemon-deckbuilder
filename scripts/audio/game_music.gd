extends AudioLoopLayer
## Region playlist and combat themes share two persistent crossfading voices.
signal theme_changed(key: String)
signal playback_changed
const BUS := "Music"
const THEMES: Array[String] = ["title", "camp", "battle", "boss", "champion"]
const TRACKS := {
    "title": preload("res://assets/audio/region_music/20_oras_littleroot_town.ogg"),
    "camp": preload("res://assets/audio/region_music/28_hgss_pallet_town.ogg"),
    "battle": preload("res://assets/audio/music/battle.wav"),
    "boss": preload("res://assets/audio/music/boss.wav"),
    "champion": preload("res://assets/audio/music/champion.wav"),
}
var streams: Dictionary = TRACKS.duplicate()
var preferences: Node
var region_tracks: Array[Dictionary] = []
var region_choices: Dictionary = {}
var region_history: Dictionary = {}
var region_history_positions: Dictionary = {}
var playback_paused := false
var selected_region := ""
var selected_region_key := ""
var boss_choices: Dictionary = {}
var _boss_rng := RandomNumberGenerator.new()
var _selection_rng := RandomNumberGenerator.new()
var _region_run := ""
var _last_region_track := -1
var _selected_track := -1

func _ready() -> void:
    preferences = get_node("/root/Preferences")
    setup(BUS)
    region_tracks = RegionMusic.tracks()
    _selection_rng.randomize()
    _boss_rng.randomize()
    preferences.changed.connect(apply_mix)
    apply_mix()

func apply_mix() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(maxf(0.0001, preferences.music_volume)))
    var silent: bool = preferences.audio_muted or preferences.master_volume <= 0.0 or preferences.music_volume <= 0.0
    AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), silent)
    set_silent(silent or playback_paused)

func toggle_playback() -> void:
    playback_paused = not playback_paused
    apply_mix()
    playback_changed.emit()

func current_track_title() -> String:
    if current_key == selected_region_key and _selected_track >= 0:
        return str(region_tracks[_selected_track]["title"])
    var boss_id := current_key.get_slice(":",2)
    if not boss_id.is_empty():
        for source: Dictionary in BossMusic.data()["sources"]:
            if source["track_id"] == boss_id: return str(source["filename"]).get_basename()
    return {"title":"시작 화면", "camp":"야영지", "battle":"일반 전투", "boss":"보스 전투", "champion":"챔피언 전투"}.get(current_key,"배경 음악")

func select_region(journey: TacticalJourney) -> String:
    if journey.run_id != _region_run:
        _region_run = journey.run_id
        region_choices.clear()
        region_history.clear()
        region_history_positions.clear()
        boss_choices.clear()
        _last_region_track = -1
    selected_region = RegionMusic.context(journey)
    if region_tracks.is_empty():
        selected_region_key = ""
        return ""
    if not region_choices.has(selected_region):
        var count := region_tracks.size()
        var selected := 0
        if count > 1 and _last_region_track >= 0:
            selected = _selection_rng.randi_range(0,count-2)
            if selected >= _last_region_track: selected += 1
        elif count > 1:
            selected = _selection_rng.randi_range(0,count-1)
        region_choices[selected_region] = selected
        region_history[selected_region] = [selected]
        region_history_positions[selected_region] = 0
    _selected_track = int(region_choices[selected_region])
    _last_region_track = _selected_track
    selected_region_key = "region_%02d" % int(region_tracks[_selected_track]["id"])
    return selected_region_key

func play_region(journey: TacticalJourney) -> void:
    var key := select_region(journey)
    if key.is_empty():
        play_camp(journey.biome())
        return
    _play_selected_region()

func can_next_track() -> bool:
    return region_tracks.size() > 1 and _selected_track >= 0 and not selected_region_key.is_empty() and current_key == selected_region_key

func next_track() -> bool:
    if not can_next_track(): return false
    # Presentation RNG only. Remember the replacement across camp/battle refreshes.
    var history: Array = region_history[selected_region]
    var position := int(region_history_positions[selected_region])+1
    region_history_positions[selected_region] = position
    if position < history.size():
        _set_region_track(int(history[position]))
        return true
    var selected := _selection_rng.randi_range(0,region_tracks.size()-2)
    if selected >= _selected_track: selected += 1
    history.append(selected)
    _set_region_track(selected)
    return true

func can_previous_track() -> bool:
    return can_next_track() and int(region_history_positions.get(selected_region,0)) > 0

func previous_track() -> bool:
    if not can_previous_track(): return false
    var position := int(region_history_positions[selected_region])-1
    region_history_positions[selected_region] = position
    _set_region_track(int(region_history[selected_region][position]))
    return true

func _set_region_track(selected: int) -> void:
    _selected_track = selected
    _last_region_track = selected
    region_choices[selected_region] = selected
    selected_region_key = "region_%02d" % int(region_tracks[selected]["id"])
    _play_selected_region()

func _play_selected_region() -> void:
    var key := selected_region_key
    if key == current_key: return
    var stream: AudioStream = load(str(region_tracks[_selected_track]["path"]))
    play_loop(key,stream)
    theme_changed.emit(key)

func play_boss(trainer: Dictionary,journey: TacticalJourney = null) -> void:
    if journey != null: select_region(journey)
    var variants := BossMusic.variants(trainer)
    if variants.is_empty():
        play_theme(for_battle(str(trainer.get("kind",""))))
        return
    var encounter := (journey.run_id+":"+str(journey.step) if journey != null else "standalone")+":"+TrainerDialogue.key(trainer)
    if not boss_choices.has(encounter):
        boss_choices[encounter] = variants[_boss_rng.randi_range(0,variants.size()-1)] if variants.size() > 1 else variants[0]
    var track := str(boss_choices[encounter])
    var key := TrainerDialogue.key(trainer)+":"+track
    if key == current_key: return
    play_loop(key,load(BossMusic.path(track)))
    theme_changed.emit(key)

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
