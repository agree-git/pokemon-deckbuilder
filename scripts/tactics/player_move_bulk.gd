class_name PlayerMoveBulk
extends RefCounted
## One v23 batch. Published engines remain unchanged; adaptations are visible on cards.
const PATH:="res://data/player_move_bulk_v23.json"
const DEFAULT:Dictionary={"forms":{},"used":{},"last":{},"rampage":{},"rage":{},"imprison":{},"grudge":{},"blocked":{},"insomnia":{},"simple":{},"salt":{},"syrup":{},"revived":{},"ko_cards":{},"ate":{},"silk":{},"future":[],"cover":0,"mat":0,"uproar":0,"reflect":{},"snatch":{},"combo":{},"fire":0,"swamp":0,"rainbow":0}
const BERRY_TYPES:Dictionary={"cheri_berry":"fire","chesto_berry":"water","pecha_berry":"electric","rawst_berry":"grass","persim_berry":"ground","lum_berry":"flying","oran_berry":"poison","sitrus_berry":"psychic","liechi_berry":"grass","ganlon_berry":"ice","salac_berry":"fighting","petaya_berry":"poison","apicot_berry":"ground"}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.bulk_context if not b.bulk_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.bulk_context.is_empty():b.bulk_context=DEFAULT.duplicate(true)
    return b.bulk_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveTraining.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true)
    v["move_id"]=int(v["move_id"]);v["player_rules"]=15
    if v.has("stat_changes"):
        for stat:String in v["stat_changes"]:v["stat_changes"][stat]=int(v["stat_changes"][stat])
    v["description"]=TacticalContent.description(v)
    return v
