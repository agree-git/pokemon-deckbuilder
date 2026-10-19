class_name PlayerInteractionHooks
extends RefCounted
## v24: pinned hooks with contact/sound/substitute facts and guard bypass.
static func held_damage(b:TacticalBattle,p:BattlePokemon,lost:int,piercing:bool,landed:bool) -> void:
    if not piercing and int(b.held_attack.get("target",0))==p.uid:
        var attack:Dictionary=b.held_attack;attack["loss"]+=lost;attack["last_loss"]=lost;attack["landed"]=attack["landed"] or landed
        var v:Dictionary=attack["view"];var source:=PlayerMoveExchange.member(b,int(attack["source"]));var d:=HeldItems.item(b,p)
        if lost>0 and source!=null:
            if d.get("rule")=="weakness" and p.alive() and b.multiplier(str(v.get("type","normal")),p)>1:
                HeldItems.consume(b,p,p.held_item)
                for stat:String in ["attack","special_attack"]:p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+2)
            if d.get("rule")=="helmet" and source.alive() and PlayerMoveInteractions.flag(int(v.get("copied_view",{}).get("move_id",v.get("effective_move",v.get("move_id",0)))),1):b._damage(source,maxi(1,source.max_hp/6),true)
    HeldItems.react(b,p)
static func player_hits(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon,values:Array[int]) -> void:
    var bypass:=PlayerMoveInteractions.flag(int(v["move_id"]),9) or PlayerMoveInteractions.flag(int(v["move_id"]),14)
    for i in values.size():
        if not target.alive() or not p.alive():break
        if i>0:b._record("player_hit",p.display_name+" · 연속 타격",{"move_id":int(v["move_id"]),"actor":p.uid})
        b._damage(target,values[i],false,str(v["damage_class"]),bypass)
