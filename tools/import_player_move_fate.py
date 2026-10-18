#!/usr/bin/env python3
"""Build the v19 fate overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='2f84e8a18ee1b46d3e9ded28bacf53a34d577911dca79c2ed20bf24923c30b9c'
NOTES={
 'nightmare':('nightmare','잠든 상대에게 수면 동안 매 턴 최대HP¼ 지속 피해 · 보호막/대타 피해 흡수 무시 · 깨어나거나 대상 교대 시 해제'),
 'perish-song':('perish','현재 양쪽 포켓몬은 3상대 행동 뒤 기절 · 각자 교대하면 자기 카운트만 해제 · 보호/대타/공중/타입 무효 무시 · 재사용으로 기간 연장 없음'),
 'healing-wish':('wish','자신 기절 · 다음 입장 피해를 견딘 동료의 HP/상태 회복 · 기존 회복 감소/봉인 적용 · 기절 동료 부활 없음'),
 'lunar-dance':('lunar','자신 기절 · 다음 입장 피해를 견딘 동료의 HP/상태 회복 · 기존 회복 감소/봉인 적용 · PP 시스템이 없어 PP 회복은 생략')}

def generate(game,csv_dir):
 path=game/'data/player_move_assist_v18.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json','player_move_items_v17.json','player_move_assist_v18.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json','player_move_items_v17.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['fate_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  if tag in ['wish','lunar']:v['exhaust']=True
  out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':19,'player_moves_version':11,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_fate_v19.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
