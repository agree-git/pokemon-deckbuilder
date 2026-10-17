class_name StarterLoadout
extends RefCounted
## Read-only Lv.5 preparation. No journey, profile, save, clock or RNG access.
var members: Array[BattlePokemon] = []
var cards: Array[BattleCardInstance] = []
var fallback_names: Array[String] = []
var valid := false

func _init(selected: Array[int], catalog: VisualCatalog) -> void:
    if selected.is_empty() or selected.size() > 3: return
    var seen := []
    for id: int in selected:
        if catalog.species(id).is_empty() or id in seen or catalog.starter_species_id(id) != id: return
        seen.append(id)
    for id: int in selected:
        var p := BattlePokemon.new(TacticalContent.member_definition(id,catalog),id)
        p.types.assign(catalog.species(id)["types"])
        TacticalGrowth.initialize(p,true)
        members.append(p)
        if not p.learned_skills.any(func(key: String): return TacticalMoves.definition(key).has("damage")):
            fallback_names.append(p.display_name)
    cards.assign(TacticalContent.starting_deck(members))
    valid = true

func member(uid: int) -> BattlePokemon:
    for p: BattlePokemon in members:
        if p.uid == uid: return p
    return null
func view(card: BattleCardInstance) -> Dictionary:
    var result := TacticalContent.definition(card)
    var owner := member(card.owner_uid)
    result["owner_name"] = owner.display_name if owner != null else ""
    result["species_id"] = owner.species_id if owner != null else 0
    result["description"] = TacticalContent.description(result)
    return result
func counts() -> Dictionary:
    var result := {"technique":0,"tool":0,"trainer":0}
    for card: BattleCardInstance in cards:
        var category: String = TacticalContent.definition(card)["category"]
        result[category] += 1
    return result
func note() -> String:
    var notes: Array[String] = []
    if members.size() < 3: notes.append("빈자리 %d칸 · 야생 포획으로 동료를 늘릴 수 있습니다." % (3-members.size()))
    if not fallback_names.is_empty(): notes.append("%s: Lv.5 공격 기술이 없어 출발 덱에 발버둥을 포함합니다." % "·".join(fallback_names))
    return "\n".join(notes)
