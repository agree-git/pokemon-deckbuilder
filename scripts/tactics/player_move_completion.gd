class_name PlayerMoveCompletion
extends RefCounted
## v27: remaining card traits, explicit adaptations and strict optional state.
const PATH:="res://data/player_move_completion_v27.json"
const DEFAULT:Dictionary={"charged":{},"curled":{},"small":{},"weight_loss":{},"entered":{},"entry_used":{}}
const MAJOR:Array[String]=["burn","poison","sleep","paralysis"]
const STOMP:Array[int]=[23,34,407,484,535,537,560]
const BREAK:Array[int]=[364,467,566,593,621]
const PIVOT:Array[int]=[100,226,369,502,521,812,880,881]
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.completion_context if not b.completion_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.completion_context.is_empty():b.completion_context=DEFAULT.duplicate(true)
    return b.completion_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveAdaptive.definition(key)
    if v.is_empty():return v
    var d:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not d.is_empty():v=d.duplicate(true)
    v["move_id"]=int(v["move_id"]);v["player_rules"]=19;v["description"]=TacticalContent.description(v)
    for note:String in data()["policy_notes"].get(str(v["move_id"]),[]):
        if note not in v["card_notes"]:v["card_notes"].append(note)
    return v
static func seed(b:TacticalBattle,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    # Direct cards already use v27; copies/transforms can still expand frozen v15 definitions.
    var id:=int(v.get("move_id",0));var d:Dictionary=data()["moves"].get(str(id),{})
    for field:String in data().get("deltas",{}).get(str(id),{}):
        if field not in ["cost","upgrade","card_notes"]:v[field]=data()["deltas"][str(id)][field].duplicate(true) if data()["deltas"][str(id)][field] is Dictionary or data()["deltas"][str(id)][field] is Array else data()["deltas"][str(id)][field]
    for field:String in data().get("removed",{}).get(str(id),[]):v.erase(field)
    if not d.is_empty():
        for note:String in d["card_notes"]:
            if note not in v["card_notes"]:v["card_notes"].append(note)
        var card:BattleCardInstance=b._hand(int(v.get("uid",0)))
        if card!=null and card.upgraded and d.get("upgrade",{}).has("power_upgrade"):v["power_upgrade"]=int(d["upgrade"]["power_upgrade"])
    return v
static func weight(b:TacticalBattle,p:BattlePokemon,reduced:=true) -> int:
    var species:=PlayerMoveBulk.visual_species(PlayerMoveBulk.read(b),p)
    return maxi(1,int(PlayerMoveCards.data()["weights"].get(str(species),1))-(int(read(b)["weight_loss"].get(p.uid,0)) if reduced else 0))
static func weight_power(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,id:int,reduced:=true) -> int:
    var other:=weight(b,target,reduced)
    if id in [67,447]:return 20 if other<100 else 40 if other<250 else 60 if other<500 else 80 if other<1000 else 100 if other<2000 else 120
    var own:=weight(b,p,reduced)
    return 120 if own>=other*5 else 100 if own>=other*4 else 80 if own>=other*3 else 60 if own>=other*2 else 40
static func healing_blocked(b:TacticalBattle,p:BattlePokemon) -> bool:return PlayerMoveTactics.read(b)["heal_block"].get(p.uid,0)>=b.turn
static func ally(b:TacticalBattle,p:BattlePokemon) -> BattlePokemon:
    var selected:BattlePokemon=null
    for member:BattlePokemon in b.party:
        if member==p or not member.alive() or member.hp>=member.max_hp or healing_blocked(b,member):continue
        if selected==null or member.hp*selected.max_hp<selected.hp*member.max_hp:selected=member
    return selected
static func ready_attack(a:Dictionary) -> bool:
    return a.get("damage_class","status")!="status" and a["kind"] not in ["guard","prepare","recharge","wait","block","boost","fortify","recover","status"] and not a.get("asleep",false) and not a.get("player_sealed",false) and not a.get("failed_move",false) and not a.get("failed_charge",false) and not a.has("bulk_cancel")
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=19
    var id:=int(v["move_id"]);var target:=b.enemy();var tag:String=v.get("completion_rule","");var c:=read(b)
    if tag=="entry":
        if p==b.active() and (c["entered"].get(p.uid,1)!=b.turn or c["entry_used"].get(p.uid,false)):v["completion_refusal"]="입장한 첫 턴의 첫 자기 기술로만 사용할 수 있습니다."
    elif tag in ["sucker","upper","pursuit"]:
        var action:=b.intent();var mid:=PlayerMoveInteractions.move_id(action)
        if tag in ["sucker","upper"]:
            var ok:=ready_attack(action) and (tag!="upper" or int(data()["priority"].get(str(mid),0))>0)
            if not ok:v["completion_refusal"]="상대가 "+("우선도 있는 " if tag=="upper" else "")+"직접 공격을 예고해야 사용할 수 있습니다."
        elif mid in PIVOT and not action.get("asleep",false):v["completion_factor"]=2.0
    elif tag=="stuff" and not PlayerMoveBulk.berry(b,p):v["completion_refusal"]="볼가득넣기는 유효한 소지 나무열매가 필요합니다."
    elif tag=="lighten" and int(p.stat_stages.get("speed",0))>=6:v["completion_refusal"]="스피드가 이미 최대 단계입니다."
    elif tag in ["ally_heal","pollen"]:
        var recipient:=ally(b,p)
        if recipient!=null:
            v.erase("damage");v.erase("heal");v["completion_heal_uid"]=recipient.uid
            v["completion_heal_amount"]=maxi(1,recipient.max_hp*2/3) if id==666 and PlayerMoveFields.read(b)["terrain"]=="grassy" else maxi(1,recipient.max_hp/2)
            v["card_notes"].append("회복 대상: "+recipient.display_name+" · HP +"+str(mini(recipient.max_hp-recipient.hp,PlayerMoveTactics.heal_amount(b,int(v["completion_heal_amount"])))) )
        elif tag=="ally_heal":v["completion_refusal"]="회복할 수 있는 부상 동료가 없습니다."
    if v.get("special")=="purify" and not MAJOR.any(func(key:String):return target.statuses.has(key)):v["completion_refusal"]="정화할 상대의 주요 상태이상이 없습니다."
    if healing_blocked(b,p) and v.has("sap_amount"):v["sap_amount"]=0
    if not v.has("damage") or v.get("preparing",false):return v
    var extra:=int(v.get("power_upgrade",0))
    if id in [67,447,484,535]:v["move_power"]=weight_power(b,p,target,id)+extra
    var factor:float=v.get("completion_factor",1.0)
    if c["charged"].get(p.uid,false) and v["type"]=="electric":factor*=2;v["completion_charge"]=true
    if c["curled"].get(p.uid,false) and id in [205,301]:factor*=2
    if c["small"].get(target.uid,false) and id in STOMP:factor*=2
    if id==788 and PlayerMoveAltitude.gravity(b):factor*=1.5
    if factor!=1.0:v["move_power"]=maxi(1,floori(int(v["move_power"])*factor));v["card_notes"].append("충전/연계/대상 조건 위력 ×"+str(factor))
    return v
static func reason(v:Dictionary) -> String:return str(v.get("completion_refusal",""))
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var id:=int(v["move_id"])
    if id in [156,215,287,312,685,816,849,850]:
        v["completion_keep"]={}
        var members:Array=[target] if id==685 else b.party if id in [215,312,816,849] else [p]
        for member:BattlePokemon in members:
            var keep:Dictionary={}
            for key:String in member.statuses:
                if key not in (MAJOR if id!=287 else ["burn","poison","paralysis"]):keep[key]=member.statuses[key].duplicate(true)
            v["completion_keep"][member.uid]=keep
    if v.get("preparing",false) or v.get("failed",false):return
    if v.get("completion_charge",false):write(b)["charged"].erase(p.uid)
    if id in BREAK and not b.boss_context.is_empty():BossBattleRules.write(b)["guards"].erase(target.uid)
    if id==747:
        var d:=HeldItems.item(b,p);HeldItems.consume(b,p,p.held_item);HeldItems.apply_berry(b,p,d);PlayerMoveBulk.sync_berries(b)
static func base_after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var proxy:=v
    if int(v.get("drain_percent",0))>0:
        proxy=v.duplicate(true);proxy.erase("drain_percent")
        if p.alive():HeldItems.heal(b,p,PlayerMoveRules.ratio(maxi(0,int(v["target_hp_before"])-target.hp),int(v["drain_percent"])))
    PlayerMoveRules.after_card(b,proxy,p,target)
static func cure(p:BattlePokemon) -> void:
    for key:String in MAJOR:p.statuses.erase(key)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    for uid:int in v.get("completion_keep",{}):
        var member:=PlayerMoveExchange.member(b,uid)
        if member!=null and member.alive():member.statuses.merge(v["completion_keep"][uid],true)
    if p.alive():write(b)["entry_used"][p.uid]=true
    if not p.alive() or v.get("preparing",false) or v.get("failed",false):return
    var id:=int(v["move_id"]);var tag:String=v.get("completion_rule","");var c:=write(b)
    match tag:
        "charge":c["charged"][p.uid]=true
        "curl":c["curled"][p.uid]=true
        "minimize":c["small"][p.uid]=true
        "lighten":c["weight_loss"][p.uid]=mini(1000000,int(c["weight_loss"].get(p.uid,0))+1000)
    if v.has("completion_heal_uid"):
        var member:=b.member(int(v["completion_heal_uid"]))
        if member!=null:HeldItems.heal(b,member,int(v["completion_heal_amount"]))
    var hit:=PlayerMoveBulk.landed(b,v,target)
    if not hit:return
    if tag=="draw":b._draw(1)
    elif tag in ["screen","reflect"]:
        var key:="screen" if tag=="screen" else "reflect";PlayerMoveFields.write(b)["ally"][key]=5;PlayerMoveRules.write(b)[key]=0
    elif tag=="haze" and not PlayerMoveAssist.blocked(b,v):p.stat_stages.clear();target.stat_stages.clear()
    elif tag=="party_cure":
        for member:BattlePokemon in b.party:
            if member.alive():cure(member)
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> Dictionary:
    if not ready_attack(a) or int(a.get("value",0))<=0 or a.get("player_guarded",false) or a.get("immune",false):return a
    a=a.duplicate(true);var id:=PlayerMoveInteractions.move_id(a);var c:=read(b);var factor:=1.0
    if c["charged"].get(b.enemy().uid,false) and a.get("type")=="electric":factor*=2
    if c["curled"].get(b.enemy().uid,false) and id in [205,301]:factor*=2
    if c["small"].get(p.uid,false) and id in STOMP:factor*=2
    if id in [67,447,484,535]:factor*=weight_power(b,b.enemy(),p,id)/float(weight_power(b,b.enemy(),p,id,false))
    if id==788 and PlayerMoveAltitude.gravity(b):factor*=1.5
    if factor!=1.0:
        if a.has("per_hit"):a["per_hit"]=maxi(1,floori(int(a["per_hit"])*factor));a["value"]=int(a["per_hit"])*int(a.get("hits",1))
        else:a["value"]=maxi(1,floori(int(a["value"])*factor))
        a["effects"]=a.get("effects",[])+["충전/연계/대상 조건 피해 ×"+str(factor)]
    return a
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,a:Dictionary) -> void:
    if not foe.alive() or a.get("asleep",false) or a.get("player_sealed",false) or a.get("failed_move",false) or a.has("bulk_cancel") or a.has("support_cancel"):return
    var id:=PlayerMoveInteractions.move_id(a);var c:=write(b)
    if id==268:c["charged"][foe.uid]=true
    elif id==111:c["curled"][foe.uid]=true
    elif id==107:c["small"][foe.uid]=true
    elif id==475:c["weight_loss"][foe.uid]=mini(1000000,int(c["weight_loss"].get(foe.uid,0))+1000)
    elif ready_attack(a) and a.get("type")=="electric":c["charged"].erase(foe.uid)
