class_name PlayerTechniques
extends RefCounted
## Version dispatch keeps published v10 engines and definitions unchanged.
static func version(route:int) -> int:return 14 if route>=22 else 13 if route>=21 else 12 if route>=20 else 11 if route>=19 else 10 if route>=18 else 9 if route>=17 else 8 if route>=16 else 7 if route>=15 else 6 if route>=14 else 5 if route>=13 else (4 if route>=12 else (3 if route>=11 else (2 if route>=10 else 1)))
static func active(b:TacticalBattle) -> bool:return b.player_moves_version>=2
static func definition(key:String,v:int) -> Dictionary:return PlayerMoveTraining.definition(key) if v==14 else HeldItems.definition(key) if v==13 else PlayerMoveReactions.definition(key) if v==12 else PlayerMoveFate.definition(key) if v==11 else PlayerMoveAssist.definition(key) if v==10 else PlayerMoveItems.definition(key) if v==9 else PlayerMoveTraps.definition(key) if v==8 else PlayerMoveAltitude.definition(key) if v==7 else PlayerMoveSeals.definition(key) if v==6 else PlayerMoveFields.definition(key) if v==5 else (PlayerMoveExchange.definition(key) if v==4 else (PlayerMoveTactics.definition(key) if v==3 else PlayerMoveCards.definition(key)))
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if b.player_moves_version>=5:v=PlayerMoveFields.expand(b,p,v)
    elif b.player_moves_version==4:v=PlayerMoveExchange.expand(b,p,v)
    var result:=PlayerMoveCards.prepare(b,p,v)
    if b.player_moves_version>=3 and result.get("sleep_call",false):
        var overlay:Dictionary=PlayerMoveTactics.data()["moves"].get(str(result["move_id"]),{})
        if not overlay.is_empty():
            result["extension"]=overlay["extension"]
            if overlay.has("poison"):result["poison"]=int(overlay["poison"])
            result["card_notes"].append_array(overlay["card_notes"])
            result=PlayerMoveCards.prepare(b,p,result)
        if b.player_moves_version>=4:
            var extra_rule:Dictionary=PlayerMoveExchange.data()["moves"].get(str(result["move_id"]),{})
            if not extra_rule.is_empty():
                result["exchange"]=extra_rule["exchange"];result["card_notes"].append_array(extra_rule["card_notes"])
    if b.player_moves_version>=3:result=PlayerMoveTactics.prepare(b,p,result)
    if b.player_moves_version>=4:result=PlayerMoveExchange.prepare(b,p,result)
    if b.player_moves_version>=7:result=PlayerMoveAirFields.prepare(b,p,result)
    elif b.player_moves_version>=5:result=PlayerMoveFields.prepare(b,p,result)
    if b.player_moves_version>=6:result=PlayerMoveSeals.prepare(b,result)
    if b.player_moves_version>=7:result=PlayerMoveAltitude.prepare(b,p,result)
    if b.player_moves_version>=8:result=PlayerMoveTraps.prepare(b,p,result)
    if b.player_moves_version>=9:result=PlayerMoveItems.prepare(b,p,result)
    if b.player_moves_version>=10:result=PlayerMoveAssist.prepare(b,p,result)
    if b.player_moves_version>=11:result=PlayerMoveFate.prepare(b,p,result)
    if b.player_moves_version>=12:result=PlayerMoveReactions.prepare(b,result)
    if b.player_moves_version>=13:result=HeldItems.prepare(b,p,result)
    return PlayerMoveTraining.prepare(p,result) if b.player_moves_version>=14 else result
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var why:=PlayerMoveRules.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=3:why=PlayerMoveTactics.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=4:why=PlayerMoveExchange.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=7:why=PlayerMoveAltitude.reason(b,p,v)
    elif why.is_empty() and b.player_moves_version>=5:why=PlayerMoveFields.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=6 and p!=b.active() and PlayerMoveSeals.locked(b,b.active()):why="페어리록 중에는 기술 카드로 자동 교대할 수 없습니다."
    if why.is_empty() and b.player_moves_version>=8:why=PlayerMoveTraps.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=9:why=PlayerMoveItems.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=10:why=PlayerMoveAssist.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=11:why=PlayerMoveFate.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=13:why=HeldItems.reason(b,p,v)
    if why.is_empty() and b.player_moves_version>=14:why=PlayerMoveTraining.reason(p,v)
    return why
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> Dictionary:
    var conversion:bool=b.player_moves_version>=12 and PlayerMoveReactions.conversion(b,b.enemy())
    if b.player_moves_version>=4:a=HeldItemMath.enemy_exchange(b,p,a) if b.player_moves_version>=13 else PlayerMoveExchange.enemy_math(b,p,a)
    if b.player_moves_version>=7:
        a=PlayerMoveAltitude.enemy_preview(b,a)
        a=HeldItemMath.enemy_field(b,p,a) if b.player_moves_version>=13 else PlayerMoveReactionMath.field_math(b,p,a) if conversion else PlayerMoveAirFields.enemy_math(b,p,a)
        a=HeldItemMath.enemy_critical(b,p,a) if b.player_moves_version>=13 else PlayerMoveReactionMath.critical_math(b,p,a) if conversion else PlayerMoveAirFields.enemy_critical(b,p,a)
    else:
        if b.player_moves_version>=5:a=PlayerMoveFields.enemy_math(b,p,a)
        if b.player_moves_version>=6:a=PlayerMoveSeals.enemy_math(b,p,a)
    if b.player_moves_version>=9:a=HeldItemMath.enemy_arrow(b,p,a) if b.player_moves_version>=13 else PlayerMoveReactionMath.arrow_math(b,p,a) if conversion else PlayerMoveItems.enemy_math(b,p,a)
    var result:=PlayerMoveItemMath.enemy_rules(b,p,a) if b.player_moves_version>=9 else PlayerMoveRules.enemy_preview(b,p,a)
    if b.player_moves_version>=3:result=PlayerMoveTactics.enemy_preview(b,result)
    if b.player_moves_version>=8:result=PlayerMoveTraps.enemy_preview(b,p,result)
    return PlayerMoveReactions.enemy_preview(b,result) if b.player_moves_version>=12 else result
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    PlayerMoveRules.on_card(b,v,p,target)
    if b.player_moves_version>=3:PlayerMoveTactics.on_card(b,v,p,target)
    if b.player_moves_version>=4:PlayerMoveExchange.on_card(b,v,p,target)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var base:=v
    if b.player_moves_version>=3 and v.get("extension")=="clear" and v.get("boss_blocked",false):
        base=v.duplicate(true);base.erase("special")
    if b.player_moves_version>=13 and v.has("damage"):
        base=base.duplicate(true);base["target_hp_before"]=target.hp+int(b.held_attack.get("loss",0))
    PlayerMoveRules.after_card(b,base,p,target)
    if b.player_moves_version>=3:PlayerMoveTactics.after_card(b,v,p,target)
    if b.player_moves_version>=4:PlayerMoveExchange.after_card(b,v,p,target)
    if b.player_moves_version>=5:PlayerMoveFields.after_card(b,v,p,target)
    if b.player_moves_version>=6:PlayerMoveSeals.after_card(b,v)
    if b.player_moves_version>=7:PlayerMoveAltitude.after_card(b,v,p,target)
    if b.player_moves_version>=8:PlayerMoveTraps.after_card(b,v,p,target)
    if b.player_moves_version>=9:PlayerMoveItems.after_card(b,v,p,target)
    if b.player_moves_version>=10:PlayerMoveAssist.after_card(b,v,p,target)
    if b.player_moves_version>=11:PlayerMoveFate.after_card(b,v,p,target)
    if b.player_moves_version>=12:PlayerMoveReactions.after_card(b,v,target)
    if b.player_moves_version>=14:PlayerMoveTraining.after_card(b,v,p)
    if b.player_moves_version>=13:HeldItems.after_card(b,v,p,target)
