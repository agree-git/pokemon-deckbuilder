#!/usr/bin/env python3
"""Build the frozen v6 P0 rollout from the reviewed ace specification."""
import argparse
import hashlib
import json
from pathlib import Path

# These require more than the P0 stat/status/heal bridge. Never silently drop effects.
DEFERRED_MOVES = {281:'하품 지연 수면',663:'DD래리어트 방어 단계 무시',826:'섬뜩한주문 PP 차감',838:'들이받기 자기 방어 약화 원본 보강'}
STAT_NAMES = {2:'attack',3:'defense',4:'special_attack',5:'special_defense',6:'speed'}
AILMENTS = {1:'paralysis',2:'sleep',3:'sleep',4:'burn',5:'poison',6:'confusion'}


def generate(game, source):
    spec=json.loads(source.read_text(encoding='utf-8'))
    raw=json.loads((game/'data/pokedex_expansion.json').read_text(encoding='utf-8'))['move_definitions']
    profiles={};moves={};deferred={}
    for entry in spec['entries']:
        for ace in entry['aces']:
            blockers={t for a in ace['move_audit'] for t in a['required_mechanics'] if t not in ['enemy_stats','enemy_ailments']}
            blockers.update(DEFERRED_MOVES[i] for i in ace['moves'] if i in DEFERRED_MOVES)
            key=entry['key']+':'+str(ace['species'])
            if blockers:
                deferred[key]=sorted(blockers)
                continue
            intents=[]
            for step in ace['cycle']:
                if step['phase']=='guard':
                    intents.append({'kind':'guard','value':6,'move_id':0})
                else:
                    assert step['phase']=='move',key
                    intents.append({'kind':'move','value':0,'move_id':step['move']})
            profiles[key]={'boss':entry['key'],'species':ace['species'],'name':entry['name'],'plan':ace['theme'],'intents':intents}
            for move_id in ace['moves']:
                r=raw[str(move_id)]
                view={'move_id':move_id,'name':r['name'],'type':r['type'],'damage_class':{1:'status',2:'physical',3:'special'}[r['category']]}
                if r['category']!=1:
                    assert r['power']>0,(key,move_id)
                    view['move_power']=r['power']
                if r['stats']:
                    assert all(v['stat_id'] in STAT_NAMES for v in r['stats']),(key,move_id)
                    view['stat_changes']={STAT_NAMES[v['stat_id']]:v['change'] for v in r['stats']}
                    self_cost=move_id in [276,315,354,370,665]
                    raises_user=r['category']!=1 and any(v['change']>0 for v in r['stats'])
                    view['stat_target']='self' if self_cost or raises_user or r['target'] in [4,7,13] else 'enemy'
                if r['ailment']:
                    assert r['ailment'] in AILMENTS,(key,move_id)
                    status=AILMENTS[r['ailment']]
                    view[status]=1 if status=='sleep' else 3
                if r['healing']>0:view['heal']=8
                assert not r['drain'],(key,move_id)
                moves[str(move_id)]=view
    assert len(profiles)==19 and len(deferred)==119
    return {'schema_version':1,'route_version':6,'effects_version':1,'scope':'P0 단계·상태·회복 · 나머지 대표는 v5 전술 유지',
            'specification_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'rules':{'secondary_effects':'기존 카드처럼 표시된 효과를 확정 적용; 확률 RNG 추가 없음','freeze':'기존 카드처럼 수면1턴으로 각색','toxic':'기존 카드처럼 독3회; 누적 맹독 아님','roost':'회복만 적용; 타입 변경 없음','life_dew':'출전한 자신만 회복'},
            'moves':dict(sorted(moves.items(),key=lambda p:int(p[0]))),'profiles':profiles,'deferred':deferred}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    source=Path(__file__).resolve().parents[1]/'docs/boss-ace-tactics.json'
    data=generate(a.game_dir.resolve(),source)
    target=a.game_dir/'data/boss_move_effects_v6.json'
    target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"{len(data['profiles'])} representatives / {len(data['moves'])} moves; {len(data['deferred'])} deferred")
