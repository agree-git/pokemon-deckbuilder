#!/usr/bin/env python3
"""Build the v21 official held-item catalog from pinned PokéAPI CSV and sprites."""
import argparse,csv,hashlib,json
from pathlib import Path
COMMIT='6fd69dfe90465ba96534f6816fc817737d1f97f6'
SPRITES='7a7d66b1620e646f69afd48dc1273da9033ede9c'
HASHES={'items.csv':'f08cd6dc30b447cb91cbe9232c79052e8521f32f6105bb1489b5bfabf4ca3241','item_names.csv':'c4ad0b446e395c378d8ba75d6900f051cc9ebb99431d4000adeac35f492852f0','item_prose.csv':'510fc4a9e58951dcaacf156d4cc6655dce1b173dcaea45495a29f6f343076373'}
RULES={
 'choice-band':{'rule':'choice','stats':{'attack':1.5},'note':'공격1.5배 · 교대 전까지 처음 쓴 기술만 사용'},
 'choice-specs':{'rule':'choice','stats':{'special_attack':1.5},'note':'특공1.5배 · 교대 전까지 처음 쓴 기술만 사용'},
 'choice-scarf':{'rule':'choice','stats':{'speed':1.5},'note':'스피드1.5배 · 교대 전까지 처음 쓴 기술만 사용'},
 'muscle-band':{'rule':'physical','factor':1.1,'note':'물리 기술 피해1.1배'},
 'wise-glasses':{'rule':'special','factor':1.1,'note':'특수 기술 피해1.1배'},
 'expert-belt':{'rule':'expert','factor':1.2,'note':'효과가 굉장한 공격 피해1.2배'},
 'life-orb':{'rule':'life','factor':1.3,'note':'공격 기술 피해1.3배 · 명중한 공격 뒤 최대HP의1/10 반동'},
 'assault-vest':{'rule':'vest','stats':{'special_defense':1.5},'note':'특방1.5배 · 자신의 변화 기술 카드 사용 불가'},
 'eviolite':{'rule':'eviolite','stats':{'defense':1.5,'special_defense':1.5},'note':'진화할 수 있는 포켓몬의 방어/특방1.5배'},
 'leftovers':{'rule':'leftovers','note':'출전 중 턴 종료마다 최대HP의1/16 회복'},
 'black-sludge':{'rule':'sludge','note':'출전 중 턴 종료에 독 타입은 최대HP의1/16 회복 · 나머지는1/8 피해'},
 'shell-bell':{'rule':'shell','note':'공격으로 상대에게 준 실제 HP 피해의1/8 회복'},
 'rocky-helmet':{'rule':'helmet','note':'접촉 기술로 HP 피해를 받으면 공격자에게 최대HP의1/6 피해'},
 'focus-sash':{'rule':'sash','consumable':True,'note':'HP가 가득 찼을 때 공격으로 기절할 피해를 받으면 HP1로 생존 후 소모 · 연타 후속타는 유지'},
 'weakness-policy':{'rule':'weakness','consumable':True,'note':'효과가 굉장한 기술로 HP 피해를 받고 살아남으면 공격/특공+2 후 소모'},
 'white-herb':{'rule':'white','consumable':True,'note':'능력 단계가 내려가면 음수 단계만0으로 복구 후 소모'},
 'clear-amulet':{'rule':'clear','note':'상대 기술에 의한 음수 능력 단계 변화 방지'},
 'flame-orb':{'rule':'orb','status':'burn','note':'출전 중 턴 종료에 자신에게 화상 · 기존 지속 횟수 규칙 사용'},
 'toxic-orb':{'rule':'orb','status':'poison','note':'출전 중 턴 종료에 자신에게 독 · 맹독 단계 대신 기존 독 지속 피해 사용'},
 'light-ball':{'rule':'species','species':[25],'stats':{'attack':2.0,'special_attack':2.0},'note':'피카츄의 공격/특공2배'},
 'thick-club':{'rule':'species','species':[104,105],'stats':{'attack':2.0},'note':'탕구리/텅구리의 공격2배 · 지역폼 포함'},
 'deep-sea-tooth':{'rule':'species','species':[366],'stats':{'special_attack':2.0},'note':'진주몽의 특공2배'},
 'deep-sea-scale':{'rule':'species','species':[366],'stats':{'special_defense':2.0},'note':'진주몽의 특방2배'},
 'soul-dew':{'rule':'type','species':[380,381],'types':['psychic','dragon'],'factor':1.2,'note':'라티아스/라티오스의 에스퍼/드래곤 기술 피해1.2배'},
}
TYPES={'silk-scarf':'normal','charcoal':'fire','mystic-water':'water','magnet':'electric','miracle-seed':'grass','never-melt-ice':'ice','black-belt':'fighting','poison-barb':'poison','soft-sand':'ground','sharp-beak':'flying','twisted-spoon':'psychic','silver-powder':'bug','hard-stone':'rock','spell-tag':'ghost','dragon-fang':'dragon','black-glasses':'dark','metal-coat':'steel','pixie-plate':'fairy'}
TYPE_KO=dict(zip(['normal','fire','water','electric','grass','ice','fighting','poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy'],['노말','불꽃','물','전기','풀','얼음','격투','독','땅','비행','에스퍼','벌레','바위','고스트','드래곤','악','강철','페어리']))
for key,t in TYPES.items():RULES[key]={'rule':'type','types':[t],'factor':1.2,'note':TYPE_KO[t]+' 기술 피해1.2배'}
for key,status in {'cheri':'paralysis','chesto':'sleep','pecha':'poison','rawst':'burn','aspear':'freeze','persim':'confusion','lum':'all'}.items():
 # Freeze has no battle representation yet, so do not offer a nonfunctional Aspear Berry.
 if status=='freeze':continue
 RULES[key+'-berry']={'rule':'cure','status':status,'consumable':True,'note':('상태이상/혼란' if status=='all' else {'paralysis':'마비','sleep':'수면','poison':'독','burn':'화상','confusion':'혼란'}[status])+' 해제 후 소모'}
