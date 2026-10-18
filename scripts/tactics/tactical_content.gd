class_name TacticalContent
extends RefCounted
## Shared skills and trainer cards for the single encounter and tactical journey.
const PARTY := [
    {"id":4,"uid":4,"name":"파이리","type":"fire","max_hp":45},
    {"id":1,"uid":1,"name":"이상해씨","type":"grass","max_hp":48},
    {"id":7,"uid":7,"name":"꼬부기","type":"water","max_hp":52},
]
const SKILLS := {4:["ember","flame","fire_guard"],1:["vine","seed","growth"],7:["water_gun","shell","tackle"]}

static func skills_for(pokemon: BattlePokemon) -> Array:
    if pokemon.progression_initialized or not pokemon.learned_skills.is_empty(): return pokemon.learned_skills
    if SKILLS.has(pokemon.species_id): return SKILLS[pokemon.species_id]
    if BattleContent.LEARNSETS.has(pokemon.species_id): return BattleContent.LEARNSETS[pokemon.species_id]
    return {"fire":["ember","flame","fire_guard"],"water":["water_gun","shell","tackle"],"grass":["vine","seed","growth"]}.get(pokemon.type,["tackle","guard","growth"])

static func member_definition(id: int,catalog: VisualCatalog) -> Dictionary:
    for definition: Dictionary in PARTY:
        if definition["id"] == id: return definition.duplicate(true)
    var species := catalog.species(id)
    return {"id":id,"uid":id,"name":species["name"],"type":species["types"][0],"max_hp":48}

