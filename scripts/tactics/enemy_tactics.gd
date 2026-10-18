class_name EnemyTactics
extends RefCounted
## Fixed, public patterns. No hidden response to the player's cards or switches.
const PROFILES := {
    "balanced":{"name":"균형형","description":"공격과 방어를 번갈아 사용한 뒤 강공격합니다.","cycle":["attack","block","charge"]},
    "striker":{"name":"속공형","description":"공격을 이어간 뒤 방어합니다. 마지막 출전 동료를 신중히 고르세요.","cycle":["attack","charge","block"]},
    "guardian":{"name":"수비형","description":"두꺼운 보호막을 세운 뒤 공격합니다. 방어하는 동안 강화나 드로우를 준비할 수 있습니다.","cycle":["block","attack","charge"]},
    "setup":{"name":"강화형","description":"위력을 높인 뒤 공격합니다. 오래 버틸수록 공격이 강해집니다.","cycle":["boost","attack","charge","block"]},
}
const TRAINER_ROLES := ["guardian","striker","balanced","guardian","striker","setup"]
static var _moves: Dictionary = {}
static func role(species: int, kind: String, slot: int, size: int) -> String:
    if kind != "wild":
        if slot == size-1 and kind in ["veteran","gym","elite","champion"]: return "setup"
        return TRAINER_ROLES[slot%TRAINER_ROLES.size()]
    var stats := PokemonStats.base(species)
    if maxi(stats["defense"],stats["special_defense"]) >= 120 and stats["speed"] <= 60: return "guardian"
    if stats["speed"] >= 90: return "striker"
    return "balanced"
static func _score(id: int, species: int, types: Array) -> float:
    var move := TacticalMoves.definition(TacticalMoves.key_for(id))
    var stats := PokemonStats.base(species)
    var offense := int(stats["special_attack" if move.get("damage_class") == "special" else "attack"])
    return int(move.get("move_power",40))*offense*(1.5 if move["type"] in types else 1.0)
static func moves(species: int, level: int, types: Array,modern := false) -> Dictionary:
    var key := "%d:%d:%s" % [species,level,str(modern)]
    if _moves.has(key): return _moves[key]
    var known: Array[int] = []
    for entry: Dictionary in TacticalGrowth.species_data(species,modern)["learnset"]:
        var id := int(entry["move"])
        if int(entry["level"]) <= level and TacticalMoves.definition(TacticalMoves.key_for(id)).has("damage") and id not in known: known.append(id)
    if known.is_empty(): known.append(165)
    known.sort_custom(func(a: int,b: int):
        var first := _score(a,species,types)
        var second := _score(b,species,types)
        return first > second if first != second else a < b)
    var normal := known[0]
    for id: int in known:
        if int(TacticalMoves.definition(TacticalMoves.key_for(id)).get("move_power",40)) <= 80:
            normal = id
            break
    var coverage := normal
    var primary_type: String = TacticalMoves.definition(TacticalMoves.key_for(normal))["type"]
    for id: int in known:
        var move := TacticalMoves.definition(TacticalMoves.key_for(id))
        if move["type"] != primary_type and int(move.get("move_power",40)) <= 80 and _score(id,species,types) >= _score(normal,species,types)*0.65:
            coverage = id
            break
    _moves[key] = {"normal":normal,"heavy":known[0],"coverage":coverage}
    return _moves[key]
static func build(species: int, level: int, types: Array, kind: String, slot: int, size: int,modern := false) -> Dictionary:
    var tactic := role(species,kind,slot,size)
    var selected := moves(species,level,types,modern)
    var pattern: Array = []
    for action: String in PROFILES[tactic]["cycle"]:
        if action == "block": pattern.append({"kind":"block","value":10 if tactic == "guardian" else 6,"move_id":115})
        elif action == "boost": pattern.append({"kind":"boost","value":2,"move_id":74})
        else:
            var id: int = selected["heavy"] if action == "charge" else (selected["coverage"] if tactic == "striker" else selected["normal"])
            var move := TacticalMoves.definition(TacticalMoves.key_for(id))
            pattern.append({"kind":action,"value":40,"move_id":id,"type":move["type"]})
    return {"tactic":tactic,"intents":pattern}
