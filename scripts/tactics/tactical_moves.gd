class_name TacticalMoves
extends RefCounted
## Original identities/learn levels with effects scaled to the tactical battle.
static var _definitions: Dictionary = {}
static func key_for(id: int) -> String:
    return "move_%d" % id
static func visual(id: int) -> Dictionary:
    return TacticalGrowth.data()["moves"].get(str(id),{})
static func definition(key: String) -> Dictionary:
    if BattleContent.CARDS.has(key):
        var result: Dictionary = BattleContent.CARDS[key].duplicate(true)
        var raw := visual(int(result["move_id"]))
        if result.has("damage"):
            result["move_power"] = int(raw["power"]) if int(raw.get("power",0)) > 0 else 40
            result["damage_class"] = "special" if int(raw.get("category",2)) == 3 else "physical"
        return result
    if _definitions.has(key): return _definitions[key]
    var raw := visual(key.trim_prefix("move_").to_int())
    if raw.is_empty(): return {}
    var view := {"name":raw["name"],"move_id":int(raw["id"]),"type":raw["type"],"cost":1,"damage_class":{1:"status",2:"physical",3:"special"}[int(raw["category"])]}
    if int(raw["id"]) == 150:
        view["cost"] = 0
        view["description"] = "아무 일도 일어나지 않습니다."
        _definitions[key] = view
        return view
    if BattleWeather.MOVES.has(int(raw["id"])):
        view["weather"] = BattleWeather.MOVES[int(raw["id"])]
        view["description"] = BattleWeather.tooltip(view["weather"])
        _definitions[key] = view
        return view
    var effects: Array[String] = []
    if int(raw["category"]) != 1:
        view["move_power"] = int(raw["power"]) if int(raw["power"]) > 0 else 40
        view["damage"] = clampi(roundi(float(raw["power"])/8.0),4,20)
        if int(raw["power"]) >= 90: view["cost"] = 2
        effects.append("피해 %d" % view["damage"])
    if int(raw["id"]) == 73:
        view["seed"] = 3
        effects.append("씨뿌리기 3회")
    else:
        var ailment: String = {1:"paralysis",2:"sleep",3:"sleep",4:"burn",5:"poison",6:"confusion"}.get(int(raw["ailment"]),"")
        if not ailment.is_empty():
            view[ailment] = 1 if ailment == "sleep" else 3
            effects.append({"paralysis":"마비 · 스피드 절반 3턴","sleep":"행동 1회 취소","burn":"화상 3회","poison":"독 3회","confusion":"혼란 3회"}[ailment])
    if int(raw["healing"]) > 0 or int(raw["drain"]) > 0:
        view["heal"] = 8 if int(raw["healing"]) > 0 else 3
        effects.append("회복 %d" % view["heal"])
    var changes := {}
    for stat: Dictionary in raw["stats"]:
        var id := int(stat["stat_id"])
        if PokemonStats.STAT_IDS.has(id):
            var name: String = PokemonStats.STAT_IDS[id]
            changes[name] = int(stat["change"])
            effects.append("%s %+d단계" % [PokemonStats.TITLES[name],int(stat["change"])])
        else:
            view["block"] = 8
            effects.append("보호막 8")
    if not changes.is_empty():
        view["stat_changes"] = changes
        # Damaging moves with positive secondary stages raise the user (e.g. Rapid Spin).
        var raises_user: bool = int(raw["category"]) != 1 and raw["stats"].any(func(change: Dictionary): return int(change["change"]) > 0)
        view["stat_target"] = "self" if raises_user or int(raw["target"]) in [4,7,13] or int(raw["id"]) in [276,315,354] else "enemy"
    if effects.is_empty():
        view["block"] = 5
        effects.append("전술 보조 · 보호막 5")
    view["description"] = " · ".join(effects)
    _definitions[key] = view
    return view
