extends SceneTree
const PokemonMotion := preload("res://scripts/content/pokemon_animation.gd")
const W := preload("res://scripts/ui/combat_widgets.gd")
var checks := 0
var failures := 0
var folder := "/tmp/pokemon-animation-review"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func shot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN; root.position=Vector2i.ZERO; root.size=Vector2i(1920,1080)
    var manifest := PokemonMotion.data()
    check(manifest["views"].size()==2824,"All 1412 front/back views have a record")
    var geometry_ok := true
    for entry: Dictionary in PokedexExpansion.data()["pokemon"]:
        for back: bool in [false,true]:
            var view := PokemonMotion.entry(int(entry["id"]),back)
            if not view.has("sheet") or not view.has("frames") or view["frames"].size()<2:
                geometry_ok=false; continue
            var sheet: Dictionary = manifest["sheets"][view["sheet"]]
            for frame: Array in view["frames"]:
                geometry_ok = geometry_ok and frame[0]>=0 and frame[1]>=0 and frame[2]==view["width"] and frame[3]==view["height"] and frame[4]>0
                geometry_ok = geometry_ok and frame[0]+frame[2]<=sheet["sheet_size"][0] and frame[1]+frame[3]<=sheet["sheet_size"][1]
    check(geometry_ok,"Every animation has complete positive timing and bounded fixed-size frames")
    for pair: Array in [[10080,7],[10081,3],[10082,6],[10083,5],[10084,4],[10085,2],[10094,8],[10148,14],[10160,15]]:
        var view := PokemonMotion.entry(pair[0]); var source: Dictionary = manifest["sheets"][view["sheet"]]
        check(source["source_path"]=="Graphics/Pokemon/Front/PIKACHU_%d.png"%pair[1],"Visually audited costume/cap "+str(pair[0]))
    var alola := PokemonMotion.entry(10149)
    check(manifest["sheets"][alola["sheet"]]["source_path"].ends_with("MAROWAK_1.png"),"Totem Alolan Marowak cannot use Kanto art")
    check(PokemonMotion.entry(10027)["sheet"]!=PokemonMotion.entry(10029)["sheet"],"Pumpkaboo sizes retain distinct source animations")
    check(PokemonMotion.entry(710)["sheet"]!=PokemonMotion.entry(10027)["sheet"],"Average and small Pumpkaboo are distinct")
    var session := root.get_node("BattleSession")
    var starters: Array[int] = [1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated expedition")
    var j: TacticalJourney = session.journey
    var original := JourneySnapshot.encode(j)
    var saved := FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j; root.add_child(ui); current_scene=ui
    await create_timer(.5).timeout
    var canvas := ui.battle_ui.stage.canvas
    var source: Node = canvas.source_sprite.get_node("PokemonAnimation")
    var target: Node = canvas.target_sprite.get_node("PokemonAnimation")
    check(source.back_view and not target.back_view,"Ally back / enemy front, Pokemon only")
    var index: int = source.frame_index
    await shot("01-battle")
    await create_timer(.34).timeout
    check(source.frame_index!=index,"Visible ally animation advances in the real window")
    await shot("02-battle-later")
    var stable := canvas.sprite_rect(true)
    var anchor := canvas.foot_anchor(true)
    source.set_process(false)
    source.advance(float(source.frames[source.frame_index][4])+.001)
    check(canvas.sprite_rect(true)==stable and canvas.foot_anchor(true)==anchor,"Frame updates keep stable ground bounds and HUD layout")
    var sprite_texture := canvas.source_sprite.texture
    var frame_index: int = source.frame_index
    canvas.set_species(canvas.source_species,canvas.target_species,VisualCatalog.new(),false)
    check(canvas.source_sprite.texture==sprite_texture and source.frame_index==frame_index,"UI refresh never resets the current animation")
    canvas.source_sprite.hide(); var time_before: float = source.elapsed
    source.set_process(true); await create_timer(.15).timeout
    check(source.elapsed==time_before,"Hidden Pokemon stops frame processing")
    canvas.source_sprite.show()
    check(JourneySnapshot.encode(j)==original and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"PokemonMotion leaves actual saved run/UID/RNG and save bytes unchanged")
    var restored := JourneySnapshot.restore(original)
    check(JourneySnapshot.validate(original) and JourneySnapshot.encode(restored)==original,"Exact save restore with animation enabled")
    ui.hide()
    var gallery := Control.new(); root.add_child(gallery); gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    W.panel(gallery,Rect2(0,0,1920,1080),Color("14282f"))
    W.label(gallery,"2D 애니메이션 · 의상 / 지역폼 / 최신 포켓몬",Rect2(40,12,1800,44),28)
    var samples := [10080,10081,10082,10083,10084,10085,10094,10160,10149,10091,10233,10250,10251,10252,10273,10275,650,652,655,658,905,906,909,912,936,937,979,990,993,1007,1008,1025,30346,30347,30348,30349,30350,30351,30352,30353,30450,30459,30468,30477,30486,30495,10027,10029]
    var portraits: Array[TextureRect] = []
    for i in samples.size():
        var id: int = samples[i]; var pos := Vector2(38+(i%8)*235,72+floori(i/8.0)*164)
        W.panel(gallery,Rect2(pos,Vector2(224,154)),Color("20343a"))
        var sprite := W.sprite(gallery,id,Rect2(pos+Vector2(6,4),Vector2(212,110)))
        portraits.append(sprite)
        check(Rect2(pos+Vector2(6,4),Vector2(212,110)).encloses(sprite.get_rect()),"Fitted animated portrait "+str(id))
        W.label(gallery,VisualCatalog.new().species(id)["name"],Rect2(pos+Vector2(4,118),Vector2(216,30)),15,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    await create_timer(.35).timeout
    await shot("03-forms-and-latest")
    # Every displayed frame changes its real pixels, not a fake clock or a moving whole image.
    var changed := 0
    for portrait: TextureRect in portraits:
        var player := portrait.get_node("PokemonAnimation")
        player.set_process(false)
        var before := portrait.texture.get_image().get_data()
        for i in player.frames.size():
            player.advance(float(player.frames[player.frame_index][4])+.00001)
            if portrait.texture.get_image().get_data()!=before: changed+=1; break
    check(changed==portraits.size(),"Every representative has genuinely different decoded frames")
    await shot("04-forms-later")
    check(PokemonMotion._bytes<=PokemonMotion.CACHE_BYTES,"Strong texture cache stays within 32 MiB")
    check(JourneySnapshot.encode(j)==original and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Gallery/asset loading also leaves saved gameplay untouched")
    # Large battle species and form changes use the same binding path as switches/transformation.
    gallery.hide(); ui.show()
    for pair: Array in [[6,10149],[1007,1025],[10029,10032]]:
        canvas.set_species(pair[0],pair[1],VisualCatalog.new(),false)
        check(canvas.source_sprite.get_node("PokemonAnimation").species_id==pair[0] and canvas.target_sprite.get_node("PokemonAnimation").species_id==pair[1],"Species switch rebinds correct front/back textures")
        await create_timer(.1).timeout
        check(canvas.sprite_rect(true).position.y>=132 and canvas.sprite_rect(false).position.y>=132,"Animated union clears the top HUD")
    canvas.set_species(j.battle.active().species_id,j.battle.enemy().species_id,VisualCatalog.new(),false)
    check(JourneySnapshot.encode(j)==original,"Visual switch probes cannot change battle state")
    gallery.queue_free(); ui.queue_free(); await process_frame
    print("POKEMON_ANIMATION_NATIVE ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
