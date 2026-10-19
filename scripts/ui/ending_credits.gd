extends Control
## Presentation only: never settles battles, writes saves or consumes journey RNG.
signal closed
const W = preload("res://scripts/ui/combat_widgets.gd")
const SECTIONS := [
    ["기획 · 제작", "DO"],
    ["함께한 트레이너", "끝까지 원정대를 이끈 당신"],
    ["개발 지원", "OpenAI Codex"],
    ["포켓몬 · 원작 세계", "The Pokémon Company\nNintendo · GAME FREAK · Creatures"],
    ["포켓몬 데이터 · 울음소리 · 이미지", "PokéAPI / pokeapi · sprites · cries\n각 자료의 원저작자와 기여자"],
    ["움직이는 포켓몬 스프라이트", "Smogon / Pokémon Showdown!\nPagefault Games / PokéRogue\nElite Battle: DX · Pokémon Essentials\n각 스프라이트의 원작자와 커뮤니티 기여자"],
    ["트레이너 팬 스프라이트", "Gnomowladny · Beliot419 · Brumirage\nkyledove · ZacWeavile\nSmogon · SDM0 · PokéRogue 컬렉션"],
    ["음악", "사용자가 제공한 Pokémon BGM\n각 곡의 작곡가 · 연주자 · 원권리자"],
    ["글꼴", "Noto Sans KR\nNoto 프로젝트 기여자 · SIL Open Font License"],
    ["게임 엔진", "Godot Engine\nGodot 기여자 · MIT License"],
    ["상세 출처 · 라이선스", "배포 폴더의 ASSET_SOURCES.md\nassets/sources · licenses\n개별 작가·파일 출처와 원문 고지를 포함합니다."],
    ["팬 프로젝트", "Pokémon의 권리는 각 원권리자에게 있습니다.\n이 게임은 공식 Pokémon 제품이 아닙니다."],
    ["THANK YOU FOR PLAYING", "포켓몬 원정대를 플레이해 주셔서 감사합니다.\n다음 원정에서도 다시 만나요."]
]
var journey: TacticalJourney
var roll: Control
var viewport_panel: Control
var pause_button: Button
var close_button: Button
var progress_bar: ColorRect
var paused := false
var finished := false
var travel_distance := 0.0
var elapsed_distance := 0.0
var closing := false

func _ready() -> void:
    name = "EndingCredits"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 200
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(journey.biome() if journey != null else VisualCatalog.new().biomes[0])
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.025,0.06,0.075,0.95)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
    W.label(self,"POKÉMON EXPEDITION",Rect2(120,62,900,40),19,W.MUTED)
    W.label(self,"여정의 끝, 또 다른 시작",Rect2(120,114,1000,72),42,W.GOLD)
    W.label(self,"ENDING CREDITS",Rect2(1390,118,410,54),20,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    W.panel(self,Rect2(120,218,616,674),Color("14282f"),Color("405960"),16)
    _companions()
    W.panel(self,Rect2(800,218,1000,674),Color("102329"),Color("405960"),16)
    viewport_panel = Control.new()
    viewport_panel.name = "CreditsViewport"
    viewport_panel.position = Vector2(824,242)
    viewport_panel.size = Vector2(952,626)
    viewport_panel.clip_contents = true
    viewport_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(viewport_panel)
    roll = Control.new()
    roll.name = "Roll"
    roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
    viewport_panel.add_child(roll)
    var y := 0.0
    var last_section_y := 0.0
    for section: Array in SECTIONS:
        last_section_y = y
        W.label(roll,section[0],Rect2(24,y,904,42),20,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
        var height: float = section[1].count("\n")*40+48
        W.label(roll,section[1],Rect2(24,y+58,904,height),24,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        y += height+146
    travel_distance = viewport_panel.size.y-96+last_section_y-180
    roll.position.y = viewport_panel.size.y-96
    progress_bar = W.bar(self,Rect2(800,918,1000,3),W.GOLD).get_child(0)
    progress_bar.size.x = 0
    W.label(self,"SPACE 일시정지 · ↑↓ 스크롤 · ESC / ENTER 돌아가기",Rect2(120,958,1030,50),17,W.MUTED)
    pause_button = W.button(self,Rect2(1192,952,220,64),_toggle_pause,"일시정지")
    pause_button.name = "PauseCredits"
    close_button = W.button(self,Rect2(1436,952,364,64),close,"원정 결과로" if journey != null else "시작 화면으로")
    close_button.name = "CloseCredits"
    UiMotion.appear(self)

func _companions() -> void:
    W.icon(self,"badge",Rect2(368,258,120,120))
    W.label(self,"명예의 전당" if journey != null else "포켓몬 원정대",Rect2(144,406,568,60),36,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    var message := "당신과 동료들의 모험은 계속됩니다."
    if journey != null:
        message = "챔피언 %s 격파\n%d승 · 배지 %d개 · 총 %d턴" % [journey.route.champion["name"],journey.wins,journey.badges,journey.total_turns]
    W.label(self,message,Rect2(144,488,568,88),22,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    var ids: Array[int] = [1,4,7]
    if journey != null:
        ids.clear()
        for pokemon: BattlePokemon in journey.party: ids.append(pokemon.species_id)
    for i in ids.size():
        var x := 148+(560-ids.size()*176)/2+i*176
        W.sprite(self,ids[i],Rect2(x,620,168,144))
        if journey != null:
            W.label(self,journey.party[i].display_name,Rect2(x,786,168,36),18,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
            W.label(self,"Lv.%d" % journey.party[i].level,Rect2(x,826,168,28),16,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _process(delta: float) -> void:
    if not paused and not finished: _advance(delta*54.0)

func _advance(distance: float) -> void:
    elapsed_distance = clampf(elapsed_distance+distance,0,travel_distance)
    roll.position.y = viewport_panel.size.y-96-elapsed_distance
    progress_bar.size.x = 1000*elapsed_distance/maxf(travel_distance,1)
    finished = elapsed_distance >= travel_distance
    pause_button.text = "처음부터" if finished else ("계속 재생" if paused else "일시정지")

func _toggle_pause() -> void:
    if finished:
        paused = false
        _advance(-travel_distance)
    else:
        paused = not paused
        _advance(0)

func _input(event: InputEvent) -> void:
    if closing: return
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F11: return
        get_viewport().set_input_as_handled()
        if event.echo and event.keycode not in [KEY_UP,KEY_DOWN]: return
        match event.keycode:
            KEY_ESCAPE,KEY_ENTER: close()
            KEY_SPACE: _toggle_pause()
            KEY_UP: _advance(-120)
            KEY_DOWN: _advance(120)
    elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
        _advance(-100 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 100)
        get_viewport().set_input_as_handled()

func close() -> void:
    if closing: return
    closing = true
    closed.emit()
    queue_free()