static func on_switch(b:TacticalBattle,old:int) -> void:
    if b.player_moves_version>=10:PlayerMoveAssist.on_switch(b,old)
    if b.player_moves_version>=9:PlayerMoveItems.on_switch(b,old)
    if b.player_moves_version>=8:PlayerMoveTraps.on_switch(b,old)
    if b.player_moves_version>=7:PlayerMoveAltitude.on_switch(b,old)
    PlayerMoveRules.on_switch(b,old)
    if b.player_moves_version>=3:PlayerMoveTactics.on_switch(b,old)
    if b.player_moves_version>=4:PlayerMoveExchange.on_switch(b,old)
    if b.player_moves_version>=7:PlayerMoveAirFields.on_switch(b)
    elif b.player_moves_version>=5:PlayerMoveFields.on_switch(b)
    if b.player_moves_version>=11:PlayerMoveFate.on_switch(b,old)
    if b.player_moves_version>=12:PlayerMoveReactions.on_switch(b,old)
    if b.player_moves_version>=13:HeldItems.on_switch(b,old)
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    var n:=0
    if b.player_moves_version>=13:n=HeldItems.player_damage(b,p,target,v,bonus)
    elif b.player_moves_version>=9 and int(v.get("move_id",0))==614:n=PlayerMoveItems.raw_damage(b,p,target,v,bonus)
    elif b.player_moves_version>=7:n=PlayerMoveAirFields.raw_damage(b,p,target,v,bonus)
    elif b.player_moves_version>=5:n=PlayerMoveFields.raw_damage(b,p,target,v,bonus)
    else:n=PlayerMoveExchange.raw_damage(b,p,target,v,bonus) if b.player_moves_version>=4 else PlayerMoveCards.raw_damage(b,p,target,v,bonus)
    return PlayerMoveAssist.damage(v,n) if b.player_moves_version>=10 else n
