extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    var j := TacticalJourney.new(2026,"field_kit",[891,808,789],true)
    j.step = 1
    j.phase = TacticalJourney.MAP
    j.enter_next()
    for key: String in ["darkness_scroll","metal_candy"]: j.inventory[key] = 1
    check(j.use_item("darkness_scroll",0).is_empty() and j.party[0].species_id == 892 and j.party[0].uid == 891,"Kubfu camp evolution preserves identity")
    check(j.use_item("metal_candy",1).is_empty() and j.party[1].species_id == 809 and j.party[1].uid == 808,"Meltan camp evolution preserves identity")
    check(j.inventory["darkness_scroll"] == 0 and j.inventory["metal_candy"] == 0,"Evolution consumes exactly one owned material")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Camp rare evolution is save compatible")
    var p := j.party[2]
    TacticalGrowth.award(p,TacticalGrowth.experience_floor(43,789)-p.experience)
    check(p.species_id == 790 and p.level == 43,"Cosmog automatically evolves at Lv43")
    TacticalGrowth.award(p,TacticalGrowth.experience_floor(53,790)-p.experience,"day")
    check(p.species_id == 791 and p.level == 53 and p.uid == 789,"Cosmoem automatically evolves by expedition time")
    var pool := [BattlePokemon.new(TacticalContent.member_definition(150,VisualCatalog.new()),150)]
    var party: Array[BattlePokemon] = []
    party.assign(pool)
    for s in 50:
        check(EvolutionItems.merchant_offer(s,2,party) not in ["darkness_scroll","metal_candy"],"New materials do not alter unrelated merchant stock")
    print("RARE_GROWTH ",checks," checks / ",failures," failures")
    await process_frame
    quit(0 if failures == 0 else 1)
