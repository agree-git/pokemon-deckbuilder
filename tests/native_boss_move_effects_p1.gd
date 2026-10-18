extends SceneTree
var checks:=0
var failures:=0
var inputs:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func wait_ui(ui:TacticalUI) -> void:
    for i in 300:
        if not ui.busy:return
        await create_timer(.05).timeout
    check(false,"P1 presentation completes")
func key() -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY Return");inputs+=1
    await create_timer(.3).timeout
func shot(name:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OS.get_environment("BOSS_P1_REVIEW_DIR").path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
    var folder:=OS.get_environment("BOSS_P1_REVIEW_DIR")
    if DisplayServer.get_name()=="headless" or folder.is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.size=Vector2i(1920,1080)
    var targets:={"champion:leon":[76,"prepare",2],"champion:cynthia":[416,"move",2],"champion:iris":[530,"move",1],"gym:blaine":[394,"move",1],"gym:juan":[156,"move",3],"elite:drayton":[905,"prepare",1]}
    var found:={}
    for seed_value in 300:
        var r:=CampaignRoute.new(seed_value,7)
        for step in r.stops.size():
            var stop:Dictionary=r.stops[step]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var boss:=TrainerDialogue.key(TrainerDialogue.opponent(stop,stop["biome"]))
            if targets.has(boss) and not found.has(boss):found[boss]=[seed_value,step]
        if found.size()==targets.size():break
    check(found.size()==targets.size(),"All six real route showcases reachable")
    for boss:String in targets:
        var j:=TacticalJourney.new(found[boss][0],"field_kit",[3,6,9],true,7)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[boss][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"] in ["elite","champion"]:j.badges=8;j.elite_wins=int(j.current()["league_index"])
        check(j.enter_next().is_empty(),"Enter "+boss)
        var b:=j.battle
        b.enemy_index=b.enemies.size()-1
        for i in b.enemy_index:b.enemies[i].hp=0;b.enemies[i].knocked_out=true
        b._grant_turn_energy()
        b.active().block=0
        for i in b.enemy_definitions[-1]["intents"].size():
            var a:Dictionary=b.enemy_definitions[-1]["intents"][i]
            if a["move_id"]==targets[boss][0] and a["kind"]==targets[boss][1]:b.opening()["intent"]=i;break
        if boss=="gym:juan":b.enemy().hp=1
        if boss=="elite:drayton":b.powers["weather_rain"]=5
        var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey=j;root.add_child(ui)
        await create_timer(.4).timeout;await wait_ui(ui.battle_ui)
        check(b.enemy_definitions[-1].get("boss_moves_version")==2,"Actual P1 representative loaded")
        var tooltip:String=ui.battle_ui.get_node("Intent").tooltip_text
        check(tooltip.contains(BossMoveEffectsP1.view(targets[boss][0])["name"]) or tooltip.contains("충전"),"Move/phase explanation visible")
        check(root.get_node("GameMusic").current_key.begins_with(boss+":"),"Dedicated BGM retained "+boss)
        var before:=var_to_bytes([b.enemy_states,b.enemy().snapshot(),b.active().snapshot(),b._rng.state])
        ui.battle_ui._refresh();ui.battle_ui._refresh()
        check(before==var_to_bytes([b.enemy_states,b.enemy().snapshot(),b.active().snapshot(),b._rng.state]),"Actual UI refresh is pure")
        await shot(boss.replace(":","-")+"-before")
        var hp:=b.active().hp
        var enemy_hp:=b.enemy().hp
        for turn in int(targets[boss][2]):
            await key();await wait_ui(ui.battle_ui)
            if boss=="champion:leon" and turn==0:
                check(b.active().hp==hp and BossMoveEffectsP1.state(b)["charge"]==76,"Native Solar Beam charging turn deals no damage")
                check(ui.battle_ui.get_node("Intent/Title").text=="솔라빔","Native second turn announces actual Solar Beam")
            if boss=="champion:cynthia" and turn==0:
                check(ui.battle_ui.get_node("Intent/Title").text=="재충전","Native Giga Impact announces recovery")
                hp=b.active().hp
            if boss=="gym:juan" and turn==0:
                check(b.enemy().hp==b.enemy().max_hp and b.enemy().statuses.get("sleep",{}).get("turns")==2,"Native Rest heals with two future sleeping turns")
                check(ui.battle_ui.get_node("Intent/Title").text=="행동 취소","Native Rest shows cancelled sleeping action")
        match boss:
            "champion:leon":check(b.active().hp<hp,"Native prepared Solar Beam attacks on second action")
            "champion:cynthia":check(b.active().hp==hp,"Native recharge cannot attack")
            "champion:iris":check(b.events.any(func(e:Dictionary):return e["kind"]=="enemy_hit"),"Native Dual Chop presents second hit")
            "gym:blaine":check(b.enemy().hp<enemy_hp and b.events.any(func(e:Dictionary):return e["kind"]=="recoil"),"Native Flare Blitz presents real self damage")
            "gym:juan":check(not b.enemy().statuses.has("sleep"),"Native Rest wakes after two cancelled actions")
            "elite:drayton":check(b.enemy().stat_stages.get("special_attack")==1 and b.intent()["move_id"]==406,"Native rain executes Electro Shot once with one boost")
        await shot(boss.replace(":","-")+"-after")
        ui.free();await process_frame
    for name:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native boss P1: %d checks / %d failures; %d OS keys" % [checks,failures,inputs])
    quit(1 if failures else 0)
