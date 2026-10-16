extends SceneTree
var checks := 0
var failures := 0
var catalog := VisualCatalog.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func opponent(id: int) -> Dictionary:
    var entry := catalog.species(id)
    var definition := {"id":id,"name":entry["name"],"types":entry["types"],"type":entry["types"][0],"max_hp":PokemonStats.value(id,20,"hp"),"level":20}
    definition.merge(EnemyTactics.build(id,20,entry["types"],"wild",0,1))
    return definition
func fixture() -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.phase = TacticalJourney.MAP
    j.step = 1
    j.enter_next()
    return j
func by_key(entries: Array, key: String) -> Dictionary:
    for entry: Dictionary in entries:
        if entry["card"]["key"] == key: return entry
    return {}
func run() -> void:
    var j := fixture()
    # Explicit coverage fixture: card identities/owners are real, hand order is irrelevant.
    j.deck.clear()
    for key: String in ["move_33","move_52","move_55","move_22","move_165","move_92","move_109"]:
        j.deck.append(j._allocate_card(key,j.party[0].uid))
    for key: String in ["shield_strike","status_cash","guard"]: j.deck.append(j._allocate_card(key,0))
    j.deck[1].upgraded = true
    var before := JourneySnapshot.encode(j)
    var ghost := EncounterPreparation.analyze(j,opponent(355))
    check(by_key(ghost["groups"]["immune"],"move_33")["affinity"] == 0,"Normal attacks are immune against Ghost")
    check(by_key(ghost["groups"]["attack"],"move_165")["affinity"] == 1,"Struggle ignores type immunities exactly as the battle does")
    check(by_key(ghost["groups"]["attack"],"move_52")["card"]["name"].ends_with(" +"),"Preparation preserves actual upgrades and card faces")
    check(by_key(ghost["groups"]["conditional"],"move_92")["label"] == "지속 피해" and by_key(ghost["groups"]["conditional"],"move_109")["label"] == "지속 피해","Poison and confusion are actual ongoing damage paths")
    check(by_key(ghost["groups"]["conditional"],"shield_strike")["label"] == "보호막 필요" and by_key(ghost["groups"]["conditional"],"status_cash")["label"] == "상태 필요","Conditional effects never masquerade as guaranteed direct damage")
    check(by_key(ghost["groups"]["attack"],"shield_strike").is_empty() and by_key(ghost["groups"]["attack"],"guard").is_empty(),"Support and setup-dependent damage are excluded from direct attacks")
    var dual := EncounterPreparation.analyze(j,opponent(74))
    check(by_key(dual["groups"]["attack"],"move_55")["affinity"] == 4 and by_key(dual["groups"]["attack"],"move_52")["affinity"] == 0.5,"Dual types preserve fourfold weakness and resistance")
    check(JourneySnapshot.encode(j) == before,"Coverage does not change deck, card IDs, stats, XP, statuses, resources, RNG or encounters")
    # Compare each displayed attack to the actual engine across representative dual types/immunities.
    for id in [355,74,130,81,292,201,302]:
        var definition := opponent(id)
        var row := EncounterPreparation.analyze(j,definition)
        var battle := TacticalBattle.new()
        var members: Array[BattlePokemon] = []
        for p: BattlePokemon in j.party:
            var copy := BattlePokemon.new(TacticalContent.member_definition(p.species_id,catalog),p.uid)
            TacticalGrowth.initialize(copy)
            members.append(copy)
        battle.start_with(members,j.deck,[definition],42,"field_kit")
        battle.full_type_chart = true
        for card: BattleCardInstance in j.deck:
            var view := battle.card_view(card)
            if not view.has("damage"): continue
            var immune: bool = int(view["preview_damage"]) == 0
            check(not by_key(row["groups"]["immune" if immune else "attack"],card.key).is_empty(),"Displayed immunity agrees with actual attack resolution for %d/%s" % [id,card.key])
    j.party[0].hp = 0
    j.party[0].knocked_out = true
    ghost = EncounterPreparation.analyze(j,opponent(355))
    check(ghost["groups"]["attack"].is_empty() and ghost["groups"]["immune"].is_empty() and ghost["unavailable"] == 7,"A fainted owner cannot supply attack coverage even if their moves are known")
    check(ghost["groups"]["conditional"].size() == 2,"Living allies can still use shared conditional cards")
    for p: BattlePokemon in j.party: p.hp = 0
    check(not EncounterPreparation.analyze(j,opponent(355))["living"] and EncounterPreparation.analyze(j,opponent(355))["groups"]["conditional"].is_empty(),"Without living allies shared cards cannot provide coverage")
    # Known moves without actual deck copies must never be reported as attacks.
    j = fixture()
    j.party[0].learned_skills.assign(["move_84"])
    var keys := j.deck.map(func(c: BattleCardInstance): return c.key)
    ghost = EncounterPreparation.analyze(j,opponent(355))
    check(by_key(ghost["groups"]["attack"],"move_84").is_empty() and "move_84" not in keys,"Preparation uses permanent cards, not the learned-move list")
    before = JourneySnapshot.encode(j)
    var info := EncounterPreparation.describe(j)
    check(info["step"] == 2 and info["enemies"][0]["opponent"] == j.opponents_at(2)[0],"Camp previews the exact next encounter")
    j.phase = TacticalJourney.MAP
    check(EncounterPreparation.describe(j)["step"] == 2,"Map before a camp also previews the next actual battle")
    j.phase = TacticalJourney.REST
    check(JourneySnapshot.encode(j) == before,"Repeated map/camp queries do not mutate the journey")
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] in ["gym","elite","champion"]:
            j.phase = TacticalJourney.MAP
            j.step = i
            var snapshot := JourneySnapshot.encode(j)
            info = EncounterPreparation.describe(j)
            check(info["enemies"].size() == j.route.stops[i]["party"].size() and info["enemies"].map(func(row: Dictionary): return row["opponent"]) == j.opponents_at(i),"The actual gym/league roster count and definitions are preserved: %d" % i)
            check(JourneySnapshot.encode(j) == snapshot,"Boss inspection does not roll rewards, reserve rare hunts or advance routes")
    j = fixture()
    # Explicit reservation boundary: reading must respect, never create, the reservation.
    j.rare_hunt = RareEncounter.initial(j.seed_value)
    j.rare_hunt["battle_step"] = 2
    before = JourneySnapshot.encode(j)
    info = EncounterPreparation.describe(j)
    check(info["enemies"][0]["opponent"]["id"] == j.rare_hunt["target"] and info["title"].contains("조우"),"A reserved rare encounter uses its actual species, level and title")
    check(JourneySnapshot.encode(j) == before,"Rare preparation cannot investigate clues or change reservations")
    j.phase = TacticalJourney.BATTLE
    check(EncounterPreparation.describe(j).is_empty(),"Preparation is available before battle only")
    j = TacticalJourney.new()
    j.phase = TacticalJourney.MAP
    j.step = 2
    info = EncounterPreparation.describe(j)
    check(info["enemies"].size() == 2,"Legacy trials keep their actual opponent count")
    j.phase = TacticalJourney.REST
    j.step = TacticalJourneyContent.STOPS.size()-1
    check(EncounterPreparation.describe(j).is_empty(),"No target is invented beyond the last encounter")
    print("ENCOUNTER_PREPARATION: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
