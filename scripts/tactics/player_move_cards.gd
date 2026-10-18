class_name PlayerMoveCards
extends RefCounted
## Player-only card definitions for route v10. TacticalMoves remains frozen for old saves.
const PATH := "res://data/player_move_cards_v10.json"
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():
        _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        for key:String in _data["flags"]:_data["flags"][key]=_data["flags"][key].map(func(v:Variant):return int(v))
    return _data
static func active(b:TacticalBattle) -> bool:return b.player_moves_version==2
static func definition(key:String) -> Dictionary:
    var legacy:=TacticalMoves.definition(key)
    if legacy.is_empty():return {}
    var v:Dictionary=data()["moves"].get(str(int(legacy["move_id"])),{}).duplicate(true)
    v["move_id"]=int(v["move_id"]);v["player_rules"]=2
    if v.has("stat_changes"):
        for stat:String in v["stat_changes"]:v["stat_changes"][stat]=int(v["stat_changes"][stat])
    v["description"]=TacticalContent.description(v)
    return v
static func flag(id:int,n:int) -> bool:return n in data()["flags"].get(str(id),[])
static func clone(p:BattlePokemon) -> BattlePokemon:
    var copy:=BattlePokemon.new({"id":p.species_id,"name":p.display_name,"types":p.types,"type":p.type,"max_hp":p.max_hp,"level":p.level},p.uid)
    copy.species_stats=p.species_stats;copy.strength=p.strength;copy.stat_stages=p.stat_stages.duplicate();copy.statuses=p.statuses.duplicate(true)
    return copy
static func called(p:BattlePokemon) -> String:
    for key:String in p.learned_skills:
        var m:=definition(key)
        if m.has("damage") and not m.has("charge") and not m.has("recharge") and m.get("special","") not in ["sleep_talk","final_gambit"] and not m.get("self_ko",false):return key
    return ""
