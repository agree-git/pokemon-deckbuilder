extends SceneTree
## Read-only audit of current representative intents. Writes only the explicit output path.
func _initialize() -> void:
    var output := OS.get_environment("BOSS_ACE_AUDIT_OUTPUT")
    if output.is_empty():
        push_error("BOSS_ACE_AUDIT_OUTPUT is required")
        quit(1)
        return
    var records: Array = []
    var catalog := VisualCatalog.new()
    var checks := 0
    for key: String in BossParties.entries():
        var party := BossParties.party(key)
        for species: int in BossParties.aces(key):
            var slot := party.rfind(species)
            var probes: Array = []
            for level: int in [18,50,100]:
                var current := BossTactics.build(key,slot,species,level,catalog.species(species)["types"],true)
                assert(BossTactics.valid(current))
                probes.append({"level":level,"style":current["boss_style"],"intents":current["intents"]})
                checks += 1
            records.append({"key":key,"species":species,"slot":slot,"probes":probes})
    var file := FileAccess.open(output,FileAccess.WRITE)
    assert(file != null)
    var views := {}
    var spec_path := OS.get_environment("BOSS_ACE_SPEC_PATH")
    if not spec_path.is_empty():
        var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
        for entry: Dictionary in spec["entries"]:
            for ace: Dictionary in entry["aces"]:
                for id: int in ace["moves"]:
                    views[str(id)] = TacticalMoves.definition(TacticalMoves.key_for(id))
    file.store_string(JSON.stringify({"records":records,"checks":checks,"player_move_views":views},"  ")+"\n")
    file.close()
    print("BOSS ACE AUDIT: %d representatives / %d valid current patterns" % [records.size(),checks])
    quit()
