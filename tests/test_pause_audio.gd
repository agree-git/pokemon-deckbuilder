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
    var ambient := root.get_node("GameAmbience")
    var prefs := root.get_node("Preferences")
    prefs.path = "user://pause-audio-settings.cfg"
    prefs.set_audio_muted(false)
    var j := TacticalJourney.new(117,"field_kit",[1,4,7],true)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await create_timer(.3).timeout
    var view := ui.battle_ui
    var before := JourneySnapshot.encode(j)
    var track: String = music.current_key
    var voice: AudioStreamPlayer = music.players[music._active]
    var position := voice.get_playback_position()
    view._open_overlay(view.menu_panel)
    check(view.menu_panel.visible and music.muffled and ambient.muffled,"Pause menu muffles music and ambience immediately")
    Engine.time_scale = 2
    await create_timer(.35,true,false,true).timeout
    Engine.time_scale = 1
    for layer: Node in [music,ambient]:
        check(layer._muffle_filter is AudioEffectLowPassFilter,"Real engine low-pass effect is installed")
        check(AudioServer.is_bus_effect_enabled(layer._bus_index,layer._muffle_index) and is_equal_approx(layer._muffle_filter.cutoff_hz,1200),"Pause reaches 1200Hz low-pass in real time")
    check(music.current_key == track and voice.get_playback_position() >= position,"Muffling keeps the same track and playback position")
    prefs.show_panel(view)
    check(music.muffled and ambient.muffled,"Nested settings keeps pause filtering")
    prefs.set_audio_volume("music",.23)
    check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),.23),"Filter does not replace or double-apply saved music volume")
    prefs.set_audio_muted(true)
    check(voice.stream_paused,"Master mute remains effective under pause filter")
    prefs.set_audio_muted(false)
    prefs.panel.close()
    await process_frame
    check(music.muffled and ambient.muffled,"Closing nested settings leaves the outer pause filter active")
    view._close_overlays(true)
    await create_timer(.35).timeout
    for layer: Node in [music,ambient]:
        check(not layer.muffled and not AudioServer.is_bus_effect_enabled(layer._bus_index,layer._muffle_index),"Closing final menu bypasses low-pass completely")
        check(is_equal_approx(layer._muffle_filter.cutoff_hz,20000),"Normal cutoff restored after menu close")
    view._open_overlay(view.menu_panel)
    await create_timer(.05).timeout
    view._close_overlays(true)
    view._open_overlay(view.menu_panel)
    await create_timer(.35).timeout
    check(music.muffled and is_equal_approx(music._muffle_filter.cutoff_hz,1200),"Rapid close/reopen cancels stale restore callback")
    check(JourneySnapshot.encode(j) == before,"Pause/settings preserve complete campaign/save/RNG snapshot")
    ui.free()
    await create_timer(.35).timeout
    check(not music.muffled and not ambient.muffled and prefs._background_menus.is_empty(),"Scene removal releases pause ownership")
    var host := Control.new()
    root.add_child(host)
    prefs.show_panel(host)
    await create_timer(.3).timeout
    check(music.muffled and ambient.muffled,"Standalone title/camp settings muffles background audio")
    host.free()
    await create_timer(.35).timeout
    check(not music.muffled and not ambient.muffled and prefs._background_menus.is_empty(),"Removing a settings host restores the audio")
    check(is_equal_approx(prefs.music_volume,.23),"Closing menus preserves user volume")
    check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Game")) == 0,"UI effects and cries bus receives no low-pass")
    music.stop_music()
    ambient.stop_ambience()
    await process_frame
    await create_timer(.2).timeout
    print("PAUSE_AUDIO: ",checks," checks / ",failures," failures")
    quit(0 if failures == 0 else 1)
