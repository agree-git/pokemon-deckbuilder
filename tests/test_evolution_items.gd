extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(species := 25) -> TacticalJourney:
    var j := TacticalJourney.new(2026,"field_kit",[species,1,4],true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] == "rest" and j.route.stops[i]["camp"]["kind"] == "merchant":
            j.phase = TacticalJourney.MAP
            j.step = i
            j.enter_next()
            return j
    check(false,"Fixture has a seeded merchant")
    return j
func content_checks() -> void:
    var catalog := VisualCatalog.new()
    var file := FileAccess.open("res://assets/sources/csv/pokemon_evolution.csv",FileAccess.READ)
    var header := file.get_csv_line()
    var source: Array[Dictionary] = []
    while not file.eof_reached():
        var cells := file.get_csv_line()
        if cells.size() != header.size(): continue
        var row := {}
        for i in header.size(): row[header[i]] = cells[i]
        source.append(row)
    var item_ids := {"sun_stone":"80","moon_stone":"81","fire_stone":"82","thunder_stone":"83","water_stone":"84","leaf_stone":"85","kings_rock":"198","metal_coat":"210","dragon_scale":"212","upgrade":"229","deep_sea_tooth":"203","deep_sea_scale":"204"}
    var count := 0
    for species: int in EvolutionItems.ROUTES:
        for key: String in EvolutionItems.ROUTES[species]:
            count += 1
            var target := EvolutionItems.target(key,species)
            check(target >= 1 and target <= 386 and catalog.species(target)["evolves_from"] == species,"Every route is an actual Gen 1–3 evolution family")
            check(EvolutionItems.ITEMS.has(key),"Every route has an obtainable material")
            var trade := not key.ends_with("stone")
            check(source.any(func(row: Dictionary):
                return row["evolved_species_id"] == str(target) and row["is_default"] == "1" and row["evolution_trigger_id"] == ("2" if trade else "3") and row["region_id"].is_empty() and row["evolved_pokemon_form_id"].is_empty() and row["required_pokemon_form_id"] in ["",str(species)] and row["held_item_id" if trade else "trigger_item_id"] == str(item_ids.get(key,""))),"Each curated stone/trade material agrees with the pinned base-form evolution source")
    check(count == 33 and EvolutionItems.ITEMS.size() == 13,"Scope is 21 stone and 12 trade evolutions with thirteen materials")
    check(EvolutionItems.target("water_stone",133) == 134 and EvolutionItems.target("thunder_stone",133) == 135 and EvolutionItems.target("fire_stone",133) == 136,"Eevee's three item branches are explicit")
    check(EvolutionItems.target("leaf_stone",44) == 45 and EvolutionItems.target("sun_stone",44) == 182 and EvolutionItems.target("water_stone",61) == 62 and EvolutionItems.target("kings_rock",61) == 186,"Gloom and Poliwhirl branches do not collapse")
    check(EvolutionItems.target("deep_sea_tooth",366) == 367 and EvolutionItems.target("deep_sea_scale",366) == 368,"Clamperl branches retain their own material")
    check(EvolutionItems.target("fire_stone",1) == 0 and EvolutionItems.target("missing",25) == 0,"Unrelated items and species have no evolution")
func action_checks() -> void:
    for species: int in EvolutionItems.ROUTES:
        for key: String in EvolutionItems.ROUTES[species]:
            var j := fixture(species)
            var p := j.party[0]
            p.level = 40
            p.experience = TacticalGrowth.experience_floor(40,species)+12.3
            PokemonStats.apply(p,true)
            p.hp -= 7
            p.held_item = "healing_bell"
            j.deck.back().upgraded = true
            j.inventory[key] = 1
            var identity := p.uid
            var xp := p.experience
            var known := p.learned_skills.duplicate()
            var cards := j.deck.map(func(c: BattleCardInstance): return JourneySnapshot.fields(c,JourneySnapshot.CARD_FIELDS))
            var money := j.gold
            var reports := j.growth_reports.duplicate(true)
            check(j.item_reason(key,0).is_empty(),"A compatible living Pokemon may evolve even at full or partial HP")
            check(j.use_item(key,0).is_empty() and p.species_id == EvolutionItems.target(key,species),"The chosen material performs exactly the advertised evolution")
            check(p.uid == identity and p.level == 40 and p.experience == xp and p.learned_skills == known and p.held_item == "healing_bell","Evolution retains identity, experience, level, moves and held equipment")
            check(p.max_hp-p.hp == 7 and p.max_hp == PokemonStats.value(p.species_id,40,"hp") and p.types == VisualCatalog.new().species(p.species_id)["types"],"New species stats and dual type preserve missing HP")
            check(j.deck.map(func(c: BattleCardInstance): return JourneySnapshot.fields(c,JourneySnapshot.CARD_FIELDS)) == cards,"Every owned card and its upgrade remain connected")
            check(j.inventory[key] == 0 and j.gold == money and j.rested_steps.is_empty() and j.phase == TacticalJourney.REST and j.growth_reports == reports,"Only one material is spent, without XP, money, rest or settlement side effects")
            check(j.statistics["counts"]["items_used"] == 1 and j.statistics["counts"]["camp_healing"] == 0 and j.statistics["choices"].back().contains("진화"),"Successful evolution records one item and a choice, without healing inflation")
            var data := JourneySnapshot.encode(j)
            check(not j.use_item(key,0).is_empty() and JourneySnapshot.encode(j) == data,"Repeating a spent or stale target cannot consume or evolve again")
            check(JourneySnapshot.validate(data) and JourneySnapshot.encode(JourneySnapshot.restore(data)) == data,"Every branch saves and restores exact species, items, cards and RNG")
    var j := fixture()
    j.inventory["thunder_stone"] = 2
    for index in [-1,1,3]:
        var before := JourneySnapshot.encode(j)
        check(not j.use_item("thunder_stone",index).is_empty() and JourneySnapshot.encode(j) == before,"Invalid indices and incompatible members are atomic")
    j.party[0].hp = 0
    j.party[0].knocked_out = true
    var before := JourneySnapshot.encode(j)
    check(not j.use_item("thunder_stone",0).is_empty() and JourneySnapshot.encode(j) == before,"A fainted target must recover before item evolution")
    j.phase = TacticalJourney.MAP
    before = JourneySnapshot.encode(j)
    check(not j.use_item("thunder_stone",0).is_empty() and JourneySnapshot.encode(j) == before,"Evolution cannot run outside camp")
    j = fixture(25)
    j.inventory["thunder_stone"] = 1
    var p := j.party[0]
    var known := p.learned_skills.duplicate()
    j.use_item("thunder_stone",0)
    j.leave_camp()
    check(j.enter_next().is_empty() and j.phase == TacticalJourney.BATTLE and j.battle.party[0] == p and p.species_id == 26,"The evolved Pokemon enters the next actual encounter with the same identity")
    var piles := j.battle.hand+j.battle.draw_pile+j.battle.discard+j.battle.exhausted
    check(p.learned_skills == known and piles.size() == j.deck.size() and j.deck.all(func(c: BattleCardInstance): return c in piles),"The next battle retains the learned moves and complete deck")
    var next_level := TacticalGrowth.experience_floor(p.level+1,p.species_id)
    var report := TacticalGrowth.award(p,next_level-p.experience)
    check(report["after"] == 6 and p.species_id == 26,"Subsequent XP growth uses the evolved species without granting a level for the item")