static func lines(v:Dictionary) -> Array[String]:
    if v.get("player_rules")==14:return PlayerMoveTraining.lines(v)
    if v.get("player_rules")==13:return HeldItems.lines(v)
    if v.get("player_rules")==12:return PlayerMoveReactions.lines(v)
    if v.get("player_rules")==11:return PlayerMoveFate.lines(v)
    if v.get("player_rules")==10:return PlayerMoveAssist.lines(v)
    if v.get("player_rules")==9:return PlayerMoveItems.lines(v)
    if v.get("player_rules")==8:return PlayerMoveTraps.lines(v)
    if v.get("player_rules")==7:return PlayerMoveAltitude.lines(v)
    if v.get("player_rules")==6:return PlayerMoveSeals.lines(v)
    if v.get("player_rules")==5:return PlayerMoveFields.lines(v)
    return PlayerMoveExchange.lines(v) if v.get("player_rules")==4 else legacy_lines(v)
static func legacy_lines(v:Dictionary) -> Array[String]:
    var result:=PlayerMoveCards.lines(v)
    if v.get("player_rules",1)>=3 and v.has("extension"):
        var title:String={"push":"상대 예고 한 칸 밀기","pivot":"이번 턴 교대 무료","baton":"단계·대타 인계","shed":"HP½ 소비 · 대타 인계","rocks":"입장 피해 · 바위 상성","spikes":"입장 피해 · 압정","toxic":"입장 시 독","web":"입장 시 스피드-1","bind":"4회 구속 · 매회HP⅛","taunt":"변화기3턴 봉인","encore":"직전 기술만 허용","disable":"직전 기술4턴 봉인","torment":"같은 기술 연속 금지","heal_block":"회복5턴 봉인","split":"양쪽 HP 평균","sap":"상대 공격만큼 회복","clear":"설치·장막 제거","spin":"자기 설치·구속 해제"}[v["extension"]]
        if result==["상세 규칙은 툴팁"]:result.clear()
        result.push_front(title)
        if v.has("preview_sap"):result.insert(1,"HP 회복 %d" % int(v["preview_sap"]))
        if v.has("preview_split_self"):
            result.insert(1,"자신HP → %d" % int(v["preview_split_self"]))
            result.insert(2,"상대HP → %d" % int(v["preview_split_foe"]))
        if v.has("weather"):result.append("눈 날씨5턴")
    return result.slice(0,5)
