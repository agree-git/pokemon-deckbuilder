class_name BattleFrame
extends RefCounted
## Plain presentation snapshots. Combat still commits once, independently of playback.
static func capture(b: TacticalBattle) -> Dictionary:
    var frame := {"powers":b.powers.duplicate(true),"turn_flags":b.turn_flags.duplicate(true),"party":b.party.map(member),"enemies":b.enemies.map(member),"active_index":b.active_index,"enemy_index":b.enemy_index,"energy":b.energy,"turn":b.turn,"turn_energy_bonus":b.turn_energy_bonus,"turn_speed_actor":b.turn_speed_actor,"turn_speed_enemy":b.turn_speed_enemy,"intent":b.intent(),"draw":b.draw_pile.size(),"discard":b.discard.size()}
    if not b.boss_context.is_empty():frame["boss_context"]=b.boss_context.duplicate(true)
    if not b.move_context.is_empty():frame["move_context"]=b.move_context.duplicate(true)
    if not b.technique_context.is_empty():frame["technique_context"]=b.technique_context.duplicate(true)
    if not b.assist_context.is_empty():frame["assist_context"]=b.assist_context.duplicate(true)
    if not b.fate_context.is_empty():frame["fate_context"]=b.fate_context.duplicate(true)
    if not b.reaction_context.is_empty():frame["reaction_context"]=b.reaction_context.duplicate(true)
    if not b.held_context.is_empty():frame["held_context"]=b.held_context.duplicate(true)
    if not b.item_context.is_empty():frame["item_context"]=b.item_context.duplicate(true)
    if not b.trap_context.is_empty():frame["trap_context"]=b.trap_context.duplicate(true)
    if not b.altitude_context.is_empty():frame["altitude_context"]=b.altitude_context.duplicate(true)
    if not b.seal_context.is_empty():frame["seal_context"]=b.seal_context.duplicate(true)
    if not b.field_context.is_empty():frame["field_context"]=b.field_context.duplicate(true)
    if b.turn_speed_inverted:frame["turn_speed_inverted"]=true
    if not b.exchange_context.is_empty():frame["exchange_context"]=b.exchange_context.duplicate(true)
    return frame
static func member(p: BattlePokemon) -> Dictionary:
    var row:=p.snapshot().merged({"name":p.display_name,"type":p.type})
    if not p.battle_stats.is_empty():row["battle_stats"]=p.battle_stats.duplicate()
    return row
static func restore(row: Dictionary) -> BattlePokemon:
    var p := BattlePokemon.new({"id":row["id"],"name":row["name"],"type":row["type"],"types":row["types"],"max_hp":row["max_hp"],"level":row["level"]},row["uid"])
    for field: String in ["hp","block","strength","statuses","stat_stages","held_item","experience","knocked_out"]: p.set(field,row[field])
    for field: String in ["friendship","beauty","evolution_personality","evolution_choice"]:
        if row.has(field): p.set(field,row[field])
    p.battle_stats=row.get("battle_stats",{}).duplicate()
    return p
