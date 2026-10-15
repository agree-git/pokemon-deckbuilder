extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func ids(values: Array) -> Array[int]:
    var result: Array[int] = []
    result.assign(values)
    return result
func identity(cards: Array[BattleCardInstance]) -> Array:
    return cards.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid,c.upgraded])
func run() -> void:
    var catalog := VisualCatalog.new()
    var bases := []
    for entry: Dictionary in catalog.pokemon:
        var basic := catalog.starter_species_id(int(entry["id"]))
        if basic not in bases: bases.append(basic)
    for id: int in bases:
        var preview := StarterLoadout.new(ids([id]),catalog)
        check(preview.valid and preview.members.size() == 1,"Every supported base species has an actual starter preview: %d" % id)
        var p := preview.members[0]
        check(p.level == 5 and p.hp == PokemonStats.value(id,5,"hp") and p.types == catalog.species(id)["types"],"Starter preview uses original level-five stats and full types")
        var keys := p.learned_skills.duplicate()
        var counts := preview.counts()
        check(counts["trainer"] == 5 and counts["tool"] == 1 and counts["technique"] >= 9,"Solo loadout preserves the actual shared/owned card budget")
        for card: BattleCardInstance in preview.cards:
            var view := preview.view(card)
            check(view["cost"] >= 0 and not view["name"].is_empty() and not view["description"].is_empty(),"Every card face has playable content")
            check((view["species_id"] == id and view["owner_name"] == p.display_name) if card.owner_uid != 0 else (view["species_id"] == 0 and view["owner_name"].is_empty()),"Card portraits and labels refer to the actual owner")
        check(p.learned_skills == keys,"Browsing fallback cards never teaches or replaces an original move")
    for values: Array in [[1,4,7],[63,129,150],[144,151,386],[265],[172,236],[349,360,235]]:
        var selected := ids(values)
        var preview := StarterLoadout.new(selected,catalog)
        for seed_value: int in [0,42]:
            var j := TacticalJourney.new(seed_value,"field_kit",selected,true)
            var saved := JourneySnapshot.encode(j)
            var before_rng := j.battle._rng.state
            check(identity(preview.cards) == identity(j.deck),"Preview and real start allocate the exact same keys, owners, copies and UIDs")
            for i in selected.size():
                var a := preview.members[i]
                var b := j.party[i]
                check(a.uid == b.uid and a.species_id == b.species_id and a.learned_skills == b.learned_skills,"Order, lead identity and learned moves match the real starter")
                check(PokemonStats.summary(a) == PokemonStats.summary(b) and a.types == b.types,"All six stats and types match actual gameplay")
            for card: BattleCardInstance in preview.cards: preview.view(card)
            preview.counts()
            preview.note()
            check(j.battle._rng.state == before_rng and JourneySnapshot.encode(j) == saved,"Repeated browsing changes no live run, draw RNG, UIDs, XP or resources")
    var fallback := StarterLoadout.new(ids([63,129,150]),catalog)
    check(fallback.fallback_names == ["캐이시","잉어킹"] and fallback.note().contains("발버둥"),"Support-only starters explicitly explain their fallback attack")
    check(fallback.member(63).learned_skills == ["move_100"] and fallback.member(129).learned_skills == ["move_150"],"Fallback attacks remain outside the four learned-move slots")
    var pair := StarterLoadout.new(ids([1,4]),catalog)
    check(pair.note().contains("빈자리 1칸") and pair.counts()["technique"] == 10,"Two-member preparation shows its real card allocation and recruitment space")
    check(StarterLoadout.new(ids([1,4,7]),catalog).note().is_empty(),"Full ordinary starters receive no artificial difficulty label")
    for values: Array in [[],[1,1],[1,4,7,150],[0],[387],[6],[1,6]]:
        var invalid := StarterLoadout.new(ids(values),catalog)
        check(not invalid.valid and invalid.members.is_empty() and invalid.cards.is_empty(),"Malformed or evolved starter previews cannot partially allocate a party")
    print("STARTER_LOADOUT: ",checks," checks, ",failures," failures; ",bases.size()," base species")
    quit(0 if failures == 0 else 1)
