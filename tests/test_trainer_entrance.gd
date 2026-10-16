extends SceneTree
var native := false
var checks := 0
var failures := 0
var ui: TacticalJourneyUI
var output := "/tmp/pokemon-trainer-entrance"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func wait_kind(view: TacticalUI,kind: String) -> void:
    for i in 250:
        if kind in view.playback_kinds: return
        await create_timer(0.01).timeout
    check(false,"Trainer entrance reaches "+kind)
func picture(name_text: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(name_text+".png")) == OK,"Save trainer sequence inspection capture")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.step = 10
    j.phase = TacticalJourney.MAP
    check(j.enter_next().is_empty(),"Enter an actual regional trainer battle")
    var before := JourneySnapshot.encode(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    var view := ui.battle_ui
    check(view.busy and view.trainer_intro.visible and view.stage.canvas.target_factor == 0,"Trainer appears before the first opponent Pokemon")
    check(view.end_button.disabled and view.trainer_buttons.values().all(func(card: Button): return card.disabled),"Battle controls remain locked throughout the entrance")
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        print("OS_KEY q")
        await create_timer(0.1).timeout
    else:
        var key := InputEventKey.new()
        key.keycode = KEY_Q
        key.pressed = true
        root.push_input(key)
    check(JourneySnapshot.encode(j) == before,"Input during the entrance cannot spend energy, play cards or change RNG")
    await picture("trainer-arrival")
    await wait_kind(view,"trainer_windup")
    check(view.trainer_intro.pose == "windup" and view.stage.canvas.target_factor == 0,"Throwing arm winds up while the Pokemon remains hidden")
    await wait_kind(view,"trainer_throw")
    await create_timer(0.12).timeout
    check(view.trainer_intro.projectile and view.trainer_intro.throw_progress > 0 and view.trainer_intro.throw_progress < 1,"Ball visibly travels along its throwing arc")
    await picture("trainer-throw")
    await wait_kind(view,"trainer_release")
    check(view.motion.mode == "release" and view.motion.ball_already_landed and view.busy,"Pokemon opens the landed ball without a second throw and still blocks input")
    for i in 250:
        if not view.busy: break
        await create_timer(0.01).timeout
    check(not view.busy and not view.trainer_intro.visible and view.stage.canvas.target_factor == 1,"Entrance completes with normal battle controls and Pokemon visibility")
    check(JourneySnapshot.encode(j) == before,"Timed trainer sequence leaves the exact campaign state unchanged")
    await picture("grounded-battle")
    ui.refresh()
    await process_frame
    check(not ui.battle_ui.busy and ui.battle_ui.trainer_intro == null,"Refreshing the same battle does not replay the entrance")
    var canvas := ui.battle_ui.stage.canvas
    check(canvas.source_anchor.y == 477 and canvas.target_anchor.y == 400,"Ally occupies the lower foreground and opponent the upper background")
    for id in [1,6,25,93,130,143,201,249,321,386]:
        canvas.set_species(id,id,VisualCatalog.new())
        canvas._process(0)
        ui.battle_ui._position_intent()
        var enemy_bounds := canvas.sprite_bounds(canvas.target_sprite.texture)
        var enemy_rect := Rect2(canvas.foot_anchor(false)-Vector2(enemy_bounds.size.x*canvas.sprite_zoom/2,enemy_bounds.size.y*canvas.sprite_zoom),Vector2(enemy_bounds.size)*canvas.sprite_zoom)
        check(not ui.battle_ui.get_node("Intent").get_rect().intersects(enemy_rect),"Enemy intent does not cover the visible Pokemon for species %d" % id)
        for ally in [true,false]:
            var sprite := canvas.source_sprite if ally else canvas.target_sprite
            var bounds := canvas.sprite_bounds(sprite.texture)
            var feet := sprite.position+(Vector2(bounds.position.x+bounds.size.x/2.0,bounds.end.y)-sprite.texture.get_size()/2)*canvas.sprite_zoom
            check(feet.distance_to(canvas.foot_anchor(ally)) <= 1,"Opaque sprite feet meet the shadow anchor for species %d" % id)
        var position := canvas.source_sprite.position
        canvas._process(5)
        check(canvas.source_sprite.position == position,"Idle sprites no longer bob away from their contact shadow")
    for role in ["trainer","veteran","gym","elite","champion"]:
        var probe := TacticalUI.new()
        probe.battle = TacticalBattle.new()
        probe.opponent_trainer = {"name":"도전자","kind":role,"type":"fire"}
        root.add_child(probe)
        await process_frame
        check(probe.busy and probe.trainer_intro.role == role,"Entrance supports every trainer encounter role")
        probe.finish_presentation()
        check(not probe.busy and probe.stage.canvas.target_factor == 1,"Finishing the real playback tween restores input and Pokemon")
        probe.free()
    var wild := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    ui.journey = wild
    ui.refresh()
    await process_frame
    check(ui.battle_ui.trainer_intro == null and not ui.battle_ui.busy,"Wild encounters skip the trainer entrance")
    ui.free()
    print("TRAINER_ENTRANCE native=",native,": ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
