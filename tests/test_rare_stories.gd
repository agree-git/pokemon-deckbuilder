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
func seed_for(id: int) -> int:
    for seed_value in 10000:
        if RareEncounter.target(seed_value) == id: return seed_value
    return -1
func text_fits(label: Label) -> bool:
    if label.get_line_count()*label.get_line_height() > label.size.y: return false
    if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
        for line: String in label.text.split("\n"):
            if label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x > label.size.x: return false
    return true
func run() -> void:
    root.size = Vector2i(1920,1080)
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rare_stories.json"))
    check(data.size() == RareEncounter.IDS.size() and RareEncounter.IDS.all(func(id: int): return data.has(str(id))),"Story IDs exactly cover the 103 supported rare species")
    var seen := {}
    for id: int in RareEncounter.IDS:
        var story := RareEncounterStory.entry(id)
        check(story.size() == 5 and story["clues"].size() == RareEncounter.requirement(id),"Each paid investigation has its own clue: "+str(id))
        var lines: Array = [story["site"],story["rumor"],story["arrival"]]+story["clues"]
        for line: String in lines:
            check(line.length() in range(4,61) and not line.contains("\n") and line == line.strip_edges() and not seen.has(line),"Short, unique story text: "+str(id)+" "+line)
            seen[line] = true
        var j := Support.fixture(seed_for(id))
        var scenery := RareEncounterStory.backdrop(id)
        check(not scenery.is_empty() and scenery["type"] == story["backdrop_type"] and scenery["name"] == story["site"],"Every rare site resolves to an existing background")
        scenery["name"] = "changed"
        check(RareEncounterStory.backdrop(id)["name"] == story["site"],"Backdrop copies cannot mutate cached biome presets")
        var before := JourneySnapshot.encode(j)
        for count in range(RareEncounter.requirement(id)+1):
            var expected: String = story["rumor"] if count == 0 else story["clues"][count-1]
            check(RareEncounterStory.clue(id,count) == expected,"Only the already-earned clue is revealed")
        story["clues"][0] = "changed"
        check(RareEncounterStory.entry(id)["clues"][0] != "changed","Returned story copies cannot modify the cached content")
        check(JourneySnapshot.validate(before) and JourneySnapshot.encode(JourneySnapshot.restore(before)) == before,"Existing rare checkpoint still restores exactly")
        var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        ui.rare_open = true
        root.add_child(ui)
        UiMotion.finish_tree(ui)
        await process_frame
        check(ui.page.find_child("RareSite",true,false).text == "발견 전까지 정체를 알 수 없습니다.","Camp hides the actual target site")
        check(ui.page.find_child("RareClue",true,false).text == RareEncounterStory.clue(id,j.rare_info()["clues"].size()),"Camp clue follows saved progress")
        for name_text in ["RareSite","RareClue","RareTarget","RareProgress","RareConditions"]:
            var label: Label = ui.page.find_child(name_text,true,false)
            check(text_fits(label),"Real Korean text fits "+name_text+" / "+str(id))
        var popup: Button = ui.page.find_child("RarePicker",true,false)
        var body: Control = popup.get_children().filter(func(n: Node): return n is Panel)[0]
        check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(body.get_global_rect()),"Camp modal fits native viewport")
        var clue_label: Label = ui.page.find_child("RareClue",true,false)
        var conditions: Label = ui.page.find_child("RareConditions",true,false)
        var investigate: Button = ui.page.find_child("InvestigateRare",true,false)
        check(clue_label.get_global_rect().end.y <= conditions.global_position.y and conditions.get_global_rect().end.y <= investigate.global_position.y,"Clue and rules remain clear of actions")
        ui._close_rare()
        await process_frame
        check(JourneySnapshot.encode(j) == before,"Opening/closing story never consumes clues, actions or RNG")
        ui.free()
        Support.enter(j)
        var battle_before := JourneySnapshot.encode(j)
        ui = load("res://scenes/tactical_journey.tscn").instantiate()
        ui.journey = j
        root.add_child(ui)
        var view := ui.battle_ui
        check(view.run_background["type"] == data[str(id)]["backdrop_type"] and view.stage.canvas.battlefield_layout == BattlefieldLayout.for_backdrop(view.run_background),"Battle uses the story scenery and its calibrated floor")
        check(text_fits(view.get_node("StageTitle")),"Rare site name fits the compact battle header")
        check(view.busy and view.end_button.disabled and view._rare_hidden and not view.enemy_roster.visible and view.stage.canvas.target_factor == 0,"Rare introduction locks battle input")
        var arrival: Label = view.rare_speech.find_child("RareArrival",true,false)
        await process_frame
        check(arrival.text == data[str(id)]["arrival"] and text_fits(arrival),"Own arrival line fits the battle panel")
        view.finish_presentation()
        check(not view.busy and not view.rare_speech.visible and not view.end_button.disabled,"Finishing restores battle input")
        check(JourneySnapshot.encode(j) == battle_before,"Rare introduction leaves HP, cards, energy and both RNG states untouched")
        ui.refresh()
        check(ui.battle_ui.rare_speech == null and not ui.battle_ui.busy,"Refreshing the same combat never repeats the introduction")
        ui.free()
    check(RareEncounterStory.entry(0).is_empty() and RareEncounterStory.clue(0,3).is_empty(),"Unsupported species get no invented rare story")
    var j := Support.fixture(seed_for(151))
    j.rare_hunt["clues"].pop_back()
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    ui.rare_open = true
    root.add_child(ui)
    ui._rare_action(false)
    await process_frame
    check(j.rare_info()["clues"].size() == 5 and j.step in j.rested_steps,"One real investigation earns the last clue and spends the camp action")
    check(ui.page.find_child("RareClue",true,false).text == RareEncounterStory.clue(151,5),"Investigation immediately shows the newly earned clue")
    var before := JourneySnapshot.encode(j)
    ui._rare_action(false)
    check(JourneySnapshot.encode(j) == before,"Repeated investigation still cannot spend twice")
    ui.free()
    for name_text in ["GameAudio","GameMusic","GameCries","GameAmbience"]: root.get_node(name_text).call("stop_all" if name_text != "GameMusic" else "stop_music")
    await process_frame
    await create_timer(0.2).timeout
    print("RARE_STORIES: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
