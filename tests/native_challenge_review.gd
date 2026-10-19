extends SceneTree
var checks:=0
var failures:=0
var folder:="/tmp/pokemon-challenge-review/native"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func labels(node:Node) -> String:
    var result:String=node.text+"\n" if node is Label else ""
    for child:Node in node.get_children():result+=labels(child)
    return result
func shot(label_text:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(label_text+".png"))==OK,"Screenshot "+label_text)
func run() -> void:
    if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var menu:MainMenu=load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu);current_scene=menu
    await create_timer(.5).timeout
    check(labels(menu).contains("도전 난도"),"New expedition difficulty notice")
    await shot("01-title")
    menu.free()
    var state:Dictionary=FileAccess.open("/tmp/pokemon-challenge-review/results/seed-2026-false-boss-136.bin",FileAccess.READ).get_var()
    var j:=JourneySnapshot.restore(state)
    var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j;root.add_child(ui);current_scene=ui
    for i in 240:
        if not ui.battle_ui.busy:break
        await create_timer(.05).timeout
    var before:=JourneySnapshot.encode(j)
    check(j.battle.enemy().block==j.battle.enemy_definitions[0]["challenge_block"] and j.battle.enemy().block>0,"Actual champion opening shield survives scene entry")
    check(EnemyTactics.description(j.battle.enemy_definitions[0]).contains("210%"),"Champion pressure disclosed")
    await shot("02-champion")
    check(JourneySnapshot.encode(j)==before,"Rendering preserves actual snapshot and RNG")
    ui.free()
    # UI-only camp fixture; mechanics and save compatibility are tested separately.
    j.step=33;j.phase=TacticalJourney.REST;j.rested_steps.erase(33)
    for p:BattlePokemon in j.party:p.hp=1
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=j
    root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    check(labels(ui.page).contains("전원 체력 30% 회복"),"Camp displays actual reduced recovery")
    await shot("03-camp")
    var hp:=j.party[0].max_hp
    var at:=root.get_final_transform()*(ui.rest_button.get_global_transform_with_canvas()*(ui.rest_button.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
    await create_timer(.6).timeout
    check(j.party[0].hp==1+ceili(hp*.3) and ui.rest_button.disabled,"Actual rest click matches30 percent and consumes camp action")
    ui.free()
    for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name_text).stop_all()
    print("NATIVE_CHALLENGE ",checks," checks / ",failures," failures / 1 OS click")
    quit(0 if failures==0 else 1)
