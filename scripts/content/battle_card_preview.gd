class_name BattleCardPreview
extends RefCounted
## Resolve one card on detached combatants/cards/RNG. Never expose drawn identities.
const CONTEXT_FIELDS := ["boss_context","move_context","technique_context","exchange_context","field_context","seal_context","altitude_context","trap_context","item_context","assist_context","fate_context","reaction_context","held_context","bulk_context","completion_context"]
static func copy_member(original: BattlePokemon) -> BattlePokemon:
    var result := BattlePokemon.new({"id":original.species_id,"name":original.display_name,"type":original.type,"types":original.types,"max_hp":original.max_hp,"level":original.level},original.uid)
    for field: String in JourneySnapshot.POKEMON_FIELDS+["content_version","battle_stats","friendship","beauty","evolution_personality","evolution_choice","evolution_prepared"]:
        var value: Variant = original.get(field)
        result.set(field,value.duplicate(true) if value is Dictionary or value is Array else value)
    return result

static func copy_battle(original: TacticalBattle) -> TacticalBattle:
    var result := TacticalBattle.new()
    for field: String in JourneySnapshot.BATTLE_FIELDS+CONTEXT_FIELDS+["player_moves_version","turn_speed_inverted"]:
        var value: Variant = original.get(field)
        result.set(field,value.duplicate(true) if value is Dictionary or value is Array else value)
    result.statistics = original.statistics.duplicate(true)
    result.party.assign(original.party.map(copy_member))
    result.enemies.assign(original.enemies.map(copy_member))
    var old_piles := [original.hand,original.draw_pile,original.discard,original.exhausted]
    var new_piles := [result.hand,result.draw_pile,result.discard,result.exhausted]
    for i in old_piles.size():
        new_piles[i].clear()
        for card: BattleCardInstance in old_piles[i]:
            var copied := BattleCardInstance.new(card.uid,card.key,card.owner_uid)
            copied.upgraded = card.upgraded
            copied.injury_owner_uid = card.injury_owner_uid
            new_piles[i].append(copied)
    result._rng.seed = original.seed_value
    result._rng.state = original._rng.state
    return result

static func analyze(battle: TacticalBattle,uid: int,capture_check: Callable = Callable()) -> Dictionary:
    var reason := battle.card_reason(uid)
    if not reason.is_empty(): return {"reason":reason}
    var card := battle._hand(uid)
    var actor := battle.member(card.owner_uid) if card.owner_uid != 0 else battle.active()
    var actor_before := BattleFrame.member(actor)
    var target_before := BattleFrame.member(battle.enemy())
    var sandbox := copy_battle(battle)
    var error := sandbox.play_card(uid)
    if not error.is_empty(): return {"reason":error}
    # Keep the old target even if resolving the card sends out the next enemy.
    var target := sandbox.enemies[battle.enemy_index]
    var allies: Array[Dictionary] = []
    for member: BattlePokemon in battle.party:
        if member.uid != actor.uid:
            allies.append({"before":BattleFrame.member(member),"after":BattleFrame.member(sandbox.member(member.uid))})
    var capture_reason := ""
    if capture_check.is_valid():
        capture_reason = "쓰러뜨림 · 포획 불가" if not target.alive() else str(capture_check.call(sandbox))
    return {"reason":"","name":battle.card_view(card)["name"],"actor_before":actor_before,
        "actor_after":BattleFrame.member(sandbox.active()),"target_before":target_before,
        "target_after":BattleFrame.member(target),"switched":actor.uid != battle.active().uid,
        "energy_before":battle.energy,"energy_after":sandbox.energy,
        "weather_after":BattleWeather.kind(sandbox.powers) if battle.card_view(card).has("weather") else "",
        "won":sandbox.phase == TacticalBattle.WON,"enemy_changed":sandbox.enemy_index != battle.enemy_index,"intent":sandbox.intent(),
        "capture_shown":capture_check.is_valid(),"capture_reason":capture_reason,"allies":allies}
