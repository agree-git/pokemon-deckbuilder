class_name PlayerMoveFields
extends RefCounted
## Route v13. Shared terrain/rooms and side conditions never consume battle RNG.
const PATH:="res://data/player_move_fields_v13.json"
const HAZARDS:Dictionary={"rocks":0,"spikes":0,"toxic":0,"web":0}
const SIDE:Dictionary={"screen":0,"reflect":0,"safeguard":0,"tailwind":0,"veil":0,"mist":0}
const DEFAULT:Dictionary={"terrain":"","left":0,"trick":0,"wonder":0,"mud":0,"water":0,"ally":SIDE,"foe":SIDE,"hazards":HAZARDS}
const TITLES:Dictionary={"electric":"일렉트릭필드","grassy":"그래스필드","misty":"미스트필드","psychic":"사이코필드","trick":"트릭룸","wonder":"원더룸","mud":"흙놀이","water":"물놀이","screen":"빛의장막","reflect":"리플렉터","safeguard":"신비의부적","tailwind":"순풍","veil":"오로라베일","mist":"흰안개"}
const STATUS:Array[String]=["burn","poison","sleep","paralysis","confusion"]
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():
        _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        _data["positive_priority"]=_data["positive_priority"].map(func(n:Variant):return int(n))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.field_context if not b.field_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.field_context.is_empty():b.field_context=DEFAULT.duplicate(true)
    return b.field_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveExchange.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=5;v["description"]=TacticalContent.description(v)
    return v
static func eligible(id:int) -> bool:return PlayerMoveExchange.eligible(id) and not definition(TacticalMoves.key_for(id)).get("self_ko",false)
static func sleep_choice(p:BattlePokemon) -> int:
    for key:String in p.learned_skills:
        var id:=int(TacticalMoves.definition(key).get("move_id",0))
        if eligible(id):return id
    return 0
