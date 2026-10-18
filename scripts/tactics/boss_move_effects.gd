class_name BossMoveEffects
extends RefCounted
## Frozen v6 representative moves. Older route definitions never enter this path.
const PATH := "res://data/boss_move_effects_v6.json"
const VERSION := 1
const STATUSES := ["burn","poison","sleep","paralysis","confusion"]
const STATUS_NAMES := {"burn":"화상","poison":"독","sleep":"수면","paralysis":"마비","confusion":"혼란"}
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty():
        _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        for key: String in _data["profiles"]:
            var authored: Dictionary = _data["profiles"][key]
            authored["species"] = int(authored["species"])
            for action: Dictionary in authored["intents"]:
                action["move_id"] = int(action["move_id"])
                action["value"] = int(action["value"])
    return _data
static func profile(boss: String,species: int) -> Dictionary:
    return data()["profiles"].get("%s:%d" % [boss,species],{})
static func build(boss: String,species: int) -> Dictionary:
    var authored := profile(boss,species)
    if authored.is_empty(): return {}
    return {"boss":boss,"boss_style":"authored","boss_moves_version":VERSION,"intents":authored["intents"].duplicate(true)}
static func valid(definition: Dictionary) -> bool:
    if not definition.get("boss_moves_version") is int or definition["boss_moves_version"] != VERSION: return false
    if not definition.get("boss") is String or not definition.get("id") is int or definition.get("boss_style") != "authored": return false
    var authored := profile(definition["boss"],definition["id"])
    if authored.is_empty() or definition.get("intents") != authored["intents"]: return false
    for action: Dictionary in definition["intents"]:
        if not action.get("move_id") is int or not action.get("value") is int: return false
    return true
static func view(id: int) -> Dictionary:
    # Callers only read this definition; battle state never belongs to the cache.
    return data()["moves"].get(str(id),{})
static func active_in(battle: TacticalBattle) -> bool:
    return battle.enemy_definitions.any(func(d: Dictionary): return d.get("boss_moves_version",0) == VERSION)
static func preview(battle: TacticalBattle,defender: BattlePokemon,source: Dictionary) -> Dictionary:
    var action := source.duplicate(true)
    action["boss_style"] = "authored"
    action["boss_moves_version"] = VERSION
    action["effects"] = []
    if battle.enemy().statuses.has("sleep"): action["asleep"] = true
    if source["kind"] == "guard":
        action["value"] = PokemonStats.scale(battle.enemy(),int(source["value"]))
        return action
    var move := view(int(source["move_id"]))
    var actor := battle.enemy()
    var affinity := battle.multiplier(move["type"],defender)
    action["name"] = move["name"]
    action["damage_class"] = move["damage_class"]
    action["value"] = 0
    action["immune"] = move.has("move_power") and affinity <= 0
    if move.has("move_power"):
        action["value"] = PokemonStats.damage(actor,defender,move,affinity,0,1.0,BattleWeather.kind(battle.powers))
    if move.has("stat_changes"):
        var recipient := actor if move["stat_target"] == "self" else defender
        for stat: String in move["stat_changes"]:
            var before := int(recipient.stat_stages.get(stat,0))
            var delta := clampi(before+int(move["stat_changes"][stat]),-6,6)-before
            if action["immune"]: delta = 0
            action["effects"].append("%s %s %+d단계" % ["자신" if recipient == actor else "출전 동료",PokemonStats.TITLES[stat],delta])
    for status: String in STATUSES:
        if move.has(status) and not action["immune"]:
            action["effects"].append("출전 동료 %s %d%s" % [STATUS_NAMES[status],int(move[status]),"턴" if status in ["sleep","paralysis"] else "회"])
    if move.has("heal"):
        action["healing"] = mini(actor.max_hp-actor.hp,PokemonStats.scale(actor,int(move["heal"])))
        action["effects"].append("자신 HP %d 회복" % action["healing"])
    if actor.statuses.has("sleep"): action["asleep"] = true
    return action
static func execute(battle: TacticalBattle,action: Dictionary) -> void:
    var actor := battle.enemy()
    var target := battle.active()
    if action["kind"] == "guard":
        actor.block = mini(TacticalBattle.MAX_BLOCK,int(action["value"]))
        battle._record("shield",actor.display_name+" 전술 방어",{"target":actor.uid,"amount":actor.block})
        return
    var move := view(int(action["move_id"]))
    var attacking := move.has("move_power")
    battle._record("enemy_action",actor.display_name+" · "+str(move["name"]),action.merged({"action":"attack" if attacking else "move"}))
    if attacking: battle._damage(target,int(action["value"]))
    # Resolve every side effect before _outcome can replace a fainted opponent.
    if target.alive() and not action["immune"]:
        var applied: Array[String] = []
        for status: String in STATUSES:
            if not move.has(status): continue
            target.statuses[status] = {"turns":int(move[status]),"source_uid":actor.uid}
            applied.append(STATUS_NAMES[status])
        if not applied.is_empty(): battle._record("status",target.display_name+" · "+"/".join(applied),{"target":target.uid})
    if move.has("stat_changes"):
        var recipient := actor if move["stat_target"] == "self" else target
        if recipient.alive() and not action["immune"]:
            for stat: String in move["stat_changes"]:
                recipient.stat_stages[stat] = clampi(int(recipient.stat_stages.get(stat,0))+int(move["stat_changes"][stat]),-6,6)
            battle._record("stat",recipient.display_name+" 능력 변화",{"target":recipient.uid})
    if actor.alive() and move.has("heal"):
        var healed := mini(actor.max_hp-actor.hp,PokemonStats.scale(actor,int(move["heal"])))
        actor.hp += healed
        if healed > 0: battle._record("heal",actor.display_name+" 회복",{"target":actor.uid,"amount":healed})
static func tooltip(action: Dictionary) -> String:
    if action.get("asleep",false): return "수면으로 다음 행동을 취소합니다."
    if action["kind"] == "guard": return "전술 방어 · 보호막 %d · 다음 적 행동 직전 해제" % int(action["value"])
    var lines: Array[String] = [str(action["name"])]
    if action["damage_class"] != "status":
        lines.append("%s · 피해 %d" % ["특수" if action["damage_class"] == "special" else "물리",int(action["value"])])
    if action.get("immune",false): lines.append("타입 무효 · 공격의 부가효과도 적용하지 않음")
    lines.append_array(action["effects"])
    lines.append("표시한 부가효과는 확정 적용 · 별도 확률 추첨 없음")
    if int(action["move_id"]) == 355: lines.append("날개쉬기는 회복만 적용 · 타입 유지")
    if int(action["move_id"]) == 92: lines.append("맹독은 기존 카드처럼 독 3회 · 누적 피해 없음")
    return "\n".join(lines)
