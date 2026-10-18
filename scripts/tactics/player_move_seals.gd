class_name PlayerMoveSeals
extends RefCounted
## Route v14: item effects, critical protection and temporary voluntary switch lock.
const PATH:="res://data/player_move_seals_v14.json"
const DEFAULT:Dictionary={"magic":0,"fairy":0,"ally":0,"foe":0}
const TITLES:Dictionary={"magic":"매직룸","chant":"주술","fairy":"페어리록"}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.seal_context if not b.seal_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.seal_context.is_empty():b.seal_context=DEFAULT.duplicate()
    return b.seal_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveFields.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=6;v["description"]=TacticalContent.description(v)
    return v
static func locked(b:TacticalBattle,p:BattlePokemon) -> bool:
    return read(b)["fairy"]>0 and "ghost" not in PlayerMoveCards.effective_types(b,p)
static func prepare(b:TacticalBattle,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=6 # Includes calls expanded through the frozen v13 definitions.
    if read(b)["foe"]>0 and (v.get("critical",false) or v.get("high_crit",false)):
        v["critical"]=false;v["high_crit"]=false
        v["card_notes"].append("상대 진영의 주술이 급소 보너스와 단계 무시를 차단")
    return v
static func after_card(b:TacticalBattle,v:Dictionary) -> void:
    if v.get("preparing",false) or v.get("failed",false):return
    var tag:String=v.get("seal_rule","")
    if tag.is_empty() and v.get("field_rule")!="court":return
    var c:=write(b)
    match tag:
        "magic":c["magic"]=0 if c["magic"]>0 else 5
        "chant":c["ally"]=5
        "fairy":c["fairy"]=2
    if v.get("field_rule")=="court":
        var own:int=c["ally"];c["ally"]=c["foe"];c["foe"]=own
    if not tag.is_empty():b._record("field",str(TITLES[tag])+" · "+str(v["card_notes"][-1]))
static func after_enemy(b:TacticalBattle) -> void:
    if b.seal_context.is_empty():return
    for key:String in DEFAULT:b.seal_context[key]=maxi(0,int(b.seal_context[key])-1)
static func enemy_math(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if read(b)["ally"]==0:return source
    var id:=int(source.get("effective_move",source["move_id"]))
    var m:=PlayerMoveFields.enemy_move(source,id).duplicate(true)
    if m.get("unique")!="critical" and not m.get("critical",false) and not m.get("high_crit",false):return source
    if not source.has("per_hit") or source.has("fixed_damage") or source.get("asleep",false) or source.get("failed_move",false) or source.get("failed_charge",false) or source.get("immune",false) or source.get("player_sealed",false) or source["kind"] in ["prepare","recharge","wait","guard"]:return source
    if not m.has("move_power"):return source
    var a:=source.duplicate(true);var actor:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(b.enemy()));var target:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(p))
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["type"]=a.get("type",m["type"]);m["damage_class"]=a.get("damage_class",m["damage_class"])
    m=PlayerMoveFields.attack_view(b,actor,target,m)
    if a.has("charge_boost"):actor.stat_stages["special_attack"]=int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
    if id==263:actor.statuses.erase("burn")
    if m.get("ignore_defense",false):target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    if b.boss_context.get("spent_electric",{}).get(actor.uid,false):actor.types.erase("electric")
    var n:=PokemonStats.damage(actor,target,m,b.multiplier(str(m["type"]),target),0,1.0,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
    var scale:=PlayerMoveFields.factor(b,actor,target,m)
    a["per_hit"]=maxi(1,floori(n*scale)) if n>0 else 0;a["value"]=int(a["per_hit"])*int(a.get("hits",1));a["critical_blocked"]=true
    var effects:Array=[]
    for line:String in a.get("effects",[]):
        if "확정 급소" not in line and "대상 기절 시 남은 타격 중단" not in line:effects.append(line)
    effects.append("주술 · 급소 배율/단계 무시 차단 · %d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)])
    a["effects"]=effects
    return a
static func valid_context(c:Variant) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.get(key) is int or c[key]<0 or c[key]>(2 if key=="fairy" else 5):return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveFields.lines(v)
    if v.has("seal_rule"):rows.push_front({"magic":"5턴 소지품 효과 정지 · 재사용 해제","chant":"진영5턴 급소 방어","fairy":"다음 턴까지 자발 교대 금지"}[v["seal_rule"]])
    return rows.slice(0,5)
