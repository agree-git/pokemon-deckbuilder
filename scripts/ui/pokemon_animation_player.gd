extends Node
## One lightweight clock per visible Pokemon; never touches encounter/battle RNG.
var species_id := 0
var back_view := false
var host: CanvasItem
var atlas: AtlasTexture
var frames: Array = []
var frame_index := 0
var elapsed := 0.0
var cycle := 0.0
func configure(target: CanvasItem,id: int,back: bool,record: Dictionary,texture: AtlasTexture) -> void:
    host = target
    species_id = id
    back_view = back
    atlas = texture
    host.set("texture",atlas)
    frames = record.get("frames",[])
    frame_index = 0
    elapsed = 0.0
    cycle = 0.0
    for frame: Array in frames: cycle += float(frame[4])
func advance(delta: float) -> void:
    if frames.is_empty(): return
    elapsed += fmod(delta,cycle)
    while elapsed >= float(frames[frame_index][4]):
        elapsed -= float(frames[frame_index][4])
        frame_index = (frame_index+1)%frames.size()
    var frame: Array = frames[frame_index]
    atlas.region = Rect2(frame[0],frame[1],frame[2],frame[3])
func _process(delta: float) -> void:
    if host != null and host.is_visible_in_tree(): advance(delta)
