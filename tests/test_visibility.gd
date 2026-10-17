extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    root.size = Vector2i(1920,1080)
    var session := root.get_node("BattleSession")
    session.profile = PlayerProfile.new("")
    session.journey = null
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu)
    menu._open_collection()
    menu.show_locked.button_pressed = true
    menu._filter()
    await process_frame
    for id: int in RareEncounter.IDS:
        var button: Button = menu.species_buttons[id]
        check(button.disabled and button.get_children().all(func(n: Node): return not n is TextureRect),"No rare silhouette "+str(id))
        var labels: Array = button.get_children().filter(func(n: Node): return n is Label)
        check(labels.any(func(n: Label): return n.text == "???") and labels.all(func(n: Label): return n.text in ["?","???","미발견"]),"No rare name, type or dex number "+str(id))
    menu.search.text = "뮤츠"
    menu._filter()
    check(not menu.species_buttons.has(150),"Search cannot reveal an unknown rare by name")
    menu.search.text = "1024"
    menu._filter()
    check(not menu.species_buttons.has(1024),"Search cannot reveal an unknown rare by dex number")
    session.profile.captured_ids.append(1024)
    menu._filter()
    check(menu.species_buttons.has(1024) and not menu.species_buttons[1024].disabled,"Captured rare remains visible and available")
    menu.search.text = ""
    session.journey = TacticalJourney.new(2026,"field_kit",[1],true)
    session.journey.rare_hunt = {"target":10169,"clues":[],"battle_step":0,"captured":false}
    menu._filter()
    check(menu.species_buttons[10169].get_children().any(func(n: Node): return n is TextureRect),"Already encountered target visible in current collection")
    menu.free()
    session.journey = null
    for name_text in ["GameAudio","GameMusic","GameCries"]: root.get_node(name_text).call("stop_all" if name_text != "GameMusic" else "stop_music")
    await process_frame
    await create_timer(0.2).timeout
    print("COLLECTION_HIDDEN ",checks," checks / ",failures," failures")
    quit(0 if failures == 0 else 1)
