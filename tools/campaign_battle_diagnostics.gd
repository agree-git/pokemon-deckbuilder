extends RefCounted
## Measurement snapshots only. Never advances RNG or edits the live run/deck.
static func party_state(members: Array[BattlePokemon]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for p: BattlePokemon in members:
        result.append({"uid":p.uid,"species":p.species_id,"level":p.level,"hp":p.hp,"max_hp":p.max_hp,"skills":p.learned_skills.duplicate()})
    return result

static func route_state(j: TacticalJourney) -> Dictionary:
    var bosses: Array[Dictionary] = []
    for step in j.route.stops.size():
        var stop: Dictionary = j.route.stops[step]
        if stop["kind"] not in ["gym","elite","champion"]: continue
        var trainer: Dictionary = stop["trainer"]
        bosses.append({"step":step,"kind":stop["kind"],"id":trainer.get("leader_id",trainer.get("id","")),"name":stop["name"],"region":trainer.get("region",""),"type":stop["biome"]["type"],"party":stop["party"].map(func(species: Variant): return int(species)),"level":stop["level"]})
    return {"version":j.route.generation,"signature":j.route.signature,"bosses":bosses}

static func begin(j: TacticalJourney) -> Dictionary:
    var coverage: Array[Dictionary] = []
    for definition: Dictionary in j.battle.enemy_definitions:
        var analysis := EncounterPreparation.analyze(j,definition)
        var foe := {"species":int(definition["id"]),"level":int(definition["level"]),"tactic":definition.get("tactic",""),"attack":analysis["groups"]["attack"].size(),"immune":analysis["groups"]["immune"].size(),"conditional":analysis["groups"]["conditional"].size(),"strong":analysis["strong"]}
        coverage.append(foe)
    var attacks := 0
    var fallback := 0
    var living_cards := 0
    for card: BattleCardInstance in j.deck:
        if card.owner_uid != 0 and not j.battle.member(card.owner_uid).alive(): continue
        living_cards += 1
        var view := TacticalContent.definition(card)
        if view.has("damage"):
            attacks += 1
            if int(view.get("move_id",0)) == 165: fallback += 1
    return {"step":j.step,"kind":j.current()["kind"],"place":j.current()["name"],"party_before":party_state(j.party),"deck_size":j.deck.size(),"living_cards":living_cards,"direct_cards":attacks,"fallback_cards":fallback,"coverage":coverage}

static func finish(j: TacticalJourney, entry: Dictionary) -> Dictionary:
    var result := entry.duplicate(true)
    result["outcome"] = j.battle.phase
    result["turns"] = j.battle.turn
    result["party_after"] = party_state(j.party)
    result["opponents_after"] = party_state(j.battle.enemies)
    result["counts"] = j.battle.statistics["counts"].duplicate()
    result["cards"] = j.battle.statistics["cards"].duplicate()
    return result
