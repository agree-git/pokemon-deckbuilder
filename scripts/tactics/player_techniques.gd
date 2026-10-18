class_name PlayerTechniques
extends RefCounted
## Version dispatch keeps published v10 engines and definitions unchanged.
static func version(route:int) -> int:return 3 if route>=11 else (2 if route>=10 else 1)
static func active(b:TacticalBattle) -> bool:return b.player_moves_version>=2
static func definition(key:String,v:int) -> Dictionary:return PlayerMoveTactics.definition(key) if v==3 else PlayerMoveCards.definition(key)
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    var result:=PlayerMoveCards.prepare(b,p,v)
    if b.player_moves_version==3 and result.get("sleep_call",false):
        var overlay:Dictionary=PlayerMoveTactics.data()["moves"].get(str(result["move_id"]),{})
        if not overlay.is_empty():
            result["extension"]=overlay["extension"]
            if overlay.has("poison"):result["poison"]=int(overlay["poison"])
            result["card_notes"].append_array(overlay["card_notes"])
            result=PlayerMoveCards.prepare(b,p,result)
    return PlayerMoveTactics.prepare(b,p,result) if b.player_moves_version==3 else result
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var why:=PlayerMoveRules.reason(b,p,v)
    return why if not why.is_empty() or b.player_moves_version!=3 else PlayerMoveTactics.reason(b,p,v)
static func enemy_preview(b:TacticalBattle,p:BattlePokemon,a:Dictionary) -> Dictionary:
    var result:=PlayerMoveRules.enemy_preview(b,p,a)
    return PlayerMoveTactics.enemy_preview(b,result) if b.player_moves_version==3 else result
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    PlayerMoveRules.on_card(b,v,p,target)
    if b.player_moves_version==3:PlayerMoveTactics.on_card(b,v,p,target)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    var base:=v
    if b.player_moves_version==3 and v.get("extension")=="clear" and v.get("boss_blocked",false):
        base=v.duplicate(true);base.erase("special")
    PlayerMoveRules.after_card(b,base,p,target)
    if b.player_moves_version==3:PlayerMoveTactics.after_card(b,v,p,target)
static func on_switch(b:TacticalBattle,old:int) -> void:
    PlayerMoveRules.on_switch(b,old)
    if b.player_moves_version==3:PlayerMoveTactics.on_switch(b,old)
static func lines(v:Dictionary) -> Array[String]:
    var result:=PlayerMoveCards.lines(v)
    if v.get("player_rules")==3 and v.has("extension"):
        var title:String={"push":"상대 예고 한 칸 밀기","pivot":"이번 턴 교대 무료","baton":"단계·대타 인계","shed":"HP½ 소비 · 대타 인계","rocks":"입장 피해 · 바위 상성","spikes":"입장 피해 · 압정","toxic":"입장 시 독","web":"입장 시 스피드-1","bind":"4회 구속 · 매회HP⅛","taunt":"변화기3턴 봉인","encore":"직전 기술만 허용","disable":"직전 기술4턴 봉인","torment":"같은 기술 연속 금지","heal_block":"회복5턴 봉인","split":"양쪽 HP 평균","sap":"상대 공격만큼 회복","clear":"설치·장막 제거","spin":"자기 설치·구속 해제"}[v["extension"]]
        if result==["상세 규칙은 툴팁"]:result.clear()
        result.push_front(title)
        if v.has("preview_sap"):result.insert(1,"HP 회복 %d" % int(v["preview_sap"]))
        if v.has("preview_split_self"):
            result.insert(1,"자신HP → %d" % int(v["preview_split_self"]))
            result.insert(2,"상대HP → %d" % int(v["preview_split_foe"]))
        if v.has("weather"):result.append("눈 날씨5턴")
    return result.slice(0,5)
