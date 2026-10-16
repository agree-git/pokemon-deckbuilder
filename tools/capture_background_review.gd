extends SceneTree
## Actual 1920x1080 journey UI renders, using isolated deterministic review fixtures.
## Does not adopt/checkpoint a journey or alter the player's run/collection.
var output := ""
var catalog := VisualCatalog.new()
var captures: Array[Dictionary] = []
var failures := 0
const GROUP_NAMES := {"biomes":"바이옴 18곳","elite":"사천왕 전체 후보 31명","champions":"챔피언 전체 후보 11명","reserve":"예비 실내 룸 5개"}
func _initialize() -> void: call_deferred("run")
func biome_for(type: String) -> Dictionary:
    for biome: Dictionary in catalog.biomes:
        if biome["type"] == type: return biome
    return catalog.biomes[0]
func scene_entry(group: String,key: String,title: String,kind: String,biome: Dictionary,trainer: Dictionary = {}) -> Dictionary:
    var ids: Array = trainer.get("party",[int(biome["encounters"][0]["pokemon_id"])])
    var level := 20 if kind == "wild" else (100 if kind == "champion" else 94)
    var stop := {"name":title,"kind":kind,"icon":biome["type"],"chapter":0 if kind == "wild" else 8,"biome":biome.duplicate(true),"party":ids.duplicate(),"trainer":trainer.duplicate(true),"league_index":4 if kind == "champion" else 0,"battle_index":0 if kind == "wild" else (68 if kind == "champion" else 64),"level":level}
    return {"category":group,"key":key,"title":title,"type":biome["type"],"region":trainer.get("region",""),"active":group != "reserve","stop":stop}
func entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for biome: Dictionary in catalog.biomes:
        result.append(scene_entry("biomes",biome["type"],catalog.type_name(biome["type"])+" · "+biome["name"],"wild",biome))
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var used_types: Array[String] = []
    for trainer: Dictionary in league["elite"]:
        var type: String = trainer["type"]
        if type not in used_types: used_types.append(type)
        result.append(scene_entry("elite",trainer["id"],trainer["region"]+" · "+trainer["name"]+" / "+catalog.type_name(type),"elite",biome_for(type),trainer))
    for trainer: Dictionary in league["champions"]:
        result.append(scene_entry("champions",trainer["id"],trainer["region"]+" · "+trainer["name"],"champion",biome_for(trainer["type"]),trainer))
    for type: String in BattleBackdrops.data()["elite"]:
        if type in used_types: continue
        var gym := catalog.gym_for_type(type)
        var trainer := {"id":"review_"+type,"name":"예비 "+catalog.type_name(type)+" 룸","type":type,"region":"예비","party":gym["party"].slice(0,5)}
        result.append(scene_entry("reserve","elite_"+type,trainer["name"],"elite",biome_for(type),trainer))
    var fallback: Dictionary = league["champions"][0].duplicate(true)
    fallback.merge({"id":"review_fallback","name":"공용 리그 홀","region":"공용"},true)
    result.append(scene_entry("reserve","champion_fallback","공용 리그 홀","champion",biome_for("normal"),fallback))
    return result
func fixture(entry: Dictionary) -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.party.clear()
    var species := [2,5,8] if entry["category"] == "biomes" else [3,6,9]
    var level := 20 if entry["category"] == "biomes" else (100 if entry["stop"]["kind"] == "champion" else 95)
    for id: int in species:
        var definition := TacticalContent.member_definition(id,catalog)
        definition["level"] = level
        var p := BattlePokemon.new(definition,id)
        TacticalGrowth.initialize(p)
        p.hp = p.max_hp
        j.party.append(p)
    j.deck.assign(TacticalContent.starting_deck(j.party))
    j.route.stops[0] = entry["stop"].duplicate(true)
    j.badges = 0 if entry["category"] == "biomes" else 8
    j.elite_wins = 4 if entry["stop"]["kind"] == "champion" else 0
    j.phase = TacticalJourney.MAP
    var error := j.enter_next()
    if not error.is_empty():
        push_error(error)
        failures += 1
    return j
