class_name HeldItemMath
extends RefCounted
## v21: pinned math with official equipment and contact-KO handling.
static func player_base(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if v.get("failed",false):return 0
    if not v.get("steal_applied",false) and not v.get("steal_stages",{}).is_empty():
        p=PlayerMoveExchange.clone(p);target=PlayerMoveExchange.clone(target)
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
    if PlayerMoveRules.read(b)["spent_electric"].get(p.uid,false):attacker=PlayerMoveExchange.clone(attacker);attacker.types.erase("electric")
    if v.has("immediate_boost") and not v.get("boost_applied",false):
        attacker=PlayerMoveExchange.clone(attacker)
        for stat:String in v["immediate_boost"]:attacker.stat_stages[stat]=clampi(int(attacker.stat_stages.get(stat,0))+int(v["immediate_boost"][stat]),-6,6)
    if id==263 and attacker.statuses.has("burn"):attacker=PlayerMoveExchange.clone(attacker);attacker.statuses.erase("burn")
    if v.get("ignore_defense",false):defender=PlayerMoveExchange.clone(defender);defender.stat_stages.erase("defense");defender.stat_stages.erase("special_defense")
    if v.get("critical",false):
        attacker=PlayerMoveExchange.clone(attacker);defender=PlayerMoveExchange.clone(defender)
        var stat:String="special_attack" if v["damage_class"]=="special" else "attack"
        var defense:String="special_defense" if v["damage_class"]=="special" else "defense"
        if int(attacker.stat_stages.get(stat,0))<0:attacker.stat_stages.erase(stat)
        if int(defender.stat_stages.get(defense,0))>0:defender.stat_stages.erase(defense)
        pressure*=1.5
    elif v.get("high_crit",false):pressure*=1.15
    if id==876 and BattleWeather.kind(b.powers)=="sun":pressure*=3 # cancel the usual water-in-sun half, then boost1.5
    var offense:String="defense" if v.get("variable")=="body_press" else ""
    var override:=PokemonStats.effective(target,"attack") if v.get("variable")=="foul" else 0
    return HeldItems.calculate(b,attacker,defender,v,affinity,bonus,pressure,BattleWeather.kind(b.powers),offense,override)
static func enemy_exchange(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if not BossBattleRules.modern(b) or (p.battle_stats.is_empty() and b.enemy().battle_stats.is_empty()):return source
    if not source.has("per_hit") or source.get("asleep",false) or source.get("failed_move",false) or source.get("immune",false) or source.has("fixed_damage") or source["kind"] in ["prepare","recharge","wait","guard"]:return source
    var a:=source.duplicate(true);var id:=int(a.get("effective_move",a["move_id"]))
    var m:Dictionary=a.get("copied_view",BossMoveEffectsP3.view(id)).duplicate(true)
    if not m.has("move_power"):return source
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["damage_class"]=a["damage_class"]
    if id==76 and BattleWeather.kind(b.powers) in ["rain","snow","sand"]:m["move_power"]=int(m["move_power"])/2
    var actor:=PlayerMoveExchange.clone(b.enemy());var target:=PlayerMoveExchange.clone(p);var pressure:=1.0
    if a.has("charge_boost"):actor.stat_stages["special_attack"]=int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
    if id==263:actor.statuses.erase("burn")
    if m.has("ignore_defense"):target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    if m.get("unique")=="critical":
        if int(actor.stat_stages.get("attack",0))<0:actor.stat_stages.erase("attack")
        if int(target.stat_stages.get("defense",0))>0:target.stat_stages.erase("defense")
        pressure=1.5
    if b.boss_context.get("spent_electric",{}).get(actor.uid,false):actor.types.erase("electric")
    a["per_hit"]=HeldItems.calculate(b,actor,target,m,b.multiplier(str(m["type"]),target),0,pressure,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
    a["value"]=int(a["per_hit"])*int(a.get("hits",1))
    for i:int in a.get("effects",[]).size():
        if "대상 기절 시 남은 타격 중단" in str(a["effects"][i]):a["effects"][i]="%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)]
    return a
static func arrow_base(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if v.get("failed",false):return 0
    if not v.get("steal_applied",false) and not v.get("steal_stages",{}).is_empty():
        p=PlayerMoveExchange.clone(p);target=PlayerMoveExchange.clone(target)
        for stat:String in v["steal_stages"]:
            p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+int(v["steal_stages"][stat]));target.stat_stages[stat]=0
    var id:=int(v["move_id"]);var affinity:=1.0 if id==165 else b.multiplier(str(v["type"]),target,int(v["move_id"]))
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
    if PlayerMoveRules.read(b)["spent_electric"].get(p.uid,false):attacker=PlayerMoveExchange.clone(attacker);attacker.types.erase("electric")
    if v.has("immediate_boost") and not v.get("boost_applied",false):
        attacker=PlayerMoveExchange.clone(attacker)
        for stat:String in v["immediate_boost"]:attacker.stat_stages[stat]=clampi(int(attacker.stat_stages.get(stat,0))+int(v["immediate_boost"][stat]),-6,6)
    if id==263 and attacker.statuses.has("burn"):attacker=PlayerMoveExchange.clone(attacker);attacker.statuses.erase("burn")
    if v.get("ignore_defense",false):defender=PlayerMoveExchange.clone(defender);defender.stat_stages.erase("defense");defender.stat_stages.erase("special_defense")
    if v.get("critical",false):
        attacker=PlayerMoveExchange.clone(attacker);defender=PlayerMoveExchange.clone(defender)
        var stat:String="special_attack" if v["damage_class"]=="special" else "attack"
        var defense:String="special_defense" if v["damage_class"]=="special" else "defense"
        if int(attacker.stat_stages.get(stat,0))<0:attacker.stat_stages.erase(stat)
        if int(defender.stat_stages.get(defense,0))>0:defender.stat_stages.erase(defense)
        pressure*=1.5
    elif v.get("high_crit",false):pressure*=1.15
    if id==876 and BattleWeather.kind(b.powers)=="sun":pressure*=3 # cancel the usual water-in-sun half, then boost1.5
    var offense:String="defense" if v.get("variable")=="body_press" else ""
    var override:=PokemonStats.effective(target,"attack") if v.get("variable")=="foul" else 0
    return HeldItems.calculate(b,attacker,defender,v,affinity,bonus,pressure,BattleWeather.kind(b.powers),offense,override)
static func boss_preview(b: TacticalBattle,target: BattlePokemon,source: Dictionary) -> Dictionary:
    var actor := b.enemy()
    var a := source.duplicate(true)
    a.merge({"boss_style":"authored","boss_moves_version":BossMoveEffectsP3.VERSION,"effects":[],"damage_class":"status","value":0,"immune":false,"advance":1},true)
    a["field_summary"]=BossBattleEffectsP3.summary(b)
    var s := BossMoveEffectsP3.state(b)
    var id := int(source["move_id"])
    var move := BossMoveEffectsP3.view(id)
    a["name"] = str(move.get("name",{"guard":"전술 방어","recharge":"재충전","wait":"휴식"}.get(source["kind"],"기술")))
    if actor.statuses.has("sleep") and id != 214:
        a["asleep"] = true
        return a
    if source["kind"] == "recharge" or bool(s["recharge"]):
        a["kind"] = "recharge"
        a["effects"].append("이번 행동은 공격 없이 정비합니다.")
        return a
    if source["kind"] == "guard":
        a["value"] = PokemonStats.scale(actor,int(source["value"]))
        return a
    if source["kind"] == "wait":
        a["effects"].append("이번 행동은 공격 없이 쉽니다.")
        return a
    if id == 214:
        if not actor.statuses.has("sleep"):
            a["effects"].append("잠꼬대 실패 · 깨어 있습니다.")
            return a
        id = BossMoveEffectsP3._sleep_choice(b)
        if id == 0:
            a["effects"].append("잠꼬대 실패 · 호출 가능한 기술이 없습니다.")
            return a
        move = BossMoveEffectsP3.view(id)
        a["called_move"] = id
        a["name"] = "잠꼬대 → "+str(move["name"])
    a["effective_move"] = id
    if id==119:
        var memory:Dictionary=BossBattleEffectsP3.read(b)["mirror"].get(actor.uid,{})
        if memory.get("source",0)!=target.uid or not target.alive():
            a["failed_move"]=true
            a["effects"].append("따라하기 실패 · 현 출전자의 복사 가능한 공격 기록 없음")
            return a
        move=TacticalMoves.definition(TacticalMoves.key_for(int(memory["move"]))).duplicate(true)
        move.erase("unique")
        if target.content_version>=2:move["type"]=PokedexExpansion.move_type(target.species_id,int(memory["move"]),str(move["type"]))
        a["copied_view"]=move
        a["name"]="따라하기 → "+str(move["name"])
        a["effects"].append("현 출전자의 마지막 공격 카드 위력/타입/분류·기본 부가효과 복사")
    if id in [143,340]:
        if id==340 and (BossBattleEffectsP3.read(b)["gravity"]>0 or s["air_cancel"]):
            a["failed_move"]=true;a["effects"].append("중력/착지 효과로 뛰어오르기 중단");return a
        if source["kind"]=="prepare" or (id==340 and int(s["charge"])!=340):
            a["kind"]="prepare"
            if id==340:a["advance"]=0
            a["effects"].append("뛰어오르기 · 공중 회피 · 다음 행동에 착지 공격" if id==340 else "불새 충전 · 다음 행동에 공격 · 급소/풀죽음 추첨 없음")
            return a
        elif int(s["charge"])!=id:
            a["failed_charge"]=true;a["effects"].append("준비가 취소되어 공격 실패");return a
    if move.has("charge_weather"):
        if source["kind"] == "prepare":
            if id == 905:
                a["charge_boost"] = mini(1,6-int(actor.stat_stages.get("special_attack",0)))
                a["effects"].append("충전 시 자신 특공 %+d단계" % a["charge_boost"])
            if BattleWeather.kind(b.powers) == move["charge_weather"]:
                a["kind"] = "move"
                a["advance"] = 2
                a["effects"].append("현재 날씨로 충전과 공격을 한 행동에 실행")
            else:
                a["effects"].append("충전 · 피해 없음 · 다음 행동에 공격")
                return a
        elif int(s["charge"]) != id:
            a["failed_charge"] = true
            a["effects"].append("충전이 취소되어 공격할 수 없습니다.")
            return a
    if move.has("rest"):
        a["healing"] = actor.max_hp-actor.hp
        a["effects"].append("HP %d 회복 · 화상/독/마비 해제 · 다음 두 행동 수면" % a["healing"] if a["healing"] > 0 else "HP가 가득 차 잠자기 실패")
        return a
    move = HeldItemMath.unique_conditional(b,actor,target,BossMoveEffectsP3._conditional(b,actor,target,move,a),a)
    var converted:=PlayerMoveReactions.move_type(b,actor,move)
    if converted["type"]!=move["type"]:
        move=converted;a["type"]=move["type"];a["copied_view"]=move.duplicate(true)
    a["damage_class"] = move["damage_class"]
    var affinity := b.multiplier(move["type"],target)
    a["immune"] = move.has("move_power") and affinity <= 0
    if move.has("move_power"):
        var attacker := actor
        if a.has("charge_boost"):
            attacker = BattlePokemon.new({"id":actor.species_id,"name":actor.display_name,"type":actor.type,"types":actor.types,"max_hp":actor.max_hp,"level":actor.level},actor.uid)
            attacker.species_stats = actor.species_stats
            attacker.strength = actor.strength
            attacker.stat_stages = actor.stat_stages.duplicate()
            attacker.statuses = actor.statuses.duplicate(true)
            attacker.stat_stages["special_attack"] = int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
        var attack_move := move
        if id == 76 and BattleWeather.kind(b.powers) in ["rain","snow","sand"]:
            attack_move = move.duplicate(true)
            attack_move["move_power"] = int(move["move_power"])/2
            a["effects"].append("현재 날씨로 솔라빔 위력 절반")
        a["per_hit"] = HeldItemMath.damage_preview(b,attacker,target,attack_move,a)
        a["hits"] = int(move.get("hits",1))
        a["value"] = int(a["per_hit"])*int(a["hits"])
        if a["hits"] > 1: a["effects"].append("%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a["hits"]])
    if int(a["move_id"])==136 and (a["immune"] or a.get("failed_move",false)):
        a["failed_move"]=true
        if BossBattleEffectsP3.read(b)["gravity"]==0:
            a["crash"]=maxi(1,actor.max_hp/2)
            a["effects"].append("무릎차기 실패 · 자신 최대HP/2 충돌 피해 %d" % a["crash"])
        else:a["effects"].append("중력으로 기술 사용 불가 · 충돌 반동 없음")
    if move.has("stat_changes"):
        var recipient := actor if move["stat_target"] == "self" else target
        for stat: String in move["stat_changes"]:
            var before := int(recipient.stat_stages.get(stat,0))
            var delta := clampi(before+int(move["stat_changes"][stat]),-6,6)-before
            a["effects"].append("%s %s %+d단계" % ["자신" if recipient == actor else "출전 동료",PokemonStats.TITLES[stat],0 if a["immune"] else delta])
    for status: String in BossMoveEffects.STATUSES:
        if move.has(status) and not a["immune"]:
            a["effects"].append("출전 동료 %s %d%s" % [BossMoveEffects.STATUS_NAMES[status],int(move[status]),"턴" if status in ["sleep","paralysis"] else "회"])
    if move.has("heal"):
        a["healing"] = mini(actor.max_hp-actor.hp,PokemonStats.scale(actor,int(move["heal"])))
        a["effects"].append("자신 HP %d 회복" % a["healing"])
    if move.has("shield"):
        a["shield"] = PokemonStats.scale(actor,int(move["shield"]))
        a["effects"].append("회피 대신 보호막 %d · 다음 행동 직전 해제" % a["shield"])
    if move.has("drain_percent"):
        var loss := mini(target.hp,maxi(0,int(a["value"])-target.block))
        var amount := BossMoveEffectsP3._ratio(loss,int(move["drain_percent"]))
        a["hp_cost"] = mini(actor.hp,amount) if move["drain_percent"] < 0 else -mini(actor.max_hp-actor.hp,amount)
        a["effects"].append("실제 HP 피해 기준 · 자신 %d %s" % [absi(a["hp_cost"]),"반동" if move["drain_percent"] < 0 else "흡수 회복"])
    if move.has("recharge"): a["effects"].append("다음 행동 재충전 · 공격하지 않음")
    if move.has("lock_turns"):
        a["advance"] = 0 if int(s["lock_left"]) == 0 else 1
        a["effects"].append("2행동 고정 연속기 · 종료 후 자신 혼란3회")
    if move.has("guard_kind"): a["effects"].append("다음 자기 행동까지 방어 · 킹실드는 접촉 공격 -2 · 폼 변화 없음" if move["guard_kind"] == "king" else "다음 자기 행동까지 대상 효과 방어")
    if move.has("substitute"):
        a["sub_cost"] = maxi(1,actor.max_hp/4)
        a["failed_move"] = actor.hp<=a["sub_cost"] or BossBattleEffectsP3.read(b)["substitutes"].get(actor.uid,0)>0
        a["effects"].append("대타출동 실패 · HP 부족/이미 대타 유지" if a["failed_move"] else "자신 HP %d 소비 · 같은 HP의 대타 생성" % a["sub_cost"])
    if move.has("root"): a["effects"].append("뿌리박기 · 자기 행동 종료마다 최대HP/16 회복 · 교대 불가")
    if move.has("weather"): a["effects"].append("쾌청 · 기존5턴 날씨 규칙 · 양쪽 불꽃/물 피해 변경")
    if move.has("field"): a["effects"].append({"screen":"빛의장막 · 다음5아군턴 특수 기술 피해 절반","safeguard":"신비의부적 · 다음5아군턴 상태 부여 차단","gravity":"중력 · 다음5아군턴 비행의 땅 무효 해제/공중 기술 제한 · 명중 추첨 없음"}[move["field"]])
    if move.has("hazard"): a["effects"].append("스텔스록 · 교대 시 최대HP/8 × 바위 상성 · 중첩 없음")
    if move.has("trap") and not a["immune"]: a["effects"].append("구속 · 최대HP/8 피해4회" if move["trap"]=="bind" else "구속 · 자신/대상 기절까지 교대 제한")
    if move.has("force_switch") and not a["immune"]:
        var uid:=BossBattleEffectsP3.next_ally(b)
        a["effects"].append("강제 교대 → "+b.member(uid).display_name if uid!=0 else "강제 교대 실패 · 살아 있는 대기 동료 없음")
    if move.has("pivot_final"): a["effects"].append("대표 마지막 순서 유지 · 앞 동료 기절로 교대 대상 없음")
    if move.has("ignore_defense"): a["effects"].append("상대 방어 단계 무시")
    if move.has("order_note"): a["effects"].append(move["order_note"])
    if move.has("adaptation"):a["effects"].append(move["adaptation"])
    if a.get("failed_move",false):a["effects"].append("현재 조건에서 기술 실패 · 피해/부가효과 없음")
    return a
static func enemy_field(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    var a:=source.duplicate(true);var id:=int(a.get("effective_move",a["move_id"]));var raw:=TacticalMoves.definition(TacticalMoves.key_for(id))
    var detail:=PlayerMoveFields.enemy_move(a,id)
    var actual_id:=int(detail.get("move_id",id))
    var status_blocked:=false
    for key:String in PlayerMoveFields.STATUS:
        if detail.has(key) and PlayerMoveAirFields.protected_status(b,p,key):status_blocked=true
    if status_blocked:a["effects"]=a.get("effects",[])+["필드/신비의부적 · 동료의 새 상태이상 차단"]
    if actual_id==281 and PlayerMoveAirFields.protected_status(b,p,"sleep"):
        a["player_sealed"]=true;a["value"]=0;a["effects"]=a.get("effects",[])+["필드/신비의부적 · 새 하품 예약 차단"]
        return a
    if detail.get("stat_target")=="enemy" and detail.has("stat_changes") and PlayerMoveFields.read(b)["ally"]["mist"]>0:a["effects"]=a.get("effects",[])+["흰안개 · 상대에 의한 음수 능력 단계 변화 차단"]
    if id==156 and PlayerMoveAltitude.grounded(b,b.enemy()) and PlayerMoveFields.read(b)["terrain"] in ["electric","misty"]:a["player_sealed"]=true;a["value"]=0;return a
    var attack:bool=a.get("damage_class",raw.get("damage_class","status"))!="status" and a["kind"] not in ["prepare","recharge","wait","guard","block","fortify","boost","recover","status"]
    if not attack or a.get("asleep",false) or a.get("failed_move",false) or a.get("failed_charge",false):return a
    if actual_id in PlayerMoveFields.data()["positive_priority"] and PlayerMoveFields.read(b)["terrain"]=="psychic" and PlayerMoveAltitude.grounded(b,p):
        a["player_sealed"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        a["effects"]=a.get("effects",[])+["사이코필드 · 접지 동료에 대한 선공 공격 차단"]
        return a
    if id==798 and PlayerMoveFields.read(b)["terrain"].is_empty():a["player_sealed"]=true;a["value"]=0;return a
    var m:Dictionary=detail.duplicate(true)
    m["type"]=a.get("type",m.get("type","normal"));m["damage_class"]=a.get("damage_class",m.get("damage_class","physical"))
    if m.has("move_power") and (PlayerMoveFields.read(b)["wonder"]>0 or actual_id in [805,797,804,802]):
        m["move_power"]=int(a.get("base_power",m["move_power"]));m=PlayerMoveAirFields.attack_view(b,b.enemy(),p,m);m=PlayerMoveReactions.move_type(b,b.enemy(),m)
        if id==76 and BattleWeather.kind(b.powers) in ["rain","snow","sand"]:m["move_power"]=int(m["move_power"])/2
        var actor:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(b.enemy()));var target:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(p));var pressure:=1.0
        if a.has("charge_boost"):actor.stat_stages["special_attack"]=int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
        if id==263:actor.statuses.erase("burn")
        if m.has("ignore_defense"):target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
        if m.get("unique")=="critical":
            if int(actor.stat_stages.get("attack",0))<0:actor.stat_stages.erase("attack")
            if int(target.stat_stages.get("defense",0))>0:target.stat_stages.erase("defense")
            pressure=1.5
        if b.boss_context.get("spent_electric",{}).get(actor.uid,false):actor.types.erase("electric")
        if not b.enemy_definitions[b.enemy_index].has("boss_moves_version"):pressure=0.55 if a["kind"]=="barrage" else (1.2 if a["kind"]=="charge" else 1.0)
        var affinity:=1.0 if id==165 else b.multiplier(str(m["type"]),target)
        var n:=int(a["fixed_damage"]) if a.has("fixed_damage") else HeldItems.calculate(b,actor,target,m,affinity,0,pressure,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
        a["immune"]=affinity<=0;a["type"]=m["type"]
        if a.has("per_hit"):a["per_hit"]=n
        a["value"]=n*int(a.get("hits",1))
    var scale:=PlayerMoveAirFields.factor(b,b.enemy(),p,m)
    if a.has("fixed_damage"):scale=1.0
    if scale!=1.0:
        if a.has("per_hit"):a["per_hit"]=maxi(1,floori(int(a["per_hit"])*scale)) if a["per_hit"]>0 else 0;a["value"]=int(a["per_hit"])*int(a.get("hits",1))
        else:a["value"]=maxi(1,floori(int(a["value"])*scale)) if a["value"]>0 else 0
    for i:int in a.get("effects",[]).size():
        if "대상 기절 시 남은 타격 중단" in str(a["effects"][i]) and a.has("per_hit"):a["effects"][i]="%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)]
    if not b.field_context.is_empty():a["effects"]=a.get("effects",[])+["공유 필드/룸·진영 효과 반영"]
    return a
static func enemy_critical(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if PlayerMoveSeals.read(b)["ally"]==0:return source
    var id:=int(source.get("effective_move",source["move_id"]))
    var m:=PlayerMoveFields.enemy_move(source,id).duplicate(true)
    if m.get("unique")!="critical" and not m.get("critical",false) and not m.get("high_crit",false):return source
    if not source.has("per_hit") or source.has("fixed_damage") or source.get("asleep",false) or source.get("failed_move",false) or source.get("failed_charge",false) or source.get("immune",false) or source.get("player_sealed",false) or source["kind"] in ["prepare","recharge","wait","guard"]:return source
    if not m.has("move_power"):return source
    var a:=source.duplicate(true);var actor:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(b.enemy()));var target:=PlayerMoveFields.room_clone(b,PlayerMoveExchange.clone(p))
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["type"]=a.get("type",m["type"]);m["damage_class"]=a.get("damage_class",m["damage_class"])
    m=PlayerMoveAirFields.attack_view(b,actor,target,m);m=PlayerMoveReactions.move_type(b,b.enemy(),m)
    if a.has("charge_boost"):actor.stat_stages["special_attack"]=int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
    if id==263:actor.statuses.erase("burn")
    if m.get("ignore_defense",false):target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    if b.boss_context.get("spent_electric",{}).get(actor.uid,false):actor.types.erase("electric")
    var n:=HeldItems.calculate(b,actor,target,m,b.multiplier(str(m["type"]),target),0,1.0,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
    var scale:=PlayerMoveAirFields.factor(b,actor,target,m)
    a["per_hit"]=maxi(1,floori(n*scale)) if n>0 else 0;a["value"]=int(a["per_hit"])*int(a.get("hits",1));a["critical_blocked"]=true
    var effects:Array=[]
    for line:String in a.get("effects",[]):
        if "확정 급소" not in line and "대상 기절 시 남은 타격 중단" not in line:effects.append(line)
    effects.append("주술 · 급소 배율/단계 무시 차단 · %d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)])
    a["effects"]=effects
    return a
static func enemy_arrow(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if not PlayerMoveItems.arrow(source) or source.get("asleep",false) or source.get("failed_move",false) or source.get("player_sealed",false):return source
    var a:=source.duplicate(true);var m:=PlayerMoveFields.enemy_move(a,int(a.get("effective_move",a["move_id"]))).duplicate(true)
    if not m.has("move_power"):return source
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["type"]=PlayerMoveReactions.move_type(b,b.enemy(),m)["type"]
    var actor:=PlayerMoveFields.room_clone(b,b.enemy());var target:=PlayerMoveFields.room_clone(b,p)
    var pressure:=1.0 if a.has("boss_moves_version") else (0.55 if a["kind"]=="barrage" else (1.2 if a["kind"]=="charge" else 1.0))
    var n:=HeldItems.calculate(b,actor,target,m,b.multiplier(str(m["type"]),p,614),0,pressure,BattleWeather.kind(b.powers))
    n=maxi(1,floori(n*PlayerMoveAirFields.factor(b,actor,target,m))) if n>0 else 0
    a["immune"]=n==0
    if a.has("per_hit"):a["per_hit"]=n
    a["value"]=n*int(a.get("hits",1))
    return a
static func damage_preview(b: TacticalBattle,actor: BattlePokemon,target: BattlePokemon,m: Dictionary,a: Dictionary) -> int:
    if a.get("failed_move",false) or a["immune"]:return 0
    if a.has("fixed_damage"):return int(a["fixed_damage"])
    if int(m["move_id"])==263 and actor.statuses.has("burn"):
        actor=BossMoveEffectsP3._clone(actor);actor.statuses.erase("burn")
    if m.has("ignore_defense"):
        target=BossMoveEffectsP3._clone(target);target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    var pressure:=1.0
    if m.get("unique")=="critical":
        actor=BossMoveEffectsP3._clone(actor);target=BossMoveEffectsP3._clone(target)
        if int(actor.stat_stages.get("attack",0))<0:actor.stat_stages.erase("attack")
        if int(target.stat_stages.get("defense",0))>0:target.stat_stages.erase("defense")
        pressure=1.5
    if BossBattleEffectsP3.read(b)["spent_electric"].get(actor.uid,false):
        actor=BossMoveEffectsP3._clone(actor);actor.types.erase("electric")
    return HeldItems.calculate(b,actor,target,m,b.multiplier(m["type"],target),0,pressure,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
static func unique_conditional(b: TacticalBattle,actor: BattlePokemon,target: BattlePokemon,source: Dictionary,a: Dictionary) -> Dictionary:
    var m:=source.duplicate(true)
    var c:=BossBattleEffectsP3.read(b)
    var s:=BossMoveEffectsP3.state(b)
    match str(m.get("unique","")):
        "attract":a["effects"].append("헤롱헤롱 · 성별/추첨 대신 다음2아군턴 자신 대상 기술 피해 절반 · 교대/시전자 기절로 해제")
        "destiny":a["effects"].append("길동무 · 다음 자기 행동 전 직접 기술로 쓰러지면 공격자도 기절 · 지속 피해/포획 제외")
        "yawn":
            a["failed_move"]=c["drowsy"].has(target.uid) or ["burn","poison","sleep","paralysis"].any(func(k:String):return target.statuses.has(k))
            a["effects"].append("하품 · 다음 아군턴 종료에 수면1턴 · 그 전에 교대하면 해제")
        "curse":a["effects"].append("자신 최대HP/2 소비 · 대상에게 매턴 최대HP/4 저주 · 교대로 해제" if "ghost" in actor.types else "저주 · 자신 공격/방어 +1, 스피드 -1")
        "knock_off":
            if not target.held_item.is_empty():m["move_power"]=floori(int(m["move_power"])*1.5)
            a["effects"].append("장비 보유 시 위력1.5배 · 전투 동안 장비 무효 · 전투 종료 복구")
        "thief":a["effects"].append("도둑질 · 전투 동안 대상 장비 무효 · 적 보너스/영구 손실 없음")
        "fake_out":
            a["failed_move"]=int(s["actions"])>0
            a["effects"].append("속이기 · 출전 후 첫 자기 행동에서만 성공 · 순서/풀죽음 추첨 없음")
        "tar":a["effects"].append("타르샷 · 교대 전까지 받는 불꽃 상성2배 · 스피드 -1")
        "silence":a["effects"].append("지옥찌르기 · 다음2아군턴 음성 기술 사용 금지 · 다른 기술/도구/교대 가능")
        "shell_side":
            var physical:=HeldItems.effective(b,actor,"attack")*HeldItems.effective(b,target,"special_defense")
            var special:=HeldItems.effective(b,actor,"special_attack")*HeldItems.effective(b,target,"defense")
            m["damage_class"]="physical" if physical>special else "special"
            a["effects"].append("셸암즈 · 단계 반영 공격/방어 비율 비교 · 동률 특수 · 현재 "+("물리" if m["damage_class"]=="physical" else "특수"))
        "eerie":a["effects"].append("섬뜩한주문 · PP 대신 마지막 사용 기술을 다음3아군턴 봉인 · 중복 카드도 동일")
        "critical":a["effects"].append("확정 급소1.5배 ×3타 · 공격 음수/방어 양수 무시 · 화상 감소 유지")
        "ohko":
            a["failed_move"]=actor.level<target.level or (int(m["move_id"])==329 and "ice" in target.types)
            a["effects"].append("일격기 각색 · 위력160 공개 강공격 · 높은 레벨/절대영도 얼음 타입은 실패")
        "jump_kick":
            a["failed_move"]=c["gravity"]>0
            a["effects"].append("명중 추첨 없음 · 타입 무효 시 최대HP/2 충돌 반동 · 중력 중 사용 불가")
        "beak":a["effects"].append("부리캐논 · 이 기술 예고 중 접촉 기술을 쓰면 접촉자 화상")
        "hammer":
            a["failed_move"]=int(s["last_move"])==893 and not s["last_failed"]
            a["effects"].append("거대해머 · 성공 직후 같은 기술 연속 사용 불가 · 명세 사이 다른 행동 유지")
        "glaive":a["effects"].append("대검돌격 · 성공 후 다음 자기 행동까지 받는 기술 피해2배")
        "temper":
            if s["last_failed"]:m["move_power"]=150
            a["effects"].append("열불내기 · 직전 기술 실패/수면 취소 시 위력150 · 현재 %d" % int(m["move_power"]))
        "double_shock":
            a["failed_move"]="electric" not in BossBattleEffectsP3.effective_types(b,actor)
            a["effects"].append("전광쌍격 · 성공 후 이번 전투 전기 타입 소모 · 재사용 실패")
        "fickle":
            m["move_power"]=160 if int(s["fickle"]) in [2,5,9] else 80
            a["effects"].append("변덕레이저 · 공개10회 주기3/6/10번째2배 · 현재 위력%d" % int(m["move_power"]))
        "sucker":
            var last:Dictionary=c["last_moves"].get(target.uid,{})
            a["failed_move"]=last.get("turn",0)!=b.turn or not last.get("attack",false)
            a["effects"].append("기습 각색 · 현재 출전자가 이번 턴 공격 기술을 사용했을 때 성공")
    if m.has("move_power"):a["base_power"]=int(m["move_power"])
    return m
static func boss_execute(b: TacticalBattle,a: Dictionary) -> void:
    var actor:=b.enemy()
    var target:=b.active()
    var before:=BossMoveEffectsP3.state(b).duplicate(true)
    HeldItemMath.boss_perform(b,a)
    var current:=BossMoveEffectsP3.state(b).duplicate(true)
    current["actions"]=int(before["actions"])+1
    current["last_move"]=int(a.get("effective_move",a["move_id"]))
    current["last_failed"]=a.get("failed_move",false) or a.get("failed_charge",false) or a.get("asleep",false) or a.get("immune",false) or (int(a["move_id"])==156 and int(a.get("healing",0))==0) or (int(a["move_id"])==214 and not a.has("called_move"))
    b.opening()["effects_v4"]=current
    if current["last_failed"] or a["kind"] in ["guard","wait","recharge","prepare"]:return
    var move:Dictionary=a.get("copied_view",BossMoveEffectsP3.view(int(a.get("effective_move",a["move_id"]))))
    var c:=BossBattleEffectsP3.write(b)
    match str(move.get("unique","")):
        "attract":
            if actor.alive() and target.alive():c["infatuation"][target.uid]={"source":actor.uid,"until":b.turn+2}
        "destiny":
            if actor.alive():c["destiny"][actor.uid]=true
        "yawn":
            if target.alive():c["drowsy"][target.uid]={"source":actor.uid,"due":b.turn+1}
        "curse":
            if "ghost" in actor.types:
                b._damage(actor,maxi(1,actor.max_hp/2),true)
                if target.alive():c["curses"][target.uid]=actor.uid
            elif actor.alive():
                for stat:String in ["attack","defense","speed"]:actor.stat_stages[stat]=clampi(int(actor.stat_stages.get(stat,0))+(-1 if stat=="speed" else 1),-6,6)
        "knock_off","thief":
            if not target.held_item.is_empty():
                c["removed_items"][target.uid]=target.held_item;target.held_item=""
                b._record("status",target.display_name+" · 이번 전투 동안 장비 무효",{"target":target.uid})
        "tar":
            if target.alive():c["tar"][target.uid]=true
        "silence":
            if target.alive():c["silence"][target.uid]=b.turn+2
        "eerie":
            var last:Dictionary=c["last_moves"].get(target.uid,{})
            if target.alive() and not last.is_empty():c["seals"][target.uid]={"move":last["move"],"until":b.turn+3}
        "glaive":
            if actor.alive():c["vulnerable"][actor.uid]=true
        "double_shock":
            if actor.alive():c["spent_electric"][actor.uid]=true
        "fickle":current["fickle"]=(int(before["fickle"])+1)%10
static func boss_perform(b: TacticalBattle,a: Dictionary) -> void:
    var actor := b.enemy()
    var target := b.active()
    var current := BossMoveEffectsP3.state(b).duplicate(true)
    b.opening()["effects_v4"] = current
    if a.get("asleep",false):
        current.merge({"charge":0,"recharge":false,"lock":0,"lock_left":0},true)
        b._record("cancel",actor.display_name+"은 잠들어 행동할 수 없습니다.")
        return
    if a["kind"] in ["recharge","wait"]:
        current["recharge"] = false
        b._record("enemy_action",actor.display_name+" · "+a["name"],a.merged({"action":"move"}))
        return
    if a["kind"] == "guard":
        actor.block = mini(TacticalBattle.MAX_BLOCK,int(a["value"]))
        b._record("shield",actor.display_name+" 전술 방어",{"target":actor.uid,"amount":actor.block})
        return
    var move:Dictionary = a.get("copied_view",BossMoveEffectsP3.view(int(a.get("effective_move",a["move_id"]))))
    if a.get("failed_charge",false) or a.get("failed_move",false) or (int(a["move_id"]) == 214 and not a.has("called_move")):
        b._record("cancel",actor.display_name+" · "+str(a["name"])+" 실패/중단")
        current["charge"]=0
        current["air_cancel"]=false
        if int(a.get("crash",0))>0:b._damage(actor,int(a["crash"]),true)
        return
    b._record("enemy_action",actor.display_name+" · "+str(a["name"]),a.merged({"action":"attack" if a["damage_class"] != "status" else "move"}))
    if a.has("charge_boost"):
        actor.stat_stages["special_attack"] = int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
        b._record("stat",actor.display_name+" · 충전 특공 강화",{"target":actor.uid})
    if a["kind"] == "prepare":
        current["charge"] = int(a["move_id"])
        if int(a["move_id"])==340:BossBattleEffectsP3.write(b)["airborne"][actor.uid]=true
        return
    if move.has("charge_weather") or int(a["move_id"]) in [143,340]: current["charge"] = 0
    if move.has("rest"):
        if actor.hp == actor.max_hp: return
        var healed := actor.max_hp-actor.hp
        for status: String in ["burn","poison","paralysis"]: actor.statuses.erase(status)
        actor.hp = actor.max_hp
        # The common end-of-action tick consumes this action, leaving two future actions.
        actor.statuses["sleep"] = {"turns":3,"source_uid":actor.uid}
        b._record("heal",actor.display_name+" · 잠자기",{"target":actor.uid,"amount":healed})
        b._record("status",actor.display_name+" · 다음 두 행동 수면",{"target":actor.uid})
        return
    var context:=BossBattleEffectsP3.write(b)
    if move.has("guard_kind"):
        context["guards"][actor.uid]=move["guard_kind"]
        b._record("field",actor.display_name+" · 방어 유지")
    if move.has("substitute"):
        b._damage(actor,int(a["sub_cost"]),true)
        context["substitutes"][actor.uid]=int(a["sub_cost"])
        b._record("substitute",actor.display_name+" · 대타출동")
    if move.has("root"):context["roots"][actor.uid]=true
    if move.has("weather"):BattleWeather.apply(b,move["weather"])
    if move.has("field"):
        context[move["field"]]=6
        b._record("field",actor.display_name+" · "+str(move["name"]))
    if move.has("hazard"):
        context["rocks"]=true
        b._record("field","아군 진영에 스텔스록 설치")
    var lost := 0
    if move.has("move_power"):
        for hit in int(a["hits"]):
            if not target.alive() or not actor.alive(): break
            if hit > 0: b._record("enemy_hit",actor.display_name+" · 연속 공격",a.merged({"action":"barrage"}))
            var before := target.hp
            b._damage(target,int(a["per_hit"]))
            lost += int(b.held_attack.get("last_loss",before-target.hp))
    if target.alive() and actor.alive() and not a["immune"]:
        for status: String in BossMoveEffects.STATUSES:
            if not move.has(status): continue
            target.statuses[status] = {"turns":int(move[status]),"source_uid":actor.uid}
            b._record("status",target.display_name+" · "+str(BossMoveEffects.STATUS_NAMES[status]),{"target":target.uid})
    if move.has("stat_changes") and not a["immune"]:
        var recipient := actor if move["stat_target"] == "self" else target
        if recipient.alive():
            for stat: String in move["stat_changes"]: recipient.stat_stages[stat] = clampi(int(recipient.stat_stages.get(stat,0))+int(move["stat_changes"][stat]),-6,6)
            b._record("stat",recipient.display_name+" 능력 변화",{"target":recipient.uid})
    if move.has("heal"):
        var healed := mini(actor.max_hp-actor.hp,PokemonStats.scale(actor,int(move["heal"])))
        actor.hp += healed
        if healed > 0: b._record("heal",actor.display_name+" 회복",{"target":actor.uid,"amount":healed})
    if move.has("shield"):
        actor.block = mini(TacticalBattle.MAX_BLOCK,int(a["shield"]))
        b._record("shield",actor.display_name+" · 회피 대신 보호막",{"target":actor.uid,"amount":actor.block})
    if move.has("drain_percent"):
        var amount := BossMoveEffectsP3._ratio(lost,int(move["drain_percent"]))
        if move["drain_percent"] < 0:
            if amount > 0:
                b._record("recoil",actor.display_name+" 반동",{"target":actor.uid,"amount":mini(actor.hp,amount)})
                b._damage(actor,amount,true)
        else:
            amount = mini(actor.max_hp-actor.hp,amount)
            actor.hp += amount
            if amount > 0: b._record("heal",actor.display_name+" 흡수",{"target":actor.uid,"amount":amount})
    if actor.alive() and target.alive() and not a["immune"]:
        if move.has("trap"):
            context["traps"][target.uid]={"source":actor.uid,"turns":4 if move["trap"]=="bind" else 0,"dot":move["trap"]=="bind"}
            b._record("status",target.display_name+" · 구속",{"target":target.uid})
        if move.has("force_switch"):BossBattleEffectsP3.force_switch(b)
    if actor.alive():
        if move.has("recharge") and not a["immune"]: current["recharge"] = true
        if move.has("lock_turns"):
            if current["lock_left"] == 0:
                current["lock"] = int(a.get("effective_move",a["move_id"]))
                current["lock_left"] = 1
            else:
                current["lock"] = 0
                current["lock_left"] = 0
                # Existing confusion ticks immediately, then twice more: three hits in total.
                actor.statuses["confusion"] = {"turns":3,"source_uid":actor.uid}
                b._record("status",actor.display_name+" · 연속기 종료 혼란",{"target":actor.uid})
