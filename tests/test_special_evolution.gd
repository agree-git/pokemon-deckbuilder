extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(starters: Array[int]) -> TacticalJourney:
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",starters,true)
        if j.route.stops[1]["camp"]["kind"] != "merchant": continue
        j.phase = TacticalJourney.MAP
        j.step = 1
        j.enter_next()
        return j
    check(false,"Find a reproducible first-camp merchant")
    return null
func member(species: int, level: int) -> BattlePokemon:
    var p := BattlePokemon.new(TacticalContent.member_definition(species,VisualCatalog.new()),species)
    p.level = level
    TacticalGrowth.initialize(p)
    return p
func advance(p: BattlePokemon, level: int) -> Dictionary:
    return TacticalGrowth.award(p,(TacticalGrowth.experience_floor(level,p.species_id)-p.experience)/(1.0 if p.alive() else 0.3))
func coverage_checks() -> void:
    var edges := {}
    var ordinary: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolutions.json"))
    for rule: Dictionary in ordinary: edges["%d:%d" % [rule["from"],rule["to"]]] = true
    for id in EvolutionItems.ROUTES:
        for target in EvolutionItems.ROUTES[id].values(): edges["%d:%d" % [id,target]] = true
    for id in FriendshipEvolution.ROUTES: edges["%d:%d" % [id,FriendshipEvolution.ROUTES[id]]] = true
    for edge: Array in [[133,196],[133,197],[236,106],[236,107],[236,237],[265,266],[265,268],[349,350],[290,292]]: edges["%d:%d" % edge] = true
    var catalog := VisualCatalog.new()
    var families := {}
    for p: Dictionary in catalog.pokemon:
        if int(p["evolves_from"]) > 0 and int(p["evolves_from"]) <= 386: families["%d:%d" % [p["evolves_from"],p["id"]]] = true
    check(edges == families and edges.size() == 184,"All 184 supported Gen 1–3 family edges have a growth/item/conditional path")
    var file := FileAccess.open("res://assets/sources/csv/pokemon_evolution.csv",FileAccess.READ)
    var header := file.get_csv_line()
    var rows: Array[Dictionary] = []
    while not file.eof_reached():
        var cells := file.get_csv_line()
        if cells.size() != header.size(): continue
        var row := {}
        for i in header.size(): row[header[i]] = cells[i]
        rows.append(row)
    for spec: Array in [[106,"1"],[107,"-1"],[237,"0"]]:
        check(rows.any(func(r: Dictionary): return r["evolved_species_id"] == str(spec[0]) and r["relative_physical_stats"] == spec[1] and r["minimum_level"] == "20"),"Tyrogue stat comparison matches the original source")
    for id in [266,268]:
        check(rows.any(func(r: Dictionary): return r["evolved_species_id"] == str(id) and r["version_group_id"] == "5" and r["minimum_level"] == "7" and r["percentage_chance"] == "50"),"Wurmple retains both original personality branches")
    check(rows.any(func(r: Dictionary): return r["evolved_species_id"] == "350" and r["version_group_id"] == "5" and r["minimum_beauty"] == "170"),"Milotic uses original beauty rather than the later trade item")
    check(rows.any(func(r: Dictionary): return r["evolved_species_id"] == "292" and r["evolution_trigger_id"] == "4"),"Shedinja is an additional spawn rather than replacing Ninjask")
