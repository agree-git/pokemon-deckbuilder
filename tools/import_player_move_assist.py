#!/usr/bin/env python3
"""Build the v18 assist overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='5165abda6c87b7274ea1f7dcd57c23c03b9dd9b40b33a13163adeacf51f02251'
NOTES={
 'foresight':('ghost','상대가 교대할 때까지 고스트의 노말/격투 무효만 해제 · 실제 타입 유지 · 회피 단계/명중 추첨 없음'),
 'odor-sleuth':('ghost','상대가 교대할 때까지 고스트의 노말/격투 무효만 해제 · 실제 타입 유지 · 회피 단계/명중 추첨 없음'),
 'miracle-eye':('dark','상대가 교대할 때까지 악의 에스퍼 무효만 해제 · 실제 타입 유지 · 회피 단계/명중 추첨 없음'),
 'lock-on':('aim','현재 상대에 대한 자신의 다음 공격은 공중 회피에 막히지 않음 · 보호/대타/타입 무효는 유지 · 2상대 행동 또는 교대 시 만료'),
 'mind-reader':('aim','현재 상대에 대한 자신의 다음 공격은 공중 회피에 막히지 않음 · 보호/대타/타입 무효는 유지 · 2상대 행동 또는 교대 시 만료'),
 'helping-hand':('help','이번 턴 다른 동료의 다음 공격 피해1.5배 · 자신의 공격에는 적용하지 않음 · 중복 배율 누적 없음'),
 'after-you':('after','고정 행동 순서 대신 이번 턴 다른 동료의 다음 비용 있는 기술 카드 비용-1 · 최소0 · 행동 순서/현재 에너지 변경 없음'),
 'quash':('quash','고정 행동 순서 대신 상대 예고 한 칸 밀기 · 같은 상대에 턴당1회 · 승인 파티 순서 유지')}
def generate(game,csv_dir):
 path=game/'data/player_move_items_v17.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json','player_move_items_v17.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json','player_move_traps_v16.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['assist_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  if name=='quash':v['extension']='push'
  out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':18,'player_moves_version':10,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_assist_v18.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
