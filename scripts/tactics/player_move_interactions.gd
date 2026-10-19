class_name PlayerMoveInteractions
extends RefCounted
## v24. Metadata and interaction rules only; all persistent battle state is reused.
const PATH:="res://data/player_move_interactions_v24.json"
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():
        _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        for key:String in _data["flags"]:_data["flags"][key]=_data["flags"][key].map(func(n:Variant):return int(n))
        _data["breaks_guard"]=_data["breaks_guard"].map(func(n:Variant):return int(n))
    return _data
static func flag(id:int,n:int) -> bool:return n in data()["flags"].get(str(id),[])
static func move_id(v:Dictionary) -> int:return int(v.get("copied_view",{}).get("move_id",v.get("effective_move",v.get("move_id",0))))
static func bypasses_guard(id:int) -> bool:return id in data()["breaks_guard"]
static func bypasses_sub(v:Dictionary) -> bool:return flag(move_id(v),9) or flag(move_id(v),14)
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveBulk.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true)
    v["move_id"]=int(v["move_id"]);v["player_rules"]=16;v["description"]=TacticalContent.description(v)
    return v
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=16
    var id:=int(v.get("move_id",0))
    if id in [887,910]:
        v["bulk_rule"]="bypass";v["boss_blocked"]=false
        if id==910:v.erase("stat_changes");v.erase("stat_target")
        v["card_notes"]=data()["moves"][str(id)]["card_notes"].duplicate()
    if data()["changed"].has(str(id)):
        if flag(id,1):v["card_notes"].append("접촉 기술 · 접촉 방어/울퉁불퉁멧 반응")
        if flag(id,9):v["card_notes"].append("음성 기술 · 지옥찌르기로 봉인 · 대타 관통")
    return v
static func finalize(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique" or not v.has("damage"):return v
    var missed:bool=v.get("failed",false) or v.get("preparing",false) or b.multiplier(str(v.get("type","normal")),b.enemy(),int(v.get("move_id",0)))<=0
    if BossBattleRules.modern(b):
        missed=missed or PlayerInteractionHooks.boss_protected(b,v) or (not v.get("aimed",false) and BossBattleEffectsP3.airborne_miss(b,v))
    elif BossBattleRules.active_in(b):missed=missed or BossBattleEffects.protected(b,v)
    if missed and v.get("stat_target")=="self" and not v.has("charge_boost"):
        v.erase("stat_changes");v["card_notes"].append("공격 실패/보호/타입 무효 · 명중 뒤 능력 변화 없음")
    return v
static func boss_filter(b:TacticalBattle,v:Dictionary) -> Dictionary:
    var result:=PlayerInteractionHooks.aimed_filter_view(b,v) if v.get("aimed",false) else PlayerInteractionHooks.boss_filter_view(b,PlayerMoveItems.boss_proxy(b,v))
    if int(v.get("move_id",0))==614:result["move_id"]=614
    return result
static func boss_damage(b:TacticalBattle,v:Dictionary,n:int) -> int:
    return PlayerInteractionHooks.aimed_player_damage(b,v,n) if v.get("aimed",false) else PlayerInteractionHooks.boss_player_damage(b,PlayerMoveItems.boss_proxy(b,v),n)
static func boss_notice(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> String:
    return PlayerInteractionHooks.aimed_card_notice(b,v,p) if v.get("aimed",false) else PlayerInteractionHooks.boss_card_notice(b,PlayerMoveItems.boss_proxy(b,v),p)
static func boss_on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    if int(v.get("move_id",0))==614:PlayerMoveItems.boss_card(b,v,p)
    elif v.get("aimed",false):PlayerInteractionHooks.aimed_on_card(b,v,p)
    else:PlayerInteractionHooks.boss_on_card(b,v,p)
static func lines(v:Dictionary) -> Array[String]:return PlayerMoveBulk.lines(v)
