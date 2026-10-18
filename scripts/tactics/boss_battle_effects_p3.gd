class_name BossBattleEffectsP3
extends RefCounted
## Optional battle context used only by v9 representative encounters.
const DEFAULT := {"rocks":false,"screen":0,"safeguard":0,"gravity":0,"received":{},"acted":{},"hurt":{},"guards":{},"substitutes":{},"roots":{},"traps":{},"last_enemy_ko":0,"last_switch":0,"drowsy":{},"infatuation":{},"silence":{},"seals":{},"curses":{},"tar":{},"vulnerable":{},"destiny":{},"airborne":{},"spent_electric":{},"last_moves":{},"mirror":{},"removed_items":{},"card_attacker":0,"bond_pending":0}
const TARGET_EFFECTS := ["burn","seed","poison","sleep","paralysis","confusion","weaken","expose","cash","pulse_status"]
static func active_in(b: TacticalBattle) -> bool:
    return b.enemy_definitions.any(func(d: Dictionary):return d.get("boss_moves_version")==4)
static func read(b: TacticalBattle) -> Dictionary:
    return b.boss_context if not b.boss_context.is_empty() else DEFAULT
static func write(b: TacticalBattle) -> Dictionary:
    if b.boss_context.is_empty(): b.boss_context=DEFAULT.duplicate(true)
    return b.boss_context
static func received(b: TacticalBattle,uid: int) -> Dictionary:
    var r: Dictionary=read(b)["received"].get(uid,{})
    return r if r.get("turn",0)==b.turn else {"damage":0,"kind":""}
static func flag(id: int,value: int) -> bool:
    return value in BossMoveEffectsP3.data()["move_flags"].get(str(id),[])
static func protected(b: TacticalBattle,view: Dictionary) -> bool:
    var guard: String=read(b)["guards"].get(b.enemy().uid,"")
    if guard.is_empty(): return false
    var targeted: bool=view.has("damage") or view.has("shield_attack") or TARGET_EFFECTS.any(func(k: String):return view.has(k)) or (view.has("stat_changes") and view.get("stat_target")=="enemy") or int(view.get("move_id",0))==432
    if not targeted:return false
    var id:=int(view.get("move_id",0))
    if id in [165,364,467,566,593,621]: return false
    return guard!="king" or view.has("damage") or view.has("shield_attack")
static func player_damage(b: TacticalBattle,view: Dictionary,amount: int) -> int:
    if not active_in(b): return amount
    if protected(b,view) or airborne_miss(b,view): return 0
    var target:=b.enemy()
    if read(b)["airborne"].get(target.uid,false) and int(view.get("move_id",0)) in [16,239] and amount>0:amount*=2
    if read(b)["vulnerable"].get(target.uid,false) and view.has("damage") and amount>0:amount*=2
    var actor:=b.member(int(view.get("owner_uid",0)))
    # card_view supplies the exact owner; shared cards never trigger attraction.
    if actor!=null and read(b)["infatuation"].get(actor.uid,{}).get("source",0)==target.uid and amount>0:amount=maxi(1,amount/2)
    if read(b)["screen"]>0 and view.get("damage_class")=="special" and int(view.get("move_id",0))!=280 and amount>0: return maxi(1,amount/2)
    return amount
static func filter_view(b: TacticalBattle,original: Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    var guarded:=protected(b,v) or airborne_miss(b,v)
    var sub: bool=read(b)["substitutes"].get(b.enemy().uid,0)>0 and not flag(int(v.get("move_id",0)),9) and not flag(int(v.get("move_id",0)),14)
    if guarded:
        if v.get("category")=="technique" and flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):v["boss_contact_guard"]=read(b)["guards"].get(b.enemy().uid,"")
        v["boss_blocked"]=true
    for key: String in TARGET_EFFECTS:
        if guarded or sub or (read(b)["safeguard"]>0 and key in ["burn","poison","sleep","paralysis","confusion"]):v.erase(key)
    if (guarded or sub) and v.get("stat_target")=="enemy":v.erase("stat_changes")
    return v
