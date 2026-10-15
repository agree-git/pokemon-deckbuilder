class_name JourneyTravel
extends Control
## A short, input-blocking walk between stops, using existing pixel assets.
signal arrived
const W = preload("res://scripts/ui/combat_widgets.gd")
const DURATION := 0.85
var progress := 0.0
var walkers: Array[Control] = []
var completed := false
func start(destination: String, biome: Dictionary, party: Array[BattlePokemon]) -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 100
    var background := TextureRect.new()
    background.texture = VisualCatalog.biome_texture(biome)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.02,0.05,0.07,0.52)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
    W.label(self,"다음 장소로 이동 중",Rect2(380,255,1160,60),25,W.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
    W.label(self,destination,Rect2(280,330,1360,74),38,W.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    W.panel(self,Rect2(0,700,1920,10),Color("6d7251"))
    for i in party.size():
        var actor := Control.new()
        actor.position = Vector2(470+i*230,510)
        actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(actor)
        W.sprite(actor,party[i].species_id,Rect2(0,0,150,150))
        walkers.append(actor)
    var bar := W.bar(self,Rect2(660,810,600,6),W.GOLD)
    var tween := UiMotion.begin(self,"travel")
    tween.tween_method(func(value: float):
        progress = value
        bar.get_child(0).size.x = value*600
        for i in walkers.size():
            walkers[i].position = Vector2(roundf(470+i*230+value*220),roundf(510+sin(value*TAU*3+i)*8))
        ,0.0,1.0,DURATION)
    tween.tween_callback(_arrive)
func _arrive() -> void:
    if completed: return
    completed = true
    hide()
    arrived.emit()
    queue_free()
func _input(event: InputEvent) -> void:
    if visible and (event is InputEventKey or event is InputEventMouseButton): get_viewport().set_input_as_handled()
