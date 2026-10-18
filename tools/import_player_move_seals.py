#!/usr/bin/env python3
"""Build the v14 seal overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='4a970fc9f58ab132138d42ab53b2d779fb2fbcc9d3a414cb520be5d4ec9716d1'
NOTES={
 'magic-room':('magic','5턴 동안 양쪽 소지품의 지속 효과만 정지 · 소지품 소유/제거 판정은 유지 · 재사용 시 해제 · 이미 얻은 보호막/강화는 유지'),
 'lucky-chant':('chant','아군 진영5턴 급소 방어 · 확정 급소/높은 급소 보너스와 급소의 단계 무시를 차단 · 교대해도 유지'),
 'fairy-lock':('fairy','현재 턴과 다음 턴의 자발적 교대 금지 · 소유 기술 카드 자동 교대도 금지 · 고스트/기절 후 필수 교대/상대의 강제 교대는 허용 · 재사용은 기간 갱신')}
def generate(game,csv_dir):
 path=game/'data/player_move_fields_v13.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['seal_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note];v['upgrade']={'cost':max(0,v['cost']-1)};out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':14,'player_moves_version':6,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_seals_v14.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
