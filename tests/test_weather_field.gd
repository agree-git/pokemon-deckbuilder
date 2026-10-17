extends "res://tests/test_build_concepts_ui.gd"
## Exercise actual compositing, transitions, UI clipping and immutable combat state.
func run() -> void:
    Engine.max_fps = 60
    root.mode = Window.MODE_FULLSCREEN
    root.size = Vector2i(1920,1080)
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-weather-field")
    await fresh([["weather_rain",0],["weather_snow",0],["weather_sun",0],["weather_sand",0],["water_gun",7]],[])
    view.battle.energy = 3+view.battle.turn_energy_bonus
    view.battle.enemy().max_hp = PokemonStats.value(view.battle.enemy().species_id,view.battle.enemy().level,"hp")
    view.battle.enemy().hp = view.battle.enemy().max_hp
    view._refresh()
    UiMotion.finish_tree(view)
    await create_timer(0.2).timeout
    var canvas := view.stage.canvas
    var layer := canvas.weather_layer
    check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and layer.clip_contents,"Weather cannot intercept cards or escape its field")
    check(canvas.get_children().find(layer) > canvas.get_children().find(canvas.target_sprite) and canvas.get_children().find(layer) < canvas.get_children().find(canvas.effect),"Weather covers combatants while move VFX remain above it")
    canvas.set_process(false)
    layer.set_process(false)
    var before := view.battle.snapshot()
    var feet := [canvas.foot_anchor(true),canvas.foot_anchor(false)]
    var initial_clock := layer.clock
    layer.set_weather("rain")
    layer.advance(BattleWeatherVisual.FADE_SECONDS*0.5)
    check(is_equal_approx(layer.weights["rain"],0.5),"Weather enters progressively rather than flashing on")
    layer.set_weather("sun")
    layer.advance(BattleWeatherVisual.FADE_SECONDS*0.25)
    check(is_equal_approx(layer.weights["rain"],0.25) and is_equal_approx(layer.weights["sun"],0.25),"Changing weather crossfades the visible layers")
    var unchanged := layer.weights.duplicate()
    layer.set_weather("sun")
    check(layer.weights == unchanged,"Repeated HUD refresh cannot restart the weather fade")
    layer.set_weather("")
    layer.advance(1)
    check(not layer.visible and layer.weights.values().all(func(v: float): return v == 0),"Weather expiration removes every lingering layer")
    for key: String in BattleWeather.KINDS:
        layer.set_weather(key)
        layer.advance(1)
        check(layer.visible and layer.weights[key] == 1,"Every weather has an active visible layer: "+key)
    check(layer.clock > initial_clock and view.battle.snapshot() == before,"Ambient animation and transitions preserve battle state and seeded RNG")
    var catalog := VisualCatalog.new()
    var league: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/league.json"))
    var backdrops := {"forest":catalog.biomes[3],"indoor":BattleBackdrops.for_stop({"kind":"champion","trainer":league["champions"][0]},catalog.biomes[3])}
    for backdrop: String in backdrops:
        canvas.set_backdrop(backdrops[backdrop])
        view.get_node("StageTitle").text = "햇살숲" if backdrop == "forest" else "리그 실내"
        canvas._process(0)
        feet = [canvas.foot_anchor(true),canvas.foot_anchor(false)]
        for key: String in BattleWeather.KINDS:
            BattleWeather.clear(view.battle.powers)
            BattleWeather.apply(view.battle,key)
            view._refresh()
            var model := view.battle.snapshot()
            layer.advance(1)
            var phase := layer.clock
            check(layer.weather == key and layer.weights[key] == 1,"Actual weather state drives field rendering: "+key)
            if DisplayServer.get_name() != "headless":
                layer.hide()
                var plain := await capture()
                layer.show()
                layer.queue_redraw()
                var weather := await capture()
                check(weather.get_size() == Vector2i(1920,1080),"Native review capture is 1920x1080")
                check(plain.get_region(Rect2i(0,0,1920,72)).get_data() == weather.get_region(Rect2i(0,0,1920,72)).get_data(),"Weather does not tint the top bar")
                check(plain.get_region(Rect2i(0,790,1920,290)).get_data() == weather.get_region(Rect2i(0,790,1920,290)).get_data(),"Weather leaves the whole hand, piles and end-turn button untouched")
                check(opaque_ui_unchanged(plain,weather,Rect2i(36,104,240,252)),"Party names and HP text remain crisp above weather")
                check(plain.get_region(Rect2i(300,300,1300,380)).get_data() != weather.get_region(Rect2i(300,300,1300,380)).get_data(),"Visible battlefield and combatants receive weather: "+key)
                if key == "sun":
                    check(light_gain(plain,weather,Rect2i(0,72,280,28)) > light_gain(plain,weather,Rect2i(1600,620,300,60))+0.02,"Sun light source is visibly stronger in the upper-left corner")
                check(weather.save_png("/tmp/pokemon-weather-field/"+backdrop+"-"+key+".png") == OK,"Save weather review frame")
                layer.advance(0.7)
                var moving := await capture()
                check(moving.get_region(Rect2i(300,100,1300,250)).get_data() != weather.get_region(Rect2i(300,100,1300,250)).get_data(),"Weather keeps animating between combat actions: "+key)
                # Same state/time must reproduce identical pixels, independent of redraws.
                layer.clock = phase
                layer.queue_redraw()
                var repeated := await capture()
                check(repeated.get_region(Rect2i(300,100,1300,250)).get_data() == weather.get_region(Rect2i(300,100,1300,250)).get_data(),"Weather rendering is deterministic without consuming game randomness")
            check(model == view.battle.snapshot() and feet == [canvas.foot_anchor(true),canvas.foot_anchor(false)],"Weather never moves calibrated feet or changes combat state")
    # Real UI layout geometry follows native viewport at every supported ratio.
    for viewport: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(900,900)]:
        root.mode = Window.MODE_WINDOWED
        root.size = viewport
        canvas.set_process(true)
        await process_frame
        await process_frame
        check(layer.position == Vector2(0,72) and is_equal_approx(layer.size.x,canvas.canvas_size.x) and layer.position.y+layer.size.y <= 780,"Weather boundary follows stage without overflowing lower HUD: "+str(viewport))
        canvas.set_process(false)
    canvas.weather = ""
    layer.advance(1)
    check(not layer.visible,"Battle reset/clear returns to the original field")
    view.free()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.2).timeout
    print("WEATHER_FIELD: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
func capture() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func opaque_ui_unchanged(plain: Image,weather: Image,rect: Rect2i) -> bool:
    var marks := 0
    var inks := [W.TEXT.to_rgba32(),W.GOLD.to_rgba32(),W.MUTED.to_rgba32()]
    for y in range(rect.position.y,rect.end.y):
        for x in range(rect.position.x,rect.end.x):
            var pixel := plain.get_pixel(x,y).to_rgba32()
            if pixel not in inks: continue
            marks += 1
            if weather.get_pixel(x,y).to_rgba32() != pixel: return false
    return marks > 10

func light_gain(plain: Image,weather: Image,rect: Rect2i) -> float:
    var gain := 0.0
    var count := 0
    for y in range(rect.position.y,rect.end.y,4):
        for x in range(rect.position.x,rect.end.x,8):
            var before := plain.get_pixel(x,y)
            var after := weather.get_pixel(x,y)
            gain += (after.r+after.g+after.b-before.r-before.g-before.b)/3.0
            count += 1
    return gain/maxi(1,count)
