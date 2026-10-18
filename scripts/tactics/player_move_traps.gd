class_name PlayerMoveTraps
extends RefCounted
## v16: persistent switch links, Octolock and No Retreat. Read paths stay pure.
const PATH:="res://data/player_move_traps_v16.json"
const DEFAULT:Dictionary={"links":[],"stand":{}}
const MOVES:Array[int]=[169,212,335,615,746,753]
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.trap_context if not b.trap_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.trap_context.is_empty():b.trap_context=DEFAULT.duplicate(true)
    return b.trap_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveAltitude.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    if v.has("stat_changes"):
        for stat:String in v["stat_changes"]:v["stat_changes"][stat]=int(v["stat_changes"][stat])
    v["player_rules"]=8;v["description"]=TacticalContent.description(v)
    return v
static func present(b:TacticalBattle,uid:int) -> bool:
    var p:=PlayerMoveExchange.member(b,uid)
    return p!=null and p.alive() and p==(b.active() if uid>0 else b.enemy())
static func valid_link(b:TacticalBattle,link:Dictionary) -> bool:return present(b,int(link["source"])) and present(b,int(link["target"]))
static func blocked(b:TacticalBattle,p:BattlePokemon) -> bool:
    if not p.alive() or "ghost" in PlayerMoveCards.effective_types(b,p):return false
    if read(b)["stand"].get(p.uid,false):return true
    return read(b)["links"].any(func(link:Dictionary):return link["target"]==p.uid and valid_link(b,link))
static func add(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,id:int) -> void:
    var link:Dictionary={"source":p.uid,"target":target.uid,"move":id}
    if link not in read(b)["links"]:write(b)["links"].append(link)
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=8
    var id:=int(v["move_id"])
    if id==615 and b.boss_context.get("airborne",{}).get(b.enemy().uid,false) and not PlayerMoveAltitude.gravity(b):
        v["failed"]=true;v["card_notes"].append("사우전드웨이브는 공중 회피를 뚫거나 착지시키지 않음")
    if not v.has("trap_rule") or v["trap_rule"]=="stand":return v
    var stopped:=false
    if BossBattleRules.active_in(b):
        if PlayerMoveCards.flag(id,4):stopped=PlayerMoveExchange.blocked(b,v)
        else:
            var proxy:=v.duplicate(true);proxy["pulse_status"]=true
            stopped=BossBattleRules.read(b)["substitutes"].get(b.enemy().uid,0)>0 or (BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy))
    v["trap_blocked"]=stopped
    if stopped:v["card_notes"].append("상대 방어/대타/공중 회피가 새 구속을 차단")
    if "ghost" in PlayerMoveCards.effective_types(b,b.enemy()):v["card_notes"].append("고스트 상대는 교대 가능 · 문어굳히기 능력 감소는 유지")
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("trap_rule")=="stand" and read(b)["stand"].get(p.uid,false):return "배수의진은 교대 전까지 한 번만 사용할 수 있습니다."
    if (p!=b.active() and blocked(b,b.active())) or (v.get("extension","") in ["pivot","baton","shed"] and blocked(b,p)):return "구속 중에는 수동/기술 카드 교대를 할 수 없습니다."
    return ""
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if not v.has("trap_rule") or v.get("preparing",false) or v.get("failed",false):return
    var id:=int(v["move_id"]);var tag:String=v["trap_rule"]
    if tag=="stand":write(b)["stand"][p.uid]=true
    elif p.alive() and target.alive() and not v.get("trap_blocked",false) and not v.get("boss_blocked",false) and not v.get("target_effect_blocked",false) and (not v.has("damage") or b.multiplier(str(v["type"]),target)>0):
        if tag!="jaw" or (not blocked(b,p) and not blocked(b,target)):
            add(b,p,target,id)
            if tag=="jaw":add(b,target,p,id)
    b._record("field",str(v["name"])+" · 구속 규칙 반영")
static func on_switch(b:TacticalBattle,old:int) -> void:
    if b.trap_context.is_empty():return
    b.trap_context["stand"].erase(old)
    b.trap_context["links"]=b.trap_context["links"].filter(func(link:Dictionary):return link["source"]!=old and link["target"]!=old)
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,had_sub:bool) -> void:
    var id:=int(a.get("effective_move",a.get("move_id",0)))
    if id==746:
        var native:Dictionary=b.boss_context.get("traps",{}).get(p.uid,{})
        if native.get("source",0)==foe.uid and not native.get("dot",true):b.boss_context["traps"].erase(p.uid)
        if foe.alive() and p.alive() and not had_sub and not a.get("immune",false) and not a.get("player_sealed",false) and not a.get("player_guarded",false) and not a.get("player_airborne",false) and not a.get("asleep",false) and not a.get("failed_move",false) and not blocked(b,p) and not blocked(b,foe):
            add(b,foe,p,746);add(b,p,foe,746)
    if b.trap_context.is_empty():return
    b.trap_context["links"]=read(b)["links"].filter(func(link:Dictionary):return valid_link(b,link))
    for link:Dictionary in read(b)["links"]:
        if int(link["move"])!=753:continue
        var target:=PlayerMoveExchange.member(b,int(link["target"]))
        if PlayerMoveFields.read(b)[PlayerMoveFields.side(target)]["mist"]>0:continue
        for stat:String in ["defense","special_defense"]:target.stat_stages[stat]=maxi(-6,int(target.stat_stages.get(stat,0))-1)
        b._record("stat",target.display_name+" · 문어굳히기 방어/특방-1",{"target":target.uid})
static func air_charge(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> Dictionary:
    # Frozen v10 confused Waves(615) with Arrows(614); preserve only this charge.
    if int(a.get("effective_move",a.get("move_id",0)))!=615 or PlayerMoveAltitude.gravity(b):return {}
    var c:Dictionary=PlayerMoveRules.read(b)["charges"].get(p.uid,{})
    return c.duplicate() if PlayerMoveCards.data()["moves"].get(str(c.get("move",0)),{}).get("charge")=="air" else {}
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var c:=air_charge(b,p,original)
    if c.is_empty() or b.turn>=c["ready"]:return original
    var a:=original.duplicate(true);a["player_airborne"]=true;a["immune"]=true;a["value"]=0
    if a.has("per_hit"):a["per_hit"]=0
    a["effects"]=a.get("effects",[])+["사우전드웨이브 · 공중 회피 중인 상대에게 빗나감 · 착지 없음"]
    return a
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=2 or not c.get("links") is Array or c["links"].size()>64 or not c.get("stand") is Dictionary:return false
    var ids:Array=b["party"]+b["enemies"];var seen:Array=[]
    for link:Variant in c["links"]:
        if not link is Dictionary or link.size()!=3 or not link.get("source") is int or not link.get("target") is int or not link.get("move") is int:return false
        if link["source"] not in ids or link["target"] not in ids or link["source"]*link["target"]>=0 or link["move"] not in MOVES or link in seen:return false
        seen.append(link)
    for uid:Variant in c["stand"]:
        if not uid is int or uid not in ids or not c["stand"][uid] is bool or not c["stand"][uid]:return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveAltitude.lines(v)
    if v.has("trap_rule"):rows.push_front({"lock":"시전자 이탈까지 상대 교대 봉쇄","octo":"구속 · 매 행동 뒤 방어/특방-1","jaw":"명중 후 양쪽 교대 봉쇄","stand":"전 능력+1 · 자신 교대 봉쇄"}[v["trap_rule"]])
    return rows.slice(0,5)