static func item_preview(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> void:
    if not v.has("damage"):return
    var target:=b.enemy();var hp:=target.hp;var shield:=target.block;var sub:=0;var total:=0;var self_hp:=p.hp
    var d:=HeldItems.item(b,target)
    if BossBattleRules.active_in(b) and not PlayerMoveInteractions.flag(int(v["move_id"]),9) and not PlayerMoveInteractions.flag(int(v["move_id"]),14):sub=int(BossBattleRules.read(b)["substitutes"].get(target.uid,0))
    for n:int in PlayerMoveCards.damage_values(b,v,p):
        if hp<=0 or self_hp<=0:break
        var hit:=maxi(0,n-shield);shield=maxi(0,shield-n)
        if sub>0:sub=maxi(0,sub-hit);continue
        var lost:=mini(hp,hit)
        if d.get("rule")=="sash" and hp==target.max_hp and lost>=hp:lost=maxi(0,hp-1);d={}
        hp-=lost;total+=lost
        if lost>0 and d.get("rule")=="helmet" and PlayerMoveInteractions.flag(int(v["move_id"]),1):self_hp-=maxi(1,p.max_hp/6)
        if hp>0 and d.get("rule")=="heal" and hp<=target.max_hp/2 and PlayerMoveTactics.read(b)["heal_block"].get(target.uid,0)<b.turn:
            var recovered:=int(d["amount"]) if int(d["amount"])>0 else maxi(1,target.max_hp/4)
            if target.uid>0:recovered=PlayerMoveTactics.heal_amount(b,recovered)
            hp=mini(target.max_hp,hp+recovered);d={}
    v["preview_hp_loss"]=total;v["preview_target_hp"]=hp
    if v.has("drain_percent"):
        var percent:=int(v["drain_percent"]);var amount:=PlayerMoveRules.ratio(total,percent)
        if percent>0 and b.has_relic("shield_core"):amount=floori(amount*0.5)
        v["preview_drain"]=mini(p.max_hp-p.hp,amount) if percent>0 else mini(p.hp,amount)
    if HeldItems.item(b,p).get("rule")=="life":v["card_notes"].append("생명의구슬 · 명중 뒤 최대HP의1/10 반동")
static func player_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var c:=PlayerMoveRules.write(b);var id:=int(v["move_id"])
    c["destiny"].erase(p.uid);c["vulnerable"].erase(p.uid)
    if v.get("boss_blocked",false) and v.get("special") in ["attract","yawn","tar","seal","purify"]:b._record("cancel","상대의 방어 · 대상 효과 차단")
    v["target_hp_before"]=target.hp
    v["target_effect_blocked"]=v.get("boss_blocked",false)
    if BossBattleRules.active_in(b) and BossBattleRules.read(b)["substitutes"].get(target.uid,0)>0 and not PlayerMoveInteractions.flag(id,9) and not PlayerMoveInteractions.flag(id,14):v["target_effect_blocked"]=true
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
static func player_after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,before:Dictionary,had_sub:bool,stages:Dictionary,marks:Dictionary) -> void:
    var c:=PlayerMoveRules.write(b)
    var bypass:=PlayerMoveInteractions.flag(PlayerMoveInteractions.move_id(a),9) or PlayerMoveInteractions.flag(PlayerMoveInteractions.move_id(a),14)
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
    var contact:bool=PlayerMoveInteractions.flag(PlayerMoveInteractions.move_id(a),1) and not a.get("player_sealed",false) and not a.get("player_airborne",false) and not a.get("asleep",false) and not a.get("powdered",false) and not a.has("bulk_cancel") and a["kind"] not in ["prepare","recharge","wait"]
    if foe.alive() and c["beak"].get(p.uid,0)==b.turn and contact and "fire" not in foe.types:foe.statuses["burn"]={"turns":3,"source_uid":p.uid}
    if PlayerMoveInteractions.move_id(a)>0 and not a.get("player_sealed",false):c["foe_last"][foe.uid]=PlayerMoveInteractions.move_id(a)
    var mode:=PlayerMoveRules.guard(b,p)
    if not mode.is_empty() and mode!="endure" and contact and foe.alive() and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(a)):
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
static func player_absorb(b:TacticalBattle,p:BattlePokemon,amount:int,piercing:bool,bypass:bool) -> int:
    if p.uid<0 or piercing:return amount
    var mode:=PlayerMoveRules.guard(b,p)
    if b.phase=="enemy" and not mode.is_empty() and mode!="endure" and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(b.held_attack.get("view",{}))):return 0
    var pool:=int(PlayerMoveRules.read(b)["substitutes"].get(p.uid,0))
    if pool>0 and not bypass:
        PlayerMoveRules.write(b)["substitutes"][p.uid]=maxi(0,pool-amount)
        if amount>0:b._record("substitute",p.display_name+" · 대타가 피해 흡수",{"target":p.uid,"amount":mini(pool,amount)})
        return 0
    return mini(amount,maxi(0,p.hp-1)) if mode=="endure" and b.phase=="enemy" else amount