static func prepare(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    if v.get("category")!="technique":return v
    var c:=PlayerMoveRules.read(b);var target:=b.enemy();var id:=int(v["move_id"])
    if v.get("special")=="sleep_talk" and p.statuses.has("sleep") and not called(p).is_empty():
        var card:=BattleCardInstance.new(int(v["uid"]),called(p),p.uid)
        card.upgraded=b._hand(int(v["uid"])).upgraded if b._hand(int(v["uid"]))!=null else false
        var copy:=TacticalContent.definition(card,2)
        copy["key"]=v["key"];copy["name"]="잠꼬대 → "+str(copy["name"]);copy["sleep_call"]=true
        v=copy;id=int(v["move_id"])
        v["card_notes"].append("수면 중 자신의 첫 사용 가능한 공격 기술을 호출 · 별도 카드/추첨 없음")
    if v.has("charge"):
        var charge:Dictionary=c["charges"].get(p.uid,{})
        var instant:bool=str(v["charge"]) in ["sun","rain"] and BattleWeather.kind(b.powers)==v["charge"]
        var ready:bool=charge.get("move",0)==id and charge.get("card",0)==v["uid"] and b.turn>=charge.get("ready",0)
        if ready:v["cost"]=0;v["released"]=true
        elif not instant:
            v["preparing"]=true
            for f:String in ["damage","heal","stat_changes","stat_target","burn","poison","sleep","paralysis","confusion","pressure_down"]:v.erase(f)
        if v.has("charge_boost") and not v.get("preparing",false):
            v.erase("stat_changes")
            if instant:v["immediate_boost"]=v["charge_boost"].duplicate()
        if instant:v["card_notes"].append("현재 날씨로 충전 없이 즉시 공격")
    if v.has("weather_heal"):
        var weather:=BattleWeather.kind(b.powers)
        var points:=32 if (id==659 and weather=="sand") or (id!=659 and weather=="sun") else (12 if id!=659 and not weather.is_empty() else 24)
        v["heal"]=points+(4 if b._hand(int(v["uid"]))!=null and b._hand(int(v["uid"])).upgraded else 0)
    if v.get("special")=="swallow":v["heal"]={0:0,1:12,2:24,3:48}[int(c["stocks"].get(p.uid,0))]
    if v.get("special")=="spit_up":v["move_power"]=100*int(c["stocks"].get(p.uid,0))
    if v.get("special")=="knock" and not target.held_item.is_empty():v["move_power"]=floori(int(v["move_power"])*1.5)
    if v.has("damage"):
        v=_variable(b,p,target,v)
        if id==76 and BattleWeather.kind(b.powers) in ["rain","sand","snow"]:v["move_power"]=maxi(1,int(v["move_power"])/2)
        if v.get("party_hits",false):v["hit_weights"]=[];v["hit_weights"].resize(b.party.filter(func(a:BattlePokemon):return a.alive()).size());v["hit_weights"].fill(1)
        if v.has("chain"):
            var last:Dictionary=c["last"].get(p.uid,{})
            var count:int=mini(3,int(last.get("count",0))+1) if last.get("move",0)==id and last.get("turn",0)>=b.turn-1 else 1
            v["chain_count"]=count
            v["move_power"]=mini(200,40*count) if id==497 else int(v["move_power"])*int(pow(2,count-1))
        if c["focus"].get(p.uid,false):v["critical"]=true
        if v.get("special")=="ohko":
            if p.level<target.level or (id==329 and "ice" in target.types):v["failed"]=true
        if v.get("special")=="hammer" and c["last"].get(p.uid,{}).get("move",0)==id and not c["last"].get(p.uid,{}).get("failed",false):v["failed"]=true
        if v.get("special")=="double_shock" and "electric" not in effective_types(b,p):v["failed"]=true
        if v.get("special")=="fake_out" and c["acted"].get(p.uid,0)>0:v["failed"]=true
        if v.get("special")=="dream" and not target.statuses.has("sleep"):v["failed"]=true
        if v.get("special") in ["counter","mirror_coat","metal_burst"]:
            var received:=PlayerMoveRules.received(b,p.uid)
            if received["damage"]==0 or (v["special"]=="counter" and received["kind"]!="physical") or (v["special"]=="mirror_coat" and received["kind"]!="special"):v["failed"]=true
        if v.get("special")=="sucker" and PlayerMoveRules.received(b,p.uid).get("damage",0)==0:v["failed"]=true
    if v.get("special") in ["attract","yawn","tar","seal","purify"] and BossBattleRules.active_in(b):
        var proxy:=v.duplicate(true);proxy["pulse_status"]=true
        var blocked:bool=BossBattleEffectsP3.protected(b,proxy) if BossBattleRules.modern(b) else BossBattleEffects.protected(b,proxy)
        if BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy):blocked=true
        if v.get("special")=="yawn" and BossBattleRules.read(b)["safeguard"]>0:blocked=true
        if blocked:
            v["boss_blocked"]=true;v["card_notes"].append("상대의 보호 기술로 대상 효과 차단")
            if v.get("special")=="purify":v.erase("heal")
        if v.get("special")=="purify" and BossBattleRules.read(b)["substitutes"].get(target.uid,0)>0:
            v.erase("heal");v["card_notes"].append("상대 대타가 정화를 막아 회복 불가")
    # Type-specific status immunities; guaranteed card effects still respect these.
    var target_types:=effective_types(b,target)
    for status:String in ["burn","poison","paralysis","seed"]:
        if (status=="burn" and "fire" in target_types) or (status=="poison" and target_types.any(func(t:String):return t in ["poison","steel"])) or (status=="paralysis" and "electric" in target_types) or (status=="seed" and "grass" in target_types):
            if v.has(status):v.erase(status);v["card_notes"].append("상대 타입이 해당 상태를 막음")
    if v.has("damage") and b.multiplier(str(v["type"]),target)<=0:
        for status:String in ["burn","poison","sleep","paralysis","confusion","seed"]:v.erase(status)
        v.erase("stat_changes")
        if v.has("crash"):v["crash_due"]=true
    return v