const ENEMIES := [
    {"id":43,"name":"뚜벅쵸","type":"grass","max_hp":40,"intents":[
        {"kind":"charge","value":14,"type":"normal","move_id":33},
        {"kind":"block","value":6,"move_id":115},
        {"kind":"attack","value":9,"type":"grass","move_id":22}]},
    {"id":58,"name":"가디","type":"fire","max_hp":48,"intents":[
        {"kind":"charge","value":14,"type":"fire","move_id":52},
        {"kind":"boost","value":2,"move_id":74},
        {"kind":"attack","value":10,"type":"normal","move_id":33}]},
]
# A compact shared deck. Pokemon techniques are added by starting_deck().
const DECK := ["guard","guard","focus","rally","potion_card","analysis"]
const CARDS := {
    "analysis":{"name":"전장 분석","category":"trainer","cost":0,"move_id":116,"draw":1,"weaken":1,"exhaust":true,"description":"적 공격 -1 · 카드 1장 뽑기. 소진."},
    "guard":{"name":"방어 지시","category":"trainer","cost":1,"move_id":115,"block":8,"description":"출전 포켓몬이 보호막 8을 얻습니다."},
    "focus":{"name":"전술 정리","category":"trainer","cost":0,"move_id":116,"draw":2,"exhaust":true,"description":"카드 2장 뽑기. 소진."},
    "rally":{"name":"강화 지시","category":"trainer","cost":1,"move_id":74,"bonus":7,"description":"다음 공격의 기본 피해 +7. 교대해도 유지."},
    "counter":{"name":"견제 지시","category":"trainer","cost":1,"move_id":43,"weaken":3,"block":4,"description":"적 공격 -3 · 보호막 4."},
    "redraw":{"name":"작전 변경","category":"trainer","cost":0,"move_id":116,"redraw":true,"exhaust":true,"description":"남은 손패를 모두 버리고 그 수만큼 뽑기. 소진."},
    "hold":{"name":"대기 지시","category":"trainer","cost":0,"move_id":116,"retain":true,"description":"손패에서 비용이 가장 높은 카드 1장을 다음 턴까지 보존."},
    "retrieve":{"name":"재정비","category":"trainer","cost":1,"move_id":116,"retrieve":true,"description":"버린 더미의 가장 최근 기술 카드 1장을 손으로 회수."},
    "relay_plan":{"name":"릴레이 작전","category":"trainer","cost":1,"move_id":97,"power":"relay","description":"지속: 기술로 교대할 때 출전 포켓몬이 보호막 3 획득. 전투 동안 유지."},
    "ace_plan":{"name":"에이스 육성","category":"trainer","cost":1,"move_id":74,"power":"ace","description":"지속: 출전 포켓몬을 유지해 턴을 마치면 다음 턴 위력 보정 +20%."},
    "tool_plan":{"name":"보급 작전","category":"trainer","cost":1,"move_id":115,"power":"supply","description":"지속: 도구 카드를 쓸 때 출전 포켓몬이 보호막 5 획득."},
    "status_cash":{"name":"상태 회수","category":"trainer","cost":1,"move_id":92,"cash":true,"description":"적의 화상·독·씨앗을 모두 제거하고 남은 횟수당 4 피해. 상성 무시."},
    "potion_card":{"name":"응급 회복약","category":"tool","cost":1,"move_id":105,"heal":16,"exhaust":true,"description":"출전 포켓몬의 HP 16 회복. 소진."},
    "boost_card":{"name":"배틀 강화제","category":"tool","cost":0,"move_id":74,"temporary_strength":4,"exhaust":true,"description":"출전 포켓몬의 공격 +4. 교대하면 해제. 소진."},
    "smoke_card":{"name":"연막탄","category":"tool","cost":1,"move_id":108,"weaken":4,"draw":1,"exhaust":true,"description":"적 공격 -4 · 카드 1장 뽑기. 소진."},
    "ether_card":{"name":"에너지 팩","category":"tool","cost":0,"move_id":116,"energy":2,"exhaust":true,"description":"에너지 +2. 소진."},
    "antidote_card":{"name":"만능 치료제","category":"tool","cost":0,"move_id":105,"cleanse":true,"heal":5,"exhaust":true,"description":"출전 포켓몬 상태이상 제거 · HP 5 회복. 소진."},
    "relay_cover":{"name":"교대 엄호","category":"trainer","cost":1,"move_id":115,"block":6,"conditional_draw":2,"condition":"relay","description":""},
    "ace_order":{"name":"집중 지시","category":"trainer","cost":1,"move_id":116,"bonus":5,"conditional_draw":2,"condition":"ace","description":""},
    "status_plan":{"name":"소모전 작전","category":"trainer","cost":1,"move_id":92,"power":"attrition","description":""},
    "shield_strike":{"name":"보호막 전환","category":"trainer","cost":1,"move_id":33,"shield_attack":true,"description":"보호막을 모두 소비해 같은 수치의 피해. 상성 무시, 적 보호막 적용."},
    "toxic_flask":{"name":"독성 캡슐","category":"tool","cost":1,"move_id":92,"poison":3,"exhaust":true,"description":""},
    "shield_cell":{"name":"방어 배터리","category":"tool","cost":0,"move_id":115,"block":6,"exhaust":true,"description":""},
    "relay_retrieve":{"name":"연계 회수","category":"trainer","cost":1,"move_id":116,"retrieve":true,"retrieve_scope":"reserve","retrieve_count":2,"exhaust":true,"description":""},
    "ace_finisher":{"name":"결정타 지시","category":"trainer","cost":1,"move_id":116,"finisher":true,"exhaust":true,"description":""},
    "status_pulse":{"name":"발병 촉진","category":"tool","cost":1,"move_id":92,"pulse_status":true,"exhaust":true,"description":""},
    "shield_double":{"name":"방벽 압축","category":"trainer","cost":1,"move_id":115,"double_block":true,"exhaust":true,"description":""},
    "relay_formation":{"name":"대열 정비","cost":1,"party_block":4,"upgrade":{"party_block":6},"category":"trainer","move_id":97,"concept":"relay","description":""},
    "relay_accelerate":{"name":"교대 가속","cost":0,"draw":1,"condition":"relay","conditional_energy":1,"exhaust":true,"upgrade":{"draw":2},"category":"trainer","move_id":97,"concept":"relay","description":""},
    "relay_command":{"name":"합동 지휘","cost":1,"team_bonus":4,"upgrade":{"team_bonus":6},"category":"trainer","move_id":97,"concept":"relay","description":""},
    "relay_cycle_plan":{"name":"순환 작전","cost":1,"power":"relay_cycle","upgrade":{"cost":0},"category":"trainer","move_id":97,"concept":"relay","description":""},
    "ace_retrieve":{"name":"전담 회수","cost":1,"retrieve":true,"retrieve_scope":"active","retrieve_count":2,"exhaust":true,"upgrade":{"retrieve_count":3},"category":"trainer","move_id":116,"concept":"ace","description":""},
    "ace_precision":{"name":"일점 집중","cost":1,"bonus":5,"condition":"ace","conditional_bonus":5,"upgrade":{"bonus":7,"conditional_bonus":7},"category":"trainer","move_id":116,"concept":"ace","description":""},
    "ace_reserve":{"name":"전력 비축","cost":0,"bank_energy":1,"exhaust":true,"upgrade":{"bank_energy":2},"category":"trainer","move_id":116,"concept":"ace","description":""},
    "ace_breathing":{"name":"침착한 호흡","cost":1,"power":"ace_guard","upgrade":{"cost":0},"category":"trainer","move_id":116,"concept":"ace","description":""},
    "status_catalyst":{"name":"지속 촉매","cost":1,"extend_status":1,"exhaust":true,"upgrade":{"extend_status":2},"category":"trainer","move_id":92,"concept":"status","description":""},
    "status_ampoule":{"name":"화상 앰풀","cost":1,"burn":3,"exhaust":true,"upgrade":{"cost":0},"category":"tool","move_id":52,"concept":"status","description":""},
    "status_analysis":{"name":"오염 분석","cost":1,"draw":1,"condition":"status","conditional_draw":2,"upgrade":{"draw":2},"category":"trainer","move_id":92,"concept":"status","description":""},
    "status_absorption":{"name":"흡수 작전","cost":1,"power":"toxin_heal","upgrade":{"cost":0},"category":"trainer","move_id":92,"concept":"status","description":""},
    "shield_lock":{"name":"방벽 고정","cost":1,"keep_block":true,"exhaust":true,"upgrade":{"cost":0},"category":"trainer","move_id":115,"concept":"shield","description":""},
    "shield_inspect":{"name":"방패 점검","cost":0,"draw":1,"condition":"shield","conditional_energy":1,"exhaust":true,"upgrade":{"draw":2},"category":"trainer","move_id":115,"concept":"shield","description":""},
    "shield_regroup":{"name":"수비 재정비","cost":1,"block":6,"condition":"shield","conditional_draw":2,"upgrade":{"block":10},"category":"trainer","move_id":115,"concept":"shield","description":""},
    "shield_fortress":{"name":"요새 작전","cost":2,"power":"bulwark","upgrade":{"cost":1},"category":"trainer","move_id":115,"concept":"shield","description":""},
    "supply_recycle":{"name":"도구 재활용","cost":1,"recover_tool":1,"exhaust":true,"upgrade":{"cost":0},"category":"trainer","move_id":116,"concept":"supply","description":""},
    "supply_pack":{"name":"만능 보급","cost":1,"heal":6,"block":6,"exhaust":true,"upgrade":{"heal":8,"block":8},"category":"tool","move_id":105,"concept":"supply","description":""},
    "supply_dynamo":{"name":"긴급 동력","cost":1,"energy":2,"draw":1,"exhaust":true,"upgrade":{"energy":3},"category":"tool","move_id":116,"concept":"supply","description":""},
    "supply_assembly":{"name":"현장 조립","cost":1,"power":"tool_bonus","upgrade":{"cost":0},"category":"trainer","move_id":116,"concept":"supply","description":""},
    "cycle_filter":{"name":"선별 정리","cost":0,"cycle_discard":1,"draw":2,"exhaust":true,"upgrade":{"draw":3},"category":"trainer","move_id":116,"concept":"cycle","description":""},
    "cycle_preserve":{"name":"계획 보존","cost":1,"retain_all":true,"exhaust":true,"upgrade":{"cost":0},"category":"trainer","move_id":116,"concept":"cycle","description":""},
    "cycle_opportunity":{"name":"되찾은 기회","cost":0,"retrieve":true,"retrieve_count":1,"condition":"cycle","conditional_energy":1,"exhaust":true,"upgrade":{"retrieve_count":2},"category":"trainer","move_id":116,"concept":"cycle","description":""},
    "cycle_engine":{"name":"재순환 엔진","cost":1,"power":"cycle_energy","upgrade":{"cost":0},"category":"trainer","move_id":116,"concept":"cycle","description":""},
    "weather_rain":{"name":"비 작전","cost":1,"weather":"rain","upgrade":{"cost":0},"category":"trainer","move_id":240,"description":""},
    "weather_snow":{"name":"눈 작전","cost":1,"weather":"snow","upgrade":{"cost":0},"category":"trainer","move_id":258,"description":""},
    "weather_sun":{"name":"쾌청 작전","cost":1,"weather":"sun","upgrade":{"cost":0},"category":"trainer","move_id":241,"description":""},
    "weather_sand":{"name":"모래바람 작전","cost":1,"weather":"sand","upgrade":{"cost":0},"category":"trainer","move_id":201,"description":""},
    "injury":{"name":"부상","category":"status","cost":1,"move_id":150,"description":"효과 없음. 기절 시 추가되며 야영지 휴식으로 제거."},
}
const RELICS := {
    "relay_core":{"name":"순환 엔진","icon":"switch","core":true,"benefit":"매 턴 첫 기술 자동 교대 시 카드 2장 뽑기","tradeoff":"첫 턴을 포함한 턴 시작 드로우 4장","description":"매 턴 첫 기술 자동 교대 시 카드 2장 뽑기 · 대가: 첫 턴을 포함한 턴 시작 드로우 4장"},
    "ace_core":{"name":"고정 조준경","icon":"attack","core":true,"benefit":"턴 시작 출전 멤버의 첫 기술 비용 -1 (최소 0)","tradeoff":"직접 교대 비용 2 · 기술/강제 교대는 무료","description":"턴 시작 출전 멤버의 첫 기술 비용 -1 (최소 0) · 대가: 직접 교대 비용 2 · 기술/강제 교대는 무료"},
    "status_core":{"name":"침식 촉매","icon":"poison","core":true,"benefit":"적의 화상·독·씨앗 매회 피해 +50%","tradeoff":"기술 카드의 직접 공격 피해 -20%","description":"적의 화상·독·씨앗 매회 피해 +50% · 대가: 기술 카드의 직접 공격 피해 -20%"},
    "shield_core":{"name":"잔류 방벽","icon":"shield","core":true,"benefit":"아군 턴 시작 시 각 동료의 보호막 절반 보존","tradeoff":"카드로 회복하는 HP -50% · 야영지 회복은 유지","description":"아군 턴 시작 시 각 동료의 보호막 절반 보존 · 대가: 카드로 회복하는 HP -50% · 야영지 회복은 유지"},
    "supply_core":{"name":"비상 보급함","icon":"energy","core":true,"benefit":"매 턴 첫 소진 도구 사용 시 에너지 +1 · 2장 뽑기","tradeoff":"첫 턴을 포함한 턴 시작 드로우 4장","description":"매 턴 첫 소진 도구 사용 시 에너지 +1 · 2장 뽑기 · 대가: 첫 턴을 포함한 턴 시작 드로우 4장"},
    "field_kit":{"name":"탐험 구급함","icon":"heal","description":"전투 시작 시 모든 아군이 최대 HP의 10.4% 보호막을 얻습니다."},
    "seed_relay":{"name":"씨앗 전이","icon":"seed","description":"씨뿌리기 대상이 쓰러지면 남은 씨앗을 다음 적에게 옮깁니다."},
    "switch_power":{"name":"교대 배턴","icon":"switch","description":"기술로 교대한 포켓몬의 다음 공격 추가 피해 · 최대 HP의 6.3%. 턴 종료 시 해제."},
    "relay_draw":{"name":"릴레이 수첩","icon":"draw","description":"한 턴에 서로 다른 아군 3마리가 기술을 사용하면 카드 2장 뽑기. 턴당 한 번."},
    "ace_focus":{"name":"에이스의 깃발","icon":"boost","description":"포켓몬을 유지해 턴을 마치면 다음 턴 해당 포켓몬 위력 보정 +10%."},
    "tool_belt":{"name":"보급 벨트","icon":"draw","description":"매 턴 처음 사용하는 도구 카드가 카드 1장을 뽑습니다."},
    "relay_cell":{"name":"릴레이 발전기","icon":"energy","description":"매 턴 처음 기술 카드로 교대하면 에너지 +1. 수동·강제 교대는 제외."},
    "ace_emblem":{"name":"집중 문장","icon":"draw","description":"한 포켓몬이 한 턴에 두 번째 기술을 쓰면 카드 1장 뽑기. 파티 전체에서 턴당 한 번."},
    "status_flask":{"name":"잔류 시약","icon":"poison","description":"매 턴 처음 카드로 화상·독·씨앗을 부여할 때 그 카드의 지속 횟수 +1. 수면 등에는 적용되지 않음."},
    "relay_cloak":{"name":"인계 망토","icon":"switch","description":"매 턴 첫 기술 자동 교대 시 이전 동료의 남은 보호막 전부를 새 동료에게 이동. 수동·강제 교대 제외."},
    "ace_medal":{"name":"돌파 훈장","icon":"energy","description":"같은 포켓몬이 한 턴 세 번째 기술을 쓰면 에너지 +1. 파티 전체에서 턴당 한 번."},
    "status_dish":{"name":"배양 접시","icon":"draw","description":"카드로 새로운 화상·독·씨앗을 걸어 적에게 두 종류 이상이 되면 카드 2장 뽑기. 턴당 한 번. 재부여 제외."},
    "shield_battery":{"name":"축전 방패","icon":"shield","description":"적의 공격을 보호막으로 완전히 막으면 다음 아군 턴 에너지 +1. 턴당 한 번. 피해 0인 공격·지속 피해 제외."},
    "relay_signal":{"name":"교차 신호기","icon":"draw","description":"한 턴에 서로 다른 동료 2마리가 기술을 쓰면 카드 1장 뽑기. 턴당 한 번."},
    "manual_pin":{"name":"안전 교대핀","icon":"switch","description":"매 턴 첫 직접 교대 비용 -1, 최소 0. 고정 조준경의 직접 교대 비용에도 적용. 강제 교대 제외."},
    "ace_sight":{"name":"에이스 조준기","icon":"attack","description":"턴 시작 출전 멤버의 첫 공격 기술 피해 +25%. 다른 동료·공격 외 기술 제외. 상성 무효는 0."},
    "ace_calm":{"name":"고요한 메달","icon":"draw","description":"교대 없이 턴을 마치면 다음 아군 턴 카드 1장 추가로 뽑기."},
    "status_ember":{"name":"잔열 결정","icon":"boost","description":"매 턴 처음 적이 화상·독·씨앗으로 실제 HP 피해를 받으면 다음 공격 추가 피해 +3. 다음 공격자 최대 HP 기준으로 환산."},
    "status_vial":{"name":"봉인 유리병","icon":"draw","description":"적 화상·독·씨앗이 정상 발동으로 남은 횟수를 모두 쓰면 카드 1장 뽑기. 턴당 한 번. 제거·즉시 발동 제외."},
    "shield_pad":{"name":"완충 패드","icon":"shield","description":"매 턴 처음 기본 효과로 보호막을 얻는 카드의 보호막 +3. 받는 동료 최대 HP 기준으로 환산. 압축·파티 보호막 제외."},
    "shield_badge":{"name":"보루 휘장","icon":"draw","description":"적의 양수 공격 피해를 보호막으로 완전히 막으면 다음 아군 턴 카드 1장 추가로 뽑기. 턴당 한 번. 지속 피해 제외."},
    "tool_pouch":{"name":"구조 파우치","icon":"heal","description":"매 턴 첫 소진 도구 사용 시 출전 멤버 HP 3 회복. 해당 멤버 최대 HP 기준으로 환산."},
    "tool_discount":{"name":"정밀 공구","icon":"energy","description":"매 턴 첫 도구 카드 비용 -1, 최소 0. 원래 0비용인 도구도 해당 턴 기회를 사용."},
    "cycle_spring":{"name":"되감기 태엽","icon":"shield","description":"매 턴 처음 버린 더미를 다시 섞으면 출전 멤버 보호막 4. 해당 멤버 최대 HP 기준으로 환산."},
    "cycle_bookmark":{"name":"보존 책갈피","icon":"energy","description":"손패 카드를 실제로 보존해 턴을 마치면 다음 아군 턴 에너지 +1. 여러 장이어도 한 번."},
    "status_lens":{"name":"상태 관측경","icon":"counter","description":"매 턴 처음 새로운 상태이상을 걸면 에너지 +1."},
}
const HELD_ITEMS := {
    "power_band":{"name":"힘의 머리띠","icon":"attack","description":"장착한 포켓몬의 공격 추가 피해 · 최대 HP의 6.3%."},
    "guard_charm":{"name":"수호 부적","icon":"shield","description":"장착한 포켓몬이 카드의 기본 효과로 얻는 보호막 추가 · 최대 HP의 8.3%."},
    "relay_ribbon":{"name":"교대 리본","icon":"switch","description":"매 턴 처음 교대해 출전할 때 최대 HP의 10.4% 보호막 획득."},
    "ace_band":{"name":"집중 밴드","icon":"boost","description":"장착한 포켓몬을 유지해 턴을 마치면 다음 턴 위력 보정 +10%."},
    "seed_charm":{"name":"생명의 부적","icon":"seed","description":"적에게 화상·독·씨앗이 있으면 턴 종료 시 장착자 최대 HP의 4.2% 회복."},
    "healing_bell":{"name":"치유의 방울","icon":"heal","description":"장착한 포켓몬이 도구 카드로 받는 회복 추가 · 최대 HP의 12.5%."},
}

