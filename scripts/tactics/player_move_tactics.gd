class_name PlayerMoveTactics
extends RefCounted
## Additional mechanics for route v11 only; this state is separate from frozen v10.
const PATH:="res://data/player_move_tactics_v11.json"
const DEFAULT:Dictionary={"hazards":{"rocks":0,"spikes":0,"toxic":0,"web":0},"binds":{},"taunt":{},"encore":{},"disable":{},"torment":{},"heal_block":{},"last":{},"pushed":{},"pass":{}}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.technique_context if not b.technique_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.technique_context.is_empty():b.technique_context=DEFAULT.duplicate(true)
    return b.technique_context
static func definition(key:String) -> Dictionary:
    var result:=PlayerMoveCards.definition(key)
    if result.is_empty():return result
    var overlay:Dictionary=data()["moves"].get(str(result["move_id"]),{})
    if not overlay.is_empty():
        result=overlay.duplicate(true);result["move_id"]=int(result["move_id"])
        if result.has("stat_changes"):
            for stat:String in result["stat_changes"]:result["stat_changes"][stat]=int(result["stat_changes"][stat])
    result["player_rules"]=3;result["description"]=TacticalContent.description(result)
    return result
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if not v.has("extension"):return v
    var tag:String=v["extension"];var target:=b.enemy();var blocked:=false
    if tag in ["push","bind","taunt","encore","disable","torment","heal_block","split","sap"] and BossBattleRules.active_in(b):
        var proxy:=v.duplicate(true);proxy["pulse_status"]=true
        blocked=BossBattleEffectsP3.protected(b,proxy) if BossBattleRules.modern(b) else BossBattleEffects.protected(b,proxy)
        if BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy):blocked=true
        if BossBattleRules.read(b)["substitutes"].get(target.uid,0)>0 and not PlayerMoveCards.flag(int(v["move_id"]),9) and not PlayerMoveCards.flag(int(v["move_id"]),14):blocked=true
    v["extension_blocked"]=blocked
    if blocked:v["card_notes"].append("상대의 보호/대타/공중으로 이 대상 효과 차단")
    if tag=="sap":v["preview_sap"]=mini(p.max_hp-p.hp,heal_amount(b,PokemonStats.effective(target,"attack"))) if not blocked else 0
    if tag=="split":
        var average:=(p.hp+target.hp)/2
        v["preview_split_self"]=p.hp+heal_amount(b,maxi(0,mini(p.max_hp,average)-p.hp)) if average>p.hp else average
        v["preview_split_foe"]=mini(target.max_hp,average)
        if blocked:v["preview_split_self"]=p.hp;v["preview_split_foe"]=target.hp
    if tag in ["rocks","spikes","toxic","web"]:v["card_notes"].append("현재 겹수%d" % int(read(b)["hazards"][tag]))
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var tag:String=v.get("extension","");var c:=read(b)
    if tag in ["rocks","spikes","toxic","web"] and c["hazards"][tag]>={"rocks":1,"spikes":3,"toxic":2,"web":1}[tag]:return "이미 최대 겹수로 설치했습니다."
    if tag in ["encore","disable"] and not c["last"].has(b.enemy().uid):return "상대가 기술을 사용한 뒤 사용할 수 있습니다."
    if tag=="push":
        if c["pushed"].get(b.enemy().uid,0)==b.turn:return "이번 턴 이 상대의 예고를 이미 밀어냈습니다."
        if b.enemy_definitions[b.enemy_index]["intents"].size()<2:return "밀어낼 다음 전술이 없습니다."
    if tag=="sap" and int(b.enemy().stat_stages.get("attack",0))<=-6:return "상대 공격이 이미 최저 단계입니다."
    if tag in ["pivot","baton","shed"]:
        if not b.party.any(func(a:BattlePokemon):return a!=p and a.alive()):return "교대할 살아 있는 동료가 없습니다."
        if p==b.active() and (PlayerMoveRules.rooted(b) or (BossBattleRules.active_in(b) and BossBattleRules.trapped(b))):return "구속/뿌리박기 중에는 교대 기술을 사용할 수 없습니다."
        if tag=="shed" and (p.hp<=maxi(1,p.max_hp/2) or PlayerMoveRules.read(b)["substitutes"].get(p.uid,0)>0):return "꼬리자르기는 HP가 절반보다 많고 기존 대타가 없어야 합니다."
    return ""
