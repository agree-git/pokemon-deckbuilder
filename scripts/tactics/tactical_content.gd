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
    "guard":{"name":"방어 지시","category":"trainer","cost":1,"move_id":115,"block":8,"description":"출전 포켓몬이 보호막 8 + 성장 보정을 얻습니다."},
    "focus":{"name":"전술 정리","category":"trainer","cost":0,"move_id":116,"draw":2,"exhaust":true,"description":"카드 2장 뽑기. 소진."},
    "rally":{"name":"강화 지시","category":"trainer","cost":1,"move_id":74,"bonus":7,"description":"다음 공격의 기본 피해 +7 + 성장 보정. 교대해도 유지."},
    "counter":{"name":"견제 지시","category":"trainer","cost":1,"move_id":43,"weaken":3,"block":4,"description":"적 공격 -3 · 보호막 4 + 성장 보정."},
    "redraw":{"name":"작전 변경","category":"trainer","cost":0,"move_id":116,"redraw":true,"exhaust":true,"description":"남은 손패를 모두 버리고 그 수만큼 뽑기. 소진."},
    "hold":{"name":"대기 지시","category":"trainer","cost":0,"move_id":116,"retain":true,"description":"손패에서 비용이 가장 높은 카드 1장을 다음 턴까지 보존."},
    "retrieve":{"name":"재정비","category":"trainer","cost":1,"move_id":116,"retrieve":true,"description":"버린 더미의 가장 최근 기술 카드 1장을 손으로 회수."},
    "relay_plan":{"name":"릴레이 작전","category":"trainer","cost":1,"move_id":97,"power":"relay","description":"지속: 기술로 교대할 때 출전 포켓몬이 보호막 3 획득. 전투 동안 유지."},
    "ace_plan":{"name":"에이스 육성","category":"trainer","cost":1,"move_id":74,"power":"ace","description":"지속: 출전 포켓몬을 유지해 턴을 마치면 다음 턴 공격 +2."},
    "tool_plan":{"name":"보급 작전","category":"trainer","cost":1,"move_id":115,"power":"supply","description":"지속: 도구 카드를 쓸 때 출전 포켓몬이 보호막 5 획득."},
    "status_cash":{"name":"상태 회수","category":"trainer","cost":1,"move_id":92,"cash":true,"description":"적의 화상·독·씨앗을 모두 제거하고 남은 횟수당 4 피해. 상성 무시."},
    "potion_card":{"name":"응급 회복약","category":"tool","cost":1,"move_id":105,"heal":16,"exhaust":true,"description":"출전 포켓몬의 HP 16 회복. 소진."},
    "boost_card":{"name":"배틀 강화제","category":"tool","cost":0,"move_id":74,"temporary_strength":4,"exhaust":true,"description":"출전 포켓몬의 공격 +4. 교대하면 해제. 소진."},
    "smoke_card":{"name":"연막탄","category":"tool","cost":1,"move_id":108,"weaken":4,"draw":1,"exhaust":true,"description":"적 공격 -4 · 카드 1장 뽑기. 소진."},
    "ether_card":{"name":"에너지 팩","category":"tool","cost":0,"move_id":116,"energy":2,"exhaust":true,"description":"에너지 +2. 소진."},
    "antidote_card":{"name":"만능 치료제","category":"tool","cost":0,"move_id":105,"cleanse":true,"heal":5,"exhaust":true,"description":"출전 포켓몬 상태이상 제거 · HP 5 회복. 소진."},
    "injury":{"name":"부상","category":"status","cost":1,"move_id":150,"description":"효과 없음. 기절 시 추가되며 야영지 휴식으로 제거."},
}
const RELICS := {
    "field_kit":{"name":"탐험 구급함","icon":"heal","description":"전투 시작 시 모든 아군이 보호막 5를 얻습니다."},
    "seed_relay":{"name":"씨앗 전이","icon":"seed","description":"씨뿌리기 대상이 쓰러지면 남은 씨앗을 다음 적에게 옮깁니다."},
    "switch_power":{"name":"교대 배턴","icon":"switch","description":"기술로 교대한 포켓몬의 다음 공격 기본 피해 +3. 턴 종료 시 해제."},
    "relay_draw":{"name":"릴레이 수첩","icon":"draw","description":"한 턴에 서로 다른 아군 3마리가 기술을 사용하면 카드 2장 뽑기. 턴당 한 번."},
    "ace_focus":{"name":"에이스의 깃발","icon":"boost","description":"포켓몬을 유지해 턴을 마치면 다음 턴 해당 포켓몬 공격 +1."},
    "tool_belt":{"name":"보급 벨트","icon":"draw","description":"매 턴 처음 사용하는 도구 카드가 카드 1장을 뽑습니다."},
    "status_lens":{"name":"상태 관측경","icon":"counter","description":"매 턴 처음 새로운 상태이상을 걸면 에너지 +1."},
}
const HELD_ITEMS := {
    "power_band":{"name":"힘의 머리띠","icon":"attack","description":"장착한 포켓몬의 공격 기본 피해 +3."},
    "guard_charm":{"name":"수호 부적","icon":"shield","description":"장착한 포켓몬이 카드의 기본 효과로 얻는 보호막 +4."},
    "relay_ribbon":{"name":"교대 리본","icon":"switch","description":"매 턴 처음 교대해 출전할 때 보호막 5 획득."},
    "ace_band":{"name":"집중 밴드","icon":"boost","description":"장착한 포켓몬을 유지해 턴을 마치면 다음 턴 공격 +1."},
    "seed_charm":{"name":"생명의 부적","icon":"seed","description":"적에게 화상·독·씨앗이 있으면 턴 종료 시 장착자 HP 2 회복."},
    "healing_bell":{"name":"치유의 방울","icon":"heal","description":"장착한 포켓몬이 도구 카드로 받는 회복 +6."},
}