func capture(entry: Dictionary) -> void:
    var j := fixture(entry)
    var before := JourneySnapshot.encode(j)
    var ui := TacticalJourneyUI.new()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
    await process_frame
    # Keep the cursor away from cards: every shot shows the same settled state.
    for card: TrainerActionCard in ui.battle_ui.trainer_buttons.values(): card._set_hover(false)
    UiMotion.finish_tree(ui)
    await process_frame
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    var relative: String = "screens/"+entry["category"]+"/"+entry["key"]+".png"
    DirAccess.make_dir_recursive_absolute(output.path_join(relative.get_base_dir()))
    if picture.get_size() != Vector2i(1920,1080) or picture.save_png(output.path_join(relative)) != OK:
        push_error("Cannot save a 1920x1080 capture: "+relative)
        failures += 1
    if JourneySnapshot.encode(j) != before:
        push_error("Rendering changed the review fixture: "+relative)
        failures += 1
    var descriptor := BattleBackdrops.for_stop(j.current(),j.biome())
    if ui.battle_ui.run_background != descriptor or ui.battle_ui.busy:
        push_error("Wrong background or unfinished entrance: "+relative)
        failures += 1
    var row := entry.duplicate(true)
    row.erase("stop")
    row["file"] = relative
    row["background"] = descriptor["background"]
    row["cell"] = descriptor["cell"]
    row["sha256"] = FileAccess.get_sha256(output.path_join(relative))
    row["resolution"] = [1920,1080]
    row["party"] = j.party.map(func(p: BattlePokemon): return p.species_id)
    row["opponents"] = j.battle.enemies.map(func(p: BattlePokemon): return p.species_id)
    captures.append(row)
    ui.free()
    print("BACKGROUND_CAPTURE ",captures.size()," ",relative)
func sheet(group: String) -> void:
    var rows := captures.filter(func(row: Dictionary): return row["category"] == group)
    var height := 120+ceili(rows.size()/3.0)*490
    root.size = Vector2i(2400,height)
    var page := Control.new()
    root.add_child(page)
    var fill := ColorRect.new()
    fill.color = Color("0b171d")
    fill.size = Vector2(2400,height)
    page.add_child(fill)
    var font := load("res://assets/fonts/NotoSansKR.ttf")
    var heading := Label.new()
    heading.position = Vector2(28,18)
    heading.text = GROUP_NAMES[group]+" · 실제 전투 화면"
    heading.add_theme_font_override("font",font)
    heading.add_theme_font_size_override("font_size",42)
    page.add_child(heading)
    for i in rows.size():
        var at := Vector2(28+(i%3)*790,110+floori(i/3.0)*490)
        var thumbnail := TextureRect.new()
        thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(output.path_join(rows[i]["file"])))
        thumbnail.position = at
        thumbnail.size = Vector2(768,432)
        thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        page.add_child(thumbnail)
        var caption := Label.new()
        caption.position = at+Vector2(0,437)
        caption.text = "%02d  %s" % [i+1,rows[i]["title"]]
        caption.add_theme_font_override("font",font)
        caption.add_theme_font_size_override("font_size",28)
        page.add_child(caption)
    await process_frame
    await RenderingServer.frame_post_draw
    var relative := "sheets/"+group+".png"
    if root.get_texture().get_image().save_png(output.path_join(relative)) != OK:
        failures += 1
        push_error("Cannot save contact sheet: "+relative)
    page.free()
func run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2 or args[0] != "--output" or DisplayServer.get_name() == "headless":
        printerr("Use graphical Godot with -- --output <new-empty-directory>")
        quit(2)
        return
    output = args[1]
    if DirAccess.dir_exists_absolute(output) and (not DirAccess.get_files_at(output).is_empty() or not DirAccess.get_directories_at(output).is_empty()):
        printerr("Output directory must be new or empty: ",output)
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(output.path_join("sheets"))
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    Input.warp_mouse(Vector2(1900,80))
    for entry: Dictionary in entries(): await capture(entry)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    for group: String in GROUP_NAMES: await sheet(group)
    var manifest := {"engine":Engine.get_version_info()["string"],"scene_mode":"isolated deterministic review fixtures, not campaign playthroughs","captures":captures,"failures":failures}
    var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
    if file == null:
        push_error("Cannot write review manifest")
        quit(1)
        return
    file.store_string(JSON.stringify(manifest,"  "))
    file.close()
    print("BACKGROUND_REVIEW ",captures.size()," captures, ",failures," failures, output=",output)
    quit(1 if failures else 0)