static func on_switch(b:TacticalBattle,old:int) -> void:
    if b.completion_context.is_empty():
        write(b)["entered"][b.active().uid]=b.turn;return
    for group:String in DEFAULT:b.completion_context[group].erase(old)
    if b.active().alive():b.completion_context["entered"][b.active().uid]=b.turn
static func on_knockout(b:TacticalBattle,uid:int) -> void:
    if b.completion_context.is_empty():return
    for group:String in DEFAULT:b.completion_context[group].erase(uid)
static func valid_context(value:Variant,b:Dictionary) -> bool:
    if not value is Dictionary:return false
    if value.is_empty():return true
    if value.size()!=DEFAULT.size():return false
    var uids:Array=b["party"]+b["enemies"]
    for group:String in DEFAULT:
        if not value.has(group) or not value[group] is Dictionary or value[group].size()>uids.size():return false
        for uid:Variant in value[group]:
            if not uid is int or uid not in uids:return false
            var v:Variant=value[group][uid]
            if group=="weight_loss":
                if not v is int or v<1 or v>1000000:return false
            elif group=="entered":
                if not v is int or v<1 or v>b["turn"]:return false
            elif not v is bool or not v:return false
    return true
static func lines(v:Dictionary) -> Array[String]:return PlayerMoveAdaptive.lines(v)
