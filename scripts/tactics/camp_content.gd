class_name CampContent
extends RefCounted
## Independently seeded arrivals; immutable until copied into a run's camp state.
static func generate(run_seed: int, step: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = run_seed ^ (step*104729+2971215073)
    var roll := rng.randi_range(1,100)
    if roll <= 35:
        var medicine: Array[String] = ["potion","super_potion","revive"]
        var excluded := rng.randi_range(0,2)
        medicine.remove_at(excluded)
        medicine.append("ball")
        return {"kind":"merchant","title":"떠돌이 상인","icon":"bag","description":"길을 떠돌던 상인이 잠시 머물렀습니다. 이번 물품을 둘러보세요.","offers":medicine}
    if roll <= 70:
        var events := [
            {"kind":"event","id":"spring","title":"치유의 샘","icon":"heal","description":"맑은 샘을 발견했습니다. 동료들을 쉬게 할까요, 물을 담아 갈까요?","choices":["전원 HP 25% 회복","좋은상처약 1개 얻기"]},
            {"kind":"event","id":"lesson","title":"길가의 전술가","icon":"analysis","description":"여행 중인 전술가가 수업을 제안합니다. 50골드로 트레이너 카드 1장을 배웁니다.","choices":["50골드 · 분석 배우기","50골드 · 견제 지시 배우기"]},
            {"kind":"event","id":"satchel","title":"길가의 낡은 가방","icon":"bag","description":"누군가 두고 간 낡은 가방입니다. 보급품을 챙기거나 쓸 만한 부품을 팔 수 있습니다.","choices":["몬스터볼 2개 얻기","부품 판매 · 60골드 얻기"]},
        ]
        return events[rng.randi_range(0,events.size()-1)].duplicate(true)
    if roll <= 90:
        var items: Array[String] = ["potion","super_potion","revive","ball"]
        var item := items[rng.randi_range(0,items.size()-1)]
        return {"kind":"discovery","title":"숨겨진 보급품","icon":"bag","description":"풀숲 사이에 아직 쓸 수 있는 보급품이 남아 있습니다.","item":item,"quantity":2 if item == "ball" else 1}
    return {"kind":"quiet","title":"고요한 야영지","icon":"heal","description":"오늘은 조용한 밤입니다. 동료들과 쉬며 다음 전투를 준비하세요."}
