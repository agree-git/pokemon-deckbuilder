#!/usr/bin/env python3
"""Deterministic v26 type/category overlays; no new forms or held items."""
import argparse, hashlib, json
from pathlib import Path
BASES={'player_move_cards_v10.json':'cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255','player_move_support_v25.json':'fa42f8466048ddeeb0c22d320925232053cd7303c7053574eaf362251ee5ae6c'}
NOTES={237:'개체값 없이 현재 첫 타입 · 변신/타입 변경 반영',311:'날씨별 타입/위력 · 최종 타입으로 면역/부가효과 판정',363:'자신 나무열매별 타입/위력 · 실제 소모/리사이클 유지',449:'지원 타입 강화 물건 우선 · 없으면 현재 종/폼 기준',546:'지원 타입 강화 물건 우선 · 없으면 현재 드라이브 폼 기준',560:'격투/비행 이중 상성 · 최종 피해와 보호/대타 일치',573:'물 타입 상성을 항상 2배로 계산 · 다른 타입 상성은 곱함 · 기존 얼음 상태의 수면 각색 유지',686:'현재 첫 타입으로 공격 · 변신/전투 타입 변경 반영',718:'지원 타입 강화 물건 우선 · 없으면 현재 종/폼 기준',722:'물건/룸을 반영한 공격과 특공 중 높은 쪽으로 물리/특수 선택 · 동률 특수',801:'물건/룸 반영 공격×상대특방과 특공×상대방어 비교 · 물리일 때만 접촉 · 동률 특수',805:'접지한 자신은 현재 필드 타입 · 최종 타입으로 면역/부가효과 판정',873:'현재 변신 종/폼에 맞는 레이징불 타입 · 장막 제거 유지'}
def generate(game):
    for f,sha in BASES.items():assert hashlib.sha256((game/'data'/f).read_bytes()).hexdigest()==sha,f
    return {'schema_version':1,'route_version':26,'player_moves_version':18,'base_sha256':BASES,'source':{'repository':'smogon/pokemon-showdown','commit':'7b02eb39878f4b486f658a752b38c161379bd352','path':'data/moves.ts','sha256':'61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7'},'moves':{str(k):{'adaptive_note':v} for k,v in NOTES.items()}}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    (a.game_dir/'data/player_move_adaptive_v26.json').write_text(json.dumps(generate(a.game_dir),ensure_ascii=False,indent=2)+'\n');print(len(NOTES),'adaptive overlays')
