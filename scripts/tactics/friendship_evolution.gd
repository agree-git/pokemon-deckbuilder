class_name FriendshipEvolution
extends RefCounted
## Gen III friendship threshold, with gains tuned for a 69-battle expedition.
const START := 70
const THRESHOLD := 220
const MAXIMUM := 255
const VICTORY := 8
const FAINTED := -10
const LEVEL := 2
const REST := 5
const ROUTES := {772:773,172:25,173:35,174:39,42:169,175:176,298:183,113:242}
static func value(pokemon: BattlePokemon) -> int:
    # Missing fields in older saves stay absent until an actual growth action.
    return pokemon.friendship if pokemon.friendship >= 0 else START
static func change(pokemon: BattlePokemon, amount: int) -> void:
    pokemon.friendship = clampi(value(pokemon)+amount,0,MAXIMUM)
static func eligible(species: int) -> bool:
    return species == 133 or ROUTES.has(species)
static func target(pokemon: BattlePokemon, time_of_day: String) -> int:
    if value(pokemon) < THRESHOLD: return 0
    if pokemon.species_id == 133:
        return 196 if time_of_day == "day" else (197 if time_of_day == "night" else 0)
    return int(ROUTES.get(pokemon.species_id,0))
static func summary(pokemon: BattlePokemon, time_of_day: String, catalog: VisualCatalog) -> String:
    var text := "친밀도 %d / 255" % value(pokemon)
    if not eligible(pokemon.species_id): return text
    text += " · 진화 기준 220"
    if pokemon.level >= 100: return text+"\n최대 레벨입니다. 친밀도 진화에는 레벨업이 필요합니다."
    if pokemon.species_id == 133:
        text += "\n친밀도 220 이상으로 레벨업\n낮 → 에브이 · 밤 → 블래키\n원정 시간: "+("낮" if time_of_day == "day" else "밤")
    else: text += "\n친밀도 220 이상으로 레벨업 → "+str(catalog.species(ROUTES[pokemon.species_id])["name"])
    return text+"\n생존 승리 +8 · 기절 -10 · 생존 레벨업 +2 · 휴식 +5"