static func on_card(b:TacticalBattle,v:Dictionary,_p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("extension")=="sap":v["sap_amount"]=PokemonStats.effective(target,"attack")
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if not v.has("extension") or v.get("preparing",false):return
    var c:=write(b);var tag:String=v["extension"]
    var affected:bool=target.alive() and not v.get("extension_blocked",false) and not v.get("boss_blocked",false) and not v.get("failed",false) and (not v.has("damage") or b.multiplier(str(v["type"]),target)>0)
    match tag:
        "rocks","spikes","toxic","web":
            c["hazards"][tag]=mini(int(c["hazards"][tag])+1,{"rocks":1,"spikes":3,"toxic":2,"web":1}[tag])
            b._record("field",str(v["name"])+" · 다음 상대 입장부터 적용")
        "clear":
            if not v.get("boss_blocked",false):c["hazards"]=DEFAULT["hazards"].duplicate()
        "bind":
            if affected:c["binds"][target.uid]={"source":p.uid,"until":b.turn+3}
        "taunt","torment","heal_block":
            if affected:c[tag][target.uid]=b.turn+{"taunt":2,"torment":3,"heal_block":4}[tag]
        "encore","disable":
            if affected:c[tag][target.uid]={"move":c["last"][target.uid],"until":b.turn+(2 if tag=="encore" else 3)}
        "push":
            if affected:
                b.opening()["intent"]+=1;c["pushed"][target.uid]=b.turn
                for key:String in ["effects_v4","effects_v3","effects_v2"]:
                    if b.opening().has(key):b.opening()[key].merge({"charge":0,"recharge":false,"lock":0,"lock_left":0},true)
                if b.boss_context.has("airborne"):b.boss_context["airborne"].erase(target.uid)
                b._record("field","전술 밀어내기 · 상대 다음 예고 · 파티 순서 유지")
        "pivot","baton","shed":
            if (int(v["move_id"])!=575 or affected) and p.alive():
                PlayerMoveRules.write(b)["pivot"]={"uid":p.uid,"turn":b.turn}
                if tag=="shed":
                    b._damage(p,maxi(1,p.max_hp/2),true)
                    PlayerMoveRules.write(b)["substitutes"][p.uid]=maxi(1,p.max_hp/4)
                if tag in ["baton","shed"]:
                    c["pass"]={"source":p.uid,"turn":b.turn,"stages":p.stat_stages.duplicate() if tag=="baton" else {},"substitute":int(PlayerMoveRules.read(b)["substitutes"].get(p.uid,0))}
        "sap":
            if affected:heal(b,p,int(v["sap_amount"]))
        "split":
            if affected:
                var average:=(p.hp+target.hp)/2
                adjust(b,p,mini(p.max_hp,average));adjust(b,target,mini(target.max_hp,average))
    if tag not in ["spin","clear"]:b._record("field",str(v["name"])+(" · 대상 효과 차단" if not affected and tag in ["push","bind","taunt","encore","disable","torment","heal_block","split","sap"] else " · 카드 효과 적용"))
static func heal_amount(b:TacticalBattle,n:int) -> int:return floori(n*0.5) if b.has_relic("shield_core") else n
static func heal(b:TacticalBattle,p:BattlePokemon,n:int) -> void:
    if not p.alive():return
    var amount:=mini(p.max_hp-p.hp,heal_amount(b,n) if p.uid>0 else n);p.hp+=amount
    if amount>0:b._record("heal",p.display_name+" · 기술 회복",{"target":p.uid,"amount":amount})
static func adjust(b:TacticalBattle,p:BattlePokemon,n:int) -> void:
    if n<p.hp:b._damage(p,p.hp-n,true)
    elif n>p.hp:heal(b,p,n-p.hp)
static func on_switch(b:TacticalBattle,old:int) -> void:
    var c:=write(b)
    for uid:int in c["binds"].keys():
        if c["binds"][uid]["source"]==old:c["binds"].erase(uid)
    var transfer:Dictionary=c["pass"];c["pass"]={}
    if transfer.get("source",0)!=old or transfer.get("turn",0)!=b.turn:return
    var p:=b.active()
    for stat:String in transfer["stages"]:p.stat_stages[stat]=int(transfer["stages"][stat])
    if transfer["substitute"]>0:PlayerMoveRules.write(b)["substitutes"][p.uid]=int(transfer["substitute"])
    b._record("field",p.display_name+" · 교대 효과 인계",{"target":p.uid})
static func end_player(b:TacticalBattle) -> void:
    write(b)["pass"]={}
static func enemy_preview(b:TacticalBattle,source:Dictionary) -> Dictionary:
    var a:=source.duplicate(true);var c:=read(b);var uid:=b.enemy().uid;var id:=int(a.get("effective_move",a["move_id"]))
    var raw:=TacticalMoves.visual(id);var status:bool=raw.get("category",2)==1 or a["kind"] in ["guard","prepare","recharge","wait","block","boost","fortify","recover","status"] and a.get("damage_class","status")=="status"
    var why:=""
    if c["taunt"].get(uid,0)>=b.turn and status:why="도발 · 변화 기술 봉인"
    if c["encore"].get(uid,{}).get("until",0)>=b.turn and c["encore"][uid]["move"]!=id:why="앙코르 · 직전 기술만 허용"
    if c["disable"].get(uid,{}).get("until",0)>=b.turn and c["disable"][uid]["move"]==id:why="사슬묶기 · 이 기술 봉인"
    if c["torment"].get(uid,0)>=b.turn and c["last"].get(uid,0)==id:why="트집 · 연속 성공 금지"
    var healing:bool=a["kind"]=="recover" or int(raw.get("healing",0))>0
    if c["heal_block"].get(uid,0)>=b.turn and healing:why="회복봉인 · 회복 기술 사용 불가"
    if not why.is_empty():
        a["player_sealed"]=true;a["value"]=0;a["advance"]=1
        if a.has("per_hit"):a["per_hit"]=0
        if not a.has("effects"):a["effects"]=[]
        a["effects"].append(why);a["restriction"]=why
    return a
static func limit_healing(b:TacticalBattle,foe:BattlePokemon,hp_before:int) -> void:
    var c:=read(b);var uid:=foe.uid
    if foe.alive() and c["heal_block"].get(uid,0)>=b.turn and foe.hp>hp_before:
        var restored:=foe.hp-hp_before;foe.hp=hp_before
        b._record("field","회복봉인 · HP 증가 차단",{"target":uid,"amount":restored})
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,a:Dictionary,hp_before:int) -> void:
    limit_healing(b,foe,hp_before)
    var c:=write(b);var uid:=foe.uid
    if not a.get("player_sealed",false) and not a.get("asleep",false) and not a.get("failed_move",false) and not a.get("failed_charge",false):c["last"][uid]=int(a.get("effective_move",a["move_id"]))
    var bound:Dictionary=c["binds"].get(uid,{})
    if not bound.is_empty():
        var owner:=b.member(int(bound["source"]))
        if bound["until"]<b.turn or owner==null or not owner.alive() or owner!=b.active():c["binds"].erase(uid)
        elif foe.alive():
            b._damage(foe,maxi(1,foe.max_hp/8),true)
            b._record("field",foe.display_name+" · 구속 지속 피해",{"target":uid})
    c["pass"]={}
