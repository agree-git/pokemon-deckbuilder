extends SceneTree
## Current-rule representative review. Fixtures select situations; XTest drives controls.
var checks := 0
var failures := 0
var clicks := 0
var keys := 0
var folder := OS.get_environment("COMPLETION_REVIEW_DIR")
var ui: TacticalJourneyUI
var session: Node
var music: Node
var ambient: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func focus() -> void: print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
func point(control: Control) -> Vector2:
    var local: Vector2 = control.visible_point() if control is TrainerActionCard else control.size*.5
    return root.get_final_transform()*(control.get_global_transform_with_canvas()*local)+Vector2(root.position)
func click(control: Control) -> void:
    check(is_instance_valid(control),"OS click target exists")
    if not is_instance_valid(control): return
    if control is TrainerActionCard: await hover(control)
    var at := point(control)
    focus(); print("OS_CLICK ",roundi(at.x)," ",roundi(at.y)); clicks += 1
    await create_timer(.4).timeout
func key(symbol: String) -> void:
    print("OS_MOVE 960 80")
    await create_timer(.2).timeout
    focus(); print("OS_KEY ",symbol); keys += 1
    await create_timer(.35).timeout
func hover(control: Control) -> void:
    for i in 2:
        var at := point(control)
        focus(); print("OS_MOVE ",roundi(at.x)," ",roundi(at.y))
        await create_timer(.3).timeout
func ready(view: TacticalUI) -> void:
    for i in 400:
        if not view.busy:
            await create_timer(.35).timeout
            return
        await create_timer(.05).timeout
    check(false,"Natural presentation completes in20seconds")
func shot(label_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(label_text+".png"))==OK,"Screenshot "+label_text)
func show_journey(j: TacticalJourney) -> void:
    if is_instance_valid(ui): ui.free(); await process_frame
    session.adopt_journey(j)
    ui=load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey=j
    root.add_child(ui)
    await create_timer(.45).timeout
func add_card(j: TacticalJourney,id: int,owner := 0) -> BattleCardInstance:
    var b:=j.battle
    var c:=BattleCardInstance.new(b._next_uid,TacticalMoves.key_for(id),b.active().uid if owner==0 else owner)
    b._next_uid+=1; j._next_card_uid=b._next_uid
    b.hand.append(c); j.deck.append(c); b.energy=100
    return c
func clear_hand(b: TacticalBattle) -> void:
    b.draw_pile.append_array(b.hand); b.hand.clear()
func ordinary() -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p: BattlePokemon in j.party: p.level=50; PokemonStats.apply(p,true)
    for step in range(60,120):
        if j.route.stops[step]["kind"]!="wild": continue
        j.step=step; j.phase=TacticalJourney.MAP; j.enter_next()
        if "ghost" not in j.battle.enemy().types and j.battle.intent()["kind"]=="attack": return j
    check(false,"Representative ordinary battle exists")
    return j
func forecast(j: TacticalJourney,c: BattleCardInstance,label_text: String) -> void:
    var before:=JourneySnapshot.encode(j)
    var expected:=JourneySnapshot.restore(before.duplicate(true))
    var outcome:=expected.battle.play_card(c.uid)
    var value:=BattleCardPreview.analyze(j.battle,c.uid)
    check(outcome.is_empty() and value.get("reason","").is_empty(),label_text+" preview resolves")
    if not value.get("reason","").is_empty(): return
    check(value["target_after"]==BattleFrame.member(expected.battle.enemies[j.battle.enemy_index]) and value["actor_after"]==BattleFrame.member(expected.battle.active()) and value["intent"]==expected.battle.intent(),label_text+" forecast matches real current-rule resolution")
    check(JourneySnapshot.encode(j)==before,label_text+" forecast leaves actual state/RNG unchanged")
    await hover(ui.battle_ui.trainer_buttons[c.uid])
    check(ui.battle_ui.action_preview.visible and ui.battle_ui.action_preview.title.text.contains(str(j.battle.card_view(c)["name"])),label_text+" real hover opens correct forecast")
func play(c: BattleCardInstance) -> void:
    await click(ui.battle_ui.trainer_buttons[c.uid])
    await ready(ui.battle_ui)
    check(c not in ui.journey.battle.hand,"OS click plays "+c.key)
