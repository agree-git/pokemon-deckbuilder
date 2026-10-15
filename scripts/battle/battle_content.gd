class_name BattleContent
extends RefCounted
## Authored deck-building values, separate from PokéAPI's original game stats.

const PARTY := [
    {"id": 4, "uid": 4, "name": "파이리", "type": "fire", "max_hp": 45},
    {"id": 1, "uid": 1, "name": "이상해씨", "type": "grass", "max_hp": 48},
]
const ENEMY := {"id": 43, "name": "뚜벅쵸", "type": "grass", "max_hp": 64}
const ENCOUNTERS := [
    ENEMY,
    {"id": 7, "name": "꼬부기", "type": "water", "max_hp": 52},
    {"id": 4, "name": "파이리", "type": "fire", "max_hp": 45},
]
const CAPTURE_CARDS := {43: ["absorb", "seed"], 7: ["water_gun", "shell"], 4: ["ember", "fire_guard"]}
const INTENTS := [
    {"kind": "attack", "value": 8, "type": "normal", "move_id": 33},
    {"kind": "block", "value": 7, "move_id": 115},
    {"kind": "attack", "value": 12, "type": "normal", "move_id": 33},
    {"kind": "boost", "value": 2, "move_id": 74},
]
const DECK := [
    {"key": "tackle", "owner": 0, "copies": 3},
    {"key": "guard", "owner": 0, "copies": 2},
    {"key": "focus", "owner": 0, "copies": 1},
    {"key": "ember", "owner": 4, "copies": 2},
    {"key": "flame", "owner": 4, "copies": 1},
    {"key": "fire_guard", "owner": 4, "copies": 1},
    {"key": "vine", "owner": 1, "copies": 2},
    {"key": "seed", "owner": 1, "copies": 1},
    {"key": "growth", "owner": 1, "copies": 1},
]
const CARDS := {
    "tackle": {"name": "몸통박치기", "cost": 1, "type": "normal", "kind": "공격", "move_id": 33, "damage": 6, "description": "6 피해를 줍니다."},
    "guard": {"name": "방어", "cost": 1, "type": "normal", "kind": "스킬", "move_id": 115, "block": 5, "description": "출전 포켓몬이\n보호막 5를 얻습니다."},
    "focus": {"name": "집중", "cost": 0, "type": "normal", "kind": "스킬", "move_id": 116, "draw": 2, "description": "카드를 2장 뽑습니다."},
    "ember": {"name": "불꽃세례", "cost": 1, "type": "fire", "kind": "공격", "move_id": 52, "damage": 4, "burn": 3, "description": "4 피해 · 화상 3회\n행동 종료 시 2 피해."},
    "flame": {"name": "화염방사", "cost": 2, "type": "fire", "kind": "공격", "move_id": 53, "damage": 12, "description": "12 피해를 줍니다."},
    "fire_guard": {"name": "웅크리기", "cost": 1, "type": "normal", "kind": "스킬", "move_id": 111, "block": 8, "description": "사용 포켓몬이\n보호막 8을 얻습니다."},
    "vine": {"name": "덩굴채찍", "cost": 1, "type": "grass", "kind": "공격", "move_id": 22, "damage": 8, "description": "8 피해를 줍니다."},
    "seed": {"name": "씨뿌리기", "cost": 1, "type": "grass", "kind": "스킬", "move_id": 73, "seed": 3, "description": "3회: 적에게 2 피해\n사용 포켓몬 2 회복."},
    "growth": {"name": "성장", "cost": 0, "type": "grass", "kind": "스킬", "move_id": 74, "strength": 2, "description": "사용 포켓몬의 공격력이\n이번 전투 동안 2 증가."},
    "absorb": {"name": "흡수", "cost": 1, "type": "grass", "kind": "공격", "move_id": 71, "damage": 6, "heal": 2, "description": "6 피해를 주고\n자신의 체력을 2 회복."},
    "water_gun": {"name": "물대포", "cost": 1, "type": "water", "kind": "공격", "move_id": 55, "damage": 8, "description": "8 피해를 줍니다."},
    "shell": {"name": "껍질에숨기", "cost": 1, "type": "water", "kind": "스킬", "move_id": 110, "block": 8, "description": "사용 포켓몬이\n보호막 8을 얻습니다."},
    "injury": {"name": "부상", "cost": 1, "type": "normal", "kind": "상태", "move_id": 150, "description": "효과가 없습니다.\n기절 시 덱에 추가."},
}

static func multiplier(attack_type: String, defense_type: String) -> float:
    var strong := {"fire": "grass", "grass": "water", "water": "fire"}
    if strong.get(attack_type, "") == defense_type:
        return 1.5
    if attack_type != "normal" and (attack_type == defense_type or strong.get(defense_type, "") == attack_type):
        return 0.75
    return 1.0
