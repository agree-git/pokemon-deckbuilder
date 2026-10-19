class_name HeldItems
extends RefCounted
## v21 official equipment. Ownership tokens keep permanent consumption separate from battle trades.
const PATH:="res://data/held_items_v21.json"
const DEFAULT:Dictionary={"originals":{},"owners":{},"used":{},"spent":{},"choice":{}}
static var _data:Dictionary={}
static var _evolvable:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func catalog() -> Dictionary:return data()["items"].duplicate(true)
static func active(b:TacticalBattle) -> bool:return b.player_moves_version>=13
static func allowed(key:String,route:int) -> bool:return TacticalContent.LEGACY_HELD_ITEMS.has(key) or (route>=21 and data()["items"].has(key))
static func legacy_context_items(b:Dictionary) -> bool:
    for pair:Array in [["item_context","base"],["item_context","spent"],["boss_context","removed_items"]]:
        var context:Variant=b.get(pair[0],{})
        if not context is Dictionary:return false
        var values:Variant=context.get(pair[1],{})
        if not values is Dictionary:return false
        for value:Variant in values.values():
            if value is String and not value.is_empty() and not TacticalContent.LEGACY_HELD_ITEMS.has(value):return false
    return true
static func reward_keys(route:int) -> Array:return data()["items"].keys() if route>=21 else TacticalContent.LEGACY_HELD_ITEMS.keys()
static func read(b:TacticalBattle) -> Dictionary:return b.held_context if not b.held_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.held_context.is_empty():b.held_context=DEFAULT.duplicate(true)
    return b.held_context
static func initialize(b:TacticalBattle) -> void:
    b.held_context=DEFAULT.duplicate(true);b.held_attack.clear()
    for p:BattlePokemon in b.party+b.enemies:
        if not p.held_item.is_empty():b.held_context["originals"][p.uid]=p.held_item;b.held_context["owners"][p.uid]=p.uid
static func item(b:TacticalBattle,p:BattlePokemon) -> Dictionary:
    var live:=PlayerMoveExchange.member(b,p.uid)
    return data()["items"].get(b.effective_item(live if live!=null else p),{})
static func species_ok(p:BattlePokemon,d:Dictionary) -> bool:return not d.has("species") or PokedexExpansion.species(p.species_id).get("dex_id",p.species_id) in d["species"]
static func can_evolve(p:BattlePokemon) -> bool:
    if _evolvable.is_empty():
        for e:Dictionary in PokedexExpansion.data()["evolutions"]:_evolvable[int(e["from"])]=true
    return _evolvable.has(p.species_id)
static func stats(b:TacticalBattle,p:BattlePokemon,ignore:=false) -> BattlePokemon:
    var d:Dictionary={} if ignore else item(b,p)
    if not d.has("stats") or not species_ok(p,d) or (d["rule"]=="eviolite" and not can_evolve(p)):return p
    var copy:=PlayerMoveExchange.clone(p)
    for key:String in d["stats"]:copy.battle_stats[key]=maxi(1,floori(int(p.battle_stats.get(key,PokemonStats.value(p.species_id,p.level,key)))*float(d["stats"][key])))
    return copy
static func effective(b:TacticalBattle,p:BattlePokemon,key:String) -> int:return PokemonStats.effective(stats(b,p),key)
static func speed(b:TacticalBattle,p:BattlePokemon,n:int) -> int:
    var d:=item(b,p)
    return maxi(1,floori(n*float(d.get("stats",{}).get("speed",1.0))))
