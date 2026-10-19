extends Panel
## Presentation-only controls shared by battle and camp Esc menus.
const W = preload("res://scripts/ui/combat_widgets.gd")
var previous_button: Button
var play_button: Button
var next_button: Button
var volume_slider: HSlider
var title_label: Label
var subtitle: Label
var elapsed: Label
var duration: Label
var progress: ProgressBar
var volume_label: Label
var _music: Node
var _preferences: Node

func _ready() -> void:
    name = "MusicPlayer"
    mouse_filter = Control.MOUSE_FILTER_STOP
    _music = get_node("/root/GameMusic")
    _preferences = get_node("/root/Preferences")
    add_theme_stylebox_override("panel",W.box(Color("10252c"),Color("51685f"),12))
    var cover := W.panel(self,Rect2(24,24,96,96),Color("2b4541"),Color("667963"),12)
    W.label(cover,"♪",Rect2(0,0,96,96),58,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    title_label = W.label(self,"",Rect2(144,24,size.x-168,56),22,W.GOLD)
    title_label.mouse_filter = Control.MOUSE_FILTER_PASS
    subtitle = W.label(self,"",Rect2(144,84,size.x-168,32),15,W.MUTED)
    progress = ProgressBar.new()
    progress.position = Vector2(24,144)
    progress.size = Vector2(size.x-48,8)
    progress.show_percentage = false
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress.add_theme_stylebox_override("background",W.box(Color("30494b")))
    progress.add_theme_stylebox_override("fill",W.box(Color("91c8a4")))
    add_child(progress)
    elapsed = W.label(self,"0:00",Rect2(24,164,100,24),14,W.MUTED)
    duration = W.label(self,"0:00",Rect2(size.x-124,164,100,24),14,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    var row := Rect2(24,208,size.x-48,56)
    previous_button = W.button(self,W.row_rect(row,0,3),func(): _music.previous_track(),"이전 곡")
    play_button = W.button(self,W.row_rect(row,1,3),_music.toggle_playback)
    next_button = W.button(self,W.row_rect(row,2,3),func(): _music.next_track(),"다음 곡")
    for button: Button in [previous_button,play_button,next_button]: button.add_theme_font_size_override("font_size",19)
    W.icon(self,"sound",Rect2(24,308,24,24))
    W.label(self,"음악 음량",Rect2(60,304,96,32),15,W.MUTED)
    volume_slider = HSlider.new()
    volume_slider.position = Vector2(168,304)
    volume_slider.size = Vector2(size.x-264,32)
    volume_slider.max_value = 100
    volume_slider.step = 1
    volume_slider.focus_mode = Control.FOCUS_NONE
    volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    volume_slider.value_changed.connect(func(value: float): _preferences.set_audio_volume("music",value/100.0))
    add_child(volume_slider)
    volume_label = W.label(self,"",Rect2(size.x-72,304,48,32),15,W.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
    _music.theme_changed.connect(_sync)
    _music.playback_changed.connect(_sync)
    _preferences.changed.connect(_sync)
    _sync()

func _sync(_key := "") -> void:
    title_label.text = _music.current_track_title()
    title_label.tooltip_text = title_label.text
    previous_button.disabled = not _music.can_previous_track()
    next_button.disabled = not _music.can_next_track()
    previous_button.tooltip_text = "앞서 들었던 곡으로 돌아갑니다." if not previous_button.disabled else "돌아갈 이전 곡이 없습니다."
    next_button.tooltip_text = "현재 곡을 제외한 음악을 무작위로 재생합니다." if not next_button.disabled else "전용 전투 음악은 유지됩니다. 일반 전투·야영지에서 곡을 바꿀 수 있습니다."
    play_button.text = "재생" if _music.playback_paused else "일시정지"
    subtitle.text = "원정 플레이리스트 · 무작위 · 반복" if _music.can_next_track() else "전용 음악 · 반복 재생"
    if _music.playback_paused: subtitle.text = "일시정지 · "+subtitle.text
    elif _preferences.audio_muted or _preferences.master_volume <= 0.0 or _preferences.music_volume <= 0.0:
        subtitle.text = "음소거 · "+subtitle.text
    volume_slider.set_value_no_signal(_preferences.music_volume*100.0)
    volume_label.text = "%d%%" % roundi(_preferences.music_volume*100.0)

func _process(_delta: float) -> void:
    if not is_visible_in_tree(): return
    var length := 0.0
    var position := 0.0
    if _music._active >= 0:
        var player: AudioStreamPlayer = _music.players[_music._active]
        if player.stream != null:
            length = player.stream.get_length()
            position = fposmod(player.get_playback_position(),length) if length > 0 else 0.0
    progress.max_value = maxf(length,1.0)
    progress.value = position
    elapsed.text = _time(position)
    duration.text = _time(length)

func _time(seconds: float) -> String:
    return "%d:%02d" % [int(seconds)/60,int(seconds)%60]
