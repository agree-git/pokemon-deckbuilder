class_name BossBattleRules
extends RefCounted
## Dispatch shared hooks without changing shipped v8 rules.
static func modern(b: TacticalBattle) -> bool:
    return b.enemy_definitions.any(func(d:Dictionary):return d.get("boss_moves_version")==4)
static func active_in(b: TacticalBattle) -> bool:
    return BossBattleEffectsP3.active_in(b) if modern(b) else BossBattleEffects.active_in(b)
static func read(b: TacticalBattle) -> Dictionary:
    return BossBattleEffectsP3.read(b) if modern(b) else BossBattleEffects.read(b)
static func write(b: TacticalBattle) -> Dictionary:
    return BossBattleEffectsP3.write(b) if modern(b) else BossBattleEffects.write(b)
static func player_damage(b: TacticalBattle,v: Dictionary,amount: int) -> int:
    if modern(b) and b.player_moves_version>=18:return PlayerMoveAdaptive.boss_damage(b,v,amount)
    if modern(b) and b.player_moves_version>=16:return PlayerMoveInteractions.boss_damage(b,v,amount)
    if modern(b) and b.player_moves_version>=10 and v.get("aimed",false):return PlayerMoveAssistMath.boss_player_damage(b,v,amount)
    v=PlayerMoveItems.boss_proxy(b,v)
    return BossBattleEffectsP3.player_damage(b,v,amount) if modern(b) else BossBattleEffects.player_damage(b,v,amount)
static func card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    if modern(b) and b.player_moves_version>=18:return PlayerMoveAdaptive.boss_notice(b,v,actor)
    if modern(b) and b.player_moves_version>=16:return PlayerMoveInteractions.boss_notice(b,v,actor)
    if modern(b) and b.player_moves_version>=10 and v.get("aimed",false):return PlayerMoveAssistMath.boss_card_notice(b,v,actor)
    v=PlayerMoveItems.boss_proxy(b,v)
    return BossBattleEffectsP3.card_notice(b,v,actor) if modern(b) else BossBattleEffects.card_notice(b,v,actor)
static func trapped(b: TacticalBattle) -> bool:
    return BossBattleEffectsP3.trapped(b) if modern(b) else BossBattleEffects.trapped(b)
static func entry_damage(b: TacticalBattle,p: BattlePokemon) -> int:
    return BossBattleEffectsP3.entry_damage(b,p) if modern(b) else BossBattleEffects.entry_damage(b,p)
static func on_card(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> void:
    if modern(b) and b.player_moves_version>=18:
        PlayerMoveAdaptive.boss_on_card(b,v,actor);return
    if modern(b) and b.player_moves_version>=16:
        PlayerMoveInteractions.boss_on_card(b,v,actor);return
    if modern(b) and b.player_moves_version>=9 and int(v.get("move_id",0))==614:PlayerMoveItems.boss_card(b,v,actor)
    elif modern(b) and b.player_moves_version>=10 and v.get("aimed",false):PlayerMoveAssistMath.boss_on_card(b,v,actor)
    elif modern(b):BossBattleEffectsP3.on_card(b,v,actor)
    else:BossBattleEffects.on_card(b,v,actor)
static func filter_view(b: TacticalBattle,v: Dictionary) -> Dictionary:
    if modern(b) and b.player_moves_version>=18:return PlayerMoveAdaptive.boss_filter(b,v)
    if modern(b) and b.player_moves_version>=16:return PlayerMoveInteractions.boss_filter(b,v)
    if modern(b) and b.player_moves_version>=10 and v.get("aimed",false):return PlayerMoveAssistMath.boss_filter_view(b,v)
    var result:=BossBattleEffectsP3.filter_view(b,PlayerMoveItems.boss_proxy(b,v)) if modern(b) else BossBattleEffects.filter_view(b,v)
    if b.player_moves_version>=9 and int(v.get("move_id",0))==614:result["move_id"]=614
    return result
static func after_card(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> void:
    if modern(b) and b.player_moves_version>=18:PlayerAdaptiveMath.boss_after_card(b,v,actor)
    elif modern(b) and b.player_moves_version>=16:PlayerInteractionHooks.boss_after_card(b,v,actor)
    elif modern(b):BossBattleEffectsP3.after_card(b,v,actor)
    else:BossBattleEffects.after_card(b,v,actor)
static func on_switch(b: TacticalBattle,uid: int) -> void:
    if modern(b):BossBattleEffectsP3.on_switch(b,uid)
    else:BossBattleEffects.on_switch(b,uid)
static func begin_enemy(b: TacticalBattle) -> void:
    if modern(b):BossBattleEffectsP3.begin_enemy(b)
    else:BossBattleEffects.begin_enemy(b)
static func end_enemy(b: TacticalBattle,actor: BattlePokemon) -> void:
    if modern(b):BossBattleEffectsP3.end_enemy(b,actor)
    else:BossBattleEffects.end_enemy(b,actor)
static func tick_trap(b: TacticalBattle,p: BattlePokemon) -> void:
    if modern(b):BossBattleEffectsP3.tick_trap(b,p)
    else:BossBattleEffects.tick_trap(b,p)
static func absorb(b: TacticalBattle,p: BattlePokemon,amount: int,piercing: bool,bypass: bool) -> int:
    return BossBattleEffectsP3.absorb(b,p,amount,piercing,bypass) if modern(b) else BossBattleEffects.absorb(b,p,amount,piercing,bypass)
static func track(b: TacticalBattle,p: BattlePokemon,lost: int,kind: String) -> void:
    if modern(b):BossBattleEffectsP3.track(b,p,lost,kind)
    else:BossBattleEffects.track(b,p,lost,kind)
static func affinity(b: TacticalBattle,attack: String,p: BattlePokemon) -> float:
    return BossBattleEffectsP3.affinity(b,attack,p) if modern(b) else BossBattleEffects.affinity(b,attack,p)
static func flag(id: int,value: int) -> bool:
    return BossBattleEffectsP3.flag(id,value) if value==7 else BossBattleEffects.flag(id,value)
static func valid_context(c: Variant,b: Dictionary) -> bool:
    var use_new:bool=b["enemy_definitions"].any(func(d:Variant):return d is Dictionary and d.get("boss_moves_version")==4)
    return BossBattleEffectsP3.valid_context(c,b) if use_new else BossBattleEffects.valid_context(c,b)