static func _variable(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,source:Dictionary) -> Dictionary:
    var v:=source.duplicate(true);var c:=PlayerMoveRules.read(b);var power:=int(v.get("move_power",0));var mode:String=v.get("variable","")
    var hit:=PlayerMoveRules.received(b,p.uid);var condition:=false
    match mode:
        "weight":
            var w:=int(data()["weights"][str(target.species_id)])
            power=20 if w<100 else (40 if w<250 else (60 if w<500 else (80 if w<1000 else (100 if w<2000 else 120))))
        "heavy":
            var w:=int(data()["weights"][str(target.species_id)]);var own:=int(data()["weights"][str(p.species_id)])
            power=120 if own>=w*5 else (100 if own>=w*4 else (80 if own>=w*3 else (60 if own>=w*2 else 40)))
        "gyro":power=clampi(25*PokemonStats.effective(target,"speed")/PokemonStats.effective(p,"speed")+1,1,150)
        "electro":
            var ratio:=PokemonStats.effective(p,"speed")/float(PokemonStats.effective(target,"speed"))
            power=150 if ratio>=4 else (120 if ratio>=3 else (80 if ratio>=2 else (60 if ratio>=1 else 40)))
        "flail":
            var hp:=48*p.hp/p.max_hp
            power=200 if hp<=1 else (150 if hp<=4 else (100 if hp<=9 else (80 if hp<=16 else (40 if hp<=32 else 20))))
        "eruption":power=maxi(1,150*p.hp/p.max_hp)
        "crush":power=maxi(1,120*target.hp/target.max_hp)
        "hard_press":power=maxi(1,100*target.hp/target.max_hp)
        "stored":
            power=20
            for stage:Variant in p.stat_stages.values():power+=20*maxi(0,int(stage))
        "punishment":
            power=60
            for stage:Variant in target.stat_stages.values():power+=20*maxi(0,int(stage))
            power=mini(200,power)
        "return","frustration":
            var friendship:=p.friendship if p.friendship>=0 else 70
            power=maxi(1,(friendship if mode=="return" else 255-friendship)*2/5)
        "facade":condition=["burn","poison","paralysis"].any(func(k:String):return p.statuses.has(k))
        "brine":condition=target.hp*2<=target.max_hp
        "hex":condition=["burn","poison","sleep","paralysis"].any(func(k:String):return target.statuses.has(k))
        "payback","avalanche":condition=int(hit.get("damage",0))>0
        "assurance":condition=c["hurt"].get(target.uid,0)==b.turn
        "retaliate":condition=c["last_ally_ko"]>0 and c["last_ally_ko"]>=b.turn-1
        "acrobatics":condition=p.held_item.is_empty()
        "focus":v["card_notes"].append("카드 전투에서는 직전 상대턴 HP 피해가 없을 때 위력1.5배");condition=int(hit.get("damage",0))==0
        "magnitude":power=70;v["card_notes"].append("매그니튜드7 고정 · 위력70 · 추첨 없음")
        "trump":power=200 if b.hand.size()<=1 else (80 if b.hand.size()<=2 else (60 if b.hand.size()<=3 else 40));v["card_notes"].append("PP 대신 남은 손패가 적을수록 위력 증가")
        "rage":power=mini(350,50+50*int(c["hits"].get(p.uid,0)))
        "fickle":power=160 if int(c["fickle"].get(p.uid,0)) in [2,5,9] else 80;v["card_notes"].append("공개10회 주기3/6/10번째 위력2배")
        "temper":condition=c["last"].get(p.uid,{}).get("failed",false)
        "higher":v["damage_class"]="physical" if PokemonStats.effective(p,"attack")>PokemonStats.effective(p,"special_attack") else "special"
        "shell":v["damage_class"]="physical" if PokemonStats.effective(p,"attack")*PokemonStats.effective(target,"special_defense")>PokemonStats.effective(p,"special_attack")*PokemonStats.effective(target,"defense") else "special"
        "weather":
            var weather:=BattleWeather.kind(b.powers)
            if not weather.is_empty():power*=2;v["type"]={"sun":"fire","rain":"water","snow":"ice","sand":"rock"}[weather]
        "jealousy":
            if target.stat_stages.values().any(func(s:Variant):return int(s)>0):v["burn"]=3
            else:v.erase("burn")
            v["card_notes"].append("상대에게 양수 능력 단계가 있으면 화상")
    if mode in ["facade","brine","hex","payback","avalanche","assurance","retaliate","acrobatics","temper"] and condition:power*=2
    if mode=="focus" and condition:power=roundi(power*1.5)
    if not mode.is_empty():v["card_notes"].append("현재 조건 위력%d" % power)
    v["move_power"]=power+int(v.get("power_upgrade",0))
    return v
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if v.get("failed",false):return 0
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
    if fixed>=0:return fixed
    var attacker:=p;var defender:=target;var pressure:=1.0
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
        pressure=1.5
    elif v.get("high_crit",false):pressure=1.15
    if id==876 and BattleWeather.kind(b.powers)=="sun":pressure*=3 # cancel the usual water-in-sun half, then boost1.5
    var offense:String="defense" if v.get("variable")=="body_press" else ""
    var override:=PokemonStats.effective(target,"attack") if v.get("variable")=="foul" else 0
    return PokemonStats.damage(attacker,defender,v,affinity,bonus,pressure,BattleWeather.kind(b.powers),offense,override)
