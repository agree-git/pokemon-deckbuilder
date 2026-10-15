class_name CombatWidgets
extends RefCounted
## Native-resolution UI with original 16px icons. Children never steal button input.
const TEXT := Color("e8ede7")
const MUTED := Color("9bafaf")
const GOLD := Color("edcb80")
static var _icons: Dictionary = {}
static var _portraits: Dictionary = {}
static func texture(key: String) -> Texture2D:
    if not ResourceLoader.exists("res://assets/ui/icons/%s.svg" % key): key = "normal"
    if not _icons.has(key):
        _icons[key] = load("res://assets/ui/icons/%s.svg" % key)
    return _icons[key]
static func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(0)
    return style
static func panel(parent: Node, rect: Rect2, color := Color("14282f"), border := Color("344b51"), radius := 8) -> Panel:
    var panel_node := Panel.new()
    panel_node.position = rect.position
    panel_node.size = rect.size
    panel_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel_node.add_theme_stylebox_override("panel",box(color,border,radius))
    parent.add_child(panel_node)
    return panel_node
static func label(parent: Node, value: String, rect: Rect2, font_size := 18, color := TEXT, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var node := Label.new()
    node.position = rect.position
    node.size = rect.size
    node.text = value
    node.add_theme_font_size_override("font_size",font_size)
    node.add_theme_color_override("font_color",color)
    node.horizontal_alignment = alignment
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.clip_text = true
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node
static func icon(parent: Node, key: String, rect: Rect2) -> TextureRect:
    var node := TextureRect.new()
    node.texture = texture(key)
    node.position = rect.position
    node.size = rect.size
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node
static func sprite(parent: Node, species: int, rect: Rect2) -> TextureRect:
    if not _portraits.has(species):
        var source: Texture2D = load(VisualCatalog.sprite_path(species))
        var atlas := AtlasTexture.new()
        atlas.atlas = source
        atlas.region = source.get_image().get_used_rect()
        _portraits[species] = atlas
    var portrait: AtlasTexture = _portraits[species]
    var fit := minf(rect.size.x/portrait.region.size.x,rect.size.y/portrait.region.size.y)
    # Large evolved species also need to fit a 48px roster portrait.
    # Use integer zoom or reciprocal integer reduction, keeping nearest sampling.
    var factor := floorf(fit) if fit >= 1.0 else 1.0/ceilf(1.0/fit)
    var dimensions := (portrait.region.size*factor).floor()
    var node := TextureRect.new()
    node.texture = portrait
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.position = (rect.position+(rect.size-dimensions)/2).round()
    node.size = dimensions
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node
static func button(parent: Node, rect: Rect2, action: Callable, title := "") -> Button:
    var node := Button.new()
    node.position = rect.position
    node.size = rect.size
    node.text = title
    node.focus_mode = Control.FOCUS_NONE
    node.pressed.connect(action)
    parent.add_child(node)
    UiMotion.bind_button(node)
    return node
static func icon_button(parent: Node, key: String, rect: Rect2, action: Callable, tip: String) -> Button:
    var node := button(parent,rect,action)
    var side := minf(32,minf(rect.size.x,rect.size.y)-20)
    icon(node,key,Rect2((rect.size-Vector2.ONE*side)/2,Vector2.ONE*side))
    node.tooltip_text = tip
    return node
static func bar(parent: Node, rect: Rect2, color := Color("91c8a4")) -> ColorRect:
    var track := ColorRect.new()
    track.position = rect.position
    track.size = rect.size
    track.color = Color("344a50")
    track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fill := ColorRect.new()
    fill.size = rect.size
    fill.color = color
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    track.add_child(fill)
    parent.add_child(track)
    return track
static func fill_bar(track: ColorRect, value: int, maximum: int) -> void:
    UiMotion.value(track.get_child(0),"size:x",track.size.x*clampf(float(value)/maxi(1,maximum),0,1))
static func badge(parent: Node, value: String, rect: Rect2, color := GOLD) -> Label:
    panel(parent,rect,Color("314448"),Color("6b7158"),int(rect.size.y/2))
    return label(parent,value,rect,19,color,HORIZONTAL_ALIGNMENT_CENTER)
static func clear(node: Node) -> void:
    for child: Node in node.get_children():
        node.remove_child(child)
        child.queue_free()
static func fade(button_node: Button) -> void:
    # Godot adds a PopupPanel child while the built-in tooltip is visible.
    for child: Node in button_node.get_children():
        if child is CanvasItem:
            child.modulate.a = 0.43 if button_node.disabled else 1.0