func board() -> Dictionary:
    var j:=ordinary(); var b:=j.battle
    clear_hand(b); b.enemy().block=1000
    var charge:=add_card(j,268)
    var electric:=add_card(j,85)
    var curl:=add_card(j,111)
    var small:=add_card(j,107)
    var light:=add_card(j,475)
    var heal:=add_card(j,505)
    var transform:=add_card(j,144)
    j.party[1].hp=j.party[1].max_hp/2; j.party[2].hp=j.party[2].max_hp/10
    session.adopt_journey(j)
    var menu:MainMenu=load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    await create_timer(.45).timeout
    check(is_instance_valid(menu.continue_button),"Title exposes saved expedition")
    await shot("01-title")
    # The genuine continue callback changes current_scene.
    current_scene=menu
    await click(menu.continue_button)
    ui=current_scene
    await ready(ui.battle_ui)
    check(ui.journey==j and b.player_moves_version==19,"Title continue opens v27/effects19 battle")
    await play(charge)
    check(PlayerMoveCompletion.read(b)["charged"].get(b.active().uid,false),"Charge persists through natural card playback")
    await forecast(j,electric,"Charged electric")
    await shot("02-charged-preview")
    var before:=JourneySnapshot.encode(j)
    await key("Escape")
    check(ui.battle_ui.menu_panel.visible and music.muffled and ambient.muffled,"OS pause filters music and ambience")
    await click(ui.battle_ui.settings_button)
    check(is_instance_valid(root.get_node("Preferences").panel),"Settings opens from pause")
    await shot("03-pause-settings")
    await key("Escape")
    check(music.muffled,"Closing settings preserves outer pause filter")
    await key("Escape")
    check(not music.muffled and not ambient.muffled and JourneySnapshot.encode(j)==before,"Pause restores audio and preserves state/RNG")
    await play(curl); await play(small); await play(light)
    var tips:=""
    for chip:Control in ui.battle_ui.ally_statuses.get_children(): tips+=chip.tooltip_text
    check(tips.contains("다음 전기") and tips.contains("구르기") and tips.contains("짓밟기") and tips.contains("몸무게"),"Current context badges render after natural playback")
    await forecast(j,heal,"Injured ally heal")
    check(ui.battle_ui.trainer_buttons[heal.uid].tooltip_text.contains(j.party[2].display_name),"Heal tooltip names actual weakest-ratio ally")
    check(ui.battle_ui.action_preview.allies.any(func(line:RichTextLabel):return line.visible and line.get_parsed_text().contains(j.party[2].display_name)),"Heal hover shows actual ally HP change")
    await shot("04-ally-heal-preview")
    var hp:=j.party[2].hp
    await play(heal)
    check(j.party[2].hp>hp and ui.battle_ui.party_values[2].text.contains(str(j.party[2].hp)),"Healing updates correct reserve HP in roster")
    await play(transform)
    check(PlayerMoveBulk.visual_species(b.bulk_context,b.active())==b.enemy().species_id,"Transform displays opponent species after natural playback")
    var portrait:TextureRect=ui.battle_ui.trainer_buttons[electric.uid].art_frame.get_node("Portrait")
    check((portrait.texture as AtlasTexture).atlas.resource_path==VisualCatalog.sprite_path(int(b.card_view(electric)["species_id"])),"Transformation refreshes existing hand portrait")
    await forecast(j,electric,"Transformed charged electric")
    await shot("05-transformed-preview")
    PlayerMoveTraps.add(b,b.enemy(),b.active(),212)
    ui.battle_ui._refresh()
    var other:=add_card(j,33,j.party[1].uid)
    ui.battle_ui._refresh()
    before=JourneySnapshot.encode(j)
    await key("2")
    check(JourneySnapshot.encode(j)==before and not b.card_reason(other.uid).is_empty() and ui.battle_ui.trainer_buttons[other.uid].disabled,"Trap blocks actual manual key and automatic-owner card")
    await shot("06-trapped")
    check(JourneySnapshot.validate(before),"State with transformed stats/charge/trap validates")
    var expected:=JourneySnapshot.restore(before.duplicate(true))
    expected.battle.end_turn()
    return {"state":before,"next":JourneySnapshot.encode(expected)}
