extends SceneTree
const Support = preload("support/rare_fixture.gd")
var checks := 0
var failures := 0
var seeds := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    root.size = Vector2i(1920,1080)
    var catalog := VisualCatalog.new()
    check(catalog.pokemon.size() == 1412 and RareEncounter.IDS.size() == 103,"Exact catalog and encounter scope")
    for value in range(1,1026):
        check(VisualCatalog.supports(value),"Strict supported species membership")
    for id: int in [793,794,795,796,797,798,799,803,804,805,806,984,985,986,987,988,989,990,991,992,993,994,995,1005,1006,1011,1012,1013,1018,1019,10168,10172]: check(VisualCatalog.supports(id),"Expanded ordinary, UB, paradox and regional forms "+str(id))
    for seed_value in 5000:
        var id := RareEncounter.target(seed_value)
        if not seeds.has(id): seeds[id] = seed_value
    check(seeds.size() == 103,"All targets reachable")
    check(RareEntrance.KINDS.size() == 25 and RareEncounter.SUPER_LEGENDARY.all(func(id: int): return id in [789,790] or RareEntrance.supports(id)),"All 25 superlegendary arrivals")
    var profile := PlayerProfile.new("user://gen9-test-collection.json")
    profile.captured_ids.clear()
    for id: int in RareEncounter.IDS:
        var species := catalog.species(id)
        check(not species.is_empty(),"Catalog "+str(id))
        for back: bool in [false,true]:
            var texture: Texture2D = load(VisualCatalog.sprite_path(id,back))
            check(texture != null and not texture.get_image().get_used_rect().size == Vector2i.ZERO,"Opaque front/back sprite "+str(id))
        var cry: AudioStream = load("res://assets/audio/cries/%d.ogg" % id)
        check(cry != null and cry.get_length() > 0,"Decoded cry "+str(id))
        check(PokemonStats.base(id).size() == 6,"Six species stats "+str(id))
        var learnset: Array = TacticalGrowth.species_data(id)["learnset"]
        check(not learnset.is_empty(),"Real learnset "+str(id))
        for entry: Dictionary in learnset:
            check(not TacticalMoves.definition(TacticalMoves.key_for(entry["move"])).is_empty(),"Move card definition "+str(entry["move"]))
        var j := Support.fixture(seeds[id])
        check(not RareEncounter.identity_known(j),"Hidden before reservation")
        var before := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(before),"Valid rare camp snapshot "+str(id))
        var story := RareEncounterStory.entry(id)
        check(story["clues"].size() == RareEncounter.requirement(id),"Every investigation has a clue "+str(id))
        for line: String in [story["rumor"]]+story["clues"]:
            check(not line.contains(species["name"]),"No species name in pre-encounter clues "+str(id))
        check(j.challenge_rare().is_empty(),"Reserve "+str(id))
        check(not EncounterPreparation.upcoming(j).has("opponents") or EncounterPreparation.upcoming(j)["opponents"].is_empty(),"Preparation hides rare opponents")
        check(j.history.back().contains("???"),"Reservation history is anonymous")
        j.leave_camp()
        check(not RareEncounter.identity_known(j) and j.progress_title().contains("???"),"Map keeps identity hidden")
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Reserved save valid "+str(id))
        j.enter_next()
        check(RareEncounter.identity_known(j),"Identity revealed in encounter")
        check(j.battle.enemy().species_id == id,"Actual enemy species "+str(id))
        j.battle.energy = int(RareEncounter.rule(id)["energy"])
        j.battle.enemy().hp = floori(j.battle.enemy().max_hp*0.10)+1
        check(not j.capture_reason().is_empty(),"10% + one HP rejected "+str(id))
        j.battle.enemy().hp -= 1
        check(j.capture_reason().is_empty(),"10% accepted "+str(id))
        var balls := j.balls
        var energy := j.battle.energy
        check(j.capture().is_empty(),"Capture succeeds "+str(id))
        check(j.balls == balls-int(RareEncounter.rule(id)["balls"]) and j.battle.energy == energy-int(RareEncounter.rule(id)["energy"]),"Exact rare costs")
        check(j.captured_ids.has(id) and j.pending_captures[0].species_id == id,"Actual captured member")
        var captured := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured)) == captured,"Captured save roundtrip "+str(id))
        check(profile.record_capture(id,catalog).is_empty(),"Permanent capture "+str(id))
        var basic := catalog.starter_species_id(id)
        check(basic in profile.unlocked_starters(catalog),"Base form starter unlocked "+str(id))
        var new_run := TacticalJourney.new(2026,"field_kit",[basic],true)
        check(JourneySnapshot.validate(JourneySnapshot.encode(new_run)),"New rare starter starts playable run "+str(id))
    var loaded := PlayerProfile.new("user://gen9-test-collection.json")
    check(loaded.captured_ids == profile.captured_ids,"Expanded profile roundtrip")
    # Legacy four-field hunt: preserve its historical seed mapping exactly.
    for seed_value in [0,14,16,24,2026,9999]:
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        j.rare_hunt = {"target":RareEncounter.target(seed_value,1),"clues":[],"battle_step":-1,"captured":false}
        var old := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(old) and JourneySnapshot.encode(JourneySnapshot.restore(old)) == old,"Legacy hunt pool restored "+str(seed_value))
    var collision := TacticalJourney.new(1,"field_kit",[1001,1002,10169],true)
    var first_uid := collision._allocate_pokemon_uid()
    var next_uid := collision._allocate_pokemon_uid()
    check(first_uid != next_uid and [first_uid,next_uid].all(func(uid: int): return not collision.party.any(func(p: BattlePokemon): return p.uid == uid)),"Recruit UIDs are distinct and never collide with high-ID starters")
    check(catalog.starter_species_id(791) == 789 and catalog.starter_species_id(792) == 789 and catalog.starter_species_id(773) == 772 and catalog.starter_species_id(892) == 891 and catalog.starter_species_id(809) == 808,"Rare evolutionary starter ancestry")
    for time_of_day: String in ["day","night"]:
        var p := BattlePokemon.new(TacticalContent.member_definition(790,catalog),790)
        p.level = 52
        TacticalGrowth.initialize(p)
        TacticalGrowth.award(p,TacticalGrowth.experience_floor(53,790)-p.experience,time_of_day)
        check(p.species_id == (791 if time_of_day == "day" else 792),"Cosmoem time branch")
    var null_p := BattlePokemon.new(TacticalContent.member_definition(772,catalog),772)
    null_p.friendship = 220
    check(FriendshipEvolution.target(null_p,"day") == 773,"Type Null friendship")
    check(EvolutionItems.target("darkness_scroll",891) == 892 and EvolutionItems.target("metal_candy",808) == 809,"Solo camp rare evolution materials")
    print("GEN9 ",checks," checks / ",failures," failures")
    await process_frame
    quit(0 if failures == 0 else 1)
