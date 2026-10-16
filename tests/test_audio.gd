extends SceneTree
var checks := 0
var failures := 0
var heard: Array[String] = []
var audio: Node
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
    if count == 0: return value
    for sample: Vector2 in capture.get_buffer(count): value = maxf(value, maxf(absf(sample.x), absf(sample.y)))
    return value
func mixed_peak(key: String) -> float:
    audio.stop_all()
    await create_timer(0.07).timeout
    capture.clear_buffer()
    audio.play(key)
    await create_timer(0.42).timeout
    return peak()
func run() -> void:
    audio = root.get_node("GameAudio")
    preferences = root.get_node("Preferences")
    preferences.path = "user://audio-test.cfg"
    preferences.set_audio_volume("master", 1.0)
    preferences.set_audio_volume("effects", 1.0)
    preferences.set_audio_muted(false)
    audio.cue_played.connect(func(key: String): heard.append(key))
    capture.buffer_length = 1.0
    AudioServer.add_bus_effect(0, capture)
    check(audio.streams.size() == 15 and audio.voices.size() == 6, "All original effects load into a bounded voice pool")
    for key: String in audio.KEYS:
        var stream: AudioStreamWAV = audio.streams[key]
        check(stream != null and stream.get_length() > 0.03 and stream.get_length() < 0.7 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Imported one-shot asset is valid: " + key)
    var full := await mixed_peak("heal")
    check(full > 0.01, "AudioServer really mixes non-silent PCM, including with the Dummy output driver")
    preferences.set_audio_volume("master", 0.5)
    var half := await mixed_peak("heal")
    check(absf(half / full - 0.5) < 0.08, "Master gain halves measured output amplitude")
    preferences.set_audio_volume("effects", 0.5)
    var quarter := await mixed_peak("heal")
    check(absf(quarter / full - 0.25) < 0.06, "Effects gain multiplies master gain in the actual mix")
    preferences.set_audio_muted(true)
    heard.clear()
    var muted := await mixed_peak("hit")
    check(muted == 0.0 and heard.is_empty() and not audio.voices.any(func(v: AudioStreamPlayer): return v.playing), "Mute produces silence and does not queue effects for later")
    preferences.set_audio_muted(false)
    preferences.set_audio_volume("effects", 0.0)
    check(await mixed_peak("heal") == 0.0 and heard.is_empty(), "Zero effects volume produces silence")
    preferences.set_audio_volume("effects", 0.8)
    preferences.set_audio_volume("master", 0.0)
    check(await mixed_peak("heal") == 0.0 and heard.is_empty(), "Zero master volume produces silence")
    preferences.set_audio_volume("master", 0.75)
    audio.play("invalid")
    check(heard.is_empty(), "Unknown cue is ignored")
    for i in 30: audio.play("shield")
    audio.play("ui_click")
    check(audio.voices.size() == 6 and audio.click_voice.playing, "Rapid playback cannot grow the pool or steal the dedicated UI voice")
    audio.stop_all()
    check(not audio.click_voice.playing and not audio.voices.any(func(v: AudioStreamPlayer): return v.playing), "All scene tails can be stopped")
    var expected: Dictionary = {}
    for speed: float in preferences.SPEEDS:
        preferences.set_battle_speed(speed)
        var b := TacticalBattle.new(71)
        b.energy = 8
        b.enemy().hp = 500
        b.enemy().max_hp = 500
        b.hand.assign([BattleCardInstance.new(101, "move_55", 7)])
        var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
        ui.battle = b
        root.add_child(ui)
        await process_frame
        heard.clear()
        ui._card(101)
        var committed := b.snapshot()
        check(heard.is_empty(), "Rule commit is silent until its presentation starts")
        if expected.is_empty(): expected = committed
        else: check(b.snapshot() == expected, "Sound and speed cannot alter rules or RNG")
        for i in 400:
            if not ui.busy: break
            await create_timer(0.01).timeout
        check(not ui.busy and b.snapshot() == committed, "Audio playback never reapplies combat rules")
        check(heard.find("recall") >= 0 and heard.find("recall") < heard.find("release") and heard.find("release") < heard.find("attack") and heard.find("attack") < heard.find("hit"), "Recall, release, attack and hit cues follow the actual animation phases at %s" % speed)
        heard.clear()
        preferences.set_audio_muted(true)
        ui.motion.recall(true)
        check(heard.is_empty(), "Switch animation honors mute")
        preferences.set_audio_muted(false)
        UiMotion.finish_tree(ui)
        ui.free()
        audio.stop_all()
    var zero_events := [{"kind":"damage","amount":0,"blocked":0}, {"kind":"shield","amount":0}, {"kind":"heal","amount":0}, {"kind":"draw"}]
    for event: Dictionary in zero_events: check(BattleSoundCues.for_event(event).is_empty(), "No sound for zero change or unannounced draws")
    check(BattleSoundCues.for_event({"kind":"damage","amount":0,"blocked":4}) == "block", "Fully absorbed damage uses the shield impact")
    var support := TacticalBattle.new(71)
    support.energy = 20
    support.active().hp = 1
    support.hand.assign([BattleCardInstance.new(201, "guard", 0), BattleCardInstance.new(202, "potion_card", 0)])
    var support_ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    support_ui.battle = support
    root.add_child(support_ui)
    await process_frame
    heard.clear()
    support_ui._card(201)
    support_ui.finish_presentation()
    check("card_play" in heard and "shield" in heard and heard.find("card_play") < heard.find("shield"), "Real guard card sounds at use, then at shield gain")
    heard.clear()
    support_ui._card(202)
    support_ui.finish_presentation()
    check("heal" in heard and support.active().hp > 1, "Real healing card sounds when HP recovery is displayed")
    support.active().block = 1000
    heard.clear()
    support_ui._end()
    support_ui.finish_presentation()
    check("block" in heard, "Real enemy damage absorbed by a shield uses its distinct impact")
    support_ui.free()
    var stored := FileAccess.get_file_as_string(preferences.path)
    preferences.set_audio_volume("master", NAN)
    preferences.set_audio_volume("effects", -1.0)
    preferences.set_audio_volume("unknown", 0.5)
    check(FileAccess.get_file_as_string(preferences.path) == stored, "Invalid volume inputs cannot mutate disk preferences")
    var copy: Node = load("res://scripts/preferences.gd").new()
    copy.path = preferences.path
    copy.load_preferences()
    check(copy.master_volume == 0.75 and copy.effects_volume == 0.8 and not copy.audio_muted, "Reload restores exact gains and mute state")
    copy.free()
    AudioServer.remove_bus_effect(0, 0)
    audio.play("victory")
    change_scene_to_file("res://scenes/main_menu.tscn")
    await scene_changed
    check(not audio.voices.any(func(v: AudioStreamPlayer): return v.playing), "Scene change stops fanfares and combat tails")
    print("AUDIO: ", checks, " checks, ", failures, " failures; measured PCM peaks ", [full, half, quarter, muted])
    quit(0 if failures == 0 else 1)
