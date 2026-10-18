#!/usr/bin/env python3
"""Build the v20 reactions overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='5aa55a74d9382b115f43f616e7f2e40e4cbba151084b1d62a529a6abe6a5970c'
NOTES={
 'ion-deluge':('plasma','이번 상대 행동 종료까지 양쪽 노말 기술이 전기로 변함 · 실제 포켓몬 타입 유지 · 발버둥 제외'),
 'electrify':('electric','이번 상대의 다음 기술만 전기로 변함 · 상대 행동/대상 교대/기절 시 해제 · 타입 상성/필드/날씨에 변환 반영'),
 'powder':('powder','이번 상대가 불꽃 기술을 쓰려 하면 취소하고 상대 최대HP¼ 피해 · 송전으로 전기가 되면 폭발 없음 · 풀 타입 무효 · 다음 상대 행동까지')}

def generate(game,csv_dir):
 path=game/'data/player_move_fate_v19.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json','player_move_items_v17.json','player_move_assist_v18.json','player_move_fate_v19.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json','player_move_items_v17.json','player_move_assist_v18.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['reaction_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':20,'player_moves_version':12,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_reactions_v20.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
