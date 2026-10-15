class_name VisualCatalog
extends RefCounted
## Immutable content lookup. No battle state, damage, or encounter RNG here.

const TYPE_COLORS := {
    "normal": Color("b4b5a8"), "fire": Color("ff9564"),
    "water": Color("6bbdff"), "grass": Color("8bd6a0"),
    "electric": Color("ffe27b"), "ice": Color("9de5e9"),
    "fighting": Color("ef9a81"), "poison": Color("c59bef"),
    "ground": Color("e7bd82"), "flying": Color("a9cafa"),
    "psychic": Color("f5a5d0"), "bug": Color("c3d77b"),
    "rock": Color("ccbe9b"), "ghost": Color("ac9be5"),
    "dragon": Color("a3a5ff"), "dark": Color("ab9db7"),
    "steel": Color("b1cfda"), "fairy": Color("f3bddf"),
}
const EFFECT_NAMES := {
    "projectile": "원소 투사체", "impact": "타격", "slash": "참격",
    "explosion": "폭발", "charge": "충전 후 발사", "shield": "보호막",
    "heal": "회복", "drain": "흡수", "stat_up": "능력 상승", "stat_down": "능력 하락",
    "burn": "화상", "poison": "독", "paralysis": "마비", "sleep": "수면",
    "freeze": "얼음", "confusion": "혼란", "seed": "씨뿌리기", "bind": "속박",
    "mist": "필드 안개", "evade": "이동", "transform": "변신",
    "seal": "봉인", "splash": "도약", "utility": "보조 연출",
}

var pokemon: Array = []
var moves: Array = []
var biomes: Array = []
var types: Array = []
var gyms: Array = []
var _pokemon_by_id: Dictionary = {}
var _moves_by_id: Dictionary = {}
var _type_names: Dictionary = {}

func _init() -> void:
    var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
    pokemon = content["pokemon"]
    moves = content["moves"]
    types = content["types"]
    biomes = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
    gyms = JSON.parse_string(FileAccess.get_file_as_string("res://data/gyms.json"))
    for entry: Dictionary in pokemon:
        _pokemon_by_id[int(entry["id"])] = entry
    for entry: Dictionary in moves:
        _moves_by_id[int(entry["id"])] = entry
    for entry: Dictionary in types:
        _type_names[entry["key"]] = entry["name"]

func species(id: int) -> Dictionary:
    return _pokemon_by_id.get(id, {})

func move_by_id(id: int) -> Dictionary:
    return _moves_by_id.get(id, {})

func gym_for_type(key: String) -> Dictionary:
    for gym: Dictionary in gyms:
        if gym["type"] == key: return gym
    return {}

func type_name(key: String) -> String:
    return _type_names.get(key, key)

static func type_color(key: String) -> Color:
    return TYPE_COLORS.get(key, Color.WHITE)

static func sprite_path(id: int, back: bool = false) -> String:
    return "res://assets/pokemon/%s/%03d.png" % ["back" if back else "front", id]

static func biome_texture(biome: Dictionary) -> AtlasTexture:
    var atlas := AtlasTexture.new()
    atlas.atlas = load(biome["background"])
    var cell := Vector2(atlas.atlas.get_width() / 2.0, atlas.atlas.get_height() / 3.0)
    var index: int = int(biome["cell"])
    atlas.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
    atlas.filter_clip = true
    return atlas
