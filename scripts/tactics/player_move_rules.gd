class_name PlayerMoveRules
extends RefCounted
## Optional player-card state. No new RNG or changes to shipped boss engines.
const DEFAULT:Dictionary={"charges":{},"recharge":{},"guards":{},"used_guard":{},"substitutes":{},"screen":0,"reflect":0,"safeguard":0,"pressure":{},"focus":{},"received":{},"hurt":{},"hits":{},"last":{},"yawn":{},"acted":{},"curses":{},"last_ally_ko":0,"pivot":{},"fickle":{},"stocks":{},"wishes":{},"rings":{},"roots":{},"infatuation":{},"silence":{},"seals":{},"foe_last":{},"tar":{},"destiny":{},"bond_pending":0,"spent_electric":{},"vulnerable":{},"beak":{}}
static func read(b:TacticalBattle) -> Dictionary:return b.move_context if not b.move_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.move_context.is_empty():b.move_context=DEFAULT.duplicate(true)
    return b.move_context
static func ratio(hp:int,percent:int) -> int:
    if hp<=0:return 0
    return maxi(1,roundi(hp/3.0) if absi(percent)==33 else roundi(hp*absi(percent)/100.0))
static func received(b:TacticalBattle,uid:int) -> Dictionary:
    var hit:Dictionary=read(b)["received"].get(uid,{})
    return hit if hit.get("turn",-100)>=b.turn-1 and hit.get("source",0)==b.enemy().uid else {"damage":0,"kind":""}
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("category")!="technique":return ""
    var c:=read(b);var id:=int(v["move_id"]);var original_id:=int(TacticalMoves.definition(str(v["key"]))["move_id"])
    if p.statuses.has("sleep") and original_id!=214:return "수면 중에는 자신의 기술을 쓸 수 없습니다. 다른 동료/도구를 사용하세요."
    if original_id==214:
        if not p.statuses.has("sleep"):return "잠꼬대는 수면 중에 사용합니다."
        if PlayerMoveCards.called(p).is_empty():return "잠꼬대로 호출할 수 있는 자신의 공격 기술이 없습니다."
    if v.get("special")=="stockpile" and c["stocks"].get(p.uid,0)>=3:return "이미3회 비축했습니다. 꿀꺽/토해내기로 비축을 소비하세요."
    if v.get("special") in ["swallow","spit_up"] and c["stocks"].get(p.uid,0)==0:return "먼저 비축하기를 사용하세요."
    if v.get("special")=="purify" and b.enemy().statuses.is_empty():return "치유할 상대 상태이상이 없습니다."
    if c["recharge"].get(p.uid,0)>=b.turn:return "재충전 중입니다. 다음 아군턴 종료 뒤 기술을 다시 쓸 수 있습니다."
    var charge:Dictionary=c["charges"].get(p.uid,{})
    if not charge.is_empty():
        if charge["card"]!=v["uid"]:return "충전한 카드를 사용하거나 다른 동료로 교대하세요."
        if b.turn<charge["ready"]:return "충전 중입니다. 다음 아군턴부터 이 카드를 사용하세요."
    if v.has("guard") and c["used_guard"].get(p.uid,0)==b.turn:return "이 동료는 이번 턴 이미 보호 기술을 사용했습니다."
    if v.get("special")=="substitute" and (p.hp<=maxi(1,p.max_hp/4) or c["substitutes"].get(p.uid,0)>0):return "대타출동은 최대HP의¼보다 많은 HP가 필요하며 대타를 중복 생성할 수 없습니다."
    if v.get("special")=="belly" and p.hp<=maxi(1,p.max_hp/2):return "배북은 최대HP의 절반보다 많은 HP가 필요합니다."
    if v.get("special")=="rest" and p.hp==p.max_hp:return "HP가 가득 차 잠자기를 사용할 필요가 없습니다."
    if id in [26,136] and BossBattleRules.active_in(b) and BossBattleRules.read(b)["gravity"]>0:return "중력 중에는 점프 기술을 사용할 수 없습니다."
    if v.has("hp_cost") and p.hp<=ratio(p.max_hp,int(v["hp_cost"])) and int(v["move_id"])==775:return "소울비트에 필요한 HP가 부족합니다."
    return ""
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var c:=write(b);var id:=int(v["move_id"])
    c["destiny"].erase(p.uid);c["vulnerable"].erase(p.uid)
    if v.get("boss_blocked",false) and v.get("special") in ["attract","yawn","tar","seal","purify"]:b._record("cancel","상대의 방어 · 대상 효과 차단")
    v["target_hp_before"]=target.hp
    v["target_effect_blocked"]=v.get("boss_blocked",false)
    if BossBattleRules.active_in(b) and BossBattleRules.read(b)["substitutes"].get(target.uid,0)>0 and not PlayerMoveCards.flag(id,9) and not PlayerMoveCards.flag(id,14):v["target_effect_blocked"]=true
    if v.has("immediate_boost"):
        for stat:String in v["immediate_boost"]:p.stat_stages[stat]=clampi(int(p.stat_stages.get(stat,0))+int(v["immediate_boost"][stat]),-6,6)
        v["boost_applied"]=true
    if v.get("preparing",false):
        c["charges"][p.uid]={"move":id,"ready":b.turn+1,"card":int(v["uid"])}
        c["acted"][p.uid]=b.turn;c["last"][p.uid]={"move":id,"turn":b.turn,"count":1,"failed":false}
        if v.has("charge_boost"):
            for stat:String in v["charge_boost"]:p.stat_stages[stat]=clampi(int(p.stat_stages.get(stat,0))+int(v["charge_boost"][stat]),-6,6)
        b._record("prepare",p.display_name+" · 충전한 카드를 다음 턴까지 보존",{"actor":p.uid,"move_id":id})
    elif v.get("released",false):c["charges"].erase(p.uid)