static func visual_species(c:Dictionary,p:BattlePokemon) -> int:return int(c.get("forms",{}).get(p.uid,{}).get("species",p.species_id))
static func expand(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique" or not read(b)["forms"].has(p.uid):return v
    var ids:Array=read(b)["forms"][p.uid]["moves"]
    var slot:=maxi(0,p.learned_skills.find(str(v["key"])))%ids.size()
    var proxy:=BattleCardInstance.new(int(v["uid"]),TacticalMoves.key_for(int(ids[slot])),p.uid)
    var original:=b._hand(proxy.uid);proxy.upgraded=original!=null and original.upgraded
    var result:=TacticalContent.definition(proxy,15)
    for key:String in ["uid","key","owner_uid","owner_name","switches","retained","cost"]:
        if v.has(key):result[key]=v[key]
    result["species_id"]=visual_species(read(b),p);result["name"]="변신 · "+str(result["name"])
    return result
static func known_moves(b:TacticalBattle,p:BattlePokemon) -> Array:
    return read(b)["forms"][p.uid]["moves"].duplicate() if read(b)["forms"].has(p.uid) else p.learned_skills.map(func(key:String):return int(TacticalMoves.definition(key)["move_id"]))
static func berry(b:TacticalBattle,p:BattlePokemon) -> bool:return BERRY_TYPES.has(b.effective_item(p))
static func combo(b:TacticalBattle) -> Dictionary:return read(b)["combo"] if read(b)["combo"].get("turn",0)==b.turn else {}
static func upgrade_call(v:Dictionary) -> Dictionary:
    if not (v.get("sleep_call",false) or v.has("copy_move")) or not data()["moves"].has(str(v.get("move_id",0))):return v
    var proxy:=BattleCardInstance.new(int(v["uid"]),TacticalMoves.key_for(int(v["move_id"])),int(v["owner_uid"]))
    var fresh:=TacticalContent.definition(proxy,15)
    for key:String in ["uid","key","owner_uid","owner_name","species_id","switches","retained","cost","name","sleep_call","copy_mode","copy_move","copy_source","copy_boost"]:
        if v.has(key):fresh[key]=v[key]
    return fresh
static func speed(b:TacticalBattle,n:int) -> int:return maxi(1,n/4) if read(b)["swamp"]>=b.turn else n
static func guard_view(v:Dictionary) -> Dictionary:
    var id:=593 if v.get("bulk_rule")=="drill" else 280 if v.get("bulk_rule") in ["break_screens","guardian"] else 0
    if id==0:return v
    var proxy:=v.duplicate(true);proxy["move_id"]=id;return proxy
static func after_preview(b:TacticalBattle,_p:BattlePokemon,v:Dictionary) -> void:
    if v.get("bulk_rule")=="false_swipe" and v.has("preview_hp_loss"):v["preview_hp_loss"]=mini(int(v["preview_hp_loss"]),maxi(0,b.enemy().hp-1))
static func was_hit(b:TacticalBattle,p:BattlePokemon,kind:="") -> bool:
    var hit:=PlayerMoveRules.received(b,p.uid)
    return int(hit.get("damage",0))>0 and (kind.is_empty() or hit.get("kind")==kind)
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=15
    var id:=int(v.get("move_id",0));var tag:String=v.get("bulk_rule","");var target:=b.enemy()
    var previous:Dictionary=PlayerMoveRules.read(b)["last"].get(p.uid,{})
    var used:int=int(read(b)["used"].get(p.uid,{}).get(id,0));var plus:=15 if v.get("upgraded",false) else 0
    # card upgrades are already applied by TacticalContent; infer the power delta there.
    if v.has("move_power"):plus=maxi(0,int(v["move_power"])-int(data()["moves"].get(str(id),v).get("move_power",v["move_power"])))
    match tag:
        "hidden":v["type"]=PlayerMoveCards.effective_types(b,p)[0]
        "item_type":
            var d:=HeldItems.item(b,p)
            if d.get("rule")=="type" and not d.get("types",[]).is_empty():v["type"]=d["types"][0]
        "gift":
            if berry(b,p):v["type"]=BERRY_TYPES[b.effective_item(p)];v["move_power"]=(100 if HeldItems.item(b,p).get("rule")=="stat" else 80)+plus
        "present":
            if used%4==3:v.erase("damage");v["present_heal"]=true
            else:v["move_power"]=[40,80,120][used%4]+plus
        "future":v.erase("damage")
        "poison_double":
            if target.statuses.has("poison"):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "wake":
            if target.statuses.has(v["condition_status"]):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "round":
            if combo(b).get("round",[]).any(func(uid:Variant):return uid!=p.uid):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "fusion":
            if int(v["partner"]) in combo(b).get("fusion",[]):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "pledge":
            var old:Dictionary=combo(b).get("pledge",{})
            if old.get("owner",p.uid)!=p.uid and old.get("move",id)!=id:v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "faster":
            if HeldItems.effective(b,p,"speed")>HeldItems.effective(b,target,"speed"):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "negative":
            if p.stat_stages.values().any(func(n:Variant):return int(n)<0):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "stomping":
            if previous.get("failed",false):v["move_power"]=(int(v["move_power"])-plus)*2+plus
        "last_respects":v["move_power"]=50+50*mini(3,b.party.filter(func(a:BattlePokemon):return not a.alive()).size())+plus
        "super":
            if b.multiplier(str(v["type"]),target,id)>1:v["move_power"]=floori((int(v["move_power"])-plus)*4.0/3.0)+plus
        "psyblade":
            if PlayerMoveFields.read(b)["terrain"]=="electric" and PlayerMoveAltitude.grounded(b,p):v["move_power"]=floori((int(v["move_power"])-plus)*1.5)+plus
        "higher_offense":v["damage_class"]="physical" if HeldItems.effective(b,p,"attack")>HeldItems.effective(b,p,"special_attack") else "special"
        "tri","fatal":v["bulk_status"]=["burn","paralysis","poison"][used%3]
        "alluring":
            if target.stat_stages.values().any(func(n:Variant):return int(n)>0):v["confusion"]=3
        "secret":
            var field:String=PlayerMoveFields.read(b)["terrain"]
            if field in ["grassy","misty"]:v["stat_changes"]={"attack":-1} if field=="grassy" else {"special_attack":-1};v["stat_target"]="enemy"
            else:v["paralysis" if field!="psychic" else "sleep"]=3 if field!="psychic" else 1
        "drill":v["boss_blocked"]=false;v["target_effect_blocked"]=false;v.erase("failed")
    if tag in ["suppress","role","swap","give","doodle","insomnia","simple","spite"]:v["bulk_blocked"]=PlayerMoveAssist.blocked(b,v) or PlayerMoveExchange.blocked(b,v)
    if tag=="powder_cover":v["bulk_blocked"]="grass" in PlayerMoveCards.effective_types(b,target)
    if read(b)["rainbow"]>=b.turn:
        for key:String in ["burn","poison","paralysis","confusion"]:
            if v.has(key):v[key]=int(v[key])+1
    for key:String in ["burn","poison","sleep","paralysis","confusion"]:
        if v.has(key) and PlayerMoveAirFields.protected_status(b,target,key):v.erase(key)
    if tag=="shed_tail_cost":v["card_notes"].append("소비 HP %d" % maxi(1,p.max_hp/2))
    return v
static func replacement(b:TacticalBattle,p:BattlePokemon) -> BattlePokemon:
    for ally:BattlePokemon in b.party:
        if ally!=p and ally.alive() and (not BossBattleRules.active_in(b) or BossBattleRules.entry_damage(b,ally)<ally.hp):return ally
    return null
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    if v.get("category")!="technique":return ""
    var id:=int(v["move_id"]);var tag:String=v.get("bulk_rule","")
    var lock:Dictionary=read(b)["rampage"].get(p.uid,{})
    if not lock.is_empty() and lock["move"]!=id:return "난동 중에는 같은 기술을 사용하거나 교대해야 합니다."
    if tag=="bloodmoon" and read(b)["last"].get(p.uid,0)==id:return "블러드문은 연속으로 사용할 수 없습니다. 다른 기술이나 교대를 사용하세요."
    if tag=="mat" and b.turn!=1:return "마룻바닥세워막기는 전투 첫 턴에만 사용합니다."
    if tag in ["hands","spotlight","cheer"] and not b.party.any(func(ally:BattlePokemon):return ally!=p and ally.alive()):return "함께할 살아 있는 다른 동료가 필요합니다."
    if tag=="ally_switch" and replacement(b,p)==null:return "입장할 수 있는 살아 있는 대기 동료가 필요합니다."
    if tag=="ally_switch" and (PlayerMoveRules.rooted(b) or PlayerMoveTraps.blocked(b,p) or PlayerMoveSeals.locked(b,p) or (BossBattleRules.active_in(b) and BossBattleRules.trapped(b))):return "구속/교대 잠금 중에는 사이드체인지를 사용할 수 없습니다."
    if tag=="revive" and (read(b)["revived"].has(p.uid) or not b.party.any(func(a:BattlePokemon):return not a.alive())):return "회생할 기절 동료가 없거나 이 동료는 이미 회생의기도를 사용했습니다."
    if tag=="shed_tail_cost" and p.hp<=maxi(1,p.max_hp/2):return "제살깎기는 HP가 절반보다 많아야 합니다."
    if tag=="gift" and not berry(b,p):return "자연의은혜는 유효한 소지 나무열매가 필요합니다."
    if tag=="belch" and not ate(b,p):return "이번 전투에 자신이 나무열매를 소모한 뒤 사용할 수 있습니다."
    if tag=="poltergeist" and b.enemy().held_item.is_empty():return "상대가 지닌 물건이 없습니다."
    if tag=="shared_type" and not PlayerMoveCards.effective_types(b,p).any(func(t:String):return t in PlayerMoveCards.effective_types(b,b.enemy())):return "같은 타입을 가진 상대에게만 사용할 수 있습니다."
    if tag=="shell_trap" and not was_hit(b,p,"physical"):return "직전 상대 행동에 물리 직접 피해를 받아야 합니다."
    if tag=="sky_drop" and (int(PlayerMoveCards.data()["weights"].get(str(b.enemy().species_id),0))>=2000 or "flying" in PlayerMoveCards.effective_types(b,b.enemy())):return "프리폴은 비행 타입/200kg 이상 상대에게 사용할 수 없습니다."
    if tag=="future" and read(b)["future"].any(func(row:Dictionary):return row["source"]==p.uid and row["move"]==id):return "같은 동료의 이 기술은 이미 발동을 기다리고 있습니다."
    if tag=="spite" and not PlayerMoveTactics.read(b)["last"].has(b.enemy().uid):return "상대가 기술을 사용한 뒤 원한을 사용할 수 있습니다."
    if tag=="last_resort":
        for mid:int in known_moves(b,p):
            if mid!=id and not read(b)["used"].get(p.uid,{}).has(mid):return "다른 습득 기술을 먼저 모두 사용하세요."
    return ""
static func ate(b:TacticalBattle,p:BattlePokemon) -> bool:
    if read(b)["ate"].has(p.uid):return true
    var c:=HeldItems.read(b);var origin:int=int(c["spent"].get(p.uid,0))
    return origin!=0 and BERRY_TYPES.has(c["originals"].get(origin,""))
static func sync_berries(b:TacticalBattle) -> void:
    for p:BattlePokemon in b.party+b.enemies:
        if ate(b,p):write(b)["ate"][p.uid]=true
static func positive(source:BattlePokemon,target:BattlePokemon) -> void:
    for stat:String in PlayerMoveTraining.STATS:
        var n:=int(source.stat_stages.get(stat,0))
        if n>0:target.stat_stages[stat]=n
static func strip(p:BattlePokemon) -> void:
    for stat:String in p.stat_stages.keys():
        if int(p.stat_stages[stat])>0:p.stat_stages.erase(stat)
    p.strength=mini(0,p.strength)
static func status(b:TacticalBattle,p:BattlePokemon,key:String,source:int,turns:=3) -> void:
    if not p.alive():return
    if key=="sleep" and (read(b)["insomnia"].get(p.uid,0)>=b.turn or read(b)["uproar"]>=b.turn):return
    if PlayerMoveAirFields.protected_status(b,p,key) or not HeldItems.status_allowed(b,p,key,false):return
    var types:=PlayerMoveCards.effective_types(b,p)
    if (key=="burn" and "fire" in types) or (key=="poison" and types.any(func(t:String):return t in ["poison","steel"])) or (key=="paralysis" and "electric" in types):return
    if key=="seed" and "grass" in types:return
    if key in ["sleep","poison","burn","paralysis"] and ["sleep","poison","burn","paralysis"].any(func(s:String):return p.statuses.has(s)):return
    p.statuses[key]={"turns":turns,"source_uid":source};b._record("status",p.display_name+" · "+key,{"target":p.uid})
static func on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    b.bulk_action={"own":p.stat_stages.duplicate(),"target":target.stat_stages.duplicate()}
    if v.get("bulk_rule")!="grudge":write(b)["grudge"].erase(p.uid)
    if v.get("bulk_rule")!="rage":write(b)["rage"].erase(p.uid)
    if v.get("bulk_rule")=="shed_tail_cost":b._damage(p,maxi(1,p.max_hp/2),true)
    if v.get("bulk_rule") in ["break_screens","drill"]:
        if v["bulk_rule"]=="break_screens":
            for key:String in ["screen","reflect","veil"]:PlayerMoveFields.write(b)["foe"][key]=0
            if not b.boss_context.is_empty():
                for key:String in ["screen","reflect"]:
                    if b.boss_context.has(key):b.boss_context[key]=0
        elif not b.boss_context.is_empty():BossBattleRules.write(b)["guards"].erase(target.uid)
static func landed(b:TacticalBattle,v:Dictionary,target:BattlePokemon) -> bool:
    return not v.get("failed",false) and not v.get("preparing",false) and not v.get("boss_blocked",false) and not v.get("target_effect_blocked",false) and (not v.has("damage") or b.multiplier(str(v.get("type","normal")),target,int(v["move_id"]))>0)
static func simple_delta(b:TacticalBattle,p:BattlePokemon,before:Dictionary) -> void:
    if not p.alive() or read(b)["simple"].get(p.uid,0)<b.turn:return
    for stat:String in PlayerMoveTraining.STATS:
        var now:=int(p.stat_stages.get(stat,0));var old:=int(before.get(stat,0))
        if now!=old:p.stat_stages[stat]=clampi(now+(now-old),-6,6)
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false):return
    var id:=int(v["move_id"]);var tag:String=v.get("bulk_rule","");var c:=write(b);var hit:=landed(b,v,target)
    if not c["used"].has(p.uid):c["used"][p.uid]={}
    c["used"][p.uid][id]=int(c["used"][p.uid].get(id,0))+1;c["last"][p.uid]=id
    simple_delta(b,target,b.bulk_action.get("target",{}))
    if not p.alive():return
    if tag in ["cover","powder_cover"]:
        if not v.get("bulk_blocked",false):c["cover"]=b.turn
    elif tag=="mat":c["mat"]=b.turn
    elif tag in ["reflect","snatch"]:c[tag]={"uid":p.uid,"turn":b.turn}
    elif tag=="celebrate":b._record("status",p.display_name+" · 축하합니다!")
    elif tag=="hands":
        for ally:BattlePokemon in b.party:
            if ally.alive():b._gain_block(ally,maxi(1,ally.max_hp/8))
    elif tag in ["spotlight","cheer","laser"]:
        for ally:BattlePokemon in b.party:
            if ally.alive() and ((tag=="laser" and ally==p) or (tag!="laser" and ally!=p)):PlayerMoveRules.write(b)["focus"][ally.uid]=true
    elif tag=="ally_switch":
        var next:=replacement(b,p)
        if next!=null:b._change_active(next.uid,true)
    elif tag=="lunar":
        for ally:BattlePokemon in b.party:
            if ally.alive():ally.statuses.clear();HeldItems.heal(b,ally,maxi(1,ally.max_hp/4))
    elif tag=="revive":
        for ally:BattlePokemon in b.party:
            if ally.alive():continue
            ally.hp=maxi(1,PlayerMoveTactics.heal_amount(b,maxi(1,ally.max_hp/2)));ally.knocked_out=false;c["revived"][p.uid]=true
            var ids:Array=c["ko_cards"].get(ally.uid,[])
            for card:BattleCardInstance in b.exhausted.duplicate():
                if card.uid in ids:b.exhausted.erase(card);b.discard.append(card)
            c["ko_cards"].erase(ally.uid);b._record("heal",ally.display_name+" · 회생의기도",{"target":ally.uid,"amount":ally.hp});break
    elif tag=="tea":
        for member:BattlePokemon in [p,target]:
            if member.alive() and berry(b,member):var d:=HeldItems.item(b,member);HeldItems.consume(b,member,member.held_item);HeldItems.apply_berry(b,member,d);c["ate"][member.uid]=true
    elif tag=="imprison":c["imprison"][p.uid]=known_moves(b,p)
    elif tag=="grudge":c["grudge"][p.uid]=true
    elif tag=="rage":c["rage"][p.uid]=true
    elif tag=="rampage":
        var left:int=int(c["rampage"].get(p.uid,{"left":3})["left"])-1
        if left==0:c["rampage"].erase(p.uid);status(b,p,"confusion",p.uid)
        else:c["rampage"][p.uid]={"move":id,"left":left}
    elif tag=="uproar":
        c["uproar"]=b.turn+2
        for member:BattlePokemon in [p,target]:member.statuses.erase("sleep")
    elif tag=="silk":c["silk"][p.uid]=b.turn
    elif tag=="tidy":
        PlayerMoveFields.write(b)["hazards"]=PlayerMoveFields.HAZARDS.duplicate()
        if not b.boss_context.is_empty():BossBattleRules.write(b)["rocks"]=false
        PlayerMoveTactics.write(b)["hazards"]=PlayerMoveTactics.DEFAULT["hazards"].duplicate();PlayerMoveRules.write(b)["substitutes"].clear()
        if not b.boss_context.is_empty():BossBattleRules.write(b)["substitutes"].clear()
    elif tag=="future":
        c["future"].append({"source":p.uid,"move":id,"due":b.turn+1,"power":int(v["move_power"]),"type":str(v["type"])})
    elif tag=="present" and v.get("present_heal",false):HeldItems.heal(b,target,maxi(1,target.max_hp/4))
    elif tag=="chloroblast":b._damage(p,maxi(1,p.max_hp/2),true)
    if hit:
        if tag=="transform" and target.alive():
            var ids:Array=[]
            for a:Dictionary in b.enemy_definitions[b.enemy_index]["intents"]:
                var mid:=int(a.get("move_id",0))
                if mid>0 and mid!=144 and mid not in ids:ids.append(mid)
            if ids.is_empty():ids.append(33)
            c["forms"][p.uid]={"species":target.species_id,"moves":ids.slice(0,4)}
            for stat:String in PlayerMoveTraining.STATS:PlayerMoveExchange.set_stat(b,p,stat,PlayerMoveExchange.base_stat(target,stat))
            p.stat_stages=target.stat_stages.duplicate();PlayerMoveExchange.set_type(b,p,PlayerMoveCards.effective_types(b,target))
        elif tag in ["role","doodle"] and not v.get("bulk_blocked",false):
            for ally:BattlePokemon in (b.party if tag=="doodle" else [p]):
                if ally.alive():positive(target,ally)
        elif tag=="swap" and not v.get("bulk_blocked",false):
            var a:=PlayerMoveExchange.clone(p);var foe:=PlayerMoveExchange.clone(target);strip(p);strip(target);positive(a,target);positive(foe,p)
            var power:=p.strength;p.strength=mini(0,power)+maxi(0,foe.strength);target.strength=mini(0,target.strength)+maxi(0,a.strength)
        elif tag=="give" and not v.get("bulk_blocked",false):strip(target);positive(p,target)
        elif tag=="suppress" and not v.get("bulk_blocked",false):strip(target)
        elif tag in ["insomnia","simple"] and not v.get("bulk_blocked",false):
            c[tag][target.uid]=b.turn+2
            if tag=="insomnia":target.statuses.erase("sleep")
        elif tag=="spite" and not v.get("bulk_blocked",false):PlayerMoveTactics.write(b)["disable"][target.uid]={"move":PlayerMoveTactics.read(b)["last"][target.uid],"until":b.turn+1}
        elif tag in ["tri","fatal"]:
            var sequence:Array=[v["bulk_status"],"burn","paralysis","poison"]
            for s:String in sequence:
                var count:=target.statuses.size();status(b,target,s,p.uid)
                if target.statuses.size()>count:break
        elif tag=="wake":target.statuses.erase(v["condition_status"])
        elif tag=="cure_burn":target.statuses.erase("burn")
        elif tag=="salt" and target.alive():c["salt"][target.uid]=p.uid
        elif tag=="syrup" and target.alive():c["syrup"][target.uid]={"source":p.uid,"until":b.turn+2}
        elif tag=="fell" and not target.alive():p.stat_stages["attack"]=mini(6,int(p.stat_stages.get("attack",0))+3)
        elif tag=="esper":
            var stat:String="attack" if HeldItems.effective(b,p,"attack")>HeldItems.effective(b,p,"special_attack") else "special_attack"
            p.stat_stages[stat]=mini(6,int(p.stat_stages.get(stat,0))+1)
        elif tag=="noise":PlayerMoveTactics.write(b)["heal_block"][target.uid]=b.turn+1
        elif tag=="plasma":PlayerMoveReactions.write(b)["plasma"]=true
        elif tag in ["max_weather","max_terrain","terrain_psychic","clear_terrain"]:
            if tag=="max_weather":BattleWeather.apply(b,v["after_weather"])
            else:
                PlayerMoveFields.write(b)["terrain"]="" if tag=="clear_terrain" else "psychic" if tag=="terrain_psychic" else v["after_terrain"]
                PlayerMoveFields.write(b)["left"]=0 if tag=="clear_terrain" else 5
        elif tag in ["party_stat","max_drop"]:
            for member:BattlePokemon in (b.party if tag=="party_stat" else [target]):
                if member.alive():member.stat_stages[v["after_stat"]]=clampi(int(member.stat_stages.get(v["after_stat"],0))+(1 if tag=="party_stat" else -1),-6,6)
        elif tag in ["eat","incinerate"] and berry(b,target):
            var d:=HeldItems.item(b,target);HeldItems.consume(b,target,target.held_item)
            if tag=="eat":HeldItems.apply_berry(b,p,d);c["ate"][p.uid]=true
        elif tag=="lock" and target.alive():PlayerMoveTraps.add(b,p,target,615)
        elif tag=="sky_drop":c["cover"]=b.turn
    if tag=="gift" and berry(b,p):HeldItems.consume(b,p,p.held_item)
    if tag=="matcha" and int(c["used"][p.uid][id])%4==0:b._damage(p,maxi(1,p.max_hp/3),true)
    if tag=="crash" and not hit and p.alive():b._damage(p,maxi(1,p.max_hp/2),true)
    if tag in ["round","fusion","pledge"] and hit:
        if c["combo"].get("turn",0)!=b.turn:c["combo"]={"turn":b.turn,"round":[],"fusion":[],"pledge":{}}
        if tag=="round":c["combo"]["round"].append(p.uid)
        elif tag=="fusion":c["combo"]["fusion"].append(id)
        else:
            var old:Dictionary=c["combo"]["pledge"]
            if not old.is_empty() and old["owner"]!=p.uid and old["move"]!=id:
                var pair:Array=[id,old["move"]]
                var field:String="swamp" if 518 in pair and 520 in pair else "fire" if 519 in pair and 520 in pair else "rainbow"
                c[field]=b.turn+3
            c["combo"]["pledge"]={"owner":p.uid,"move":id}
    sync_berries(b)
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if v.get("bulk_rule")=="guardian":return 0 if b.multiplier(str(v["type"]),target,int(v["move_id"]))<=0 else maxi(1,target.hp*3/4)
    var calc:=v
    if v.get("bulk_rule")=="break_screens":calc=v.duplicate(true);calc["move_id"]=280
    var n:=HeldItems.player_damage(b,p,target,calc,bonus)
    if v.get("bulk_rule")=="flying_press":
        var factor:=b.multiplier("flying",target,int(v["move_id"]))
        return 0 if factor<=0 or n<=0 else maxi(1,floori(n*factor))
    return n
