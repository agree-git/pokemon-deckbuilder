class_name NationalEvolution
extends RefCounted
## Expanded evolution conditions; external world actions have an explicit camp adaptation.
static var _rules: Dictionary = {}
static func rules_for(id: int) -> Array:
    if _rules.is_empty():
        for rule: Dictionary in PokedexExpansion.data()["evolutions"]:
            var source := int(rule["from"])
            if not _rules.has(source): _rules[source] = []
            _rules[source].append(rule)
    return _rules.get(id,[])
static func has_branch(source: int,target: int) -> bool:
    return rules_for(source).any(func(rule: Dictionary): return int(rule["to"]) == target)
static func gender(pokemon: BattlePokemon) -> int:
    var rate := int(PokedexExpansion.species(pokemon.species_id).get("gender_rate",-1))
    if rate < 0: return 0
    return 1 if posmod(pokemon.uid*1664525+1013904223,8) < rate else 2
static func reason(pokemon: BattlePokemon,rule: Dictionary,time: String,prepared := true) -> String:
    if pokemon.level < int(rule["level"]): return "Lv.%d 이상이 필요합니다." % int(rule["level"])
    var conditions: Dictionary = rule["conditions"]
    if conditions.has("gender_id") and gender(pokemon) != int(conditions["gender_id"]): return "이 진화는 %s 동료의 분기입니다." % ("암컷" if int(conditions["gender_id"]) == 1 else "수컷")
    if conditions.has("time_of_day"):
        var required := str(conditions["time_of_day"])
        if required in ["day","night"] and time != required: return "야영지에서 %s을 준비하세요." % ("낮" if required == "day" else "밤")
    if FriendshipEvolution.value(pokemon) < int(conditions.get("minimum_happiness",0)): return "친밀도 %d 이상이 필요합니다." % int(conditions["minimum_happiness"])
    if conditions.has("known_move_id") and TacticalMoves.key_for(int(conditions["known_move_id"])) not in pokemon.learned_skills: return "%s 기술을 배워야 합니다." % TacticalMoves.visual(int(conditions["known_move_id"]))["name"]
    if conditions.has("used_move_id") and TacticalMoves.key_for(int(conditions["used_move_id"])) not in pokemon.learned_skills: return "%s 기술을 먼저 배워야 합니다." % TacticalMoves.visual(int(conditions["used_move_id"]))["name"]
    if conditions.has("known_move_type_id"):
        var type: String = PokedexExpansion.data().get("type_ids",{}).get(str(int(conditions["known_move_type_id"])),"fairy")
        if not pokemon.learned_skills.any(func(key: String): return TacticalMoves.definition(key).get("type","") == type): return "%s 타입 기술을 배워야 합니다." % VisualCatalog.new().type_name(type)
    if conditions.has("minimum_beauty") and SpecialEvolution.beauty(pokemon) < int(conditions["minimum_beauty"]): return "아름다움 조건을 준비하세요."
    if prepared and rule["prepare"] and pokemon.evolution_prepared != int(rule["to"]): return "야영지의 진화 연구로 준비하세요."
    return ""
static func level_target(pokemon: BattlePokemon,time: String) -> int:
    if pokemon.species_id in [236,265,349]: return 0 # Preserve authored legacy branches.
    var candidates: Array = rules_for(pokemon.species_id).duplicate()
    candidates.sort_custom(func(a: Dictionary,b: Dictionary):
        if int(a["to"]) == int(b["to"]): return false
        if int(a["to"]) == pokemon.evolution_prepared: return true
        if int(b["to"]) == pokemon.evolution_prepared: return false
        return a["conditions"].has("known_move_type_id") and not b["conditions"].has("known_move_type_id"))
    for rule: Dictionary in candidates:
        if rule["method"] != "level" or rule["trigger"] == "shed": continue
        if pokemon.evolution_prepared > 0 and int(rule["to"]) != pokemon.evolution_prepared: continue
        if reason(pokemon,rule,time).is_empty(): return int(rule["to"])
    return 0
