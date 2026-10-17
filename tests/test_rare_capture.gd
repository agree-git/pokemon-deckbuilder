extends SceneTree
const RareTestSupport = preload("support/rare_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func reload(j: TacticalJourney) -> TacticalJourney:
    var snapshot := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(snapshot),"Rare save validates at "+j.phase+" / "+str(j.step))
    if not JourneySnapshot.validate(snapshot): return j
    var restored := JourneySnapshot.restore(snapshot)
    check(JourneySnapshot.encode(restored) == snapshot,"Target, clues, capture, resources and RNG restore exactly")
    return restored
func unchanged(j: TacticalJourney,action: Callable,message: String) -> void:
    var before := JourneySnapshot.encode(j)
    check(not str(action.call()).is_empty() and JourneySnapshot.encode(j) == before,message)
func run() -> void:
    var catalog := VisualCatalog.new()
    var rare_ids := []
    for species: Dictionary in catalog.pokemon:
        if int(species["id"]) in RareEncounter.IDS: rare_ids.append(int(species["id"]))
    rare_ids.sort()
    check(rare_ids == RareEncounter.IDS,"All 103 supported rare species are candidates")
    var seeds := {}
    for seed_value in 5000:
        var id := RareEncounter.target(seed_value)
        if not seeds.has(id): seeds[id] = seed_value
        check(id == RareEncounter.target(seed_value),"Target is deterministic without route or battle RNG")
    check(seeds.size() == 103,"Every rare species is reachable by a seeded expedition")
    var legacy := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var before := JourneySnapshot.encode(legacy)
    legacy.rare_info()
    legacy.investigate_reason()
    check(JourneySnapshot.encode(legacy) == before and not before["run"].has("rare_hunt"),"Reading a legacy quest does not alter its save or RNG")
    check(JourneySnapshot.validate(before),"Legacy saves remain supported without route reset")
    unchanged(legacy,legacy.investigate,"Cannot investigate in battle")
    for id: int in [144,150,151,483,493,772,773,789,790,791,792,808,809,892,1009,10169,10170,10171,1024,1025]:
        var j := RareTestSupport.fixture(seeds[id])
        var signature := j.route.signature
        var required := RareEncounter.requirement(id)
        var rule := RareEncounter.rule(id)
        check(required == (7 if id in RareEncounter.SUPER_LEGENDARY else (5 if catalog.species(id)["is_mythical"] else 3)),"Super legends require seven badges and clues, mythicals five, sublegends three")
        check(j.rare_hunt["clues"].size() == required and j.rested_steps.size() == required,"Each investigation consumes a distinct camp action")
        unchanged(j,j.investigate,"Full clues cannot consume another camp action")
        j = reload(j)
        var balls := j.balls
        j.balls = int(rule["balls"])-1
        unchanged(j,j.challenge_rare,"Reserve requires three prepared balls")
        j.balls = balls
        j.badges -= 1
        unchanged(j,j.challenge_rare,"Clues do not bypass badge gate")
        j.badges += 1
        var step := j.step
        j.step = required*16+9 # Next is a trainer.
        j._prepare_camp()
        unchanged(j,j.challenge_rare,"Cannot replace trainer, gym or league fights")
        j.step = step
        check(j.challenge_rare().is_empty(),"All gates allow one explicit rare challenge")
        check(j.route.signature == signature and j.route.stops.size() == 137 and j.route.stops[j.step+1]["party"] != [id],"Optional challenge preserves the original 69 battles and 68 camps")
        j = reload(j)
        unchanged(j,j.challenge_rare,"Challenge cannot be reserved twice after reload")
        j.leave_camp()
        j = reload(j)
        check(j.current()["rare"] and j.current()["party"] == [id],"Travel preview shows the reserved target")
        j.enter_next()
        check(j.battle.enemies.size() == 1 and j.battle.enemy().species_id == id and j.battle.enemy().level == mini(100,int(j.route.stops[j.step]["level"])+int(rule["level_bonus"])),"Rare encounter has the correct species, full stats and elevated level")
        check(j.battle.enemy_definitions[0]["tactic"] == "setup","Rare opponent uses stronger veteran tactics")
        j = reload(j)
        RareTestSupport.ready_capture(j)
        j.battle.enemy().hp += 1
        unchanged(j,j.capture,"HP above the tier’s HP threshold cannot capture")
        RareTestSupport.ready_capture(j)
        j.battle.energy = int(rule["energy"])-1
        unchanged(j,j.capture,"One fewer energy is insufficient for a rare capture")
        j.battle.energy = int(rule["energy"])
        j.balls = int(rule["balls"])-1
        unchanged(j,j.capture,"One fewer ball is insufficient for a rare capture")
        j.balls = int(rule["balls"])
        j = reload(j)
        check(j.capture().is_empty() and j.balls == 0 and j.battle.energy == 0,"Valid capture spends the tier’s exact ball and energy cost")
        check(j.battle.statistics["counts"]["energy_spent"] == rule["energy"] and j.battle.statistics["counts"]["captures"] == 1,"Rare capture statistics record the real cost once")
        check(j.rare_hunt["captured"] and id in j.captured_ids and j.pending_captures.size() == 1,"Capture records the permanent collection before settlement")
        j = reload(j)
        unchanged(j,j.capture,"A restarted capture cannot grant another Pokemon or refund resources")
        check(j.settle().is_empty(),"Captured encounter settles normally")
        while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
        check(j.phase == TacticalJourney.CAPTURE and j.wins == 1,"Capture proceeds through growth to the normal party decision")
        j = reload(j)
        var profile := PlayerProfile.new("")
        profile.captured_ids.assign(j.captured_ids)
        check(catalog.starter_species_id(id) in profile.unlocked_starters(catalog),"Every rare capture unlocks its earliest supported level-five starter")
        check(j.resolve_capture(-1).is_empty() and id in j.captured_ids and j.party.size() == 3,"Releasing the captured rare does not revoke the unlock")
        j.choose_reward(-1)
        j.enter_next()
        j = reload(j)
        unchanged(j,j.challenge_rare,"The next camp cannot reroll or replay a completed hunt")
        var bad := JourneySnapshot.encode(j)
        bad["run"]["rare_hunt"]["target"] = 1
        check(not JourneySnapshot.validate(bad),"Reject corrupt target state")
        bad = JourneySnapshot.encode(j)
        bad["run"]["rare_hunt"]["clues"].append(bad["run"]["rare_hunt"]["clues"][0])
        check(not JourneySnapshot.validate(bad),"Reject duplicate or excess clues")
        bad = JourneySnapshot.encode(j)
        bad["run"]["rare_hunt"]["battle_step"] += 2
        check(not JourneySnapshot.validate(bad),"Reject a moved or mismatched rare capture receipt")
    var j := RareTestSupport.fixture(seeds[144])
    RareTestSupport.enter(j)
    j.battle.enemy().hp = 0
    j.battle._outcome()
    j.settle()
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    check(j.phase == TacticalJourney.REWARD and j.captured_ids.is_empty() and j.pending_captures.is_empty(),"Defeating a rare yields a normal reward without a collection unlock")
    j.choose_reward(-1)
    j.enter_next()
    j = reload(j)
    unchanged(j,j.challenge_rare,"Defeating instead of capturing consumes the one challenge")
    var joined := RareTestSupport.fixture(seeds[150])
    RareTestSupport.enter(joined)
    var captured_level := joined.battle.enemy().level
    RareTestSupport.ready_capture(joined)
    check(joined.capture().is_empty(),"Prepare a real rare party replacement")
    joined.settle()
    while joined.phase == TacticalJourney.LEARN: joined.resolve_learning(-1)
    check(joined.resolve_capture(0).is_empty() and joined.party[0].species_id == 150,"A caught superlegend can join the capped three-member party")
    check(joined.party[0].level == captured_level and joined.party[0].uid == 1000,"Joining preserves the captured level and assigns a distinct owner identity")
    check(joined.deck.any(func(c: BattleCardInstance): return c.owner_uid == 1000) and not joined.deck.any(func(c: BattleCardInstance): return c.owner_uid == 1),"Replacement removes the old owner's cards and creates the rare's own techniques")
    joined = reload(joined)
    joined.choose_reward(-1)
    joined.enter_next()
    joined.leave_camp()
    joined.enter_next()
    check(joined.battle.member(1000) == joined.party[0] and joined.party[0].hp > 0,"The captured rare and its cards participate in the next real encounter")
    check(JourneySnapshot.validate(JourneySnapshot.encode(joined)),"A party containing a captured superlegend remains save-compatible")
    var unbound := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    var definition := TacticalContent.member_definition(150,catalog)
    definition["types"] = catalog.species(150)["types"]
    unbound.battle.enemies[0] = BattlePokemon.new(definition,-1)
    unbound.battle.enemy().hp = 1
    unbound.battle.energy = 3
    unbound.balls = 5
    unchanged(unbound,unbound.capture,"Rare capture resources alone cannot bypass the dedicated challenge")
    unbound.step = 10
    unchanged(unbound,unbound.capture,"Trainer encounters remain uncapturable even with rare resources")
    var fresh := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    fresh.phase = TacticalJourney.MAP
    fresh.step = 1
    fresh.enter_next()
    check(fresh.investigate().is_empty(),"A new camp can collect the first clue")
    unchanged(fresh,fresh.investigate,"Re-entering or clicking twice cannot farm the same camp")
    unchanged(fresh,fresh.rest,"Investigation excludes both healing and upgrading")
    fresh = reload(fresh)
    unchanged(fresh,fresh.rest,"Reload cannot reset the shared camp action")
    fresh.restart()
    check(fresh.rare_hunt.is_empty() and fresh.rested_steps.is_empty(),"New expedition resets only its own quest")
    print("RARE_ENCOUNTER: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