static func enemy_preview(b:TacticalBattle,a:Dictionary) -> Dictionary:
    var c:=read(b);var id:=int(a.get("effective_move",a.get("move_id",0)));var v:=definition(TacticalMoves.key_for(id))
    var using:bool=not a.get("asleep",false) and not a.get("player_sealed",false) and not a.get("failed_move",false) and a["kind"] not in ["prepare","recharge","wait"]
    if not using:return a
    a=a.duplicate(true)
    var sealed:bool=id in c["blocked"].get(b.enemy().uid,[])
    for uid:int in c["imprison"]:
        var owner:=b.member(uid)
        if owner!=null and owner==b.active() and owner.alive() and id in c["imprison"][uid]:sealed=true
    if sealed:a["player_sealed"]=true;a["value"]=0;a["advance"]=1
    var attack:bool=a.get("damage_class","status")!="status" or a["kind"] in ["attack","charge","barrage"]
    if attack and (c["mat"]==b.turn or c["cover"]==b.turn):
        var factor:=0.0 if c["mat"]==b.turn else 0.5
        a["value"]=floori(int(a["value"])*factor)
        if a.has("per_hit"):a["per_hit"]=floori(int(a["per_hit"])*factor);a["value"]=int(a["per_hit"])*int(a.get("hits",1))
        if factor==0.0:a["immune"]=true
    if not sealed and not attack:
        var reflect:Dictionary=c["reflect"];var snatch:Dictionary=c["snatch"]
        var self_effect:bool=v.get("stat_target","")=="self" or v.has("heal") or a["kind"] in ["boost","fortify","recover"]
        var reflectable:bool=not self_effect and (v.has("stat_changes") or ["burn","poison","sleep","paralysis","confusion","seed"].any(func(key:String):return v.has(key)) or v.get("extension","") in ["taunt","bind","disable","encore","heal_block"])
        if v.get("extension","") in ["encore","disable"] and not PlayerMoveTactics.read(b)["last"].has(b.enemy().uid):reflectable=false
        if reflect.get("turn",0)==b.turn and reflectable:a["bulk_cancel"]="reflect";a["bulk_owner"]=reflect["uid"]
        elif snatch.get("turn",0)==b.turn and self_effect:a["bulk_cancel"]="snatch";a["bulk_owner"]=snatch["uid"]
    if a.has("bulk_cancel"):a["value"]=0;a["advance"]=1
    if a.get("player_sealed",false) or a.has("bulk_cancel"):
        if a.has("per_hit"):a["per_hit"]=0
    return a