func camp_review() -> void:
    var j:TacticalJourney
    for seed_value in 100:
        j=TacticalJourney.new(seed_value,"field_kit",[133,129],true)
        j.step=1;j.phase=TacticalJourney.MAP;j.enter_next()
        if j.camp()["kind"]=="merchant" and not j.camp()["machine_offers"].is_empty(): break
    j.party[0].hp=maxi(1,j.party[0].max_hp/2)
    j.party[1].hp=0;j.party[1].knocked_out=true
    j.held_inventory.append("oran_berry")
    await show_journey(j)
    var region_key:String=music.current_key
    await click(ui.find_child("CampMachinesButton",true,false))
    var w:=ui.workshop
    var move:=int(j.camp()["machine_offers"][0]["move"])
    await click(w.find_child("MachineOffer_0",true,false).find_child("WorkshopAction",true,false))
    check(j.gold==0 and j.machines.get(move,0)==1,"OS purchase spends100gold and obtains one TM")
    await click(w.find_child("WorkshopParty_1",true,false))
    check(w.find_child("MachineOwned_%d"%move,true,false).find_child("WorkshopAction",true,false).disabled,"Incompatible ally cannot learn TM")
    await click(w.find_child("WorkshopParty_0",true,false))
    await click(w.find_child("WorkshopSlot_1",true,false))
    await shot("07-tm-preview")
    await click(w.find_child("MachineOwned_%d"%move,true,false).find_child("WorkshopAction",true,false))
    check(j.party[0].learned_skills[1]==TacticalMoves.key_for(move) and j.machines[move]==0 and j.rested_steps.is_empty(),"TM use changes only selected slot and consumes item")
    await key("Escape")
    await click(ui.camp_tabs["gear"])
    await click(ui.find_child("Equipment_%d"%j.party[0].uid,true,false))
    await click(ui.find_child("Equip_oran_berry",true,false))
    check(j.party[0].held_item=="oran_berry" and "oran_berry" not in j.held_inventory,"OS equipment moves owned berry into held slot")
    await shot("08-held-item")
    await click(ui.camp_tabs["rest"])
    await click(ui.rest_button)
    check(j.party[1].alive() and not j.party[1].knocked_out and j.step in j.rested_steps,"Actual camp rest revives KO ally and spends camp action")
    await click(ui.actions[0])
    check(j.phase==TacticalJourney.MAP,"Actual leave-camp control reaches map")
    await click(ui.actions[0])
    for i in 100:
        if not ui.travelling: break
        await create_timer(.05).timeout
    await ready(ui.battle_ui)
    check(j.phase==TacticalJourney.BATTLE and music.current_key==region_key,"Camp/travel/ordinary battle keep same regional recording")
    clear_hand(j.battle)
    var stuff:=add_card(j,747)
    ui.battle_ui._refresh()
    await play(stuff)
    check(j.party[0].held_item.is_empty() and "oran_berry" not in j.held_inventory,"Berry consumed permanently through actual card use")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)) and session.save_notice.is_empty(),"Post-camp TM/rest/equip/consumption state autosaves")
    await shot("09-camp-next-battle")
func consumption_review() -> void:
    var j:=ordinary()
    j.party[0].held_item="oran_berry";HeldItems.initialize(j.battle)
    clear_hand(j.battle)
    var c:=add_card(j,747)
    await show_journey(j)
    await ready(ui.battle_ui)
    await play(c)
    check(j.party[0].held_item.is_empty() and "oran_berry" not in j.held_inventory and PlayerMoveBulk.ate(j.battle,j.party[0]),"Actual berry card consumes permanent item and records eating")
    check(session.save_notice.is_empty() and JourneySnapshot.encode(session.save_store.load_journey())==JourneySnapshot.encode(j),"Consumed berry stays absent in saved expedition")
    await shot("09-berry-consumed")
func card_text_review() -> void:
    var j:=ordinary()
    j.party[2].hp=1
    for id:int in [268,111,107,475,505,666,676,747,252,389,691,799,859,816,850]:
        var c:=add_card(j,id)
        var widget:=TrainerActionCard.new()
        widget.definition=j.battle.card_view(c)
        widget.position=Vector2(2100,0)
        root.add_child(widget)
        await process_frame
        check(not widget.effect_label.get_parsed_text().strip_edges().is_empty() and widget.effect_label.get_content_height()<=widget.effect_label.size.y+1 and not widget.cost_label.text.contains(".0"),"Current card text fits and cost is integral "+str(id))
        if id in [252,389]:check(not widget.tooltip_text.contains("이 동료의 전투 첫 기술에서만") and not widget.tooltip_text.contains("직전 상대턴에 이 동료가 직접 HP 피해"),"Tooltip uses current trigger "+str(id))
        widget.free()