static func calculate(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,affinity:float,bonus:=0,pressure:=1.0,weather:="",offense:="",override:=0) -> int:
    if not active(b):return PokemonStats.damage(p,target,v,affinity,bonus,pressure,weather,offense,override)
    var fling:bool=int(v.get("move_id",0))==374
    var n:=PokemonStats.damage(stats(b,p,fling),stats(b,target),v,affinity,bonus,pressure,weather,offense,override)
    if n<=0 or fling:return n
    var d:=item(b,p);var factor:=1.0
    match str(d.get("rule","")):
        "physical":factor=float(d["factor"]) if v.get("damage_class")=="physical" else 1.0
        "special":factor=float(d["factor"]) if v.get("damage_class")=="special" else 1.0
        "expert":factor=float(d["factor"]) if affinity>1 else 1.0
        "life":factor=float(d["factor"])
        "type":factor=float(d["factor"]) if species_ok(p,d) and v.get("type","normal") in d["types"] else 1.0
    return maxi(1,floori(n*factor))
static func player_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    var actor:=PlayerMoveFields.room_clone(b,p);var defender:=PlayerMoveFields.room_clone(b,target)
    var n:=HeldItemMath.arrow_base(b,actor,defender,v,bonus) if int(v["move_id"])==614 else HeldItemMath.player_base(b,actor,defender,v,bonus)
    return maxi(1,floori(n*PlayerMoveAirFields.factor(b,p,target,v))) if n>0 else 0
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveReactions.definition(key)
    if not v.is_empty():
        v["player_rules"]=13
        if v.get("item_rule")=="recycle":v["card_notes"]=["이번 전투에 자신이 소모한 물건 복구 · 나무열매/기합의띠/내던지기 포함 · 제거된 물건 제외"]
        if v.get("item_rule")=="fling":v["card_notes"]=["물건별 실제 위력/부가효과 · 강화 위력+15 · 던진 물건은 영구 소모"]
    return v
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=13
    if v.get("item_rule")=="fling" and data()["items"].has(p.held_item):
        v["move_power"]=int(data()["items"][p.held_item]["fling_power"])+(15 if v.get("upgraded",false) else 0)
        v["card_notes"].append("내던지기 위력 · 실제 물건 기준 · 소모 후 전투 종료에도 사라짐")
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("category")!="technique":return ""
    var d:=item(b,p);var id:=int(TacticalMoves.definition(str(v["key"]))["move_id"])
    if d.get("rule")=="vest" and v.get("damage_class")=="status":return "돌격조끼를 지니면 변화 기술을 사용할 수 없습니다."
    if d.get("rule")=="choice" and read(b)["choice"].has(p.uid) and read(b)["choice"][p.uid]!=id:return "구애 도구로 기술이 고정되었습니다. 같은 기술을 사용하거나 교대하세요."
    return ""
static func begin_action(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary) -> void:
    b.held_attack={"source":p.uid,"target":target.uid,"view":v.duplicate(true),"loss":0,"last_loss":0,"landed":false,"owners":read(b)["owners"].duplicate(),"stages":target.stat_stages.duplicate()}
static func consume(b:TacticalBattle,p:BattlePokemon,key:String) -> void:
    var c:=write(b);var origin:int=int(c["owners"].get(p.uid,0))
    if origin==0:return
    PlayerMoveItems.remember(b,p);PlayerMoveItems.write(b)["spent"][p.uid]=key
    c["used"][origin]=true;c["spent"][p.uid]=origin;c["owners"].erase(p.uid);p.held_item=""
    b._record("held",TacticalContent.HELD_ITEMS[key]["name"]+" 소모 · 전투 후에도 소모 유지",{"target":p.uid})
static func cap_damage(b:TacticalBattle,p:BattlePokemon,lost:int,piercing:bool) -> int:
    if not piercing and lost>=p.hp and p.hp==p.max_hp and item(b,p).get("rule")=="sash" and int(b.held_attack.get("target",0))==p.uid:
        consume(b,p,p.held_item);return maxi(0,p.hp-1)
    return lost
static func heal(b:TacticalBattle,p:BattlePokemon,amount:int) -> void:
    if p.alive() and PlayerMoveTactics.read(b)["heal_block"].get(p.uid,0)<b.turn:PlayerMoveTactics.heal(b,p,maxi(1,amount))
