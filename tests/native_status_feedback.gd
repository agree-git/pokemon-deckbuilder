extends SceneTree
const FOLDER := "/tmp/pokemon-status-feedback"
var checks := 0
var failures := 0
var view: TacticalUI
var seen: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func observe() -> void:
    if not is_instance_valid(view):return
    for pulse: Dictionary in view.status_feedback.pulses:
        var key: String=pulse["kind"]
        if key not in seen:seen.append(key)
func only_original_numbers() -> bool:
    for number: Node in view.damage_layer.get_children():
        if number is RichTextLabel:
            for added: String in ["독", "화상", "마비", "피해", "상태이상"]:
                if number.text.contains(added):return false
    return true
func clear_feedback() -> void:
    view.status_feedback.clear()
    for number: Node in view.damage_layer.get_children():number.free()
func shot(name_text: String) -> void:
    view.status_feedback.set_process(false)
    view.status_feedback._process(.15)
    for sprite: Sprite2D in [view.stage.canvas.source_sprite,view.stage.canvas.target_sprite]:
        var tracks: Dictionary=sprite.get_meta(UiMotion.META,{})
        if tracks.has("status_flash") and tracks["status_flash"].is_valid():
            tracks["status_flash"].pause();tracks["status_flash"].custom_step(.15)
    for number: Node in view.damage_layer.get_children():
        var t: Tween=number.get_meta(UiMotion.META)["float"]
        t.pause();t.custom_step(.05)
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(FOLDER.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
    view.status_feedback.set_process(true)
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(FOLDER)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var prefs:=root.get_node("Preferences")
    prefs.set_battle_speed(1)
    var session:=root.get_node("BattleSession")
    var starters: Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated run starts")
    var actual: TacticalJourney=session.journey
    var baseline:=JourneySnapshot.encode(actual)
    var saved:=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var samples: Dictionary={}
    for key: String in ["poison","burn","seed","confusion"]:
        var probe:=TutorialLesson.battle_practice()
        var p:=probe.battle.active()
        p.statuses[key]={"turns":1,"source_uid":probe.battle.enemy().uid}
        var hp:=p.hp;var block:=p.block;var random_state:=probe.battle._rng.state
        var expected:=mini(hp,probe.battle.status_damage(p,key))
        var start:=BattleFrame.capture(probe.battle)
        probe.battle.events.clear();probe.battle._tick(p)
        var damage: Dictionary={}
        for event: Dictionary in probe.battle.events:
            if event["kind"]=="damage" and event.get("cause","")==key:damage=event
        check(not damage.is_empty() and damage["amount"]==expected,"Tick has exact structured cause and amount: "+key)
        check(p.hp==hp-expected and p.block==block and not p.statuses.has(key) and probe.battle._rng.state==random_state,"Final tick preserves damage, bypass, expiry and battle RNG: "+key)
        check(damage["text"]=="%s · 피해 %d"%[p.display_name,expected],"Battle record wording is unchanged: "+key)
        samples[key]={"before":start,"event":damage}
    var j:=TutorialLesson.battle_practice()
    var fixture_before:=JourneySnapshot.encode(j)
    var ui: TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    view=ui.battle_ui
    seed(845);var next_random:=randi();seed(845)
    for key: String in ["poison","burn"]:
        clear_feedback();view._apply_frame(samples[key]["before"])
        view._play_event(samples[key]["event"])
        check(only_original_numbers(),"Final tick adds only VFX and keeps numeric text unchanged: "+key)
        check(view.status_feedback.pulses.size()==1 and view.status_feedback.pulses[0]["kind"]==key,"Correct amplified particle/tint burst: "+key)
        await shot("01-poison" if key=="poison" else "02-burn")
    clear_feedback()
    var initial:=BattleFrame.capture(j.battle)
    var applied:=initial.duplicate(true)
    applied["party"][0]["statuses"]["paralysis"]={"turns":3,"source_uid":j.battle.enemy().uid}
    view._apply_frame(initial)
    view._play_event({"kind":"status","target":j.party[0].uid,"text":"파이리 · 마비","frame":applied})
    check(view.damage_layer.get_child_count()==0 and view.status_feedback.pulses[0]["kind"]=="paralysis","Application adds electric VFX without extra cause labels")
    var named_badge:=false
    for chip: Node in view.ally_statuses.get_children():
        for label: Node in chip.get_children():
            if label is Label and label.text=="3":named_badge=true
    check(named_badge,"Persistent status badge retains original counter wording")
    await shot("03-paralysis")
    clear_feedback();view._apply_frame(applied)
    view._play_event({"kind":"damage","target":j.party[0].uid,"amount":3,"blocked":0,"text":"일반 공격","frame":applied})
    check(only_original_numbers() and view.status_feedback.pulses.is_empty(),"Ordinary attack does not wrongly trigger status VFX")
    clear_feedback()
    view._play_event({"kind":"status_tick","target":j.party[0].uid,"text":"파이리 · 엉겨붙기","frame":applied})
    view._play_event({"kind":"damage","target":j.party[0].uid,"amount":2,"blocked":0,"text":"피해 2","frame":applied})
    check(view.status_feedback.pulses.size()==1 and view.status_feedback.pulses[0]["kind"]=="bind" and view._pending_status_cause.is_empty() and only_original_numbers(),"Legacy trap has VFX without extra labels and consumes context once")
    clear_feedback()
    view._play_event({"kind":"weather_tick","target":j.party[0].uid,"text":"모래바람 · 파이리","frame":applied})
    view._play_event({"kind":"damage","target":j.party[0].uid,"amount":1,"blocked":0,"text":"피해 1","frame":applied})
    check(view.status_feedback.pulses.size()==1 and view.status_feedback.pulses[0]["kind"]=="sand" and only_original_numbers(),"Weather damage uses distinct particles without new labels")
    clear_feedback()
    view._play_event({"kind":"heal","target":j.party[0].uid,"amount":2,"text":"씨앗 흡수 · 파이리","frame":applied})
    check(view.status_feedback.pulses.size()==1 and view.status_feedback.pulses[0]["kind"]=="seed" and only_original_numbers(),"Seed recovery adds green particles and retains original number")
    clear_feedback();view.status_feedback.burst("poison",true)
    prefs.set_battle_speed(2);view.status_feedback._process(.1)
    check(is_equal_approx(view.status_feedback.pulses[0]["time"],.2),"Condition burst follows battle speed")
    view.status_feedback._process(1)
    UiMotion.finish_tree(view.stage.canvas.source_sprite)
    check(view.status_feedback.pulses.is_empty() and view.stage.canvas.source_sprite.self_modulate==Color.WHITE,"Particle/tint expiry cleans up without a stuck overlay")
    prefs.set_battle_speed(1);clear_feedback()
    check(randi()==next_random and JourneySnapshot.encode(j)==fixture_before,"Visual effects and labels preserve global RNG and full fixture snapshot")
    ui.queue_free();await process_frame
    j=TutorialLesson.battle_practice()
    j.party[0].statuses={"burn":{"turns":2,"source_uid":j.battle.enemy().uid},"poison":{"turns":2,"source_uid":j.battle.enemy().uid}}
    var reference:=JourneySnapshot.restore(JourneySnapshot.encode(j))
    reference.battle.end_turn()
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.4).timeout
    view=ui.battle_ui;process_frame.connect(observe)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE));print("OS_KEY Return")
    await create_timer(.3).timeout
    for i in 160:
        if not view.busy and not seen.is_empty():break
        await create_timer(.08).timeout
    check(not view.busy and seen.has("burn") and seen.has("poison"),"Actual end-turn playback triggers successive burn and poison VFX")
    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(reference),"Natural playback exactly matches resolved turn, HP, expiry and RNG")
    check(JourneySnapshot.encode(actual)==baseline and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved and JourneySnapshot.encode(JourneySnapshot.restore(baseline))==baseline,"Actual run/save/UID/RNG and old snapshot restoration unchanged")
    ui.queue_free();await process_frame
    for name_text: String in ["GameMusic","GameAmbience","GameCries","GameAudio"]:
        var audio_node:=root.get_node(name_text)
        if name_text=="GameMusic":audio_node.stop_music()
        elif name_text=="GameAmbience":audio_node.stop_ambience()
        else:audio_node.stop_all()
    await create_timer(.2).timeout
    print("STATUS_FEEDBACK: ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
