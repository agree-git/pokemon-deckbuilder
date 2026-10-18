#!/usr/bin/env python3
"""Generate route v8 effects without rewriting v6/v7 inputs."""
import argparse,copy,csv,hashlib,json
from pathlib import Path
from import_boss_move_effects_p1 import move_view, SUPPORTED
from import_boss_move_effects import DEFERRED_MOVES

VARIABLE={68:'counter',175:'flail',216:'return',228:'pursuit',263:'facade',264:'focus',360:'gyro',362:'brine',368:'metal_burst',371:'payback',372:'assurance',419:'avalanche',447:'grass_knot',474:'venoshock',484:'heavy_slam',506:'hex',514:'retaliate',776:'body_press',912:'hard_press'}
DEFERRED=dict(DEFERRED_MOVES)
DEFERRED.update({136:'무릎차기 실패/반동',340:'뛰어오르기 공중 회피',498:'야금야금 지닌 물건',818:'수류연타 확정 급소',801:'셸암즈 분류 선택',907:'변덕레이저 변동',862:'대검돌격 후 취약',915:'열불내기 조건부 화상',143:'불새 충전/급소'})
ALLOWED=SUPPORTED|{'variable_power','hazards_switch','guard_counter','weather_field'}

def generate(game,source,csv_dir):
    spec=json.loads(source.read_text());dex=json.loads((game/'data/pokedex_expansion.json').read_text())
    old=json.loads((game/'data/boss_move_effects_v7.json').read_text());raw=dex['move_definitions'];modified=copy.deepcopy(raw)
    for i in VARIABLE:
        if modified[str(i)]['category']!=1 and not modified[str(i)]['power']:modified[str(i)]['power']=1
    for i in [182,275,611]:modified[str(i)]['ailment']=0
    profiles={};moves={};deferred={}
    def add(i):
        v=move_view(i,modified)
        if i in VARIABLE:v['variable']=VARIABLE[i]
        if i==439:v['recharge']=True
        if i==446:v['hazard']='rocks'
        if i in [18,46,525]:v['force_switch']=True
        if i in [369,521]:v['pivot_final']=True
        if i in [182,588,792]:v['guard_kind']={182:'protect',588:'king',792:'obstruct'}[i]
        if i==164:v['substitute']=True
        if i==275:v['root']=True
        if i==611:v['trap']='bind'
        if i==746:v['trap']='lock'
        if i in [113,219,356]:v['field']={113:'screen',219:'safeguard',356:'gravity'}[i]
        if i==241:v['weather']='sun'
        if i==533:v['ignore_defense']=True
        if i not in [104,905] and (raw[str(i)]['priority'] or raw[str(i)]['effect_id'] in [32,44,119,274,275,276] or i in [314,421,440,869]):
            v['order_note']='고정 턴 순서 · 우선도/풀죽음/급소·명중 추가 추첨 없음'
        moves[str(i)]=v
    for e in spec['entries']:
        for a in e['aces']:
            k=e['key']+':'+str(a['species'])
            blockers={t for v in a['move_audit'] for t in v['required_mechanics'] if t not in ALLOWED}
            blockers.update(DEFERRED[i] for i in a['moves'] if i in DEFERRED)
            if blockers:deferred[k]=sorted(blockers);continue
            cycle=[]
            for s in a['cycle']:
                phase=s['phase'];i=s.get('move',0)
                if phase.startswith('charge-'):i={'charge-solar':76,'charge-electro':905}[phase];kind='prepare'
                else:kind={'guard':'guard','move':'move','recharge':'recharge','sleep-rest':'wait'}[phase]
                cycle.append({'kind':kind,'value':6 if kind=='guard' else 0,'move_id':i})
            profiles[k]={'boss':e['key'],'species':a['species'],'name':e['name'],'plan':a['theme'],'intents':cycle}
            for i in a['moves']:add(i)
    for i in [156,214,*VARIABLE]:add(i)
    assert set(old['profiles'])<=set(profiles)
    flags={}
    for row in csv.DictReader((csv_dir/'move_flag_map.csv').open()):
        i=row['move_id'];f=int(row['move_flag_id'])
        if i in raw and f in [1,4,9,10,14]:flags.setdefault(i,[]).append(f)
    return {'schema_version':1,'route_version':8,'effects_version':3,'specification_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
      'scope':'P0/P1 + P2 조건부 위력·방어/반격·설치/강제교대·구속·날씨/장막',
      'rules':dict(old['rules'],retaliation='카운터/메탈버스트는 이번 턴 마지막 기술로 받은 실제HP 피해를 현재 출전자에게 반환',pursuit='이번 턴 교대한 출전자에게2배; 교대 도중 끼어들지 않음',retaliate='동료가 이번/직전 턴 기절했을 때2배',return_power='NPC 친밀도255 기준 위력102',protection='다음 자기 행동까지 보호; 킹실드 접촉 공격-2; 전투 폼 변경 없음',rocks='교대 시 최대HP/8×바위 상성; 중첩 없음',pivot='대표 마지막 규칙 유지; 앞 동료가 기절한 마지막 대표는 교대 대상 없음',duration='장막/신비/중력은 다음5아군턴; 구속 피해4회; 뿌리박기1/16회복'),
      'moves':dict(sorted(moves.items(),key=lambda p:int(p[0]))),'profiles':profiles,'deferred':deferred,
      'weights':{str(p['id']):p['weight_hg'] for p in dex['pokemon']},'move_flags':flags,
      'flag_source':{'url':'https://raw.githubusercontent.com/PokeAPI/pokeapi/5ee47a9a9c1229632ec4b473a9c1c53026e005dd/data/v2/csv/move_flag_map.csv','sha256':hashlib.sha256((csv_dir/'move_flag_map.csv').read_bytes()).hexdigest()}}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args()
    d=generate(a.game_dir,Path(__file__).resolve().parents[1]/'docs/boss-ace-tactics.json',a.csv_dir)
    (a.game_dir/'data/boss_move_effects_v8.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    live={v['move_id'] for p in d['profiles'].values() for v in p['intents'] if v['move_id']}
    print(len(d['profiles']),'representatives',len(live),'live moves',len(d['moves']),'engine moves',len(d['deferred']),'deferred')
