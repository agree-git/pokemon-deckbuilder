class_name PlayerMoveExchange
extends RefCounted
## Route v12 only. Canonical Pokemon fields are restored at save/switch/end boundaries.
const PATH:="res://data/player_move_exchange_v12.json"
const STATS:Array[String]=["attack","defense","special_attack","special_defense","speed"]
const DEFAULT:Dictionary={"types":{},"stats":{},"roost":{},"last":{},"last_any":{},"calls":{},"copies":{}}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.exchange_context if not b.exchange_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.exchange_context.is_empty():b.exchange_context=DEFAULT.duplicate(true)
    return b.exchange_context
static func member(b:TacticalBattle,uid:int) -> BattlePokemon:
    for p:BattlePokemon in b.party+b.enemies:
        if p.uid==uid:return p
    return null
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveTactics.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=4;v["description"]=TacticalContent.description(v)
    return v
static func eligible(id:int) -> bool:
    var v:=definition(TacticalMoves.key_for(id))
    return v.has("damage") and not v.has("charge") and not v.has("recharge") and not v.get("self_ko",false) and not v.has("copy_mode") and v.get("special","") not in ["counter","mirror_coat","metal_burst","ohko","final_gambit"]
static func choice(b:TacticalBattle,p:BattlePokemon,mode:String) -> int:
    var c:=read(b);var id:=0
    match mode:
        "mimic","mirror-move":id=int(c["last"].get(b.enemy().uid,{}).get("move",0))
        "copycat":id=int(c["last_any"].get("move",0))
        "instruct":id=int(c["last"].get(p.uid,{}).get("move",0))
        "sketch":id=int(c["copies"].get(p.uid,c["last"].get(b.enemy().uid,{}).get("move",0)))
        "me-first":
            var a:=b.intent();id=int(a.get("effective_move",a["move_id"]))
            if a.get("damage_class","status")=="status" or a["kind"] in ["prepare","recharge","wait","guard"]:return 0
        "metronome":id=int(data()["pool"][(absi(b.seed_value)+absi(p.uid)*17+int(c["calls"].get(p.uid,0))*7)%data()["pool"].size()])
        "nature-power":id=int(data()["nature"][BattleWeather.kind(b.powers)])
        "assist":
            for ally:BattlePokemon in b.party:
                if ally==p or not ally.alive():continue
                for key:String in ally.learned_skills:
                    var move:=int(TacticalMoves.definition(key).get("move_id",0))
                    if eligible(move):return move
    if mode=="mirror-move" and not PlayerMoveCards.flag(id,7):return 0
    return id if eligible(id) else 0
static func expand(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    if not original.has("copy_mode"):return original
    var mode:String=original["copy_mode"];var id:=choice(b,p,mode)
    if id==0:
        var missing:=original.duplicate(true);missing["copy_failed"]=true
        return missing
    var card:=BattleCardInstance.new(int(original["uid"]),TacticalMoves.key_for(id),p.uid)
    var v:=TacticalContent.definition(card,4)
    for field:String in ["uid","key","owner_uid","owner_name","species_id","switches","retained","cost"]:
        if original.has(field):v[field]=original[field]
    v["name"]=str(original["name"])+" → "+str(v["name"])
    v["copy_mode"]=mode;v["copy_move"]=id
    v["copy_source"]=int(original["move_id"])
    if mode=="me-first":v["copy_boost"]=true
    if original.get("exhaust",false):v["exhaust"]=true
    v["card_notes"].append_array(original["card_notes"])
    v["card_notes"].append("이번 호출: "+str(TacticalMoves.visual(id)["name"]))
    return v
static func blocked(b:TacticalBattle,v:Dictionary) -> bool:
    if not BossBattleRules.active_in(b):return false
    var proxy:=v.duplicate(true);proxy["pulse_status"]=true
    if BossBattleEffectsP3.protected(b,proxy) if BossBattleRules.modern(b) else BossBattleEffects.protected(b,proxy):return true
    if BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy):return true
    return BossBattleRules.read(b)["substitutes"].get(b.enemy().uid,0)>0 and not PlayerMoveCards.flag(int(v["move_id"]),9) and not PlayerMoveCards.flag(int(v["move_id"]),14)
