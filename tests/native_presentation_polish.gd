extends SceneTree
const OUT := "/tmp/pokemon-presentation-polish"
const W = preload("res://scripts/ui/combat_widgets.gd")
var checks := 0
var failures := 0
var keys := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1;push_error(message)
func wait_ui() -> void:
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol);keys += 1
    await wait_ui()
func shot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUT.path_join(name_text))==OK,"Screenshot "+name_text)
func run() -> void:
    if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().begins_with(OUT): quit(2);return
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    if OS.get_environment("POLISH_CAPTURE_ONLY")=="1":
        await capture_probe()
        return
    var gallery := Control.new()
    gallery.theme=Theme.new();gallery.theme.default_font=load("res://assets/fonts/NotoSansKR.ttf")
    root.add_child(gallery);current_scene=gallery
    var background := ColorRect.new();background.color=Color("102329");background.size=Vector2(1920,1080);gallery.add_child(background)
    W.label(gallery,"원작 일반 트레이너 12종 · 아이템 크기 정리",Rect2(72,40,1750,80),32,W.GOLD)
    var factory := TacticalJourneyUI.new()
    var holder := Control.new();gallery.add_child(holder);holder.hide()
    var count := 0
    for file: String in DirAccess.get_files_at("res://assets/items"):
        if not file.ends_with(".png"): continue
        var icon := factory._item_sprite(holder,file.trim_suffix(".png"),Rect2(10,20,54,54))
        check(icon.size==Vector2(54,54) and icon.position==Vector2(10,20),"Item rect fits requested 54px: "+file)
        count += 1
    check(count>=112,"All differently sized original item PNGs checked")
    factory.page.free();factory.free()
    var canvas := BattleCanvas.new();canvas.canvas_size=Vector2(1920,1080);gallery.add_child(canvas);canvas.hide()
    var pool := TrainerSprites.regular()
    check(pool.size()>=10,"At least ten original trainer portraits available")
    var unique := {}
    for i in pool.size():
        var definition := {"kind":"trainer","name":"훈련가","sprite_seed":i}
        var entry := TrainerSprites.entry(definition)
        unique[entry["path"]]=true
        check(entry==TrainerSprites.entry(definition),"Portrait stays stable within encounter")
        var entrance := TrainerEntrance.new();entrance.canvas=canvas;entrance.slide=0;entrance.set_trainer(definition)
        check(entrance.portrait!=null and entrance.portrait_bounds.size.x>0,"Canonical portrait and opaque bounds load")
        check(entrance.portrait_extent().x<=260 and entrance.portrait_extent().y<=260,"Canonical portrait fits entrance area")
        entrance.position=Vector2(210+(i%6)*300,450+(i/6)*350)-entrance.trainer_foot()
        gallery.add_child(entrance)
        W.label(gallery,entry["name"],Rect2(72+(i%6)*300,464+(i/6)*350,276,40),18,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    check(unique.size()==pool.size(),"The reusable pool includes distinct sprites")
    var boss := {"kind":"gym","id":"brock"}
    check(TrainerSprites.entry(boss)==TrainerSprites.manifest()["entries"]["gym:brock"],"Dedicated boss sprite mapping unchanged")
    var sample_factory := TacticalJourneyUI.new()
    for i in 6:
        var name_text: String=["ball","clear-amulet","unremarkable_teacup","galarica_wreath","peat_block","syrupy_apple"][i]
        sample_factory._item_sprite(gallery,name_text,Rect2(102+i*300,930,54,54))
        W.label(gallery,name_text,Rect2(172+i*300,930,200,54),16)
    sample_factory.page.free();sample_factory.free()
    await wait_ui();await shot("01-trainers-and-items.png")
    gallery.free();current_scene=null
    await capture_probe()

func capture_probe() -> void:
    # Run only this range after a capture-specific fix, without repeating 112 items/12 portraits.
    for i in 2:
        var factory := TacticalJourneyUI.new()
        check(factory.page.get_parent()==null,"Unattached fixture page must be freed explicitly")
        factory.page.free();factory.free()
    var session := root.get_node("BattleSession")
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    check(j.is_wild(),"Capture uses ordinary wild encounter fixture")
    j.battle.enemy().hp=maxi(1,j.battle.enemy().max_hp/4)
    check(j.capture_reason().is_empty(),"Existing capture conditions are satisfied")
    session.adopt_journey(j)
    var before := JourneySnapshot.encode(j)
    var reference := JourneySnapshot.restore(before)
    check(reference.capture().is_empty(),"Reference public capture resolves")
    var expected := JourneySnapshot.encode(reference)
    var screen: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    screen.journey=j;root.add_child(screen);current_scene=screen
    await wait_ui()
    var ui := screen.battle_ui
    await key("c")
    var animation=ui.motion.capture_animation
    check(ui.busy and animation.active and "capture_motion" in ui.playback_kinds,"Actual C key starts capture presentation")
    check(not ui.notice.text.contains("포획 성공"),"Success notice waits until the capture animation finishes")
    if not animation.active: quit(1);return
    ui._sequence.pause()
    animation.get_meta(UiMotion.META)["capture"].pause()
    var saved := FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    check(JourneySnapshot.encode(j)==expected,"Presentation preserves exact reference capture/RNG/costs")
    await key("c")
    check(JourneySnapshot.encode(j)==expected,"Busy capture blocks duplicate capture input")
    animation.seek(.26)
    check(animation.phase_name=="throw" and ui.stage.canvas.target_factor==1,"Ball follows flight before Pokemon shrinks")
    await wait_ui();await shot("02-capture-flight.png")
    animation.seek(.82)
    check(animation.phase_name=="absorb" and ui.stage.canvas.target_factor>0 and ui.stage.canvas.target_factor<1,"Hit Pokemon shrinks and is pulled into ball")
    await wait_ui();await shot("03-capture-absorb.png")
    animation.seek(1.4)
    check(animation.phase_name=="drop" and ui.stage.canvas.target_factor==0 and animation.ball_position.y<animation.ground.y,"Closed ball drops to ground with Pokemon hidden")
    for i in 3:
        animation.seek(animation.SHAKE_STARTS[i]+.085)
        check(animation.phase_name=="shake_%d"%(i+1) and absf(animation.ball_angle)>.2,"Grounded shake %d"%(i+1))
    await wait_ui();await shot("04-capture-shake.png")
    animation.seek(3.65)
    check(animation.phase_name=="success" and animation.completed_shakes==3 and animation.ball_position==animation.ground,"Exactly three shakes before successful lock")
    await wait_ui();await shot("05-capture-success.png")
    check(JourneySnapshot.encode(j)==expected and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"All visual phases leave exact state/save/RNG untouched")
    ui.finish_presentation();await wait_ui()
    check(not ui.busy and not animation.active and ui.stage.canvas.target_factor==0,"Presentation completes without Pokemon or lingering ball reappearing")
    check(ui.result.visible and "capture" in ui.playback_kinds,"Success result appears only after capture sequence")
    check(ui.notice.text.contains("포획 성공"),"Deferred capture notice appears after three shakes and completion")
    var restored: TacticalJourney = session.save_store.load_journey()
    check(restored!=null and JourneySnapshot.encode(restored)==expected,"Actual post-capture saved run restores exactly")
    ui.motion.capture();animation.seek(.82);ui.motion.reset()
    check(not animation.active and ui.stage.canvas.target_factor==1 and ui.stage.canvas.target_motion==Vector2.ZERO,"Interrupted capture reset clears tint/position/size")
    check(JourneySnapshot.encode(j)==expected,"Reset is presentation only")
    screen.free();current_scene=null
    for node_name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(node_name).stop_all()
    await wait_ui()
    print("PRESENTATION_POLISH ",checks," checks / ",failures," failures / ",keys," OS keys")
    quit(0 if failures==0 else 1)