static func expand(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var mode:String=original.get("copy_mode","");var sleeping:bool=original.get("special")=="sleep_talk" and p.statuses.has("sleep")
    if mode.is_empty() and not sleeping:return original
    var id:=sleep_choice(p) if sleeping else PlayerMoveExchange.choice(b,p,mode)
    if mode=="nature-power" and not read(b)["terrain"].is_empty():id={"electric":85,"grassy":412,"misty":585,"psychic":94}[read(b)["terrain"]]
    if mode=="assist":
        id=0
        for ally:BattlePokemon in b.party:
            if ally==p or not ally.alive():continue
            id=sleep_choice(ally)
            if id>0:break
    if id==0 or not eligible(id):
        var missing:=original.duplicate(true);missing["copy_failed"]=true
        if sleeping:missing.erase("special");missing["safe_sleep_missing"]=true
        return missing
    var card:=BattleCardInstance.new(int(original["uid"]),TacticalMoves.key_for(id),p.uid)
    var v:=TacticalContent.definition(card,5)
    for field:String in ["uid","key","owner_uid","owner_name","species_id","switches","retained","cost"]:
        if original.has(field):v[field]=original[field]
    v["name"]=str(original["name"])+" → "+str(v["name"])
    if sleeping:v["sleep_call"]=true
    else:
        v["copy_mode"]=mode;v["copy_move"]=id;v["copy_source"]=int(original["move_id"])
        if mode=="me-first":v["copy_boost"]=true
    if original.get("exhaust",false):v["exhaust"]=true
    v["card_notes"].append_array(original.get("card_notes",[]));v["card_notes"].append("이번 호출: "+str(TacticalMoves.visual(id)["name"]))
    return v
static func grounded(b:TacticalBattle,p:BattlePokemon,entering:=false) -> bool:
    var types:Array=PlayerMoveCards.effective_types(b,p)
    if entering and read(b).has("terrain"):
        types=PlayerMoveExchange.read(b)["types"].get(p.uid,{}).get("base",p.types)
    if b.boss_context.get("gravity",0)>0 or PlayerMoveRules.read(b)["roots"].get(p.uid,false) or b.boss_context.get("roots",{}).get(p.uid,false):return true
    if "flying" in types:return false
    if not entering:
        var charge:Dictionary=PlayerMoveRules.read(b)["charges"].get(p.uid,{})
        var phase:String=PlayerMoveCards.data()["moves"].get(str(charge.get("move",0)),{}).get("charge","")
        if phase=="air" and b.turn<int(charge.get("ready",0)):return false
        if b.boss_context.get("airborne",{}).get(p.uid,false):return false
    return true
static func side(p:BattlePokemon) -> String:return "ally" if p.uid>0 else "foe"
static func native(b:TacticalBattle,p:BattlePokemon,key:String) -> int:
    if p.uid>0:return int(PlayerMoveRules.read(b).get(key,0))
    return int(BossBattleRules.read(b).get(key,0)) if BossBattleRules.active_in(b) and key in ["screen","safeguard"] else 0
static func protected_status(b:TacticalBattle,p:BattlePokemon,status:String) -> bool:
    if int(read(b)[side(p)]["safeguard"])>0:return true
    return grounded(b,p) and (read(b)["terrain"]=="misty" or (read(b)["terrain"]=="electric" and status=="sleep"))
static func prevent_status(b:TacticalBattle,p:BattlePokemon,before:Dictionary) -> void:
    for key:String in STATUS:
        if not before.has(key) and p.statuses.has(key) and protected_status(b,p,key):
            p.statuses.erase(key);b._record("field",p.display_name+" · 필드/신비의부적이 새 상태이상 차단",{"target":p.uid})
static func attack_view(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary) -> Dictionary:
    var id:=int(v["move_id"]);var terrain:String=read(b)["terrain"];var own:=grounded(b,p);var other:=grounded(b,target)
    match id:
        805:
            if own and not terrain.is_empty():v["type"]={"electric":"electric","grassy":"grass","misty":"fairy","psychic":"psychic"}[terrain];v["move_power"]=int(v["move_power"])*2
        797:
            if terrain=="psychic" and own:v["move_power"]=floori(int(v["move_power"])*1.5)
        804:
            if terrain=="electric" and other:v["move_power"]=int(v["move_power"])*2
        803:
            if terrain=="grassy" and own and v.has("cost"):v["cost"]=maxi(0,int(v["cost"])-1)
        802:
            if terrain=="misty" and own:v["move_power"]=floori(int(v["move_power"])*1.5)
    return v
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    var target:=b.enemy();v=attack_view(b,p,target,v)
    for status:String in STATUS:
        if v.has(status) and protected_status(b,target,status):v.erase(status);v["card_notes"].append("필드/신비의부적이 새 상태이상을 차단")
    if v.get("exchange")=="shift" and protected_status(b,target,PlayerMoveExchange.main_status(p)):v["exchange_blocked"]=true
    if v.get("special")=="yawn" and protected_status(b,target,"sleep"):v["boss_blocked"]=true
    if v.get("stat_target")=="enemy" and v.has("stat_changes") and read(b)["foe"]["mist"]>0:
        for stat:String in v["stat_changes"].keys():
            if int(v["stat_changes"][stat])<0:v["stat_changes"].erase(stat)
        v["card_notes"].append("흰안개가 상대의 음수 능력 단계 변화를 차단")
    if v.has("damage") and int(v["move_id"]) in data()["positive_priority"] and read(b)["terrain"]=="psychic" and grounded(b,target):
        v["priority_blocked"]=true;v["failed"]=true;v["card_notes"].append("사이코필드가 접지 상대에 대한 선공 공격을 차단")
    if v.has("damage") and not read(b)["terrain"].is_empty():v["card_notes"].append("현재 필드: "+str(TITLES[read(b)["terrain"]]))
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("safe_sleep_missing",false):return "잠꼬대로 부를 수 있는 안전한 공격이 없습니다."
    if v.get("copy_failed",false):return "복사 가능한 공격이 없습니다."
    if v.get("priority_blocked",false):return "사이코필드가 접지 상대에 대한 선공 공격을 막습니다."
    if v.get("field_rule")=="roller" and read(b)["terrain"].is_empty():return "아이언롤러에는 활성 필드가 필요합니다."
    if v.get("field_rule")=="veil" and BattleWeather.kind(b.powers)!="snow":return "오로라베일은 눈이 내릴 때 설치합니다."
    if v.get("special")=="rest" and grounded(b,p) and read(b)["terrain"] in ["electric","misty"]:return "현재 필드가 새 수면을 막아 잠자기를 사용할 수 없습니다."
    if p!=b.active() and entry_damage(b,p)+ (BossBattleRules.entry_damage(b,p) if BossBattleRules.active_in(b) else 0)>=p.hp:return "진영 설치 입장 피해로 기절해 기술을 사용할 수 없습니다."
    return ""
static func court(b:TacticalBattle) -> void:
    var c:=write(b);var own:Dictionary=c["ally"].duplicate();var foe:Dictionary=c["foe"].duplicate();var moves:=PlayerMoveRules.write(b)
    for key:String in ["screen","reflect","safeguard"]:own[key]=maxi(int(own[key]),int(moves[key]));moves[key]=0
    if BossBattleRules.active_in(b):
        var boss:=BossBattleRules.write(b)
        for key:String in ["screen","safeguard"]:foe[key]=maxi(int(foe[key]),int(boss[key]));boss[key]=0
    c["ally"]=foe;c["foe"]=own
    var incoming:Dictionary=c["hazards"].duplicate()
    if BossBattleRules.active_in(b) and BossBattleRules.read(b)["rocks"]:incoming["rocks"]=1;BossBattleRules.write(b)["rocks"]=false
    c["hazards"]=PlayerMoveTactics.read(b)["hazards"].duplicate();PlayerMoveTactics.write(b)["hazards"]=incoming
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false):return
    var c:=write(b);var tag:String=v.get("field_rule","")
    var hit:bool=not v.get("boss_blocked",false) and not v.get("failed",false) and (not v.has("damage") or b.multiplier(str(v["type"]),target)>0)
    match tag:
        "electric","grassy","misty","psychic":c["terrain"]=tag;c["left"]=5
        "trick","wonder":c[tag]=0 if c[tag]>0 else 5
        "mud","water":c[tag]=5
        "tailwind","veil","mist":c["ally"][tag]=4 if tag=="tailwind" else 5
        "court":court(b)
        "roller","spinner":
            if hit:c["terrain"]="";c["left"]=0
        "defog":
            if hit:
                c["terrain"]="";c["left"]=0;c["hazards"]=HAZARDS.duplicate()
                for s:String in ["ally","foe"]:
                    for key:String in ["screen","reflect","safeguard","veil","mist"]:c[s][key]=0
    if int(v["move_id"])==280 and hit:
        for key:String in ["screen","reflect","veil"]:c["foe"][key]=0
    if int(v["move_id"]) in [229,866] and hit:c["hazards"]=HAZARDS.duplicate()
    if not tag.is_empty():b._record("field",str(v["name"])+(" · 필드 규칙 적용" if hit else " · 대상 효과 차단"))