static func cancel_enemy(b:TacticalBattle,a:Dictionary) -> void:
    var p:=b.member(int(a["bulk_owner"]));var target:=b.enemy() if a["bulk_cancel"]=="reflect" else p
    var id:=int(a.get("effective_move",a["move_id"]));var v:=definition(TacticalMoves.key_for(id))
    if p!=null and p.alive() and target.alive():
        for stat:String in v.get("stat_changes",{}):
            var delta:=int(v["stat_changes"][stat])
            if delta>=0 or HeldItems.item(b,target).get("rule")!="clear":target.stat_stages[stat]=clampi(int(target.stat_stages.get(stat,0))+delta,-6,6)
        for s:String in ["burn","poison","sleep","paralysis","confusion","seed"]:
            if v.has(s):status(b,target,s,p.uid,int(v[s]))
        if a["bulk_cancel"]=="snatch":
            if v.has("heal"):HeldItems.heal(b,target,PokemonStats.scale(target,int(v["heal"])))
            elif a["kind"]=="recover":HeldItems.heal(b,target,maxi(1,target.max_hp/2))
            if a["kind"]=="boost":target.strength+=maxi(1,int(a.get("value",1)))
        else:
            var tag:String=v.get("extension","")
            if tag in ["taunt","heal_block"]:PlayerMoveTactics.write(b)[tag][target.uid]=b.turn+2
            elif tag=="bind":PlayerMoveTactics.write(b)["binds"][target.uid]={"source":p.uid,"until":b.turn+3}
            elif tag in ["encore","disable"] and PlayerMoveTactics.read(b)["last"].has(target.uid):PlayerMoveTactics.write(b)[tag][target.uid]={"move":PlayerMoveTactics.read(b)["last"][target.uid],"until":b.turn+2}
        b._record("cancel",("매직코트 · 반사" if a["bulk_cancel"]=="reflect" else "가로채기 · 강화/회복 획득"),{"target":target.uid})
    if b.enemy_definitions[b.enemy_index].get("boss_moves_version")==4:
        b.opening()["effects_v4"]=BossMoveEffectsP3.state(b).duplicate(true)
        b.opening()["effects_v4"].merge({"charge":0,"recharge":false,"lock":0,"lock_left":0,"last_failed":true,"last_move":id,"air_cancel":false},true)
        b.opening()["effects_v4"]["actions"]+=1
    write(b)[a["bulk_cancel"]]={}