static func definition(card: BattleCardInstance) -> Dictionary:
    var result: Dictionary = (TacticalMoves.definition(card.key) if card.owner_uid != 0 else CARDS.get(card.key,{})).duplicate(true)
    if result.is_empty(): return result
    result["category"] = "technique" if card.owner_uid != 0 else result.get("category","trainer")
    result["uid"] = card.uid
    result["key"] = card.key
    result["owner_uid"] = card.owner_uid
    if card.owner_uid != 0 and result.has("heal") and not result.has("damage"): result["exhaust"] = true
    if card.upgraded:
        result["name"] += " +"
        var increased := false
        if result.has("retain"):
            result["retain_count"] = 2
            result["description"] = "손패에서 비용이 가장 높은 카드 2장을 다음 턴까지 보존."
            increased = true
        if result.has("redraw"):
            result["redraw_bonus"] = 1
            result["description"] = "남은 손패를 버리고 그 수 +1장 뽑기."
            increased = true
        for field: String in ["damage","block","heal","bonus"]:
            if result.has(field):
                result[field] = int(result[field])+4
                increased = true
        for field: String in ["draw","energy","strength","weaken","temporary_strength"]:
            if result.has(field):
                result[field] = int(result[field])+1
                increased = true
        if not increased: result["cost"] = maxi(0,int(result["cost"])-1)
    result["description"] = description(result)
    return result

static func can_upgrade(card: BattleCardInstance) -> bool:
    if card.upgraded or card.key == "injury": return false
    var original := definition(card)
    var upgraded := BattleCardInstance.new(card.uid,card.key,card.owner_uid)
    upgraded.upgraded = true
    var improved := definition(upgraded)
    original.erase("name")
    improved.erase("name")
    return original != improved

static func description(view: Dictionary) -> String:
    var parts: Array[String] = []
    for field: String in ["damage","block","heal","strength","weaken","draw","energy","bonus","temporary_strength"]:
        if view.has(field):
            parts.append({"damage":"피해 %d","block":"보호막 %d","heal":"회복 %d","strength":"공격 +%d","weaken":"적 공격 -%d","draw":"%d장 뽑기","energy":"에너지 +%d","bonus":"다음 공격 +%d","temporary_strength":"교대 전까지 공격 +%d"}[field] % int(view[field]))
    for status: String in ["burn","seed","poison","sleep","paralysis","confusion","expose"]:
        if view.has(status): parts.append({"burn":"화상","seed":"씨뿌리기","poison":"독","sleep":"수면","paralysis":"마비","confusion":"혼란","expose":"방어 약화"}[status]+" %d회" % int(view[status]))
    for marker: String in ["redraw","retain","retrieve","cash","power","cleanse"]:
        if view.has(marker): parts.append(str(view.get("description","")))
    if view.get("exhaust",false): parts.append("소진")
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
