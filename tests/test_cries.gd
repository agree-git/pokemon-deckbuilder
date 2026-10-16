extends SceneTree
var checks := 0
var failures := 0
var cries: Node
var preferences: Node
var heard: Array[Array] = []
var capture := AudioEffectCapture.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func measured() -> float:
    cries.stop_all()
    await create_timer(0.1).timeout
    capture.clear_buffer()
    cries.play(1)
    await create_timer(0.6).timeout
    var peak := 0.0
    var count := capture.get_frames_available()
    if count > 0:
        for sample: Vector2 in capture.get_buffer(count): peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
    return peak
func run() -> void:
    cries = root.get_node("GameCries")
    preferences = root.get_node("Preferences")
    preferences.path = "user://cries-test.cfg"
    preferences.set_audio_muted(false)
    preferences.set_audio_volume("master",1.0)
    preferences.set_audio_volume("effects",0.0)
    preferences.set_audio_volume("music",0.0)
    preferences.set_audio_volume("cries",1.0)
    cries.cry_played.connect(func(id: int, ally: bool): heard.append([id,ally]))
    check(cries.voices.size() == 2 and cries.streams.is_empty(),"Two persistent voices; no initial bulk preload")
    check(AudioServer.get_bus_send(AudioServer.get_bus_index("Cries")) == "Game","Cry bus shares game master only")
    for id in range(1,387):
        cries.play(id,id % 2 == 0)
        var stream: AudioStreamOggVorbis = cries.streams[id]
        check(stream != null and not stream.loop and stream.get_length() > 0.1,"Non-looping imported cry #%03d" % id)
        if id % 24 == 0: await process_frame
    check(cries.streams.size() == 12 and cries._recent.size() == 12 and not cries.streams.has(1),"Species cache evicts to twelve; voices remain bounded")
    cries.play(375)
    check(cries.voices.all(func(v: AudioStreamPlayer): return v.pitch_scale == 1.0 and is_equal_approx(v.volume_linear,0.35)),"Cries preserve pitch and fixed mixing headroom")
    check(cries._recent.back() == 375 and cries.streams.size() == 12,"Cache hit updates LRU without duplicate entries")
    cries.play(1,true)
    cries.play(25,false)
    check(cries.voices[0].playing and cries.voices[1].playing,"Separate battle sides can cry independently")
    cries.stop_side(true)
    check(not cries.voices[0].playing and cries.voices[0].stream == null and cries.voices[1].playing,"Recall stops and releases only the recalled side")
    cries.stop_all()
    await create_timer(0.5).timeout # Drain the exhaustive import/play stress before measuring one voice.
    capture.buffer_length = 2.0
    AudioServer.add_bus_effect(0,capture)
    var full := await measured()
    check(full > 0.01,"Actual cry PCM remains audible with music and effects at zero")
    preferences.set_audio_volume("cries",0.5)
    var half := await measured()
    check(absf(half/full-0.5) < 0.07,"Cry slider halves actual PCM")
    preferences.set_audio_volume("master",0.5)
    var quarter := await measured()
    check(absf(quarter/full-0.25) < 0.05,"Master and cry gains multiply")
    preferences.set_audio_volume("cries",0.0)
    var before := heard.size()
    check(await measured() == 0.0 and heard.size() == before,"Zero cry gain rejects new playback and emits no delayed cue")
    preferences.set_audio_volume("cries",1.0)
    preferences.set_audio_muted(true)
    check(await measured() == 0.0,"Global mute silences cries")
    preferences.set_audio_muted(false)
    preferences.set_audio_volume("master",0.0)
    check(await measured() == 0.0,"Master zero silences cries independently")
    preferences.set_audio_volume("master",1.0)
    cries.play(1)
    preferences.set_audio_muted(true)
    check(cries.voices.all(func(v: AudioStreamPlayer): return not v.playing and v.stream == null),"Muting clears active voices immediately")
    preferences.set_audio_muted(false)
    before = heard.size()
    cries.play(0)
    cries.play(387)
    check(heard.size() == before,"Out-of-scope IDs are silent and never loaded")
    cries.play(25)
    await create_timer(1.5).timeout
    check(cries.voices[0].stream == null,"Finished one-shot releases its player reference")
    cries.play(1)
    scene_changed.emit()
    check(cries.voices.all(func(v: AudioStreamPlayer): return not v.playing),"Scene transition cuts old cries")
    AudioServer.remove_bus_effect(0,0)
    var b := TacticalBattle.new(71)
    b.energy = 8
    b.hand.assign([BattleCardInstance.new(101,"move_55",7)])
    var snapshot := b.snapshot()
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    heard.clear()
    root.add_child(ui)
    await process_frame
    check(heard == [[b.active().species_id,true]],"First ally cries on battle appearance")
    ui._refresh()
    ui._refresh()
    check(heard.size() == 1,"HUD refresh never repeats a cry")
    await create_timer(1.1).timeout
    check(heard == [[b.active().species_id,true],[b.enemy().species_id,false]],"Wild enemy appearance follows ally")
    check(b.snapshot() == snapshot,"Opening audio leaves battle and RNG unchanged")
    heard.clear()
    ui._card(101)
    check(heard.is_empty(),"Auto switch does not cry at rule commit")
    for i in 250:
        if not heard.is_empty(): break
        await create_timer(0.01).timeout
    check(heard == [[7,true]] and ui.stage.canvas.source_species == 7,"New owner cries at actual ball release, after visual species changes")
    ui.finish_presentation()
    # Defeat the first opponent and check the next enemy uses its own cry.
    b.energy = 8
    b.enemy().hp = 1
    b.hand.assign([BattleCardInstance.new(102,"move_55",7)])
    heard.clear()
    ui._card(102)
    for i in 500:
        if not ui.busy: break
        await create_timer(0.01).timeout
    check(b.enemy_index == 1 and heard == [[b.enemy().species_id,false]],"Enemy replacement cries only for the new displayed opponent")
    ui.free()
    check(cries.voices.all(func(v: AudioStreamPlayer): return not v.playing),"Leaving battle stops cries")
    # An immediate action cancels the delayed wild opening cue.
    b = TacticalBattle.new(71)
    b.energy = 8
    ui = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    heard.clear()
    ui._end()
    await create_timer(1.15).timeout
    check(not heard.any(func(row: Array): return not row[1]),"Starting an action cancels stale wild opening audio")
    ui.finish_presentation()
    ui.free()
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.step = 10
    j.phase = TacticalJourney.MAP
    j.enter_next()
    var campaign_before := JourneySnapshot.encode(j)
    var journey_ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    journey_ui.journey = j
    heard.clear()
    root.add_child(journey_ui)
    await process_frame
    check(heard.size() == 1 and heard[0][1],"Trainer enemy remains silent while trainer is on screen")
    for i in 300:
        if not journey_ui.battle_ui.busy: break
        await create_timer(0.01).timeout
    check(heard == [[j.battle.active().species_id,true],[j.battle.enemy().species_id,false]],"Trainer enemy cries exactly once from thrown ball")
    check(JourneySnapshot.encode(j) == campaign_before,"Trainer cries do not change campaign save or RNG")
    journey_ui.free()
    # Exercise the real SceneTree replacement, not only root.add_child fixtures.
    var old_scene := Control.new()
    root.add_child(old_scene)
    current_scene = old_scene
    heard.clear()
    check(change_scene_to_file("res://scenes/tactical_battle.tscn") == OK,"Change to a real battle scene")
    await scene_changed
    await process_frame
    check(heard.size() == 1 and heard[0][1] and cries.voices[0].playing,"New scene's initial cry survives previous-scene cleanup")
    current_scene.free()
    root.get_node("GameMusic").stop_music()
    cries.stop_all()
    await create_timer(0.15).timeout
    print("CRIES: ",checks," checks, ",failures," failures; PCM full/half/quarter=",full,"/",half,"/",quarter)
    quit(0 if failures == 0 else 1)
