extends "res://.dev-materials/tests/native_combat_motion.gd"
func run() -> void:
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var prefs:=root.get_node("Preferences")
    prefs.set_battle_speed(1);prefs.set_hit_motion(true)
    var j:=TutorialLesson.battle_practice();j.deck[0].key="move_10"
    var expected:=JourneySnapshot.restore(JourneySnapshot.encode(j))
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    view=ui.battle_ui;process_frame.connect(observe)
    expected.battle.play_card(TutorialLesson.FIRST_CARD)
    await key("q");await wait_idle()
    var left:=JourneySnapshot.encode(j);var right:=JourneySnapshot.encode(expected)
    var canvas:=view.stage.canvas
    check(left==right,"Actual player state/RNG matches reference")
    check(settled(canvas),"Player completion settles both body poses")
    await create_timer(.4).timeout
    check(settled(canvas),"Body remains settled after another .4 seconds")
    expected.battle.end_turn();enemy_peak=0
    Engine.max_fps=8;prefs.set_battle_speed(2)
    await key("Return");await wait_idle()
    check(enemy_peak>0 and settled(canvas),"Enemy animation settles under low FPS at double speed")
    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(expected),"Low-FPS enemy presentation preserves exact reference outcome/RNG")
    var before:=JourneySnapshot.encode(j)
    view.motion.use_move(false,{"category":"physical"})
    view.motion.use_move(true,{"category":"special"})
    for side: String in ["source_motion","target_motion"]:
        var t: Tween=canvas.get_meta(UiMotion.META)[side]
        t.pause();t.custom_step(.05)
    canvas.target_factor=0
    view._finished()
    check(settled(canvas) and canvas.target_factor==0,"Completion settles both poses while preserving faint invisibility")
    await create_timer(.4).timeout
    check(settled(canvas) and JourneySnapshot.encode(j)==before,"Canceled old tweens cannot restore stale offsets or change state")
    view.motion.reset()
    check(canvas.target_factor==1 and settled(canvas),"Explicit restart still restores faded sprite")
    Engine.max_fps=0
    ui.queue_free();await process_frame
    root.get_node("GameMusic").stop_music();root.get_node("GameAmbience").stop_ambience()
    root.get_node("GameCries").stop_all();root.get_node("GameAudio").stop_all()
    await create_timer(.2).timeout
    print("COMBAT_MOTION_FLOW: ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
