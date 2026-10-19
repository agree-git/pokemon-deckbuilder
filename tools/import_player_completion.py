#!/usr/bin/env python3
"""Build the remaining v27 traits and explicit policies for all 919 cards."""
import argparse,copy,hashlib,json,re
from pathlib import Path
PINS = {'player_move_cards_v10.json': 'cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255', 'player_move_tactics_v11.json': 'ee46cbac553dd2736ff20c4781205c3024fe39e4ef52b8c1761a54d95666ab53', 'player_move_exchange_v12.json': '1586ae99131c89cac7a0d3c4e95f89261b2865e89a1c5be6b4191b50b3b0fc33', 'player_move_fields_v13.json': '4a970fc9f58ab132138d42ab53b2d779fb2fbcc9d3a414cb520be5d4ec9716d1', 'player_move_seals_v14.json': 'b9e3a818e2f359c9aa2582ca988c36f2b1c2251419dd18c65867e6451c408543', 'player_move_altitude_v15.json': '596e9b74d5cb953481ffbec6abf8f1a7f10870681abc42bcfd4d7980354851aa', 'player_move_traps_v16.json': '1784987e13a8d2a405a48e1983f4a9637a8b36c7b7be8795f2343115a1347103', 'player_move_items_v17.json': '5165abda6c87b7274ea1f7dcd57c23c03b9dd9b40b33a13163adeacf51f02251', 'player_move_assist_v18.json': '2f84e8a18ee1b46d3e9ded28bacf53a34d577911dca79c2ed20bf24923c30b9c', 'player_move_fate_v19.json': '5aa55a74d9382b115f43f616e7f2e40e4cbba151084b1d62a529a6abe6a5970c', 'player_move_reactions_v20.json': 'ffd3bfb2485c4e61790d0e2ee09629b079dbeb72e9305aebb9a6d49e7b03b283', 'player_move_training_v22.json': '21ba4e654916749d6acf9049e02913cb92610bd22e616123e97ec746f0091686', 'player_move_bulk_v23.json': 'd2fa0fa25059099f5290139a261a71d8deb12b663985d451ba4e51c11e470a87', 'player_move_interactions_v24.json': '9cda3ca64e304c33c24777c90ed83b54a3e897db4d3e17d7ae1b51bc70003341', 'player_move_support_v25.json': 'fa42f8466048ddeeb0c22d320925232053cd7303c7053574eaf362251ee5ae6c', 'player_move_adaptive_v26.json': '1f8b04ad4c8c107f8102cd28640f9b669fe76e25030fbe9f3f212987514dacb5'}
SOURCE_SHA='61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7'
LAYERS=['cards_v10','tactics_v11','exchange_v12','fields_v13','seals_v14','altitude_v15','traps_v16','items_v17','assist_v18','fate_v19','reactions_v20','training_v22','bulk_v23','interactions_v24','support_v25','adaptive_v26']
def generate(game,cache):
    merged={};previous=set();hashes={}
    for layer in LAYERS:
        p=game/'data'/('player_move_'+layer+'.json');sha=hashlib.sha256(p.read_bytes()).hexdigest();assert sha==PINS[p.name],p.name;hashes[p.name]=sha
        d=json.loads(p.read_text())
        if layer=='bulk_v23':previous={k for k,v in d['audit'].items() if v['mode']!='standard'}
        if layer in ['support_v25','adaptive_v26']:previous.update(d['moves'])
        for k,v in d['moves'].items():
            merged[k]=copy.deepcopy(v) if 'move_id' in v else {**merged[k],**copy.deepcopy(v)}
            if v.get('support_changes'):
                merged[k].pop('stat_changes',None);merged[k].pop('stat_target',None)
    raw=(cache/'moves.ts').read_bytes();assert hashlib.sha256(raw).hexdigest()==SOURCE_SHA
    source={};starts=list(re.finditer(r'^\t(?:"([^"\n]+)"|(\w+)): \{\n',raw.decode(),re.M))
    text=raw.decode()
    for n,m in enumerate(starts):
        body=text[m.end():starts[n+1].start() if n+1<len(starts) else len(text)];num=re.search(r'^\t\tnum: (\d+),',body,re.M)
        if num and 1<=int(num[1])<=919:source[num[1]]=body
    out={}
    def add(mid,note,remove=(),**rules):
        key=str(mid);v=copy.deepcopy(out.get(key,merged[key]))
        for field in remove:v.pop(field,None)
        v.update(rules);v['card_notes']=v.get('card_notes',[])+[note];out[key]=v
    add(6,'상금 대신 명중 후 카드1장 · 골드/경제 변경 없음',completion_rule='draw')
    add(150,'원작처럼 전투 효과 없음 · 비용0',cost=0,upgrade={'cost':0})
    add(228,'상대가 교대 기술을 준비하면 위력2배 · 교대 직전 추가 공격은 생략',completion_rule='pursuit')
    add(268,'특방+1 및 다음 전기 공격 위력2배 · 사용/교대 시 충전 해제',completion_rule='charge')
    add(111,'방어+1 · 교대 전까지 구르기/아이스볼 위력2배',completion_rule='curl')
    add(107,'기존 회피의 보호막 각색 유지 · 짓밟기 계열에 피해2배',completion_rule='minimize')
    add(475,'스피드+2 및 몸무게100kg 감소 · 최소0.1kg · 교대 시 복구',completion_rule='lighten')
    for mid in [67,447,484,535]:add(mid,'현재 변신 종/폼·바디퍼지의 무게로 위력 계산',completion_rule='weight')
    for mid in [23,34,407,537,560,484,535]:add(mid,'작아지기 중인 상대에게 위력2배')
    for mid in [205,301]:add(mid,'웅크리기 중이면 기존 연속 위력에 추가2배')
    for mid in [364,467,566,593,621]:add(mid,'공격할 때 보호를 관통하고 해당 보호 상태 해제 · 준비 중에는 해제하지 않음',completion_rule='break_guard')
    for mid in [252,660]:add(mid,'입장한 첫 아군턴의 첫 자기 기술로만 사용 가능 · 교대 전 자원 소모 없이 조건 확인',remove=['special'],completion_rule='entry')
    for mid in [389,909]:add(mid,'직전 피격 대신 상대의 예고된 직접 공격에 반응 · 변화/수면/준비/재충전에는 실패',remove=['special'],completion_rule='sucker')
    add(918,'상대의 우선도 양수인 직접 공격을 예고했을 때만 사용 가능 · 풀죽음은 피해20% 경감 각색',completion_rule='upper',pressure_down=True)
    for mid in [691,859]:add(mid,'명중 뒤 자기 능력 저하 · 상대를 낮추지 않음',stat_target='self')
    add(799,'연타 명중 뒤 자기 방어-1/스피드+1 · 카드당1회',stat_changes={'defense':-1,'speed':1},stat_target='self')
    add(788,'중력 중 위력1.5배 · 상대 방어 저하 유지',completion_rule='gravity')
    for mid in [732,741]:add(mid,'친밀도에 비례하는 위력 · 최대102 · 강화+15',remove=['upgrade'],variable='return',upgrade={'power_upgrade':15})
    add(733,'실제 HP 피해의50% 흡수 · 회복봉인 적용',drain_percent=50)
    add(736,'명중 후 아군 빛의장막5턴 · 피해 없이 준비/실패한 경우 제외',completion_rule='screen')
    add(737,'명중 후 아군 리플렉터5턴 · 같은 장막은 갱신',completion_rule='reflect')
    add(738,'명중 후 씨뿌리기3회 · 풀 타입/대타/보호 면역 유지',seed=3)
    add(739,'명중 후 양쪽 출전 능력 단계를 초기화 · 대기 동료 제외',completion_rule='haze')
    add(740,'명중 후 살아 있는 동료 전원의 주요 상태 치료 · 씨뿌리기/혼란 등은 유지',completion_rule='party_cure')
    add(747,'유효한 소지 나무열매를 먹고 방어+2 · 실제 영구 소모/리사이클·트림과 연결',completion_rule='stuff')
    for mid in [505,666]:add(mid,'가장 부상 비율이 큰 살아 있는 다른 동료를 자동 회복 · 대상/회복 가능 여부를 미리 표시',remove=['heal'],completion_rule='ally_heal')
    add(676,'부상 동료가 있으면 가장 부상 비율이 큰 동료HP½ 회복 · 없으면 기존 공격',completion_rule='pollen')
    add(850,'자신 특공/특방+1 및 주요 상태 치료 · 씨뿌리기/혼란은 유지',stat_changes={'special_attack':1,'special_defense':1},stat_target='self')
    add(816,'살아 있는 동료 전원HP¼ 회복 및 주요 상태 치료 · 회복봉인 적용',remove=['heal'],bulk_rule='lunar')
    for mid in [156,215,287,312,685,816,849]:add(mid,'주요 상태만 치료 · 씨뿌리기/혼란/노출 등 별도 상태는 유지')
    for k,body in source.items():
        if re.search(r'^\t\tdrain: \[',body,re.M):add(int(k),'흡수는 실제 HP 피해 기준 · 회복봉인 적용')
    for mid in [73,105,135,156,208,234,235,236,256,273,303,355,392,456,659,668]:
        if str(mid) in merged:add(mid,'기술 회복/지속 회복은 회복봉인을 적용 · 아픔나누기는 별도 HP 조정 규칙 유지')
    audit={};notes={}
    named={445:'성별 없이 상대 특공-2로 각색',464:'카드 체계에서는 원작 사용 종 제한 생략',481:'단일 상대 전투라 주변 확산 피해 없음',547:'수면 효과 유지 · 전투 전용 폼 변경 생략',744:'다이맥스 없는 전투 · 대상 다이맥스 추가 배율 없음',781:'다이맥스 없는 전투 · 추가 배율 없음',782:'다이맥스 없는 전투 · 추가 배율 없음',783:'스피드 상승 유지 · 원작 사용 종/전투 전용 폼 제한 생략',874:'특공 저하 유지 · 원작 상금 효과 생략/경제 변경 없음',713:'새 특성 체계 없이 공격 효과 적용',714:'새 특성 체계 없이 공격 효과 적용',724:'새 특성 체계 없이 공격 효과 적용',725:'새 특성 체계 없이 공격 효과 적용'}
    for mid,note in named.items():add(mid,note)
    for i in range(1,920):
        k=str(i);v=out.get(k,merged[k]);body=source.get(k,'');policy=[]
        if v.get('block') and i in [104,107]:policy.append('회피 단계 대신 보호막으로 각색')
        if v.get('sleep') and re.search(r"status: ['\"]frz",body):policy.append('얼음 상태 대신 수면으로 각색')
        if re.search(r'^\t\tpriority: [1-9]',body,re.M):policy.append('별도 동시 행동 순서 대신 카드 사용/기술별 소진 규칙 적용')
        if re.search(r'chance: (?:[1-9]|[1-9][0-9]),',body) and any(f in v for f in ['burn','poison','sleep','paralysis','confusion','stat_changes','pressure_down']):policy.append('원작 부가 확률 대신 카드 효과 적용')
        if i in [59,87,542]:policy.append('명중률 추첨이 없어 날씨별 명중률 변화는 생략')
        if i in named:policy.append(named[i])
        classification='no_battle_effect' if i in [150,606] else 'adapted' if policy else 'implemented' if k in out or k in previous else 'standard'
        audit[k]={'name':v['name'],'classification':classification,'basis':'v27' if k in out else 'versioned_card_rule' if k in previous else 'standard_card_rule','adaptations':policy}
        if policy:notes[k]=policy
    assert len(audit)==919
    deltas={k:{f:v for f,v in entry.items() if v!=merged[k].get(f)} for k,entry in out.items()}
    removed={k:[f for f in merged[k] if f not in entry] for k,entry in out.items()}
    priority={k:int(m[1]) for k,body in source.items() if (m:=re.search(r'^\t\tpriority: (-?\d+),',body,re.M)) and int(m[1])!=0}
    return {'schema_version':1,'route_version':27,'player_moves_version':19,'base_sha256':hashes,'source':{'repository':'smogon/pokemon-showdown','commit':'7b02eb39878f4b486f658a752b38c161379bd352','path':'data/moves.ts','sha256':SOURCE_SHA},'scope':'All 919 cards classified under the existing game rules; original PP, abilities, accuracy rolls and battle-only forms remain explicit adaptations.','moves':out,'deltas':deltas,'removed':removed,'audit':audit,'policy_notes':notes,'priority':priority,'common_rules':['healing_block','major_status_only','charge_curl_minimize_weight','entry_and_announced_attack','guard_break'],'pending':[]}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args()
    d=generate(a.game_dir,a.cache_dir);(a.game_dir/'data/player_move_completion_v27.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'changed;',len(d['audit']),'classified; pending',len(d['pending']))
