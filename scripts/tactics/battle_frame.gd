class_name BattleFrame
extends RefCounted
## Plain presentation snapshots. Combat still commits once, independently of playback.
static func capture(b: TacticalBattle) -> Dictionary:
    return {"powers":b.powers.duplicate(true),"turn_flags":b.turn_flags.duplicate(true),"party":b.party.map(member),"enemies":b.enemies.map(member),"active_index":b.active_index,"enemy_index":b.enemy_index,"energy":b.energy,"turn":b.turn,"turn_energy_bonus":b.turn_energy_bonus,"turn_speed_actor":b.turn_speed_actor,"turn_speed_enemy":b.turn_speed_enemy,"intent":b.intent(),"draw":b.draw_pile.size(),"discard":b.discard.size()}
static func member(p: BattlePokemon) -> Dictionary:
    return p.snapshot().merged({"name":p.display_name,"type":p.type})
static func restore(row: Dictionary) -> BattlePokemon:
    var p := BattlePokemon.new({"id":row["id"],"name":row["name"],"type":row["type"],"types":row["types"],"max_hp":row["max_hp"],"level":row["level"]},row["uid"])
    for field: String in ["hp","block","strength","statuses","stat_stages","held_item","experience","knocked_out"]: p.set(field,row[field])
    for field: String in ["friendship","beauty","evolution_personality","evolution_choice"]:
        if row.has(field): p.set(field,row[field])
    return p
