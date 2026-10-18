#!/usr/bin/env python3
"""Build the v17 item overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='1784987e13a8d2a405a48e1983f4a9637a8b36c7b7be8795f2343115a1347103'
NOTES={
 'thousand-arrows':('arrows','부유/공중 회피를 뚫고 명중 후 착지 · 아직 접지하지 않은 비행 타입 첫 타격은 땅 상성1배 · 이후 일반 땅 상성 · 대타/보호는 착지 차단'),
 'trick':('swap','양쪽 소지품 교환 · 무소지와 교환 가능 · 전투 종료 시 원래 장비 복구'),
 'switcheroo':('swap','양쪽 소지품 교환 · 무소지와 교환 가능 · 전투 종료 시 원래 장비 복구'),
 'bestow':('give','상대가 무소지일 때 자신의 소지품 전달 · 전투 종료 시 원래 장비 복구'),
 'recycle':('recycle','자신이 이번 전투에서 내던지기로 소비한 마지막 소지품 복구 · 현재 무소지 필요 · 탁쳐서떨구기/부식가스의 제거물은 복구 불가'),
 'embargo':('embargo','상대5턴 소지품 효과/도구 카드/내던지기 금지 · 소유권은 유지 · 교대 시 해제'),
 'corrosive-gas':('gas','보호/대타에 막히지 않은 상대 소지품 제거 · 전투 종료 시 원래 장비 복구 · 리사이클 복구 불가'),
 'fling':('fling','현재 커스텀 소지품6종을 위력40(강화55)으로 던져 소비 · 보호/타입 무효에도 소비 · 금제/매직룸 또는 무소지 중 사용 불가 · 추가 상태 효과 없음')}
def generate(game,csv_dir):
 path=game/'data/player_move_traps_v16.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['item_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':17,'player_moves_version':9,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_items_v17.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
