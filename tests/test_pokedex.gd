extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    var catalog := VisualCatalog.new()
    var legacy := VisualCatalog.new(false)
    check(catalog.pokemon.size() == 1412 and legacy.pokemon.size() == 468,"Complete1025 species and permanent forms; frozen legacy catalog")
    check(catalog.moves.size() == 919,"All919 mainline move identities and presentations")
    var dex_ids := {}
    var roots := {}
    for entry: Dictionary in catalog.pokemon:
        var id := int(entry["id"])
        dex_ids[int(entry["dex_id"])] = true
        check(VisualCatalog.supports(id) and PokemonStats.base(id).size() == 6,"Six stats and supported identity "+str(id))
        var root_id := catalog.starter_species_id(id)
        check(root_id > 0 and catalog.starter_species_id(root_id) == root_id,"Acyclic reachable starter family "+str(id))
        roots[root_id] = true
        check(not PokedexExpansion.ability_text(id).is_empty(),"Original ability metadata "+str(id))
        for back: bool in [false,true]:
            var texture: Texture2D = load(VisualCatalog.sprite_path(id,back))
            check(texture != null and texture.get_image().get_used_rect().has_area(),"Real correctly facing sprite "+str(id)+"/"+str(back))
        var cry: AudioStreamOggVorbis = load("res://assets/audio/cries/%d.ogg" % id)
        check(cry != null and cry.get_length() > 0,"Real Vorbis cry "+str(id))
        var playback := cry.instantiate_playback()
        playback.start()
        var audio := playback.mix_audio(1,1024)
        check(audio.size() == 1024,"Cry engine decode "+str(id))
        playback.stop()
        var member := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        member.types.assign(entry["types"])
        TacticalGrowth.initialize(member,true)
        check(member.content_version == 2 and member.learned_skills.size() in range(1,5) and member.max_hp > 0,"Playable Lv.5 learnset and growth "+str(id))
        var previous := 0
        for move: Dictionary in TacticalGrowth.species_data(id,true)["learnset"]:
            check(int(move["level"]) >= previous and not TacticalMoves.definition(TacticalMoves.key_for(int(move["move"]))).is_empty(),"Complete ordered learnset "+str(id))
            previous = int(move["level"])
    check(dex_ids.size() == 1025,"Every National Dex number represented exactly once as a species")
    for id in range(1,1026): check(dex_ids.has(id),"National Dex coverage "+str(id))
    for entry: Dictionary in catalog.moves:
        var view := TacticalMoves.definition(TacticalMoves.key_for(int(entry["id"])))
        check(view.get("type","") in VisualCatalog.TYPE_COLORS and not str(view.get("description","")).is_empty(),"Usable move card and effect presentation "+str(entry["id"]))
    for entry: Dictionary in catalog.moves:
        var combat := TacticalBattle.new()
        var owner := combat.active()
        var key := TacticalMoves.key_for(int(entry["id"]))
        var card := BattleCardInstance.new(99000,key,owner.uid)
        combat.hand.assign([card])
        combat.energy = 10
        check(combat.play_card(card.uid).is_empty() and combat.energy >= 0 and combat.enemy().hp >= 0,"Actual card resolution for every move "+str(entry["id"]))
    check(PokedexExpansion.move_type(30044,449,"normal") == "electric","Arceus Judgment follows permanent type form")
    var arceus := BattlePokemon.new(TacticalContent.member_definition(30044,catalog),30044)
    arceus.types.assign(catalog.species(30044)["types"])
    TacticalGrowth.initialize(arceus,true)
    var combat := TacticalBattle.new()
    combat.party.assign([arceus])
    var judgment := BattleCardInstance.new(99001,"move_449",arceus.uid)
    check(combat.card_view(judgment)["type"] == "electric" and TacticalMoves.definition("move_449")["type"] == "normal","Actual form-specific card preview leaves global move definition unchanged")
    for biome: Dictionary in catalog.biomes:
        for encounter: Dictionary in biome["encounters"]:
            var id := int(encounter["pokemon_id"])
            check(id not in RareEncounter.IDS and not catalog.species(id)["is_legendary"] and not catalog.species(id)["is_mythical"] and biome["type"] in catalog.species(id)["types"],"Type-appropriate ordinary encounter preserves rare gates")
    for entry: Dictionary in legacy.pokemon:
        check(catalog.species(int(entry["id"]))["types"] == entry["types"] and catalog.species(int(entry["id"]))["name"] == entry["name"],"Historical saved names/types preserved")
    check(not VisualCatalog.supports(10034) and not VisualCatalog.supports(10326),"Battle-only Mega forms excluded")
    for name: String in ["GameMusic","GameAmbience","GameAudio","GameCries"]: root.get_node(name).stop_all()
    await create_timer(.2).timeout
    print("National Dex: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
