extends "res://tests/test_build_concepts_ui.gd"
func run() -> void:
    Engine.max_fps = 60
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-concepts")
    root.mode = Window.MODE_FULLSCREEN
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    for key: String in BattleWeather.KINDS:
        await fresh([["weather_"+key,0],["water_gun",7]],[])
        check(not view.weather_chip.visible and view.stage.canvas.weather.is_empty(),"No weather before card use")
        var preview := BattleCardPreview.analyze(view.battle,1)
        view.action_preview.display(preview,view.battle.active().uid)
        check(view.action_preview.resources.text.contains("weather_"+key) and preview["weather_after"] == key,"Weather appears in card action forecast")
        await use(1)
        check(view.weather_chip.visible and view.weather_chip.get_node("Title").text == BattleWeather.TITLES[key]+" · 5턴","Real weather card displays icon and remaining turns")
        check(view.stage.canvas.weather == key and view.weather_chip.tooltip_text.contains("양쪽") and "weather" in view.playback_kinds,"Weather effect and full rules follow staged event")
        await use(2)
        check(view.battle.active().uid == 7 and view.weather_chip.get_node("Title").text.ends_with("5턴"),"Weather survives real automatic switch")
        await click(view.end_button)
        check(view.weather_chip.get_node("Title").text.ends_with("4턴") and "weather_turn" in view.playback_kinds,"Round end updates weather through sequential playback")
        # Publish a normal encounter screenshot, not the high-HP test fixture.
        view.battle.enemy().max_hp = PokemonStats.value(view.battle.enemy().species_id,view.battle.enemy().level,"hp")
        view.battle.enemy().hp = view.battle.enemy().max_hp
        view._refresh()
        await picture("weather-"+key+"-battle")
    view.free()
    await weather_gallery()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.15).timeout
    print("WEATHER_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
func weather_gallery() -> void:
    var page := Control.new()
    root.add_child(page)
    W.panel(page,Rect2(0,0,1920,1080),Color("0b1d24"))
    W.label(page,"날씨 · 비 / 눈 / 쾌청 / 모래바람",Rect2(80,18,1760,48),32,W.GOLD)
    W.label(page,"위: 기본 / 아래: 강화 · 양쪽 모두 적용 · 다른 날씨로 교체 · 5턴 후 종료",Rect2(80,70,1760,32),20,W.MUTED)
    for i in 4:
        var key: String = "weather_"+BattleWeather.KINDS[i]
        for row in 2:
            var card := BattleCardInstance.new(1,key,0)
            card.upgraded = row == 1
            var face := CardStackView.new()
            face.definition = TacticalContent.definition(card)
            face.key = key
            face.position = Vector2(150+i*450,108+row*334)
            face.scale = Vector2.ONE*1.15
            page.add_child(face)
        var description := W.label(page,BattleWeather.description(BattleWeather.KINDS[i]),Rect2(112+i*450,835,398,180),24,W.TEXT)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    await process_frame
    await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png("/tmp/pokemon-concepts/weather.png") == OK,"Capture real base/upgraded weather card gallery")
    page.free()
