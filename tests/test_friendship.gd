extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func member(species: int, level := 10) -> BattlePokemon:
    var p := BattlePokemon.new(TacticalContent.member_definition(species,VisualCatalog.new()),1000)
    p.level = level
    TacticalGrowth.initialize(p)
    return p
func camp_fixture() -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[133,172,298],true)
    j.phase = TacticalJourney.MAP
    j.step = 1
    j.enter_next()
    return j
func source_checks() -> void:
    var file := FileAccess.open("res://assets/sources/csv/pokemon_evolution.csv",FileAccess.READ)
    var header := file.get_csv_line()
    var rows: Array[Dictionary] = []
    while not file.eof_reached():
        var cells := file.get_csv_line()
        if cells.size() != header.size(): continue
        var row := {}
        for i in header.size(): row[header[i]] = cells[i]
        rows.append(row)
    var routes := FriendshipEvolution.ROUTES.duplicate()
    for id in routes:
        check(VisualCatalog.new().species(routes[id])["evolves_from"] == id,"Each friendship route stays within its supported base-form family")
        check(rows.any(func(row: Dictionary): return int(row["evolved_species_id"]) == routes[id] and row["is_default"] == "1" and int(row["minimum_happiness"]) > 0 and row["time_of_day"].is_empty()),"Friendship family matches the pinned canonical source")
    for spec: Array in [[196,"day"],[197,"night"]]:
        check(rows.any(func(row: Dictionary): return int(row["evolved_species_id"]) == spec[0] and int(row["minimum_happiness"]) > 0 and row["time_of_day"] == spec[1] and row["is_default"] == "1"),"Eevee branches retain the original day/night condition")
    check(FriendshipEvolution.THRESHOLD == 220 and routes.size()+2 == 9,"All nine Gen III friendship branches use the original 220 threshold")
func growth_checks() -> void:
    var routes: Array = []
    for id in FriendshipEvolution.ROUTES: routes.append([id,FriendshipEvolution.ROUTES[id],"day"])
    routes.append_array([[133,196,"day"],[133,197,"night"]])
    for spec: Array in routes:
        var p := member(spec[0])
        p.friendship = 217
        p.hp -= 5
        p.held_item = "healing_bell"
        var known := p.learned_skills.duplicate()
        var report := TacticalGrowth.award(p,TacticalGrowth.experience_floor(11,p.species_id)-p.experience,spec[2])
        check(p.species_id == spec[0] and p.friendship == 219 and report["evolutions"].is_empty(),"Below-threshold level gain does not evolve")
        report = TacticalGrowth.award(p,TacticalGrowth.experience_floor(12,p.species_id)-p.experience,spec[2])
        check(p.species_id == spec[1] and p.friendship == 221 and p.level == 12 and report["evolutions"].size() == 1,"Crossing the threshold triggers the advertised form on the actual level-up")
        check(p.uid == 1000 and p.held_item == "healing_bell" and known.all(func(key: String): return key in p.learned_skills),"Friendship evolution preserves identity, equipment and known skills")
        check(p.max_hp-p.hp == 5 and p.max_hp == PokemonStats.value(spec[1],12,"hp") and p.types == VisualCatalog.new().species(spec[1])["types"],"Evolution applies new stats and types without full healing")
        check(report["friendship_before"] == 219 and report["friendship_after"] == 221,"Growth report tracks the exact one-time gain")
        var state := p.snapshot()
        TacticalGrowth.award(p,0,spec[2])
        check(p.snapshot() == state,"Reading or awarding zero XP cannot repeat the evolution or friendship gain")
    var p := member(133)
    p.friendship = 220
    var state := p.snapshot()
    TacticalGrowth.award(p,0,"night")
    check(p.snapshot() == state and p.species_id == 133,"A qualified Eevee still needs a real level-up")
    check(FriendshipEvolution.target(p,"unknown") == 0,"An invalid time cannot silently pick a branch")
    p = member(172)
    p.friendship = 230
    p.hp = 0
    p.knocked_out = true
    var experience := p.experience
    TacticalGrowth.award(p,100000)
    check(p.species_id == 25 and p.hp == 0 and p.knocked_out and p.friendship == 230 and p.experience-experience == 30000,"A fainted Pokemon keeps 30% XP, may evolve, and gains no living-level friendship")
    p = member(41,21)
    p.friendship = 250
    var report := TacticalGrowth.award(p,TacticalGrowth.experience_floor(24,41)-p.experience)
    check(p.species_id == 169 and report["evolutions"].size() == 2 and report["evolutions"][0]["level"] == 22 and report["evolutions"][1]["level"] == 23,"Bulk XP handles Golbat then Crobat at successive levels rather than two evolutions on one level")
    p = member(133,100)
    p.friendship = 220
    TacticalGrowth.award(p,100000,"night")
    check(p.species_id == 133 and p.friendship == 220,"The level cap does not fabricate a level-up for evolution")
    FriendshipEvolution.change(p,999)
    check(p.friendship == 255,"Friendship caps at 255")
    FriendshipEvolution.change(p,-999)
    check(p.friendship == 0,"Friendship cannot go below zero")
