extends SceneTree
var checks := 0
var failures := 0
var gallery := "/tmp/pokemon-fan-trainers"
var catalog := VisualCatalog.new()
var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func boss(key: String) -> TacticalUI:
    var role := key.get_slice(":",0)
    var id := key.get_slice(":",1)
    var pool: Array = GymLeaders.all() if role == "gym" else league["elite"]
    var trainer: Dictionary = pool.filter(func(p: Dictionary): return p.get("leader_id",p.get("id","")) == id)[0]
    var stop := {"kind":role,"trainer":trainer,"party":trainer["party"],"level":30}
    var route := CampaignRoute.new(42)
    route.stops[0] = stop
    var party: Array[BattlePokemon] = []
    for species in [4,7,1]:
        var p := BattlePokemon.new(TacticalContent.member_definition(species,catalog),species)
        p.level = 30
        PokemonStats.apply(p,true)
        party.append(p)
    var cards: Array[BattleCardInstance] = [BattleCardInstance.new(101,"move_165",4),BattleCardInstance.new(102,"guard",0)]
    var battle := TacticalBattle.new()
    battle.start_with(party,cards,route.opponents(0),42,"field_kit")
    battle.full_type_chart = true
    var view: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    view.battle = battle
    view.run_mode = true
    var biome: Dictionary = catalog.biomes.filter(func(entry: Dictionary): return entry["type"] == trainer["type"])[0]
    view.run_biome = biome
    view.run_background = BattleBackdrops.for_stop(stop,biome)
    view.opponent_trainer = TrainerDialogue.opponent(stop,biome)
    view.run_title = TrainerDialogue.title(view.opponent_trainer)
    root.add_child(view)
    if role == "elite":
        view.get_node("StageTitle").text = catalog.type_name(trainer["type"])+" 배틀 룸"
        view.get_node("StageTitle").add_theme_font_size_override("font_size",18)
    return view
func shot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(gallery.path_join(name_text+".png")) == OK,"Native capture: "+name_text)
func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("This probe requires actual rendered pixels")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(gallery)
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    Input.warp_mouse(Vector2(960,50))
    var keys: Array[String] = []
    for key: String in TrainerSprites.manifest()["entries"]:
        var e: Dictionary = TrainerSprites.manifest()["entries"][key]
        if e.get("status","") == "included" and TrainerSprites.manifest()["assets"][e["path"]].get("kind","") == "fan" and not TrainerSprites.manifest()["assets"][e["path"]].has("source_repository"): keys.append(key)
    check(keys.size() == 14,"All fourteen new trainer identities are exercised")
    var index := 0
    for key: String in keys:
        root.get_node("Preferences").battle_speed = [1.0,1.5,2.0][index % 3]
        index += 1
        var view := boss(key)
        var before := view.battle.snapshot()
        for tick in 500:
            if view.trainer_speech.visible: break
            await create_timer(0.01).timeout
        await create_timer(0.27).timeout
        var intro := view.trainer_intro
        check(view.busy and intro.visible and intro.portrait != null,"Real encounter uses own downloaded portrait: "+key)
        check(view.trainer_speech.quote.text == TrainerDialogue.line(view.opponent_trainer,"intro"),"Dialogue still matches identity")
        check(view.end_button.disabled and view.stage.canvas.target_factor == 0,"Pokemon and battle input wait for the throw")
        var rect := intro.portrait_rect()
        check(absf(rect.end.y-intro.trainer_foot().y) <= 1,"Opaque feet meet measured floor: "+key)
        check(rect.end.x <= 1630 and rect.position.x >= 1344,"Portrait clears roster and dialogue: "+key)
        var zoom := rect.size/intro.portrait_bounds.size
        check(zoom.x == floor(zoom.x) and zoom.x == zoom.y and intro.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"Unmodified pixels render at an integer nearest scale")
        check(Rect2(intro.portrait.get_image().get_used_rect()) == intro.portrait_bounds,"Actual alpha bounds match source metadata")
        await shot(key.replace(":","-")+"-intro")
        for tick in 500:
            if intro.projectile and intro.throw_progress > 0: break
            await create_timer(0.01).timeout
        check(intro.pose == "throw" and intro.projectile and intro.throw_progress > 0 and intro.throw_progress < 1,"Original ball flight remains timed: "+key)
        check(view.battle.snapshot() == before,"Introduction preserves cards, energy, HP and RNG")
        if key in ["gym:korrina","gym:valerie","elite:acerola"]: await shot(key.replace(":","-")+"-throw")
        view.finish_presentation()
        check(not view.busy and not intro.visible and view.stage.canvas.target_factor == 1,"Completing playback restores battle")
        view.free()
    root.get_node("GameAudio").stop_all()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.2).timeout
    print("FAN_TRAINER_NATIVE: ",checks," checks, ",failures," failures; ",keys.size()," identities; 17 captures")
    quit(0 if failures == 0 else 1)
