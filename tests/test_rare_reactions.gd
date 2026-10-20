extends SceneTree
const Support = preload("support/rare_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fits(label: Label) -> bool:
    return label.get_line_count()*label.get_line_height() <= label.size.y and (label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x <= label.size.x)
func view_for(journey: TacticalJourney) -> TacticalJourneyUI:
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = journey
    root.add_child(ui)
    return ui
func stop_audio() -> void:
    root.get_node("GameMusic").stop_music()
    root.get_node("GameAmbience").stop_ambience()
    root.get_node("GameCries").stop_all()
    root.get_node("GameAudio").stop_all()
func run() -> void:
    root.size = Vector2i(1920,1080)
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rare_reactions.json"))
    check(data.size() == 103 and RareEncounter.IDS.all(func(id: int): return data.has(str(id))),"Reaction data covers exactly all supported rare species")
    var seen := {}
    for id: int in RareEncounter.IDS:
        check(data[str(id)].size() == 3,"Exactly three supported reactions per species")
        for event: String in RareCaptureReaction.EVENTS:
            var line := RareCaptureReaction.line(id,event)
            check(line == data[str(id)][event] and line.length() in range(10,61) and line == line.strip_edges() and not line.contains("\n") and not seen.has(line),"Short unique authored text: "+str(id)+"/"+event)
            seen[line] = true
    check(RareCaptureReaction.line(1,"capture").is_empty() and RareCaptureReaction.line(0,"joined").is_empty() and RareCaptureReaction.line(151,"unknown").is_empty(),"Unsupported species and events have no rare reaction")
    var session := root.get_node("BattleSession")
    var original_profile: PlayerProfile = session.profile
    var profile := PlayerProfile.new("user://reaction_collection.json")
    session.profile = profile
    var seeds := {}
    for candidate in 5000:
        var id := RareEncounter.target(candidate)
        if not seeds.has(id): seeds[id] = candidate
    check(seeds.size() == 103,"Every rare is covered by an actual seeded challenge")
    for id: int in RareEncounter.IDS:
        var j := Support.fixture(seeds[id])
        if id%2 == 1:
            var leaving := j.party.pop_back() as BattlePokemon
            j.deck.assign(j.deck.filter(func(card: BattleCardInstance): return card.owner_uid != leaving.uid and card.injury_owner_uid != leaving.uid))
        Support.enter(j)
        var ui := view_for(j)
        ui.battle_ui.finish_presentation()
        var view := ui.battle_ui
        var before := JourneySnapshot.encode(j)
        view._capture()
        check(JourneySnapshot.encode(j) == before and not view.capture_quote.visible and ui.rare_reaction.is_empty(),"Rejected capture does not show a success reaction or change state")
        Support.ready_capture(j)
        view._capture()
        view.finish_presentation()
        UiMotion.finish_tree(ui)
        await process_frame
        check(j.rare_hunt["captured"] and id in profile.captured_ids and view.capture_quote.visible,"Actual capture records unlock before showing result text")
        check(view.capture_quote.text == data[str(id)]["capture"] and fits(view.capture_quote),"Captured species reaction fits battle result: "+str(id))
        check(view.capture_quote.get_global_rect().end.y <= view.result_next.global_position.y,"Result reaction clears buttons")
        before = JourneySnapshot.encode(j)
        view._refresh()
        check(JourneySnapshot.encode(j) == before,"Refreshing capture result preserves resources, deck, UIDs and RNG")
        j.settle()
        while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
        check(j.phase == TacticalJourney.CAPTURE,"Actual settlement reaches recruitment choice")
        ui.refresh()
        UiMotion.finish_tree(ui)
        await process_frame
        var quote: Label = ui.page.find_child("RareCaptureQuote",true,false)
        check(quote != null and quote.text == data[str(id)]["capture"] and fits(quote),"Species reaction fits recruitment choice: "+str(id))
        var checkpoint := JourneySnapshot.encode(j)
        check(JourneySnapshot.validate(checkpoint),"Captured checkpoint remains valid")
        ui._preview_recruit(0)
        await process_frame
        ui._close_recruit()
        await process_frame
        check(JourneySnapshot.encode(j) == checkpoint and ui.rare_reaction.is_empty(),"Preview and cancel do not confirm a reaction or change state")
        ui._resolve_capture(99)
        check(JourneySnapshot.encode(j) == checkpoint and ui.rare_reaction.is_empty(),"Invalid recruitment choice is silent and atomic")
        ui.free()
        await process_frame
        # Compare actual UI actions against the existing model for both decisions.
        for index: int in [0,-1]:
            var expected := JourneySnapshot.restore(checkpoint)
            expected.resolve_capture(index)
            var expected_state := JourneySnapshot.encode(expected)
            j = JourneySnapshot.restore(checkpoint)
            ui = view_for(j)
            ui._resolve_capture(index)
            UiMotion.finish_tree(ui)
            await process_frame
            var panel := ui.page.find_child("RareReactionPanel",true,false) as RareReactionPanel
            var event := "joined" if index == 0 else "released"
            check(panel != null and panel.species_id == id and panel.event == event and panel.quote.text == data[str(id)][event],"Correct post-choice reaction: "+str(id)+"/"+event)
            check(fits(panel.quote) and panel.body.get_global_rect().encloses(panel.continue_button.get_global_rect()) and panel.quote.get_global_rect().end.y < panel.continue_button.global_position.y,"Native text and controls fit modal")
            check(JourneySnapshot.encode(j) == expected_state and not expected_state["run"].has("rare_reaction"),"Reaction has no model/save/RNG side effects")
            check(id in profile.captured_ids and id in PlayerProfile.new(profile.path).captured_ids,"Both choices preserve permanent unlock")
            check(j.pending_captures.is_empty() and j.party.any(func(p: BattlePokemon): return p.species_id == id) == (index == 0),"Party choice resolves exactly once")
            ui.refresh()
            UiMotion.finish_tree(ui)
            await process_frame
            panel = ui.page.find_child("RareReactionPanel",true,false) as RareReactionPanel
            check(panel != null and JourneySnapshot.encode(j) == expected_state,"UI refresh retains reaction without applying choice twice")
            ui._resolve_capture(index)
            check(JourneySnapshot.encode(j) == expected_state,"Repeated choice cannot repeat rewards or resources")
            panel.close()
            await process_frame
            check(ui.rare_reaction.is_empty() and ui.page.find_child("RareReactionPanel",true,false) == null and JourneySnapshot.encode(j) == expected_state,"Closing acknowledges without another model action")
            ui.free()
            await process_frame
            ui = view_for(JourneySnapshot.restore(expected_state))
            check(ui.rare_reaction.is_empty() and ui.page.find_child("RareReactionPanel",true,false) == null,"Reload does not replay temporary choice reaction")
            ui.free()
            await process_frame
    # Ordinary captures keep the existing direct decision flow.
    var ordinary := TacticalJourney.new(42,"field_kit",[4])
    Support.ready_capture(ordinary)
    ordinary.balls = 2
    ordinary.battle.energy = 3
    ordinary.battle.enemy().hp = 1
    check(ordinary.capture().is_empty(),"Prepare an ordinary capture")
    ordinary.settle()
    while ordinary.phase == TacticalJourney.LEARN: ordinary.resolve_learning(-1)
    var plain := view_for(ordinary)
    check(plain.page.find_child("RareCaptureQuote",true,false) == null,"Ordinary capture has no rare narration")
    plain._resolve_capture(0)
    check(plain.rare_reaction.is_empty() and plain.page.find_child("RareReactionPanel",true,false) == null,"Ordinary join adds no extra reaction dialog")
    plain.free()
    # Defeating a rare is distinct from capturing it.
    var defeated := Support.fixture(seeds[151])
    Support.enter(defeated)
    var lost_view := view_for(defeated)
    lost_view.battle_ui.finish_presentation()
    defeated.battle.enemy().hp = 0
    defeated.battle._outcome()
    lost_view.battle_ui._refresh()
    check(not lost_view.battle_ui.capture_quote.visible,"Defeating a rare never shows captured narration")
    lost_view.free()
    session.profile = original_profile
    stop_audio()
    await process_frame
    await create_timer(.2).timeout
    print("RARE_REACTIONS: ",checks," checks / ",failures," failures")
    quit(0 if failures == 0 else 1)