static func resistance(b:TacticalBattle,p:BattlePokemon) -> String:
    var last:Dictionary=read(b)["last"].get(b.enemy().uid,{})
    if last.is_empty() or int(last["move"])==165 or TacticalMoves.visual(int(last["move"])).get("category",1)==1:return ""
    for t:String in data()["type_order"]:
        var one:Array[String]=[t]
        if t not in PlayerMoveCards.effective_types(b,p) and TypeMatchup.multiplier(str(last["type"]),one)<1:return t
    return ""
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    var tag:String=v.get("exchange","")
    if tag.is_empty() or tag=="copy":return v
    var target:=b.enemy()
    if tag in ["power_swap","guard_swap","heart_swap","psych_up","invert","steal","power_split","guard_split","speed_swap","water","psychic","ghost","grass","reflect_type","shift"]:
        v["exchange_blocked"]=blocked(b,v)
        if tag=="psychic" and "grass" in PlayerMoveCards.effective_types(b,target):v["exchange_blocked"]=true
        if tag=="shift" and BossBattleRules.active_in(b) and BossBattleRules.read(b)["safeguard"]>0:v["exchange_blocked"]=true
        if v["exchange_blocked"]:v["card_notes"].append("대상 효과가 보호/대타/공중/면역으로 막힘")
    if tag=="steal" and not v.get("exchange_blocked",false):
        var stolen:Dictionary={}
        for stat:String in STATS:
            if int(target.stat_stages.get(stat,0))>0:stolen[stat]=int(target.stat_stages[stat])
        v["steal_stages"]=stolen
    if tag=="conversion2":v["new_type"]=resistance(b,p)
    if tag=="burn_up" and "fire" not in PlayerMoveCards.effective_types(b,p):v["failed"]=true
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("copy_failed",false):return "복사/호출 가능한 공격 기록이나 동료 기술이 없습니다."
    if v.get("exchange")=="conversion2" and str(v.get("new_type","")).is_empty():return "상대의 직전 공격과 바꿀 반감 타입이 필요합니다."
    if v.get("exchange")=="burn_up" and "fire" not in PlayerMoveCards.effective_types(b,p):return "불사르기는 불꽃 타입일 때 사용할 수 있습니다."
    if v.get("exchange")=="shift":
        if main_status(p).is_empty():return "옮길 자신의 주 상태이상이 없습니다."
        if not main_status(b.enemy()).is_empty():return "상대에게 이미 주 상태이상이 있습니다."
        if immune(b,main_status(p),b.enemy()):return "상대 타입이 이 상태이상을 막습니다."
    return ""
static func main_status(p:BattlePokemon) -> String:
    for key:String in ["burn","poison","sleep","paralysis"]:
        if p.statuses.has(key):return key
    return ""
static func immune(b:TacticalBattle,status:String,p:BattlePokemon) -> bool:
    var types:=PlayerMoveCards.effective_types(b,p)
    return (status=="burn" and "fire" in types) or (status=="poison" and ("poison" in types or "steel" in types)) or (status=="paralysis" and "electric" in types)
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("exchange")=="steal" and not v.get("exchange_blocked",false) and not v.get("boss_blocked",false) and b.multiplier(str(v["type"]),target)>0:
        for stat:String in v.get("steal_stages",{}):
            p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+int(v["steal_stages"][stat]));target.stat_stages[stat]=0
        v["steal_applied"]=true
