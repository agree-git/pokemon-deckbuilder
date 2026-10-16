extends SceneTree
var checks := 0
var failures := 0
var changes: Array[String] = []
var music: Node
var preferences: Node
var capture := AudioEffectCapture.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func peak() -> float:
    var value := 0.0
    var count := capture.get_frames_available()
    if count > 0:
        for sample: Vector2 in capture.get_buffer(count): value = maxf(value,maxf(absf(sample.x),absf(sample.y)))
    return value
func measured() -> float:
    await create_timer(0.08).timeout
    capture.clear_buffer()
    music.players[music._active].seek(0.0)
    await create_timer(0.45).timeout
    return peak()
func run() -> void:
    music = root.get_node("GameMusic")
    preferences = root.get_node("Preferences")
    preferences.path = "user://music-test.cfg"
    preferences.set_audio_muted(false)
    preferences.set_audio_volume("master",1.0)
    preferences.set_audio_volume("effects",0.0)
    preferences.set_audio_volume("music",1.0)
    music.theme_changed.connect(func(key: String): changes.append(key))
    check(music.players.size() == 2 and music.streams.size() == 5,"Music uses two persistent voices and five themes")
    check(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == "Game","Music shares game master gain and has its own bus")
    for key: String in music.THEMES:
        var stream: AudioStreamWAV = music.streams[key]
        check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.get_length() > 13.0 and stream.get_length() < 24.0,"Original eight-bar loop imports: " + key)
    music.play_theme("title")
    await create_timer(0.7).timeout
    var title_voice: int = music._active
    var start: float = music.players[title_voice].get_playback_position()
    music.play_theme("title")
    await create_timer(0.12).timeout
    check(changes == ["title"] and music.players[title_voice].get_playback_position() > start,"Repeated context requests do not restart a track")
    music.play_theme("camp")
    await create_timer(0.16).timeout
    check(music.players.all(func(p: AudioStreamPlayer): return p.playing and p.volume_linear > 0 and p.volume_linear < 1),"Old and new tracks crossfade together")
    music.play_theme("title")
    await create_timer(0.12).timeout
    check(music._active == title_voice and music.players[title_voice].get_playback_position() > start,"Quick return reuses the still-playing previous theme")
    music.play_theme("boss")
    music.play_theme("champion")
    await create_timer(0.7).timeout
    check(music.current_key == "champion" and music.players.filter(func(p: AudioStreamPlayer): return p.playing).size() == 1,"Interrupted transitions leave only the latest theme playing")
    check(is_equal_approx(music.players[music._active].volume_linear,1.0),"Crossfade reaches full target gain")
    var length: float = music.streams["champion"].get_length()
    music.players[music._active].seek(length-0.07)
    await create_timer(0.3).timeout
    check(music.players[music._active].playing and music.players[music._active].get_playback_position() < 1.0,"Actual PCM playback loops across the final sample")
    music.play_theme("invalid")
    check(music.current_key == "champion","Invalid requests preserve current music")
    music.play_theme("camp")
    await create_timer(0.7).timeout
    capture.buffer_length = 1.0
    AudioServer.add_bus_effect(0,capture)
    var full := await measured()
    check(full > 0.01,"Music produces measured non-silent PCM even with effects volume zero")
    preferences.set_audio_volume("music",0.5)
    var half := await measured()
    check(absf(half/full-0.5) < 0.1,"Music gain halves actual mixed output")
    preferences.set_audio_volume("master",0.5)
    var quarter := await measured()
    check(absf(quarter/full-0.25) < 0.07,"Master and music gains multiply independently")
    preferences.set_audio_volume("music",0.0)
    await create_timer(0.1).timeout
    var paused_at: float = music.players[music._active].get_playback_position()
    capture.clear_buffer()
    await create_timer(0.2).timeout
    check(peak() == 0.0 and absf(music.players[music._active].get_playback_position()-paused_at) < 0.02,"Music zero mutes and pauses playback")
    preferences.set_audio_volume("music",0.55)
    await create_timer(0.15).timeout
    check(music.players[music._active].get_playback_position() > paused_at,"Raising music volume resumes its position")
    preferences.set_audio_muted(true)
    music.play_theme("boss")
    await create_timer(0.7).timeout
    capture.clear_buffer()
    await create_timer(0.12).timeout
    check(peak() == 0.0 and music.players[music._active].stream_paused,"Muted context changes stay silent")
    preferences.set_audio_muted(false)
    await create_timer(0.12).timeout
    check(music.current_key == "boss" and music.players[music._active].playing and not music.players[music._active].stream_paused,"Unmute resumes only the current scene theme")
    preferences.set_audio_volume("master",0.0)
    await create_timer(0.1).timeout
    capture.clear_buffer()
    await create_timer(0.12).timeout
    check(peak() == 0.0 and music.players[music._active].stream_paused,"Master zero also pauses and silences music")
    preferences.set_audio_volume("master",0.75)
    preferences.set_battle_speed(2.0)
    check(music.players[music._active].pitch_scale == 1.0,"Battle speed cannot raise music pitch")
    AudioServer.remove_bus_effect(0,0)
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    check(music.current_key == "title","Real title screen selects title music")
    menu._choose()
    check(music.current_key == "title","Starter selection preserves title music")
    menu.free()
    for role: String in ["wild","trainer","veteran","gym","elite","champion"]:
        var b := TacticalBattle.new(71)
        var before := b.snapshot()
        var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
        ui.battle = b
        if role != "wild": ui.opponent_trainer = {"kind":role,"name":"음악 검사","type":"grass"}
        root.add_child(ui)
        await process_frame
        check(music.current_key == music.for_battle(role),"Real battle screen selects " + role + " theme")
        check(b.snapshot() == before,"Music context cannot change battle state or RNG")
        ui.free()
    var final_fight := TacticalJourney.new(71,"field_kit",[4],false)
    var winning := final_fight.battle
    winning.enemy().hp = 1
    winning.enemy().block = 0
    winning.energy = 8
    winning.hand.assign([BattleCardInstance.new(901,"move_52",winning.active().uid)])
    var result_ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    result_ui.battle = winning
    result_ui.opponent_trainer = {"kind":"gym","name":"음악 검사","type":"grass"}
    root.add_child(result_ui)
    await process_frame
    result_ui.finish_presentation()
    result_ui._card(901)
    check(winning.phase == TacticalBattle.WON and music.current_key == "boss","A winning rule commit keeps battle music during its remaining animation")
    result_ui.finish_presentation()
    check(music.current_key == "camp","Finished victory presentation fades to relaxed result music")
    result_ui.free()
    var journey := TacticalJourney.new(2026,"field_kit",[1,4,7],false)
    journey.phase = TacticalJourney.MAP
    journey.step = 1
    journey.enter_next()
    var camp: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    camp.journey = journey
    root.add_child(camp)
    await process_frame
    check(music.current_key == "camp","Real camp selects relaxed music")
    var position: float = music.players[music._active].get_playback_position()
    var previous_changes := changes.size()
    camp.refresh()
    await process_frame
    check(changes.size() == previous_changes and music.players[music._active].get_playback_position() >= position,"Camp redraw does not restart its music")
    camp.free()
    music.stop_music()
    check(music.current_key.is_empty() and not music.players.any(func(p: AudioStreamPlayer): return p.playing),"Explicit music stop clears both voices")
    # AudioServer releases stopped PCM playback on its next mixer update.
    await create_timer(0.12).timeout
    print("MUSIC: ",checks," checks, ",failures," failures; mixed PCM peaks ",[full,half,quarter])
    quit(0 if failures == 0 else 1)