static func on_card(b: TacticalBattle,original: Dictionary,actor: BattlePokemon) -> void:
    var c:=write(b)
    c["acted"][actor.uid]=b.turn
    c["card_attacker"]=actor.uid if original.get("category")=="technique" else 0
    if original.get("category")=="technique":
        var move_id:=int(original.get("move_id",0))
        var attack:bool=original.has("damage") or original.has("shield_attack")
        c["last_moves"][actor.uid]={"move":move_id,"target":b.enemy().uid,"turn":b.turn,"attack":attack}
        if attack and flag(move_id,7):c["mirror"][b.enemy().uid]={"source":actor.uid,"move":move_id}
    if airborne_miss(b,original):
        b._record("cancel","상대가 공중에 있어 대상 효과 빗나감")
        return
    var id:=int(original.get("move_id",0))
    if protected(b,original):
        b._record("cancel","상대의 방어 · 대상 효과 차단")
        return
    if id in [479,615] and int(original.get("preview_damage",0))>0 and c["airborne"].has(b.enemy().uid):
        c["airborne"].erase(b.enemy().uid)
        if b.opening().has("effects_v4"):
            b.opening()["effects_v4"]["charge"]=0
            b.opening()["effects_v4"]["air_cancel"]=true
        b._record("field","착지 기술 · 뛰어오르기 중단")
    if id==364: c["guards"].erase(b.enemy().uid)
    if id==280 and int(original.get("preview_damage",0))>0:
        c["screen"]=0
        b._record("field","깨뜨리다 · 빛의장막 해제")
    if id==432:
        c["rocks"]=false;c["screen"]=0;c["safeguard"]=0
        b._record("field","안개제거 · 스텔스록/빛의장막/신비의부적 해제")
    if id in [229,866] and int(original.get("preview_damage",0))>0:
        c["rocks"]=false;c["traps"].erase(actor.uid)
        b._record("field","회전 기술 · 스텔스록/구속 해제")
static func after_card(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> void:
    write(b)["card_attacker"]=0
    if v.get("category")=="technique" and flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):
        var cycle: Array=b.enemy_definitions[b.enemy_index]["intents"]
        if int(cycle[int(b.opening()["intent"])%cycle.size()]["move_id"])==690 and actor.alive():
            actor.statuses["burn"]={"turns":3,"source_uid":b.enemy().uid}
            b._record("status",actor.display_name+" · 부리캐논 준비 중 접촉 화상",{"target":actor.uid})
    var guard: String=v.get("boss_contact_guard","")
    var stat: String="attack" if guard=="king" else "defense"
    if guard in ["king","obstruct"] and actor.alive():
        actor.stat_stages[stat]=maxi(-6,int(actor.stat_stages.get(stat,0))-2)
        b._record("stat",actor.display_name+" · 접촉 반격 "+PokemonStats.TITLES[stat]+" -2",{"target":actor.uid})
static func absorb(b: TacticalBattle,target: BattlePokemon,amount: int,piercing: bool,bypass: bool) -> int:
    if target.uid>0 or piercing or bypass or amount<=0: return amount
    var pool:=int(read(b)["substitutes"].get(target.uid,0))
    if pool<=0:return amount
    var c:=write(b)
    c["substitutes"][target.uid]=maxi(0,pool-amount)
    b._record("substitute",target.display_name+" · 대타가 피해 %d 흡수" % mini(pool,amount),{"target":target.uid,"amount":mini(pool,amount)})
    return 0 # A breaking hit never overflows into the owner.
static func track(b: TacticalBattle,target: BattlePokemon,lost: int,kind: String) -> void:
    if lost<=0:return
    var c:=write(b)
    c["hurt"][target.uid]=b.turn
    if target.uid<0 and kind in ["physical","special"]:c["received"][target.uid]={"turn":b.turn,"damage":lost,"kind":kind}
    if not target.alive():
        var bonded:bool=c["destiny"].get(target.uid,false) and kind in ["physical","special"] and target.uid<0 and c["card_attacker"]==b.active().uid and c["last_moves"].get(b.active().uid,{}).get("turn",0)==b.turn
        for group: String in ["vulnerable","destiny","airborne","infatuation","silence","seals","tar"]:c[group].erase(target.uid)
        for uid: int in c["infatuation"].keys():
            if c["infatuation"][uid]["source"]==target.uid:c["infatuation"].erase(uid)
        if bonded:c["bond_pending"]=b.active().uid
        if target.uid<0:c["last_enemy_ko"]=b.turn
        for group: String in ["guards","substitutes","roots","traps"]:c[group].erase(target.uid)
        for uid: int in c["traps"].keys():
            if c["traps"][uid]["source"]==target.uid:c["traps"].erase(uid)
