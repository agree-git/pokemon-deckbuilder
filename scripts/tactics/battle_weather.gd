class_name BattleWeather
extends RefCounted
## One shared, finite weather. Stored in v3 powers; never uses battle RNG.
const KINDS := ["rain","snow","sun","sand"]
const TITLES := {"rain":"비","snow":"눈","sun":"쾌청","sand":"모래바람"}
const MOVES := {240:"rain",258:"snow",241:"sun",201:"sand"}
const TURNS := 5
static func kind(powers: Dictionary) -> String:
    for key: String in KINDS:
        if int(powers.get("weather_"+key,0)) > 0: return key
    return ""
static func remaining(powers: Dictionary) -> int:
    var key := kind(powers)
    return int(powers.get("weather_"+key,0)) if not key.is_empty() else 0
static func clear(powers: Dictionary) -> void:
    for key: String in KINDS: powers.erase("weather_"+key)
static func apply(b: TacticalBattle,key: String) -> void:
    if key not in KINDS: return
    clear(b.powers)
    b.powers["weather_"+key] = TURNS
    b._record("weather",TITLES[key]+" · %d턴" % TURNS,{"weather":key})
static func description(key: String) -> String:
    return {"rain":"물 공격 피해 ×1.5 · 불꽃 공격 피해 ×0.5","sun":"불꽃 공격 피해 ×1.5 · 물 공격 피해 ×0.5","snow":"얼음 타입의 물리 방어 ×1.5 · 지속 피해 없음","sand":"바위 타입 특방 ×1.5 · 턴 종료 시 출전 포켓몬 최대 HP의 1/16 피해 · 바위·땅·강철 면역"}.get(key,"")
static func tooltip(key: String) -> String:
    return TITLES.get(key,"")+" · 5턴 · 양쪽 모두 적용\n"+description(key)+"\n다른 날씨로 교체 · 재사용 시 5턴 갱신 · 교대 시 유지 · 상대 행동 후 1턴 경과"
static func attack_factor(key: String,type: String) -> float:
    if type not in ["water","fire"]: return 1.0
    if key == "rain": return 1.5 if type == "water" else 0.5
    if key == "sun": return 1.5 if type == "fire" else 0.5
    return 1.0
static func defense_factor(key: String,target: BattlePokemon,special: bool) -> float:
    if key == "snow" and not special and "ice" in target.types: return 1.5
    if key == "sand" and special and "rock" in target.types: return 1.5
    return 1.0
static func end_round(b: TacticalBattle,foe: BattlePokemon) -> void:
    var key := kind(b.powers)
    if key.is_empty(): return
    # Process both original recipients before outcomes; no damage to a new foe.
    if key == "sand":
        for p: BattlePokemon in [b.active(),foe]:
            if not p.alive() or p.types.any(func(t: String): return t in ["rock","ground","steel"]): continue
            b._record("weather_tick","모래바람 · "+p.display_name,{"target":p.uid})
            b._damage(p,maxi(1,floori(p.max_hp/16.0)),true)
    var left := remaining(b.powers)-1
    if left <= 0:
        clear(b.powers)
        b._record("weather_end",TITLES[key]+" 종료")
    else:
        b.powers["weather_"+key] = left
        b._record("weather_turn",TITLES[key]+" · %d턴 남음" % left)