static func speed(b:TacticalBattle,p:BattlePokemon) -> int:return PokemonStats.effective(p,"speed")*(2 if read(b)[side(p)]["tailwind"]>0 else 1)
static func room_clone(b:TacticalBattle,p:BattlePokemon) -> BattlePokemon:
    if read(b)["wonder"]==0:return p
    var copy:=PlayerMoveExchange.clone(p);copy.battle_stats["defense"]=p.special_defense;copy.battle_stats["special_defense"]=p.defense
    return copy
static func fixed(v:Dictionary) -> bool:return str(v.get("special",v.get("variable",""))) in ["level","psywave","forty","twenty","half","endeavor","final_gambit","counter","mirror_coat","metal_burst"]
static func factor(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary) -> float:
    if fixed(v):return 1.0
    var c:=read(b);var type_name:String=v["type"];var result:=1.0;var id:=int(v["move_id"])
    if id!=165:
        if grounded(b,p) and {"electric":"electric","grassy":"grass","psychic":"psychic"}.get(c["terrain"],"")==type_name:result*=1.3
        if grounded(b,target) and c["terrain"]=="misty" and type_name=="dragon":result*=0.5
        if grounded(b,target) and c["terrain"]=="grassy" and id in [89,222,523]:result*=0.5
        if (type_name=="electric" and c["mud"]>0) or (type_name=="fire" and c["water"]>0):result/=3.0
    var wall:String="screen" if v.get("damage_class")=="special" else "reflect"
    if id!=280 and native(b,target,wall)==0 and (c[side(target)][wall]>0 or c[side(target)]["veil"]>0):result*=0.5
    return result
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    var n:=PlayerMoveExchange.raw_damage(b,room_clone(b,p),room_clone(b,target),v,bonus)
    return maxi(1,floori(n*factor(b,p,target,v))) if n>0 else 0
static func enemy_move(a:Dictionary,id:int) -> Dictionary:
    # An encounter can contain ordinary members followed by an authored ace.
    # Select by this action's source, rather than the whole encounter's engine.
    if a.has("copied_view"):return a["copied_view"]
    if a.get("boss_moves_version")==4:return BossMoveEffectsP3.view(id)
    return TacticalMoves.definition(TacticalMoves.key_for(id))