func merchant_checks() -> void:
    var j := fixture()
    check(j.camp()["evolution_offer"] == "thunder_stone" and j.shop_items().size() == 4,"A Pikachu party receives a targeted fourth supply")
    var before := JourneySnapshot.encode(j)
    check(not j.buy("thunder_stone").is_empty() and JourneySnapshot.encode(j) == before,"Material purchase respects the same limited gold budget")
    j.gold = 180
    check(j.buy("thunder_stone").is_empty() and j.gold == 0 and j.quantity("thunder_stone") == 1 and j.shop_stock["thunder_stone"] == 0,"Exact-price purchase charges once and sells out")
    before = JourneySnapshot.encode(j)
    check(not j.buy("thunder_stone").is_empty() and JourneySnapshot.encode(j) == before,"Sold materials cannot be duplicated")
    var store := JourneySave.new("user://tests/evolution_%d/journey.json" % Time.get_ticks_usec())
    check(store.save(j).is_empty(),"Write a purchased evolution material to disk")
    var resumed := store.load_journey()
    check(resumed != null and JourneySnapshot.encode(resumed) == before,"A fresh disk restore preserves the purchased material and sold stock")
    if resumed != null:
        check(resumed.use_item("thunder_stone",0).is_empty() and j.use_item("thunder_stone",0).is_empty() and JourneySnapshot.encode(resumed) == JourneySnapshot.encode(j),"Evolution after resume matches uninterrupted play")
    var old := JourneySnapshot.encode(j)
    var camp: Dictionary = old["run"]["camp_states"][j.step]
    camp.erase("evolution_offer")
    camp["stock"].erase("thunder_stone")
    old["run"]["inventory"].erase("thunder_stone")
    check(JourneySnapshot.validate(old),"Old v3 camps and inventories require no new fields")
    resumed = JourneySnapshot.restore(old)
    check(JourneySnapshot.encode(resumed) == old and not resumed.camp().has("evolution_offer"),"Previously visited merchants do not gain or reroll material stock")
    for edit: Dictionary in [{"evolution_offer":"missing"},{"evolution_offer":23}]:
        var broken := before.duplicate(true)
        broken["run"]["camp_states"][j.step].merge(edit,true)
        check(not JourneySnapshot.validate(broken),"Malformed saved material offers are rejected")
    for count in [-1,2]:
        var broken := before.duplicate(true)
        broken["run"]["camp_states"][j.step]["stock"]["thunder_stone"] = count
        check(not JourneySnapshot.validate(broken),"Saved material stock stays in zero to one")
    var broken := before.duplicate(true)
    broken["run"]["inventory"]["missing"] = 1
    check(not JourneySnapshot.validate(broken),"Unknown bag materials are rejected")
    for seed_value in 100:
        var party: Array[BattlePokemon] = [BattlePokemon.new(TacticalContent.member_definition(133,VisualCatalog.new()),133)]
        var offer := EvolutionItems.merchant_offer(seed_value,1,party)
        check(offer in EvolutionItems.options(133) and offer == EvolutionItems.merchant_offer(seed_value,1,party),"Targeted stock is seedable and includes only relevant branches")
        party[0].species_id = 63
        check(EvolutionItems.merchant_offer(seed_value,1,party) == "linking_cord","Merchant anticipates Abra's ordinary Kadabra evolution")
func run() -> void:
    content_checks()
    action_checks()
    merchant_checks()
    print("EVOLUTION_ITEMS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
