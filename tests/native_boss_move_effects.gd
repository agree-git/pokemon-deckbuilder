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
    check(false,"Enemy move presentation completes")
func key(symbol:String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol)
    inputs+=1
    await create_timer(.3).timeout
func shot(name:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OS.get_environment("BOSS_EFFECT_REVIEW_DIR").path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
    var folder:=OS.get_environment("BOSS_EFFECT_REVIEW_DIR")
    if DisplayServer.get_name()=="headless" or folder.is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.size=Vector2i(1920,1080)
    var targets:={"elite:caitlin":347,"gym:misty":58,"gym:winona":355}
    var found:Dictionary={}
    for seed_value in 300:
        var route:=CampaignRoute.new(seed_value)
        for step in route.stops.size():
            var stop:Dictionary=route.stops[step]
            if stop["kind"] not in ["gym","elite","champion"]:continue
            var boss:=TrainerDialogue.key(TrainerDialogue.opponent(stop,stop["biome"]))
            if targets.has(boss) and not found.has(boss):found[boss]=[seed_value,step]
        if found.size()==targets.size():break
    check(found.size()==3,"All real seeded demo cases reachable")
    for boss:String in targets:
        var j:=TacticalJourney.new(found[boss][0],"field_kit",[3,6,9],true)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[boss][1];j.phase=TacticalJourney.MAP
        if j.current()["kind"]=="elite":j.badges=8;j.elite_wins=int(j.current()["league_index"])
        check(j.enter_next().is_empty(),"Enter "+boss)
        var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey=j;root.add_child(ui)
        await create_timer(.4).timeout
        await wait_ui(ui.battle_ui)
        for slot in j.battle.enemies.size()-1:
            ui.battle_ui._action_before=BattleFrame.capture(j.battle)
            j.battle.events.clear();j.battle._damage(j.battle.enemy(),j.battle.enemy().hp,true);j.battle._outcome()
            ui.battle_ui._present("")
            await wait_ui(ui.battle_ui)
        var b:=j.battle
        check(b.enemy_definitions[-1].has("boss_moves_version"),"Authored representative active "+boss)
        for i in b.enemy_definitions[-1]["intents"].size():
            if int(b.enemy_definitions[-1]["intents"][i]["move_id"])==targets[boss]:b.opening()["intent"]=i;break
        if boss=="gym:winona":b.enemy().hp=maxi(1,b.enemy().max_hp/2)
        ui.battle_ui._apply_frame(BattleFrame.capture(b));ui.battle_ui._refresh()
        var tooltip:String=ui.battle_ui.get_node("Intent").tooltip_text
        check(tooltip.contains(BossMoveEffects.view(targets[boss])["name"]) and tooltip.contains("확정"),"Visible named move and deterministic side-effect rules")
        check(ui.battle_ui.get_node("Intent/Tactic").text=="대표 전술","Authored heading fits intent badge")
        var state:=var_to_bytes([b.enemy_states,b.party.map(func(p:BattlePokemon):return p.snapshot()),b.enemy().snapshot(),b._rng.state])
        ui.battle_ui._refresh();ui.battle_ui._refresh()
        check(state==var_to_bytes([b.enemy_states,b.party.map(func(p:BattlePokemon):return p.snapshot()),b.enemy().snapshot(),b._rng.state]),"Repeated actual UI refresh preserves battle state and draw RNG")
        check(root.get_node("GameMusic").current_key.begins_with(boss+":"),"Dedicated music retained "+boss)
        await shot(boss.replace(":","-")+"-before")
        var hp:=b.enemy().hp
        await key("Return")
        await wait_ui(ui.battle_ui)
        if boss=="elite:caitlin":
            check(b.enemy().stat_stages.get("special_attack")==1 and b.enemy().stat_stages.get("special_defense")==1,"Actual Enter executes Calm Mind stages")
        elif boss=="gym:misty":
            check(b.active().statuses.has("sleep"),"Actual enemy attack applies visible one-turn sleep adaptation")
            var has_owned:=b.hand.any(func(c:BattleCardInstance):return c.owner_uid==b.active().uid)
            if not has_owned:
                # Deliberate UI fixture: expose a legitimate owned card without assuming a random draw.
                for pile:Array in [b.draw_pile,b.discard]:
                    var moved:=false
                    for c:BattleCardInstance in pile:
                        if c.owner_uid==b.active().uid:
                            pile.erase(c);b.hand.append(c);moved=true;break
                    if moved:break
                ui.battle_ui._refresh_hand()
            var disabled:=false
            for c:BattleCardInstance in b.hand:
                if c.owner_uid==b.active().uid:disabled=disabled or b.card_reason(c.uid).contains("수면")
            check(disabled,"Sleeping technique card fixture gives an actionable refusal reason")
        else:check(b.enemy().hp>hp and b.enemy().hp<=b.enemy().max_hp,"Actual Roost presentation heals and clamps HP")
        await shot(boss.replace(":","-")+"-after")
        ui.free();await process_frame
    for name:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native boss move effects: %d checks / %d failures; %d OS keys" % [checks,failures,inputs])
    quit(1 if failures else 0)
