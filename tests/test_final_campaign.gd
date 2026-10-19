extends SceneTree
## One current-rule expedition using ordinary public actions, no state/HP/energy cheats.
const Policy = preload("support/campaign_policy.gd")
var checks := 0
var failures := 0
var actions := 0
var purchases := 0
var folder := OS.get_environment("FINAL_CAMPAIGN_DIR")
var store: JourneySave
var seen := {}
var phases := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func capture(j: TacticalJourney,name: String) -> void:
    FileAccess.open(folder.path_join(name+".bin"),FileAccess.WRITE).store_var(JourneySnapshot.encode(j))
func checkpoint(j: TacticalJourney) -> TacticalJourney:
    var before:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(before),"Public checkpoint validates "+j.progress_title()+" / "+j.phase)
    if not JourneySnapshot.validate(before):return j
    check(store.save(j).is_empty(),"Write real checkpoint")
    var restored:=store.load_journey()
    check(restored!=null and JourneySnapshot.encode(restored)==before,"File load preserves exact campaign/UID/RNG")
    return restored if restored!=null else j
func camp(j: TacticalJourney) -> String:
    Policy.camp(j)
    if purchases<3 and j.camp()["kind"]=="merchant":
        for i in j.shop_cards().size():
            var offer:Dictionary=j.shop_cards()[i]
            var view:=j.reward_view(offer)
            var useful:bool=offer["key"] in ["guard","counter","potion_card","boost_card","ether_card","focus","analysis"] or (int(offer["owner_uid"])!=0 and view.has("damage"))
            if not useful or not j.shop_card_reason(i).is_empty():continue
            var gold:=j.gold;var count:=j.deck.size()
            var reason:=j.buy_shop_card(i)
            if not reason.is_empty():return reason
            check(j.gold==gold-int(offer["price"]) and j.deck.size()==count+1,"Public merchant purchase pays quoted price once")
            purchases+=1
            break
    if not j.held_inventory.is_empty():
        var reason:=j.equip_held(j.held_inventory[0],j.party[0].uid)
        if not reason.is_empty():return reason
    if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty():
        var reason:=j.resolve_camp(0)
        if not reason.is_empty():return reason
    return j.leave_camp()
func run() -> void:
    if folder.is_empty():folder=OS.get_cache_dir().path_join("pokemon-final-campaign")
    if not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")) or OS.get_environment("XDG_DATA_HOME").is_empty():
        push_error("Isolated XDG_DATA_HOME required");quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    store=JourneySave.new("user://final-campaign.json")
    var j:=TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var resume:=OS.get_environment("FINAL_CAMPAIGN_RESUME")
    if not resume.is_empty():
        var previous:Dictionary=FileAccess.open(resume,FileAccess.READ).get_var()
        check(JourneySnapshot.validate(previous),"Resume a real captured public-action checkpoint")
        if not JourneySnapshot.validate(previous):quit(1);return
        j=JourneySnapshot.restore(previous)
        print("RESUMED step=",j.step," wins=",j.wins)
    check(j.route.generation==27 and j.battle.player_moves_version==19,"Current v27 / effects19")
    while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and actions<20000 and failures==0:
        phases[j.phase]=int(phases.get(j.phase,0))+1
        var key:=str(j.step)+":"+j.phase
        if not seen.has(key):
            seen[key]=true
            check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Progress state validates "+key)
            if failures>0:break
            if j.phase==TacticalJourney.BATTLE:
                capture(j,"last-battle")
                if j.current()["kind"] in ["gym","elite","champion"]:
                    capture(j,"boss-"+str(j.step))
                    j=checkpoint(j)
            elif j.phase==TacticalJourney.REST and j.step%16==1:j=checkpoint(j)
        var reason:=""
        var action:Array=[]
        match j.phase:
            TacticalJourney.BATTLE:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                    reason=j.settle()
                    if j.wins%8==0 or j.current()["kind"] in ["gym","elite","champion"]:
                        print("CAMPAIGN step=",j.step," wins=",j.wins," badges=",j.badges," elite=",j.elite_wins," phase=",j.phase," actions=",actions)
                else:
                    action=Policy.action(j)
                    reason=Policy.apply(j,action)
            TacticalJourney.LEARN:reason=j.resolve_learning(Policy.learn(j))
            TacticalJourney.REWARD:reason=j.choose_reward(Policy.reward(j))
            TacticalJourney.MAP:reason=j.enter_next()
            TacticalJourney.REST:reason=camp(j)
            TacticalJourney.CAPTURE:reason=j.resolve_capture(-1)
            _:reason="Unexpected phase "+j.phase
        actions+=1
        if not reason.is_empty():
            print("REJECTED step=",j.step," phase=",j.phase," action=",action," reason=",reason)
            check(false,"Public progression action rejected: "+reason)
        if actions%100==0:await process_frame
    capture(j,"final")
    check(j.phase==TacticalJourney.CLEARED and j.wins==69 and j.badges==8 and j.elite_wins==4,"One public-action69-battle expedition reaches champion completion")
    if j.phase==TacticalJourney.CLEARED:
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Terminal state validates")
        check(j.statistics["battles"].size()==69 and RunStatistics.valid_run(j.statistics),"All69 unique battle statistics remain valid")
        check(j.gold==100+int(j.statistics["counts"]["gold_earned"])-RunStatistics.spent(j.statistics),"Final wallet reconciles earned/spent gold")
        check(store.save(j).is_empty() and store.load_journey()==null and store.last_error.is_empty(),"Completed save cannot resume or fall back to unfinished backup")
        var before:=JourneySnapshot.encode(j)
        j.settle()
        check(JourneySnapshot.encode(j)==before,"Repeated terminal settlement cannot pay rewards twice")
    else:
        print("STOPPED step=",j.step," phase=",j.phase," turn=",j.battle.turn," intent=",j.battle.intent()," party=",j.party.map(func(p:BattlePokemon):return p.snapshot()))
    var report:={"seed":2026,"route_version":j.route.generation,"player_rules":j.battle.player_moves_version,"phase":j.phase,"wins":j.wins,"badges":j.badges,"elite_wins":j.elite_wins,"actions":actions,"turns":j.total_turns,"purchases":purchases,"checks":checks,"failures":failures,"phases":phases,"fingerprint":JourneySave.fingerprint()}
    FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FINAL_CAMPAIGN ",checks," checks / ",failures," failures; wins=",j.wins," actions=",actions," turns=",j.total_turns)
    quit(0 if failures==0 else 1)
