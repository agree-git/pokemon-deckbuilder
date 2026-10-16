class_name PixelStage
extends Control
## Native-resolution stage. Pixel art is a texture style, not a screen resolution.

var canvas := BattleCanvas.new()
var source_ratio := Vector2(0.25, 0.6)
var target_ratio := Vector2(0.75, 0.52)

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(canvas)
    resized.connect(_layout)
    _layout()

func _layout() -> void:
    canvas.canvas_size = size
    canvas.source_anchor = (size * source_ratio).round()
    canvas.target_anchor = (size * target_ratio).round()
    canvas.layout_battlefield()
