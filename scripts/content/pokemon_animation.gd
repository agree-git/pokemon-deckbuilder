extends RefCounted
## Local presentation only. The national species data and save fingerprints stay frozen.
const PATH := "res://assets/pokemon/animated/manifest.json"
const PLAYER := preload("res://scripts/ui/pokemon_animation_player.gd")
const CACHE_BYTES := 32*1024*1024
static var _data: Dictionary = {}
static var _sheets: Dictionary = {}
static var _weak_sheets: Dictionary = {}
static var _order: Array[String] = []
static var _bytes := 0
static func data() -> Dictionary:
    if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func entry(id: int,back := false) -> Dictionary:
    return data()["views"].get("%d/%s" % [id,"back" if back else "front"],{})
static func _sheet(path: String) -> Texture2D:
    var texture: Texture2D
    if _sheets.has(path):
        texture = _sheets[path]
        _order.erase(path)
    else:
        if _weak_sheets.has(path): texture = _weak_sheets[path].get_ref()
        if texture == null:
            # Source checkouts can display new sheets before the editor imports them.
            texture = load(path) if FileAccess.file_exists(path+".import") else ImageTexture.create_from_image(Image.load_from_file(path))
        _weak_sheets[path] = weakref(texture)
        _sheets[path] = texture
        _bytes += texture.get_width()*texture.get_height()*4
    _order.append(path)
    while _bytes > CACHE_BYTES and _order.size() > 1:
        var oldest: String = _order.pop_front()
        var removed: Texture2D = _sheets[oldest]
        _bytes -= removed.get_width()*removed.get_height()*4
        _sheets.erase(oldest)
    return texture
static func texture(id: int,back := false) -> AtlasTexture:
    var record := entry(id,back)
    var result := AtlasTexture.new()
    if record.has("sheet"):
        result.atlas = _sheet(record["sheet"])
        var frame: Array = record["frames"][0]
        result.region = Rect2(frame[0],frame[1],frame[2],frame[3])
    else:
        result.atlas = load(VisualCatalog.sprite_path(id,back))
        result.region = result.atlas.get_image().get_used_rect()
    result.filter_clip = true
    result.set_meta("pokemon_bounds",Rect2i(Vector2i.ZERO,Vector2i(result.region.size)))
    return result
static func bind(node: CanvasItem,id: int,back := false) -> void:
    var player := node.get_node_or_null("PokemonAnimation")
    if player == null:
        player = PLAYER.new()
        player.name = "PokemonAnimation"
        node.add_child(player)
    if player.species_id == id and player.back_view == back: return
    player.configure(node,id,back,entry(id,back),texture(id,back))