static func enemy_math(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    var a:=source.duplicate(true);var id:=int(a.get("effective_move",a["move_id"]));var raw:=TacticalMoves.definition(TacticalMoves.key_for(id))
    var detail:=enemy_move(a,id)
    var actual_id:=int(detail.get("move_id",id))
    var status_blocked:=false
    for key:String in STATUS:
        if detail.has(key) and protected_status(b,p,key):status_blocked=true
    if status_blocked:a["effects"]=a.get("effects",[])+["필드/신비의부적 · 동료의 새 상태이상 차단"]
    if actual_id==281 and protected_status(b,p,"sleep"):
        a["player_sealed"]=true;a["value"]=0;a["effects"]=a.get("effects",[])+["필드/신비의부적 · 새 하품 예약 차단"]
        return a
    if detail.get("stat_target")=="enemy" and detail.has("stat_changes") and read(b)["ally"]["mist"]>0:a["effects"]=a.get("effects",[])+["흰안개 · 상대에 의한 음수 능력 단계 변화 차단"]
    if id==156 and grounded(b,b.enemy()) and read(b)["terrain"] in ["electric","misty"]:a["player_sealed"]=true;a["value"]=0;return a
    var attack:bool=a.get("damage_class",raw.get("damage_class","status"))!="status" and a["kind"] not in ["prepare","recharge","wait","guard","block","fortify","boost","recover","status"]
    if not attack or a.get("asleep",false) or a.get("failed_move",false) or a.get("failed_charge",false):return a
    if actual_id in data()["positive_priority"] and read(b)["terrain"]=="psychic" and grounded(b,p):
        a["player_sealed"]=true;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        a["effects"]=a.get("effects",[])+["사이코필드 · 접지 동료에 대한 선공 공격 차단"]
        return a
    if id==798 and read(b)["terrain"].is_empty():a["player_sealed"]=true;a["value"]=0;return a
    var m:Dictionary=detail.duplicate(true)
    m["type"]=a.get("type",m.get("type","normal"));m["damage_class"]=a.get("damage_class",m.get("damage_class","physical"))
    if m.has("move_power") and (read(b)["wonder"]>0 or actual_id in [805,797,804,802]):
        m["move_power"]=int(a.get("base_power",m["move_power"]));m=attack_view(b,b.enemy(),p,m)
        if id==76 and BattleWeather.kind(b.powers) in ["rain","snow","sand"]:m["move_power"]=int(m["move_power"])/2
        var actor:=room_clone(b,PlayerMoveExchange.clone(b.enemy()));var target:=room_clone(b,PlayerMoveExchange.clone(p));var pressure:=1.0
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
        var n:=int(a["fixed_damage"]) if a.has("fixed_damage") else PokemonStats.damage(actor,target,m,affinity,0,pressure,BattleWeather.kind(b.powers),str(a.get("offense_stat","")))
        a["immune"]=affinity<=0;a["type"]=m["type"]
        if a.has("per_hit"):a["per_hit"]=n
        a["value"]=n*int(a.get("hits",1))
    var scale:=factor(b,b.enemy(),p,m)
    if a.has("fixed_damage"):scale=1.0
    if scale!=1.0:
        if a.has("per_hit"):a["per_hit"]=maxi(1,floori(int(a["per_hit"])*scale)) if a["per_hit"]>0 else 0;a["value"]=int(a["per_hit"])*int(a.get("hits",1))
        else:a["value"]=maxi(1,floori(int(a["value"])*scale)) if a["value"]>0 else 0
    for i:int in a.get("effects",[]).size():
        if "대상 기절 시 남은 타격 중단" in str(a["effects"][i]) and a.has("per_hit"):a["effects"][i]="%d × %d회 · 대상 기절 시 남은 타격 중단" % [a["per_hit"],a.get("hits",1)]
    if not b.field_context.is_empty():a["effects"]=a.get("effects",[])+["공유 필드/룸·진영 효과 반영"]
    return a
static func entry_damage(b:TacticalBattle,p:BattlePokemon) -> int:
    var h:Dictionary=read(b)["hazards"];var types:Array=PlayerMoveExchange.read(b)["types"].get(p.uid,{}).get("base",p.types)
    var rocks:bool=h["rocks"]>0 and not (BossBattleRules.active_in(b) and BossBattleRules.read(b)["rocks"])
    var n:=maxi(1,floori(p.max_hp*TypeMatchup.multiplier("rock",types)/8.0)) if rocks else 0
    if grounded(b,p,true) and h["spikes"]>0:n+=maxi(1,p.max_hp/{1:8,2:6,3:4}[int(h["spikes"])])
    return n
static func on_switch(b:TacticalBattle) -> void:
    var p:=b.active();var h:Dictionary=read(b)["hazards"];var n:=entry_damage(b,p)
    if not p.alive():return
    if n>0:b._damage(p,n,true)
    if not p.alive() or not grounded(b,p):return
    if h["toxic"]>0:
        if "poison" in p.types:write(b)["hazards"]["toxic"]=0
        elif "steel" not in p.types and not protected_status(b,p,"poison") and PlayerMoveExchange.main_status(p).is_empty():p.statuses["poison"]={"turns":3 if h["toxic"]==1 else 5,"source_uid":b.enemy().uid}
    if h["web"]>0:p.stat_stages["speed"]=maxi(-6,int(p.stat_stages.get("speed",0))-1)
static func prevent_drops(b:TacticalBattle,p:BattlePokemon,before:Dictionary) -> void:
    if read(b)[side(p)]["mist"]==0:return
    for stat:String in before.keys()+p.stat_stages.keys():
        if int(p.stat_stages.get(stat,0))<int(before.get(stat,0)):p.stat_stages[stat]=int(before.get(stat,0))
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,before:Dictionary,foe_before:Dictionary,stages:Dictionary) -> void:
    prevent_status(b,p,before);prevent_status(b,foe,foe_before)
    var mid:=int(a.get("effective_move",a["move_id"]))
    var detail:=enemy_move(a,mid)
    if p==b.active() and detail.get("stat_target")=="enemy" and detail.has("stat_changes"):prevent_drops(b,p,stages)
    var acted:bool=not a.get("player_sealed",false) and not a.get("asleep",false) and not a.get("failed_move",false) and not a.get("failed_charge",false) and not a.get("immune",false)
    var id:=int(a.get("effective_move",a["move_id"]))
    if acted and id in [798,861]:write(b)["terrain"]="";write(b)["left"]=0
    if acted and id==802 and foe.alive():b._damage(foe,foe.hp,true)
    var c:=write(b)
    if c["terrain"]=="grassy":
        for actor:BattlePokemon in [p,foe]:
            if not actor.alive() or not grounded(b,actor) or (actor.uid<0 and PlayerMoveTactics.read(b)["heal_block"].get(actor.uid,0)>=b.turn):continue
            var n:=mini(actor.max_hp-actor.hp,maxi(1,actor.max_hp/16));actor.hp+=n
            if n>0:b._record("heal",actor.display_name+" · 그래스필드",{"target":actor.uid,"amount":n})
    for key:String in ["trick","wonder","mud","water","left"]:c[key]=maxi(0,int(c[key])-1)
    if c["left"]==0:c["terrain"]=""
    for s:String in ["ally","foe"]:
        for key:String in SIDE:c[s][key]=maxi(0,int(c[s][key])-1)
