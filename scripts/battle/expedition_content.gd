class_name ExpeditionContent
extends RefCounted
## One authored nine-stop expedition, with choices visible before committing.
const ROUTE := [
    [{"name": "햇살숲 입구", "kind": "wild", "biome": 3, "enemy": {"id": 43, "name": "뚜벅쵸", "type": "grass", "max_hp": 64}}],
    [{"name": "해오름 물가", "kind": "wild", "biome": 2, "enemy": {"id": 7, "name": "꼬부기", "type": "water", "max_hp": 52}},
     {"name": "잿불 샛길", "kind": "wild", "biome": 1, "enemy": {"id": 4, "name": "파이리", "type": "fire", "max_hp": 45}}],
    [{"name": "숲속 야영지", "kind": "rest", "biome": 3}],
    [{"name": "길목의 트레이너", "kind": "trainer", "biome": 0, "enemy": {"id": 20, "name": "레트라", "type": "normal", "max_hp": 64, "wild": false, "intents": [
        {"kind": "attack", "value": 9, "move_id": 33}, {"kind": "block", "value": 6, "move_id": 115}, {"kind": "attack", "value": 12, "move_id": 33}]}}],
    [{"name": "깊은 숲의 야생", "kind": "wild", "biome": 3, "enemy": {"id": 43, "name": "뚜벅쵸", "type": "grass", "max_hp": 60}},
     {"name": "물가의 야생", "kind": "wild", "biome": 2, "enemy": {"id": 7, "name": "꼬부기", "type": "water", "max_hp": 52}}],
    [{"name": "진화의 샘", "kind": "rest", "biome": 3}],
    [{"name": "불꽃 수련자", "kind": "elite", "biome": 1, "enemy": {"id": 5, "name": "리자드", "type": "fire", "max_hp": 72, "wild": false, "intents": [
        {"kind": "attack", "value": 10, "move_id": 52, "type": "fire"}, {"kind": "boost", "value": 2, "move_id": 74}, {"kind": "attack", "value": 14, "move_id": 53, "type": "fire"}]}},
     {"name": "물의 수련자", "kind": "elite", "biome": 2, "enemy": {"id": 8, "name": "어니부기", "type": "water", "max_hp": 76, "wild": false, "intents": [
        {"kind": "block", "value": 10, "move_id": 110}, {"kind": "attack", "value": 12, "move_id": 55, "type": "water"}, {"kind": "attack", "value": 10, "move_id": 33}]}}],
    [{"name": "수호자 앞 야영지", "kind": "rest", "biome": 3}],
    [{"name": "숲의 수호자", "kind": "boss", "biome": 3, "enemy": {"id": 2, "name": "수호자 이상해풀", "type": "grass", "max_hp": 100, "wild": false, "intents": [
        {"kind": "attack", "value": 10, "move_id": 22, "type": "grass"}, {"kind": "block", "value": 12, "move_id": 115}, {"kind": "attack", "value": 16, "move_id": 75, "type": "grass"}, {"kind": "boost", "value": 3, "move_id": 74}]}}],
]
const EVOLUTIONS := {
    1: {"id": 2, "name": "이상해풀", "max_hp": 64, "from_card": "vine", "to_card": "razor_leaf", "trait": "전투 시작 보호막 4"},
    4: {"id": 5, "name": "리자드", "max_hp": 60, "from_card": "ember", "to_card": "fire_spin", "trait": "전투 동안 공격력 +1"},
    7: {"id": 8, "name": "어니부기", "max_hp": 68, "from_card": "water_gun", "to_card": "bubble_beam", "trait": "파티의 첫 턴 에너지 +1 (중복 없음)"},
}
static func kind_name(kind: String) -> String:
    return {"wild": "야생 · 포획 가능", "trainer": "트레이너 · 포획 불가", "elite": "수련자 · 포획 불가", "rest": "휴식 · 행동 1회", "boss": "최종 수호자 · 포획 불가"}.get(kind, kind)
