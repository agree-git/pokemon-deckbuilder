class_name PlayerCompletionHooks
extends RefCounted
## v27: passive move healing respects the existing healing block.
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
        for group:String in (["roots","rings"] if not PlayerMoveCompletion.healing_blocked(b,p) else []):
            if c[group].get(p.uid,false):
                var amount:=maxi(1,p.max_hp/16)
                if b.has_relic("shield_core"):amount=floori(amount*0.5)
                amount=mini(p.max_hp-p.hp,amount);p.hp+=amount
                if amount>0:b._record("heal",p.display_name+" · 지속 회복",{"target":p.uid,"amount":amount})
    if c["charges"].has(p.uid):
        var charge_id:=int(c["charges"][p.uid]["move"])
        if PlayerMoveCards.data()["moves"][str(charge_id)].get("charge")=="air" and ((int(a.get("move_id",0)) in [479,615]) or b.boss_context.get("gravity",0)>0):c["charges"].erase(p.uid)
    var contact:bool=PlayerMoveAdaptive.contact(a) and not a.get("player_sealed",false) and not a.get("player_airborne",false) and not a.get("asleep",false) and not a.get("powdered",false) and not a.has("bulk_cancel") and a["kind"] not in ["prepare","recharge","wait"]
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
static func start_player(b:TacticalBattle) -> void:
    var c:=PlayerMoveRules.write(b)
    for uid:int in c["wishes"].keys():
        var p:=b.member(uid)
        if c["wishes"][uid]["due"]>b.turn:continue
        var amount:=int(c["wishes"][uid]["amount"]);c["wishes"].erase(uid)
        if p==null or not p.alive() or PlayerMoveCompletion.healing_blocked(b,p):continue
        if b.has_relic("shield_core"):amount=floori(amount*0.5)
        amount=mini(p.max_hp-p.hp,amount);p.hp+=amount
        if amount>0:b._record("heal",p.display_name+" · 소원 회복",{"target":uid,"amount":amount})