static func react(b:TacticalBattle,p:BattlePokemon) -> void:
    if not p.alive():return
    var d:=item(b,p);var trigger:=false;var rule:String=d.get("rule","")
    match rule:
        "heal":trigger=p.hp<=p.max_hp/2 and PlayerMoveTactics.read(b)["heal_block"].get(p.uid,0)<b.turn
        "stat":trigger=p.hp<=p.max_hp/4 and int(p.stat_stages.get(d["stat"],0))<6
        "cure":trigger=["burn","poison","paralysis","sleep","confusion"].any(func(s:String):return p.statuses.has(s)) if d["status"]=="all" else p.statuses.has(d["status"])
        "white":trigger=p.stat_stages.values().any(func(n:Variant):return int(n)<0)
    if not trigger:return
    var key:=p.held_item;consume(b,p,key);apply_berry(b,p,d)
static func apply_berry(b:TacticalBattle,p:BattlePokemon,d:Dictionary) -> void:
    match str(d.get("rule","")):
        "heal":heal(b,p,int(d["amount"]) if int(d["amount"])>0 else maxi(1,p.max_hp/4))
        "stat":p.stat_stages[d["stat"]]=mini(6,int(p.stat_stages.get(d["stat"],0))+1)
        "cure":
            if d["status"]=="all":
                for s:String in ["burn","poison","paralysis","sleep","confusion"]:p.statuses.erase(s)
            else:p.statuses.erase(d["status"])
        "white":
            for stat:String in p.stat_stages.keys():
                if int(p.stat_stages[stat])<0:p.stat_stages.erase(stat)
    b._record("held",p.display_name+" · 지닌 물건 효과",{"target":p.uid})
static func on_damage(b:TacticalBattle,p:BattlePokemon,lost:int,piercing:bool,landed:bool) -> void:
    if not piercing and int(b.held_attack.get("target",0))==p.uid:
        var attack:Dictionary=b.held_attack;attack["loss"]+=lost;attack["last_loss"]=lost;attack["landed"]=attack["landed"] or landed
        var v:Dictionary=attack["view"];var source:=PlayerMoveExchange.member(b,int(attack["source"]));var d:=item(b,p)
        if lost>0 and source!=null:
            if d.get("rule")=="weakness" and p.alive() and b.multiplier(str(v.get("type","normal")),p)>1:
                consume(b,p,p.held_item)
                for stat:String in ["attack","special_attack"]:p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+2)
            if d.get("rule")=="helmet" and source.alive() and PlayerMoveCards.flag(int(v.get("copied_view",{}).get("move_id",v.get("effective_move",v.get("move_id",0)))),1):b._damage(source,maxi(1,source.max_hp/6),true)
    react(b,p)
static func preserve_drops(b:TacticalBattle,p:BattlePokemon,before:Dictionary) -> void:
    if item(b,p).get("rule")!="clear":return
    for stat:String in p.stat_stages.keys():
        if int(p.stat_stages[stat])<int(before.get(stat,0)):p.stat_stages[stat]=int(before.get(stat,0))
