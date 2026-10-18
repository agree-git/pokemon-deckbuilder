class_name PlayerMoveAssistMath
extends RefCounted
## v18: aimed attacks bypass aerial evasion, preserving native guards and substitutes.
static func boss_player_damage(b: TacticalBattle,view: Dictionary,amount: int) -> int:
    if not BossBattleEffectsP3.active_in(b): return amount
    if BossBattleEffectsP3.protected(b,view): return 0
    var target:=b.enemy()
    if BossBattleEffectsP3.read(b)["airborne"].get(target.uid,false) and int(view.get("move_id",0)) in [16,239] and amount>0:amount*=2
    if BossBattleEffectsP3.read(b)["vulnerable"].get(target.uid,false) and view.has("damage") and amount>0:amount*=2
    var actor:=b.member(int(view.get("owner_uid",0)))
    # card_view supplies the exact owner; shared cards never trigger attraction.
    if actor!=null and BossBattleEffectsP3.read(b)["infatuation"].get(actor.uid,{}).get("source",0)==target.uid and amount>0:amount=maxi(1,amount/2)
    if BossBattleEffectsP3.read(b)["screen"]>0 and view.get("damage_class")=="special" and int(view.get("move_id",0))!=280 and amount>0: return maxi(1,amount/2)
    return amount
static func boss_filter_view(b: TacticalBattle,original: Dictionary) -> Dictionary:
    var v:=original.duplicate(true)
    var guarded:=BossBattleEffectsP3.protected(b,v)
    var sub: bool=BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0 and not BossBattleEffectsP3.flag(int(v.get("move_id",0)),9) and not BossBattleEffectsP3.flag(int(v.get("move_id",0)),14)
    if guarded:
        if v.get("category")=="technique" and BossBattleEffectsP3.flag(int(v.get("move_id",0)),1) and (v.has("damage") or v.has("shield_attack")):v["boss_contact_guard"]=BossBattleEffectsP3.read(b)["guards"].get(b.enemy().uid,"")
        v["boss_blocked"]=true
    for key: String in BossBattleEffectsP3.TARGET_EFFECTS:
        if guarded or sub or (BossBattleEffectsP3.read(b)["safeguard"]>0 and key in ["burn","poison","sleep","paralysis","confusion"]):v.erase(key)
    if (guarded or sub) and v.get("stat_target")=="enemy":v.erase("stat_changes")
    return v
static func boss_on_card(b: TacticalBattle,original: Dictionary,actor: BattlePokemon) -> void:
    var c:=BossBattleEffectsP3.write(b)
    c["acted"][actor.uid]=b.turn
    c["card_attacker"]=actor.uid if original.get("category")=="technique" else 0
    if original.get("category")=="technique":
        var move_id:=int(original.get("move_id",0))
        var attack:bool=original.has("damage") or original.has("shield_attack")
        c["last_moves"][actor.uid]={"move":move_id,"target":b.enemy().uid,"turn":b.turn,"attack":attack}
        if attack and BossBattleEffectsP3.flag(move_id,7):c["mirror"][b.enemy().uid]={"source":actor.uid,"move":move_id}
    var id:=int(original.get("move_id",0))
    if BossBattleEffectsP3.protected(b,original):
        b._record("cancel","상대의 방어 · 대상 효과 차단")
        return
    if id in [479,614] and int(original.get("preview_damage",0))>0 and c["airborne"].has(b.enemy().uid):
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
static func boss_card_notice(b: TacticalBattle,v: Dictionary,actor: BattlePokemon) -> String:
    var notes: Array[String]=[]
    if BossBattleEffectsP3.protected(b,v):notes.append("상대 방어로 대상 효과 차단")
    if BossBattleEffectsP3.read(b)["substitutes"].get(b.enemy().uid,0)>0:notes.append("대타출동 유지 · 대타를 깬 타격의 초과 피해 없음")
    if BossBattleEffectsP3.read(b)["safeguard"]>0:notes.append("신비의부적 · 상태 부여 차단")
    if actor!=b.active() and BossBattleEffectsP3.read(b)["rocks"]:notes.append("교대 시 스텔스록 HP -%d" % BossBattleEffectsP3.entry_damage(b,actor))
    if int(v.get("move_id",0)) in [229,432,866,280]:notes.append("설치/장막 해제 효과 지원")
    var why:=BossBattleEffectsP3.card_reason(b,v,actor)
    if not why.is_empty():notes.append(why)
    if BossBattleEffectsP3.read(b)["infatuation"].has(actor.uid):notes.append("헤롱헤롱 · 시전자 대상 기술 피해 절반 · 교대로 해제")
    if BossBattleEffectsP3.trapped(b):notes.append("교체 봉쇄 · 현재 동료 기술/도구는 사용 가능")
    return "\n".join(notes)
