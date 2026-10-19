class_name PlayerMoveSupport
extends RefCounted
## v25: conditional support and powder, using existing persistent state only.
const PATH:="res://data/player_move_support_v25.json"
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():
        _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        _data["powder"]=_data["powder"].map(func(n:Variant):return int(n))
        for entry:Dictionary in _data["moves"].values():
            for stat:String in entry.get("support_changes",{}):entry["support_changes"][stat]=int(entry["support_changes"][stat])
    return _data
static func overlay(id:int) -> Dictionary:return data()["moves"].get(str(id),{})
static func powder(id:int) -> bool:return id in data()["powder"]
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveInteractions.definition(key)
    if v.is_empty():return v
    var d:=overlay(int(v["move_id"]))
    v.merge(d.duplicate(true),true)
    if d.has("support_changes"):v.erase("stat_changes");v.erase("stat_target")
    v["player_rules"]=17;v["description"]=TacticalContent.description(v)
    return v
static func airborne(b:TacticalBattle,p:BattlePokemon) -> bool:
    if b.boss_context.get("airborne",{}).get(p.uid,false):return true
    var charge:Dictionary=PlayerMoveRules.read(b)["charges"].get(p.uid,{})
    return not charge.is_empty() and PlayerMoveCards.data()["moves"].get(str(charge.get("move",0)),{}).get("charge","") in ["air","burrow","dive","vanish"]
static func recipients(b:TacticalBattle,p:BattlePokemon,tag:String) -> Array[int]:
    var result:Array[int]=[]
    var members:Array=[p,b.enemy()] if tag in ["till","flower"] else b.party
    for member:BattlePokemon in members:
        if not member.alive():continue
        var types:=PlayerMoveCards.effective_types(b,member)
        if tag in ["till","flower"]:
            if "grass" not in types or airborne(b,member):continue
            if tag=="till" and not PlayerMoveAltitude.grounded(b,member):continue
        elif tag in ["flux","gear"]:
            if "electric" not in types and "steel" not in types:continue
        elif member==p:continue
        result.append(member.uid)
    return result
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=17
    var id:=int(v.get("move_id",0));var d:=overlay(id);var tag:String=d.get("support_rule","")
    if not d.is_empty():
        for note:String in d["card_notes"]:
            if note not in v["card_notes"]:v["card_notes"].append(note)
    if tag=="growth":
        var n:=2 if BattleWeather.kind(b.powers)=="sun" else 1
        v["stat_changes"]={"attack":n,"special_attack":n};v["stat_target"]="self"
    elif tag=="venom" and not b.enemy().statuses.has("poison"):
        v.erase("stat_changes");v["support_refusal"]="베놈트랩은 독 상태인 상대에게만 사용할 수 있습니다."
    elif d.has("support_changes"):
        v.erase("stat_changes");v.erase("stat_target");v.erase("boss_contact_guard");v["boss_blocked"]=false
        v["support_changes"]=d["support_changes"].duplicate();v["support_targets"]=recipients(b,p,tag)
        if v["support_targets"].is_empty():v["support_refusal"]="이 기술을 적용할 수 있는 살아 있는 대상이 없습니다."
        else:
            var names:Array[String]=[]
            for uid:int in v["support_targets"]:names.append(PlayerMoveExchange.member(b,uid).display_name)
            v["card_notes"].append("적용 대상: "+" · ".join(names))
    if powder(id) and "grass" in PlayerMoveCards.effective_types(b,b.enemy()):
        for field:String in ["burn","poison","sleep","paralysis","confusion","stat_changes"]:v.erase(field)
        v["exchange_blocked"]=true;v["reaction_blocked"]=true;v["target_effect_blocked"]=true
        v["support_refusal"]="풀 타입은 가루·포자 기술의 영향을 받지 않습니다."
    return v
static func reason(v:Dictionary) -> String:return str(v.get("support_refusal",""))
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    if not v.has("support_targets") or v.get("failed",false) or v.get("preparing",false):return
    for uid:int in v["support_targets"]:
        var member:=PlayerMoveExchange.member(b,uid)
        if member==null or not member.alive():continue
        var before:=member.stat_stages.duplicate()
        for stat:String in v["support_changes"]:member.stat_stages[stat]=clampi(int(member.stat_stages.get(stat,0))+int(v["support_changes"][stat]),-6,6)
        # Bulk.after_card doubles the enemy's delta; allied recipients need it here.
        if uid>0:PlayerMoveBulk.simple_delta(b,member,before)
        if member.stat_stages!=before:b._record("stat",member.display_name+" · "+str(v["name"])+" 능력 변화",{"target":uid})
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> Dictionary:
    if a.get("asleep",false) or a.get("player_sealed",false) or a.get("failed_move",false) or a.has("bulk_cancel") or a["kind"] in ["prepare","recharge","wait"]:return a
    if powder(PlayerMoveInteractions.move_id(a)) and "grass" in PlayerMoveCards.effective_types(b,p):
        a=a.duplicate(true);a["support_cancel"]="풀 타입 · 가루/포자 기술 무효";a["failed_move"]=true;a["immune"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        a["effects"]=a.get("effects",[])+[a["support_cancel"]]
    return a
static func lines(v:Dictionary) -> Array[String]:return PlayerMoveInteractions.lines(v)
