extends SceneTree
## Render each newly added matchup through the real battle scene and entrance.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    if DisplayServer.get_name() == "headless": quit(1); return
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    var folder := OS.get_environment("BOSS_REVIEW_DIR")
    if folder.is_empty(): quit(2); return
    DirAccess.make_dir_recursive_absolute(folder)
    var expansion := BossExpansion.data()
    var roster := {"gym":expansion["gyms"],"elite":expansion["elite"],"champion":expansion["champions"]}
    var music := root.get_node("GameMusic")
    var number := 0
    for role: String in roster:
        for entry: Dictionary in roster[role]:
            var j := TacticalJourney.new(2718,"field_kit",[1,4,7],true)
            j.step = 14 if role == "gym" else (128 if role == "elite" else 136)
            var stop: Dictionary = j.route.stops[j.step]
            stop["kind"] = role
            stop["trainer"] = entry
            stop["party"] = entry["party"]
            j.badges = 8
            j.elite_wins = int(stop["league_index"]) if role != "gym" else 0
            j.phase = TacticalJourney.MAP
            check(j.enter_next().is_empty(),"Enter new boss fixture")
            var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate()
            ui.journey = j
            root.add_child(ui)
            await create_timer(.75).timeout
            var trainer := ui.battle_ui.opponent_trainer
            var key := TrainerDialogue.key(trainer)
            check(is_instance_valid(ui.battle_ui.trainer_intro) and ui.battle_ui.trainer_intro.visible and ui.battle_ui.trainer_intro.portrait != null,"Actual individual trainer entrance "+key)
            check(music.current_key.begins_with(key+":"),"Actual boss scene selects correct recording "+key)
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(folder.path_join(key.replace(":","-")+".png")) == OK,"Capture new boss room/portrait/dialogue "+key)
            await create_timer(2).timeout
            if number == 0:
                for tick in 150:
                    if not ui.battle_ui.busy: break
                    await create_timer(.1).timeout
                check(not ui.battle_ui.busy,"Entrance completes before pause input")
                var before := JourneySnapshot.encode(j)
                print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
                print("OS_KEY Escape")
                await create_timer(.4).timeout
                check(ui.battle_ui.menu_panel.visible and music.muffled,"Actual boss pause muffles dedicated music")
                print("OS_KEY Escape")
                await create_timer(.4).timeout
                check(not music.muffled and JourneySnapshot.encode(j) == before,"Boss pause restores audio and preserves game state")
            ui.free()
            await process_frame
            number += 1
    music.stop_music()
    root.get_node("GameAmbience").clear()
    await create_timer(1.4).timeout
    print("Native bosses: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
