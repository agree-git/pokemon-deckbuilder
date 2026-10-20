extends SceneTree
func _initialize()->void:call_deferred('run')
func run()->void:
    var input:=TextEdit.new();input.position=Vector2(60,60);input.size=Vector2(800,100);root.add_child(input)
    input.text_changed.connect(func():print('TEXT ',input.text))
    root.window_input.connect(func(e:InputEvent):
        if e is InputEventKey: print('EVENT ',e.keycode,' ',e.unicode,' ',e.pressed))
    await create_timer(1).timeout
    print('OS_FOCUS ',DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print('OS_CLICK 200 100');await create_timer(1).timeout
    for letter in 'wjsrl':
        print('OS_KEY ',letter);await create_timer(.5).timeout
        print('STATE ',input.text,'/',input.get_line_with_ime(0),'/',input.has_ime_text())
    print('OS_KEY Return');await create_timer(.5).timeout
    print('FINAL ',input.text)
    input.free();quit()