static func on_damage(b:TacticalBattle,p:BattlePokemon,lost:int,piercing:bool) -> void:
    if lost>0 and not piercing and read(b)["rage"].has(p.uid) and p.alive():p.stat_stages["attack"]=mini(6,int(p.stat_stages.get("attack",0))+1)
static func on_knockout(b:TacticalBattle,p:BattlePokemon) -> void:
    var c:=write(b)
    if p.uid>0:
        var ids:Array=[]
        for pile:Array in [b.hand,b.draw_pile,b.discard]:
            for card:BattleCardInstance in pile:
                if card.owner_uid==p.uid:ids.append(card.uid)
        c["ko_cards"][p.uid]=ids
        if c["grudge"].has(p.uid) and b.phase=="enemy" and int(b.held_attack.get("source",0))==b.enemy().uid:
            var v:Dictionary=b.held_attack.get("view",{});var id:=int(v.get("effective_move",v.get("move_id",0)))
            if id>0:
                if not c["blocked"].has(b.enemy().uid):c["blocked"][b.enemy().uid]=[]
                if id not in c["blocked"][b.enemy().uid]:c["blocked"][b.enemy().uid].append(id)
    on_switch(b,p.uid)
static func on_switch(b:TacticalBattle,uid:int) -> void:
    if b.bulk_context.is_empty():return
    for key:String in ["forms","last","rampage","rage","imprison","grudge","insomnia","simple","salt","syrup","silk"]:b.bulk_context[key].erase(uid)
