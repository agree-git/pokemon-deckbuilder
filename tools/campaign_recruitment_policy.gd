extends RefCounted
## Early ordinary recruitment only; public actions, two catches, bounded patience.
var attempts: Dictionary = {}
var captures: Array[Dictionary] = []
var decisions: Array[Dictionary] = []
var catalog := VisualCatalog.new()
static func value(pokemon: BattlePokemon) -> float:
    var best := 0.0
    for key: String in pokemon.learned_skills:
        best = maxf(best,CampaignPolicy.score(TacticalMoves.definition(key)))
    return pokemon.max_hp+pokemon.attack+pokemon.defense+pokemon.special_attack+pokemon.special_defense+pokemon.speed+3*best
static func candidate(enemy: BattlePokemon) -> BattlePokemon:
    var copy := BattlePokemon.new({"id":enemy.species_id,"name":enemy.display_name,"type":enemy.type,"types":enemy.types,"max_hp":enemy.max_hp,"level":enemy.level},enemy.uid)
    TacticalGrowth.initialize(copy)
    return copy
func choice(j: TacticalJourney, caught: BattlePokemon) -> int:
    var family := catalog.starter_species_id(caught.species_id)
    if j.party.any(func(p: BattlePokemon): return catalog.starter_species_id(p.species_id) == family): return -1
    if j.party.size() < 3: return 0
    var worst := 0
    for i in j.party.size():
        if value(j.party[i]) < value(j.party[worst]): worst = i
    return worst if value(caught) > value(j.party[worst])*1.15 else -1
func wants(j: TacticalJourney) -> bool:
    return j.full_campaign and j.phase == TacticalJourney.BATTLE and j.current()["kind"] == "wild" and int(j.current()["chapter"]) == 0 and not j.current().get("rare",false) and captures.size() < 2 and j.balls > 0 and choice(j,candidate(j.battle.enemy())) >= 0
func action(j: TacticalJourney) -> Array:
    var b := j.battle
    if b.phase != TacticalBattle.PLAYER or not wants(j): return CampaignPolicy.action(j)
    if not attempts.has(j.step): attempts[j.step] = b.turn
    if b.turn-int(attempts[j.step]) >= 3: return CampaignPolicy.action(j)
    if j.capture_reason().is_empty(): return ["capture"]
    var best := -1.0
    var uid := 0
    var threshold := floori(b.enemy().max_hp*0.25)
    for card: BattleCardInstance in b.hand:
        if not b.card_reason(card.uid).is_empty(): continue
        var view := b.card_view(card)
        if ["burn","poison","seed","cash","shield_attack","bonus","strength","temporary_strength"].any(func(key: String): return view.has(key)): continue
        var dealt := maxi(0,int(view.get("preview_damage",0))-b.enemy().block)
        var remaining := b.enemy().hp-dealt
        if remaining <= 0: continue
        if dealt > 0 and remaining <= threshold and b.energy-int(view["cost"]) < 1: continue
        var score := float(dealt)*2
        if dealt > 0 and remaining <= threshold: score += 300
        if view.has("draw"): score += int(view["draw"])*4
        if view.has("energy"): score += int(view["energy"])*10
        if view.has("block"): score += mini(int(view.get("preview_block",0)),int(b.intent().get("value",0)))
        if view.has("heal"): score += mini(int(view.get("preview_heal",0)),b.active().max_hp-b.active().hp)
        if score > best and score > 0:
            best = score
            uid = card.uid
    return ["card",uid] if uid != 0 else ["end"]
func apply(j: TacticalJourney, step: Array) -> String:
    if step[0] != "capture": return CampaignPolicy.apply(j,step)
    var species := j.battle.enemy().species_id
    var error := j.capture()
    if error.is_empty(): captures.append({"step":j.step,"species":species})
    return error
func resolve(j: TacticalJourney) -> String:
    var caught := j.pending_captures[0]
    var index := choice(j,caught)
    var leaving := j.party[index].species_id if index >= 0 and j.party.size() == 3 else 0
    var error := j.resolve_capture(index)
    if error.is_empty(): decisions.append({"species":caught.species_id,"step":j.step,"joined":index >= 0,"replaced":leaving})
    return error