static func enemy_rules(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var a:=original.duplicate(true);var c:=PlayerMoveRules.read(b);var raw:=TacticalMoves.visual(PlayerMoveInteractions.move_id(a))
    var attack:bool=a.get("damage_class","status")!="status" or a["kind"] in ["attack","charge","barrage"]
    var targeted:bool=attack or (not raw.is_empty() and int(raw.get("target",7)) not in [4,7,12,13] and a["kind"] not in ["guard","prepare","recharge","wait","block","fortify","boost","recover"])
    var mode:=PlayerMoveRules.guard(b,p)
    var mid:=int(a.get("copied_view",{}).get("move_id",a.get("effective_move",a.get("move_id",0))))
    var sealed:Dictionary=c["seals"].get(b.enemy().uid,{})
    if (c["silence"].get(b.enemy().uid,0)>=b.turn and PlayerMoveInteractions.flag(mid,9)) or (sealed.get("until",0)>=b.turn and sealed.get("move",0)==mid):
        a["player_sealed"]=true;a["value"]=0;a["advance"]=1
        if a.has("per_hit"):a["per_hit"]=0
        if a.has("effects"):a["effects"].append("아군의 봉인 효과로 이 기술 사용 불가")
    var charge:Dictionary=c["charges"].get(p.uid,{})
    var phase:String=str(PlayerMoveCards.data()["moves"].get(str(charge.get("move",0)),{}).get("charge",""))
    var exceptions:Array={"air":[16,87,239,327,479,542,614],"burrow":[89,222],"dive":[57,250],"vanish":[]}.get(phase,[])
    var hiding:bool=phase in ["air","burrow","dive","vanish"] and not charge.is_empty() and b.turn<int(charge["ready"])
    if targeted and hiding and mid not in exceptions:
        a["player_airborne"]=true;a["immune"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        if a.has("effects"):a["effects"].append("아군이 공중/잠복/수중/모습을 감춘 상태라 빗나감")
    if mid in [18,46,525] and ((c["substitutes"].get(p.uid,0)>0 and not PlayerMoveInteractions.flag(mid,9)) or c["roots"].get(p.uid,false)):a["player_stop_switch"]=true
    if targeted and not PlayerMoveInteractions.bypasses_guard(mid) and not mode.is_empty() and mode!="endure":
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
static func boss_protected(b: TacticalBattle,view: Dictionary) -> bool:
    var guard: String=BossBattleEffectsP3.read(b)["guards"].get(b.enemy().uid,"")
    if guard.is_empty(): return false
    var targeted: bool=view.has("damage") or view.has("shield_attack") or BossBattleEffectsP3.TARGET_EFFECTS.any(func(k: String):return view.has(k)) or (view.has("stat_changes") and view.get("stat_target")=="enemy") or int(view.get("move_id",0))==432
    if not targeted:return false
    var id:=int(view.get("move_id",0))
    if PlayerMoveInteractions.bypasses_guard(id): return false
    return guard!="king" or view.has("damage") or view.has("shield_attack")
static func boss_filter_view(b: TacticalBattle,original: Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    var guarded:=PlayerInteractionHooks.boss_protected(b,v) or BossBattleEffectsP3.airborne_miss(b,v)
    var sub: bool=BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0 and not PlayerMoveInteractions.flag(int(v.get("move_id",0)),9) and not PlayerMoveInteractions.flag(int(v.get("move_id",0)),14)
    if guarded:
        if v.get("category")=="technique" and PlayerMoveInteractions.flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):v["boss_contact_guard"]=BossBattleEffectsP3.read(b)["guards"].get(b.enemy().uid,"")
        v["boss_blocked"]=true
    for key: String in BossBattleEffectsP3.TARGET_EFFECTS:
        if guarded or sub or (BossBattleEffectsP3.read(b)["safeguard"]>0 and key in ["burn","poison","sleep","paralysis","confusion"]):v.erase(key)
    if (guarded or sub) and v.get("stat_target")=="enemy":v.erase("stat_changes")
    return v
static func boss_after_card(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> void:
    BossBattleEffectsP3.write(b)["card_attacker"]=0
    if v.get("category")=="technique" and PlayerMoveInteractions.flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):
        var cycle: Array=b.enemy_definitions[b.enemy_index]["intents"]
        if int(cycle[int(b.opening()["intent"])%cycle.size()]["move_id"])==690 and actor.alive():
            actor.statuses["burn"]={"turns":3,"source_uid":b.enemy().uid}
            b._record("status",actor.display_name+" · 부리캐논 준비 중 접촉 화상",{"target":actor.uid})
    var guard: String=v.get("boss_contact_guard","")
    var stat: String="attack" if guard=="king" else "defense"
    if guard in ["king","obstruct"] and actor.alive():
        actor.stat_stages[stat]=maxi(-6,int(actor.stat_stages.get(stat,0))-2)
        b._record("stat",actor.display_name+" · 접촉 반격 "+PokemonStats.TITLES[stat]+" -2",{"target":actor.uid})
static func boss_card_reason(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    if v.get("category")!="technique":return ""
    if BossBattleEffectsP3.read(b)["silence"].get(actor.uid,0)>=b.turn and PlayerMoveInteractions.flag(int(v.get("move_id",0)),9):return "지옥찌르기 · 음성 기술이 봉인돼 있습니다."
    var seal:Dictionary=BossBattleEffectsP3.read(b)["seals"].get(actor.uid,{})
    if seal.get("until",0)>=b.turn and seal.get("move",0)==int(v.get("move_id",0)):return "섬뜩한주문 · 마지막 기술이 봉인돼 있습니다. 다른 기술/도구/교대를 사용하세요."
    return ""
static func boss_player_damage(b: TacticalBattle,view: Dictionary,amount: int) -> int:
    if not BossBattleEffectsP3.active_in(b): return amount
    if PlayerInteractionHooks.boss_protected(b,view) or BossBattleEffectsP3.airborne_miss(b,view): return 0
    var target:=b.enemy()
    if BossBattleEffectsP3.read(b)["airborne"].get(target.uid,false) and int(view.get("move_id",0)) in [16,239] and amount>0:amount*=2
    if BossBattleEffectsP3.read(b)["vulnerable"].get(target.uid,false) and view.has("damage") and amount>0:amount*=2
    var actor:=b.member(int(view.get("owner_uid",0)))
    # card_view supplies the exact owner; shared cards never trigger attraction.
    if actor!=null and BossBattleEffectsP3.read(b)["infatuation"].get(actor.uid,{}).get("source",0)==target.uid and amount>0:amount=maxi(1,amount/2)
    if BossBattleEffectsP3.read(b)["screen"]>0 and view.get("damage_class")=="special" and int(view.get("move_id",0))!=280 and amount>0: return maxi(1,amount/2)
    return amount
static func boss_card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    var notes: Array[String]=[]
    if BossBattleEffectsP3.airborne_miss(b,v):notes.append("공중 회피 · 일반 대상 효과가 빗나감")
    if PlayerInteractionHooks.boss_protected(b,v):notes.append("상대 방어로 대상 효과 차단")
    if BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0:notes.append("대타출동 유지 · 대타를 깬 타격의 초과 피해 없음")
    if BossBattleEffectsP3.read(b)["safeguard"]>0:notes.append("신비의부적 · 상태 부여 차단")
    if actor!=b.active() and BossBattleEffectsP3.read(b)["rocks"]:notes.append("교대 시 스텔스록 HP -%d" % BossBattleEffectsP3.entry_damage(b,actor))
    if int(v.get("move_id",0)) in [229,432,866,280]:notes.append("설치/장막 해제 효과 지원")
    var why:=PlayerInteractionHooks.boss_card_reason(b,v,actor)
    if not why.is_empty():notes.append(why)
    if BossBattleEffectsP3.read(b)["infatuation"].has(actor.uid):notes.append("헤롱헤롱 · 시전자 대상 기술 피해 절반 · 교대로 해제")
    if BossBattleEffectsP3.trapped(b):notes.append("교체 봉쇄 · 현재 동료 기술/도구는 사용 가능")
    return "\n".join(notes)
static func boss_on_card(b: TacticalBattle,original: Dictionary,actor: BattlePokemon) -> void:
    var c:=BossBattleEffectsP3.write(b)
    c["acted"][actor.uid]=b.turn
    c["card_attacker"]=actor.uid if original.get("category")=="technique" else 0
    if original.get("category")=="technique":
        var move_id:=int(original.get("move_id",0))
        var attack:bool=original.has("damage") or original.has("shield_attack")
        c["last_moves"][actor.uid]={"move":move_id,"target":b.enemy().uid,"turn":b.turn,"attack":attack}
        if attack and PlayerMoveInteractions.flag(move_id,7):c["mirror"][b.enemy().uid]={"source":actor.uid,"move":move_id}
    if BossBattleEffectsP3.airborne_miss(b,original):
        b._record("cancel","상대가 공중에 있어 대상 효과 빗나감")
        return
    var id:=int(original.get("move_id",0))
    if PlayerInteractionHooks.boss_protected(b,original):
        b._record("cancel","상대의 방어 · 대상 효과 차단")
        return
    if id in [479,615] and int(original.get("preview_damage",0))>0 and c["airborne"].has(b.enemy().uid):
        c["airborne"].erase(b.enemy().uid)
        if b.opening().has("effects_v4"):
            b.opening()["effects_v4"]["charge"]=0
            b.opening()["effects_v4"]["air_cancel"]=true
        b._record("field","착지 기술 · 뛰어오르기 중단")
    if id==364: c["guards"].erase(b.enemy().uid)
    if id==280 and int(original.get("preview_damage",0))>0:
        c["screen"]=0
        b._record("field","깨뜨리다 · 빛의장막 해제")
    if id==432:
        c["rocks"]=false;c["screen"]=0;c["safeguard"]=0
        b._record("field","안개제거 · 스텔스록/빛의장막/신비의부적 해제")
    if id in [229,866] and int(original.get("preview_damage",0))>0:
        c["rocks"]=false;c["traps"].erase(actor.uid)
        b._record("field","회전 기술 · 스텔스록/구속 해제")
static func aimed_filter_view(b: TacticalBattle,original: Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    var guarded:=PlayerInteractionHooks.boss_protected(b,v)
    var sub: bool=BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0 and not PlayerMoveInteractions.flag(int(v.get("move_id",0)),9) and not PlayerMoveInteractions.flag(int(v.get("move_id",0)),14)
    if guarded:
        if v.get("category")=="technique" and PlayerMoveInteractions.flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):v["boss_contact_guard"]=BossBattleEffectsP3.read(b)["guards"].get(b.enemy().uid,"")
        v["boss_blocked"]=true
    for key: String in BossBattleEffectsP3.TARGET_EFFECTS:
        if guarded or sub or (BossBattleEffectsP3.read(b)["safeguard"]>0 and key in ["burn","poison","sleep","paralysis","confusion"]):v.erase(key)
    if (guarded or sub) and v.get("stat_target")=="enemy":v.erase("stat_changes")
    return v
static func aimed_on_card(b: TacticalBattle,original: Dictionary,actor: BattlePokemon) -> void:
    var c:=BossBattleEffectsP3.write(b)
    c["acted"][actor.uid]=b.turn
    c["card_attacker"]=actor.uid if original.get("category")=="technique" else 0
    if original.get("category")=="technique":
        var move_id:=int(original.get("move_id",0))
        var attack:bool=original.has("damage") or original.has("shield_attack")
        c["last_moves"][actor.uid]={"move":move_id,"target":b.enemy().uid,"turn":b.turn,"attack":attack}
        if attack and PlayerMoveInteractions.flag(move_id,7):c["mirror"][b.enemy().uid]={"source":actor.uid,"move":move_id}
    var id:=int(original.get("move_id",0))
    if PlayerInteractionHooks.boss_protected(b,original):
        b._record("cancel","상대의 방어 · 대상 효과 차단")
        return
    if id in [479,614] and int(original.get("preview_damage",0))>0 and c["airborne"].has(b.enemy().uid):
        c["airborne"].erase(b.enemy().uid)
        if b.opening().has("effects_v4"):
            b.opening()["effects_v4"]["charge"]=0
            b.opening()["effects_v4"]["air_cancel"]=true
        b._record("field","착지 기술 · 뛰어오르기 중단")
    if id==364: c["guards"].erase(b.enemy().uid)
    if id==280 and int(original.get("preview_damage",0))>0:
        c["screen"]=0
        b._record("field","깨뜨리다 · 빛의장막 해제")
    if id==432:
        c["rocks"]=false;c["screen"]=0;c["safeguard"]=0
        b._record("field","안개제거 · 스텔스록/빛의장막/신비의부적 해제")
    if id in [229,866] and int(original.get("preview_damage",0))>0:
        c["rocks"]=false;c["traps"].erase(actor.uid)
        b._record("field","회전 기술 · 스텔스록/구속 해제")
static func aimed_player_damage(b: TacticalBattle,view: Dictionary,amount: int) -> int:
    if not BossBattleEffectsP3.active_in(b): return amount
    if PlayerInteractionHooks.boss_protected(b,view): return 0
    var target:=b.enemy()
    if BossBattleEffectsP3.read(b)["airborne"].get(target.uid,false) and int(view.get("move_id",0)) in [16,239] and amount>0:amount*=2
    if BossBattleEffectsP3.read(b)["vulnerable"].get(target.uid,false) and view.has("damage") and amount>0:amount*=2
    var actor:=b.member(int(view.get("owner_uid",0)))
    # card_view supplies the exact owner; shared cards never trigger attraction.
    if actor!=null and BossBattleEffectsP3.read(b)["infatuation"].get(actor.uid,{}).get("source",0)==target.uid and amount>0:amount=maxi(1,amount/2)
    if BossBattleEffectsP3.read(b)["screen"]>0 and view.get("damage_class")=="special" and int(view.get("move_id",0))!=280 and amount>0: return maxi(1,amount/2)
    return amount
static func aimed_card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    var notes: Array[String]=[]
    if PlayerInteractionHooks.boss_protected(b,v):notes.append("상대 방어로 대상 효과 차단")
    if BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0:notes.append("대타출동 유지 · 대타를 깬 타격의 초과 피해 없음")
    if BossBattleEffectsP3.read(b)["safeguard"]>0:notes.append("신비의부적 · 상태 부여 차단")
    if actor!=b.active() and BossBattleEffectsP3.read(b)["rocks"]:notes.append("교대 시 스텔스록 HP -%d" % BossBattleEffectsP3.entry_damage(b,actor))
    if int(v.get("move_id",0)) in [229,432,866,280]:notes.append("설치/장막 해제 효과 지원")
    var why:=PlayerInteractionHooks.boss_card_reason(b,v,actor)
    if not why.is_empty():notes.append(why)
    if BossBattleEffectsP3.read(b)["infatuation"].has(actor.uid):notes.append("헤롱헤롱 · 시전자 대상 기술 피해 절반 · 교대로 해제")
    if BossBattleEffectsP3.trapped(b):notes.append("교체 봉쇄 · 현재 동료 기술/도구는 사용 가능")
    return "\n".join(notes)
static func bulk_after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,foe_stages:Dictionary) -> void:
    var c:=PlayerMoveBulk.write(b);PlayerMoveBulk.simple_delta(b,foe,foe_stages)
    if c["silk"].get(p.uid,0)==b.turn and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(a)) and not a.get("powdered",false) and not a.has("bulk_cancel") and PlayerMoveInteractions.flag(PlayerMoveInteractions.move_id(a),1) and not a.get("asleep",false) and not a.get("player_sealed",false) and foe.alive():foe.stat_stages["speed"]=maxi(-6,int(foe.stat_stages.get("speed",0))-1)
    if foe.alive() and c["fire"]>=b.turn and "fire" not in PlayerMoveCards.effective_types(b,foe):b._damage(foe,maxi(1,foe.max_hp/8),true)
    if foe.alive() and c["salt"].has(foe.uid):b._damage(foe,maxi(1,foe.max_hp/(4 if PlayerMoveCards.effective_types(b,foe).any(func(t:String):return t in ["water","steel"]) else 8)),true)
    if foe.alive() and c["syrup"].get(foe.uid,{}).get("until",0)>=b.turn:foe.stat_stages["speed"]=maxi(-6,int(foe.stat_stages.get("speed",0))-1)
    for pending:Dictionary in c["future"].duplicate(true):
        if pending["due"]>b.turn:continue
        c["future"].erase(pending)
        var owner:=b.member(int(pending["source"]));var delayed_target:=b.enemy()
        if owner==null or not delayed_target.alive():continue
        var view:=PlayerMoveBulk.definition(TacticalMoves.key_for(int(pending["move"])));view["move_power"]=pending["power"];view["type"]=pending["type"];view["damage"]=1
        if not PlayerMoveExchange.blocked(b,view):b._damage(delayed_target,PlayerTechniques.raw_damage(b,owner,delayed_target,view,0),false,str(view["damage_class"]))
    for member:BattlePokemon in [p,foe]:
        if c["insomnia"].get(member.uid,0)>=b.turn or c["uproar"]>=b.turn:member.statuses.erase("sleep")
    c["reflect"]={};c["snatch"]={};PlayerMoveBulk.sync_berries(b)
    for key:String in ["insomnia","simple","silk"]:
        for uid:int in c[key].keys():
            if c[key][uid]<=b.turn:c[key].erase(uid)
    for uid:int in c["syrup"].keys():
        if c["syrup"][uid]["until"]<=b.turn:c["syrup"].erase(uid)