static func after_enemy(b:TacticalBattle,foe:BattlePokemon,p:BattlePokemon,a:Dictionary,foe_stages:Dictionary) -> void:
    var c:=write(b);simple_delta(b,foe,foe_stages)
    if c["silk"].get(p.uid,0)==b.turn and PlayerMoveCards.flag(int(a.get("effective_move",a.get("move_id",0))),1) and not a.get("asleep",false) and not a.get("player_sealed",false) and foe.alive():foe.stat_stages["speed"]=maxi(-6,int(foe.stat_stages.get("speed",0))-1)
    if foe.alive() and c["fire"]>=b.turn and "fire" not in PlayerMoveCards.effective_types(b,foe):b._damage(foe,maxi(1,foe.max_hp/8),true)
    if foe.alive() and c["salt"].has(foe.uid):b._damage(foe,maxi(1,foe.max_hp/(4 if PlayerMoveCards.effective_types(b,foe).any(func(t:String):return t in ["water","steel"]) else 8)),true)
    if foe.alive() and c["syrup"].get(foe.uid,{}).get("until",0)>=b.turn:foe.stat_stages["speed"]=maxi(-6,int(foe.stat_stages.get("speed",0))-1)
    for pending:Dictionary in c["future"].duplicate(true):
        if pending["due"]>b.turn:continue
        c["future"].erase(pending)
        var owner:=b.member(int(pending["source"]));var delayed_target:=b.enemy()
        if owner==null or not delayed_target.alive():continue
        var view:=definition(TacticalMoves.key_for(int(pending["move"])));view["move_power"]=pending["power"];view["type"]=pending["type"];view["damage"]=1
        if not PlayerMoveExchange.blocked(b,view):b._damage(delayed_target,PlayerTechniques.raw_damage(b,owner,delayed_target,view,0),false,str(view["damage_class"]))
    for member:BattlePokemon in [p,foe]:
        if c["insomnia"].get(member.uid,0)>=b.turn or c["uproar"]>=b.turn:member.statuses.erase("sleep")
    c["reflect"]={};c["snatch"]={};sync_berries(b)
    for key:String in ["insomnia","simple","silk"]:
        for uid:int in c[key].keys():
            if c[key][uid]<=b.turn:c[key].erase(uid)
    for uid:int in c["syrup"].keys():
        if c["syrup"][uid]["until"]<=b.turn:c["syrup"].erase(uid)
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveTraining.lines(v)
    if v.has("bulk_rule") and not v.get("card_notes",[]).is_empty():rows.push_front(str(v["card_notes"][-1]))
    return rows.slice(0,5)
