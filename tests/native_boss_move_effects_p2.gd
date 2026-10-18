extends SceneTree
var checks:=0
var failures:=0
var inputs:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func wait_ui(ui:TacticalUI) -> void:
    for i in 300:
        if not ui.busy:return
        await create_timer(.05).timeout
    check(false,"P2 animation completes")
func key(symbol:="Return") -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol);inputs+=1
    await create_timer(.3).timeout
func shot(name:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OS.get_environment("BOSS_P2_REVIEW_DIR").path_join(name+".png"))==OK,"Capture "+name)
func select(b:TacticalBattle,id:int) -> void:
    for i in b.enemy_definitions[b.enemy_index]["intents"].size():
        if b.enemy_definitions[b.enemy_index]["intents"][i]["move_id"]==id:b.opening()["intent"]=i;return
func expose(j:TacticalJourney,ui:TacticalUI,id:int,owner:=0) -> BattleCardInstance:
    var b:=j.battle
    var c:=BattleCardInstance.new(b._next_uid,TacticalMoves.key_for(id),b.active().uid if owner==0 else owner)
    b._next_uid+=1;j._next_card_uid=maxi(j._next_card_uid,b._next_uid)
    j.deck.append(c);b.hand.push_front(c)
    ui._refresh_hand();ui._refresh()
    return c
func refresh(ui:TacticalUI) -> void:ui._apply_frame(BattleFrame.capture(ui.battle));ui._refresh()
func chip(row:Control,text:String) -> bool:
    return row.get_children().any(func(n:Node):return n is Control and n.tooltip_text.contains(text))