static func enter_enemy(b:TacticalBattle) -> void:
    var p:=b.enemy();var c:=read(b);var h:Dictionary=c["hazards"]
    if h.values().all(func(v:Variant):return v==0):return
    var grounded:bool="flying" not in p.types or b.boss_context.get("gravity",0)>0
    var amount:=maxi(1,floori(p.max_hp*TypeMatchup.multiplier("rock",p.types)/8.0)) if h["rocks"]>0 else 0
    if grounded and h["spikes"]>0:amount+=maxi(1,p.max_hp/{1:8,2:6,3:4}[int(h["spikes"])])
    if amount>0:b._damage(p,amount,true)
    if not p.alive():return
    if grounded and h["toxic"]>0:
        if "poison" in p.types:write(b)["hazards"]["toxic"]=0;b._record("field",p.display_name+" · 독압정 흡수")
        elif "steel" not in p.types and not ["burn","poison","sleep","paralysis"].any(func(k:String):return p.statuses.has(k)):p.statuses["poison"]={"turns":3 if h["toxic"]==1 else 5,"source_uid":b.active().uid}
    if grounded and h["web"]>0:p.stat_stages["speed"]=maxi(-6,int(p.stat_stages.get("speed",0))-1)
    b._record("field",p.display_name+" · 상대 필드 설치 효과",{"target":p.uid})
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.get(key) is Dictionary:return false
    if c["hazards"].size()!=4:return false
    for key:String in DEFAULT["hazards"]:
        if not c["hazards"].get(key) is int or c["hazards"][key]<0 or c["hazards"][key]>{"rocks":1,"spikes":3,"toxic":2,"web":1}[key]:return false
    for key:String in ["binds","taunt","encore","disable","torment","heal_block","last","pushed"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in b["enemies"]:return false
            var v:Variant=c[key][uid]
            if key=="binds":
                if not v is Dictionary or v.size()!=2 or not v.get("source") is int or v["source"] not in b["party"] or not valid_turn(v.get("until"),b,3):return false
            elif key in ["encore","disable"]:
                if not v is Dictionary or v.size()!=2 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not valid_turn(v.get("until"),b,3):return false
            elif key=="last":
                if not v is int or TacticalMoves.visual(v).is_empty():return false
            elif not valid_turn(v,b,4 if key=="heal_block" else 3):return false
    var pass_state:Dictionary=c["pass"]
    if not pass_state.is_empty():
        if pass_state.size()!=4 or not pass_state.get("source") is int or pass_state["source"] not in b["party"] or not valid_turn(pass_state.get("turn"),b,0) or not pass_state.get("substitute") is int or pass_state["substitute"]<0 or pass_state["substitute"]>25000 or not pass_state.get("stages") is Dictionary:return false
        if pass_state["source"]!=b["party"][b["active_index"]] or pass_state["turn"]!=b["turn"]:return false
        for key:Variant in pass_state["stages"]:
            if key not in ["attack","defense","special_attack","special_defense","speed"] or not pass_state["stages"][key] is int or absi(pass_state["stages"][key])>6:return false
    return true
static func valid_turn(n:Variant,b:Dictionary,ahead:int) -> bool:return n is int and n>=1 and n<=b["turn"]+ahead
