extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func checkpoint(j: TacticalJourney) -> void:
    var before := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(before),"Validate expanded Pokemon state")
    if not JourneySnapshot.validate(before): return
    check(JourneySnapshot.encode(JourneySnapshot.restore(before)) == before,"Exact new move/form/evolution/RNG snapshot roundtrip")
func fixture(ids: Array[int]) -> TacticalJourney:
    var j := TacticalJourney.new(712,"field_kit",ids,true)
    j.step = 1
    j.phase = TacticalJourney.MAP
    check(j.enter_next().is_empty(),"Enter an actual camp")
    return j
func run() -> void:
    var golden := {1:"7ef133f1577eaae001eb598750393f8a1d15e6a0111ab932f8e33965538e8451",712:"77f048afb85c2643536ebbe42b2eddbf4d389ad89062ecdac49fd436cb46c988",2026:"6ff01675f45fce21f9e3cfc99e2a75b8a6b3c48abd50e99e3f7afde9ad354012"}
    for seed_value: int in golden:
        var old := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true,3)
        check(old.route.signature == golden[seed_value] and old.party.all(func(p: BattlePokemon): return p.content_version == 1),"v3 routes/RNG and legacy learnsets preserved")
        checkpoint(old)
    var j := fixture([906,909,912])
    check(j.party[0].species_id == 906 and j.party[0].content_version == 2 and j.route.generation == 11,"Generation9 starters use expanded route and original modern learning")
    checkpoint(j)
    var member := j.party[0]
    member.level = 15
    member.experience = TacticalGrowth.experience_floor(15,906)
    PokemonStats.apply(member,true)
    var report := TacticalGrowth.award(member,TacticalGrowth.experience_floor(16,906)-member.experience)
    check(member.species_id == 907 and not report["evolutions"].is_empty(),"Sprigatito evolves at original Lv.16")
    # Form selection keeps HP/cards and cannot turn into a different regional lineage.
    var forms := fixture([479])
    var uid := forms.party[0].uid
    var hp := forms.party[0].hp
    check(forms.change_form(uid,10009).is_empty() and forms.party[0].species_id == 10009,"Wash Rotom available as a permanent form")
    check(forms.party[0].hp <= hp and forms.rested_steps.is_empty(),"Form preparation cannot heal or spend the camp rest action")
    checkpoint(forms)
    var region := fixture([37])
    check(not region.change_form(region.party[0].uid,10103).is_empty(),"Regional Vulpix requires its own capture/evolution lineage")
    var fusion := fixture([898])
    check(not fusion.change_form(fusion.party[0].uid,10193).is_empty(),"Calyrex Ice fusion gated by Glastrier collection")
    check(fusion.change_form(fusion.party[0].uid,10193,[896,898]).is_empty(),"Both captured fusion partners unlock appropriate form")
    checkpoint(fusion)
    # Teaching uses a legal source and swaps only that owner's old move copies.
    var training := fixture([133])
    var p := training.party[0]
    var legal := NationalEvolution.teachable_moves(p)
    var selected := 0
    for move: int in legal:
        if TacticalMoves.key_for(move) not in p.learned_skills: selected = move; break
    check(selected > 0 and training.train_move(p.uid,selected,0).is_empty(),"Teach a legal machine/tutor move at camp")
    check(p.learned_skills[0] == TacticalMoves.key_for(selected) and training.step in training.rested_steps,"Teaching replaces selected learned slot and spends one action")
    check(not training.train_move(p.uid,919,0).is_empty(),"Repeated/illegal training cannot bypass action or learnset")
    checkpoint(training)
    var prepare := fixture([57])
    var primeape := prepare.party[0]
    primeape.level = 40
    primeape.experience = TacticalGrowth.experience_floor(40,57)
    primeape.learned_skills.assign([TacticalMoves.key_for(889)])
    PokemonStats.apply(primeape,true)
    prepare.deck.assign(TacticalContent.starting_deck(prepare.party))
    prepare.battle.start_with(prepare.party,prepare.deck,prepare.route.opponents(0),prepare.seed_value,prepare.relic,true)
    prepare.battle.full_type_chart = true
    prepare._collect_deck()
    check(NationalEvolution.level_target(primeape,"day") == 0,"Special evolution never happens before explicit preparation")
    check(prepare.prepare_evolution(primeape.uid,979).is_empty() and prepare.step in prepare.rested_steps,"Special original-world condition has a concrete camp adaptation")
    checkpoint(prepare)
    TacticalGrowth.award(primeape,TacticalGrowth.experience_floor(41,57)-primeape.experience)
    check(primeape.species_id == 979 and primeape.evolution_prepared == 0,"Prepared Annihilape branch resolves on next level-up")
    var item := fixture([133])
    item.inventory["ice_stone"] = 1
    check(item.use_item("ice_stone",0).is_empty() and item.party[0].species_id == 471,"New generation evolution item resolves to Glaceon")
    checkpoint(item)
    var cosmetic := fixture([30001]) # Unown B form has a distinct runtime identity.
    check(cosmetic._next_pokemon_uid > cosmetic.party[0].uid,"High form-ID starters reserve noncolliding capture UIDs")
    checkpoint(cosmetic)
    check(JourneySave.compatible_content("cb812fd10b00f224a7c50255448f2d5643ed440af7daa4429d41ae26bfc6e952"),"Prior full-content fingerprint accepted")
    var eevee := BattlePokemon.new(TacticalContent.member_definition(133,VisualCatalog.new()),133)
    TacticalGrowth.initialize(eevee,true)
    eevee.friendship = 255
    eevee.learned_skills.assign(["move_33"])
    eevee.evolution_prepared = 700
    TacticalGrowth.award(eevee,TacticalGrowth.experience_floor(6,133)-eevee.experience,"day")
    check(eevee.species_id == 133,"Selected Sylveon branch cannot silently fall through to legacy Espeon without a Fairy move")
    eevee.learned_skills.append("move_608")
    TacticalGrowth.award(eevee,TacticalGrowth.experience_floor(7,133)-eevee.experience,"day")
    check(eevee.species_id == 700,"Selected Sylveon evolves once the required Fairy technique is learned")
    var toxel := BattlePokemon.new(TacticalContent.member_definition(848,VisualCatalog.new()),848)
    toxel.level = 30
    TacticalGrowth.initialize(toxel,true)
    check(NationalEvolution.level_target(toxel,"day") == 0,"Nature-based Toxtricity branch requires explicit camp adaptation")
    toxel.evolution_prepared = 849
    check(NationalEvolution.level_target(toxel,"day") == 849,"Amped Toxtricity preparation keeps its own branch")
    toxel.evolution_prepared = 10184
    check(NationalEvolution.level_target(toxel,"day") == 10184,"Low Key Toxtricity preparation keeps its own branch")
    for key: String in EvolutionItems.all_items():
        check(EvolutionItems.all_items()[key]["stock"] is int and EvolutionItems.all_items()[key]["price"] is int,"Imported material stock/price remain save-safe integers")
    for seed_value in 30:
        var camp := TacticalJourney.new(seed_value,"field_kit",[906,909,912],true)
        for step in range(1,16,2):
            camp.step = step
            camp.phase = TacticalJourney.MAP
            camp.enter_next()
        checkpoint(camp)
    print("National progression: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