static func damage_values(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> Array[int]:
    var values:Array[int]=[]
    for n in v.get("hit_weights",[1]).size():
        var copy:=v.duplicate(true);copy["move_power"]=int(v["move_power"])*int(v.get("hit_weights",[1])[n]);copy["omit_card_bonus"]=n>0
        values.append(b.attack_damage(copy,p))
    return values
static func after_preview(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> void:
    if not v.has("damage"):return
    var values:=damage_values(b,v,p);v["preview_damage"]=0
    var hp:=b.enemy().hp;var shield:=b.enemy().block;var sub:=0
    if BossBattleRules.active_in(b) and not flag(int(v["move_id"]),9) and not flag(int(v["move_id"]),14):sub=int(BossBattleRules.read(b)["substitutes"].get(b.enemy().uid,0))
    for amount:int in values:
        v["preview_damage"]+=amount
        var remaining:=maxi(0,amount-shield);shield=maxi(0,shield-amount)
        if sub>0:sub=maxi(0,sub-remaining)
        else:hp=maxi(0,hp-remaining)
        if hp==0:break
    v["preview_hp_loss"]=b.enemy().hp-hp
    if v.has("drain_percent"):
        var percent:=int(v["drain_percent"]);var amount:=PlayerMoveRules.ratio(int(v["preview_hp_loss"]),percent)
        if percent>0 and b.has_relic("shield_core"):amount=floori(amount*0.5)
        v["preview_drain"]=mini(p.max_hp-p.hp,amount) if percent>0 else mini(p.hp,amount)
static func lines(v:Dictionary) -> Array[String]:
    var rows:Array[String]=[]
    if v.get("preparing",false):return ["충전 · 피해 없음","다음 턴부터 비용0 발사","이 카드를 손패에 보존","교대하면 충전 취소"]
    if v.has("damage"):
        rows.append("피해 %d" % int(v["preview_damage"]) if v.has("preview_damage") else "위력 %d" % int(v["move_power"]))
        if v.has("hit_weights"):rows.append("%d회 연속 타격" % v["hit_weights"].size())
        if v.has("variable"):rows.append("조건에 따라 위력 변화")
        if v.get("special") in ["level","forty","twenty","psywave","half","counter","mirror_coat","metal_burst","final_gambit"] or v.get("variable")=="endeavor":rows[0]="고정 피해 "+str(v.get("preview_damage","· 상세 툴팁"))
    if v.has("drain_percent"):rows.append(("HP 흡수 " if v["drain_percent"]>0 else "자기 반동 ")+(str(v["preview_drain"]) if v.has("preview_drain") else str(absi(int(v["drain_percent"])))+"%"))
    if v.has("heal"):rows.append("HP 회복 "+str(v.get("preview_heal",PokemonStats.percent(int(v["heal"])))))
    if v.has("guard"):rows.append("HP1로 버팀" if v["guard"]=="endure" else "이번 상대 행동 방어")
    if v.has("recharge"):rows.append("다음 턴까지 기술 재충전")
    if v.get("critical",false):rows.append("확정 급소 ×1.5")
    if v.has("block"):rows.append("보호막 "+str(v.get("preview_block",PokemonStats.percent(int(v["block"])))))
    if v.has("stat_changes"):rows.append(("자신" if v["stat_target"]=="self" else "상대")+" 능력 단계 변경")
    for status:String in ["burn","poison","sleep","paralysis","confusion","seed"]:
        if v.has(status):rows.append(BossMoveEffects.STATUS_NAMES.get(status,"씨뿌리기")+" %d회" % int(v[status]))
    if v.has("special"):
        var title:String={"substitute":"HP¼로 대타 생성","yawn":"다음 행동 뒤 수면","rest":"두 아군턴 수면","sleep_talk":"수면 중 자기 기술 호출","haze":"양쪽 능력 단계 초기화","party_cure":"동료 전원 상태 회복","refresh":"자신 상태 회복","focus_energy":"다음 공격 확정 급소","belly":"HP½ 소비 · 공격+6","screen":"특수 피해½ · 5턴","reflect":"물리 피해½ · 5턴","safeguard":"상태 방어 · 5턴","curse":"저주 · 능력/지속 피해","pivot":"이번 턴 수동 교대 무료","defog":"설치/장막 제거","ohko":"일격기 대신 강공격","clear_stages":"상대 능력 단계 초기화","stockpile":"비축 · 방어/특방+1","swallow":"비축을 소비해 회복","spit_up":"비축을 소비해 공격","wish":"다음 턴 HP½ 회복","ring":"턴마다 HP1/16 회복","root":"뿌리 · 회복/교대 제한","purify":"상대 상태 치유 + 회복","attract":"자신 대상 공격 피해½","silence":"음성 기술2턴 봉인","seal":"직전 기술3턴 봉인","tar":"불꽃 피해2배 + 둔화","knock":"상대 장비 무효","thief":"상대 장비 무효","destiny":"직접 공격자와 동반 기절","double_shock":"전기 타입 소모","glaive":"다음 자기 기술까지 취약","hammer":"연속 사용 불가","beak":"다음 접촉자 화상"}.get(v["special"],"")
        if not title.is_empty():rows.append(title)
    if v.has("hp_cost"):rows.append("자신 HP %d%% 소비" % int(v["hp_cost"]))
    if v.get("self_ko",false):rows.append("사용 후 자신 기절")
    if rows.is_empty():rows.append("효과 없음" if int(v["move_id"])==150 else "상세 규칙은 툴팁")
    if v.get("exhaust",false):rows.append("소진")
    return rows.slice(0,5)

static func effective_types(b:TacticalBattle,p:BattlePokemon) -> Array:
    var types:=p.types.duplicate()
    if PlayerMoveRules.read(b)["spent_electric"].get(p.uid,false) or b.boss_context.get("spent_electric",{}).get(p.uid,false):types.erase("electric")
    return types
