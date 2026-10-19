extends SceneTree
var checks := 0
var failures := 0
var clicks := 0
const FOLDER := "/tmp/pokemon-music-player"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func click(control: Control) -> void:
    if not is_instance_valid(control) or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
        check(false,"Available click target");quit(2);return
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func shot(filename: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(FOLDER.path_join(filename))==OK,"Screenshot "+filename)
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(FOLDER)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    if OS.get_environment("MUSIC_PLAYER_CHECK")=="camp-popup":
        await camp_popup()
        return
    var prefs := root.get_node("Preferences")
    prefs.set_audio_muted(false)
    prefs.set_audio_volume("master",.75)
    prefs.set_audio_volume("music",.55)
    var music := root.get_node("GameMusic")
    var ambient := root.get_node("GameAmbience")
    var session := root.get_node("BattleSession")
    var starters: Array[int] = [1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated expedition starts")
    var actual: TacticalJourney = session.journey
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=actual;root.add_child(ui);current_scene=ui
    await create_timer(1.4).timeout
    var before := JourneySnapshot.encode(actual)
    var saved := FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var battle_ui: TacticalUI = ui.battle_ui
    await key("Escape")
    var player: Control = battle_ui.menu_panel.find_child("MusicPlayer",true,false)
    check(battle_ui.menu_panel.visible and music.muffled and ambient.muffled,"Actual Esc exposes player and muffles both backgrounds")
    check(player.title_label.text==music.current_track_title() and player.next_button.disabled==false and player.previous_button.disabled,"Live title and initial history controls")
    check(player.next_button.position.x-player.play_button.get_rect().end.x>=24 and player.play_button.position.x-player.previous_button.get_rect().end.x>=24,"Transport controls retain 24px gutters")
    var bounds := Rect2(0,0,1920,1080)
    check(bounds.encloses(battle_ui.menu_panel.get_node("Body").get_global_rect()) and not player.get_global_rect().intersects(battle_ui.bag_button.get_global_rect()),"Player and battle actions have separate bounded columns")
    check(player.progress.max_value>1 and player.duration.text!="0:00","Progress bar reports actual stream duration")
    var original: String = music.current_key
    var outgoing: AudioStreamPlayer = music.players[music._active]
    seed(912);var expected := randi();seed(912)
    await click(player.next_button)
    check(randi()==expected,"Actual next click consumes no global gameplay RNG")
    var replacement: String = music.current_key
    var incoming: AudioStreamPlayer = music.players[music._active]
    check(replacement!=original and incoming!=outgoing,"Next chooses a different recording and voice")
    check(incoming.volume_linear>0 and incoming.volume_linear<1 and outgoing.volume_linear>0 and outgoing.volume_linear<1,"Actual next click crossfades both voices")
    check(music.muffled and is_equal_approx(music._muffle_filter.cutoff_hz,1200),"Skipping retains pause-menu low-pass")
    battle_ui._play_soundscape()
    check(music.current_key==replacement,"Ordinary battle sound refresh preserves replacement")
    await click(player.previous_button)
    check(music.current_key==original and player.previous_button.disabled,"Previous returns to actual history and reaches its start")
    var random_state: int = music._selection_rng.state
    await click(player.next_button)
    check(music.current_key==replacement and music._selection_rng.state==random_state,"Forward from previous replays history without drawing again")
    await click(player.play_button)
    var paused_at: float = music.players[music._active].get_playback_position()
    await create_timer(.35).timeout
    check(music.playback_paused and player.play_button.text=="재생" and absf(music.players[music._active].get_playback_position()-paused_at)<.08,"Pause freezes the music playback cursor")
    check(not ambient._silent,"Music pause leaves environment audio alone")
    prefs.set_audio_muted(true)
    await click(player.next_button)
    var all_paused := true
    for voice: AudioStreamPlayer in music.players:
        if voice.stream!=null and not voice.stream_paused: all_paused=false
    check(all_paused and music.playback_paused,"Next while paused/muted keeps both crossfade voices paused")
    prefs.set_audio_muted(false)
    check(music.players[music._active].stream_paused,"Unmuting does not override explicit playback pause")
    await click(player.play_button)
    check(not music.playback_paused and not music.players[music._active].stream_paused,"Actual play resumes selected recording")
    await click(player.volume_slider)
    check(absf(prefs.music_volume-.5)<.1 and player.volume_label.text=="%d%%"%roundi(prefs.music_volume*100),"Actual slider updates preference and percentage")
    await click(battle_ui.settings_button)
    check(is_instance_valid(prefs.panel) and is_equal_approx(prefs.panel.volume_sliders["music"].value,prefs.music_volume*100),"Settings shares the same music volume")
    await key("Escape")
    check(not is_instance_valid(prefs.panel) and music.muffled,"Closing settings retains outer player menu and low-pass")
    await shot("01-battle-player.png")
    replacement=music.current_key
    await key("Escape")
    check(not battle_ui.menu_panel.visible and not music.muffled and music.current_key==replacement,"Closing menu restores background clarity and keeps selected song (visible=%s, muffled=%s, same=%s)"%[battle_ui.menu_panel.visible,music.muffled,music.current_key==replacement])
    for i in 3:
        var prior: String=music.current_key
        check(music.next_track() and music.current_key!=prior,"Rapid skip avoids immediate repeat")
    await create_timer(1.35).timeout
    check(music.players[1-music._active].stream==null and is_equal_approx(music.players[music._active].volume_linear,1),"Rapid skips settle to one fully faded-in voice")
    await key("Escape")
    for boss: Dictionary in [{"kind":"gym","id":"brock"},{"kind":"elite","id":"bruno"},{"kind":"champion","id":"red"}]:
        music.play_boss(boss,actual)
        var boss_key: String=music.current_key
        check(player.next_button.disabled and player.previous_button.disabled and not music.next_track() and not music.previous_track() and music.current_key==boss_key,"Dedicated theme protected for "+str(boss["kind"]))
    check(player.title_label.text==music.current_track_title() and not player.title_label.text.is_empty(),"Dedicated theme title updates in player")
    await shot("02-dedicated-player.png")
    music.play_region(actual)
    check(not player.next_button.disabled,"Normal region restores transport controls")
    check(JourneySnapshot.encode(actual)==before and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Battle controls preserve full campaign, UID/RNG and saved bytes")
    ui.queue_free();await process_frame
    var camp := TutorialLesson.camp_practice()
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=camp;root.add_child(ui);current_scene=ui
    await create_timer(.35).timeout
    var camp_before := JourneySnapshot.encode(camp)
    await key("Escape")
    check(is_instance_valid(ui.pause_menu) and ui.pause_menu.visible and music.muffled,"Camp Esc opens player menu rather than leaving expedition")
    player=ui.pause_menu.find_child("MusicPlayer",true,false)
    original=music.current_key
    await click(player.next_button)
    replacement=music.current_key
    check(replacement!=original,"Camp actual next click changes recording")
    await click(ui.pause_menu.find_child("Settings",true,false))
    await key("Escape")
    check(ui.pause_menu.visible and music.muffled,"Camp nested settings close preserves menu filter")
    await shot("03-camp-player.png")
    await key("Escape")
    check(not ui.pause_menu.visible and not music.muffled,"Camp Esc resumes without navigating home (visible=%s, muffled=%s)"%[ui.pause_menu.visible,music.muffled])
    ui.refresh()
    check(music.current_key==replacement,"Camp refresh preserves manually selected track")
    await click(ui.deck_button);await key("Escape")
    check(not ui.deck_open and not ui.pause_menu.visible,"Esc closes existing camp popup before opening player")
    check(JourneySnapshot.encode(camp)==camp_before and JourneySnapshot.encode(actual)==before and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Camp controls preserve fixture, real expedition and saved bytes")
    var tracks: Array[Dictionary]=music.region_tracks.duplicate()
    music.region_tracks.assign([tracks[0]])
    check(not music.can_next_track() and not music.next_track(),"Single-track playlist cannot skip")
    music.region_tracks.clear()
    check(not music.can_next_track() and not music.next_track(),"Empty playlist cannot skip")
    music.region_tracks.assign(tracks)
    ui.queue_free();await process_frame
    check(not music.muffled and not ambient.muffled,"Menu teardown releases muffle registrations")
    music.stop_music();ambient.stop_ambience()
    await create_timer(.2).timeout
    print("MUSIC_PLAYER: ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)

func camp_popup() -> void:
    var session := root.get_node("BattleSession")
    var starters: Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated save starts")
    var actual: TacticalJourney=session.journey
    var baseline:=JourneySnapshot.encode(actual)
    var saved:=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var camp:=TutorialLesson.camp_practice()
    var before:=JourneySnapshot.encode(camp)
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=camp;root.add_child(ui);current_scene=ui
    await create_timer(.4).timeout
    await click(ui.deck_button)
    check(ui.deck_open,"Actual deck button opens existing popup")
    await key("Escape")
    check(not ui.deck_open and not is_instance_valid(ui.pause_menu),"Esc closes deck without opening the music menu")
    await key("Escape")
    check(ui.pause_menu.visible and root.get_node("GameMusic").muffled,"Next Esc opens music menu and low-pass")
    await shot("04-camp-popup-recheck.png")
    await key("Escape")
    check(not ui.pause_menu.visible and not root.get_node("GameMusic").muffled,"Esc resumes camp after menu animation")
    check(JourneySnapshot.encode(camp)==before and JourneySnapshot.encode(actual)==baseline and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Actual popup flow preserves campaign, fixture and save bytes")
    ui.queue_free();await process_frame
    root.get_node("GameMusic").stop_music();root.get_node("GameAmbience").stop_ambience()
    await create_timer(.2).timeout
    print("MUSIC_PLAYER_CAMP_POPUP: ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)
