extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func no_replay_labels(node:Node) -> bool:
    if (node is Button or node is Label) and node.text in ["다시 시작","원정 다시 하기","같은 시드로 다시 출발","새 시드로 출발"]:return false
    for child:Node in node.get_children():
        if not no_replay_labels(child):return false
    return true
func run() -> void:
    if not OS.get_user_data_dir().begins_with("/tmp/pokemon-remove-restart/"):quit(2);return
    var j:=TacticalJourney.new(712,"field_kit",[1,4,7],true)
    check(j.party.size()==3 and j.route.generation==28 and not j.has_method("restart"),"Fresh expedition initializes normally without replay API")
    var original:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(original) and JourneySnapshot.encode(JourneySnapshot.restore(original))==original,"Existing saves restore exactly through constructor initialization")
    var view:=TacticalJourneyUI.new();view.journey=j;root.add_child(view)
    await process_frame
    var battle:TacticalUI=view.battle_ui
    battle.finish_presentation()
    check(not is_instance_valid(battle.restart_button) and not is_instance_valid(battle.result_restart) and no_replay_labels(battle),"Campaign pause menu and battle result contain no restart buttons")
    check(not battle.has_signal("run_restart_requested") and not view.has_method("_restart") and not view.has_method("_new_seed"),"Campaign replay signal and same/new-seed handlers are removed")
    original=JourneySnapshot.encode(j)
    battle.restart("field_kit")
    check(JourneySnapshot.encode(j)==original,"Direct combat restart call cannot reset the current campaign/RNG")
    for phase in [TacticalBattle.WON,TacticalBattle.LOST]:
        j.battle.phase=phase;battle.busy=false;battle._refresh()
        check(battle.result.visible and is_instance_valid(battle.result_next) and no_replay_labels(battle),"Victory and defeat result still offer continuation without retry")
    # Continue the real defeated campaign into its terminal result, preserving the run.
    var run_id:=j.run_id
    battle.result_next.pressed.emit()
    await process_frame
    check(j.phase==TacticalJourney.FAILED and j.run_id==run_id and no_replay_labels(view),"Defeat continuation shows final result without creating a new run")
    check(view.actions.size()==1 and view.actions[0].get_global_rect().position.x==880,"Final result offers one centered return-to-title action")
    original=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(original) and JourneySnapshot.encode(JourneySnapshot.restore(original))==original,"Terminal result still roundtrips exactly")
    j.phase=TacticalJourney.CLEARED;view._credits_run_id=j.run_id;view.refresh()
    await process_frame
    check(no_replay_labels(view) and view.actions.size()==1 and view.page.find_child("ReplayCredits",true,false)!=null,"Clear result keeps credits replay and title action, no expedition replay")
    view.free()
    await process_frame
    print("NO_RUN_RESTART ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