static func deal_damage(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon,values:Array[int]) -> void:
    var bypass:=PlayerMoveCards.flag(int(v["move_id"]),9) or PlayerMoveCards.flag(int(v["move_id"]),14)
    for i in values.size():
        if not target.alive():break
        if i>0:b._record("player_hit",p.display_name+" · 연속 타격",{"move_id":int(v["move_id"]),"actor":p.uid})
        b._damage(target,values[i],false,str(v["damage_class"]),bypass)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var c:=write(b);var id:=int(v["move_id"])
    if v.get("preparing",false):return
    var successful:bool=not v.get("failed",false) and not v.get("boss_blocked",false) and (not v.has("damage") or b.multiplier(str(v["type"]),target)>0)
    var lost:=maxi(0,int(v["target_hp_before"])-target.hp)
    if v.has("drain_percent"):
        var percent:=int(v["drain_percent"]);var amount:=ratio(lost,percent)
        if percent>0 and p.alive():
            if b.has_relic("shield_core"):amount=floori(amount*0.5)
            amount=mini(p.max_hp-p.hp,amount);p.hp+=amount
            if amount>0:b._record("heal",p.display_name+" · 실제 피해 흡수",{"target":p.uid,"amount":amount})
        elif percent<0 and amount>0:b._damage(p,amount,true)
    if v.has("hp_cost") and p.alive():b._damage(p,ratio(p.max_hp,int(v["hp_cost"])),true)
    if v.get("crash_due",false) and p.alive():b._damage(p,maxi(1,p.max_hp/2),true)
    if v.has("damage"):c["focus"].erase(p.uid)
    if v.has("recharge") and successful:c["recharge"][p.uid]=b.turn+1
    if v.has("guard"):
        c["guards"][p.uid]={"kind":v["guard"],"turn":b.turn};c["used_guard"][p.uid]=b.turn
        b._record("field",p.display_name+" · "+str(v["name"]),{"target":p.uid})
    var affected:bool=successful and not v.get("target_effect_blocked",false)
    if v.get("pressure_down",false) and affected:c["pressure"][target.uid]=b.turn
    match str(v.get("special","")):
        "stockpile":c["stocks"][p.uid]=mini(3,int(c["stocks"].get(p.uid,0))+1)
        "swallow","spit_up":
            var stocks:=int(c["stocks"].get(p.uid,0))
            for stat:String in ["defense","special_defense"]:p.stat_stages[stat]=clampi(int(p.stat_stages.get(stat,0))-stocks,-6,6)
            c["stocks"].erase(p.uid)
        "purify":
            if affected:target.statuses.clear()
        "wish":c["wishes"][p.uid]={"due":b.turn+1,"amount":maxi(1,p.max_hp/2)}
        "ring":c["rings"][p.uid]=true
        "root":c["roots"][p.uid]=true
        "attract":
            if affected:c["infatuation"][target.uid]={"source":p.uid,"until":b.turn+1}
        "silence":
            if affected:c["silence"][target.uid]=b.turn+1
        "seal":
            if affected and c["foe_last"].get(target.uid,0)>0:c["seals"][target.uid]={"move":c["foe_last"][target.uid],"until":b.turn+2}
        "tar":
            if affected:c["tar"][target.uid]=true
        "knock","thief":
            if affected:target.held_item=""
        "destiny":c["destiny"][p.uid]=true
        "double_shock":
            if successful:c["spent_electric"][p.uid]=true
        "glaive":
            if successful:c["vulnerable"][p.uid]=true
        "beak":
            if successful:c["beak"][p.uid]=b.turn
        "rest":
            for status:String in ["burn","poison","paralysis"]:p.statuses.erase(status)
            p.statuses["sleep"]={"turns":3,"source_uid":p.uid}
        "substitute":
            var cost:=maxi(1,p.max_hp/4);b._damage(p,cost,true);c["substitutes"][p.uid]=cost
        "haze":
            for a:BattlePokemon in [p,target]:a.stat_stages.clear()
            b._record("stat","흑안개 · 양쪽 능력 단계 초기화")
        "clear_stages":
            if affected:target.stat_stages.clear()
        "party_cure":
            for a:BattlePokemon in b.party:a.statuses.clear()
            b._record("status","동료 전원 상태이상 회복")
        "refresh":p.statuses.clear()
        "yawn":
            if affected and target.alive() and not ["burn","poison","sleep","paralysis"].any(func(k:String):return target.statuses.has(k)):
                c["yawn"][target.uid]={"source":p.uid,"due":b.turn+1}
                b._record("status",target.display_name+" · 다음 자기 행동 종료 뒤 수면",{"target":target.uid})
        "focus_energy":c["focus"][p.uid]=true
        "belly":
            b._damage(p,maxi(1,p.max_hp/2),true);p.stat_stages["attack"]=6
        "screen","reflect","safeguard":
            c[v["special"]]=6
            b._record("field",str(v["name"])+" · 다음5아군턴 유지")
        "curse":
            if "ghost" in p.types:
                b._damage(p,maxi(1,p.max_hp/2),true)
                if affected and target.alive():c["curses"][target.uid]=p.uid
            else:
                for stat:String in ["attack","defense","speed"]:p.stat_stages[stat]=clampi(int(p.stat_stages.get(stat,0))+(-1 if stat=="speed" else 1),-6,6)
        "defog":
            c["screen"]=0;c["reflect"]=0;c["safeguard"]=0
            b._record("field","안개제거 · 양쪽 장막 해제")
        "pivot":
            if successful:c["pivot"]={"uid":p.uid,"turn":b.turn}
    if v.get("variable")=="fickle" and successful:c["fickle"][p.uid]=(int(c["fickle"].get(p.uid,0))+1)%10
    var last:Dictionary=c["last"].get(p.uid,{})
    c["last"][p.uid]={"move":id,"turn":b.turn,"count":int(v.get("chain_count",1)),"failed":not successful}
    c["acted"][p.uid]=b.turn
