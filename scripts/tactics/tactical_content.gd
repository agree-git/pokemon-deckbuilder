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
    if not pokemon.learned_skills.is_empty(): return pokemon.learned_skills
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
const DECK := ["analysis","analysis","guard","guard","guard","focus","focus","rally","rally","counter"]
const CARDS := {
    "analysis":{"name":"분석","cost":1,"move_id":116,"description":"현재 적에게 다음 공격 시 빈틈 +1을 예약합니다. 중첩하지 않습니다."},
    "guard":{"name":"방어 지시","cost":1,"move_id":115,"description":"출전 포켓몬이 보호막 6을 얻습니다."},
    "focus":{"name":"전술 정리","cost":0,"move_id":116,"description":"카드를 2장 뽑습니다. 사용 후 이번 전투에서 소진됩니다."},
    "rally":{"name":"강화 지시","cost":1,"move_id":74,"description":"다음 공격 기술의 기본 피해 +4. 교체해도 유지하며 중첩하지 않습니다."},
    "counter":{"name":"견제 지시","cost":1,"move_id":43,"description":"적이 강공격 준비 중이면 빈틈 +1. 그 외에는 보호막 4를 얻습니다."},
    "injury":{"name":"부상","cost":1,"move_id":150,"description":"효과가 없습니다. 포켓몬 기절 시 추가됩니다."},
}
const RELICS := {
    "seed_relay":{"name":"씨앗 전이","description":"씨뿌리기 대상이 쓰러지면 남은 씨앗을 다음 적에게 옮깁니다."},
    "switch_power":{"name":"교체 연계","description":"자발적 교체 직후 그 포켓몬의 다음 공격 기술 기본 피해 +3. 다음 턴에 해제."},
    "break_focus":{"name":"절정의 집중","description":"브레이크 시 1장 드로우. 다음 유료 트레이너 카드 비용 0. 부상 제외, 중첩 없음."},
}
