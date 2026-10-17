extends SceneTree
## Actual X11 keys/pointer plus engine DSP capture of generated test tones.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func focus() -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
func key(symbol: String) -> void:
    focus()
    print("OS_KEY ",symbol)
    await create_timer(.45).timeout
func click(control: Control) -> void:
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    focus()
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    await create_timer(.4).timeout
func amplitude(frames: PackedVector2Array,frequency: float,rate: float) -> float:
    var real := 0.0
    var imaginary := 0.0
    var count := mini(2048,frames.size())
    for i in count:
        var sample := frames[frames.size()-count+i].x
        real += sample*cos(TAU*frequency*i/rate)
        imaginary += sample*sin(TAU*frequency*i/rate)
    return sqrt(real*real+imaginary*imaginary)/maxi(1,count)
func probe_filter(music: Node) -> void:
    var rate := AudioServer.get_mix_rate()
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = rate
    generator.buffer_length = 1
    var player := AudioStreamPlayer.new()
    player.stream = generator
    player.bus = "Music"
    root.add_child(player)
    var capture := AudioEffectCapture.new()
    capture.buffer_length = 1
    var bus := AudioServer.get_bus_index("Music")
    var index := AudioServer.get_bus_effect_count(bus)
    AudioServer.add_bus_effect(bus,capture)
    var frames := PackedVector2Array()
    frames.resize(int(rate))
    for i in frames.size():
        var sample := .15*(sin(TAU*500*i/rate)+sin(TAU*6000*i/rate))
        frames[i] = Vector2(sample,sample)
    player.play()
    var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
    check(playback.push_buffer(frames),"Generated 500Hz/6kHz test tones enter real mixer")
    capture.clear_buffer()
    await create_timer(.16).timeout
    var normal := capture.get_buffer(capture.get_frames_available())
    music.set_muffled(true)
    capture.clear_buffer()
    await create_timer(.36).timeout
    var filtered := capture.get_buffer(capture.get_frames_available())
    check(normal.size() >= 2048 and filtered.size() >= 2048,"Real mixer capture returns normal and filtered samples")
    var low := amplitude(normal,500,rate)
    var high := amplitude(normal,6000,rate)
    var low_filtered := amplitude(filtered,500,rate)
    var high_filtered := amplitude(filtered,6000,rate)
    print("FILTER_DSP low=",low," high=",high," filtered_low=",low_filtered," filtered_high=",high_filtered)
    check(low > .001 and high > .001,"Both test-tone bands are audible in original output")
    check(low_filtered > low*.35,"Low-pass retains the low-frequency band")
    check(high_filtered/maxf(low_filtered,.000001) < high/maxf(low,.000001)*.2,"Low-pass attenuates 6kHz relative to 500Hz by more than 14dB")
    music.set_muffled(false)
    player.stop()
    player.free()
    AudioServer.remove_bus_effect(bus,index)
    await create_timer(.3).timeout
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var music := root.get_node("GameMusic")
    var ambient := root.get_node("GameAmbience")
    var prefs := root.get_node("Preferences")
    prefs.set_audio_muted(false)
    var j := TacticalJourney.new(117,"field_kit",[1,4,7],true)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.6).timeout
    var before := JourneySnapshot.encode(j)
    var selected: String = music.current_key
    await key("Escape")
    check(ui.battle_ui.menu_panel.visible and music.muffled and ambient.muffled,"Actual Esc opens the pause menu and filters both backgrounds")
    await click(ui.battle_ui.settings_button)
    check(is_instance_valid(prefs.panel) and music.muffled,"Actual settings click retains filtering")
    await key("Escape")
    check(not is_instance_valid(prefs.panel) and music.muffled,"Actual Esc closes settings while outer pause retains filtering")
    check(music.current_key == selected and JourneySnapshot.encode(j) == before,"Pause keys/settings preserve selection and campaign/RNG")
    await key("Escape")
    check(not music.muffled and not ambient.muffled,"Actual Esc closes the final pause menu")
    await key("Escape")
    await key("Escape")
    check(not music.muffled and not ambient.muffled,"Actual rapid menu reopen/close restores both buses")
    j.step = 16
    j.phase = TacticalJourney.MAP
    ui.refresh()
    ui._enter()
    var destination: String = music.current_key
    check(destination != selected,"Next region chooses a different recording during actual travel")
    await create_timer(1.1).timeout
    check(not ui.travelling and music.current_key == destination,"Arrival keeps destination music in the ordinary battle")
    ui.free()
    music.stop_music()
    ambient.stop_ambience()
    await create_timer(.3).timeout
    await probe_filter(music)
    await process_frame
    print("NATIVE_REGION_AUDIO: ",checks," checks / ",failures," failures; 5 OS keys / 1 OS click")
    quit(0 if failures == 0 else 1)