static func finish_attack(b:TacticalBattle,p:BattlePokemon) -> void:
    var a:Dictionary=b.held_attack
    if not p.alive() or a.get("source",0)!=p.uid:return
    var rule:String=item(b,p).get("rule","")
    if rule=="shell" and int(a.get("loss",0))>0:heal(b,p,maxi(1,int(a["loss"])/8))
    if rule=="life" and a.get("landed",false) and a.get("view",{}).get("damage_class","status")!="status":b._damage(p,maxi(1,p.max_hp/10),true)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false):return
    var c:=write(b);var tag:String=v.get("item_rule","")
    if not v.get("failed",false):
        if tag=="fling":
            var key:String=PlayerMoveItems.read(b)["spent"].get(p.uid,"")
            if not key.is_empty():consume(b,p,key)
            var thrown:Dictionary=data()["items"].get(key,{})
            if target.alive() and int(b.held_attack.get("loss",0))>0:
                apply_berry(b,target,thrown)
                var status:String={"flame_orb":"burn","toxic_orb":"poison","poison_barb":"poison","light_ball":"paralysis"}.get(key,"")
                if not status.is_empty() and status_allowed(b,target,status,false):target.statuses[status]={"turns":4,"source_uid":p.uid}
        elif tag=="recycle" and c["spent"].has(p.uid):
            var origin:int=c["spent"][p.uid];c["owners"][p.uid]=origin;c["used"].erase(origin);c["spent"].erase(p.uid)
        elif tag in ["swap","give","gas"] and not v.get("item_blocked",false):
            var owners:Dictionary=b.held_attack.get("owners",{})
            if tag=="swap":
                for pair:Array in [[p.uid,target.uid],[target.uid,p.uid]]:
                    c["owners"].erase(pair[0])
                    if owners.has(pair[1]):c["owners"][pair[0]]=owners[pair[1]]
            elif tag=="give":
                c["owners"].erase(p.uid)
                if owners.has(p.uid):c["owners"][target.uid]=owners[p.uid]
            else:c["owners"].erase(target.uid)
    if item(b,p).get("rule")=="choice" and not c["choice"].has(p.uid):c["choice"][p.uid]=int(TacticalMoves.definition(str(v["key"]))["move_id"])
    preserve_drops(b,target,b.held_attack.get("stages",{}));react(b,p);react(b,target);finish_attack(b,p)
static func after_enemy_action(b:TacticalBattle,p:BattlePokemon,foe:BattlePokemon,before:Dictionary) -> void:
    preserve_drops(b,p,before);react(b,p);react(b,foe);finish_attack(b,foe)
    for uid:int in read(b)["owners"].keys():
        var holder:=PlayerMoveExchange.member(b,uid)
        if holder!=null and holder.held_item.is_empty():write(b)["owners"].erase(uid)
static func status_allowed(b:TacticalBattle,p:BattlePokemon,status:String,self_inflicted:bool) -> bool:
    var types:=PlayerMoveCards.effective_types(b,p)
    if (status=="burn" and "fire" in types) or (status=="poison" and types.any(func(t:String):return t in ["poison","steel"])) or (status=="paralysis" and "electric" in types):return false
    if self_inflicted:return not (PlayerMoveAltitude.grounded(b,p) and PlayerMoveFields.read(b)["terrain"]=="misty")
    return not PlayerMoveAirFields.protected_status(b,p,status)
static func end_round(b:TacticalBattle,foe:BattlePokemon) -> void:
    for p:BattlePokemon in [b.active(),foe]:
        if not p.alive():continue
        var d:=item(b,p);var rule:String=d.get("rule","")
        if rule=="leftovers":heal(b,p,maxi(1,p.max_hp/16))
        elif rule=="sludge":
            if "poison" in PlayerMoveCards.effective_types(b,p):heal(b,p,maxi(1,p.max_hp/16))
            else:b._damage(p,maxi(1,p.max_hp/8),true)
        elif rule=="orb" and not ["burn","poison","paralysis","sleep"].any(func(s:String):return p.statuses.has(s)) and status_allowed(b,p,d["status"],true):p.statuses[d["status"]]={"turns":4,"source_uid":p.uid}
        react(b,p)
static func on_switch(b:TacticalBattle,old:int) -> void:
    if not b.held_context.is_empty():b.held_context["choice"].erase(old)
static func restore(b:TacticalBattle) -> void:
    for uid:int in read(b)["originals"]:
        var p:=PlayerMoveExchange.member(b,uid)
        if p!=null:p.held_item="" if read(b)["used"].get(uid,false) else read(b)["originals"][uid]
