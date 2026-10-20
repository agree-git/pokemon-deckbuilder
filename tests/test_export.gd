extends Node
## Separate test-only export with game entries byte-matched to the shipped PCK.
var checks := 0
var failures := 0
var root: Window
func _ready() -> void:
    root = get_tree().root
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    if not FileAccess.file_exists("user://.export-smoke-profile"):
        push_error("Refusing to test outside the caller's fresh marked profile")
        get_tree().quit(2)
        return
    check(not OS.has_feature("editor"),"Actual export template, not editor")
    check(ProjectSettings.get_setting("application/config/version","")=="0.28.7","Packed release version v0.28.7")
    var args := OS.get_cmdline_user_args()
    check(args.size() == 1 and OS.get_name() == args[0],"Expected target operating system")
    check(Engine.get_version_info()["string"].begins_with("4.7.2"),"Pinned engine version")
    check(FileAccess.file_exists("res://project.binary"),"Project loaded from packed binary settings")
    check(not FileAccess.file_exists("res://AGENTS.md") and not FileAccess.file_exists("res://.dev-materials/HANDOFF.md"),"Developer files excluded from package")
    var splash_path := str(ProjectSettings.get_setting("application/boot_splash/image", ""))
    check(splash_path == "res://assets/branding/boot_splash.png", "Game boot splash configured")
    var splash := Image.load_from_file(splash_path)
    check(splash != null and splash.get_size() == Vector2i(1920,1080), "Raw boot PNG readable from shipped PCK")
    var icon: Texture2D = load(str(ProjectSettings.get_setting("application/config/icon", "")))
    check(icon != null and icon.get_size() == Vector2(512,512), "Packed game window icon")
    for path: String in JourneySave.CONTENT:
        check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) != null,"Packed data readable: "+path)
    var catalog := VisualCatalog.new()
    check(catalog.pokemon.size() == 1412 and catalog.biomes.size() == 18,"Complete shipped catalog")
    var animation = preload("res://scripts/content/pokemon_animation.gd")
    var views: Dictionary = animation.data()["views"]
    var sheets_ok := views.size()==2824
    for record: Dictionary in views.values():
        if not ResourceLoader.exists(record["sheet"]) or record["frames"].size()<2:sheets_ok=false
    check(sheets_ok,"All 2824 animated views and imported sheets are packed")
    for id: int in [1,25,1007,1025]:
        for back: bool in [false,true]:
            var animated: AtlasTexture = animation.texture(id,back)
            check(animated.atlas!=null and animated.region.size.x>0,"Packed animated atlas decodes "+str(id)+"/"+str(back))
    var regional := RegionMusic.tracks()
    check(regional.size() == 35,"All supplied regional recordings are packed")
    for entry: Dictionary in regional:
        var stream: AudioStreamOggVorbis = load(entry["path"])
        check(stream != null and stream.loop and absf(stream.get_length()-float(entry["duration_seconds"])) < .1,"Packed regional music: "+entry["title"])
    check(BossMusic.data()["tracks"].size() == 36 and BossMusic.data()["trainers"].size() == 137,"All boss recordings and role mappings are packed")
    for track: Dictionary in BossMusic.data()["tracks"]:
        var stream: AudioStreamOggVorbis = load(track["path"])
        check(stream != null and stream.loop and absf(stream.get_length()-float(track["duration_seconds"])) < .1,"Packed boss music "+track["id"])
    var base_league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var rosters := {"gym":GymLeaders.all(),"elite":base_league["elite"]+BossExpansion.data()["elite"],"champion":base_league["champions"]+BossExpansion.data()["champions"]}
    for role: String in rosters:
        for entry: Dictionary in rosters[role]:
            entry = BossParties.apply(role,entry)
            var trainer := TrainerDialogue.opponent({"kind":role,"trainer":entry},catalog.biomes[0])
            check(TrainerSprites.texture(trainer) != null and not TrainerDialogue.line(trainer,"intro").is_empty() and not BossMusic.variants(trainer).is_empty(),"Packed complete boss "+TrainerDialogue.key(trainer))
            check(entry["party"] == BossParties.party(TrainerDialogue.key(trainer)),"Packed approved boss party "+TrainerDialogue.key(trainer))
    for key: String in BossExpansion.data()["backdrops"]:
        check(VisualCatalog.biome_texture(BossExpansion.data()["backdrops"][key]) != null,"Packed new boss room "+key)
    for pokemon: Dictionary in catalog.pokemon:
        var id := int(pokemon["id"])
        for back: bool in [false,true]:
            var sprite: Texture2D = load(VisualCatalog.sprite_path(id,back))
            check(sprite != null and sprite.get_width() > 0,"Packed sprite: "+str(id)+"/"+str(back))
        var cry: AudioStream = load("res://assets/audio/cries/%d.ogg" % id)
        check(cry != null and cry.get_length() > 0,"Packed cry: "+str(id))
    for biome: Dictionary in catalog.biomes:
        check(VisualCatalog.biome_texture(biome) != null,"Packed biome texture")
        for path: String in [BiomeAudio.music_path(biome["type"]),BiomeAudio.ambience_path(biome["type"])]:
            var sound: AudioStreamOggVorbis = load(path)
            check(sound != null and sound.loop and sound.get_length() >= 31.9,"Packed biome loop: "+path)
    for id: int in RareEncounter.IDS:
        check(not RareEncounterStory.entry(id).is_empty(),"Packed rare story: "+str(id))
        for event: String in RareCaptureReaction.EVENTS:
            check(not RareCaptureReaction.line(id,event).is_empty(),"Packed reaction: "+str(id)+"/"+event)
    var main_menu: Control = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(main_menu)
    await get_tree().process_frame
    check(main_menu.get_child_count() > 0,"Exported title scene constructs")
    main_menu.free()
    var session := root.get_node("BattleSession")
    var tutorial_before := JourneySnapshot.encode(session.journey)
    var tutorial_has_run: bool = session.has_journey
    var tutorial: TutorialUI = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(tutorial)
    check(tutorial.step == 0 and tutorial.practice.battle.card_reason(TutorialLesson.FIRST_CARD).is_empty(),"Packed practice scene and real first card construct")
    tutorial.step = 8
    tutorial._camp()
    await get_tree().process_frame
    check(tutorial.camp_view != null and not tutorial.camp_view.rest_button.disabled,"Packed camp practice subclass constructs")
    tutorial.queue_free()
    await get_tree().process_frame
    check(session.has_journey == tutorial_has_run and JourneySnapshot.encode(session.journey) == tutorial_before,"Practice leaves exported campaign state untouched")
    var starters: Array[int] = [1,4,7]
    check(session.start_journey(starters,47123).is_empty(),"Start a new real campaign")
    var journey: TacticalJourney = session.journey
    check(journey.full_campaign and journey.route.stops.size() == 137 and journey.party.size() == 3,"Real 69-battle route and selected starters")
    check(journey.route.generation == 28 and CampaignChallenge.rest_percent(journey) == 40 and journey.battle.enemy_definitions[0].get("challenge_version") == 28,"Packed new expedition uses challenge v28")
    var champion := journey.route.opponents(136)
    check(champion.all(func(d: Dictionary): return CampaignChallenge.valid(d,journey.route,136) and d["challenge_pressure"] == 210 and d["challenge_block"] > 0),"Packed champion difficulty data and every opening shield")
    var view: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    view.journey = journey
    root.add_child(view)
    await get_tree().process_frame
    check(view.battle_ui != null and view.battle_ui.hand_row.get_child_count() > 0,"Exported battle scene constructs hand and stage")
    check(view.battle_ui.stage.canvas.source_sprite.has_node("PokemonAnimation") and view.battle_ui.stage.canvas.target_sprite.has_node("PokemonAnimation"),"Packed battle binds both animated Pokemon views")
    check(view.battle_ui.menu_panel.find_child("MusicPlayer",true,false)!=null and view.battle_ui.status_feedback!=null,"Packed pause player and status VFX scripts construct")
    var ending = preload("res://scripts/ui/ending_credits.gd").new()
    root.add_child(ending)
    check(ending.sections[0][1]=="DO" and ending.viewport_panel.clip_contents,"Packed ending credits include DO and clipped roll")
    check(FileAccess.get_file_as_string("res://Credit.txt").begins_with("Pokémon Expedition / 포켓몬 원정대\nMade by DO"),"Packed Credit.txt preserves DO attribution")
    ending._advance(ending.travel_distance)
    check(ending.finished and ending.pause_button.text=="처음부터","Packed credits stop at final thanks")
    ending.close()
    await get_tree().process_frame
    var music := root.get_node("GameMusic")
    var region_key: String = music.current_key
    check(region_key.begins_with("region_"),"Exported ordinary battle uses supplied regional music")
    view.refresh()
    check(music.current_key == region_key,"Exported refresh preserves regional selection")
    view.battle_ui._open_overlay(view.battle_ui.menu_panel)
    await get_tree().create_timer(.3).timeout
    check(music.muffled and is_equal_approx(music._muffle_filter.cutoff_hz,1200),"Exported pause menu activates low-pass")
    view.battle_ui._close_overlays(true)
    await get_tree().create_timer(.3).timeout
    check(not music.muffled and not AudioServer.is_bus_effect_enabled(music._bus_index,music._muffle_index),"Exported pause close restores original audio")
    var acted := false
    for card: BattleCardInstance in journey.battle.hand:
        if journey.battle.card_reason(card.uid).is_empty():
            check(journey.battle.play_card(card.uid).is_empty(),"Playable exported card resolves")
            acted = true
            break
    check(acted,"Starter has a playable card")
    view.free()
    check(session.start_journey(starters,47124).is_empty(),"Fresh capture boundary fixture")
    journey = session.journey
    journey.battle.enemy().hp = 1
    journey.battle.energy = 1
    journey.balls = 2
    check(journey.capture().is_empty(),"Actual capture in exported runtime")
    check(journey.settle().is_empty(),"Actual battle settlement")
    while journey.phase == TacticalJourney.LEARN: journey.resolve_learning(-1)
    check(journey.phase == TacticalJourney.CAPTURE and journey.resolve_capture(0).is_empty(),"Capture joins/replaces after growth")
    check(session.checkpoint().is_empty(),"Save exported campaign")
    var before := JourneySnapshot.encode(journey)
    var restored: TacticalJourney = session.save_store.load_journey()
    check(restored != null and JourneySnapshot.encode(restored) == before,"Exported save preserves party, deck, UIDs and RNG")
    var profile := PlayerProfile.new()
    check(not profile.captured_ids.is_empty(),"Permanent capture collection saved")
    var preferences := root.get_node("Preferences")
    preferences.set_audio_volume("ambience",.27)
    var loaded: Node = load("res://scripts/preferences.gd").new()
    loaded.load_preferences()
    check(is_equal_approx(loaded.ambience_volume,.27),"Exported settings persist")
    loaded.free()
    var reaction := RareReactionPanel.new()
    reaction.species_id = 1007
    reaction.event = "joined"
    root.add_child(reaction)
    UiMotion.finish_tree(reaction)
    check(not reaction.quote.text.is_empty(),"Rare reaction scene/code/data load from PCK")
    reaction.free()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameAmbience").stop_ambience()
    root.get_node("GameCries").stop_all()
    root.get_node("GameAudio").stop_all()
    await get_tree().process_frame
    await get_tree().create_timer(.2).timeout
    print("EXPORT_USER_DIR ",OS.get_user_data_dir())
    print("EXPORT_SMOKE: ",checks," checks / ",failures," failures")
    get_tree().quit(0 if failures == 0 else 1)
