class_name LegacyStatsSnapshot
extends RefCounted
## Read-only compatibility for pre-removal saves. Never used by live stat rules.
static func max_hp(species: int, level: int) -> int:
    if species == 292: return 1
    return floori((2*int(PokemonStats.base(species)["hp"])+31)*level/100.0)+level+10

static func upgrade(source: Dictionary) -> Dictionary:
    # Caller validates the complete legacy graph before invoking this conversion.
    var data := source.duplicate(true)
    data["stat_basis"] = PokemonStats.BASIS
    for row: Dictionary in data["pokemon"].values():
        if row["species_stats"]:
            var old_max: int = row["max_hp"]
            var hp: int = row["hp"]
            var next_max := PokemonStats.value(row["species_id"],row["level"],"hp")
            row["max_hp"] = next_max
            row["hp"] = 0 if hp == 0 else (next_max if hp == old_max else maxi(1,next_max-(old_max-hp)))
        if row.has("evolution_training"):
            row["evolution_choice"] = {"attack":106,"defense":107,"balanced":237}[row["evolution_training"]]
            row.erase("evolution_training")
    var battle: Dictionary = data["battle"]
    for i in battle["enemies"].size():
        battle["enemy_definitions"][i]["max_hp"] = data["pokemon"][battle["enemies"][i]]["max_hp"]
    # Last action frames belong to the old formula; loading never replays them.
    battle["events"].clear()
    # Already granted turn energy and its historical speed comparison stay spent.
    return data