func training_checks() -> void:
    for spec: Array in [["attack",106],["defense",107],["balanced",237]]:
        var j := fixture([236,4])
        var p := j.party[0]
        p.level = 19
        p.experience = TacticalGrowth.experience_floor(19,236)
        PokemonStats.apply(p,true)
        if spec[0] != "balanced": check(j.train_evolution(p.uid,spec[0]).is_empty(),"Prepare the chosen training style")
        var hp := p.hp
        var known := p.learned_skills.duplicate()
        var effort := 32 if spec[0] == "attack" else 0
        check(p.attack == PokemonStats.value(236,19,"attack",effort) and PokemonStats.effective(p,"attack") == p.attack,"Training uses the real EV formula in both stats and combat")
        var row := BattleFrame.member(p)
        check(BattleFrame.restore(row).attack == p.attack and BattleFrame.restore(row).defense == p.defense,"Animation frames retain trained stats")
        p.stat_stages["attack"] = 6
        p.stat_stages["defense"] = -6
        var report := advance(p,20)
        check(p.species_id == spec[1] and p.level == 20 and report["evolutions"].size() == 1,"Permanent stat comparison selects the right form despite temporary stages")
        check(p.uid == 236 and p.evolution_training == ("" if spec[0] == "balanced" else spec[0]) and known.all(func(k: String): return k in p.learned_skills) and p.hp >= hp,"Evolution retains identity, moves and training")
        var data := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(data) and JourneySnapshot.encode(JourneySnapshot.restore(data)) == data,"Every trained branch saves exact stats and EV state")
        check(not j.train_evolution(p.uid,"attack").is_empty(),"Training cannot be changed after Tyrogue evolves")
    var j := fixture([236,4])
    var before := JourneySnapshot.encode(j)
    check(not j.train_evolution(999,"attack").is_empty() and not j.train_evolution(236,"speed").is_empty() and not j.train_evolution(4,"attack").is_empty() and JourneySnapshot.encode(j) == before,"Invalid training inputs are atomic")
    j.train_evolution(236,"attack")
    j.train_evolution(236,"balanced")
    check(j.party[0].attack == j.party[0].defense and j.gold == 100 and j.rested_steps.is_empty(),"Returning to balanced resets the EV choice without free healing or rest use")
func branch_checks() -> void:
    for remainder in 10:
        var p := member(265,6)
        p.evolution_personality = remainder<<16
        var personality := p.evolution_personality
        advance(p,7)
        check(p.species_id == (266 if remainder < 5 else 268) and p.evolution_personality == personality,"The personality's upper half selects the original five/five split")
        advance(p,12)
        check(p.species_id == (267 if remainder < 5 else 269),"Bulk XP continues through the chosen cocoon to its final form")
    var counts := {266:0,268:0}
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",[265,4],true)
        var p := j.party[0]
        var saved := JourneySnapshot.encode(j)
        var signature := j.route.signature
        var state := j.battle._rng.state
        SpecialEvolution.summary(p,2,j.balls,VisualCatalog.new())
        SpecialEvolution.assign_personality(p,seed_value+1)
        check(JourneySnapshot.encode(j) == saved and j.route.signature == signature and j.battle._rng.state == state,"Preview and reassigning an existing personality cannot reroll or consume gameplay RNG")
        var resumed := JourneySnapshot.restore(saved)
        advance(p,7)
        advance(resumed.party[0],7)
        check(p.species_id == resumed.party[0].species_id,"A restored Wurmple takes the same branch")
        counts[p.species_id] += 1
    check(counts[266] > 25 and counts[268] > 25,"Both personality branches occur across seeded expeditions")
func beauty_checks() -> void:
    var j := fixture([349,4])
    check(j.camp()["evolution_offer"] == "blue_pokeblock" and j.shop_stock["blue_pokeblock"] == 3,"A Feebas party receives enough finite beauty supplies")
    j.gold = 180
    var p := j.party[0]
    var xp := p.experience
    var hp := p.hp
    var friendship := p.friendship
    for i in 3:
        check(j.buy("blue_pokeblock").is_empty() and j.use_item("blue_pokeblock",0).is_empty(),"Purchase and feed one real item")
        check(p.beauty == (i+1)*60 and p.species_id == 349 and p.experience == xp and p.hp == hp and p.friendship == friendship,"Feeding raises only beauty, without immediate evolution, HP, XP or friendship")
    var before := JourneySnapshot.encode(j)
    check(j.gold == 0 and j.shop_stock["blue_pokeblock"] == 0 and not j.buy("blue_pokeblock").is_empty() and JourneySnapshot.encode(j) == before,"Three supplies sell out and share the regular gold budget")
    check(j.statistics["counts"]["items_used"] == 3 and j.statistics["counts"]["camp_healing"] == 0,"Beauty food does not inflate healing totals")
    check(JourneySnapshot.validate(before) and JourneySnapshot.encode(JourneySnapshot.restore(before)) == before,"Beauty and sold stock restore exactly")
    TacticalGrowth.award(p,0)
    check(p.species_id == 349,"The beauty threshold still requires an earned level")
    var report := advance(p,6)
    check(p.species_id == 350 and p.beauty == 180 and report["evolutions"].size() == 1,"Original beauty 170 condition triggers Milotic at the next level")
    j = fixture([349,4])
    j.inventory["blue_pokeblock"] = 4
    for index in [-1,1,3]:
        before = JourneySnapshot.encode(j)
        check(not j.use_item("blue_pokeblock",index).is_empty() and JourneySnapshot.encode(j) == before,"Invalid indices/species never spend beauty food")
    j.party[0].hp = 0
    before = JourneySnapshot.encode(j)
    check(not j.use_item("blue_pokeblock",0).is_empty() and JourneySnapshot.encode(j) == before,"Fainted Feebas must recover before feeding")
