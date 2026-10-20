extends SceneTree
const TRAINING = preload("res://scripts/tactics/camp_move_training.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1;push_error(message)
func fixture(at := 1) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[133,4,7],true)
    j.step=at;j.phase=TacticalJourney.MAP
    check(j.enter_next().is_empty(),"Enter an actual campaign camp")
    j.gold=10000000
    return j
func roundtrip(j: TacticalJourney) -> void:
    var data:=JourneySnapshot.encode(j)
    var valid:=JourneySnapshot.validate(data)
    check(valid,"Current save validates with original stored prices/statistics")
    if valid:check(JourneySnapshot.encode(JourneySnapshot.restore(data))==data,"Exact save and RNG restoration")
func run() -> void:
    if not OS.get_user_data_dir().begins_with("/tmp/pokemon-training-economy/"):quit(2);return
    var j:=fixture()
    var p:=j.party[0]
    var before:=JourneySnapshot.encode(j)
    var all_moves:=j.training_offers(p.uid)
    var level_moves:=TRAINING.level_moves(p)
    check(level_moves.all(func(move: int):return move in all_moves) and all_moves.size()>3,"Every current-level move is shown without three-choice cap")
    check(all_moves==NationalEvolution.teachable_moves(p) and j.training_offers(p.uid)==all_moves and JourneySnapshot.encode(j)==before,"Full legal catalog includes nonlevel paths without consuming RNG")
    check(level_moves.all(func(move:int):return j.train_move_price(p.uid,move)==100),"All eligible level moves cost exactly 100 gold")
    var move:=0
    var other:=0
    for id:int in all_moves:
        if TacticalMoves.key_for(id) in p.learned_skills:continue
        if id in level_moves:move=id
        else:other=id
    check(move>0 and other>0 and j.train_move_price(p.uid,other)==200,"Nonlevel compatible techniques are available for 200 gold")
    j.gold=99;before=JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,move,0).is_empty() and before==JourneySnapshot.encode(j),"100-gold boundary rejects without mutation")
    j.gold=199;before=JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,other,0).is_empty() and before==JourneySnapshot.encode(j),"200-gold boundary rejects without mutation")
    j.gold=300;before=JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,move,4).is_empty() and before==JourneySnapshot.encode(j),"Invalid slot never charges gold")
    check(not j.train_move(p.uid,919,0).is_empty() and before==JourneySnapshot.encode(j),"Incompatible move remains blocked")
    var other_cards:=j.deck.filter(func(c:BattleCardInstance):return c.owner_uid!=p.uid).map(func(c:BattleCardInstance):return [c.uid,c.key,c.upgraded])
    check(j.train_move(p.uid,move,0).is_empty() and j.gold==200 and j.rested_steps.is_empty(),"Level training spends only 100, no shared action")
    check(j.train_move(p.uid,other,1).is_empty() and j.gold==0 and j.rested_steps.is_empty(),"Second training in same camp spends only 200")
    check(other_cards==j.deck.filter(func(c:BattleCardInstance):return c.owner_uid!=p.uid).map(func(c:BattleCardInstance):return [c.uid,c.key,c.upgraded]),"Other owners' cards remain unchanged")
    check(RunStatistics.spent(j.statistics)==300,"Both training fees appear in spending totals")
    before=JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,other,1).is_empty() and before==JourneySnapshot.encode(j),"Already-known training cannot spend gold again")
    check(j.rest().is_empty(),"Training leaves the normal camp rest available")
    j.gold=100
    var after_rest:=0
    for id:int in level_moves:
        if TacticalMoves.key_for(id) not in p.learned_skills:after_rest=id;break
    check(after_rest>0 and j.train_move(p.uid,after_rest,2).is_empty() and j.gold==0,"Resting does not prevent later training")
    roundtrip(j)
    var tm:=0
    for id:int in TechnicalMachines.moves(p.species_id):
        if TacticalMoves.key_for(id) not in p.learned_skills:tm=id;break
    j.machines[tm]=1
    check(tm>0 and j.train_move(p.uid,tm,3,true).is_empty() and j.gold==0 and j.machines[tm]==0,"Owned TM remains usable for one consumable, no gold/action")
    roundtrip(j)
    var ui:=PokedexWorkshop.new();ui.journey=j;ui.mode="moves";root.add_child(ui)
    check(ui.rows.get_child_count()==j.training_offers(p.uid).size(),"Training UI shows the entire legal catalog")
    ui.free()
    # Every camp departure multiplies the previous rate by 1.1, regardless of biome boundaries.
    var prior := 100.0
    var camp_count := 0
    for index in j.route.stops.size():
        if j.route.stops[index]["kind"] != "rest":continue
        var probe := TacticalJourney.new(712,"field_kit",[133,4,7],true)
        probe.step=index;probe.phase=TacticalJourney.MAP
        probe.enter_next()
        var at_camp:=probe.gold_progression_percent()
        var untouched:=JourneySnapshot.encode(probe)
        check(is_equal_approx(at_camp,100*pow(1.1,camp_count)) and is_equal_approx(probe.gold_progression_percent(),prior) and untouched==JourneySnapshot.encode(probe),"Staying/reopening at camp never changes the multiplier or RNG")
        check(probe.leave_camp().is_empty() and is_equal_approx(probe.gold_progression_percent(),at_camp*1.1),"Leaving each camp multiplies gain and ordinary spending by 1.1")
        prior=probe.gold_progression_percent();camp_count+=1
    check(camp_count==68 and is_equal_approx(prior,65268.3435371437),"68 departures preserve the requested compound growth")
    var expected_prices := [100,110,121,134,147,162]
    for n in expected_prices.size():
        j.step = n*2
        check(j.scale_gold(100)==expected_prices[n],"Early exact gold progression rounds without floating-point extra gold")
    j.step=1
    for at in [1,35,129,135]:
        var c:=fixture(at)
        check(c.items()["ball"]["price"]==c.scale_gold(35) and c.removal_price()==c.scale_gold(50),"Supply and card-removal quotes share the departure multiplier")
        check(c.train_move_price(c.party[0].uid,level_moves[0])==100 and TechnicalMachines.PRICE==100,"Training and TM prices remain fixed late in the expedition")
        roundtrip(c)
    # Exercise actual shop and event transactions at a later region.
    var merchant:=-1;var lesson:=-1;var satchel:=-1
    for i in j.route.stops.size():
        var stop:Dictionary=j.route.stops[i]
        if stop["kind"]!="rest" or int(stop["chapter"])<2:continue
        var camp:Dictionary=stop["camp"]
        if camp["kind"]=="merchant":merchant=i
        if camp.get("id")=="lesson":lesson=i
        if camp.get("id")=="satchel":satchel=i
    check(merchant>=0 and lesson>=0 and satchel>=0,"Later merchant, paid event and gold reward fixtures exist")
    if merchant>=0:
        var c:=fixture(merchant)
        var raw:Array=c.camp()["card_offers"].duplicate(true)
        var quote:Dictionary=c.shop_cards()[0]
        var gold:=c.gold
        check(quote["price"]==c.scale_gold(raw[0]["price"]-5*int(c.current()["chapter"])) and raw==c.camp()["card_offers"],"Scaled shop view never mutates original saved offers")
        check(c.buy_shop_card(0).is_empty() and c.gold==gold-int(quote["price"]) and c.camp()["card_offers"][0]["sold"],"Shop charges shown price and persists sold state")
        before=JourneySnapshot.encode(c)
        check(not c.buy_shop_card(0).is_empty() and before==JourneySnapshot.encode(c),"Sold card cannot be purchased twice")
        var key:String=c.shop_items()[0];gold=c.gold
        var fee:int=c.items()[key]["price"]
        check(c.buy(key).is_empty() and c.gold==gold-fee,"Supply purchase charges its scaled quote")
        roundtrip(c)
        if not c.camp().get("machine_offers",[]).is_empty():
            gold=c.gold
            check(c.take_machine(0).is_empty() and c.gold==gold-100,"Merchant TM purchase still costs 100 at late stages")
            roundtrip(c)
    if lesson>=0:
        var c:=fixture(lesson);var fee:=c.scale_gold(50);c.gold=fee-1;before=JourneySnapshot.encode(c)
        check(not c.resolve_camp(0).is_empty() and before==JourneySnapshot.encode(c),"Paid event checks scaled funds before mutation")
        c.gold=fee
        check(c.resolve_camp(0).is_empty() and c.gold==0 and RunStatistics.spent(c.statistics)==fee,"Paid lesson charges scaled fee and records it")
        roundtrip(c)
    if satchel>=0:
        var c:=fixture(satchel);var gold:=c.gold
        check(c.resolve_camp(1).is_empty() and c.gold==gold+c.scale_gold(60) and c.loot[-1]["gold"]==c.scale_gold(60),"Event reward and loot record use scaled gold")
        roundtrip(c)
    var reward:=TacticalJourney.new(712,"field_kit",[133,4,7],true)
    for i in reward.route.stops.size():
        if reward.route.stops[i]["kind"]=="wild" and int(reward.route.stops[i]["chapter"])==3:reward.step=i;break
    reward.phase=TacticalJourney.MAP
    check(reward.enter_next().is_empty(),"Start a real later-region battle")
    var gold:=reward.gold
    reward.battle.phase=TacticalBattle.WON
    check(reward.settle().is_empty() and reward.gold==gold+reward.scale_gold(40) and reward.loot[-1]["gold"]==reward.scale_gold(40),"Battle settlement awards the scaled amount exactly once")
    before=JourneySnapshot.encode(reward)
    check(reward.settle().is_empty() and before==JourneySnapshot.encode(reward),"Repeated settlement is a no-op and cannot duplicate gold")
    roundtrip(reward)
    # A real champion reward now exceeds the old 100k per-loot validation cap.
    var final:=TacticalJourney.new(712,"field_kit",[133,4,7],true)
    final.step=136;final.badges=8;final.elite_wins=4
    final.phase=TacticalJourney.MAP
    check(final.enter_next().is_empty(),"Enter final champion at the maximum compound multiplier")
    var champion_reward:=final.battle_gold_reward()
    final.battle.phase=TacticalBattle.WON
    check(final.settle().is_empty() and champion_reward==117484 and final.loot[-1]["gold"]==117484,"Final champion awards exact compound gold beyond 100k")
    var high_save:=fixture(135)
    high_save.gold+=champion_reward
    high_save.loot.append({"name":"고액 전리품","gold":champion_reward,"item":"revive","quantity":1})
    roundtrip(high_save)
    var store:=JourneySave.new("user://compound-final.json")
    check(store.save(high_save).is_empty(),"Actual compound reward can be saved to disk")
    var loaded:=store.load_journey()
    check(loaded!=null and JourneySnapshot.encode(loaded)==JourneySnapshot.encode(high_save),"Disk load retains exact six-digit loot/RNG")
    print("TRAINING_ECONOMY ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
