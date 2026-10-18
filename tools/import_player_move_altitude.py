#!/usr/bin/env python3
"""Build the v15 altitude overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='b9e3a818e2f359c9aa2582ca988c36f2b1c2251419dd18c65867e6451c408543'
NOTES={
 'gravity':('gravity','5턴 동안 양쪽 강제 접지 · 비행의 땅 무효 해제 · 전자부유/텔레키네시스와 공중 충전 취소 · 공중/점프 기술 금지 · 명중 추첨 없음'),
 'magnet-rise':('rise','사용자5턴 부유 · 땅 공격 무효 · 접지 필드의 강화/회복/상태 방어 대상에서 제외 · 교대/중력/뿌리박기/떨어뜨리기에 해제'),
 'telekinesis':('lift','상대3턴 부유 · 땅 공격 무효 · 접지 필드 대상에서 제외 · 보호/대타/공중 회피에 막힘 · 명중률/체중/종별 예외는 각색상 생략 · 교대/중력/뿌리박기/떨어뜨리기에 해제')}
def generate(game,csv_dir):
 path=game/'data/player_move_seals_v14.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['air_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note];v['upgrade']={'cost':max(0,v['cost']-1)};out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':15,'player_moves_version':7,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_altitude_v15.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