static func base_stat(p:BattlePokemon,stat:String) -> int:return int(p.battle_stats.get(stat,PokemonStats.value(p.species_id,p.level,stat)))
static func set_stat(b:TacticalBattle,p:BattlePokemon,stat:String,n:int) -> void:
    var c:=write(b)
    if not c["stats"].has(p.uid):c["stats"][p.uid]={}
    c["stats"][p.uid][stat]=n;p.battle_stats[stat]=n
static func ensure_type(b:TacticalBattle,p:BattlePokemon) -> Dictionary:
    var c:=write(b)
    if not c["types"].has(p.uid):c["types"][p.uid]={"base":p.types.duplicate(),"primary":p.type,"core":p.types.duplicate(),"added":""}
    return c["types"][p.uid]
static func apply_type(b:TacticalBattle,p:BattlePokemon) -> void:
    var c:=read(b)
    if not c["types"].has(p.uid):return
    var state:Dictionary=c["types"][p.uid];var types:Array=state["core"].duplicate()
    if not state["added"].is_empty() and state["added"] not in types:
        types=types.slice(0,2);types.append(state["added"])
    if c["roost"].get(p.uid,0)==b.turn:types.erase("flying")
    if PlayerMoveRules.read(b)["spent_electric"].get(p.uid,false) or b.boss_context.get("spent_electric",{}).get(p.uid,false):types.erase("electric")
    p.types.assign(types);p.type=p.types[0] if not p.types.is_empty() else "normal"
static func set_type(b:TacticalBattle,p:BattlePokemon,types:Array) -> void:
    var state:=ensure_type(b,p);state["core"]=types.duplicate();state["added"]=""
    PlayerMoveRules.write(b)["spent_electric"].erase(p.uid)
    if b.boss_context.has("spent_electric"):b.boss_context["spent_electric"].erase(p.uid)
    apply_type(b,p)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var c:=write(b);var tag:String=v.get("exchange","")
    var affected:bool=not v.get("exchange_blocked",false) and not v.get("boss_blocked",false) and not v.get("failed",false) and target.alive()
    match tag:
        "power_swap","guard_swap","heart_swap":
            if affected:
                var selected:Array=["attack","special_attack"] if tag=="power_swap" else (["defense","special_defense"] if tag=="guard_swap" else STATS)
                for stat:String in selected:
                    var own:=int(p.stat_stages.get(stat,0));p.stat_stages[stat]=int(target.stat_stages.get(stat,0));target.stat_stages[stat]=own
        "psych_up":
            if affected:p.stat_stages=target.stat_stages.duplicate()
        "invert":
            if affected:
                for stat:String in target.stat_stages:target.stat_stages[stat]=-int(target.stat_stages[stat])
        "power_trick":
            var a:=base_stat(p,"attack");set_stat(b,p,"attack",base_stat(p,"defense"));set_stat(b,p,"defense",a)
        "power_split","guard_split","speed_swap":
            if affected:
                var selected:Array=["attack","special_attack"] if tag=="power_split" else (["defense","special_defense"] if tag=="guard_split" else ["speed"])
                for stat:String in selected:
                    var a:=base_stat(p,stat);var other:=base_stat(target,stat)
                    set_stat(b,p,stat,other if tag=="speed_swap" else (a+other)/2);set_stat(b,target,stat,a if tag=="speed_swap" else (a+other)/2)
        "water","psychic":
            if affected:set_type(b,target,["water" if tag=="water" else "psychic"])
        "ghost","grass":
            if affected:ensure_type(b,target)["added"]=tag;apply_type(b,target)
        "reflect_type":
            if affected:set_type(b,p,PlayerMoveCards.effective_types(b,target))
        "conversion":
            var key:String=p.learned_skills[0] if not p.learned_skills.is_empty() else "move_165"
            var raw:=TacticalMoves.definition(key);set_type(b,p,[PokedexExpansion.move_type(p.species_id,int(raw["move_id"]),str(raw["type"]))])
        "conversion2":set_type(b,p,[v["new_type"]])
        "camouflage":set_type(b,p,[{"rain":"water","sun":"fire","snow":"ice","sand":"rock","":"normal"}[BattleWeather.kind(b.powers)]])
        "roost":
            if p.alive():ensure_type(b,p);c["roost"][p.uid]=b.turn;apply_type(b,p)
        "burn_up":
            if not v.get("failed",false) and not v.get("boss_blocked",false) and b.multiplier(str(v["type"]),target)>0:
                var types:=PlayerMoveCards.effective_types(b,p);types.erase("fire");set_type(b,p,types)
        "shift":
            if affected and not main_status(p).is_empty():
                var status:=main_status(p);target.statuses[status]=p.statuses[status].duplicate(true);target.statuses[status]["source_uid"]=p.uid;p.statuses.erase(status)
    if v.has("copy_mode"):
        if v["copy_mode"]=="metronome":c["calls"][p.uid]=int(c["calls"].get(p.uid,0))+1
        if v["copy_mode"]=="sketch":c["copies"][p.uid]=int(v["copy_move"])
    remember(b,p,int(v["move_id"]),str(v["type"]))
    if not tag.is_empty():b._record("field",str(v["name"])+(" · 대상 효과 차단" if not affected else " · 기술 특징 적용"))
