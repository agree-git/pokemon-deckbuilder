extends SceneTree
const Policy=preload("support/campaign_policy.gd")
const Tactical=preload("support/tactical_policy.gd")
var checks:=0
var failures:=0
var folder:=OS.get_environment("CHALLENGE_REVIEW_DIR")
var results:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func prepared_camp(j:TacticalJourney) -> void:
    # Actual preparation: improve cards instead of resting at near-full HP.
    var healthy:=j.party.all(func(p:BattlePokemon):return p.alive() and p.hp*3>=p.max_hp*2)
    var best:BattleCardInstance
    var score:=0.0
    if healthy:
        for card:BattleCardInstance in j.deck:
            if not TacticalContent.can_upgrade(card,j.battle.player_moves_version):continue
            var v:=TacticalContent.definition(card,j.battle.player_moves_version)
            var rating:=float(v.get("move_power",0))/maxi(1,int(v["cost"]))
            if v.has("seed"):rating+=80
            if v.has("draw"):rating+=30
            if rating>score:score=rating;best=card
    if best!=null:j.rest("upgrade",best.uid)
    else:j.rest()
    for member:BattlePokemon in j.party:
        if member.held_item.is_empty() and not j.held_inventory.is_empty():j.equip_held(j.held_inventory[0],member.uid)
    for i in j.party.size():
        for key:String in ["revive","super_potion","potion"]:
            if j.party[i].alive() and j.party[i].hp*4>=j.party[i].max_hp*3:break
            if j.quantity(key)==0 and j.buy_reason(key).is_empty():j.buy(key)
            if j.item_reason(key,i).is_empty():j.use_item(key,i)
func run_campaign(seed_value:int,prepared:bool) -> void:
    var j:=TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
    var actions:=0
    var seen:={}
    var start:=Time.get_ticks_msec()
    while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and actions<18000 and failures==0:
        var marker:=str(j.step)+":"+j.phase
        if not seen.has(marker):
            seen[marker]=true
            check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Challenge state validates "+marker)
            if j.phase==TacticalJourney.BATTLE and j.current()["kind"] in ["gym","elite","champion"]:
                FileAccess.open(folder.path_join("seed-%d-%s-boss-%d.bin"%[seed_value,str(prepared),j.step]),FileAccess.WRITE).store_var(JourneySnapshot.encode(j))
        var why:=""
        match j.phase:
            TacticalJourney.BATTLE:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                    why=j.settle()
                    if j.current()["kind"] in ["gym","elite","champion"]:print("CHALLENGE_PROGRESS seed=",seed_value," prepared=",prepared," wins=",j.wins," phase=",j.phase)
                else:why=Policy.apply(j,Policy.action(j))
            TacticalJourney.LEARN:why=j.resolve_learning(Policy.learn(j))
            TacticalJourney.REWARD:why=j.choose_reward(Policy.reward(j))
            TacticalJourney.MAP:why=j.enter_next()
            TacticalJourney.REST:
                if prepared:prepared_camp(j)
                else:Policy.camp(j)
                if not j.held_inventory.is_empty():j.equip_held(j.held_inventory[0],j.party[0].uid)
                if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty():j.resolve_camp(0)
                why=j.leave_camp()
            TacticalJourney.CAPTURE:why=j.resolve_capture(-1)
        actions+=1
        check(why.is_empty(),"Public challenge action accepted "+why)
        if actions%100==0:await process_frame
    var row:={"seed":seed_value,"prepared":prepared,"wins":j.wins,"phase":j.phase,"turns":j.total_turns,"knockouts":j.statistics["combat"]["knockouts"],"items_used":j.statistics["counts"]["items_used"],"supplies_bought":j.statistics["counts"]["supplies_bought"],"actions":actions,"milliseconds":Time.get_ticks_msec()-start}
    results.append(row)
    FileAccess.open(folder.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    FileAccess.open(folder.path_join("seed-%d-%s-final.bin"%[seed_value,str(prepared)]),FileAccess.WRITE).store_var(JourneySnapshot.encode(j))
    print("CHALLENGE_RESULT ",JSON.stringify(row))
func compatibility() -> void:
    var records:Array=FileAccess.open("/tmp/pre-challenge-v27.bin",FileAccess.READ).get_var()
    for record:Dictionary in records:
        var j:=JourneySnapshot.restore(record["state"].duplicate(true))
        check(JourneySnapshot.validate(record["state"]) and JourneySnapshot.encode(j)==record["state"],"Actual v27 snapshot unchanged")
        check(var_to_bytes(j.route.opponents(j.step)).hex_encode().sha256_text()==record["opponents_hash"],"Old future opponent definitions unchanged")
        Policy.apply(j,record["action"])
        check(JourneySnapshot.encode(j)==record["next"],"Old same input/RNG unchanged")
    check(JourneySave.compatible_content("2fc86978c18324e8a6a55524d5665ee2f5bd71d5294e11ccb713cfa9f2cb0dba"),"Actual v27 content fingerprint accepted")
func run() -> void:
    if folder.is_empty():folder="/tmp/pokemon-challenge-review"
    if OS.get_environment("XDG_DATA_HOME").is_empty() or not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):push_error("Isolated XDG data required");quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    if OS.get_environment("CHALLENGE_PREPARED_ONLY")=="1":
        for seed_value:int in [0,42]:await run_campaign(seed_value,true)
    else:
        compatibility()
        for seed_value:int in [0,42,2026]:await run_campaign(seed_value,false)
        for seed_value:int in [0,42]:await run_campaign(seed_value,true)
    print("CHALLENGE_CHECK ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
