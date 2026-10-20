extends SceneTree
var checks:=0
var failures:=0
var inline_ime:=OS.get_environment("POKEMON_IME_MODE")=="inline"
var output_dir:=OS.get_environment("POKEMON_IME_OUTPUT")
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
    checks+=1
    print("CHECK ",ok," ",message)
    if not ok: failures+=1
func key(symbol:String)->void:
    print("OS_KEY ",symbol)
    await create_timer(.22).timeout
func word(sequence:String,search:TextEdit,ui:PokedexWorkshop)->void:
    for symbol:String in sequence:
        await key(symbol)
        print("IME ",JSON.stringify({"key":symbol,"text":search.text,"query":ui.query,"composing":search.has_ime_text(),"focus":search.has_focus()}))
func visible_rows(ui:PokedexWorkshop)->Array:
    return ui.rows.get_children().filter(func(n:Node):return n is Panel and n.visible)
func run()->void:
    if DisplayServer.get_name()!="X11" or not OS.get_user_data_dir().begins_with("/tmp/pokemon-native-ime/") or output_dir.is_empty() or OS.get_environment("POKEMON_IME_MODE") not in ["inline","external"]:quit(2);return
    create_timer(45).timeout.connect(func():push_error("Native IME timeout");quit(3))
    var j:=TacticalJourney.new(712,"field_kit",[25,4,7],true)
    j.step=1;j.phase=TacticalJourney.MAP;j.enter_next()
    var before:=JourneySnapshot.encode(j)
    var host:=TacticalJourneyUI.new();host.journey=j;root.add_child(host)
    host._open_workshop("moves")
    await create_timer(1).timeout
    var ui:PokedexWorkshop=host.workshop
    var search:TextEdit=ui.content.get_node("WorkshopSearch")
    var ids:=ui.rows.get_children().map(func(n:Node):return n.get_instance_id())
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    var point:=root.get_final_transform()*(search.get_global_transform_with_canvas()*Vector2(80,24))+Vector2(root.position)
    print("OS_CLICK ",roundi(point.x)," ",roundi(point.y))
    await create_timer(.5).timeout
    await word("wjsrhkdtjrghk",search,ui)
    check(search.has_ime_text()==inline_ime and ui.query==("전광석화" if inline_ime else "전광석") and search.has_focus(),"Native IME preserves preceding syllables, expected composition mode and focus")
    check(visible_rows(ui).size()==1 and not ui.empty_label.visible,"Korean move-name query filters while final syllable is composing")
    await key("Return")
    check(not search.has_ime_text() and search.text=="전광석화" and ui.query=="전광석화" and search.get_line_count()==1,"Enter commits all four Korean syllables without a newline")
    await key("ctrl+a");await key("BackSpace")
    await word("wjsrl",search,ui)
    check(ui.query==("전기" if inline_ime else "전") and search.has_ime_text()==inline_ime and search.has_focus(),"Clearing and retyping Korean type query retains IME")
    check(not visible_rows(ui).is_empty() and visible_rows(ui).all(func(panel:Control):return str(panel.get_meta("search_terms")).contains("전기" if inline_ime else "전")),"Visible rows match native Korean type query")
    await key("BackSpace");await key("l")
    check(ui.query==("전기" if inline_ime else "전") and search.has_focus(),"Backspace edits composing Korean syllable and resumes typing")
    check(ids==ui.rows.get_children().map(func(n:Node):return n.get_instance_id()),"Native input never replaces result controls")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output_dir.path_join("korean-search-before-commit.png"))
    await key("Return")
    check(search.text=="전기" and ui.query=="전기" and not search.has_ime_text(),"Second Korean query commits normally")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output_dir.path_join("korean-search.png"))
    check(JourneySnapshot.encode(j)==before,"Native search leaves campaign and RNG unchanged")
    host.free();await process_frame
    print("NATIVE_KOREAN_IME ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
