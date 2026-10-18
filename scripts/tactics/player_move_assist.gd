class_name PlayerMoveAssist
extends RefCounted
## v18: identification, aerial aim and same-turn help. No accuracy RNG or new turn order.
const PATH:="res://data/player_move_assist_v18.json"
const DEFAULT:Dictionary={"ghost":{},"dark":{},"aim":{},"help":0,"after":0}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.assist_context if not b.assist_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.assist_context.is_empty():b.assist_context=DEFAULT.duplicate(true)
    return b.assist_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveItems.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=10;v["description"]=TacticalContent.description(v)
    return v
static func affinity(b:TacticalBattle,attack:String,p:BattlePokemon,base:float) -> float:
    var reveal:bool=(attack in ["normal","fighting"] and read(b)["ghost"].get(p.uid,false)) or (attack=="psychic" and read(b)["dark"].get(p.uid,false))
    if not reveal:return base
    var types:=PlayerMoveCards.effective_types(b,p)
    if b.boss_context.get("spent_electric",{}).get(p.uid,false):types.erase("electric")
    types.erase("dark" if attack=="psychic" else "ghost")
    return TypeMatchup.multiplier(attack,types)
static func aimed(b:TacticalBattle,p:BattlePokemon) -> bool:
    var mark:Dictionary=read(b)["aim"].get(p.uid,{})
    return mark.get("target",0)==b.enemy().uid and int(mark.get("left",0))>0
static func blocked(b:TacticalBattle,v:Dictionary) -> bool:
    if not BossBattleRules.active_in(b):return false
    if PlayerMoveCards.flag(int(v["move_id"]),4):return PlayerMoveExchange.blocked(b,v)
    var proxy:=v.duplicate(true);proxy["pulse_status"]=true
    var sub:bool=BossBattleRules.read(b)["substitutes"].get(b.enemy().uid,0)>0 and not PlayerMoveCards.flag(int(v["move_id"]),14)
    return sub or (BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy))
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=10
    if v.get("assist_rule","") in ["ghost","dark","aim"]:
        v["assist_blocked"]=blocked(b,v)
        if v["assist_blocked"]:v["card_notes"].append("보호/대타/공중 회피에 식별·조준 차단")
    if v.has("damage") and not v.get("preparing",false):
        if aimed(b,p):
            v["aimed"]=true;v["card_notes"].append("조준 · 공중 회피 무시 · 보호/대타/타입 상성 유지")
            if int(v["move_id"])==615 and b.boss_context.get("airborne",{}).get(b.enemy().uid,false):v["failed"]=false
        if int(read(b)["help"]) not in [0,p.uid]:v["help_boost"]=true;v["card_notes"].append("다른 동료의 도우미 · 피해1.5배")
    if int(read(b)["after"]) not in [0,p.uid] and int(v["cost"])>0:
        v["assist_discount"]=1;v["cost"]=int(v["cost"])-1;v["card_notes"].append("다른 동료의 당신먼저 · 비용-1")
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("assist_rule","") in ["help","after"] and not b.party.any(func(ally:BattlePokemon):return ally!=p and ally.alive()):return "도움을 받을 살아 있는 다른 동료가 필요합니다."
    return ""
static func damage(v:Dictionary,n:int) -> int:return maxi(1,floori(n*1.5)) if n>0 and v.get("help_boost",false) else n
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false):return
    if v.get("aimed",false):write(b)["aim"].erase(p.uid)
    if v.get("help_boost",false):write(b)["help"]=0
    if v.get("assist_discount",0)>0:write(b)["after"]=0
    var tag:String=v.get("assist_rule","")
    if tag.is_empty() or v.get("failed",false):return
    var c:=write(b)
    match tag:
        "ghost","dark":
            if target.alive() and not v.get("assist_blocked",false) and not v.get("target_effect_blocked",false):c[tag][target.uid]=true
        "aim":
            if target.alive() and not v.get("assist_blocked",false) and not v.get("target_effect_blocked",false):c["aim"][p.uid]={"target":target.uid,"left":2}
        "help","after":c[tag]=p.uid
    b._record("field",str(v["name"])+" · 식별/동료 보조 규칙 반영")
static func on_switch(b:TacticalBattle,old:int) -> void:
    if b.assist_context.is_empty():return
    for key:String in ["ghost","dark","aim"]:b.assist_context[key].erase(old)
    for uid:int in read(b)["aim"].keys():
        if read(b)["aim"][uid]["target"]==old:b.assist_context["aim"].erase(uid)
static func after_enemy(b:TacticalBattle) -> void:
    if b.assist_context.is_empty():return
    var c:=b.assist_context;c["help"]=0;c["after"]=0
    for uid:int in c["aim"].keys():
        c["aim"][uid]["left"]-=1
        if c["aim"][uid]["left"]<=0:c["aim"].erase(uid)
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    var ids:Array=b["party"]+b["enemies"]
    for key:String in ["ghost","dark","aim"]:
        if not c.get(key) is Dictionary:return false
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids:return false
            var value:Variant=c[key][uid]
            if key=="aim":
                if not value is Dictionary or value.size()!=2 or not value.get("target") is int or value["target"] not in ids or value["target"]*uid>=0 or not value.get("left") is int or value["left"]<1 or value["left"]>2:return false
            elif not value is bool or not value:return false
    for key:String in ["help","after"]:
        if not c.get(key) is int or (c[key]!=0 and c[key] not in b["party"]):return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveItems.lines(v)
    if v.has("assist_rule"):rows.push_front({"ghost":"고스트의 노말/격투 무효 해제","dark":"악의 에스퍼 무효 해제","aim":"다음 공격 공중 회피 무시","help":"다른 동료 다음 공격1.5배","after":"다른 동료 다음 기술 비용-1","quash":"상대 예고 한 칸 밀기"}[v["assist_rule"]])
    return rows.slice(0,5)