func journey_checks() -> void:
    var j := camp_fixture()
    check(j.party.all(func(p: BattlePokemon): return p.friendship == 70) and j.current_time() == "day","New starters begin at 70 friendship and daytime")
    var before := JourneySnapshot.encode(j)
    check(not j.set_time("missing").is_empty() and not j.set_time("day").is_empty() and JourneySnapshot.encode(j) == before,"Invalid or unchanged time choices are atomic")
    check(j.set_time("night").is_empty() and j.current_time() == "night","Camp may choose the next battle's time")
    check(j.party.all(func(p: BattlePokemon): return p.friendship == 70) and j.gold == 100 and j.rested_steps.is_empty(),"Waiting changes no friendship, gold or rest allowance")
    j.party[0].friendship = 218
    j.party[1].hp = 0
    j.party[1].knocked_out = true
    check(j.rest().is_empty() and j.party[0].friendship == 223 and j.party[1].friendship == 75 and j.party[1].alive(),"The once-per-camp rest grants five friendship including revived allies")
    check(j.party[0].species_id == 133,"Reaching the threshold at rest never grants a free evolution")
    before = JourneySnapshot.encode(j)
    check(not j.rest().is_empty() and JourneySnapshot.encode(j) == before,"Repeated rest cannot farm friendship")
    var next := camp_fixture()
    check(next.rest("upgrade",next.deck[0].uid).is_empty() and next.party[0].friendship == 70,"Choosing card upgrade does not also receive rest friendship")
    j.leave_camp()
    before = JourneySnapshot.encode(j)
    check(not j.set_time("day").is_empty() and JourneySnapshot.encode(j) == before,"Time selection is locked outside camp")
    # A real initial wild battle: no HP, energy or outcome override.
    var played := TacticalJourney.new(2026,"field_kit",[133,172,298],true)
    for i in 500:
        if played.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
        var action := TacticalPolicy.action(played.battle)
        check(TacticalPolicy.apply(played.battle,action).is_empty(),"Public card/switch/end actions resolve the friendship fixture battle")
    check(played.battle.phase == TacticalBattle.WON,"The natural first battle can be completed by the fixture party")
    var old_friendship := played.party.map(func(p: BattlePokemon): return p.friendship)
    var old_levels := played.party.map(func(p: BattlePokemon): return p.level)
    var alive := played.party.map(func(p: BattlePokemon): return p.alive())
    check(played.settle().is_empty(),"Settle an actual victory")
    for i in played.party.size():
        var p := played.party[i]
        var expected: int = clampi(int(old_friendship[i])+(8 if alive[i] else -10)+(2*(p.level-int(old_levels[i])) if alive[i] else 0),0,255)
        check(p.friendship == expected,"Victory/fainting and earned levels contribute exactly once")
    before = JourneySnapshot.encode(played)
    check(played.settle().is_empty() and JourneySnapshot.encode(played) == before,"Reopening settlement cannot duplicate friendship")
    # Settlement-only fainting fixture: isolate the penalty from battle policy.
    var fainted := TacticalJourney.new(2026,"field_kit",[133,172,298],true)
    fainted.party[0].friendship = 225
    fainted.party[0].hp = 0
    fainted.party[0].knocked_out = true
    fainted.battle.phase = TacticalBattle.WON
    var xp := fainted.party[0].experience
    var reward := fainted.experience_reward(133)
    fainted.settle()
    check(fainted.party[0].friendship == 215 and fainted.party[0].species_id == 133,"A fainted member loses ten and does not receive living-level friendship")
    check(is_equal_approx(fainted.party[0].experience-xp,roundf(reward*3)/10.0),"Friendship penalties never alter the existing thirty-percent XP award")
    before = JourneySnapshot.encode(fainted)
    check(fainted.settle().is_empty() and JourneySnapshot.encode(fainted) == before,"The fainting penalty is not repeated during settlement reentry")
    var caught := TacticalJourney.new(42,"field_kit",[133,172,298],true)
    caught.party[0].friendship = 255
    caught.battle.enemy().hp = 1 # Legal capture threshold fixture.
    check(caught.capture().is_empty() and caught.pending_captures[0].friendship == 70,"A newly captured member starts at seventy rather than inheriting another member's friendship")
    var stone := camp_fixture()
    stone.party[0].friendship = 219
    stone.inventory["water_stone"] = 1
    check(stone.use_item("water_stone",0).is_empty() and stone.party[0].species_id == 134 and stone.party[0].friendship == 219,"An explicit item branch preserves friendship instead of selecting a day/night branch")
