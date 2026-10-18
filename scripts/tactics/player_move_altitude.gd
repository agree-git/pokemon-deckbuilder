class_name PlayerMoveAltitude
extends RefCounted
## Route v15: derived grounding; never changes permanent types, items or speed.
const PATH:="res://data/player_move_altitude_v15.json"
const DEFAULT:Dictionary={"gravity":0,"rise":{},"lift":{},"down":{}}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.altitude_context if not b.altitude_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.altitude_context.is_empty():b.altitude_context=DEFAULT.duplicate(true)
    return b.altitude_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveSeals.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=7;v["description"]=TacticalContent.description(v)
    return v
static func gravity(b:TacticalBattle) -> bool:return read(b)["gravity"]>0 or b.boss_context.get("gravity",0)>0
static func forced(b:TacticalBattle,p:BattlePokemon) -> bool:
    return gravity(b) or read(b)["down"].get(p.uid,false) or PlayerMoveRules.read(b)["roots"].get(p.uid,false) or b.boss_context.get("roots",{}).get(p.uid,false)
static func floating(b:TacticalBattle,p:BattlePokemon) -> bool:
    return not forced(b,p) and (read(b)["rise"].get(p.uid,0)>0 or read(b)["lift"].get(p.uid,0)>0)
static func grounded(b:TacticalBattle,p:BattlePokemon,entering:=false) -> bool:
    if forced(b,p):return true
    if not entering and floating(b,p):return false
    return PlayerMoveFields.grounded(b,p,entering)
static func affinity(b:TacticalBattle,attack:String,p:BattlePokemon,base:float) -> float:
    if attack!="ground":return base
    if floating(b,p):return 0.0
    if not forced(b,p):return base
    var types:=PlayerMoveCards.effective_types(b,p);types.erase("flying")
    if b.boss_context.get("spent_electric",{}).get(p.uid,false):types.erase("electric")
    return TypeMatchup.multiplier(attack,types)
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=7
    if v.get("air_rule")=="lift":
        v["altitude_blocked"]=PlayerMoveExchange.blocked(b,v)
        if v["altitude_blocked"]:v["card_notes"].append("텔레키네시스가 보호/대타/공중 회피에 막힘")
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if gravity(b) and PlayerMoveCards.flag(int(v.get("move_id",0)),10):return "중력 중에는 공중/점프 기술을 사용할 수 없습니다."
    if v.get("air_rule")=="rise" and forced(b,p):return "강제 접지 중에는 전자부유를 사용할 수 없습니다."
    if v.get("air_rule")=="lift" and forced(b,b.enemy()):return "강제 접지 상대에게는 텔레키네시스를 사용할 수 없습니다."
    return PlayerMoveAirFields.reason(b,p,v)
static func cancel_air(b:TacticalBattle,p:BattlePokemon) -> void:
    var charge:Dictionary=PlayerMoveRules.read(b)["charges"].get(p.uid,{})
    if PlayerMoveCards.data()["moves"].get(str(charge.get("move",0)),{}).get("charge")=="air":
        b.retained.erase(int(charge["card"]));PlayerMoveRules.write(b)["charges"].erase(p.uid)
    if b.boss_context.has("airborne"):b.boss_context["airborne"].erase(p.uid)
    for i in b.enemies.size():
        if b.enemies[i]!=p:continue
        var state:Dictionary=b.enemy_states[i].get("effects_v4",{})
        if state.get("charge",0)==340:state["charge"]=0;state["air_cancel"]=true
static func land(b:TacticalBattle,p:BattlePokemon,persistent:=false) -> void:
    var c:=write(b);c["rise"].erase(p.uid);c["lift"].erase(p.uid)
    if persistent:c["down"][p.uid]=true
    cancel_air(b,p)