static func item_rule(key: String,pokemon: BattlePokemon) -> Dictionary:
    var candidates: Array = rules_for(pokemon.species_id).filter(func(rule: Dictionary): return rule["item"] == key)
    if pokemon.evolution_prepared > 0:
        for rule: Dictionary in candidates:
            if int(rule["to"]) == pokemon.evolution_prepared: return rule
        return {}
    for rule: Dictionary in candidates:
        if not rule["prepare"]: return rule
    return {}
static func condition_text(rule: Dictionary) -> String:
    var parts: Array[String] = []
    if int(rule["level"]) > 1: parts.append("Lv.%d" % int(rule["level"]))
    if not str(rule["item"]).is_empty(): parts.append(str(EvolutionItems.all_items()[rule["item"]]["name"]))
    var conditions: Dictionary = rule["conditions"]
    if conditions.has("gender_id"): parts.append("암컷" if int(conditions["gender_id"]) == 1 else "수컷")
    if conditions.has("time_of_day"): parts.append({"day":"낮","night":"밤","dusk":"황혼"}.get(str(conditions["time_of_day"]),str(conditions["time_of_day"])))
    if conditions.has("minimum_happiness"): parts.append("친밀도 %d" % int(conditions["minimum_happiness"]))
    if conditions.has("known_move_id"): parts.append(str(TacticalMoves.visual(int(conditions["known_move_id"]))["name"])+" 습득")
    if conditions.has("known_move_type_id"): parts.append("지정 타입 기술 습득")
    if conditions.has("used_move_id"): parts.append("원작: %s %d회" % [TacticalMoves.visual(int(conditions["used_move_id"]))["name"],int(conditions.get("minimum_move_count",1))])
    if conditions.has("minimum_steps"): parts.append("원작: %d걸음" % int(conditions["minimum_steps"]))
    if conditions.has("minimum_damage_taken"): parts.append("원작: 누적 피해 %d" % int(conditions["minimum_damage_taken"]))
    if conditions.has("region_id"): parts.append("원작: 지정 지방에서 진화")
    if conditions.has("location_id") or conditions.has("near_special_rock"): parts.append("원작: 특정 장소")
    if conditions.has("needs_overworld_rain"): parts.append("원작: 비가 오는 장소")
    if conditions.has("needs_multiplayer"): parts.append("원작: 통신 플레이")
    if conditions.has("turn_upside_down"): parts.append("원작: 기기를 뒤집기")
    var special: String = {"three-critical-hits":"원작: 한 전투에서 급소 3회","three-defeated-bisharp":"원작: 대장의징표 절각참 3마리 처치","gimmighoul-coins":"원작: 모으령의코인 999개","spin":"원작: 사탕을 지니고 회전","agile-style-move":"원작: 속공으로 지정 기술 사용","strong-style-move":"원작: 강공으로 지정 기술 사용"}.get(str(rule["trigger"]),"")
    if not special.is_empty(): parts.append(special)
    if conditions.has("nature_bitmask"): parts.append("원작: 성향에 따른 분기")
    if conditions.has("percentage_chance"): parts.append("원작: 개체 분기 %d%%" % int(conditions["percentage_chance"]))
    if rule["prepare"]: parts.append("외부 조건은 야영 행동 1회로 준비")
    if rule["method"] == "level": parts.append("다음 레벨업 때 진화")
    return " · ".join(parts)
static func teachable_moves(pokemon: BattlePokemon) -> Array[int]:
    var result: Array[int] = []
    var row := TacticalGrowth.species_data(pokemon.species_id,true)
    for id: int in row.get("nonlevel_moves",[]):
        if id not in result: result.append(id)
    for entry: Dictionary in row["learnset"]:
        var id := int(entry["move"])
        if int(entry["level"]) <= pokemon.level and id not in result: result.append(id)
    result.sort()
    return result
