class_name BossMoveEffectsP2
extends RefCounted
## Route v8 conditional moves and field effects. Earlier engines remain frozen.
const PATH := "res://data/boss_move_effects_v8.json"
const VERSION := 3
static var _data: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty():
        _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        for id: String in _data["move_flags"]:
            _data["move_flags"][id] = _data["move_flags"][id].map(func(value: Variant):return int(value))
        for key: String in _data["profiles"]:
            var p: Dictionary = _data["profiles"][key]
            p["species"] = int(p["species"])
            for a: Dictionary in p["intents"]:
                a["move_id"] = int(a["move_id"])
                a["value"] = int(a["value"])
    return _data
static func profile(boss: String,species: int) -> Dictionary:
    return data()["profiles"].get("%s:%d" % [boss,species],{})
static func view(id: int) -> Dictionary:
    return data()["moves"].get(str(id),{})
static func build(boss: String,species: int) -> Dictionary:
    var p := profile(boss,species)
    if p.is_empty(): return {}
    return {"boss":boss,"boss_style":"authored","boss_moves_version":VERSION,"intents":p["intents"].duplicate(true)}
static func valid(d: Dictionary) -> bool:
    if not d.get("boss_moves_version") is int or d["boss_moves_version"] != VERSION: return false
    if not d.get("boss") is String or not d.get("id") is int or d.get("boss_style") != "authored": return false
    var p := profile(d["boss"],d["id"])
    if p.is_empty() or d.get("intents") != p["intents"]: return false
    for a: Dictionary in d["intents"]:
        if not a.get("move_id") is int or not a.get("value") is int: return false
    return true
static func state(b: TacticalBattle) -> Dictionary:
    # Preview must never insert defaults into a live state or consume RNG.
    return b.opening().get("effects_v3",{"charge":0,"recharge":false,"lock":0,"lock_left":0})
static func valid_state(s: Variant,d: Dictionary) -> bool:
    if not s is Dictionary or not s.get("intent") is int or s["intent"] < 0 or s["intent"] > 1000000: return false
    if not s.has("effects_v3"): return true
    var v: Variant = s["effects_v3"]
    if not v is Dictionary or v.size() != 4: return false
    if not v.get("charge") is int or not v.get("recharge") is bool or not v.get("lock") is int or not v.get("lock_left") is int: return false
    var cycle: Array = d["intents"]
    var next: Dictionary = cycle[s["intent"] % cycle.size()]
    if v["charge"] != 0 and (v["charge"] not in [76,905] or next["kind"] != "move" or next["move_id"] != v["charge"]): return false
    if v["recharge"] and next["kind"] != "recharge": return false
    if v["lock_left"] not in [0,1] or (v["lock"] == 0) != (v["lock_left"] == 0): return false
    if v["lock"] != 0 and (v["lock"] not in [37,80,200] or next["kind"] != "move" or next["move_id"] != v["lock"]): return false
    return true
static func _ratio(hp: int,percent: int) -> int:
    if hp <= 0: return 0
    return maxi(1,roundi(hp/3.0) if absi(percent) == 33 else roundi(hp*absi(percent)/100.0))
static func _sleep_choice(b: TacticalBattle) -> int:
    var choices: Array[int] = []
    for a: Dictionary in b.enemy_definitions[b.enemy_index]["intents"]:
        var id := int(a["move_id"])
        if a["kind"] == "move" and id not in choices and not view(id).has("charge_weather") and id not in [156,214]: choices.append(id)
    return choices[int(b.opening()["intent"]) % choices.size()] if not choices.is_empty() else 0