static func synchronize(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> void:
    if gravity(b):
        for actor:BattlePokemon in b.party+b.enemies:land(b,actor)
    elif int(a.get("effective_move",a.get("move_id",0)))==479 and not a.get("immune",false) and not a.get("player_guarded",false) and not a.get("player_sealed",false) and not a.get("asleep",false) and not a.get("failed_move",false) and a["kind"]!="prepare":land(b,p,true)
    for actor:BattlePokemon in b.party+b.enemies:
        if forced(b,actor) and floating_unchecked(b,actor):land(b,actor)
static func floating_unchecked(b:TacticalBattle,p:BattlePokemon) -> bool:return read(b)["rise"].has(p.uid) or read(b)["lift"].has(p.uid)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false) or v.get("failed",false):return
    match str(v.get("air_rule","")):
        "gravity":
            write(b)["gravity"]=5
            for actor:BattlePokemon in b.party+b.enemies:land(b,actor)
        "rise":write(b)["rise"][p.uid]=5
        "lift":
            if not v.get("altitude_blocked",false) and not v.get("boss_blocked",false):write(b)["lift"][target.uid]=3
    if int(v.get("move_id",0))==479 and not v.get("boss_blocked",false) and int(v.get("preview_damage",0))>0:land(b,target,true)
    if forced(b,p) and floating_unchecked(b,p):land(b,p)
    if v.has("air_rule"):b._record("field",str(v["name"])+(" · 대상 효과 차단" if v.get("altitude_blocked",false) else " · 공중/접지 규칙 적용"))
static func enemy_preview(b:TacticalBattle,source:Dictionary) -> Dictionary:
    if not gravity(b) or not PlayerMoveCards.flag(int(source.get("effective_move",source["move_id"])),10):return source
    var a:=source.duplicate(true);a["player_sealed"]=true;a["value"]=0
    if a.has("per_hit"):a["per_hit"]=0
    a["effects"]=a.get("effects",[])+["중력 · 공중/점프 기술 금지 · 충돌 반동 없음"]
    return a
static func after_enemy(b:TacticalBattle) -> void:
    if b.altitude_context.is_empty():return
    var c:=b.altitude_context;c["gravity"]=maxi(0,int(c["gravity"])-1)
    for group:String in ["rise","lift"]:
        for uid:int in c[group].keys():
            c[group][uid]-=1
            if c[group][uid]<=0:c[group].erase(uid)
static func on_switch(b:TacticalBattle,old:int) -> void:
    var p:=b.member(old)
    if p!=null:cancel_air(b,p)
    if b.altitude_context.is_empty():return
    for group:String in ["rise","lift","down"]:b.altitude_context[group].erase(old)
static func enter_enemy(b:TacticalBattle) -> void:
    # Entry grounding includes global Gravity; lifting an old foe never lifts its successor.
    var p:=b.enemy();var h:Dictionary=PlayerMoveTactics.read(b)["hazards"];var ground:=grounded(b,p,true)
    var n:=maxi(1,floori(p.max_hp*TypeMatchup.multiplier("rock",p.types)/8.0)) if h["rocks"]>0 else 0
    if ground and h["spikes"]>0:n+=maxi(1,p.max_hp/{1:8,2:6,3:4}[int(h["spikes"])])
    if n>0:b._damage(p,n,true)
    if not p.alive():return
    if ground and h["toxic"]>0:
        if "poison" in p.types:PlayerMoveTactics.write(b)["hazards"]["toxic"]=0
        elif "steel" not in p.types and not PlayerMoveAirFields.protected_status(b,p,"poison") and PlayerMoveExchange.main_status(p).is_empty():p.statuses["poison"]={"turns":3 if h["toxic"]==1 else 5,"source_uid":b.active().uid}
    if ground and h["web"]>0:p.stat_stages["speed"]=maxi(-6,int(p.stat_stages.get("speed",0))-1)
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size() or not c.get("gravity") is int or c["gravity"]<0 or c["gravity"]>5:return false
    for group:String in ["rise","lift","down"]:
        if not c.get(group) is Dictionary:return false
        for uid:Variant in c[group]:
            if not uid is int or uid not in b["party"]+b["enemies"]:return false
            var value:Variant=c[group][uid]
            if group=="down":
                if not value is bool or not value:return false
            elif not value is int or value<1 or value>(5 if group=="rise" else 3):return false
            if c["gravity"]>0 and group!="down":return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveSeals.lines(v)
    if v.has("air_rule"):rows.push_front({"gravity":"5턴 강제 접지 · 공중 기술 금지","rise":"자신5턴 부유 · 땅 공격 무효","lift":"상대3턴 부유 · 땅 공격 무효"}[v["air_rule"]])
    return rows.slice(0,5)
