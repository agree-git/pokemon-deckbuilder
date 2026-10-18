class_name EncounterPreparation
extends RefCounted
## Read-only type coverage of the actual permanent deck and living owners.
static func upcoming(j: TacticalJourney) -> Dictionary:
    if j.phase not in [TacticalJourney.MAP,TacticalJourney.REST,TacticalJourney.LEARN]: return {}
    var stops: Array = j.route.stops if j.full_campaign else TacticalJourneyContent.STOPS
    var index := j.step+1 if j.phase in [TacticalJourney.REST,TacticalJourney.LEARN] else j.step
    if index < stops.size() and stops[index]["kind"] == "rest": index += 1
    if index >= stops.size(): return {}
    var stop: Dictionary = stops[index]
    if j.full_campaign and j.rare_hunt.get("battle_step",-1) == index:
        if not RareEncounter.identity_known(j):
            return {"step":index,"title":"희귀 조우 · ???","opponents":[],"hidden":true}
        stop = RareEncounter.node(stop,int(j.rare_hunt["target"]))
    return {"step":index,"title":stop["name"],"opponents":j.opponents_at(index)}
static func describe(j: TacticalJourney) -> Dictionary:
    if j.phase not in [TacticalJourney.MAP,TacticalJourney.REST]: return {}
    var target := upcoming(j)
    if target.is_empty(): return {}
    var enemies: Array[Dictionary] = []
    for definition: Dictionary in target["opponents"]: enemies.append(analyze(j,definition))
    return {"step":target["step"],"title":target["title"],"enemies":enemies,"hidden":target.get("hidden",false)}
static func analyze(j: TacticalJourney, definition: Dictionary) -> Dictionary:
    return analyze_cards(j,definition,j.deck)
static func compare(j: TacticalJourney, cards: Array[BattleCardInstance]) -> Dictionary:
    var target := upcoming(j)
    var coverage: Array[Dictionary] = []
    for definition: Dictionary in target.get("opponents",[]):
        var before := analyze(j,definition)
        var after := analyze_cards(j,definition,cards)
        coverage.append({"opponent":definition.duplicate(true),"attack":[before["groups"]["attack"].size(),after["groups"]["attack"].size()],"strong":[before["strong"],after["strong"]],"conditional":[before["groups"]["conditional"].size(),after["groups"]["conditional"].size()]})
    return {"target":target,"coverage":coverage}
static func analyze_cards(j: TacticalJourney, definition: Dictionary, cards: Array[BattleCardInstance]) -> Dictionary:
    var target := BattlePokemon.new(definition,-1)
    var groups := {"attack":[],"immune":[],"conditional":[]}
    var unavailable := 0
    var strong := 0
    var living := j.party.any(func(p: BattlePokemon): return p.alive())
    for card: BattleCardInstance in cards:
        var owner: BattlePokemon
        if card.owner_uid != 0:
            for p: BattlePokemon in j.party:
                if p.uid == card.owner_uid: owner = p
            if owner == null or not owner.alive():
                unavailable += 1
                continue
        elif not living: continue
        var view := TacticalContent.definition(card,PlayerTechniques.version(j.route.generation) if j.full_campaign else 1)
        view["owner_name"] = owner.display_name if owner != null else ""
        view["species_id"] = owner.species_id if owner != null else 0
        if view.has("damage"):
            var affinity := 1.0 if int(view.get("move_id",0)) == 165 else (TypeMatchup.multiplier(view.get("type","normal"),target.types) if j.full_campaign else BattleContent.multiplier(view.get("type","normal"),target.type))
            var entry := {"card":view,"affinity":affinity,"label":"타격 무효" if affinity == 0 else "상성 ×"+String.num(affinity,2).trim_suffix(".0")}
            groups["immune" if affinity == 0 else "attack"].append(entry)
            if affinity > 1: strong += 1
        # Current battle rules apply these effects independently of attack typing.
        # Shield conversion and status cash need setup, so never count as direct attacks.
        var ongoing: bool = ["burn","poison","seed","confusion"].any(func(key: String): return view.has(key))
        if ongoing or view.has("shield_attack") or view.has("cash") or view.has("pulse_status"):
            groups["conditional"].append({"card":view,"label":"지속 피해" if ongoing else ("보호막 필요" if view.has("shield_attack") else "상태 필요")})
    return {"opponent":definition.duplicate(true),"groups":groups,"strong":strong,"unavailable":unavailable,"living":living}