func shedinja_checks() -> void:
    for spec: Array in [[2,1,true],[3,1,true],[2,0,true],[2,1,false]]:
        var starters: Array[int] = [290,4]
        if spec[0] == 3: starters.append(7)
        var j := TacticalJourney.new(2026,"field_kit",starters,true)
        var parent := j.party[0]
        parent.level = 19
        parent.experience = TacticalGrowth.experience_floor(20,290)-0.1
        PokemonStats.apply(parent,true)
        if not spec[2]:
            parent.hp = 0
            parent.knocked_out = true
        j.balls = spec[1]
        j.deck[0].upgraded = true
        var cards := j.deck.duplicate()
        var uid := j._next_pokemon_uid
        j.battle.phase = TacticalBattle.WON # Settlement-only boundary fixture.
        j.settle()
        check(parent.species_id == 291,"Nincada evolves to Ninjask regardless of the extra-member conditions")
        var joined: bool = spec[0] < 3 and spec[1] > 0
        check(j.party.size() == (3 if joined else spec[0]) and j.balls == (0 if joined else spec[1]) and j._next_pokemon_uid == uid+(1 if joined else 0),"Only a free slot and ball permit one additional member")
        check(j.growth_reports.size() == spec[0],"A newborn is not awarded this battle's XP again")
        if joined:
            var child: BattlePokemon = j.party.back()
            check(child.species_id == 292 and child.uid == uid and child.max_hp == 1 and child.hp == (1 if spec[2] else 0),"The new Shedinja has unique identity, one HP and the parent's fainted condition")
            check(child.level == parent.level and child.experience == parent.experience and child.learned_skills == parent.learned_skills and child.held_item.is_empty(),"A newborn inherits growth and known techniques without duplicating equipment")
            check(j.deck.any(func(c: BattleCardInstance): return c.owner_uid == uid) and j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == uid).all(func(c: BattleCardInstance): return not c.upgraded) and cards.all(func(c: BattleCardInstance): return c in j.deck),"New technique copies have their own owner and do not duplicate upgrades or remove old cards")
            check(292 not in j.captured_ids,"Additional evolution is not a capture or permanent unlock")
        var before := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(before) and JourneySnapshot.encode(JourneySnapshot.restore(before)) == before,"The additional member, cards, birth UID and ball cost persist")
        check(j.settle().is_empty() and JourneySnapshot.encode(j) == before,"Repeated settlement cannot create another Shedinja")
func save_checks() -> void:
    var j := fixture([236,265,349])
    j.train_evolution(236,"defense")
    j.inventory["blue_pokeblock"] = 1
    j.use_item("blue_pokeblock",2)
    var data := JourneySnapshot.encode(j)
    for spec: Array in [[236,"evolution_training","speed"],[265,"evolution_personality",-1],[265,"evolution_personality",4294967296],[349,"beauty",256],[349,"beauty","170"]]:
        var broken := data.duplicate(true)
        broken["pokemon"][spec[0]][spec[1]] = spec[2]
        check(not JourneySnapshot.validate(broken),"Malformed saved conditional growth fields are rejected")
    var old := data.duplicate(true)
    for p: Dictionary in old["pokemon"].values():
        for key: String in ["evolution_personality","evolution_training","beauty"]: p.erase(key)
    check(JourneySnapshot.validate(old),"Legacy saves require none of the new fields")
    var restored := JourneySnapshot.restore(old)
    for p: BattlePokemon in restored.party: SpecialEvolution.summary(p,3,restored.balls,VisualCatalog.new())
    check(JourneySnapshot.encode(restored) == old,"Legacy default previews do not manufacture saved state")
func run() -> void:
    coverage_checks()
    training_checks()
    branch_checks()
    beauty_checks()
    shedinja_checks()
    save_checks()
    print("SPECIAL_EVOLUTION: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
