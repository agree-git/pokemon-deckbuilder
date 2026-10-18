#!/usr/bin/env python3
"""Build the v16 trap overlay without changing any published move inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='596e9b74d5cb953481ffbec6abf8f1a7f10870681abc42bcfd4d7980354851aa'
NOTES={
 'mean-look':('lock','상대 자발 교대 봉쇄 · 시전자/대상 이탈·기절 시 해제 · 고스트 교대 허용 · 방어 우회/대타에는 차단'),
 'spider-web':('lock','상대 자발 교대 봉쇄 · 시전자/대상 이탈·기절 시 해제 · 고스트 교대 허용 · 방어/대타에 차단'),
 'block':('lock','상대 자발 교대 봉쇄 · 시전자/대상 이탈·기절 시 해제 · 고스트 교대 허용 · 방어 우회/대타에는 차단'),
 'octolock':('octo','상대 자발 교대 봉쇄 · 매 상대 행동 뒤 방어/특방-1 · 시전자 이탈·기절 시 종료 · 고스트는 교대 가능하며 능력 감소는 적용 · 흰안개는 감소 차단'),
 'jaw-lock':('jaw','명중 후 양쪽 자발 교대 봉쇄 · 어느 쪽이든 이탈·기절 시 해제 · 고스트는 개별 교대 가능 · 이미 구속된 쪽이 있으면 새 연결 없이 공격만 적용'),
 'no-retreat':('stand','모든 전투 능력 단계+1 · 교대 전까지 개체당1회 · 자신 자발 교대 봉쇄 · 고스트 교대 허용 · 기절 필수/강제 교대 허용'),
 'thousand-waves':('lock','명중 후 상대 자발 교대 봉쇄 · 시전자/대상 이탈·기절 시 해제 · 고스트 교대 허용 · 착지 효과 없음(사우전드애로와 별개)')}
def generate(game,csv_dir):
 path=game/'data/player_move_altitude_v15.json';assert hashlib.sha256(path.read_bytes()).hexdigest()==BASE
 layers=[json.loads((game/('data/'+name)).read_text()) for name in ['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json','player_move_altitude_v15.json']]
 for older,newer,name in zip(layers,layers[1:],['player_move_cards_v10.json','player_move_tactics_v11.json','player_move_exchange_v12.json','player_move_fields_v13.json','player_move_seals_v14.json']):
  assert hashlib.sha256((game/'data'/name).read_bytes()).hexdigest()==newer['base_sha256']
 for name,h in layers[-1]['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()==h,name
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};merged={}
 for layer in layers:merged.update(layer['moves'])
 out={}
 for name,(tag,note) in NOTES.items():
  key=ids[name];v=json.loads(json.dumps(merged[key]));v['trap_rule']=tag;v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[note]
  if v['damage_class']=='status':v['upgrade']={'cost':max(0,v['cost']-1)}
  out[key]=v
 enhanced=set(layers[0]['enhanced'])
 for layer in layers[1:]:enhanced.update(layer['moves'])
 return {'schema_version':1,'route_version':16,'player_moves_version':8,'base_sha256':BASE,'source':layers[-1]['source'],'moves':out,'total_enhanced':len(enhanced|set(out))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_traps_v16.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
