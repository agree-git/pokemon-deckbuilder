#!/usr/bin/env python3
"""Freeze the complete reviewed ace rollout in route v9; v6-v8 stay byte-identical."""
import argparse, copy, csv, hashlib, json
from pathlib import Path
from import_boss_move_effects_p1 import move_view

def generate(game, source, csv_dir):
    spec=json.loads(source.read_text()); old=json.loads((game/'data/boss_move_effects_v8.json').read_text())
    raw=json.loads((game/'data/pokedex_expansion.json').read_text())['move_definitions']; modified=copy.deepcopy(raw)
    for i in [90,329]: modified[str(i)]['power']=160
    for i in [213,281,749,675]: modified[str(i)]['ailment']=0
    # Tera Blast is Normal/special without Terastallization, with no Stellar self drop.
    modified['851']['stats']=[]
    modified['838']['stats']=[{'stat_id':3,'change':-1},{'stat_id':5,'change':-1}]
    modified['838']['target']=7
    d=copy.deepcopy(old);d.update(route_version=9,effects_version=4,scope='검토된138대표/233기술의 카드 전투 효과; 원작 확률·PP·특성·테라스탈은 명시 각색',deferred={})
    d['move_flags']={}
    for row in csv.DictReader((csv_dir/'move_flag_map.csv').open()):
        if int(row['move_flag_id']) in [1,4,7,9,10,14]:d['move_flags'].setdefault(row['move_id'],[]).append(int(row['move_flag_id']))
    custom={213:'attract',194:'destiny',281:'yawn',174:'curse',282:'knock_off',510:'incinerate',252:'fake_out',749:'tar',675:'silence',801:'shell_side',826:'eerie',818:'critical',168:'thief',90:'ohko',329:'ohko',136:'jump_kick',340:'bounce',690:'beak',893:'hammer',862:'glaive',915:'temper',119:'mirror',143:'sky',892:'double_shock',907:'fickle',389:'sucker'}
    for e in spec['entries']:
        for a in e['aces']:
            k=e['key']+':'+str(a['species']); cycle=[]
            for s in a['cycle']:
                phase=s['phase'];i=s.get('move',0)
                if phase.startswith('charge-'):i={'charge-solar':76,'charge-electro':905,'charge-sky':143}[phase];kind='prepare'
                else:kind={'guard':'guard','move':'move','recharge':'recharge','sleep-rest':'wait'}[phase]
                cycle.append({'kind':kind,'value':6 if kind=='guard' else 0,'move_id':i})
            d['profiles'][k]={'boss':e['key'],'species':a['species'],'name':e['name'],'plan':a['theme'],'intents':cycle}
            for i in a['moves']:
                if str(i) not in d['moves']: d['moves'][str(i)]=move_view(i,modified)
    for i,kind in custom.items():d['moves'][str(i)]['unique']=kind
    for i in [498,663]:d['moves'][str(i)]['ignore_defense']=True
    for i in [90,329]:d['moves'][str(i)]['move_power']=160
    d['moves']['851'].pop('stat_changes',None);d['moves']['851'].pop('stat_target',None)
    d['moves']['851']['adaptation']='테라스탈 없음 · 노말 특수80 · 자기 능력 하락 없음'
    d['moves']['510']['adaptation']='열매/주얼 지닌 물건이 없는 현행 장비 목록에서는 파괴 대상 없음'
    d['moves']['818'].pop('order_note',None)
    d['moves']['818']['hits']=3
    d['rules'].update(attract='성별/확률 시스템 대신 다음2아군턴 시전자 대상 기술 피해 절반; 어느 쪽 교대/기절 시 해제',eerie='PP 대신 대상이 마지막 사용한 기술ID를 다음3아군턴 봉인; 다른 기술/도구/교대 가능',ohko='일격 기절 대신 위력160 공개 강공격; 더 높은 레벨/절대영도 얼음/땅 무효는 실패',fickle='새 난수 없이10회 중3/6/10번째160,나머지80; 예고에 공개',mirror='현 출전자가 마지막으로 상대에게 쓴 공격 기술의 카드 위력/타입/분류·기본 상태/단계 복사; 원작 고유효과 전체 복사는 아님',items='탁쳐서떨구기/도둑질은 전투 동안 장비 무효; 전투 종료 복구,영구 아이템 손실/적 장비 보너스 없음',critical='수류연타 확정1.5배 · 자기 공격 음수/대상 방어 양수 무시; 화상 감소 유지; 급소 추첨 없음',fake_out='첫 자기 행동만 성공; 기존 명세 순서에서 이미 행동했다면 실패',sucker='고정 아군→적 순서에서 현재 대상이 이번 턴 공격 기술을 썼으면 성공',type_loss='전광쌍격 성공 후 전투 문맥에서 전기 타입 소모; 도감 타입/폼은 보존',charge='불새는 명세 충전1행동,뛰어오르기는 같은 단계에서 준비/공격2행동과 공중 회피',temper='직전 자기 기술 실패/수면 취소 시 위력150; 화상 부여 기술 아님')
    d['moves']=dict(sorted(d['moves'].items(),key=lambda p:int(p[0])))
    d['effect_sources']={'pokeapi_pin':'5ee47a9a9c1229632ec4b473a9c1c53026e005dd','prose_sha256':'f6d9bf0d28433a010a8b8b6a0a14d1ef72fbfcb997717f71b0e34483b7ee9697','supplemental':['https://pokemondb.net/move/headlong-rush','https://pokemondb.net/move/temper-flare','https://pokemondb.net/move/fickle-beam','https://bulbapedia.bulbagarden.net/wiki/Glaive_Rush_(move)','https://bulbapedia.bulbagarden.net/wiki/Gigaton_Hammer_(move)','https://bulbapedia.bulbagarden.net/wiki/Double_Shock_(move)']}
    assert len(d['profiles'])==138 and not d['deferred']
    return d
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args()
    d=generate(a.game_dir,Path(__file__).resolve().parents[1]/'docs/boss-ace-tactics.json',a.csv_dir)
    (a.game_dir/'data/boss_move_effects_v9.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    live={v['move_id'] for p in d['profiles'].values() for v in p['intents'] if v['move_id']}
    print(len(d['profiles']),'representatives',len(live),'live moves',len(d['moves']),'engine moves')
