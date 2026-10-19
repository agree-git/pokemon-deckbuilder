extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func journey(step:int,version:=28) -> TacticalJourney:
    var j:=TacticalJourney.new(2026,"field_kit",[1,4,7],true,version)
    j.step=step;j.phase=TacticalJourney.MAP
    for p:BattlePokemon in j.party:p.level=100;PokemonStats.apply(p,true)
    if step>=128:j.badges=8;j.elite_wins=int(j.current()["league_index"])
    check(j.enter_next().is_empty(),"Enter rule fixture")
    return j
func damage_contract(b:TacticalBattle,label_text:String) -> void:
    var p:=b.active();p.block=0
    var before:=p.hp
    var predicted:=b.intent()
    var raw:=BattleCardPreview.copy_battle(b)
    for field:String in CampaignChallenge.FIELDS:raw.enemy_definitions[raw.enemy_index].erase(field)
    var base:=raw.intent()
    var factor:=int(b.enemy_definitions[b.enemy_index]["challenge_pressure"])/100.0
    check(predicted["value"]==ceili(int(base.get("per_hit",base["value"]))*factor)*int(base.get("hits",1)),label_text+" scales final announced direct hit exactly once")
    check(b.end_turn().is_empty() and before-p.hp==mini(before,int(predicted["value"])),label_text+" actual HP loss equals announcement")
func run() -> void:
    var old:=CampaignRoute.new(2026,27);var current:=CampaignRoute.new(2026,28)
    check(old.stops==current.stops and old.signature==current.signature,"Party/aces/levels/route RNG unchanged")
    for step in range(0,137,2):
        var before:=old.opponents(step);var after:=current.opponents(step)
        for i in before.size():
            check(CampaignChallenge.valid(after[i],current,step),"Valid difficulty metadata")
            for field:String in CampaignChallenge.FIELDS:after[i].erase(field)
        check(before==after,"Only difficulty metadata differs at "+str(step))
    var j:=journey(10);var b:=j.battle
    check(b.enemies[0].block==b.enemy_definitions[0]["challenge_block"] and b.enemies[1].block==b.enemy_definitions[1]["challenge_block"],"Every trainer member starts with configured shield")
    b.opening()["intent"]=1
    damage_contract(b,"Generic attack")
    j=journey(136);b=j.battle;b.enemy_index=b.enemies.size()-1
    var selected:=false
    for i in b.enemy_definitions[b.enemy_index]["intents"].size():
        b.opening()["intent"]=i
        var action:=b.intent()
        if action.has("per_hit") and int(action["value"])>0 and action.get("hits",1)==1:
            selected=true;break
    check(selected,"Authored ace has a direct-hit contract fixture")
    if selected:damage_contract(b,"Authored ace")
    var state:Dictionary=FileAccess.open("/tmp/pokemon-challenge-review/results/seed-2026-false-boss-136.bin",FileAccess.READ).get_var()
    check(JourneySnapshot.validate(state),"Actual new expedition snapshot validates")
    j=JourneySnapshot.restore(state.duplicate(true))
    var store:=JourneySave.new("user://challenge-contract.json")
    check(store.save(j).is_empty(),"New rules save")
    var restored:=store.load_journey()
    check(restored!=null and JourneySnapshot.encode(restored)==state,"Exact difficulty/guard/UID/RNG file restore")
    j.battle.end_turn();restored.battle.end_turn()
    check(JourneySnapshot.encode(j)==JourneySnapshot.encode(restored),"Same next announced action and RNG after restore")
    for field:String in CampaignChallenge.FIELDS:
        var bad:=state.duplicate(true);bad["battle"]["enemy_definitions"][0][field]+=1
        check(not JourneySnapshot.validate(bad),"Reject changed difficulty field "+field)
    var records:Array=FileAccess.open("/tmp/pre-challenge-v27.bin",FileAccess.READ).get_var()
    var bad:Dictionary=records[0]["state"].duplicate(true);bad["battle"]["enemy_definitions"][0]["challenge_version"]=28
    check(not JourneySnapshot.validate(bad),"Older expedition rejects injected difficulty flag")
    for version:int in [27,28]:
        j=journey(33,version)
        for p:BattlePokemon in j.party:p.hp=1
        var hp:=j.party[0].max_hp
        check(j.rest().is_empty() and j.party[0].hp==1+ceili(hp*(.3 if version==28 else .5)),"Correct new/legacy camp heal "+str(version))
    print("CHALLENGE_CONTRACT ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