func run() -> void:
    var folder:=OS.get_environment("BOSS_P2_REVIEW_DIR")
    if DisplayServer.get_name()=="headless" or folder.is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.size=Vector2i(1920,1080)
    var targets:={"gym:brock":446,"gym:jasmine":446,"gym:byron":368,"gym:chuck":164,"gym:roxie":182,"gym:sabrina":356,"gym:tate_liza":113,"gym:raihan":776}
    var found:={}
    for seed_value in 400:
        var r:=CampaignRoute.new(seed_value,8)
        for step in r.stops.size():
            var stop:Dictionary=r.stops[step]
            if stop["kind"]!="gym":continue
            var boss:String="gym:"+str(stop["trainer"]["leader_id"])
            if targets.has(boss) and not found.has(boss):found[boss]=[seed_value,step]
        if found.size()==targets.size():break
    check(found.size()==targets.size(),"All eight real-route UI scenarios reachable")
    for boss:String in targets:
        var j:=TacticalJourney.new(found[boss][0],"field_kit",[3,6,9],true,8)
        for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
        j.step=found[boss][1];j.phase=TacticalJourney.MAP
        check(j.enter_next().is_empty(),"Enter "+boss)
        var b:=j.battle
        b.enemy_index=b.enemies.size()-1
        for i in b.enemy_index:b.enemies[i].hp=0;b.enemies[i].knocked_out=true
        b._grant_turn_energy();b.active().block=0;select(b,targets[boss])
        if boss=="gym:raihan":b.enemy().stat_stages["defense"]=2
        var ui:TacticalJourneyUI=load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey=j;root.add_child(ui)
        await create_timer(.4).timeout;await wait_ui(ui.battle_ui)
        check(b.enemy_definitions[-1].get("boss_moves_version")==3,"v8 representative active "+boss)
        check(ui.battle_ui.get_node("Intent").tooltip_text.contains(BossMoveEffectsP2.view(targets[boss])["name"]),"Actual UI move explanation present")
        check(root.get_node("GameMusic").current_key.begins_with(boss+":"),"Dedicated music retained")
        var before:=var_to_bytes(b.snapshot());refresh(ui.battle_ui);refresh(ui.battle_ui)
        check(before==var_to_bytes(b.snapshot()),"Actual field UI refresh preserves model and RNG")
        await shot(boss.replace(":","-")+"-before")
        var hp:=b.enemy().hp
        if boss=="gym:byron":
            expose(j,ui.battle_ui,33)
            await key("q");await wait_ui(ui.battle_ui)
            check(b.intent()["value"]>0 and ui.battle_ui.get_node("Intent").tooltip_text.contains("실제HP"),"Real Q attack updates Metal Burst preview")
            var ally_hp:=b.active().hp;var damage:int=b.intent()["value"]
            await key();await wait_ui(ui.battle_ui)
            check(ally_hp-b.active().hp==damage,"Actual returned damage matches updated counter preview")
        else:
            await key();await wait_ui(ui.battle_ui)
        match boss:
            "gym:brock":
                check(chip(ui.battle_ui.ally_statuses,"스텔스록"),"Installed hazard chip visible")
                check(ui.battle_ui.party_buttons[1].tooltip_text.contains("스텔스록"),"Manual reserve tooltip discloses entry loss")
                hp=b.party[1].hp;var loss:=BossBattleEffects.entry_damage(b,b.party[1]);var energy:=b.energy
                await key("2");await wait_ui(ui.battle_ui)
                check(b.active()==b.party[1] and b.active().hp==hp-loss and b.energy==energy-1,"Actual OS2 switch pays hazard and normal cost once")
            "gym:jasmine":
                select(b,46);refresh(ui.battle_ui);hp=b.party[1].hp
                await key();await wait_ui(ui.battle_ui)
                check(b.active()==b.party[1] and b.active().hp<hp,"Actual Roar chooses reserve and applies installed hazard")
            "gym:chuck":
                check(chip(ui.battle_ui.enemy_statuses,"대타출동") and b.enemy().hp<hp,"Actual substitute chip and paid HP visible")
                hp=b.enemy().hp;expose(j,ui.battle_ui,33)
                await key("q");await wait_ui(ui.battle_ui)
                check(b.enemy().hp==hp and not b.intent().get("failed_move",false),"Substitute absorbs real card without cancelling Focus Punch")
                BossBattleEffects.write(b)["substitutes"][b.enemy().uid]=0
                expose(j,ui.battle_ui,33)
                await key("q");await wait_ui(ui.battle_ui)
                check(b.intent().get("failed_move",false) and ui.battle_ui.get_node("Intent/Title").text=="행동 취소","Real HP hit updates Focus Punch failure and visible cancellation")
            "gym:roxie":
                check(chip(ui.battle_ui.enemy_statuses,"방어 유지"),"Actual Protect state chip visible")
                expose(j,ui.battle_ui,34);hp=b.enemy().hp
                await key("q");await wait_ui(ui.battle_ui)
                check(b.enemy().hp==hp and not b.enemy().statuses.has("paralysis"),"Protect cancels actual card damage and secondary effect")
            "gym:sabrina":
                check(chip(ui.battle_ui.ally_statuses,"중력"),"Gravity state chip visible")
                var c:=expose(j,ui.battle_ui,19,b.party[1].uid)
                check(ui.battle_ui.trainer_buttons[c.uid].disabled,"Gravity disables a real aerial technique card")
                before=var_to_bytes(b.snapshot())
                await key("q");await wait_ui(ui.battle_ui)
                check(before==var_to_bytes(b.snapshot()),"Actual blocked Q card consumes no model resources")
            "gym:tate_liza":check(chip(ui.battle_ui.enemy_statuses,"빛의장막") and BossBattleEffects.read(b)["screen"]==5,"Light Screen five-turn chip visible")
            "gym:raihan":check(b.events.any(func(e:Dictionary):return e["kind"]=="damage"),"Body Press presents actual Defense-based damage")
        await shot(boss.replace(":","-")+"-after")
        ui.free();await process_frame
    for name:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name).stop_all()
    await create_timer(.3).timeout
    print("Native boss P2: %d checks / %d failures; %d OS keys" % [checks,failures,inputs])
    quit(1 if failures else 0)
