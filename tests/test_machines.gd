extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func fixture(merchant: bool) -> TacticalJourney:
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",[133,129],true)
        j.step = 1
        j.phase = TacticalJourney.MAP
        j.enter_next()
        if (j.camp()["kind"] == "merchant") == merchant and not j.camp()["machine_offers"].is_empty(): return j
    return null
func snapshot(j: TacticalJourney) -> void:
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"TM state validates")
    if JourneySnapshot.validate(data): check(JourneySnapshot.encode(JourneySnapshot.restore(data)) == data,"TM snapshot preserves stock, inventory, cards and RNG exactly")
func run() -> void:
    check(TechnicalMachines.pool().size() == 303,"303 actual machine moves, not all tutor/egg moves")
    check(129 in TechnicalMachines.moves(133) and 24 not in TechnicalMachines.moves(133),"Eevee Swift machine available; Double Kick egg move excluded")
    var data := PokedexExpansion.data()
    for id: String in data["progression"]:
        var compatible := TechnicalMachines.moves(int(id))
        var nonlevel: Array[int] = []
        nonlevel.assign(data["progression"][id]["nonlevel_moves"])
        check(compatible.all(func(move: int): return move in nonlevel),"Machine-only data agrees with selected version "+id)
    var merchants := 0
    var discoveries := 0
    for seed_value in 80:
        var j := TacticalJourney.new(seed_value,"field_kit",[133,129],true)
        var rng := j.battle._rng.state
        j.step = 1
        j.phase = TacticalJourney.MAP
        j.enter_next()
        var offers: Array = j.camp()["machine_offers"]
        var merchant: bool = j.camp()["kind"] == "merchant"
        if merchant: merchants += 1
        elif not offers.is_empty(): discoveries += 1
        check(TechnicalMachines.valid_offers(offers,merchant),"Generated unique valid machine offers")
        check(offers == TechnicalMachines.generate(seed_value,1,j.party,merchant),"Camp machines deterministic on independent seed")
        check(j.battle._rng.state == rng,"Camp generation does not advance battle RNG")
        var before := JourneySnapshot.encode(j)
        j._prepare_camp()
        check(before == JourneySnapshot.encode(j),"Reopening camp cannot reroll machines")
        snapshot(j)
    check(merchants > 0 and discoveries > 0,"Both merchant stock and free camp discovery occur")
    var j := fixture(true)
    var offer: Dictionary = j.camp()["machine_offers"][0]
    var move := int(offer["move"])
    var p := j.party[0]
    var rng := j.battle._rng.state
    j.gold = 0
    var before := JourneySnapshot.encode(j)
    check(not j.take_machine(0).is_empty() and before == JourneySnapshot.encode(j),"Insufficient gold does not mutate anything")
    j.gold = 100
    check(j.take_machine(0).is_empty() and j.gold == 0 and j.machines[move] == 1,"Purchase charges exactly 100 gold and grants one machine")
    before = JourneySnapshot.encode(j)
    check(not j.take_machine(0).is_empty() and before == JourneySnapshot.encode(j),"Sold machine cannot be bought twice")
    snapshot(j)
    # Exact same offer remains sold and no extra machines appear after save/load.
    var store := JourneySave.new("user://machines-test.json")
    check(store.save(j).is_empty(),"TM inventory persists through normal save envelope")
    var loaded: TacticalJourney = store.load_journey()
    check(loaded != null and JourneySnapshot.encode(loaded) == JourneySnapshot.encode(j),"Save/load retains TM stock, acquisition and independent RNG")
    var incompatible := 0
    for id: int in TechnicalMachines.pool():
        if id not in TechnicalMachines.moves(p.species_id): incompatible = id; break
    j.machines[incompatible] = 1
    before = JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,incompatible,0,true).is_empty() and before == JourneySnapshot.encode(j),"Incompatible machine does not consume item or change cards")
    before = JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,move,4,true).is_empty() and before == JourneySnapshot.encode(j),"Invalid slot cannot consume machine")
    check(not j.train_move(999999,move,0,true).is_empty() and before == JourneySnapshot.encode(j),"Invalid target cannot consume machine")
    p.hp = 0
    before = JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,move,0,true).is_empty() and before == JourneySnapshot.encode(j),"Fainted Pokemon cannot consume machine")
    p.hp = p.max_hp
    var old := p.learned_skills[0]
    var copies := j.deck.filter(func(card: BattleCardInstance): return card.owner_uid == p.uid and card.key == old)
    copies[0].upgraded = true
    var uids := copies.map(func(card: BattleCardInstance): return card.uid)
    var other_cards := j.deck.filter(func(card: BattleCardInstance): return card.owner_uid != p.uid).map(func(card: BattleCardInstance): return [card.uid,card.key,card.upgraded])
    j.rested_steps.append(j.step)
    check(j.train_move(p.uid,move,0,true).is_empty() and j.machines[move] == 0,"TM consumes one item even after camp action used")
    check(p.learned_skills[0] == TacticalMoves.key_for(move) and p.learned_skills.size() <= 4,"TM replaces chosen learned slot")
    check(copies.all(func(card: BattleCardInstance): return card.key == TacticalMoves.key_for(move)) and copies.map(func(card: BattleCardInstance): return card.uid) == uids and copies[0].upgraded,"TM preserves each owner card UID and upgrade")
    check(other_cards == j.deck.filter(func(card: BattleCardInstance): return card.owner_uid != p.uid).map(func(card: BattleCardInstance): return [card.uid,card.key,card.upgraded]),"TM does not touch other owners or common cards")
    check(j.battle._rng.state == rng and j.rested_steps == [1],"Using TM changes neither RNG nor camp actions")
    j.machines[move] = 1
    before = JourneySnapshot.encode(j)
    check(not j.train_move(p.uid,move,1,true).is_empty() and before == JourneySnapshot.encode(j),"Already learned move cannot consume duplicate TM")
    snapshot(j)
    var free := fixture(false)
    var gold := free.gold
    check(free.take_machine(0).is_empty() and free.gold == gold and free.rested_steps.is_empty(),"Discovery grants free machine independently of encounter/action")
    check(not free.camp()["resolved"],"Taking discovery leaves the ordinary camp event available")
    snapshot(free)
    var corrupt := JourneySnapshot.encode(j)
    corrupt["run"]["machines"] = {999999:1}
    check(not JourneySnapshot.validate(corrupt),"Unknown machine rejected")
    corrupt["run"]["machines"] = {move:-1}
    check(not JourneySnapshot.validate(corrupt),"Negative machine count rejected")
    corrupt["run"]["machines"] = {str(move):1}
    check(not JourneySnapshot.validate(corrupt),"Machine IDs must be integers")
    corrupt = JourneySnapshot.encode(j)
    corrupt["run"]["camp_states"][j.step]["machine_offers"] = [{"move":move,"taken":1}]
    check(not JourneySnapshot.validate(corrupt),"Malformed stock rejected")
    corrupt = JourneySnapshot.encode(j)
    corrupt["run"].erase("machines")
    for camp: Dictionary in corrupt["run"]["camp_states"].values(): camp.erase("machine_offers")
    check(JourneySnapshot.validate(corrupt) and JourneySnapshot.restore(corrupt).machines.is_empty(),"Pre-TM save accepts absent optional state")
    check(JourneySave.compatible_content("7ce6e0d58dab102bb60728714b36d36cc417cedeb0ed92811261c6339ad15b89"),"Pre-TM content fingerprint remains accepted")
    j.restart()
    check(j.machines.is_empty(),"New expedition clears machine inventory")
    print("Technical machines: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