static func deal_damage(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon,values:Array[int]) -> void:
    var bypass:=PlayerMoveCards.flag(int(v["move_id"]),9) or PlayerMoveCards.flag(int(v["move_id"]),14)
    for i in values.size():
        if not target.alive() or not p.alive():break
        if i>0:b._record("player_hit",p.display_name+" · 연속 타격",{"move_id":int(v["move_id"]),"actor":p.uid})
        b._damage(target,values[i],false,str(v["damage_class"]),bypass)
static func after_preview(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> void:
    if not v.has("damage"):return
    var target:=b.enemy();var hp:=target.hp;var shield:=target.block;var sub:=0;var total:=0;var self_hp:=p.hp
    var d:=item(b,target)
    if BossBattleRules.active_in(b) and not PlayerMoveCards.flag(int(v["move_id"]),9) and not PlayerMoveCards.flag(int(v["move_id"]),14):sub=int(BossBattleRules.read(b)["substitutes"].get(target.uid,0))
    for n:int in PlayerMoveCards.damage_values(b,v,p):
        if hp<=0 or self_hp<=0:break
        var hit:=maxi(0,n-shield);shield=maxi(0,shield-n)
        if sub>0:sub=maxi(0,sub-hit);continue
        var lost:=mini(hp,hit)
        if d.get("rule")=="sash" and hp==target.max_hp and lost>=hp:lost=maxi(0,hp-1);d={}
        hp-=lost;total+=lost
        if lost>0 and d.get("rule")=="helmet" and PlayerMoveCards.flag(int(v["move_id"]),1):self_hp-=maxi(1,p.max_hp/6)
        if hp>0 and d.get("rule")=="heal" and hp<=target.max_hp/2 and PlayerMoveTactics.read(b)["heal_block"].get(target.uid,0)<b.turn:
            var recovered:=int(d["amount"]) if int(d["amount"])>0 else maxi(1,target.max_hp/4)
            if target.uid>0:recovered=PlayerMoveTactics.heal_amount(b,recovered)
            hp=mini(target.max_hp,hp+recovered);d={}
    v["preview_hp_loss"]=total;v["preview_target_hp"]=hp
    if v.has("drain_percent"):
        var percent:=int(v["drain_percent"]);var amount:=PlayerMoveRules.ratio(total,percent)
        if percent>0 and b.has_relic("shield_core"):amount=floori(amount*0.5)
        v["preview_drain"]=mini(p.max_hp-p.hp,amount) if percent>0 else mini(p.hp,amount)
    if item(b,p).get("rule")=="life":v["card_notes"].append("생명의구슬 · 명중 뒤 최대HP의1/10 반동")
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveReactions.lines(v)
    if not rows.is_empty() and v.get("item_rule")=="recycle":rows[0]="자신의 소모품/내던진 물건 복구"
    if not rows.is_empty() and v.get("item_rule")=="fling":rows[0]="물건별 위력/부가효과 · 영구 소모"
    return rows
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    var ids:Array=b["party"]+b["enemies"];var owners:Array=[]
    for key:String in DEFAULT:
        if not c.get(key) is Dictionary:return false
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids:return false
    for uid:int in c["originals"]:
        if not c["originals"][uid] is String or not TacticalContent.HELD_ITEMS.has(c["originals"][uid]):return false
    for uid:int in c["used"]:
        if not c["originals"].has(uid) or not c["used"][uid] is bool or not c["used"][uid]:return false
    for key:String in ["owners","spent"]:
        for uid:int in c[key]:
            var origin:Variant=c[key][uid]
            if not origin is int or not c["originals"].has(origin):return false
            if key=="owners":
                if origin in owners or c["used"].has(origin):return false
                owners.append(origin)
            elif not c["used"].has(origin):return false
    for uid:int in c["choice"]:
        if not c["choice"][uid] is int or not PlayerMoveCards.data()["moves"].has(str(c["choice"][uid])):return false
    return true
