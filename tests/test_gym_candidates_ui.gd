extends SceneTree
## Isolated review fixtures, not a campaign playthrough or a player's save.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    root.position = Vector2i.ZERO
    var desired := ["janine","falkner","tate_liza","volkner","roxie","clemont","marnie","iono","tyme","blue"]
    var examples := {}
    for seed_value in 512:
        var route := CampaignRoute.new(seed_value)
        for step in route.stops.size():
            var stop := route.stops[step]
            if stop["kind"] == "gym" and stop["trainer"]["leader_id"] in desired:
                examples[stop["trainer"]["leader_id"]] = [seed_value,step]
        if examples.size() == desired.size(): break
    check(examples.size() == desired.size(),"Find real seeded gym appointments from all eight regions plus mixed Blue")
    for id: String in desired:
        if not examples.has(id): continue
        var example: Array = examples[id]
        var j := TacticalJourney.new(example[0],"field_kit",[1,4,7],true)
        j.step = example[1]
        j.phase = TacticalJourney.MAP
        j.badges = int(j.current()["chapter"])
        # A level-matched comparison party; this fixture skips prior battles.
        j.party.clear()
        for species: int in [3,6,9]:
            var definition := TacticalContent.member_definition(species,VisualCatalog.new())
            definition["level"] = int(j.current()["level"])
            var pokemon := BattlePokemon.new(definition,species)
            TacticalGrowth.initialize(pokemon)
            j.party.append(pokemon)
        j.deck.assign(TacticalContent.starting_deck(j.party))
        check(j.enter_next().is_empty(),"Enter the actual selected gym")
        var before := JourneySnapshot.encode(j)
        var ui := TacticalJourneyUI.new()
        ui.journey = j
        root.add_child(ui)
        await process_frame
        var view := ui.battle_ui
        var trainer: Dictionary = j.current()["trainer"]
        check(view.opponent_trainer["name"] == trainer["leader"] and view.trainer_intro.role == "gym","Introduction identifies the selected leader")
        check(view.run_title.contains(trainer["leader"]) and view.run_title.contains(trainer["region"]),"Actual battle HUD shows leader and home region")
        var expected_party: Array = trainer["party"].map(func(species: Variant): return int(species))
        check(view.enemy_slots.size() == 6 and j.battle.enemies.map(func(p: BattlePokemon): return p.species_id) == expected_party,"Right roster uses all six selected members")
        UiMotion.finish_tree(ui)
        UiMotion.finish_tree(ui)
        await process_frame
        check(not view.busy and view.get_node("Intent").visible,"Gym introduction restores battle input and intent")
        check(JourneySnapshot.encode(j) == before,"Viewing/finishing the new gym introduction cannot mutate the run")
        if id == "iono" and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("/tmp/pokemon-gym-candidates")
            check(root.get_texture().get_image().save_png("/tmp/pokemon-gym-candidates/iono.png") == OK,"Capture real 1920x1080 gym UI")
        ui.free()
    print("GYM_CANDIDATES_UI ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