static func preview(b: TacticalBattle,target: BattlePokemon,source: Dictionary) -> Dictionary:
    var actor := b.enemy()
    var a := source.duplicate(true)
    a.merge({"boss_style":"authored","boss_moves_version":VERSION,"effects":[],"damage_class":"status","value":0,"immune":false,"advance":1},true)
    a["field_summary"]=BossBattleEffects.summary(b)
    var s := state(b)
    var id := int(source["move_id"])
    var move := view(id)
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
        id = _sleep_choice(b)
        if id == 0:
            a["effects"].append("잠꼬대 실패 · 호출 가능한 기술이 없습니다.")
            return a
        move = view(id)
        a["called_move"] = id
        a["name"] = "잠꼬대 → "+str(move["name"])
    a["effective_move"] = id
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
    move = _conditional(b,actor,target,move,a)
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
        a["per_hit"] = _damage_preview(b,attacker,target,attack_move,a)
        a["hits"] = int(move.get("hits",1))
        a["value"] = int(a["per_hit"])*int(a["hits"])
        if a["hits"] > 1: a["effects"].append("%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a["hits"]])
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
        var amount := _ratio(loss,int(move["drain_percent"]))
        a["hp_cost"] = mini(actor.hp,amount) if move["drain_percent"] < 0 else -mini(actor.max_hp-actor.hp,amount)
        a["effects"].append("실제 HP 피해 기준 · 자신 %d %s" % [absi(a["hp_cost"]),"반동" if move["drain_percent"] < 0 else "흡수 회복"])
    if move.has("recharge"): a["effects"].append("다음 행동 재충전 · 공격하지 않음")
    if move.has("lock_turns"):
        a["advance"] = 0 if int(s["lock_left"]) == 0 else 1
        a["effects"].append("2행동 고정 연속기 · 종료 후 자신 혼란3회")
    if move.has("guard_kind"): a["effects"].append("다음 자기 행동까지 방어 · 킹실드는 접촉 공격 -2 · 폼 변화 없음" if move["guard_kind"] == "king" else "다음 자기 행동까지 대상 효과 방어")
    if move.has("substitute"):
        a["sub_cost"] = maxi(1,actor.max_hp/4)
        a["failed_move"] = actor.hp<=a["sub_cost"] or BossBattleEffects.read(b)["substitutes"].get(actor.uid,0)>0
        a["effects"].append("대타출동 실패 · HP 부족/이미 대타 유지" if a["failed_move"] else "자신 HP %d 소비 · 같은 HP의 대타 생성" % a["sub_cost"])
    if move.has("root"): a["effects"].append("뿌리박기 · 자기 행동 종료마다 최대HP/16 회복 · 교대 불가")
    if move.has("weather"): a["effects"].append("쾌청 · 기존5턴 날씨 규칙 · 양쪽 불꽃/물 피해 변경")
    if move.has("field"): a["effects"].append({"screen":"빛의장막 · 다음5아군턴 특수 기술 피해 절반","safeguard":"신비의부적 · 다음5아군턴 상태 부여 차단","gravity":"중력 · 다음5아군턴 비행의 땅 무효 해제/공중 기술 제한 · 명중 추첨 없음"}[move["field"]])
    if move.has("hazard"): a["effects"].append("스텔스록 · 교대 시 최대HP/8 × 바위 상성 · 중첩 없음")
    if move.has("trap") and not a["immune"]: a["effects"].append("구속 · 최대HP/8 피해4회" if move["trap"]=="bind" else "구속 · 자신/대상 기절까지 교대 제한")
    if move.has("force_switch") and not a["immune"]:
        var uid:=BossBattleEffects.next_ally(b)
        a["effects"].append("강제 교대 → "+b.member(uid).display_name if uid!=0 else "강제 교대 실패 · 살아 있는 대기 동료 없음")
    if move.has("pivot_final"): a["effects"].append("대표 마지막 순서 유지 · 앞 동료 기절로 교대 대상 없음")
    if move.has("ignore_defense"): a["effects"].append("상대 방어 단계 무시")
    if move.has("order_note"): a["effects"].append(move["order_note"])
    return a
static func execute(b: TacticalBattle,a: Dictionary) -> void:
    var actor := b.enemy()
    var target := b.active()
    var current := state(b).duplicate(true)
    b.opening()["effects_v3"] = current
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
    var move := view(int(a.get("effective_move",a["move_id"])))
    if a.get("failed_charge",false) or a.get("failed_move",false) or (int(a["move_id"]) == 214 and not a.has("called_move")):
        b._record("cancel",actor.display_name+" · "+str(a["name"])+" 실패/중단")
        return
    b._record("enemy_action",actor.display_name+" · "+str(a["name"]),a.merged({"action":"attack" if a["damage_class"] != "status" else "move"}))
    if a.has("charge_boost"):
        actor.stat_stages["special_attack"] = int(actor.stat_stages.get("special_attack",0))+int(a["charge_boost"])
        b._record("stat",actor.display_name+" · 충전 특공 강화",{"target":actor.uid})
    if a["kind"] == "prepare":
        current["charge"] = int(a["move_id"])
        return
    if move.has("charge_weather"): current["charge"] = 0
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
    var context:=BossBattleEffects.write(b)
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
            if not target.alive(): break
            if hit > 0: b._record("enemy_hit",actor.display_name+" · 연속 공격",a.merged({"action":"barrage"}))
            var before := target.hp
            b._damage(target,int(a["per_hit"]))
            lost += before-target.hp
    if target.alive() and not a["immune"]:
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
        var amount := _ratio(lost,int(move["drain_percent"]))
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
        if move.has("force_switch"):BossBattleEffects.force_switch(b)
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
static func _clone(p: BattlePokemon) -> BattlePokemon:
    var copy:=BattlePokemon.new({"id":p.species_id,"name":p.display_name,"type":p.type,"types":p.types,"max_hp":p.max_hp,"level":p.level},p.uid)
    copy.species_stats=p.species_stats;copy.strength=p.strength
    copy.statuses=p.statuses.duplicate(true);copy.stat_stages=p.stat_stages.duplicate()
    return copy
static func _conditional(b: TacticalBattle,actor: BattlePokemon,target: BattlePokemon,source: Dictionary,a: Dictionary) -> Dictionary:
    var m:=source.duplicate(true)
    var id:=int(m["move_id"])
    var context:=BossBattleEffects.read(b)
    var received:=BossBattleEffects.received(b,actor.uid)
    var power:=int(m.get("move_power",0))
    var condition:=false
    var mode: String=m.get("variable","")
    match mode:
        "brine": condition=target.hp*2<=target.max_hp
        "facade": condition=["burn","poison","paralysis"].any(func(k: String):return actor.statuses.has(k))
        "venoshock":condition=target.statuses.has("poison")
        "hex":condition=["burn","poison","sleep","paralysis"].any(func(k: String):return target.statuses.has(k))
        "pursuit":condition=context["last_switch"]==b.turn
        "payback":condition=context["acted"].get(target.uid,0)==b.turn
        "assurance":condition=context["hurt"].get(target.uid,0)==b.turn
        "avalanche":condition=int(received["damage"])>0
        "retaliate":condition=context["last_enemy_ko"]>0 and context["last_enemy_ko"]>=b.turn-1
        "gyro":power=clampi(25*PokemonStats.effective(target,"speed")/PokemonStats.effective(actor,"speed")+1,1,150)
        "return":power=102
        "hard_press":power=maxi(1,100*target.hp/target.max_hp)
        "flail":
            var hp:=48*actor.hp/actor.max_hp
            power=200 if hp<=1 else (150 if hp<=4 else (100 if hp<=9 else (80 if hp<=16 else (40 if hp<=32 else 20))))
        "grass_knot":
            var weight:=int(data()["weights"][str(target.species_id)])
            power=20 if weight<100 else (40 if weight<250 else (60 if weight<500 else (80 if weight<1000 else (100 if weight<2000 else 120))))
        "heavy_slam":
            var own:=int(data()["weights"][str(actor.species_id)])
            var weight:=int(data()["weights"][str(target.species_id)])
            power=120 if own>=weight*5 else (100 if own>=weight*4 else (80 if own>=weight*3 else (60 if own>=weight*2 else 40)))
        "body_press":a["offense_stat"]="defense"
        "counter","metal_burst":
            a["fixed_damage"]=int(received["damage"])*2 if mode=="counter" and received["kind"]=="physical" else (floori(int(received["damage"])*1.5) if mode=="metal_burst" else 0)
            if a["fixed_damage"]==0:a["failed_move"]=true
            a["effects"].append("이번 턴 마지막 실제HP 피격 기준 · 현재 출전자에게 고정 피해 %d" % a["fixed_damage"])
        "focus":
            if int(received["damage"])>0:a["failed_move"]=true
            a["effects"].append("힘껏펀치 중단 · 이번 턴 기술로 HP 피해를 받음" if a.get("failed_move",false) else "이번 턴 기술 HP 피격이 없으면 공격 · 대타 피해는 중단하지 않음")
    if mode in ["brine","facade","venoshock","hex","pursuit","payback","assurance","avalanche","retaliate"]:
        if condition:power*=2
        a["effects"].append("위력 조건 %s · 현재 위력 %d" % ["성립" if condition else "불성립",power])
    elif mode in ["gyro","return","hard_press","flail","grass_knot","heavy_slam"]:a["effects"].append("현재 조건의 위력 %d%s" % [power," · NPC 친밀도255 고정" if mode=="return" else ""])
    if m.has("move_power"):m["move_power"]=power
    a["base_power"]=power
    return m
static func _damage_preview(b: TacticalBattle,actor: BattlePokemon,target: BattlePokemon,m: Dictionary,a: Dictionary) -> int:
    if a.get("failed_move",false) or a["immune"]:return 0
    if a.has("fixed_damage"):return int(a["fixed_damage"])
    if int(m["move_id"])==263 and actor.statuses.has("burn"):
        actor=_clone(actor);actor.statuses.erase("burn")
    if m.has("ignore_defense"):
        target=_clone(target);target.stat_stages.erase("defense");target.stat_stages.erase("special_defense")
    return PokemonStats.damage(actor,target,m,b.multiplier(m["type"],target),0,1.0,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
static func tooltip(a: Dictionary) -> String:
    if a.get("asleep",false): return "수면으로 다음 행동을 취소합니다.\n"+str(a.get("field_summary",""))
    if a["kind"] == "guard": return BossMoveEffects.tooltip(a)+"\n"+str(a.get("field_summary",""))
    var lines: Array[String] = [str(a["name"])]
    if a["damage_class"] != "status": lines.append("%s · 피해 %d" % ["특수" if a["damage_class"] == "special" else "물리",int(a["value"])])
    if a.get("immune",false): lines.append("타입 무효 · 공격 부가효과도 적용하지 않음")
    lines.append_array(a["effects"])
    if int(a["move_id"]) == 355: lines.append("날개쉬기는 회복만 적용 · 타입 유지")
    if int(a["move_id"]) == 92: lines.append("맹독은 독3회 · 누적 피해 없음")
    lines.append("부가효과 확정 · 연타 횟수/잠꼬대 선택 공개 · 별도 추첨 없음")
    if not str(a.get("field_summary","")).is_empty():lines.append(a["field_summary"])
    return "\n".join(lines)
