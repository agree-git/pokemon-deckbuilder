class_name SpecialEvolution
extends RefCounted
## Remaining Gen III conditions; deterministic individual branches and camp preparation.
const ITEMS := {"blue_pokeblock":{"name":"파랑포켓블록","price":60,"stock":3}}
const BEAUTY_THRESHOLD := 170
const BEAUTY_GAIN := 60
const TRAINING_EFFORT := 32
static func beauty(pokemon: BattlePokemon) -> int:
    return maxi(0,pokemon.beauty)
static func personality(pokemon: BattlePokemon) -> int:
    return pokemon.evolution_personality if pokemon.evolution_personality >= 0 else (pokemon.uid*1664525+1013904223)&0xffffffff
static func assign_personality(pokemon: BattlePokemon, run_seed: int) -> void:
    if pokemon.species_id != 265 or pokemon.evolution_personality >= 0: return
    var rng := RandomNumberGenerator.new()
    rng.seed = run_seed ^ (pokemon.uid*104729+49979687)
    pokemon.evolution_personality = rng.randi()
static func training(pokemon: BattlePokemon) -> String:
    return pokemon.evolution_training if not pokemon.evolution_training.is_empty() else "balanced"
static func target(pokemon: BattlePokemon) -> int:
    if pokemon.species_id == 236 and pokemon.level >= 20:
        return 106 if pokemon.attack > pokemon.defense else (107 if pokemon.attack < pokemon.defense else 237)
    if pokemon.species_id == 265 and pokemon.level >= 7:
        return 266 if ((personality(pokemon)>>16)%10) < 5 else 268
    if pokemon.species_id == 349 and beauty(pokemon) >= BEAUTY_THRESHOLD: return 350
    return 0
static func eligible(species: int) -> bool:
    return species in [236,265,290,349]
static func summary(pokemon: BattlePokemon, party_size: int, balls: int, catalog: VisualCatalog) -> String:
    if pokemon.level >= 100: return "최대 레벨입니다. 조건 진화에는 다음 레벨업이 필요합니다."
    match pokemon.species_id:
        236:
            var level := maxi(20,mini(100,pokemon.level+1))
            var attack := PokemonStats.value(236,level,"attack",TRAINING_EFFORT if training(pokemon) == "attack" else 0)
            var defense := PokemonStats.value(236,level,"defense",TRAINING_EFFORT if training(pokemon) == "defense" else 0)
            var id := 106 if attack > defense else (107 if attack < defense else 237)
            return "Lv.%d 예상: 공격 %d · 방어 %d → %s\n공격·균형·방어 훈련으로 준비 · 전투 중 임시 강화는 제외" % [level,attack,defense,catalog.species(id)["name"]]
        265:
            var id := 266 if ((personality(pokemon)>>16)%10) < 5 else 268
            return "Lv.7 이상 레벨업 → %s\n개체마다 정해진 분기 · 다시 실행해도 바뀌지 않습니다." % catalog.species(id)["name"]
        290: return "Lv.20 이상 레벨업 → 아이스크\n빈자리 1칸 + 몬스터볼 1개 → 껍질몬 추가 합류\n현재 파티 %d/3 · 몬스터볼 %d개" % [party_size,balls]
        349: return "아름다움 %d/170 + 레벨업 → 밀로틱\n상인의 파랑포켓블록 1개로 아름다움 +60" % beauty(pokemon)
    return ""
