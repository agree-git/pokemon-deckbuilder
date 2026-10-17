extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var music := root.get_node("GameMusic")
    var prefs := root.get_node("Preferences")
    prefs.set_audio_muted(false)
    prefs.set_audio_volume("master",.75)
    prefs.set_audio_volume("music",.55)
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RegionMusic.MANIFEST))
    check(manifest["tracks"].size() == 35 and manifest["archives"].size() == 4,"All user-supplied tracks and ZIP provenance recorded")
    var identifiers: Array[int] = []
    for entry: Dictionary in music.region_tracks:
        identifiers.append(int(entry["id"]))
        var stream: AudioStreamOggVorbis = load(entry["path"])
        check(stream != null and stream.loop and absf(stream.get_length()-float(entry["duration_seconds"])) < .1,"Full normalized recording imports as loop: "+entry["title"])
        var playback := stream.instantiate_playback()
        playback.start()
        playback.seek(2.0) # Album recordings may begin with digital silence.
        var frames := playback.mix_audio(1.0,8192)
        check(frames.size() == 8192 and frames.to_byte_array().count(0) < frames.to_byte_array().size(),"Vorbis decoder produces real audio: "+entry["title"])
        playback.seek(stream.get_length()-.01)
        frames = playback.mix_audio(1.0,2048)
        check(playback.is_playing() and frames.size() == 2048,"Full recording loops without stopping: "+entry["title"])
        playback.stop()
    identifiers.sort()
    check(identifiers == range(1,36),"Each requested recording occurs once")
    var j := TacticalJourney.new(712,"field_kit",[1,4,7],true)
    var before := JourneySnapshot.encode(j)
    seed(778)
    var expected_random := randi()
    seed(778)
    var key: String = music.select_region(j)
    check(randi() == expected_random,"Selection does not consume global gameplay randomness")
    var random_state: int = music._selection_rng.state
    check(music.select_region(j) == key and music._selection_rng.state == random_state,"Same region queries preserve choice and random state")
    check(JourneySnapshot.encode(j) == before,"Selection leaves complete campaign/save/RNG snapshot unchanged")
    var restored := JourneySnapshot.restore(before)
    check(restored != null and music.select_region(restored) == key and music._selection_rng.state == random_state,"Reloaded run_id preserves the region choice within the same app session")
    music.play_region(j)
    await create_timer(1.3).timeout
    var outgoing: AudioStreamPlayer = music.players[music._active]
    check(is_equal_approx(outgoing.volume_linear,1),"First track fades fully in")
    var position := outgoing.get_playback_position()
    var fade: Tween = music._fade
    music.play_region(j)
    check(music.players[music._active] == outgoing and music._fade == fade and outgoing.get_playback_position() >= position,"Same-region refresh preserves voice, playback position and fade")
    j.step = 16
    var next_key: String = music.select_region(j)
    check(next_key != key,"Adjacent regions never select the same recording")
    before = JourneySnapshot.encode(j)
    music.play_region(j)
    var incoming: AudioStreamPlayer = music.players[music._active]
    check(incoming != outgoing and is_zero_approx(incoming.volume_linear) and outgoing.volume_linear > .99,"New region starts a second voice at zero gain")
    await create_timer(.3).timeout
    check(incoming.volume_linear > 0 and incoming.volume_linear < 1 and outgoing.volume_linear > 0 and outgoing.volume_linear < 1,"Outgoing fades out while incoming fades in")
    fade = music._fade
    music.play_region(j)
    check(music._fade == fade,"Repeated travel/UI requests do not restart crossfade")
    prefs.set_audio_muted(true)
    check(incoming.stream_paused and outgoing.stream_paused,"Master mute pauses both overlapping voices")
    prefs.set_audio_muted(false)
    Engine.time_scale = 2
    await create_timer(1.05,true,false,true).timeout
    Engine.time_scale = 1
    check(is_equal_approx(incoming.volume_linear,1) and outgoing.stream == null and not outgoing.playing,"Real-time fade finishes at double speed and releases outgoing audio")
    check(JourneySnapshot.encode(j) == before,"Playback and fades leave complete campaign snapshot unchanged")
    var choices: int = music.region_choices.size()
    for step in range(16,32):
        j.step = step
        check(music.select_region(j) == next_key,"Every battle and camp in the chapter shares one recording")
    check(music.region_choices.size() == choices,"Chapter navigation creates no extra selections")
    var previous := next_key
    for step in [32,48,64,80,96,112]:
        j.step = step
        var selected: String = music.select_region(j)
        check(selected != previous,"Successive chapters avoid adjacent repetition")
        previous = selected
    j.step = 128
    var league_key: String = music.select_region(j)
    check(league_key != previous,"Entering the league selects a different regional recording")
    random_state = music._selection_rng.state
    for step in range(128,137):
        j.step = step
        check(music.select_region(j) == league_key and music._selection_rng.state == random_state,"League arenas and camps share one regional choice")
    j.step = 16
    check(music.select_region(j) == next_key,"Returning to a cached region restores its original choice")
    music.play_theme("boss")
    check(music.current_key == "boss","Boss has dedicated music")
    music.play_theme("champion")
    check(music.current_key == "champion","Champion has dedicated music")
    random_state = music._selection_rng.state
    music.play_region(j)
    check(music.current_key == next_key and music._selection_rng.state == random_state,"Boss completion restores region without a new draw")
    var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    check(music.current_key == "title" and music.TRACKS["title"] is AudioStreamOggVorbis,"Title immediately uses supplied music")
    menu.free()
    music.play_region(j)
    check(music.current_key == next_key and music._selection_rng.state == random_state,"Returning from the title preserves regional choice")
    music.stop_music()
    root.get_node("GameAmbience").stop_ambience()
    await process_frame
    await create_timer(.2).timeout
    print("REGION_MUSIC: ",checks," checks / ",failures," failures")
    quit(0 if failures == 0 else 1)