static func remember(b:TacticalBattle,p:BattlePokemon,id:int,type_name:String) -> void:
    var c:=write(b);c["last"][p.uid]={"move":id,"type":type_name};c["last_any"]={"uid":p.uid,"move":id,"type":type_name}
static func after_enemy(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> void:
    if not a.get("player_sealed",false) and not a.get("asleep",false) and not a.get("failed_move",false) and not a.get("failed_charge",false):remember(b,p,int(a.get("effective_move",a["move_id"])),str(a.get("type","normal")))
    for actor:BattlePokemon in b.party+b.enemies:apply_type(b,actor)
static func on_switch(b:TacticalBattle,old:int) -> void:
    var c:=write(b);var p:=member(b,old)
    if c["types"].has(old) and p!=null:p.types.assign(c["types"][old]["base"]);p.type=c["types"][old]["primary"]
    if p!=null:p.battle_stats.clear()
    c["types"].erase(old);c["stats"].erase(old);c["roost"].erase(old)
static func start_player(b:TacticalBattle) -> void:
    var c:=write(b)
    for uid:int in c["roost"].keys():
        if c["roost"][uid]<b.turn:c["roost"].erase(uid);apply_type(b,member(b,uid))
static func clear(b:TacticalBattle) -> void:
    for p:BattlePokemon in b.party+b.enemies:
        var s:Dictionary=read(b)["types"].get(p.uid,{})
        if not s.is_empty():p.types.assign(s["base"]);p.type=s["primary"]
        p.battle_stats.clear()
    b.exchange_context.clear()
static func canonical(b:TacticalBattle,p:BattlePokemon,row:Dictionary) -> void:
    var state:Dictionary=read(b)["types"].get(p.uid,{})
    if not state.is_empty():row["types"]=state["base"].duplicate();row["type"]=state["primary"]
static func reapply(b:TacticalBattle) -> void:
    for p:BattlePokemon in b.party+b.enemies:
        # Snapshot restoration shares the canonical array until detached. Combat
        # type changes must never rewrite the input snapshot's species types.
        p.types=p.types.duplicate()
        p.battle_stats=read(b)["stats"].get(p.uid,{}).duplicate();apply_type(b,p)
static func clone(p:BattlePokemon) -> BattlePokemon:
    var copy:=PlayerMoveCards.clone(p);copy.battle_stats=p.battle_stats.duplicate()
    return copy

static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if v.get("failed",false):return 0
    if not v.get("steal_applied",false) and not v.get("steal_stages",{}).is_empty():
        p=clone(p);target=clone(target)
        for stat:String in v["steal_stages"]:
            p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+int(v["steal_stages"][stat]));target.stat_stages[stat]=0
    var id:=int(v["move_id"]);var affinity:=1.0 if id==165 else b.multiplier(str(v["type"]),target)
    if affinity<=0:return 0
    var fixed:=-1;var hit:=PlayerMoveRules.received(b,p.uid)
    match str(v.get("special",v.get("variable",""))):
        "level","psywave":fixed=p.level
        "forty":fixed=40
        "twenty":fixed=20
        "half":fixed=maxi(1,target.hp/2)
        "endeavor":fixed=maxi(0,target.hp-p.hp)
        "final_gambit":fixed=p.hp
        "counter":fixed=2*int(hit["damage"]) if hit["kind"]=="physical" else 0
        "mirror_coat":fixed=2*int(hit["damage"]) if hit["kind"]=="special" else 0
        "metal_burst":fixed=floori(int(hit["damage"])*1.5)
    if fixed>=0:return floori(fixed*(1.5 if v.get("copy_boost",false) else 1.0))
    var attacker:=p;var defender:=target;var pressure:=1.5 if v.get("copy_boost",false) else 1.0
    if PlayerMoveRules.read(b)["spent_electric"].get(p.uid,false):attacker=clone(attacker);attacker.types.erase("electric")
    if v.has("immediate_boost") and not v.get("boost_applied",false):
        attacker=clone(attacker)
        for stat:String in v["immediate_boost"]:attacker.stat_stages[stat]=clampi(int(attacker.stat_stages.get(stat,0))+int(v["immediate_boost"][stat]),-6,6)
    if id==263 and attacker.statuses.has("burn"):attacker=clone(attacker);attacker.statuses.erase("burn")
    if v.get("ignore_defense",false):defender=clone(defender);defender.stat_stages.erase("defense");defender.stat_stages.erase("special_defense")
    if v.get("critical",false):
        attacker=clone(attacker);defender=clone(defender)
        var stat:String="special_attack" if v["damage_class"]=="special" else "attack"
        var defense:String="special_defense" if v["damage_class"]=="special" else "defense"
        if int(attacker.stat_stages.get(stat,0))<0:attacker.stat_stages.erase(stat)
        if int(defender.stat_stages.get(defense,0))>0:defender.stat_stages.erase(defense)
        pressure*=1.5
    elif v.get("high_crit",false):pressure*=1.15
    if id==876 and BattleWeather.kind(b.powers)=="sun":pressure*=3 # cancel the usual water-in-sun half, then boost1.5
    var offense:String="defense" if v.get("variable")=="body_press" else ""
    var override:=PokemonStats.effective(target,"attack") if v.get("variable")=="foul" else 0
    return PokemonStats.damage(attacker,defender,v,affinity,bonus,pressure,BattleWeather.kind(b.powers),offense,override)