for key,amount in [('oran',10),('sitrus',0)]:RULES[key+'-berry']={'rule':'heal','amount':amount,'consumable':True,'note':'HP½ 이하에 '+('HP10' if amount else '최대HP¼')+' 회복 후 소모'}
for key,stat in [('liechi','attack'),('ganlon','defense'),('salac','speed'),('petaya','special_attack'),('apicot','special_defense')]:
 RULES[key+'-berry']={'rule':'stat','stat':stat,'consumable':True,'note':'HP¼ 이하에 '+{'attack':'공격','defense':'방어','speed':'스피드','special_attack':'특공','special_defense':'특방'}[stat]+'+1 후 소모'}
def generate(game,cache):
 for name,h in HASHES.items():assert hashlib.sha256((cache/name).read_bytes()).hexdigest()==h,name
 raw={r['identifier']:r for r in csv.DictReader((cache/'items.csv').open())}
 ko={r['item_id']:r['name'] for r in csv.DictReader((cache/'item_names.csv').open()) if r['local_language_id']=='3'}
 prose={r['item_id']:r['short_effect'] for r in csv.DictReader((cache/'item_prose.csv').open()) if r['local_language_id']=='9'}
 out={}
 for key,rule in RULES.items():
  r=raw[key];assert r['id'] in ko and (r['id'] in prose or key=='clear-amulet'),key
  sprite=game/'assets/items'/f'{key}.png';assert sprite.read_bytes().startswith(b'\x89PNG'),key
  power=int(r['fling_power'] or (30 if key=='clear-amulet' else 0))
  out[key.replace('-','_')]={'name':ko[r['id']],'description':rule['note']+(' · 사용 후 다시 획득해야 함' if rule.get('consumable') else ''),'icon':'held:'+key,'source_id':int(r['id']),'identifier':key,'fling_power':power,'fling_effect_id':int(r['fling_effect_id'] or 0),'source_effect':prose.get(r['id'],'Prevents stat reduction caused by other Pokemon.'),'sprite_sha256':hashlib.sha256(sprite.read_bytes()).hexdigest(),**{k:v for k,v in rule.items() if k!='note'}}
  if key=='clear-amulet':out[key.replace('-','_')]['effect_reference']='https://bulbapedia.bulbagarden.net/wiki/Clear_Amulet'
 return {'schema_version':1,'route_version':21,'source':{'pokeapi_commit':COMMIT,'csv_sha256':HASHES,'sprites_commit':SPRITES},'consumption':'permanent-until-recycled','items':out}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args()
 d=generate(a.game_dir,a.cache_dir);(a.game_dir/'data/held_items_v21.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['items']),'official held items')
