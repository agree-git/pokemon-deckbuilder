class_name BossBattleEffects
extends RefCounted
## Optional battle context used only by v8 representative encounters.
const DEFAULT := {"rocks":false,"screen":0,"safeguard":0,"gravity":0,"received":{},"acted":{},"hurt":{},"guards":{},"substitutes":{},"roots":{},"traps":{},"last_enemy_ko":0,"last_switch":0}
const TARGET_EFFECTS := ["burn","seed","poison","sleep","paralysis","confusion","weaken","expose","cash","pulse_status"]
static func active_in(b: TacticalBattle) -> bool:
    return b.enemy_definitions.any(func(d: Dictionary):return d.get("boss_moves_version")==3)
static func read(b: TacticalBattle) -> Dictionary:
    return b.boss_context if not b.boss_context.is_empty() else DEFAULT
static func write(b: TacticalBattle) -> Dictionary:
    if b.boss_context.is_empty(): b.boss_context=DEFAULT.duplicate(true)
    return b.boss_context
static func received(b: TacticalBattle,uid: int) -> Dictionary:
    var r: Dictionary=read(b)["received"].get(uid,{})
    return r if r.get("turn",0)==b.turn else {"damage":0,"kind":""}
static func flag(id: int,value: int) -> bool:
    return value in BossMoveEffectsP2.data()["move_flags"].get(str(id),[])
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
    if protected(b,view): return 0
    if read(b)["screen"]>0 and view.get("damage_class")=="special" and int(view.get("move_id",0))!=280 and amount>0: return maxi(1,amount/2)
    return amount
static func filter_view(b: TacticalBattle,original: Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    var guarded:=protected(b,v)
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
    var id:=int(original.get("move_id",0))
    if protected(b,original):
        b._record("cancel","상대의 방어 · 대상 효과 차단")
        return
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
        if target.uid<0:c["last_enemy_ko"]=b.turn
        for group: String in ["guards","substitutes","roots","traps"]:c[group].erase(target.uid)
        for uid: int in c["traps"].keys():
            if c["traps"][uid]["source"]==target.uid:c["traps"].erase(uid)
static func begin_enemy(b: TacticalBattle) -> void:
    write(b)["guards"].erase(b.enemy().uid)
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
    var trap: Dictionary=read(b)["traps"].get(p.uid,{})
    if trap.is_empty() or not trap["dot"]:return
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
    var types:=target.types.duplicate()
    if attack=="ground" and (read(b)["gravity"]>0 or read(b)["roots"].get(target.uid,false)):types.erase("flying")
    return TypeMatchup.multiplier(attack,types)
static func card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    var notes: Array[String]=[]
    if protected(b,v):notes.append("상대 방어로 대상 효과 차단")
    if read(b)["substitutes"].get(b.enemy().uid,0)>0:notes.append("대타출동 유지 · 대타를 깬 타격의 초과 피해 없음")
    if read(b)["safeguard"]>0:notes.append("신비의부적 · 상태 부여 차단")
    if actor!=b.active() and read(b)["rocks"]:notes.append("교대 시 스텔스록 HP -%d" % entry_damage(b,actor))
    if int(v.get("move_id",0)) in [229,432,866,280]:notes.append("설치/장막 해제 효과 지원")
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
    return "\n".join(lines)
static func valid_context(c: Variant,b: Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=DEFAULT.size():return false
    for key: String in DEFAULT:
        if not c.has(key) or typeof(c[key])!=typeof(DEFAULT[key]):return false
    var enabled:=false
    for d: Variant in b["enemy_definitions"]:
        if not d is Dictionary:return false
        enabled=enabled or d.get("boss_moves_version")==3
    if not enabled:return false
    for key: String in ["screen","safeguard","gravity"]:
        if c[key]<0 or c[key]>6:return false
    for key: String in ["last_enemy_ko","last_switch"]:
        if c[key]<0 or c[key]>b["turn"]:return false
    for key: String in ["acted","hurt"]:
        for uid: Variant in c[key]:
            if not uid is int or uid not in b["party"]+b["enemies"] or not c[key][uid] is int or c[key][uid]<1 or c[key][uid]>b["turn"]:return false
    for uid: Variant in c["received"]:
        var r: Variant=c["received"][uid]
        if not uid is int or uid not in b["enemies"] or not r is Dictionary or r.size()!=3:return false
        if not r.get("turn") is int or r["turn"]<1 or r["turn"]>b["turn"] or not r.get("damage") is int or r["damage"]<1 or r["damage"]>100000 or r.get("kind") not in ["physical","special"]:return false
    for key: String in ["guards","substitutes","roots"]:
        for uid: Variant in c[key]:
            if not uid is int or uid not in b["enemies"]:return false
            var value: Variant=c[key][uid]
            if key=="guards" and value not in ["protect","king","obstruct"]:return false
            if key=="substitutes" and (not value is int or value<0 or value>25000):return false
            if key=="roots" and (not value is bool or not value):return false
    for uid: Variant in c["traps"]:
        var t: Variant=c["traps"][uid]
        if not uid is int or uid not in b["party"] or not t is Dictionary or t.size()!=3:return false
        if not t.get("source") is int or t["source"] not in b["enemies"] or not t.get("turns") is int or not t.get("dot") is bool:return false
        if (t["dot"] and (t["turns"]<1 or t["turns"]>4)) or (not t["dot"] and t["turns"]!=0):return false
    return true
