#!/usr/bin/env python3
"""Build the v13 field overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='1586ae99131c89cac7a0d3c4e95f89261b2865e89a1c5be6b4191b50b3b0fc33'
NOTES={
'court-change':('court','양쪽 진영 효과 교환'),
 'trick-room':('trick','5턴 동안 느린 쪽이 턴 시작 추가 에너지 획득 · 행동 순서는 유지 · 재사용 시 해제 · 현재 에너지 유지'),
 'wonder-room':('wonder','5턴 동안 피해 계산의 방어/특방 기본 능력치를 양쪽 모두 교환 · 능력 단계/영구 능력치 유지 · 재사용 시 해제'),
 'electric-terrain':('electric','일렉트릭필드5턴 · 접지한 사용자의 전기 공격1.3배 · 접지 대상의 새 수면 차단'),
 'grassy-terrain':('grassy','그래스필드5턴 · 접지한 사용자의 풀 공격1.3배 · 매 상대 행동 뒤 양쪽 접지 출전자 HP1/16 회복 · 지진/땅고르기/매그니튜드 피해 절반'),
 'misty-terrain':('misty','미스트필드5턴 · 접지 대상의 새 주 상태이상/혼란 차단 · 받는 드래곤 공격 절반'),
 'psychic-terrain':('psychic','사이코필드5턴 · 접지한 사용자의 에스퍼 공격1.3배 · 접지 대상에게 선공 공격 차단'),
 'terrain-pulse':('pulse','접지한 사용자는 필드 타입으로 바뀌고 위력2배 · 필드가 없으면 노말 공격'),
 'expanding-force':('expanding','접지한 사용자 + 사이코필드면 위력1.5배 · 한 상대 전투 유지'),
 'rising-voltage':('voltage','접지한 상대 + 일렉트릭필드면 위력2배'),
 'grassy-glide':('glide','접지한 사용자 + 그래스필드면 비용-1 · 원작 선공을 저비용 카드로 각색'),
 'steel-roller':('roller','필드가 있을 때만 사용 가능 · 명중하면 필드 제거'),
 'misty-explosion':('explosion','공격 후 사용자 기절 · 접지한 사용자 + 미스트필드면 위력1.5배'),
 'ice-spinner':('spinner','명중하면 필드 제거'),
 'defog':('defog','기존 설치/장막 해제에 양쪽 신규 장막·진영 설치·필드 제거 추가 · 보호에 막히면 유지'),
 'tailwind':('tailwind','아군 진영4턴 · 다음 턴 시작 에너지 비교의 스피드2배 · 현재 에너지/행동 순서 유지'),
 'aurora-veil':('veil','눈일 때만 설치 · 아군 진영5턴 물리/특수 공격 피해 절반 · 기존 해당 장막과 중복 감소 없음 · 눈이 끝나도 유지'),
 'mist':('mist','아군 진영5턴 · 상대 기술에 의한 새 음수 능력 단계 변화 차단 · 자기 능력 감소/단계 교환은 유지'),
 'mud-sport':('mud','5턴 동안 양쪽 전기 공격 피해1/3 · 접지와 무관'),
 'water-sport':('water','5턴 동안 양쪽 불꽃 공격 피해1/3 · 접지와 무관')}
NOTES['court-change']=('court','양쪽 설치4종과 빛의장막/리플렉터/신비의부적/순풍/오로라베일/흰안개의 남은 기간 교환 · 현재 출전자 입장 효과는 재적용하지 않음')
def generate(game,csv_dir):
 path=game/'data/player_move_exchange_v12.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 v12=json.loads(path.read_text());v11=json.loads((game/'data/player_move_tactics_v11.json').read_text());v10=json.loads((game/'data/player_move_cards_v10.json').read_text())
 assert hashlib.sha256((game/'data/player_move_tactics_v11.json').read_bytes()).hexdigest()==v12['base_sha256']
 assert hashlib.sha256((game/'data/player_move_cards_v10.json').read_bytes()).hexdigest()==v11['base_sha256']
 for name,h in v12['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 rows=list(csv.DictReader((csv_dir/'moves.csv').open()));ids={r['identifier']:r['id'] for r in rows};out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(v12['moves'].get(key,v11['moves'].get(key,v10['moves'][key]))));v['field_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  if name=='misty-explosion':v['self_ko']=True
  out[key]=v
 return {'schema_version':1,'route_version':13,'player_moves_version':5,'base_sha256':BASE,'source':v12['source'],'moves':out,'positive_priority':[int(r['id']) for r in rows if int(r['priority'])>0 and r['damage_class_id']!='1'],'total_enhanced':len(set(out)|set(v12['moves'])|set(v11['moves'])|set(v10['enhanced']))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_fields_v13.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
