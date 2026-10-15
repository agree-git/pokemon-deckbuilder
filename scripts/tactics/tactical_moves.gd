class_name TacticalMoves
extends RefCounted
## Original identities/learn levels with effects scaled to the tactical battle.
static var _definitions: Dictionary = {}
static func key_for(id: int) -> String:
    return "move_%d" % id
static func visual(id: int) -> Dictionary:
    return TacticalGrowth.data()["moves"].get(str(id),{})
static func definition(key: String) -> Dictionary:
    if BattleContent.CARDS.has(key): return BattleContent.CARDS[key]
    if _definitions.has(key): return _definitions[key]
    var raw := visual(key.trim_prefix("move_").to_int())
    if raw.is_empty(): return {}
    var view := {"name":raw["name"],"move_id":int(raw["id"]),"type":raw["type"],"cost":1}
    if int(raw["id"]) == 150:
        view["cost"] = 0
        view["description"] = "아무 일도 일어나지 않습니다."
        _definitions[key] = view
        return view
    var effects: Array[String] = []
    if int(raw["category"]) != 1:
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
            effects.append({"paralysis":"마비 · 공격 약화 3턴","sleep":"행동 1회 취소","burn":"화상 3회","poison":"독 3회","confusion":"혼란 3회"}[ailment])
    if int(raw["healing"]) > 0 or int(raw["drain"]) > 0:
        view["heal"] = 8 if int(raw["healing"]) > 0 else 3
        effects.append("회복 %d" % view["heal"])
    for stat: Dictionary in raw["stats"]:
        if int(stat["change"]) > 0:
            if int(stat["stat_id"]) in [2,4]:
                view["strength"] = 2
                effects.append("공격 +2")
            else:
                view["block"] = 8
                effects.append("보호막 8")
        elif int(stat["change"]) < 0:
            if int(stat["stat_id"]) in [3,5]:
                view["expose"] = 2
                effects.append("적 방어 약화 · 피해 +2")
            else:
                view["weaken"] = 2
                effects.append("적 공격 -2")
    if effects.is_empty():
        view["block"] = 5
        effects.append("전술 보조 · 보호막 5")
    view["description"] = " · ".join(effects)
    _definitions[key] = view
    return view