static func valid_context(value:Variant,b:Dictionary,cards:Dictionary) -> bool:
    if not value is Dictionary:return false
    if value.is_empty():return true
    var c:Dictionary=value;var ids:Array=b["party"]+b["enemies"];var turn:int=b["turn"]
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.has(key) or typeof(c[key])!=typeof(DEFAULT[key]):return false
    for key:String in ["cover","mat","uproar","fire","swamp","rainbow"]:
        if not c[key] is int or c[key]<0 or c[key]>turn+3:return false
    for key:String in ["rage","grudge","ate","revived"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids or not c[key][uid] is bool or not c[key][uid]:return false
            if key!="ate" and uid not in b["party"]:return false
    for key:String in ["insomnia","simple","silk"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids or not c[key][uid] is int or c[key][uid]<1 or c[key][uid]>turn+2:return false
    for uid:Variant in c["forms"]:
        var row:Variant=c["forms"][uid]
        if not uid is int or uid not in b["party"] or not row is Dictionary or row.size()!=2 or not row.get("species") is int or PokedexExpansion.species(row["species"]).is_empty():return false
        if not move_list(row.get("moves"),4) or row["moves"].is_empty() or 144 in row["moves"]:return false
    for uid:Variant in c["used"]:
        if not uid is int or uid not in b["party"] or not c["used"][uid] is Dictionary or c["used"][uid].size()>919:return false
        for id:Variant in c["used"][uid]:
            if not id is int or id<1 or id>919 or not c["used"][uid][id] is int or c["used"][uid][id]<1 or c["used"][uid][id]>100000:return false
    for uid:Variant in c["last"]:
        if not uid is int or uid not in b["party"] or not c["last"][uid] is int or c["last"][uid]<1 or c["last"][uid]>919:return false
    for uid:Variant in c["rampage"]:
        var row:Variant=c["rampage"][uid]
        if not uid is int or uid not in b["party"] or not row is Dictionary or row.size()!=2 or not row.get("move") is int or row["move"] not in [37,80,200] or not row.get("left") is int or row["left"] not in [1,2]:return false
    for key:String in ["imprison","blocked"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in (b["party"] if key=="imprison" else b["enemies"]) or not move_list(c[key][uid],919):return false
    for uid:Variant in c["salt"]:
        if not uid is int or uid not in b["enemies"] or not c["salt"][uid] is int or c["salt"][uid] not in b["party"]:return false
    for uid:Variant in c["syrup"]:
        var row:Variant=c["syrup"][uid]
        if not uid is int or uid not in b["enemies"] or not row is Dictionary or row.size()!=2 or not row.get("source") is int or row["source"] not in b["party"] or not row.get("until") is int or row["until"]<1 or row["until"]>turn+2:return false
    for uid:Variant in c["ko_cards"]:
        if not uid is int or uid not in b["party"] or not c["ko_cards"][uid] is Array or c["ko_cards"][uid].size()>512:return false
        var seen:Array=[]
        for id:Variant in c["ko_cards"][uid]:
            if not id is int or id not in cards or cards[id]["owner_uid"]!=uid or id in seen:return false
            seen.append(id)
    if c["future"].size()>6:return false
    var pending:Array=[]
    for row:Variant in c["future"]:
        if not row is Dictionary or row.size()!=5 or not row.get("source") is int or row["source"] not in b["party"] or not row.get("move") is int or row["move"] not in [248,353] or not row.get("due") is int or row["due"]<1 or row["due"]>turn+1 or not row.get("power") is int or row["power"]<1 or row["power"]>500 or row.get("type") not in ["normal","fire","water","electric","grass","ice","fighting","poison","ground","flying","psychic","bug","rock","ghost","dragon","dark","steel","fairy"]:return false
        var pair:Array=[row["source"],row["move"]]
        if pair in pending:return false
        pending.append(pair)
    for key:String in ["reflect","snatch"]:
        var row:Dictionary=c[key]
        if not row.is_empty() and (row.size()!=2 or not row.get("uid") is int or row["uid"] not in b["party"] or not row.get("turn") is int or row["turn"]<1 or row["turn"]>turn):return false
    var combo_state:Dictionary=c["combo"]
    if not combo_state.is_empty():
        if combo_state.size()!=4 or not combo_state.get("turn") is int or combo_state["turn"]<1 or combo_state["turn"]>turn or not combo_state.get("round") is Array or combo_state["round"].size()>512 or not move_list(combo_state.get("fusion"),512) or not combo_state.get("pledge") is Dictionary:return false
        for uid:Variant in combo_state["round"]:
            if not uid is int or uid not in b["party"]:return false
        for id:int in combo_state["fusion"]:
            if id not in [558,559]:return false
        var row:Dictionary=combo_state["pledge"]
        if not row.is_empty() and (row.size()!=2 or not row.get("owner") is int or row["owner"] not in b["party"] or not row.get("move") is int or row["move"] not in [518,519,520]):return false
    return true
static func move_list(value:Variant,limit:int) -> bool:
    if not value is Array or value.size()>limit:return false
    for id:Variant in value:
        if not id is int or id<1 or id>919:return false
    return true