static func begin_enemy(b: TacticalBattle) -> void:
    var c:=write(b)
    for key: String in ["guards","vulnerable","destiny","airborne"]:c[key].erase(b.enemy().uid)
static func end_enemy(b: TacticalBattle,actor: BattlePokemon) -> void:
    var c:=write(b)
    if actor.alive() and c["roots"].get(actor.uid,false):
        var healed:=mini(actor.max_hp-actor.hp,maxi(1,actor.max_hp/16))
        actor.hp+=healed
        if healed>0:b._record("heal",actor.display_name+" · 뿌리박기",{"target":actor.uid,"amount":healed})
    for key: String in ["screen","safeguard","gravity"]:
        if c[key]>0:
            c[key]-=1
            if c[key]==0:b._record("field",{"screen":"빛의장막","safeguard":"신비의부적","gravity":"중력"}[key]+" 종료")
static func trapped(b: TacticalBattle) -> bool:
    var trap: Dictionary=read(b)["traps"].get(b.active().uid,{})
    if trap.is_empty() or "ghost" in b.active().types:return false
    return b.enemies.any(func(p: BattlePokemon):return p.uid==trap["source"] and p.alive())
static func tick_trap(b: TacticalBattle,p: BattlePokemon) -> void:
    if not p.alive() or p.uid<0:return
    tick_unique(b,p)
    if not p.alive():return
    var trap: Dictionary=read(b)["traps"].get(p.uid,{})
    if trap.is_empty():return
    if not b.enemies.any(func(foe:BattlePokemon):return foe.uid==trap["source"] and foe.alive()):
        write(b)["traps"].erase(p.uid)
        return
    if not trap["dot"]:return
    var c:=write(b)
    c["traps"][p.uid]["turns"]-=1
    if c["traps"][p.uid]["turns"]<=0:c["traps"].erase(p.uid)
    b._record("status_tick",p.display_name+" · 엉겨붙기",{"target":p.uid})
    b._damage(p,maxi(1,p.max_hp/8),true)
static func entry_damage(b: TacticalBattle,p: BattlePokemon) -> int:
    if not read(b)["rocks"]:return 0
    return mini(p.hp,maxi(1,floori(p.max_hp*TypeMatchup.multiplier("rock",p.types)/8.0)))
static func on_switch(b: TacticalBattle,old_uid: int) -> void:
    var c:=write(b)
    c["last_switch"]=b.turn
    c["traps"].erase(old_uid)
    for key: String in ["drowsy","infatuation","curses","tar"]:c[key].erase(old_uid)
    for uid: int in c["infatuation"].keys():
        if c["infatuation"][uid]["source"]==old_uid:c["infatuation"].erase(uid)
    var loss:=entry_damage(b,b.active())
    if loss>0:
        b._record("hazard",b.active().display_name+" · 스텔스록 %d" % loss,{"target":b.active().uid,"amount":loss})
        b._damage(b.active(),loss,true)
static func next_ally(b: TacticalBattle) -> int:
    for offset in range(1,b.party.size()):
        var i: int=(b.active_index+offset)%b.party.size()
        if b.party[i].alive():return b.party[i].uid
    return 0
static func force_switch(b: TacticalBattle) -> void:
    var uid:=next_ally(b)
    if uid==0:return
    b._stat("forced_switches")
    b._change_active(uid,false)
static func affinity(b: TacticalBattle,attack: String,target: BattlePokemon) -> float:
    var types:=effective_types(b,target)
    if attack=="ground" and (read(b)["gravity"]>0 or read(b)["roots"].get(target.uid,false)):types.erase("flying")
    return TypeMatchup.multiplier(attack,types)*(2.0 if attack=="fire" and read(b)["tar"].get(target.uid,false) else 1.0)