static func definition(card: BattleCardInstance,player_version := 1) -> Dictionary:
    var result: Dictionary = ((PlayerMoveCards.definition(card.key) if player_version==2 else TacticalMoves.definition(card.key)) if card.owner_uid != 0 else CARDS.get(card.key,{})).duplicate(true)
    if result.is_empty(): return result
    result["category"] = "technique" if card.owner_uid != 0 else result.get("category","trainer")
    result["uid"] = card.uid
    result["key"] = card.key
    result["owner_uid"] = card.owner_uid
    if card.owner_uid != 0 and result.has("heal") and not result.has("damage"): result["exhaust"] = true
    if card.upgraded and result.has("upgrade"):
        for field: String in result["upgrade"]: result[field] = result["upgrade"][field]
        result["name"] += " +"
    elif card.upgraded:
        result["name"] += " +"
        var increased := false
        if result.has("move_power"):
            result["move_power"] = int(result["move_power"])+15
            increased = true
        if result.has("retain"):
            result["retain_count"] = 2
            result["description"] = "손패에서 비용이 가장 높은 카드 2장을 다음 턴까지 보존."
            increased = true
        if result.has("redraw"):
            result["redraw_bonus"] = 1
            result["description"] = "남은 손패를 버리고 그 수 +1장 뽑기."
            increased = true
        for field: String in ["damage","block","heal","bonus"]:
            if field == "damage" and result.has("move_power"): continue
            if result.has(field):
                result[field] = int(result[field])+4
                increased = true
        for field: String in ["draw","energy","strength","weaken","temporary_strength","conditional_draw","retrieve_count"]:
            if result.has(field):
                result[field] = int(result[field])+1
                increased = true
        if not increased: result["cost"] = maxi(0,int(result["cost"])-1)
    result["description"] = description(result)
    return result