func save_checks() -> void:
    var j := camp_fixture()
    j.party[0].friendship = 219
    j.set_time("night")
    var data := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(data),"New friendship and time fields validate")
    var store := JourneySave.new("user://tests/friendship_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Write friendship and time checkpoint to disk")
    var restored := store.load_journey()
    check(restored != null and JourneySnapshot.encode(restored) == data,"Disk resume retains exact friendship, time, cards and RNG")
    if restored != null:
        var xp := TacticalGrowth.experience_floor(6,133)-j.party[0].experience
        TacticalGrowth.award(j.party[0],xp,j.current_time())
        TacticalGrowth.award(restored.party[0],xp,restored.current_time())
        check(j.party[0].species_id == 197 and JourneySnapshot.encode(restored) == JourneySnapshot.encode(j),"Evolution after reload selects the saved night branch identically")
    for value in [-1,256,2.5,"220"]:
        var broken := data.duplicate(true)
        broken["pokemon"][133]["friendship"] = value
        check(not JourneySnapshot.validate(broken),"Malformed saved friendship is rejected")
    for value in ["dawn",3,""]:
        var broken := data.duplicate(true)
        broken["run"]["time_of_day"] = value
        check(not JourneySnapshot.validate(broken),"Unknown or malformed saved time is rejected")
    var old := data.duplicate(true)
    old["run"].erase("time_of_day")
    for p: Dictionary in old["pokemon"].values(): p.erase("friendship")
    check(JourneySnapshot.validate(old),"Old v3 saves require neither field")
    restored = JourneySnapshot.restore(old)
    check(JourneySnapshot.encode(restored) == old,"Reading and resaving a legacy snapshot does not manufacture new fields")
    var before := JourneySnapshot.encode(restored)
    check(restored.current_time() == "day" and FriendshipEvolution.value(restored.party[0]) == 70 and FriendshipEvolution.summary(restored.party[0],restored.current_time(),VisualCatalog.new()).contains("220") and JourneySnapshot.encode(restored) == before,"Legacy UI fallback reads daytime and 70 without mutating the save")
    restored.rest()
    check(restored.party[0].friendship == 75 and restored.time_of_day.is_empty(),"An actual legacy growth action initializes only the affected friendship state")
func run() -> void:
    source_checks()
    growth_checks()
    journey_checks()
    save_checks()
    print("FRIENDSHIP: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
