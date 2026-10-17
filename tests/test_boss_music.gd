extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    var manifest := BossMusic.data()
    check(manifest["tracks"].size() == 36 and manifest["sources"].size() == 39 and manifest["archives"].size() == 8,"36 unique recordings from39 supplied files /8ZIPs")
    check(manifest["trainers"].size() == 137,"Every boss matchup has role-qualified music")
    for track: Dictionary in manifest["tracks"]:
        var stream: AudioStreamOggVorbis = load(track["path"])
        check(stream != null and stream.loop and absf(stream.get_length()-float(track["duration_seconds"])) < .1,"Complete looping recording "+track["id"])
        var playback := stream.instantiate_playback()
        playback.start()
        playback.seek(2)
        var frames := playback.mix_audio(1,8192)
        check(frames.size() == 8192 and frames.to_byte_array().count(0) < frames.to_byte_array().size(),"Audible Vorbis decode "+track["id"])
        playback.seek(stream.get_length()-.01)
        check(playback.mix_audio(1,2048).size() == 2048 and playback.is_playing(),"Loop crosses end "+track["id"])
        playback.stop()
    var expansion := BossExpansion.data()
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var roster := {"gym":GymLeaders.all(),"elite":league["elite"]+expansion["elite"],"champion":league["champions"]+expansion["champions"]}
    var music := root.get_node("GameMusic")
    var catalog := VisualCatalog.new()
    var journey := TacticalJourney.new(712,"field_kit",[1,4,7],true)
    var snapshot := JourneySnapshot.encode(journey)
    for role: String in roster:
        for entry: Dictionary in roster[role]:
            var key := role+":"+str(entry.get("leader_id",entry.get("id")))
            var stop := {"kind":role,"trainer":entry}
            var trainer := TrainerDialogue.opponent(stop,catalog.biomes[0])
            check(TrainerDialogue.key(trainer) == key and not BossMusic.variants(trainer).is_empty(),"Role-specific music "+key)
            check(TrainerSprites.texture(trainer) != null and TrainerSprites.bounds(trainer).has_area(),"Individual credited sprite "+key)
            for phase: String in TrainerDialogue.PHASES:
                check(not TrainerDialogue.line(trainer,phase).is_empty(),"Authored dialogue "+key+"/"+phase)
            var room := BattleBackdrops.for_stop(stop,catalog.biomes[0])
            check(VisualCatalog.biome_texture(room) != null,"Valid room "+key)
            var tactics: Dictionary = BossTactics.trainers()[key]
            check(tactics["styles"].size() == entry["party"].size(),"Party/style correspondence "+key)
            for i in entry["party"].size():
                var id := int(entry["party"][i])
                check(not catalog.species(id).is_empty() and not BossTactics.build(key,i,id,50,catalog.species(id)["types"]).is_empty(),"Playable supported party slot "+key+"/"+str(i))
            seed(1234)
            var expected := randi()
            seed(1234)
            music.play_boss(trainer,journey)
            check(randi() == expected and music.current_key.begins_with(key+":"),"Dedicated music preserves global RNG "+key)
            var state: int = music._boss_rng.state
            var chosen: String = music.current_key
            music.play_boss(trainer,journey)
            check(music.current_key == chosen and music._boss_rng.state == state,"UI refresh keeps boss recording "+key)
    check(JourneySnapshot.encode(journey) == snapshot,"All boss presentation preserves complete campaign/save/RNG state")
    check(BossMusic.variants({"kind":"gym","id":"blue"}) != BossMusic.variants({"kind":"champion","id":"blue"}),"Gym Blue and champion Blue keep their own themes")
    check(BossMusic.variants({"kind":"gym","id":"hala"}) != BossMusic.variants({"kind":"elite","id":"hala"}),"Hala roles keep separate supplied recordings")
    check(BossMusic.variants({"kind":"gym","id":"burgh"}).size() == 2,"BW/BW2 variants retained within same role")
    check(BossMusic.variants({"kind":"champion","id":"red"}).size() == 1,"Mount Silver Red is a champion")
    check(manifest["fallbacks"].size() == 3,"Unlisted Bede/Marnie/Tyme use documented regional general gym theme")
    music.stop_music()
    await create_timer(1.4).timeout
    print("Boss music: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