static func enemy_math(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if not BossBattleRules.modern(b) or (p.battle_stats.is_empty() and b.enemy().battle_stats.is_empty()):return source
    if not source.has("per_hit") or source.get("asleep",false) or source.get("failed_move",false) or source.get("immune",false) or source.has("fixed_damage") or source["kind"] in ["prepare","recharge","wait","guard"]:return source
    var a:=source.duplicate(true);var id:=int(a.get("effective_move",a["move_id"]))
    var m:Dictionary=a.get("copied_view",BossMoveEffectsP3.view(id)).duplicate(true)
    if not m.has("move_power"):return source
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["damage_class"]=a["damage_class"]
    if id==76 and BattleWeather.kind(b.powers) in ["rain","snow","sand"]:m["move_power"]=int(m["move_power"])/2
    var actor:=clone(b.enemy());var target:=clone(p);var pressure:=1.0
    if a.has("charge_boost"):actor.stat_stages["special_attack"]=int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
    if id==263:actor.statuses.erase("burn")
    if m.has("ignore_defense"):target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    if m.get("unique")=="critical":
        if int(actor.stat_stages.get("attack",0))<0:actor.stat_stages.erase("attack")
        if int(target.stat_stages.get("defense",0))>0:target.stat_stages.erase("defense")
        pressure=1.5
    if b.boss_context.get("spent_electric",{}).get(actor.uid,false):actor.types.erase("electric")
    a["per_hit"]=PokemonStats.damage(actor,target,m,b.multiplier(str(m["type"]),target),0,pressure,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
    a["value"]=int(a["per_hit"])*int(a.get("hits",1))
    for i:int in a.get("effects",[]).size():
        if "대상 기절 시 남은 타격 중단" in str(a["effects"][i]):a["effects"][i]="%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)]
    return a
static func valid_context(c:Variant,b:Dictionary,ps:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.get(key) is Dictionary:return false
    var ids:Array=b["party"]+b["enemies"]
    for key:String in ["types","stats","roost","last","calls","copies"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in (b["party"] if key in ["roost","calls","copies"] else ids):return false
            var v:Variant=c[key][uid]
            match key:
                "types":
                    if not v is Dictionary or v.size()!=4 or v.get("base")!=ps[uid]["types"] or v.get("primary")!=ps[uid]["type"] or not v.get("core") is Array or v["core"].size()>3 or not v.get("added") is String:return false
                    var seen:Array=[]
                    for type_name:Variant in v["core"]:
                        if type_name not in data()["type_order"] or type_name in seen:return false
                        seen.append(type_name)
                    if not v["added"].is_empty() and v["added"] not in data()["type_order"]:return false
                "stats":
                    if not v is Dictionary or v.is_empty() or v.size()>5:return false
                    for stat:Variant in v:
                        if stat not in STATS or not v[stat] is int or v[stat]<1 or v[stat]>100000:return false
                "last":
                    if not v is Dictionary or v.size()!=2 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or v.get("type") not in data()["type_order"]:return false
                "roost":
                    if not v is int or v!=b["turn"] or not c["types"].has(uid):return false
                "calls":
                    if not v is int or v<1 or v>1000000000:return false
                "copies":
                    if not v is int or not eligible(v):return false
    var last:Dictionary=c["last_any"]
    if not last.is_empty() and (last.size()!=3 or not last.get("uid") is int or last["uid"] not in ids or not last.get("move") is int or TacticalMoves.visual(last["move"]).is_empty() or last.get("type") not in data()["type_order"]):return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:Array[String]=PlayerTechniques.legacy_lines(v)
    if v.has("copy_mode"):
        rows.push_front("공격 호출 · 추가 카드 없음" if not v.get("copy_failed",false) else "호출할 공격 없음")
        if v.get("copy_boost",false):rows.insert(1,"선취 · 피해 ×1.5")
    elif v.has("exchange"):
        var title:String={"power_swap":"공격·특공 단계 교환","guard_swap":"방어·특방 단계 교환","heart_swap":"모든 능력 단계 교환","psych_up":"상대 능력 단계 복사","invert":"상대 능력 단계 반전","steal":"양수 단계 훔친 뒤 공격","power_trick":"자신 공격·방어 교환","power_split":"양쪽 공격·특공 평균","guard_split":"양쪽 방어·특방 평균","speed_swap":"스피드 능력치 교환","water":"상대 물 타입으로","psychic":"상대 에스퍼 타입으로","ghost":"상대 고스트 타입 추가","grass":"상대 풀 타입 추가","reflect_type":"상대 타입을 복사","conversion":"첫 기술 타입으로","conversion2":"직전 공격 반감 타입으로","camouflage":"날씨에 맞는 타입으로","roost":"이번 턴 비행 타입 제거","burn_up":"공격 후 불꽃 타입 소모","shift":"자신 상태를 상대로"}.get(v["exchange"],"")
        rows.push_front(title)
    if rows.has("상세 규칙은 툴팁"):rows.erase("상세 규칙은 툴팁")
    return rows.slice(0,5)