static func title(key: String) -> String:
    return str(PROFILES.get(key,{"name":"기본형"})["name"])
static func role_title(definition: Dictionary) -> String:
    return BossTactics.title(definition["boss_style"]) if not str(definition.get("boss_style","")).is_empty() else title(definition.get("tactic",""))
static func pattern_text(definition: Dictionary) -> String:
    var actions: Array[String] = []
    for action: Dictionary in definition["intents"]:
        if definition.get("boss_moves_version") in [2,3,4] and action["kind"] in ["prepare","recharge","wait"]:
            actions.append({"prepare":"충전","recharge":"재충전","wait":"휴식"}[action["kind"]])
            continue
        if action["kind"] in ["move","guard"]:
            actions.append("전술 방어" if action["kind"] == "guard" else str(BossEffects.view(int(action["move_id"]),int(definition.get("boss_moves_version",1)))["name"]))
            continue
        actions.append({"attack":"공격","charge":"강공격","block":"방어","boost":"강화","barrage":"연타","fortify":"방벽","recover":"회복","status":"상태 부여"}[action["kind"]])
    return " → ".join(actions)
static func description(definition: Dictionary) -> String:
    if definition.has("boss_moves_version"):
        var authored := BossEffects.profile(definition)
        return "%s\n%s\n순서: %s" % [BossTactics.heading(definition),authored["plan"],pattern_text(definition)]
    if definition.has("boss"):
        var style: Dictionary = BossTactics.STYLES[definition["boss_style"]]
        return "%s\n%s · %s\n순서: %s" % [BossTactics.heading(definition),style["name"],style["description"],pattern_text(definition)]
    var key: String = definition.get("tactic","")
    var profile: Dictionary = PROFILES.get(key,{"name":"기본형","description":"예고된 순서대로 행동합니다."})
    return "%s · %s\n순서: %s" % [profile["name"],profile["description"],pattern_text(definition)]
static func intent_text(action: Dictionary) -> String:
    if action.has("boss_moves_version"): return BossEffects.tooltip(action)
    if action.get("asleep",false): return "수면으로 다음 행동을 취소합니다."
    if action["kind"] == "status": return "%s %d회 · 현재 출전 동료에게 부여 · 대기 중에도 지속" % [{"burn":"화상","poison":"독","seed":"씨뿌리기"}[action["status"]],action["value"]]
    if action["kind"] == "fortify": return "%s +%d단계 · 보호막 %d · 단계는 해당 적에게만 유지" % [PokemonStats.TITLES[action["stat"]],action["stat_delta"],action["value"]]
    if action["kind"] == "recover": return "HP %d 회복 · 현재 잃은 HP까지만 회복" % action["value"]
    if action["kind"] == "barrage":
        var move := TacticalMoves.definition(TacticalMoves.key_for(int(action["move_id"])))
        return "%s · %s · %d × %d회 = 총 피해 %d · 출전 동료가 기절하면 남은 타격 중단" % [move["name"],"특수" if action.get("damage_class") == "special" else "물리",action["per_hit"],action["hits"],action["value"]]
    if action["kind"] == "boost": return "위력 보정 +%d%% · 이번 전투 동안 유지" % (int(action["value"])*10)
    if action["kind"] == "block": return "보호막 %d 획득 · 다음 적 행동 직전 해제" % int(action["value"])
    var move := TacticalMoves.definition(TacticalMoves.key_for(int(action["move_id"])))
    return "%s · %s · 피해 %d%s" % [move["name"],"특수" if action.get("damage_class") == "special" else "물리",int(action["value"])," · 강공격" if action["kind"] == "charge" else ""]