func clone_contract(j: TacticalJourney) -> void:
    var before:=JourneySnapshot.encode(j)
    var copied:=BattleCardPreview.copy_battle(j.battle)
    check(copied.player_moves_version==j.battle.player_moves_version and copied._rng.state==j.battle._rng.state and copied.turn_speed_inverted==j.battle.turn_speed_inverted,"Detached preview keeps version/cached room direction/RNG")
    for field:String in BattleCardPreview.CONTEXT_FIELDS:
        check(copied.get(field)==j.battle.get(field),"Preview keeps "+field)
        copied.get(field)["probe_only"]=true
    copied.active().battle_stats["attack"]=1
    copied.active().content_version=1
    check(JourneySnapshot.encode(j)==before,"All preview contexts and transformed Pokemon metadata are detached")
    var old_file:=FileAccess.open("/tmp/player-v26-before.bin",FileAccess.READ)
    if old_file!=null:
        var old:Dictionary=old_file.get_var()
        var previous:=JourneySnapshot.restore(old["state"].duplicate(true))
        var old_copy:=BattleCardPreview.copy_battle(previous.battle)
        check(previous.battle.player_moves_version==18 and old_copy.player_moves_version==18 and JourneySnapshot.encode(previous)==old["state"],"Actual v26 save keeps its historical preview rule version/state")
    else:print("Previous v26 capture absent; historical-save preview check skipped")
func amplitude(frames: PackedVector2Array,frequency: float,rate: float) -> float:
    var real:=0.0;var imaginary:=0.0;var count:=mini(2048,frames.size())
    for i in count:
        var value:=frames[frames.size()-count+i].x
        real+=value*cos(TAU*frequency*i/rate);imaginary+=value*sin(TAU*frequency*i/rate)
    return sqrt(real*real+imaginary*imaginary)/maxi(1,count)
func filter_review() -> void:
    music.stop_all();music.set_muffled(false)
    var rate:=AudioServer.get_mix_rate()
    var generator:=AudioStreamGenerator.new();generator.mix_rate=rate;generator.buffer_length=1
    var player:=AudioStreamPlayer.new();player.stream=generator;player.bus="Music";root.add_child(player)
    var capture:=AudioEffectCapture.new();capture.buffer_length=1
    var bus:=AudioServer.get_bus_index("Music");var effect:=AudioServer.get_bus_effect_count(bus)
    AudioServer.add_bus_effect(bus,capture)
    var samples:=PackedVector2Array();samples.resize(int(rate))
    for i in samples.size():
        var value:=.15*(sin(TAU*500*i/rate)+sin(TAU*6000*i/rate));samples[i]=Vector2(value,value)
    player.play()
    var playback:AudioStreamGeneratorPlayback=player.get_stream_playback()
    check(playback.push_buffer(samples),"Known500Hz/6kHz tones enter real mixer")
    capture.clear_buffer();await create_timer(.16).timeout
    var normal:=capture.get_buffer(capture.get_frames_available())
    music.set_muffled(true);capture.clear_buffer();await create_timer(.36).timeout
    var filtered:=capture.get_buffer(capture.get_frames_available())
    var low:=amplitude(normal,500,rate);var high:=amplitude(normal,6000,rate)
    var filtered_low:=amplitude(filtered,500,rate);var filtered_high:=amplitude(filtered,6000,rate)
    print("FILTER_DSP ",low," ",high," ",filtered_low," ",filtered_high)
    check(normal.size()>=2048 and filtered.size()>=2048 and low>.001 and high>.001,"Actual mixer captures both original tone bands")
    check(filtered_low>low*.35 and filtered_high/maxf(filtered_low,.000001)<high/maxf(low,.000001)*.2,"Pause low-pass preserves lows and suppresses relative6kHz by at least14dB")
    music.set_muffled(false);player.stop();player.free();AudioServer.remove_bus_effect(bus,effect)
    await create_timer(.3).timeout
