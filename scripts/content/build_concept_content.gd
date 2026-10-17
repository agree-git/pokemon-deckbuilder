class_name BuildConceptContent
extends RefCounted
## Pure descriptions and catalogue metadata, independent of mutable combat.
const GROUPS := {
    "relay":["relay_formation","relay_accelerate","relay_command","relay_cycle_plan"],
    "ace":["ace_retrieve","ace_precision","ace_reserve","ace_breathing"],
    "status":["status_catalyst","status_ampoule","status_analysis","status_absorption"],
    "shield":["shield_lock","shield_inspect","shield_regroup","shield_fortress"],
    "supply":["supply_recycle","supply_pack","supply_dynamo","supply_assembly"],
    "cycle":["cycle_filter","cycle_preserve","cycle_opportunity","cycle_engine"],
}
const RELICS := {
    "relay":["relay_signal","manual_pin"],"ace":["ace_sight","ace_calm"],
    "status":["status_ember","status_vial"],"shield":["shield_pad","shield_badge"],
    "supply":["tool_pouch","tool_discount"],"cycle":["cycle_spring","cycle_bookmark"],
}
const TITLES := {"relay":"교대·협동","ace":"에이스 집중","status":"상태·지속","shield":"보호막·요새","supply":"소진·도구","cycle":"순환·보존"}
const ICONS := {"relay":"switch","ace":"attack","status":"poison","shield":"shield","supply":"energy","cycle":"draw"}
const POWER_TITLES := {"relay_cycle":"순환 작전","ace_guard":"침착한 호흡","toxin_heal":"흡수 작전","bulwark":"요새 작전","tool_bonus":"현장 조립","cycle_energy":"재순환 엔진","energy_bank":"다음 턴 에너지 비축"}
const POWER_TEXT := {
    "relay_cycle":"지속: 매 턴 첫 기술 자동 교대 시 카드 1장 뽑기",
    "ace_guard":"지속: 턴 시작 출전 멤버의 첫 기술 사용 시 해당 멤버 보호막 + 최대 HP의 10.4%",
    "toxin_heal":"지속: 매 턴 첫 적 화상·독·씨앗 HP 피해 시 현재 출전 멤버 HP를 최대 HP의 4.2% 회복",
    "bulwark":"지속: 아군 턴 종료 시 출전 멤버 보호막 + 최대 HP의 12.5%",
    "tool_bonus":"지속: 매 턴 첫 소진 도구 사용 시 다음 공격 추가 피해 + 다음 공격자 최대 HP의 8.3%",
    "cycle_energy":"지속: 매 턴 첫 버린 더미 재섞기 시 에너지 +1",
}
static func condition_text(key: String) -> String:
    return {"relay":"이번 턴 기술로 교대했다면","ace":"출전 멤버가 이번 턴 기술을 2회 이상 썼다면","status":"사용 전 적에게 화상·독·씨앗 중 두 종류 이상이 있다면","shield":"사용 전 출전 멤버에게 보호막이 있다면","cycle":"이번 턴 버린 더미를 다시 섞었다면"}.get(key,"")
static func describe(v: Dictionary) -> Array[String]:
    var result: Array[String] = []
    if v.has("party_block"): result.append("살아 있는 모든 동료 보호막 + 각자 최대 HP의 "+PokemonStats.percent(v["party_block"])+" · 지닌 물건 가산 제외")
    if v.has("team_bonus"): result.append("이번 턴 기술을 쓴 서로 다른 동료 1마리마다 다음 공격 추가 피해 + 다음 공격자 최대 HP의 "+PokemonStats.percent(v["team_bonus"]))
    if v.has("bank_energy"): result.append("다음 아군 턴 에너지 +%d 비축 · 이번 전투 안에서만" % v["bank_energy"])
    if v.has("extend_status"): result.append("적의 현재 화상·독·씨앗 남은 횟수 각각 +%d · 재부여 아님 · 최대 100회" % v["extend_status"])
    if v.has("keep_block"): result.append("출전 멤버의 남은 보호막을 다음 아군 턴 시작에 전부 보존 · 해당 멤버에 1회 · 중첩 불가")
    if v.has("recover_tool"): result.append("소진 더미에서 가장 최근 도구 카드 1장 회수 · 실제 사본 유지 · 손패가 가득 차면 그대로 남음")
    if v.has("cycle_discard"): result.append("남은 손패에서 비용이 가장 낮은 카드 1장을 버린 뒤 뽑기 · 동률은 손패 앞 카드")
    if v.has("retain_all"): result.append("남은 손패 전부를 다음 턴까지 보존 · 다음 턴에도 손패 상한 10장")
    return result