static func can_upgrade(card: BattleCardInstance,player_version := 1) -> bool:
    if card.upgraded or card.key == "injury": return false
    var original := definition(card,player_version)
    var upgraded := BattleCardInstance.new(card.uid,card.key,card.owner_uid)
    upgraded.upgraded = true
    var improved := definition(upgraded,player_version)
    original.erase("name")
    improved.erase("name")
    return original != improved

static func description(view: Dictionary) -> String:
    var parts: Array[String] = []
    for field: String in ["damage","block","heal","strength","weaken","draw","energy","bonus","temporary_strength"]:
        if field == "damage" and view.has("move_power"):
            parts.append("위력 %d · %s" % [view["move_power"],"물리" if view.get("damage_class","") == "physical" else "특수"])
            continue
        if view.has(field):
            if field in ["block","heal","bonus"]:
                var title: String = {"block":"보호막","heal":"회복","bonus":"다음 공격 추가 피해"}[field]
                if field == "bonus" and view.has("concept"): parts.append("다음 공격 추가 피해 · 다음 공격자 최대 HP의 "+PokemonStats.percent(int(view[field])))
                else: parts.append("%s %d" % [title,view["preview_"+field]] if view.has("preview_"+field) else "%s · 최대 HP의 %s" % [title,PokemonStats.percent(int(view[field]))])
                continue
            parts.append({"damage":"피해 %d","block":"보호막 %d","heal":"회복 %d","strength":"위력 보정 +%d%%","weaken":"적 위력 보정 -%d%%","draw":"%d장 뽑기","energy":"에너지 +%d","bonus":"다음 공격 +%d","temporary_strength":"교대 전까지 위력 보정 +%d%%"}[field] % (int(view[field])*10 if field in ["strength","weaken","temporary_strength"] else int(view[field])))
    if view.has("stat_changes"):
        var changes: Dictionary = view["stat_changes"]
        var recipient := "자신" if view["stat_target"] == "self" else "상대"
        if changes.size() == 5 and changes.values().all(func(change: int): return change == 1):
            parts.append(recipient+" 모든 능력 +1단계")
        else:
            for stat: String in changes:
                parts.append("%s %s %+d단계" % [recipient,PokemonStats.TITLES[stat],changes[stat]])
    for status: String in ["burn","seed","poison","sleep","paralysis","confusion","expose"]:
        if view.has(status): parts.append({"burn":"화상","seed":"씨뿌리기","poison":"독","sleep":"수면","paralysis":"마비","confusion":"혼란","expose":"방어 약화"}[status]+" %d회" % int(view.get("preview_"+status,view[status])))
    if view.has("shield_attack"):
        parts.append("보호막 모두 소비 → 피해 %d · 상성 무시 · 적 보호막 적용" % int(view["preview_damage"]) if view.has("preview_damage") else "보호막 모두 소비 → 같은 수치의 피해 · 상성 무시 · 적 보호막 적용")
    if view.has("condition"):
        parts.append(BuildConceptContent.condition_text(str(view["condition"]))+((" (충족)" if view["condition_active"] else " (미충족)") if view.has("condition_active") else ""))
    if view.has("conditional_draw"):
        parts.append("조건 충족 시 %d장 뽑기" % int(view["conditional_draw"]))
    if view.has("conditional_energy"): parts.append("조건 충족 시 에너지 +%d" % int(view["conditional_energy"]))
    if view.has("conditional_bonus"): parts.append("조건 충족 시 다음 공격 추가 피해 + 다음 공격자 최대 HP의 "+PokemonStats.percent(int(view["conditional_bonus"])))
    if view.has("weather"): parts.append(BattleWeather.tooltip(str(view["weather"])))
    parts.append_array(BuildConceptContent.describe(view))
    if view.has("redraw"): parts.append("손패 교체"+(" · 추가 1장" if int(view.get("redraw_bonus",0)) > 0 else ""))
    if view.has("retain"): parts.append("비용이 높은 카드 %d장 보존" % int(view.get("retain_count",1)))
    if view.has("retrieve"):
        parts.append("버린 더미에서 살아 있는 대기 동료의 기술을 최신순으로 최대 %d장 회수" % int(view["retrieve_count"]) if view.get("retrieve_scope","") == "reserve" else "버린 더미에서 출전 멤버의 기술을 최신순으로 최대 %d장 회수" % int(view["retrieve_count"]) if view.get("retrieve_scope","") == "active" else "버린 기술 카드 최대 %d장 회수" % int(view.get("retrieve_count",1)))
    if view.has("finisher"): parts.append("이번 턴 출전 멤버의 다음 공격 기술 피해 2배 · 중첩 불가")
    if view.has("pulse_status"): parts.append("적의 화상·독·씨앗을 각각 1회 즉시 발동 · 남은 횟수 유지 · 보호막 무시")
    if view.has("double_block"): parts.append("출전 멤버의 현재 보호막 2배 · 추가 %d" % int(view["preview_block_gain"]) if view.has("preview_block_gain") else "출전 멤버의 현재 보호막 2배 · 0이면 0")
    if view.has("cash"): parts.append("화상·독·씨앗 소비 · 남은 횟수마다 상대 최대 HP의 8.3% 피해")
    if view.has("power"): parts.append({"relay":"지속: 기술로 교대 시 최대 HP의 6.3% 보호막","ace":"지속: 출전 유지 시 다음 턴 위력 보정 +20%","supply":"지속: 도구 사용 시 최대 HP의 10.4% 보호막","attrition":"지속: 아군이 건 화상·독·씨앗의 매회 피해 + 상대 최대 HP의 2.1%"}.get(view["power"],BuildConceptContent.POWER_TEXT.get(view["power"],"")))
    if view.has("cleanse"): parts.append("상태이상 해제")
    if view.get("exhaust",false): parts.append("소진")
    if view.get("player_rules")==2:parts.append_array(view.get("card_notes",[]))
    return " · ".join(parts) if not parts.is_empty() else str(view.get("description","효과 없음"))