func boss_review() -> void:
    var j:=TacticalJourney.new(2718,"field_kit",[1,4,7],true)
    for role:String in ["gym","elite","champion"]:
        var step:=14 if role=="gym" else 128 if role=="elite" else 136
        var next:=TacticalJourney.new(2718,"field_kit",[1,4,7],true)
        next.step=step;next.badges=8;next.phase=TacticalJourney.MAP
        next.elite_wins=int(next.route.stops[step].get("league_index",0))
        check(next.enter_next().is_empty(),"Enter actual route "+role)
        await show_journey(next)
        await create_timer(.3).timeout
        var view:=ui.battle_ui
        var trainer:=view.opponent_trainer
        check(view.trainer_intro!=null and view.trainer_intro.portrait!=null and not view.dialogue_history.is_empty(),role+" loads trainer art and dialogue")
        check(music.current_key.begins_with(TrainerDialogue.key(trainer)+":"),role+" selects dedicated uploaded BGM")
        await shot("10-"+role+"-entrance")
        await ready(view)
        check(view.stage.canvas.target_factor==1 and not view.end_button.disabled,role+" natural entrance enables battle")
        await shot("11-"+role+"-ready")
        j=next
    # Actual region travel checks both fading voices before completion.
    j=ordinary(); j.step=16;j.phase=TacticalJourney.MAP
    await show_journey(j)
    var from:String=music.current_key
    await create_timer(1.4).timeout
    j.step=32
    ui.refresh()
    var to:String=music.current_key
    await create_timer(.2).timeout
    check(to!=from and music.players.all(func(p:AudioStreamPlayer):return p.playing and p.volume_linear>0 and p.volume_linear<1),"Region change uses different recording with overlapping fade-in/out")
    await create_timer(1.2).timeout
    check(music.players.filter(func(p:AudioStreamPlayer):return p.playing).size()==1,"Completed crossfade stops outgoing recording")
    var capture:=AudioEffectCapture.new()
    var bus:=AudioServer.get_bus_index("Music")
    var effect:=AudioServer.get_bus_effect_count(bus)
    AudioServer.add_bus_effect(bus,capture)
    await create_timer(.2).timeout
    var frames:=capture.get_buffer(capture.get_frames_available())
    var nonzero:=false
    for sample:Vector2 in frames:
        if sample.length()>.0001:nonzero=true;break
    check(frames.size()>0 and nonzero,"Uploaded BGM produces nonzero real mixer samples")
    AudioServer.remove_bus_effect(bus,effect)
func flow_review() -> void:
    var j:=ordinary();var b:=j.battle
    for member:BattlePokemon in j.party:member.level=100;PokemonStats.apply(member,true)
    b.active().hp=1;b.active().block=0
    clear_hand(b)
    await show_journey(j)
    await ready(ui.battle_ui)
    await key("Return")
    await ready(ui.battle_ui)
    check(not j.party[0].alive() and j.party[0].knocked_out and b.phase==TacticalBattle.REPLACE,"Actual enemy turn causes KO and mandatory replacement")
    await shot("14-forced-replacement")
    await key("2")
    await ready(ui.battle_ui)
    check(b.active()==j.party[1] and b.phase==TacticalBattle.PLAYER,"OS party key chooses mandatory replacement")
    var energy:=b.energy;var cost:=b.manual_switch_cost()
    await key("3")
    await ready(ui.battle_ui)
    check(b.active()==j.party[2] and b.energy==energy-cost,"Normal OS switch charges exactly displayed cost")
    var card:=add_card(j,33,j.party[1].uid)
    ui.battle_ui._refresh()
    var card_cost:int=b.card_view(card)["cost"]
    energy=b.energy
    await play(card)
    check(b.active()==j.party[1] and b.energy==energy-card_cost,"Owned card switches automatically without extra manual cost")
    check((b.hand+b.draw_pile+b.discard+b.exhausted).any(func(c:BattleCardInstance):return c.key=="injury" and c.injury_owner_uid==j.party[0].uid),"KO injury card enters current battle piles")
    if b.phase!=TacticalBattle.WON:
        b.enemy().hp=1;b.enemy().block=0
        card=add_card(j,33,j.party[1].uid)
        ui.battle_ui._refresh()
        await play(card)
    check(b.phase==TacticalBattle.WON and ui.battle_ui.result.visible,"Actual attack reaches victory panel")
    await shot("15-victory")
    await click(ui.battle_ui.result_next)
    check(j.phase==TacticalJourney.REWARD and j.wins==1,"Victory continue settles once into rewards")
    check(j.deck.any(func(c:BattleCardInstance):return c.key=="injury" and c.injury_owner_uid==j.party[0].uid),"Settlement commits KO injury into persistent deck")
    await shot("16-rewards")
    var count:=j.deck.size()
    await click(ui.actions[0])
    check(j.phase==TacticalJourney.MAP and (j.deck.size()>count or not j.held_inventory.is_empty() or j.relics.size()>1),"OS reward selection commits one reward and reaches map")
    await click(ui.actions[0])
    for i in 100:
        if not ui.travelling:break
        await create_timer(.05).timeout
    check(j.phase==TacticalJourney.REST and JourneySnapshot.validate(JourneySnapshot.encode(j)) and session.save_notice.is_empty(),"Victory/reward/travel reaches next valid autosaved camp")
    await shot("17-next-camp")
