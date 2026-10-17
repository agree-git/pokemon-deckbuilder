extends SceneTree
const Support = preload("rare_test_support.gd")
var checks := 0
var failures := 0
var clicks := 0
var ui: TacticalJourneyUI
var output_dir := "/tmp/pokemon-rare-stories"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func click(control: Control) -> void:
    if not is_instance_valid(control):
        check(false,"Requested pointer target still exists")
        return
    var point := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size/2))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    clicks += 1
    print("CLICK_TARGET ",control.name," ",roundi(point.x)," ",roundi(point.y))
    await create_timer(0.38).timeout
    await process_frame
func escape() -> void:
    print("OS_MOVE 20 100")
    await create_timer(0.12).timeout
    print("OS_KEY Escape")
    await create_timer(0.18).timeout
func shot(label_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output_dir.path_join(label_text+".png")) == OK,"Capture "+label_text)
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    DirAccess.make_dir_recursive_absolute(output_dir)
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    var samples := [{"seed":24,"id":144},{"seed":16,"id":151},{"seed":14,"id":150}]
    var index := 0
    for sample: Dictionary in samples:
        root.get_node("Preferences").battle_speed = [1.0,1.5,2.0][index]
        index += 1
        var j := Support.fixture(sample["seed"])
        check(j.rare_info()["target"] == sample["id"],"Fixture uses the intended real seeded target")
        var story := RareEncounterStory.entry(sample["id"])
        j.rare_hunt["clues"].pop_back()
        var before := JourneySnapshot.encode(j)
        ui = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        await create_timer(0.25).timeout
        await click(ui.page.find_child("RareEncounter",true,false))
        check(ui.rare_open and JourneySnapshot.encode(j) == before,"OS click opens story without changing the hunt or RNG")
        check(ui.page.find_child("RareClue",true,false).text == RareEncounterStory.clue(sample["id"],j.rare_info()["clues"].size()),"Modal shows saved clue, not the unrevealed final one")
        await shot(str(sample["id"])+"-clue-before")
        await click(ui.page.find_child("InvestigateRare",true,false))
        for tick in 100:
            if j.rare_info()["clues"].size() == RareEncounter.requirement(sample["id"]): break
            await create_timer(0.01).timeout
        await process_frame
        check(j.rare_info()["clues"].size() == RareEncounter.requirement(sample["id"]) and j.step in j.rested_steps,"Visible research earns one clue and consumes one camp action")
        check(ui.page.find_child("RareClue",true,false).text == story["clues"].back(),"New clue appears after real investigation")
        check(ui.rest_button.disabled and ui.page.find_child("InvestigateRare",true,false).disabled,"Rest and repeated research are disabled")
        var checkpoint := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(checkpoint) and JourneySnapshot.encode(JourneySnapshot.restore(checkpoint)) == checkpoint,"Research checkpoint restores exactly")
        await shot(str(sample["id"])+"-clue-after")
        await click(ui.page.find_child("ChallengeRare",true,false))
        check(j.rare_hunt["battle_step"] == j.step+1,"Actual pointer reserves the next wild encounter")
        await escape()
        check(not ui.rare_open,"Escape closes the story modal")
        await click(ui.actions[0])
        check(j.phase == TacticalJourney.MAP,"Camp departure still reaches the next-stop choice")
        await click(ui.actions[0])
        check(ui.travelling and ui.travel != null,"Actual pointer starts the existing walk animation")
        if ui.travel != null:
            var labels := ui.travel.get_children().filter(func(n: Node): return n is Label)
            check(labels.any(func(n: Label): return n.text == story["site"]) and labels.any(func(n: Label): return n.text == story["rumor"]),"Travel uses this species' site and approach text")
            var expected := VisualCatalog.biome_texture(RareEncounterStory.backdrop(sample["id"]))
            var shown: AtlasTexture = ui.travel.get_child(0).texture
            check(shown.atlas == expected.atlas and shown.region == expected.region,"Walking scene uses the same rare-site background as combat")
            await shot(str(sample["id"])+"-travel")
        for tick in 400:
            if not ui.travelling: break
            await create_timer(0.01).timeout
        var view := ui.battle_ui
        check(ui.battle_ui != null and ui.battle_ui.run_background["type"] == story["backdrop_type"],"Arrival uses the actual selected rare background")
        check(j.phase == TacticalJourney.BATTLE and view != null and view.busy,"Travel reaches the locked rare arrival")
        if view == null or view.rare_speech == null: ui.free(); quit(1); return
        var battle_before := JourneySnapshot.encode(j)
        await create_timer(0.25).timeout
        check(view.rare_speech.visible and view.rare_speech.find_child("RareArrival",true,false).text == story["arrival"],"Battle displays the actual species arrival text")
        await shot(str(sample["id"])+"-arrival")
        await click(view.end_button)
        check(JourneySnapshot.encode(j) == battle_before,"Disabled end-turn button cannot change battle during arrival")
        for tick in 400:
            if not view.busy: break
            await create_timer(0.01).timeout
        check(not view.busy and not view.rare_speech.visible and not view.end_button.disabled,"Arrival naturally finishes and releases combat input")
        check(JourneySnapshot.encode(j) == battle_before,"Natural playback preserves HP, cards, energy, route and both RNGs")
        var legal: Array = j.battle.hand.filter(func(card: BattleCardInstance): return j.battle.card_reason(card.uid).is_empty())
        check(not legal.is_empty(),"A real playable card exists after arrival")
        if not legal.is_empty():
            j.battle.play_card(legal[0].uid)
            var acted := JourneySnapshot.encode(j)
            check(JourneySnapshot.validate(acted),"Acted rare battle checkpoint validates")
            var restored := JourneySnapshot.restore(acted)
            ui.free()
            ui = load("res://scenes/tactical_journey.tscn").instantiate()
            ui.journey = restored
            root.add_child(ui)
            check(not ui.battle_ui.busy and ui.battle_ui.rare_speech == null,"Restoring an acted battle does not repeat the rare introduction")
        ui.free()
        await process_frame
    root.get_node("GameAudio").stop_all()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.2).timeout
    print("RARE_STORIES_NATIVE: ",checks," checks, ",failures," failures; ",clicks," OS clicks; 12 captures")
    quit(0 if failures == 0 else 1)
