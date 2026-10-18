class_name PlayerMoveFate
extends RefCounted
## v19: sleeping residual damage, independent perish counters and one replacement wish.
const PATH:="res://data/player_move_fate_v19.json"
const DEFAULT:Dictionary={"nightmare":{},"perish":{},"wish":0}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.fate_context if not b.fate_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.fate_context.is_empty():b.fate_context=DEFAULT.duplicate(true)
    return b.fate_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveAssist.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=11;v["description"]=TacticalContent.description(v)
    return v
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=11
    if v.get("fate_rule")=="nightmare":
        v["fate_blocked"]=PlayerMoveAssist.blocked(b,v)
        if v["fate_blocked"]:v["card_notes"].append("상대 보호/대타/공중 회피에 악몽 차단")
        v["preview_nightmare"]=maxi(1,b.enemy().max_hp/4)
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var tag:String=v.get("fate_rule","")
    if tag=="nightmare" and not b.enemy().statuses.has("sleep"):return "악몽은 잠든 상대에게 사용합니다."
    if tag in ["wish","lunar"] and not b.party.any(func(ally:BattlePokemon):return ally!=p and ally.alive()):return "회복을 받을 살아 있는 다른 동료가 필요합니다."
    return ""
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var tag:String=v.get("fate_rule","")
    if tag.is_empty() or v.get("preparing",false) or v.get("failed",false):return
    match tag:
        "nightmare":
            if target.alive() and target.statuses.has("sleep") and not v.get("fate_blocked",false) and not v.get("target_effect_blocked",false):
                write(b)["nightmare"][target.uid]=true
                b._record("field",target.display_name+" · 악몽",{"target":target.uid})
        "perish":
            for pokemon:BattlePokemon in [p,target]:
                if pokemon.alive() and not read(b)["perish"].has(pokemon.uid):write(b)["perish"][pokemon.uid]=3
            b._record("field","멸망의노래 · 각자 교대로 해제 · 3상대 행동 뒤 기절")
        "wish","lunar":
            write(b)["wish"]=int(v["move_id"])
            b._record("field",p.display_name+" · 다음 동료에게 회복 인계")
            b._damage(p,p.hp,true)
static func tick(b:TacticalBattle,p:BattlePokemon) -> void:
    if not read(b)["nightmare"].has(p.uid):return
    if not p.alive() or not p.statuses.has("sleep"):
        write(b)["nightmare"].erase(p.uid);return
    var wakes:bool=int(p.statuses["sleep"]["turns"])<=1
    b._record("field",p.display_name+" · 악몽 지속 피해",{"target":p.uid})
    b._damage(p,maxi(1,p.max_hp/4),true)
    if wakes:write(b)["nightmare"].erase(p.uid)
static func after_enemy(b:TacticalBattle) -> void:
    if b.fate_context.is_empty():return
    var due:Array[BattlePokemon]=[]
    for uid:int in read(b)["perish"].keys():
        var p:=PlayerMoveExchange.member(b,uid)
        if p==null or not p.alive() or p not in [b.active(),b.enemy()]:
            write(b)["perish"].erase(uid);continue
        write(b)["perish"][uid]-=1
        if read(b)["perish"][uid]<=0:due.append(p)
    # Resolve every due member before the normal outcome/forced replacement logic.
    for p:BattlePokemon in due:
        write(b)["perish"].erase(p.uid)
        b._record("field",p.display_name+" · 멸망의노래 카운트0",{"target":p.uid})
        b._damage(p,p.hp,true)
static func on_knockout(b:TacticalBattle,uid:int) -> void:
    if b.fate_context.is_empty():return
    for key:String in ["nightmare","perish"]:b.fate_context[key].erase(uid)
static func on_switch(b:TacticalBattle,old:int) -> void:
    on_knockout(b,old)
    var id:int=int(read(b)["wish"])
    var p:=b.active()
    if id==0 or not p.alive():return
    write(b)["wish"]=0
    p.statuses.clear()
    var blocked:bool=PlayerMoveTactics.read(b)["heal_block"].get(p.uid,0)>=b.turn
    if not blocked:PlayerMoveTactics.heal(b,p,p.max_hp-p.hp)
    b._record("field",p.display_name+" · 치유 인계"+(" · 회복봉인으로 HP 회복 차단" if blocked else ""),{"target":p.uid,"move_id":id})
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=3 or not c.get("nightmare") is Dictionary or not c.get("perish") is Dictionary or not c.get("wish") is int or c["wish"] not in [0,361,461]:return false
    var ids:Array=b["party"]+b["enemies"]
    for key:String in ["nightmare","perish"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids:return false
            var value:Variant=c[key][uid]
            if key=="nightmare":
                if not value is bool or not value:return false
            elif not value is int or value<1 or value>3:return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveAssist.lines(v)
    if v.has("fate_rule"):rows.push_front({"nightmare":"수면 중 매 턴 최대HP¼ 피해","perish":"양쪽 3행동 뒤 기절 · 교대로 해제","wish":"자신 기절 · 다음 동료 HP/상태 회복","lunar":"자신 기절 · 다음 동료 HP/상태 회복"}[v["fate_rule"]])
    return rows.slice(0,5)
