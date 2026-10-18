class_name PlayerMoveItemMath
extends RefCounted
## v17: generated frozen math with an explicit move ID and corrected air exception.
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
    return PokemonStats.damage(attacker,defender,v,affinity,bonus,pressure,BattleWeather.kind(b.powers),offense,override)
static func enemy_rules(b:TacticalBattle,p:BattlePokemon,original:Dictionary) -> Dictionary:
    var a:=original.duplicate(true);var c:=PlayerMoveRules.read(b);var raw:=TacticalMoves.visual(int(a.get("effective_move",a.get("move_id",0))))
    var attack:bool=a.get("damage_class","status")!="status" or a["kind"] in ["attack","charge","barrage"]
    var targeted:bool=attack or (not raw.is_empty() and int(raw.get("target",7)) not in [4,7,12,13] and a["kind"] not in ["guard","prepare","recharge","wait","block","fortify","boost","recover"])
    var mode:=PlayerMoveRules.guard(b,p)
    var mid:=int(a.get("copied_view",{}).get("move_id",a.get("effective_move",a.get("move_id",0))))
    var sealed:Dictionary=c["seals"].get(b.enemy().uid,{})
    if (c["silence"].get(b.enemy().uid,0)>=b.turn and PlayerMoveCards.flag(mid,9)) or (sealed.get("until",0)>=b.turn and sealed.get("move",0)==mid):
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