static func card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    var notes: Array[String]=[]
    if airborne_miss(b,v):notes.append("공중 회피 · 일반 대상 효과가 빗나감")
    if protected(b,v):notes.append("상대 방어로 대상 효과 차단")
    if read(b)["substitutes"].get(b.enemy().uid,0)>0:notes.append("대타출동 유지 · 대타를 깬 타격의 초과 피해 없음")
    if read(b)["safeguard"]>0:notes.append("신비의부적 · 상태 부여 차단")
    if actor!=b.active() and read(b)["rocks"]:notes.append("교대 시 스텔스록 HP -%d" % entry_damage(b,actor))
    if int(v.get("move_id",0)) in [229,432,866,280]:notes.append("설치/장막 해제 효과 지원")
    var why:=card_reason(b,v,actor)
    if not why.is_empty():notes.append(why)
    if read(b)["infatuation"].has(actor.uid):notes.append("헤롱헤롱 · 시전자 대상 기술 피해 절반 · 교대로 해제")
    if trapped(b):notes.append("교체 봉쇄 · 현재 동료 기술/도구는 사용 가능")
    return "\n".join(notes)
static func summary(b: TacticalBattle) -> String:
    var c:=read(b)
    var lines: Array[String]=[]
    if c["rocks"]:lines.append("스텔스록 · 교대 시 최대HP/8 × 바위 상성")
    for key: String in ["screen","safeguard","gravity"]:
        if c[key]>0:lines.append("%s · %d턴" % [{"screen":"빛의장막","safeguard":"신비의부적","gravity":"중력"}[key],c[key]])
    if c["substitutes"].get(b.enemy().uid,0)>0:lines.append("대타 HP %d" % c["substitutes"][b.enemy().uid])
    if not c["guards"].get(b.enemy().uid,"").is_empty():lines.append("방어 유지 · 다음 자기 행동까지")
    if trapped(b):lines.append("출전자 구속 · 기술 자동 교대/수동 교대 제한")
    for uid: int in c["drowsy"]:lines.append("하품 · 다음 아군턴 종료 시 수면 · 교대로 해제")
    if c["vulnerable"].get(b.enemy().uid,false):lines.append("대검돌격 후 취약 · 다음 자기 행동까지 받는 기술 피해2배")
    if c["destiny"].get(b.enemy().uid,false):lines.append("길동무 · 다음 자기 행동 전 직접 기술로 쓰러뜨리면 동반 기절")
    if c["airborne"].get(b.enemy().uid,false):lines.append("뛰어오르기 · 공중 회피 중")
    return "\n".join(lines)
static func effective_types(b: TacticalBattle,p: BattlePokemon) -> Array:
    var types:=p.types.duplicate()
    if read(b)["spent_electric"].get(p.uid,false):types.erase("electric")
    return types
static func airborne_miss(b: TacticalBattle,v: Dictionary) -> bool:
    if not read(b)["airborne"].get(b.enemy().uid,false):return false
    if not (v.has("damage") or v.has("shield_attack") or TARGET_EFFECTS.any(func(k:String):return v.has(k)) or v.get("stat_target")=="enemy"):return false
    return int(v.get("move_id",0)) not in [16,87,239,327,479,542,615] and read(b)["gravity"]==0
