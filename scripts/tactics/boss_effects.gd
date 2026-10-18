class_name BossEffects
extends RefCounted
## Version dispatch keeps old saved runs and their future battles unchanged.
static func build(boss: String,species: int,version: int) -> Dictionary:
    return BossMoveEffectsP1.build(boss,species) if version == 2 else BossMoveEffects.build(boss,species)
static func profile(d: Dictionary) -> Dictionary:
    return BossMoveEffectsP1.profile(d["boss"],int(d["id"])) if d.get("boss_moves_version") == 2 else BossMoveEffects.profile(d["boss"],int(d["id"]))
static func valid(d: Dictionary) -> bool:
    return BossMoveEffectsP1.valid(d) if d.get("boss_moves_version") == 2 else BossMoveEffects.valid(d)
static func view(id: int,version: int) -> Dictionary:
    return BossMoveEffectsP1.view(id) if version == 2 else BossMoveEffects.view(id)
static func active_in(b: TacticalBattle) -> bool:
    return b.enemy_definitions.any(func(d: Dictionary): return d.get("boss_moves_version",0) in [1,2])
static func preview(b: TacticalBattle,target: BattlePokemon,source: Dictionary) -> Dictionary:
    return BossMoveEffectsP1.preview(b,target,source) if b.enemy_definitions[b.enemy_index].get("boss_moves_version") == 2 else BossMoveEffects.preview(b,target,source)
static func tooltip(a: Dictionary) -> String:
    return BossMoveEffectsP1.tooltip(a) if a.get("boss_moves_version") == 2 else BossMoveEffects.tooltip(a)
