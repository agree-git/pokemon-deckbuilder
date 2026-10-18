#!/usr/bin/env python3
"""Generate separate v7 P1 definitions; never rewrite the frozen v6 input."""
import argparse
import hashlib
import json
from pathlib import Path
from import_boss_move_effects import STAT_NAMES, AILMENTS, DEFERRED_MOVES

SUPPORTED = {'enemy_stats','enemy_ailments','rest_sleep_talk','charge_recharge','multi_hit','recoil_drain','fixed_order_adaptation'}
# Fixed turn order has no priority/flinch rolls. Double Team uses visible protection.
ORDER_ADAPTED = {104,407,418,428,403}
HITS = {24:2,154:3,198:3,292:3,331:3,350:3,530:2,818:3}
LOCKS = {37,80,200}
CHARGES = {76:'sun',905:'rain'}


def move_view(move_id, raw):
    r=raw[str(move_id)]
    v={'move_id':move_id,'name':r['name'],'type':r['type'],'damage_class':{1:'status',2:'physical',3:'special'}[r['category']]}
    if r['category']!=1:
        assert r['power']>0,move_id
        v['move_power']=r['power']
    if r['stats'] and move_id not in [104,905]:
        assert all(x['stat_id'] in STAT_NAMES for x in r['stats']),move_id
        v['stat_changes']={STAT_NAMES[x['stat_id']]:x['change'] for x in r['stats']}
        v['stat_target']='self' if move_id in [276,315,354,370,665] or (r['category']!=1 and any(x['change']>0 for x in r['stats'])) or r['target'] in [4,7,13] else 'enemy'
    if r['ailment']:
        assert r['ailment'] in AILMENTS,move_id
        status=AILMENTS[r['ailment']];v[status]=1 if status=='sleep' else 3
    if r['healing']>0:v['heal']=8
    if r['drain']:
        v['drain_percent']=r['drain']
    if move_id in HITS:v['hits']=HITS[move_id]
    if move_id in LOCKS:v['lock_turns']=2
    if move_id in CHARGES:v['charge_weather']=CHARGES[move_id]
    if move_id in [63,416]:v['recharge']=True
    if move_id==156:v['rest']=True
    if move_id==214:v['sleep_talk']=True
    if move_id==104:v['shield']=6
    if move_id in ORDER_ADAPTED and move_id!=104:v['order_note']='고정된 턴 순서 유지 · 우선도/풀죽음 추가 판정 없음'
    return v


def generate(game, source):
    spec=json.loads(source.read_text(encoding='utf-8'))
    raw=json.loads((game/'data/pokedex_expansion.json').read_text(encoding='utf-8'))['move_definitions']
    old=json.loads((game/'data/boss_move_effects_v6.json').read_text(encoding='utf-8'))
    profiles={};moves={};deferred={}
    for e in spec['entries']:
        for a in e['aces']:
            key=e['key']+':'+str(a['species'])
            blockers={t for audit in a['move_audit'] for t in audit['required_mechanics'] if t not in SUPPORTED}
            blockers.update(DEFERRED_MOVES[i] for i in a['moves'] if i in DEFERRED_MOVES)
            for audit in a['move_audit']:
                if 'fixed_order_adaptation' in audit['required_mechanics'] and audit['move'] not in ORDER_ADAPTED:
                    blockers.add('미구현 개별 순서/회피 효과')
            if blockers:deferred[key]=sorted(blockers);continue
            intents=[]
            for s in a['cycle']:
                phase=s['phase'];i=s.get('move',0)
                if phase.startswith('charge-'):
                    i={'charge-solar':76,'charge-electro':905}[phase];kind='prepare'
                else:kind={'guard':'guard','move':'move','recharge':'recharge','sleep-rest':'wait'}[phase]
                intents.append({'kind':kind,'value':6 if kind=='guard' else 0,'move_id':i})
            profiles[key]={'boss':e['key'],'species':a['species'],'name':e['name'],'plan':a['theme'],'intents':intents}
            for i in a['moves']:moves[str(i)]=move_view(i,raw)
    # Engine support is independently tested before Whitney's Attract can be enabled.
    for i in [156,214]:moves[str(i)]=move_view(i,raw)
    assert set(old['profiles'])<=set(profiles)
    return {'schema_version':1,'route_version':7,'effects_version':2,
        'scope':'P0 + P1 충전/재충전·연타·반동/흡수·고정2턴 연속기·잠자기. 잠꼬대 엔진은 지원, 꼭두는 헤롱헤롱 구현 대기',
        'specification_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'rules':dict(old['rules'],multi_hit='가변 연타는3회, 고정 연타는 원래 횟수. 기절 시 중단',recoil='보호막/과잉 피해를 뺀 실제 HP 피해 기준; 33은1/3',rampage='2턴 고정 공격 후 자신 혼란3회',rest='최대 HP 회복·화상/독/마비 해제 후 다음2행동 수면; HP가 가득 차면 실패',sleep_talk='수면 중 충전기/잠자기/잠꼬대 제외 기술을 순서 기반 선택, 추첨 없음',double_team='회피 추첨 대신 HP 비례 보호막6',order='우선도/풀죽음은 고정 턴 순서를 바꾸지 않음'),
        'moves':dict(sorted(moves.items(),key=lambda p:int(p[0]))),'profiles':profiles,'deferred':deferred}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    source=Path(__file__).resolve().parents[1]/'docs/boss-ace-tactics.json'
    d=generate(a.game_dir.resolve(),source)
    (a.game_dir/'data/boss_move_effects_v7.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"{len(d['profiles'])} representatives / {len(d['moves'])} moves; {len(d['deferred'])} deferred")