static func card_reason(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    if v.get("category")!="technique":return ""
    if read(b)["silence"].get(actor.uid,0)>=b.turn and flag(int(v.get("move_id",0)),9):return "지옥찌르기 · 음성 기술이 봉인돼 있습니다."
    var seal:Dictionary=read(b)["seals"].get(actor.uid,{})
    if seal.get("until",0)>=b.turn and seal.get("move",0)==int(v.get("move_id",0)):return "섬뜩한주문 · 마지막 기술이 봉인돼 있습니다. 다른 기술/도구/교대를 사용하세요."
    return ""
static func tick_unique(b: TacticalBattle,p: BattlePokemon) -> void:
    var c:=write(b)
    if c["curses"].has(p.uid) and p==b.active():
        b._record("status_tick",p.display_name+" · 저주",{"target":p.uid})
        b._damage(p,maxi(1,p.max_hp/4),true)
    var sleepy:Dictionary=c["drowsy"].get(p.uid,{})
    if not sleepy.is_empty() and b.turn>=sleepy["due"]:
        c["drowsy"].erase(p.uid)
        if p.alive() and not ["burn","poison","sleep","paralysis"].any(func(k:String):return p.statuses.has(k)):
            p.statuses["sleep"]={"turns":1,"source_uid":sleepy["source"]}
            b._record("status",p.display_name+" · 하품으로 수면",{"target":p.uid})
    if c["infatuation"].get(p.uid,{}).get("until",0)<=b.turn:c["infatuation"].erase(p.uid)
    if c["silence"].get(p.uid,0)<=b.turn:c["silence"].erase(p.uid)
    if c["seals"].get(p.uid,{}).get("until",0)<=b.turn:c["seals"].erase(p.uid)
static func restore_items(b: TacticalBattle) -> void:
    for uid: int in b.boss_context.get("removed_items",{}):
        var p:=b.member(uid)
        if p!=null:p.held_item=b.boss_context["removed_items"][uid]
static func valid_context(c: Variant,b: Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key:String in DEFAULT:
        if not c.has(key) or typeof(c[key])!=typeof(DEFAULT[key]):return false
    if not b["enemy_definitions"].any(func(d:Variant):return d is Dictionary and d.get("boss_moves_version")==4):return false
    for key:String in ["card_attacker","bond_pending"]:
        if not c[key] is int or c[key]!=0:return false
    var base:Dictionary={}
    for key:String in BossBattleEffects.DEFAULT:base[key]=c[key]
    var legacy:=b.duplicate()
    legacy["enemy_definitions"]=b["enemy_definitions"].duplicate(true)
    for d:Dictionary in legacy["enemy_definitions"]:
        if d.get("boss_moves_version")==4:d["boss_moves_version"]=3
    if not BossBattleEffects.valid_context(base,legacy):return false
    for key:String in ["drowsy","infatuation","silence","seals","curses","tar","removed_items","last_moves"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in b["party"]:return false
            var v:Variant=c[key][uid]
            match key:
                "drowsy","infatuation":
                    var timer:String="due" if key=="drowsy" else "until"
                    if not v is Dictionary or v.size()!=2 or not v.get("source") is int or v["source"] not in b["enemies"] or not v.get(timer) is int or v[timer]<1 or v[timer]>b["turn"]+2:return false
                "silence":
                    if not v is int or v<1 or v>b["turn"]+2:return false
                "seals":
                    if not v is Dictionary or v.size()!=2 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not v.get("until") is int or v["until"]<1 or v["until"]>b["turn"]+3:return false
                "curses":
                    if not v is int or v not in b["enemies"]:return false
                "tar":
                    if not v is bool or not v:return false
                "removed_items":
                    if not v is String or not TacticalContent.HELD_ITEMS.has(v):return false
                "last_moves":
                    if not v is Dictionary or v.size()!=4 or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not v.get("target") is int or v["target"] not in b["enemies"] or not v.get("turn") is int or v["turn"]<1 or v["turn"]>b["turn"] or not v.get("attack") is bool:return false
    for key:String in ["vulnerable","destiny","airborne","spent_electric","mirror"]:
        for uid:Variant in c[key]:
            if not uid is int or uid not in b["enemies"]:return false
            var v:Variant=c[key][uid]
            if key=="mirror":
                if not v is Dictionary or v.size()!=2 or not v.get("source") is int or v["source"] not in b["party"] or not v.get("move") is int or TacticalMoves.visual(v["move"]).is_empty() or not flag(v["move"],7):return false
            elif not v is bool or not v:return false
    return true

static func source_left(b: TacticalBattle,uid: int) -> void:
    var c:=write(b)
    for target: int in c["traps"].keys():
        if c["traps"][target]["source"]==uid:c["traps"].erase(target)
    for target: int in c["infatuation"].keys():
        if c["infatuation"][target]["source"]==uid:c["infatuation"].erase(target)
    for key:String in ["guards","substitutes","roots","destiny","vulnerable","airborne"]:c[key].erase(uid)

static func finish_card(b: TacticalBattle) -> void:
    # Finish the card's drain/heal/relic effects before the forced knockout.
    # No healing tail may revive a Pokemon already knocked out by Destiny Bond.
    var c:=write(b)
    var uid:=int(c["bond_pending"])
    c["bond_pending"]=0
    var actor:=b.member(uid)
    if actor!=null and actor.alive():
        b._record("status","길동무 · 쓰러뜨린 출전자도 기절",{"target":uid})
        b._damage(actor,actor.hp,true)
