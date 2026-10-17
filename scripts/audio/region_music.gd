class_name RegionMusic
extends RefCounted
## Presentation-only metadata and route context. No campaign RNG or save writes.
const MANIFEST := "res://assets/audio/region_music/manifest.json"

static func tracks() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    result.assign(data["tracks"])
    return result

static func context(journey: TacticalJourney) -> String:
    var stop := journey.current()
    var biome := journey.biome()
    if journey.full_campaign and int(stop.get("chapter",0)) >= 8: return "8:league"
    return "%d:%s" % [int(stop.get("chapter",0)),str(biome.get("id",biome.get("type","")))]
