extends SceneTree
const FOLDER := "/tmp/pokemon-combat-motion"
var checks := 0
var failures := 0
var view: TacticalUI
var ally_peak := 0.0
var enemy_peak := 0.0
var recording := -1
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func observe() -> void:
    if not is_instance_valid(view):return
    ally_peak=maxf(ally_peak,absf(view.stage.canvas.source_motion.x))
    enemy_peak=maxf(enemy_peak,absf(view.stage.canvas.target_motion.x))
func key(symbol: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    await create_timer(.3).timeout
    await process_frame
    await process_frame
func wait_idle() -> void:
    for i in 150:
        if not view.busy:break
        await create_timer(.08).timeout
    check(not view.busy,"Natural playback finishes and unlocks input")
func settled(canvas: BattleCanvas) -> bool:
    return canvas.source_motion.is_zero_approx() and canvas.target_motion.is_zero_approx() and canvas.source_stretch.is_equal_approx(Vector2.ONE) and canvas.target_stretch.is_equal_approx(Vector2.ONE) and is_zero_approx(canvas.source_lean) and is_zero_approx(canvas.target_lean)
func shot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(FOLDER.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(FOLDER)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var prefs:=root.get_node("Preferences")
    prefs.set_battle_speed(1);prefs.set_hit_motion(true)
    var session:=root.get_node("BattleSession")
    var starters: Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated expedition")
    var actual: TacticalJourney=session.journey
    var baseline:=JourneySnapshot.encode(actual)
    var saved:=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var j:=TutorialLesson.battle_practice()
    j.deck[0].key="move_10"
    var before:=JourneySnapshot.encode(j)
    var expected:=JourneySnapshot.restore(before)
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    view=ui.battle_ui
    process_frame.connect(observe)
    var canvas:=view.stage.canvas
    var anchor_a:=canvas.foot_anchor(true)
    var anchor_b:=canvas.foot_anchor(false)
    var profiles: Array[Dictionary]=[
        {"category":"physical","vfx":{"primary":"impact"}},
        {"category":"2","vfx":{"primary":"slash"}},
        {"category":"special","vfx":{"primary":"projectile"}},
        {"category":"3","vfx":{"primary":"charge"}},
        {"category":"status","vfx":{"primary":"shield"}},
        {"category":"1","vfx":{"primary":"heal"}},
        {"category":"status","vfx":{"primary":"stat_up"}}]
    var names: Array[String]=["strike","slash","cast","charge","guard","heal","support"]
    var reference_pose := Vector2.ZERO
    seed(613);var expected_random:=randi();seed(613)
    for enemy: bool in [false,true]:
        for i in profiles.size():
            view.motion.use_move(enemy,profiles[i])
            var t: Tween=canvas.get_meta(UiMotion.META)["target_motion" if enemy else "source_motion"]
            t.pause();t.custom_step(.20)
            canvas._process(0)
            var displacement:=canvas.target_motion if enemy else canvas.source_motion
            var stretch:=canvas.target_stretch if enemy else canvas.source_stretch
            if not enemy and i==0:reference_pose=displacement
            var sprite:=canvas.target_sprite if enemy else canvas.source_sprite
            var bounds:=canvas.sprite_bounds(sprite.texture)
            var foot:=Vector2(bounds.position.x+bounds.size.x/2.0,bounds.end.y)-sprite.texture.get_size()/2
            check(view.motion.last_profile==names[i] and displacement.length()>1 and not stretch.is_equal_approx(Vector2.ONE),"Distinct full-body pose: "+names[i]+(" enemy" if enemy else " ally"))
            check((sprite.transform*foot).distance_to(canvas.foot_anchor(not enemy)+displacement)<1.5,"Pose remains pivoted at anatomical foot, "+names[i])
            if not enemy and i in [0,2,5]:await shot("pose-"+names[i])
            t.custom_step(2);canvas._process(0)
            check(settled(canvas),"Motion returns exactly to its original pose, "+names[i])
    check(randi()==expected_random and JourneySnapshot.encode(j)==before,"All pose profiles leave global RNG and campaign snapshot untouched")
    check(canvas.foot_anchor(true)==anchor_a and canvas.foot_anchor(false)==anchor_b,"Motions preserve backdrop layout and stable foot anchors")
    for speed: float in [1.5,2.0]:
        prefs.set_battle_speed(speed);view.motion.use_move(false,profiles[0])
        var t: Tween=canvas.get_meta(UiMotion.META)["source_motion"]
        t.pause();t.custom_step(.2/speed)
        check(canvas.source_motion.is_equal_approx(reference_pose),"Same pose reached proportionally faster at battle speed "+str(speed))
        view.motion.reset()
    prefs.set_battle_speed(1)
    view.motion.use_move(false,profiles[3])
    var interrupted: Tween=canvas.get_meta(UiMotion.META)["source_motion"]
    interrupted.pause();interrupted.custom_step(.1)
    view.motion.hit(true);UiMotion.finish_tree(canvas)
    check(settled(canvas) and canvas.position.is_zero_approx(),"Hit interruption clears pose and shake")
    prefs.set_hit_motion(false);view.motion.hit(true)
    check(canvas.position.is_zero_approx() and settled(canvas),"Hit-motion off keeps screen and defender steady")
    view.motion.use_move(false,profiles[0]);UiMotion.finish_tree(canvas)
    check(settled(canvas),"Attack playback still completes with hit shake off")
    prefs.set_hit_motion(true)
    view.motion.use_move(true,profiles[1]);view.motion.reset()
    check(settled(canvas) and canvas.source_factor==1 and canvas.target_factor==1,"Restart cleanup restores both sides and summon factors")
    if OS.get_environment("MOTION_RECORD")=="1":
        recording=OS.create_process("/usr/bin/ffmpeg",PackedStringArray(["-y","-loglevel","error","-nostats","-f","x11grab","-framerate","30","-video_size","1920x1080","-i",OS.get_environment("DISPLAY"),"-t","14","-an","-c:v","libx264","-preset","ultrafast","-crf","25","-pix_fmt","yuv420p",FOLDER.path_join("motion-preview.mp4")]))
        await create_timer(.5).timeout
        for i in profiles.size():
            view.motion.use_move(i%2==1,profiles[i])
            await create_timer(.7).timeout
    view.motion.reset()
    check(JourneySnapshot.encode(j)==before,"Visual demonstration changes no battle state")
    check(expected.battle.play_card(TutorialLesson.FIRST_CARD).is_empty(),"Reference physical card resolves")
    ally_peak=0
    await key("q");await wait_idle()
    check(ally_peak>25 and view.motion.last_profile in ["strike","slash"],"Actual hand shortcut plays visible physical motion")
    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(expected) and settled(canvas),"Natural player presentation matches reference result/RNG and settles")
    expected.battle.end_turn()
    enemy_peak=0
    await key("Return");await wait_idle()
    check(enemy_peak>25,"Actual end-turn action animates enemy attacker")
    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(expected) and settled(canvas),"Natural enemy presentation matches reference result/RNG and settles")
    var action_before:=JourneySnapshot.encode(j)
    view._play_event({"kind":"enemy_action","action":"move","move_id":55,"text":"연출 확인","frame":BattleFrame.capture(j.battle)})
    check(view.motion.last_profile=="cast","Enemy move action uses casting motion, not only legacy attack kinds")
    UiMotion.finish_tree(canvas);view.motion.reset()
    check(JourneySnapshot.encode(j)==action_before,"Enemy move visual probe is state neutral")
    check(JourneySnapshot.encode(actual)==baseline and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Actual saved run, UID/RNG and bytes unchanged")
    await create_timer(.5).timeout
    if recording>0 and OS.is_process_running(recording):
        OS.execute("/bin/kill",PackedStringArray(["-INT",str(recording)]))
        for i in 30:
            if not OS.is_process_running(recording):break
            await create_timer(.05).timeout
    ui.queue_free();await process_frame
    for name_text: String in ["GameMusic","GameAmbience","GameCries","GameAudio"]:
        var node:=root.get_node(name_text)
        if name_text=="GameMusic":node.stop_music()
        elif name_text=="GameAmbience":node.stop_ambience()
        else:node.stop_all()
    await create_timer(.3).timeout
    print("COMBAT_MOTION: ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