static func finish_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    if v.get("self_ko",false) and p.alive() and not v.get("preparing",false):b._damage(p,p.hp,true)
static func guard(b:TacticalBattle,p:BattlePokemon) -> String:
    var g:Dictionary=read(b)["guards"].get(p.uid,{})
    return str(g["kind"]) if g.get("turn",0)==b.turn else ""
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var a:=original.duplicate(true);var c:=read(b);var raw:=TacticalMoves.visual(int(a.get("effective_move",a.get("move_id",0))))
    var attack:bool=a.get("damage_class","status")!="status" or a["kind"] in ["attack","charge","barrage"]
    var targeted:bool=attack or (not raw.is_empty() and int(raw.get("target",7)) not in [4,7,12,13] and a["kind"] not in ["guard","prepare","recharge","wait","block","fortify","boost","recover"])
    var mode:=guard(b,p)
    var mid:=int(a.get("effective_move",a.get("move_id",0)))
    var sealed:Dictionary=c["seals"].get(b.enemy().uid,{})
    if (c["silence"].get(b.enemy().uid,0)>=b.turn and PlayerMoveCards.flag(mid,9)) or (sealed.get("until",0)>=b.turn and sealed.get("move",0)==mid):
        a["player_sealed"]=true;a["value"]=0;a["advance"]=1
        if a.has("per_hit"):a["per_hit"]=0
        if a.has("effects"):a["effects"].append("아군의 봉인 효과로 이 기술 사용 불가")
    var charge:Dictionary=c["charges"].get(p.uid,{})
    var phase:String=str(PlayerMoveCards.data()["moves"].get(str(charge.get("move",0)),{}).get("charge",""))
    var exceptions:Array={"air":[16,87,239,327,479,542,615],"burrow":[89,222],"dive":[57,250],"vanish":[]}.get(phase,[])
    var hiding:bool=phase in ["air","burrow","dive","vanish"] and not charge.is_empty() and b.turn<int(charge["ready"])
    if targeted and hiding and mid not in exceptions:
        a["player_airborne"]=true;a["immune"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        if a.has("effects"):a["effects"].append("아군이 공중/잠복/수중/모습을 감춘 상태라 빗나감")
    if mid in [18,46,525] and ((c["substitutes"].get(p.uid,0)>0 and not PlayerMoveCards.flag(mid,9)) or c["roots"].get(p.uid,false)):a["player_stop_switch"]=true
    if targeted and not mode.is_empty() and mode!="endure":
        a["player_guarded"]=true;a["immune"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        if a.has("effects"):a["effects"].append("출전 동료의 보호 기술로 대상 피해/효과 차단")
        if int(a.get("move_id",0)) in [26,136]:a["failed_move"]=true;a["crash"]=maxi(1,b.enemy().max_hp/2)
    elif attack:
        var factor:=0.8 if c["pressure"].get(b.enemy().uid,0)==b.turn else 1.0
        if c["vulnerable"].get(p.uid,false):factor*=2
        if c["infatuation"].get(b.enemy().uid,{}).get("source",0)==p.uid and c["infatuation"][b.enemy().uid]["until"]>=b.turn:factor*=0.5
        if hiding and ((phase=="air" and mid in [16,239]) or phase in ["burrow","dive"]):factor*=2
        if c["screen"]>0 and a.get("damage_class")=="special":factor*=0.5
        if c["reflect"]>0 and a.get("damage_class","physical")=="physical":factor*=0.5
        if factor!=1.0:
            if a.has("per_hit"):a["per_hit"]=maxi(1,floori(int(a["per_hit"])*factor)) if a["per_hit"]>0 else 0;a["value"]=int(a["per_hit"])*int(a.get("hits",1))
            else:a["value"]=maxi(1,floori(int(a["value"])*factor)) if a["value"]>0 else 0
            if a.has("effects"):a["effects"].append("아군 장막/공격 압박을 반영한 피해")
        if mode=="endure":
            a["value"]=mini(int(a["value"]),maxi(0,p.hp+p.block-1))
            if a.has("per_hit"):a["per_hit"]=mini(int(a["per_hit"]),maxi(0,p.hp+p.block-1))
    return a
static func absorb(b:TacticalBattle,p:BattlePokemon,amount:int,piercing:bool,bypass:bool) -> int:
    if p.uid<0 or piercing:return amount
    var mode:=guard(b,p)
    if b.phase=="enemy" and not mode.is_empty() and mode!="endure":return 0
    var pool:=int(read(b)["substitutes"].get(p.uid,0))
    if pool>0 and not bypass:
        write(b)["substitutes"][p.uid]=maxi(0,pool-amount)
        if amount>0:b._record("substitute",p.display_name+" · 대타가 피해 흡수",{"target":p.uid,"amount":mini(pool,amount)})
        return 0
    return mini(amount,maxi(0,p.hp-1)) if mode=="endure" and b.phase=="enemy" else amount
static func track(b:TacticalBattle,p:BattlePokemon,lost:int,kind:String) -> void:
    if lost<=0:return
    var c:=write(b);c["hurt"][p.uid]=b.turn
    if p.uid>0 and b.phase=="enemy" and kind in ["physical","special"]:
        c["received"][p.uid]={"turn":b.turn,"damage":lost,"kind":kind,"source":b.enemy().uid}
        c["hits"][p.uid]=mini(1000,int(c["hits"].get(p.uid,0))+1)
    if not p.alive():
        if p.uid>0:
            c["last_ally_ko"]=b.turn
            if c["destiny"].get(p.uid,false) and kind in ["physical","special"] and b.phase=="enemy":c["bond_pending"]=b.enemy().uid
        for uid:int in c["infatuation"].keys():
            if c["infatuation"][uid]["source"]==p.uid:c["infatuation"].erase(uid)
        for key:String in ["charges","recharge","guards","substitutes","focus","yawn","curses","stocks","wishes","rings","roots","infatuation","silence","seals","tar","destiny","vulnerable","beak"]:c[key].erase(p.uid)
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,before:Dictionary,had_sub:bool,stages:Dictionary,marks:Dictionary) -> void:
    var c:=write(b)
    var bypass:=PlayerMoveCards.flag(int(a.get("effective_move",a.get("move_id",0))),9) or PlayerMoveCards.flag(int(a.get("effective_move",a.get("move_id",0))),14)
    if p.alive() and (c["safeguard"]>0 or (had_sub and not bypass) or a.get("player_guarded",false) or a.get("player_airborne",false)):
        for status:String in ["burn","poison","sleep","paralysis","confusion"]:
            if before.has(status):p.statuses[status]=before[status].duplicate(true)
            else:p.statuses.erase(status)
        if (had_sub and not bypass) or a.get("player_guarded",false) or a.get("player_airborne",false):p.stat_stages=stages.duplicate()
        var block_unique:bool=(had_sub and not bypass) or a.get("player_guarded",false) or a.get("player_airborne",false)
        for group:String in (["drowsy","infatuation","silence","seals","curses","tar","traps"] if block_unique else ["drowsy"]):
            if not b.boss_context.has(group):continue
            if marks.get(group,{}).has(p.uid):b.boss_context[group][p.uid]=marks[group][p.uid].duplicate(true) if marks[group][p.uid] is Dictionary else marks[group][p.uid]
            else:b.boss_context[group].erase(p.uid)
    if p.alive():
        var types:=PlayerMoveCards.effective_types(b,p)
        if "fire" in types and not before.has("burn"):p.statuses.erase("burn")
        if types.any(func(t:String):return t in ["steel","poison"]) and not before.has("poison"):p.statuses.erase("poison")
        if "electric" in types and not before.has("paralysis"):p.statuses.erase("paralysis")
        for group:String in ["roots","rings"]:
            if c[group].get(p.uid,false):
                var amount:=maxi(1,p.max_hp/16)
                if b.has_relic("shield_core"):amount=floori(amount*0.5)
                amount=mini(p.max_hp-p.hp,amount);p.hp+=amount
                if amount>0:b._record("heal",p.display_name+" · 지속 회복",{"target":p.uid,"amount":amount})
    if c["charges"].has(p.uid):
        var charge_id:=int(c["charges"][p.uid]["move"])
        if PlayerMoveCards.data()["moves"][str(charge_id)].get("charge")=="air" and ((int(a.get("move_id",0)) in [479,615]) or b.boss_context.get("gravity",0)>0):c["charges"].erase(p.uid)
    var contact:bool=PlayerMoveCards.flag(int(a.get("effective_move",a.get("move_id",0))),1) and not a.get("player_sealed",false) and not a.get("player_airborne",false) and not a.get("asleep",false) and a["kind"] not in ["prepare","recharge","wait"]
    if foe.alive() and c["beak"].get(p.uid,0)==b.turn and contact and "fire" not in foe.types:foe.statuses["burn"]={"turns":3,"source_uid":p.uid}
    if int(a.get("effective_move",a.get("move_id",0)))>0 and not a.get("player_sealed",false):c["foe_last"][foe.uid]=int(a.get("effective_move",a["move_id"]))
    var mode:=guard(b,p)
    if not mode.is_empty() and mode!="endure" and contact and foe.alive():
        if mode in ["king","obstruct"]:
            var stat:String="attack" if mode=="king" else "defense"
            foe.stat_stages[stat]=maxi(-6,int(foe.stat_stages.get(stat,0))-2)
        if (mode=="baneful" and not foe.types.any(func(t:String):return t in ["steel","poison"])) or (mode=="burning" and "fire" not in foe.types):foe.statuses["poison" if mode=="baneful" else "burn"]={"turns":3,"source_uid":p.uid}
        if mode=="spiky":b._damage(foe,maxi(1,foe.max_hp/8),true)
    if foe.alive() and c["curses"].has(foe.uid):b._damage(foe,maxi(1,foe.max_hp/4),true)
    var yawn:Dictionary=c["yawn"].get(foe.uid,{})
    if foe.alive() and not yawn.is_empty() and yawn["due"]<=b.turn:
        c["yawn"].erase(foe.uid)
        if (not BossBattleRules.active_in(b) or BossBattleRules.read(b)["safeguard"]==0) and not ["burn","poison","sleep","paralysis"].any(func(k:String):return foe.statuses.has(k)):foe.statuses["sleep"]={"turns":1,"source_uid":yawn["source"]}
    for key:String in ["screen","reflect","safeguard"]:
        if c[key]>0:c[key]-=1
static func on_switch(b:TacticalBattle,uid:int) -> void:
    var c:=write(b)
    c["acted"].erase(uid);c["spent_electric"].erase(uid)
    c["charges"].erase(uid);c["guards"].erase(uid);c["substitutes"].erase(uid);c["last"].erase(uid);c["focus"].erase(uid);c["pivot"].clear()
    for group:String in ["stocks","rings","roots","destiny","vulnerable","beak"]:c[group].erase(uid)
    for enemy_uid:int in c["infatuation"].keys():
        if c["infatuation"][enemy_uid]["source"]==uid:c["infatuation"].erase(enemy_uid)
static func pivot_free(b:TacticalBattle) -> bool:return read(b)["pivot"].get("uid",0)==b.active().uid and read(b)["pivot"].get("turn",0)==b.turn
static func end_player(b:TacticalBattle,p:BattlePokemon) -> void:
    var c:=write(b)
    if c["recharge"].get(p.uid,0)<=b.turn:c["recharge"].erase(p.uid)
static func valid_context(c:Variant,b:Dictionary,cards:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.has(key) or typeof(c[key])!=typeof(DEFAULT[key]):return false
    for key:String in ["screen","reflect","safeguard"]:
        if c[key]<0 or c[key]>6:return false
    if c["bond_pending"]!=0:return false
    if c["last_ally_ko"]<0 or c["last_ally_ko"]>b["turn"]:return false
    for key:String in ["charges","recharge","guards","used_guard","substitutes","focus","received","hits","last","acted","fickle","stocks","wishes","rings","roots","destiny","spent_electric","vulnerable","beak"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in b["party"]:return false
            var v:Variant=c[key][uid]
            match key:
                "charges":
                    if not v is Dictionary or v.size()!=3 or not v.get("move") is int or not PlayerMoveCards.data()["moves"].get(str(v["move"]),{}).has("charge") or not v.get("ready") is int or v["ready"]<1 or v["ready"]>b["turn"]+1 or not v.get("card") is int or not cards.has(v["card"]) or cards[v["card"]]["owner_uid"]!=uid or int(TacticalMoves.definition(cards[v["card"]]["key"])["move_id"])!=v["move"] or v["card"] not in b["piles"][0]:return false
                "guards":
                    if not v is Dictionary or v.size()!=2 or v.get("kind") not in ["protect","endure","king","spiky","baneful","obstruct","burning"] or not v.get("turn") is int or v["turn"]<1 or v["turn"]>b["turn"]:return false
                "received":
                    if not v is Dictionary or v.size()!=4 or not v.get("turn") is int or v["turn"]<1 or v["turn"]>b["turn"] or not v.get("damage") is int or v["damage"]<1 or v["damage"]>100000 or v.get("kind") not in ["physical","special"] or not v.get("source") is int or v["source"] not in b["enemies"]:return false
                "last":
                    if not v is Dictionary or v.size()!=4 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not v.get("turn") is int or v["turn"]<1 or v["turn"]>b["turn"] or not v.get("count") is int or v["count"]<1 or v["count"]>3 or not v.get("failed") is bool:return false
                "wishes":
                    if not v is Dictionary or v.size()!=2 or not v.get("due") is int or v["due"]<1 or v["due"]>b["turn"]+1 or not v.get("amount") is int or v["amount"]<1 or v["amount"]>50000:return false
                "stocks":
                    if not v is int or v<1 or v>3:return false
                "focus","rings","roots","destiny","spent_electric","vulnerable":
                    if not v is bool or not v:return false
                "substitutes":
                    if not v is int or v<0 or v>25000:return false
                "fickle":
                    if not v is int or v<0 or v>9:return false
                "hits":
                    if not v is int or v<0 or v>1000:return false
                _:
                    if not v is int or v<1 or v>b["turn"]+(1 if key=="recharge" else 0):return false
    for key:String in ["hurt","pressure","yawn","curses","infatuation","silence","seals","foe_last","tar"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in (b["party"]+b["enemies"] if key=="hurt" else b["enemies"]):return false
            var v:Variant=c[key][uid]
            if key=="yawn":
                if not v is Dictionary or v.size()!=2 or not v.get("source") is int or v["source"] not in b["party"] or not v.get("due") is int or v["due"]<1 or v["due"]>b["turn"]+1:return false
            elif key=="infatuation":
                if not v is Dictionary or v.size()!=2 or not v.get("source") is int or v["source"] not in b["party"] or not v.get("until") is int or v["until"]<1 or v["until"]>b["turn"]+1:return false
            elif key=="seals":
                if not v is Dictionary or v.size()!=2 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not v.get("until") is int or v["until"]<1 or v["until"]>b["turn"]+2:return false
            elif key=="silence":
                if not v is int or v<1 or v>b["turn"]+1:return false
            elif key=="foe_last":
                if not v is int or TacticalMoves.visual(v).is_empty():return false
            elif key=="tar":
                if not v is bool or not v:return false
            elif key=="curses":
                if not v is int or v not in b["party"]:return false
            elif not v is int or v<1 or v>b["turn"]:return false
    var pivot:Dictionary=c["pivot"]
    if not pivot.is_empty() and (pivot.size()!=2 or not pivot.get("uid") is int or pivot["uid"] not in b["party"] or not pivot.get("turn") is int or pivot["turn"]<1 or pivot["turn"]>b["turn"]):return false
    return true

static func keep_charge(b:TacticalBattle,uid:int) -> bool:
    return read(b)["charges"].values().any(func(v:Dictionary):return v["card"]==uid)
static func clean_charges(b:TacticalBattle) -> void:
    var c:=write(b)
    for uid:int in c["charges"].keys():
        if not b.hand.any(func(card:BattleCardInstance):return card.uid==c["charges"][uid]["card"]):c["charges"].erase(uid)

static func finish_enemy_hit(b:TacticalBattle) -> void:
    var c:=write(b);var uid:=int(c["bond_pending"]);c["bond_pending"]=0
    for foe:BattlePokemon in b.enemies:
        if foe.uid==uid and foe.alive():
            b._record("status","길동무 · 직접 공격한 상대와 동반 기절",{"target":uid})
            b._damage(foe,foe.hp,true)
static func start_player(b:TacticalBattle) -> void:
    var c:=write(b)
    for uid:int in c["wishes"].keys():
        var p:=b.member(uid)
        if c["wishes"][uid]["due"]>b.turn:continue
        var amount:=int(c["wishes"][uid]["amount"]);c["wishes"].erase(uid)
        if p==null or not p.alive():continue
        if b.has_relic("shield_core"):amount=floori(amount*0.5)
        amount=mini(p.max_hp-p.hp,amount);p.hp+=amount
        if amount>0:b._record("heal",p.display_name+" · 소원 회복",{"target":uid,"amount":amount})
static func rooted(b:TacticalBattle) -> bool:return read(b)["roots"].get(b.active().uid,false) and "ghost" not in PlayerMoveCards.effective_types(b,b.active())
static func affinity(b:TacticalBattle,attack:String,p:BattlePokemon,base:float) -> float:
    var c:=read(b)
    if p.uid>0 and (c["spent_electric"].get(p.uid,false) or (attack=="ground" and c["roots"].get(p.uid,false))):
        var types:=PlayerMoveCards.effective_types(b,p)
        if attack=="ground" and (c["roots"].get(p.uid,false) or b.boss_context.get("gravity",0)>0):types.erase("flying")
        base=TypeMatchup.multiplier(attack,types)
    return base*(2 if attack=="fire" and c["tar"].get(p.uid,false) else 1)