func art_review() -> void:
    check(session.has_journey and session.journey.phase==TacticalJourney.REST and session.journey.deck.any(func(c:BattleCardInstance):return c.key=="injury" and c.injury_owner_uid==session.journey.party[0].uid),"Actual saved post-victory camp preserves KO injury in persistent deck")
    var j:=ordinary();clear_hand(j.battle)
    var transform:=add_card(j,144);var electric:=add_card(j,85)
    await show_journey(j);await ready(ui.battle_ui)
    var original:TrainerActionCard=ui.battle_ui.trainer_buttons[electric.uid]
    await play(transform)
    var view:=j.battle.card_view(electric)
    var portrait:TextureRect=original.art_frame.get_node("Portrait")
    var type_icon:TextureRect=original.art_frame.get_node("TypeIcon")
    check(ui.battle_ui.trainer_buttons[electric.uid]==original and (portrait.texture as AtlasTexture).atlas.resource_path==VisualCatalog.sprite_path(int(view["species_id"])) and type_icon.texture.resource_path==TrainerActionCard.W.texture(str(view["type"])).resource_path,"Existing hand card refreshes portrait/type to actual transformation without reload")
    # Type-only changes reuse the same card and preserve state/RNG.
    var before:=JourneySnapshot.encode(j)
    var changed:=view.duplicate(true);changed["type"]="ice"
    original.update_card(changed,"",false)
    check((original.art_frame.get_node("TypeIcon") as TextureRect).texture.resource_path==TrainerActionCard.W.texture("ice").resource_path and JourneySnapshot.encode(j)==before,"Type-only artwork refresh is state/RNG neutral")
    original.update_card(view,"",false)
    await hover(original);await shot("18-transform-card-art")
    await card_text_review()
func resume_review() -> void:
    var saved:Dictionary=FileAccess.open(folder.path_join("resume.bin"),FileAccess.READ).get_var()
    check(session.has_journey and JourneySnapshot.encode(session.journey)==saved["state"],"Fresh engine process restores exact saved expedition/RNG")
    var menu:MainMenu=load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu);current_scene=menu
    await create_timer(.4).timeout
    await click(menu.continue_button)
    ui=current_scene
    await ready(ui.battle_ui)
    clone_contract(ui.journey)
    for chip:Control in ui.battle_ui.ally_statuses.get_children():
        var label:Label=chip.get_child(1)
        check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=label.size.x,"Status badge text fits "+label.text)
    await shot("12-resumed-state")
    await key("Return")
    await ready(ui.battle_ui)
    check(JourneySnapshot.encode(ui.journey)==saved["next"],"Actual next turn after process restart matches saved deterministic continuation")
    await shot("13-resumed-next-turn")
    await card_text_review()
    await filter_review()
func run() -> void:
    if DisplayServer.get_name()=="headless" or folder.is_empty():quit(2);return
    if not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):
        push_error("Isolated XDG_DATA_HOME required");quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    session=root.get_node("BattleSession");music=root.get_node("GameMusic");ambient=root.get_node("GameAmbience")
    root.get_node("Preferences").set_audio_muted(false)
    var phase:=OS.get_environment("COMPLETION_REVIEW_PHASE")
    if phase=="resume":
        await resume_review()
    elif phase=="flow":
        await flow_review()
    elif phase=="art":
        await art_review()
    else:
        var saved:=await board()
        if is_instance_valid(ui):current_scene=null
        if phase=="remaining":
            await consumption_review()
        else:
            await camp_review()
            await boss_review()
            await flow_review()
        var restored:=JourneySnapshot.restore(saved["state"])
        session.adopt_journey(restored)
        check(session.save_notice.is_empty(),"Save complex representative state before process exit")
        FileAccess.open(folder.path_join("resume.bin"),FileAccess.WRITE).store_var(saved)
    if is_instance_valid(ui):ui.free()
    for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]: root.get_node(name_text).stop_all()
    await create_timer(.3).timeout
    print("NATIVE_COMPLETION ",checks," checks / ",failures," failures / ",clicks," OS clicks / ",keys," OS keys")
    quit(1 if failures else 0)
