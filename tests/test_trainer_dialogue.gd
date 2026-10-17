extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var catalog := VisualCatalog.new()
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var all: Array[Dictionary] = []
    for role: String in ["gym","elite","champion"]:
        var people: Array = GymLeaders.all() if role == "gym" else league["elite" if role == "elite" else "champions"]
        for person: Dictionary in people: all.append({"kind":role,"trainer":person})
    check(all.size() == 124 and TrainerDialogue.data().size() == 124,"Dialogue covers exactly 82 gym teams, 31 elite trainers and 11 champions")
    var host := Control.new()
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):650.0}
    host.add_theme_font_override("font",font)
    root.add_child(host)
    var speech := TrainerSpeech.new()
    speech.size = Vector2(768,132)
    host.add_child(speech)
    var compact := TrainerSpeech.new()
    compact.compact = true
    compact.size = Vector2(688,90)
    host.add_child(compact)
    var canvas := BattleCanvas.new()
    canvas.canvas_size = Vector2(1920,1080)
    canvas.target_anchor = Vector2(1440,280)
    root.add_child(canvas)
    canvas.hide()
    var art := TrainerEntrance.new()
    art.canvas = canvas
    art.slide = 0
    var included := 0
    var covered := {}
    var distinct := {}
    for stop: Dictionary in all:
        var source: Dictionary = stop.duplicate(true)
        var person := TrainerDialogue.opponent(stop,{"type":"grass"})
        var key := TrainerDialogue.key(person)
        check(not covered.has(key) and TrainerDialogue.data().has(key),"Each roster has exactly its own role-qualified dialogue: "+key)
        covered[key] = true
        check(person["name"] in TrainerDialogue.title(person) and person["region"] in TrainerDialogue.title(person),"Speaker preserves actual trainer and home region: "+key)
        check(person["type"] == ("grass" if stop["trainer"]["type"] == "mixed" else stop["trainer"]["type"]),"Presentation uses trainer specialty, not previous biome type: "+key)
        var portrait := TrainerSprites.texture(person)
        var mapping := TrainerSprites.entry(person)
        check(not mapping.is_empty(),"Every boss has an explicit sprite mapping or fallback: "+key)
        if portrait != null:
            included += 1
            var actual := portrait.get_image().get_used_rect()
            check(Rect2(actual) == TrainerSprites.bounds(person),"Mapped bounds match actual opaque source pixels: "+key)
            art.set_trainer(person)
            for pose: String in ["stand","windup","throw"]:
                art.pose = pose
                var area := art.portrait_rect()
                check(area.end.x <= 1630 and area.position.x >= 1344,"Every mapped pose clears roster and speech: "+key)
                check(area.size.x/actual.size.x == floor(area.size.x/actual.size.x),"Every mapped pose preserves integer pixel scaling")
        else:
            check(mapping.get("status","") == "fallback","Unavailable art has an explicit fallback: "+key)
        for phase: String in TrainerDialogue.PHASES:
            var line := TrainerDialogue.line(person,phase)
            check(line.length() in range(4,37) and not line.contains("\n") and line == line.strip_edges(),"Short original dialogue exists and is well formed: "+key+"/"+phase)
            distinct[line] = true
            speech.present(person,phase)
            compact.present(person,phase)
            await process_frame
            check(speech.quote.text == line and compact.quote.text == line,"Both presentation sizes show the full selected line")
            for box: TrainerSpeech in [speech,compact]:
                check(box.quote.get_line_count()*box.quote.get_line_height() <= box.quote.size.y and box.speaker.get_line_count()*box.speaker.get_line_height() <= box.speaker.size.y,"Actual Korean font fits the battle and result speech sizes: "+key)
                check(box.mouse_filter == Control.MOUSE_FILTER_IGNORE and box.quote.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Speech never steals UI pointer input")
        check(source == stop,"Selecting dialogue does not mutate route trainer content")
    check(included == 123,"123 roster identities use original or credited community sprites")
    check(distinct.size() == 372,"Every authored line is distinct")
    check(covered.keys().all(func(key: String): return TrainerDialogue.data().has(key)),"No mismatched or orphaned trainer content")
    for person: String in ["koga","blue","lance","wallace","iris","larry"]:
        var texts: Array[String] = []
        for role: String in ["gym","elite","champion"]:
            var line := TrainerDialogue.line({"kind":role,"id":person},"intro")
            if not line.is_empty(): texts.append(line)
        check(texts.size() == 2 and texts[0] != texts[1],"Same person has separate writing for their two roles: "+person)
    for unknown: Dictionary in [{},{"kind":"trainer","id":"brock"},{"kind":"gym","id":"missing"},{"kind":"gym","name":"웅"}]:
        speech.present(unknown,"intro")
        check(TrainerDialogue.line(unknown,"intro").is_empty() and not speech.visible,"Unknown trainer uses the existing generic entrance, never another person's line")
    check(TrainerDialogue.line({"kind":"gym","id":"brock"},"unknown").is_empty(),"Unknown phase is ignored")
    for seed_value in [0,42,2026]:
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        var before := JourneySnapshot.encode(j)
        var resumed := JourneySnapshot.restore(before)
        for stop: Dictionary in j.route.stops:
            if stop["kind"] not in TrainerDialogue.ROLES: continue
            var trainer := TrainerDialogue.opponent(stop,stop["biome"])
            for phase: String in TrainerDialogue.PHASES: check(not TrainerDialogue.line(trainer,phase).is_empty(),"Actual seeded route resolves every boss line")
        check(JourneySnapshot.encode(j) == before and JourneySnapshot.encode(resumed) == before,"Dialogue lookup preserves v3 checkpoint and both RNG states")
    art.free()
    canvas.free()
    host.free()
    print("TRAINER_DIALOGUE: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