static func starting_deck(members: Array[BattlePokemon]) -> Array[BattleCardInstance]:
    var result: Array[BattleCardInstance] = []
    for key: String in DECK: result.append(BattleCardInstance.new(result.size()+1,key,0))
    var slots := maxi(3,ceili(9.0/members.size()))
    for pokemon: BattlePokemon in members:
        var learned: Array = skills_for(pokemon).duplicate()
        var attacks: Array = learned.filter(func(key: String): return TacticalMoves.definition(key).has("damage"))
        if attacks.is_empty():
            learned.push_front("move_165")
            attacks.append("move_165")
        for i in maxi(slots,learned.size()):
            var key: String = learned[i] if i < learned.size() else (attacks[(i-learned.size())%attacks.size()] if not attacks.is_empty() else learned[i%learned.size()])
            result.append(BattleCardInstance.new(result.size()+1,key,pokemon.uid))
    return result

const CARD_THEMES := {
    "relay_formation":["relay"],
    "relay_accelerate":["relay"],
    "relay_command":["relay"],
    "relay_cycle_plan":["relay"],
    "ace_retrieve":["ace"],
    "ace_precision":["ace"],
    "ace_reserve":["ace"],
    "ace_breathing":["ace"],
    "status_catalyst":["status"],
    "status_ampoule":["status"],
    "status_analysis":["status"],
    "status_absorption":["status"],
    "shield_lock":["shield"],
    "shield_inspect":["shield"],
    "shield_regroup":["shield"],
    "shield_fortress":["shield"],
    "supply_recycle":["supply"],
    "supply_pack":["supply"],
    "supply_dynamo":["supply"],
    "supply_assembly":["supply"],
    "cycle_filter":["cycle"],
    "cycle_preserve":["cycle"],
    "cycle_opportunity":["cycle"],
    "cycle_engine":["cycle"],

    "relay_plan":["relay"],"relay_cover":["relay"],"relay_retrieve":["relay"],
    "ace_finisher":["ace"],"status_pulse":["status","supply"],"shield_double":["shield"],
    "ace_plan":["ace"],"ace_order":["ace"],"boost_card":["ace"],"hold":["ace","cycle"],"redraw":["cycle"],"retrieve":["cycle"],
    "status_cash":["status"],"status_plan":["status"],"toxic_flask":["status","supply"],
    "tool_plan":["supply","shield"],"shield_cell":["supply","shield"],
    "potion_card":["supply"],"smoke_card":["supply"],"ether_card":["supply"],"antidote_card":["supply"],
    "guard":["shield"],"counter":["shield"],"shield_strike":["shield"],
}
const RELIC_THEMES := {
    "relay_signal":["relay"],
    "manual_pin":["relay"],
    "ace_sight":["ace"],
    "ace_calm":["ace"],
    "status_ember":["status"],
    "status_vial":["status"],
    "shield_pad":["shield"],
    "shield_badge":["shield"],
    "tool_pouch":["supply"],
    "tool_discount":["supply"],
    "cycle_spring":["cycle"],
    "cycle_bookmark":["cycle"],

    "relay_core":["relay"],"ace_core":["ace"],"status_core":["status"],"shield_core":["shield"],"supply_core":["supply"],
    "seed_relay":["status"],"status_lens":["status"],"status_flask":["status"],
    "switch_power":["relay"],"relay_draw":["relay"],"relay_cell":["relay"],
    "ace_focus":["ace"],"ace_emblem":["ace"],"tool_belt":["supply"],
    "relay_cloak":["relay","shield"],"ace_medal":["ace"],"status_dish":["status"],"shield_battery":["shield"],
}
static func synergy_cards(deck: Array[BattleCardInstance], acquired: Array[String]) -> Array[String]:
    var themes: Array[String] = []
    for key: String in acquired:
        for theme: String in RELIC_THEMES.get(key,[]):
            if theme not in themes: themes.append(theme)
    for card: BattleCardInstance in deck:
        # Starter staples alone must not force every run toward shields/tools.
        var tags: Array = CARD_THEMES.get(card.key,[]) if card.key not in DECK else []
        if card.owner_uid != 0:
            var view := definition(card)
            if ["burn","poison","seed"].any(func(key: String): return view.has(key)): tags = ["status"]
        for theme: String in tags:
            if theme not in themes: themes.append(theme)
    var result: Array[String] = []
    for key: String in CARD_THEMES:
        if CARD_THEMES[key].any(func(theme: String): return theme in themes): result.append(key)
    return result