static func condition_rows(key: String) -> Array[String]:
    var i := CardEffectText.icon
    match key:
        "relay": return ["이번 턴 기술로 교대 시"]
        "ace": return ["출전 멤버가 이번 턴","기술 2회 이상 사용 시"]
        "status": return ["사용 전 적에게 "+i.call("burn")+i.call("ailment_poison")+i.call("seed"),"두 종류 이상 있다면"]
        "shield": return ["사용 전 자신에게",i.call("shield")+"있다면"]
        "cycle": return ["이번 턴 버린 더미를","다시 섞었다면"]
    return []
static func effect_rows(v: Dictionary) -> Array[String]:
    var r: Array[String] = []
    if v.has("party_block"):
        r.assign(["살아 있는 모든 동료",CardEffectText.icon("shield")+"+"+PokemonStats.percent(v["party_block"]),"각자 최대 "+CardEffectText.icon("heal")+"기준"])
    if v.has("team_bonus"):
        r.append_array(["이번 턴 기술 쓴 동료","서로 다른 1마리마다","다음 "+CardEffectText.icon("attack")+"+"+PokemonStats.percent(v["team_bonus"]),"다음 공격자 최대 "+CardEffectText.icon("heal")+"기준"])
    if v.has("bank_energy"): r.append_array(["다음 아군 턴",CardEffectText.icon("energy")+"+%d 비축" % v["bank_energy"],"이번 전투에서만 유지"])
    if v.has("extend_status"): r.append_array(["적의 "+CardEffectText.icon("burn")+CardEffectText.icon("ailment_poison")+CardEffectText.icon("seed"),"남은 횟수 각각 +%d" % v["extend_status"],"재부여 아님"])
    if v.has("keep_block"): r.append_array(["이 멤버의 남은 "+CardEffectText.icon("shield"),"다음 아군 턴까지 보존","해당 멤버에 1회 적용"])
    if v.has("recover_tool"): r.append_array(["소진 더미에서","가장 최근 도구 1장을","손패로 가져오기"])
    if v.has("cycle_discard"): r.append_array(["비용이 가장 낮은","손패 1장 먼저 버리기"])
    if v.has("retain_all"): r.append_array(["남은 손패 모두","다음 턴까지 보존"])
    return r
static func power_rows(key: String) -> Array[String]:
    match key:
        "relay_cycle": return ["매 턴 첫 기술 자동 교대 시",CardEffectText.icon("draw")+"1장 뽑기"]
        "ace_guard": return ["턴 시작 출전 멤버의","첫 기술 사용 시",CardEffectText.icon("shield")+"+10.4%","자신 최대 "+CardEffectText.icon("heal")+"기준"]
        "toxin_heal": return ["매 턴 첫 적의",CardEffectText.icon("burn")+CardEffectText.icon("ailment_poison")+CardEffectText.icon("seed")+"로",CardEffectText.icon("heal")+"감소 시","출전 멤버 "+CardEffectText.icon("heal")+"4.2% 회복"]
        "bulwark": return ["내 턴 종료 시 출전 멤버",CardEffectText.icon("shield")+"+12.5%","자신 최대 "+CardEffectText.icon("heal")+"기준"]
        "tool_bonus": return ["매 턴 첫 소진 도구 사용 시","다음 "+CardEffectText.icon("attack")+"+8.3%","다음 공격자 최대 "+CardEffectText.icon("heal")+"기준"]
        "cycle_energy": return ["매 턴 첫 버린 더미","재섞기 시 "+CardEffectText.icon("energy")+"+1"]
    return []
