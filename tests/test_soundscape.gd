extends SceneTree
const RareFixture = preload("support/rare_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var music := root.get_node("GameMusic")
    var ambient := root.get_node("GameAmbience")
    var prefs := root.get_node("Preferences")
    prefs.path = "user://soundscape_settings.cfg"
    prefs.set_audio_muted(false)
    var keys: Array[String] = []
    for biome: Dictionary in VisualCatalog.new().biomes:
        var key := BiomeAudio.key(biome)
        check(not key.is_empty() and key not in keys,"Every route biome has a unique soundscape")
        keys.append(key)
        for path: String in [BiomeAudio.music_path(key), BiomeAudio.ambience_path(key)]:
            var stream: AudioStreamOggVorbis = load(path)
            check(stream != null and stream.loop and stream.get_length() >= 31.9,"Loop imports and duration: "+path)
            var playback := stream.instantiate_playback()
            playback.start()
            var frames := playback.mix_audio(1.0,4096)
            check(frames.size() == 4096 and frames.to_byte_array().count(0) < frames.to_byte_array().size(),"Vorbis decoder returns frames: "+path)
            playback.seek(stream.get_length()-.01)
            var seam_frames := playback.mix_audio(1.0,2048)
            check(playback.is_playing() and seam_frames.size() == 2048 and seam_frames.to_byte_array().count(0) < seam_frames.to_byte_array().size(),"Decoder crosses loop seam: "+path)
        music.play_camp(biome)
        ambient.play_biome(biome)
        check(music.current_key == "camp_"+key and ambient.current_key == key,"Biome selects both layers")
    check(keys.size() == 18,"All eighteen biomes covered")
    music.play_camp({})
    ambient.play_biome({})
    check(music.current_key == "camp" and ambient.current_key.is_empty(),"Unknown biome uses safe fallback")
    ambient.stop_ambience()
    ambient.play_biome({"type":"water"})
    await create_timer(.16).timeout
    var voice: AudioStreamPlayer = ambient.players[ambient._active]
    var position := voice.get_playback_position()
    var fade: Tween = ambient._fade
    ambient.play_biome({"type":"water"})
    check(ambient._fade == fade and ambient.players[ambient._active] == voice,"Refresh preserves playback and fade")
    ambient.play_biome({"type":"water"},true)
    check(ambient.players[ambient._active] == voice and voice.get_playback_position() >= position,"Battle ducks same voice without restarting")
    ambient.play_biome({"type":"water"})
    check(is_equal_approx(ambient._target_gain,.65),"Returning to camp can interrupt duck fade")
    Engine.time_scale = 2.0
    await create_timer(1.4,true,false,true).timeout
    Engine.time_scale = 1.0
    check(is_equal_approx(voice.volume_linear,.65),"Fade finishes in wall time at doubled combat speed")
    ambient.play_biome({"type":"grass"})
    ambient.play_biome({"type":"water"},true)
    await create_timer(1.35).timeout
    check(ambient.players[ambient._active] == voice and is_equal_approx(voice.volume_linear,.28),"Rapid interrupted crossfade resumes surviving voice")
    var playing := 0
    for p: AudioStreamPlayer in ambient.players:
        if p.playing: playing += 1
    check(playing == 1,"Old voice stops after crossfade")
    prefs.set_audio_volume("ambience",0)
    check(voice.stream_paused and AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"Zero ambience pauses and mutes")
    prefs.set_audio_volume("ambience",.4)
    check(not voice.stream_paused,"Volume restores ambience")
    prefs.set_audio_volume("music",0)
    check(not voice.stream_paused,"Music volume does not silence ambience")
    prefs.set_audio_volume("effects",0)
    check(not voice.stream_paused,"Effect volume does not silence ambience")
    prefs.set_audio_muted(true)
    check(voice.stream_paused,"Master mute pauses ambience")
    prefs.set_audio_muted(false)
    prefs.set_audio_volume("master",0)
    check(voice.stream_paused,"Zero master volume pauses ambience")
    prefs.set_audio_volume("master",.75)
    var loaded: Node = load("res://scripts/preferences.gd").new()
    loaded.path = prefs.path
    loaded.load_preferences()
    check(is_equal_approx(loaded.ambience_volume,.4),"Environment volume persists separately")
    var old := ConfigFile.new()
    old.set_value("audio","music",.23)
    old.set_value("audio","cries",.62)
    old.save(loaded.path)
    loaded.load_preferences()
    check(is_equal_approx(loaded.ambience_volume,.55) and is_equal_approx(loaded.music_volume,.23) and is_equal_approx(loaded.cries_volume,.62),"Old settings retain old channels and default ambience")
    old.set_value("audio","ambience",NAN)
    old.save(loaded.path)
    loaded.load_preferences()
    check(is_equal_approx(loaded.ambience_volume,.55),"Invalid ambience value falls back")
    loaded.free()
    prefs.set_audio_volume("music",.55)
    prefs.set_audio_volume("effects",.8)
    # Real journey UI requests, including modal refresh and terminal screens.
    var j := TacticalJourney.new(721,"field_kit",[1,4,7],true)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    var before := JourneySnapshot.encode(j)
    root.add_child(ui)
    var region_key: String = music.selected_region_key
    check(music.current_key == region_key and ambient.current_key == j.biome()["type"],"Wild battle uses regional music and route ambience")
    check(JourneySnapshot.encode(j) == before,"Soundscape leaves battle/save/RNG unchanged")
    var view := ui.battle_ui
    for kind: String in ["gym","elite","champion"]:
        view.opponent_trainer = {"kind":kind}
        view._play_soundscape()
        check(ambient.current_key.is_empty() and music.current_key == ("champion" if kind == "champion" else "boss"),"Indoor boss themes suppress outdoor ambience")
    view.opponent_trainer = {}
    j.battle.phase = TacticalBattle.WON
    view._play_soundscape()
    check(music.current_key == region_key and is_equal_approx(ambient._target_gain,.65),"Victory restores selected regional soundscape")
    j.phase = TacticalJourney.MAP
    ui.refresh()
    var fade_before: Tween = ambient._fade
    ui.refresh()
    check(ambient._fade == fade_before,"Map refresh preserves soundscape")
    # Enter a new chapter through the actual travel UI, then wait for arrival.
    j.step = 16
    j.phase = TacticalJourney.MAP
    ui._enter()
    var travelling_state := JourneySnapshot.encode(j)
    check(ui.travelling and music.current_key == music.selected_region_key and music.current_key != region_key and ambient.current_key == j.biome()["type"],"Travel adopts a new destination track immediately")
    await create_timer(1.05).timeout
    check(not ui.travelling and music.current_key == music.selected_region_key and is_equal_approx(ambient._target_gain,.28),"Arrival keeps regional music and ducks ambience")
    check(JourneySnapshot.encode(j) == travelling_state,"Travel soundscape leaves newly entered battle/RNG unchanged")
    j.phase = TacticalJourney.FAILED
    ui.refresh()
    check(ambient.current_key.is_empty(),"Failed expedition fades ambience out")
    ui.free()
    await process_frame
    var seed_value := 0
    for seed_candidate in 5000:
        if RareEncounter.target(seed_candidate) == 10169:
            seed_value = seed_candidate
            break
    j = RareFixture.fixture(seed_value)
    RareFixture.enter(j)
    before = JourneySnapshot.encode(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    check(ambient.current_key == j.biome()["type"],"Hidden rare uses route ambience, never species backdrop")
    check(JourneySnapshot.encode(j) == before,"Rare soundscape leaves saved state and RNG unchanged")
    ui.battle_ui.finish_presentation()
    ui.free()
    await process_frame
    var settings: Control = load("res://scripts/ui/settings_panel.gd").new()
    root.add_child(settings)
    check(settings.volume_sliders.has("ambience"),"Settings exposes independent environment slider")
    for channel: String in settings.volume_sliders:
        check(settings.body.get_rect().size.y > settings.volume_sliders[channel].position.y+44,"Volume row fits panel: "+channel)
    settings.free()
    var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    check(music.current_key == "title" and ambient.current_key.is_empty(),"Title fades out former biome ambience")
    await create_timer(1.35).timeout
    for p: AudioStreamPlayer in ambient.players: check(p.stream == null and not p.playing,"Cleared ambience releases stopped voices")
    menu.free()
    ambient.stop_ambience()
    music.stop_music()
    await process_frame
    # Let the audio mixer release stopped WAV playbacks before engine teardown.
    await create_timer(.15).timeout
    print("SOUNDSCAPE: ",checks," checks / ",failures," failures")
    quit(0 if failures == 0 else 1)
