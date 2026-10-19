class_name PlayerMoveTraining
extends RefCounted
## v22 self stat techniques. Uses existing stage/stat persistence and switch cleanup.
const PATH:="res://data/player_move_training_v22.json"
const STATS:Array[String]=["attack","defense","special_attack","special_defense","speed"]
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func definition(key:String) -> Dictionary:
    var v:=HeldItems.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true)
    v["player_rules"]=14;v["description"]=TacticalContent.description(v)
    return v
static func eligible(p:BattlePokemon) -> Array[String]:
    return STATS.filter(func(stat:String):return int(p.stat_stages.get(stat,0))<6)
static func prepare(p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=14
    # Also apply to called/copied techniques after their move ID has resolved.
    var overlay:Dictionary=data()["moves"].get(str(v.get("move_id",0)),{})
    if overlay.is_empty():return v
    v.erase("block");v["training_rule"]=overlay["training_rule"]
    if overlay.has("stat_changes"):
        v["stat_changes"]=overlay["stat_changes"].duplicate();v["stat_target"]="self"
    v["card_notes"]=v.get("card_notes",[]).duplicate()
    for note:String in overlay["card_notes"]:
        if note not in v["card_notes"]:v["card_notes"].append(note)
    if v["training_rule"]=="random":
        var names:Array[String]=[]
        for stat:String in eligible(p):names.append(PokemonStats.TITLES[stat])
        v["card_notes"].append("현재 강화 후보: "+(" · ".join(names) if not names.is_empty() else "없음"))
    return v
static func reason(p:BattlePokemon,v:Dictionary) -> String:
    return "강화할 능력이 없습니다. 모든 능력이 이미 최고 단계입니다." if v.get("training_rule")=="random" and eligible(p).is_empty() else ""
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    if not p.alive() or v.get("failed",false) or v.get("preparing",false):return
    match str(v.get("training_rule","")):
        "random":
            var choices:=eligible(p)
            if choices.is_empty():return
            var stat:String=choices[b._rng.randi_range(0,choices.size()-1)]
            p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+2)
            b._record("stat",p.display_name+" · "+PokemonStats.TITLES[stat]+" +2 (최대 +6)",{"target":p.uid})
        "shift":
            for pair:Array in [["attack","defense"],["special_attack","special_defense"]]:
                var a:=PlayerMoveExchange.base_stat(p,pair[0]);var d:=PlayerMoveExchange.base_stat(p,pair[1])
                PlayerMoveExchange.set_stat(b,p,pair[0],d);PlayerMoveExchange.set_stat(b,p,pair[1],a)
            b._record("stat",p.display_name+" · 공격↔방어 / 특공↔특방 능력치 교환 · 단계 유지",{"target":p.uid})
static func lines(v:Dictionary) -> Array[String]:
    var rows:=HeldItems.lines(v)
    if v.get("training_rule")=="random":rows.push_front("무작위 능력 1개 +2 · 최고 단계 제외")
    elif v.get("training_rule")=="shift":rows.push_front("공격↔방어 · 특공↔특방 능력치 교환")
    return rows.slice(0,5)