static func valid_context(c:Variant) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size() or c.get("terrain") not in ["","electric","grassy","misty","psychic"]:return false
    for key:String in ["left","trick","wonder","mud","water"]:
        if not c.get(key) is int or c[key]<0 or c[key]>5:return false
    if (c["terrain"].is_empty())!=(c["left"]==0):return false
    for s:String in ["ally","foe"]:
        if not c.get(s) is Dictionary or c[s].size()!=SIDE.size():return false
        for key:String in SIDE:
            if not c[s].get(key) is int or c[s][key]<0 or c[s][key]>6:return false
    if not c.get("hazards") is Dictionary or c["hazards"].size()!=4:return false
    for key:String in HAZARDS:
        if not c["hazards"].get(key) is int or c["hazards"][key]<0 or c["hazards"][key]>{"rocks":1,"spikes":3,"toxic":2,"web":1}[key]:return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveExchange.lines(v)
    if v.has("field_rule"):rows.push_front({"court":"양쪽 진영 효과 교환","trick":"느린 쪽 에너지 우대","wonder":"피해 계산 방어·특방 교환","electric":"전기 강화 · 수면 차단","grassy":"풀 강화 · 접지 회복","misty":"상태 방어 · 드래곤 반감","psychic":"에스퍼 강화 · 선공 차단","pulse":"필드 타입 · 위력2배","expanding":"사이코필드 위력 증가","voltage":"전기필드 위력2배","glide":"그래스필드 비용-1","roller":"필드 필요 · 필드 제거","explosion":"공격 후 사용자 기절","spinner":"명중 시 필드 제거","defog":"진영 설치·장막·필드 제거","tailwind":"4턴 에너지 비교 속도2배","veil":"눈 필요 · 양쪽 공격 반감","mist":"5턴 상대 단계 감소 차단","mud":"양쪽 전기 피해⅓","water":"양쪽 불꽃 피해⅓"}[v["field_rule"]])
    return rows.slice(0,5)
