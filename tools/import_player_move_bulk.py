#!/usr/bin/env python3
"""Build a single v23 batch and an explicit audit of all 919 existing moves."""
import argparse, copy, hashlib, json
from pathlib import Path

PINS = {'player_move_cards_v10.json': 'cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255', 'player_move_tactics_v11.json': 'ee46cbac553dd2736ff20c4781205c3024fe39e4ef52b8c1761a54d95666ab53', 'player_move_exchange_v12.json': '1586ae99131c89cac7a0d3c4e95f89261b2865e89a1c5be6b4191b50b3b0fc33', 'player_move_fields_v13.json': '4a970fc9f58ab132138d42ab53b2d779fb2fbcc9d3a414cb520be5d4ec9716d1', 'player_move_seals_v14.json': 'b9e3a818e2f359c9aa2582ca988c36f2b1c2251419dd18c65867e6451c408543', 'player_move_altitude_v15.json': '596e9b74d5cb953481ffbec6abf8f1a7f10870681abc42bcfd4d7980354851aa', 'player_move_traps_v16.json': '1784987e13a8d2a405a48e1983f4a9637a8b36c7b7be8795f2343115a1347103', 'player_move_items_v17.json': '5165abda6c87b7274ea1f7dcd57c23c03b9dd9b40b33a13163adeacf51f02251', 'player_move_assist_v18.json': '2f84e8a18ee1b46d3e9ded28bacf53a34d577911dca79c2ed20bf24923c30b9c', 'player_move_fate_v19.json': '5aa55a74d9382b115f43f616e7f2e40e4cbba151084b1d62a529a6abe6a5970c', 'player_move_reactions_v20.json': 'ffd3bfb2485c4e61790d0e2ee09629b079dbeb72e9305aebb9a6d49e7b03b283', 'player_move_training_v22.json': '21ba4e654916749d6acf9049e02913cb92610bd22e616123e97ec746f0091686'}

LAYERS = ['cards_v10', 'tactics_v11', 'exchange_v12', 'fields_v13', 'seals_v14',
          'altitude_v15', 'traps_v16', 'items_v17', 'assist_v18', 'fate_v19',
          'reactions_v20', 'training_v22']

def generate(game):
    merged, signatures, hashes = {}, set(), {}
    for layer in LAYERS:
        p = game/'data'/('player_move_'+layer+'.json')
        d = json.loads(p.read_text()); hashes[p.name] = hashlib.sha256(p.read_bytes()).hexdigest()
        assert hashes[p.name] == PINS[p.name], p.name
        merged.update(d['moves']); signatures.update(d.get('enhanced', d['moves']))
    out = {}
    def add(mid, note, **rules):
        key = str(mid); v = copy.deepcopy(out.get(key, merged[key]))
        if v['damage_class'] == 'status':
            v.pop('block', None); v['upgrade'] = {'cost': max(0, v['cost']-1)}
        v.update(rules); v['card_notes'] = v.get('card_notes', [])+[note]
        out[key] = v
    # All 29 former shield-only status moves, grouped in one release.
    for mid, rule, note in [
        (144,'transform','상대의 타입·능력치·단계를 복사하고 자신의 기술 카드를 상대 기술 슬롯으로 전환 · HP/장비/영구 학습 유지 · 교대 시 해제'),
        (180,'spite','PP 대신 상대 직전 기술을 2상대턴 봉인'),
        (266,'cover','주목을 끌어 이번 상대 행동의 파티 직접 피해½ · 교대 후에도 유지 · 실제 대상 변경은 하지 않음'),
        (272,'role','특성 대신 상대의 양수 능력 단계를 자신에게 복사 · 음수 단계는 유지'),
        (277,'reflect','이번 상대 행동의 반사 가능한 대상 변화 효과를 상대에게 반사 · 공격/필드/자기 강화 제외'),
        (285,'swap','특성 대신 양쪽의 양수 능력 단계와 양수 위력 강화를 교환 · 음수 단계 유지'),
        (286,'imprison','출전 중 자신이 배운 기술과 같은 상대 기술 봉인 · 자신 교대/기절 시 해제'),
        (288,'grudge','다음 자신의 기술 전까지 직접 공격에 기절하면 그 상대 기술을 이 전투 동안 봉인 · PP 대신 기술 봉인'),
        (289,'snatch','이번 상대 행동의 자기 능력 강화/직접 회복을 취소하고 자신이 받음 · 공격 부가효과 제외'),
        (380,'suppress','특성 대신 상대의 양수 능력 단계와 양수 위력 강화를 제거'),
        (388,'insomnia','상대 수면 해제 · 3상대턴 동안 수면 방지 · 새 특성 시스템 없음'),
        (476,'powder_cover','풀 타입 상대는 무효 · 이번 상대 행동의 파티 직접 피해½ · 대상 변경 대신 피해 경감'),
        (493,'simple','다음 3상대턴 상대에게 생기는 능력 단계 변화량2배 · ±6 상한 유지 · 새 특성 시스템 없음'),
        (494,'give','특성 대신 자신의 양수 능력 단계를 상대에게 덮어씀 · 양쪽 음수 단계 유지'),
        (502,'ally_switch','다음 살아 있는 대기 동료로 무료 교대 · 구속/입장 피해 제한 유지'),
        (561,'mat','첫 턴에만 이번 상대 행동의 파티 공격 피해 차단 · 변화 효과 제외'),
        (606,'celebrate','축하 메시지 · 원작처럼 전투 효과 없음 · 비용0'),
        (607,'hands','함께 손을 잡은 동료 전원에게 최대HP⅛ 보호막 · 다른 살아 있는 동료 필요'),
        (671,'spotlight','더블배틀 대상 변경 대신 다른 동료 전원의 다음 공격 확정 급소'),
        (673,'laser','다음 자신의 공격 확정 급소 · 교대 시 해제'),
        (752,'tea','양쪽 출전 포켓몬의 유효한 소지 나무열매를 즉시 먹음 · 조건 무시/영구 소모 · 리사이클 가능'),
        (849,'lunar','살아 있는 동료 전원 최대HP¼ 회복 및 상태이상 치료 · 회복 감소/봉인 적용'),
        (863,'revive','첫 기절 동료 최대HP½로 회생 · 사용 동료당 전투1회 · 기절로 소진된 기술은 버린 더미로 복귀 · 부상 유지'),
        (867,'doodle','특성 대신 상대의 양수 능력 단계를 살아 있는 동료 전원에게 복사'),
        (913,'cheer','다른 동료 전원의 다음 공격 확정 급소 · 드래곤의 추가 급소 단계는 별도 추첨 없이 통합'),
    ]: add(mid,note,bulk_rule=rule)
    add(230,'회피 단계 대신 상대 취약3턴 · 받는 공격 피해 증가',expose=1)
    add(603,'상금 대신 보급 카드2장 뽑기 · 전투 중 소진 · 상금/경제 변경 없음',draw=2,exhaust=True)
    add(743,'다이맥스 없이 사용하는 보호 · 이번 상대 행동 피해/상태 차단',guard='protect')
    add(883,'양쪽에 눈5턴 · 얼음 타입 물리 방어1.5배 · 날씨 교체',weather='snow')
    out['606'].update(cost=0,upgrade={'cost':0})
    for mid in [849,863]:out[str(mid)]['exhaust']=True
    # Existing generic attacks with missing signature behavior.
    for mid in [37,80,200]:add(mid,'같은 기술3회 연속 사용 후 자신 혼란 · 다른 기술 불가/교대로 해제',bulk_rule='rampage')
    add(99,'이후 직접 피해를 받을 때 공격+1 · 다음 다른 자기 기술/교대 시 해제',bulk_rule='rage')
    add(128,'명중 시4회 구속 · 상대 교대/시전자 이탈 규칙 유지',extension='bind')
    add(161,'확률 대신 화상/마비/독 중 유효한 상태 하나를 기술 사용 횟수에 따라 순환 · 얼음 상태는 독으로 각색',bulk_rule='tri')
    for mid in [206,610]:add(mid,'직접 피해로 상대 HP를1 미만으로 내리지 않음',bulk_rule='false_swipe')
    add(217,'추첨 대신 위력40→80→120→상대HP¼ 회복의 공개4회 주기',bulk_rule='present')
    add(237,'개체값 없이 자신의 첫 타입 · 위력60 고정',move_power=60,bulk_rule='hidden')
    for mid in [248,353]:add(mid,'공격을 예고한 뒤 두 번째 상대 행동 종료에 발동 · 그때 출전 상대/상성/보호 적용 · 시전자 기절에도 유지',bulk_rule='future')
    add(253,'자기 소란3턴 · 양쪽 출전 수면 해제/방지 · 연속 사용 강제는 생략',bulk_rule='uproar')
    for mid,status in [(265,'paralysis'),(358,'sleep')]:add(mid,'대상의 해당 상태라면 위력2배 · 명중 후 상태 치료',bulk_rule='wake',condition_status=status)
    add(279,'직전 상대 행동에 자신이 직접 피해를 받았으면 위력2배',variable='avalanche')
    for mid in [280,706]:add(mid,'피해 계산 전에 상대 빛의장막/리플렉터/오로라베일 제거',bulk_rule='break_screens')
    add(290,'현재 필드에 따라 마비/수면/특공 저하/공격 저하 · 필드 없으면 마비',bulk_rule='secret')
    add(343,'명중 후 상대 소지품 제거 · 소유권 복구는 기존 전투 규칙',special='thief')
    add(363,'자신의 나무열매별 위력/타입으로 공격 후 영구 소모',bulk_rule='gift')
    for mid in [365,450]:add(mid,'명중 시 상대 나무열매를 먹고 효과를 자신에게 적용 · 원래 물건 영구 소모',bulk_rule='eat')
    add(387,'자신의 다른 습득 기술을 이 전투에서 모두 사용한 뒤 사용 가능',bulk_rule='last_resort')
    for mid in [449,546,718]:add(mid,'지원하는 타입 강화 소지품이 있으면 해당 타입 · 없으면 원래 타입',bulk_rule='item_type')
    for mid in [473,540,548]:add(mid,'특수 공격력으로 상대 물리 방어를 계산 · 특수 기술 분류 유지',defense_stat='defense')
    add(474,'상대가 독이면 위력2배',bulk_rule='poison_double')
    add(485,'자신과 같은 타입을 하나 이상 가진 상대에게만 명중',bulk_rule='shared_type')
    add(496,'이번 턴 이미 다른 동료가 돌림노래를 썼으면 위력2배',bulk_rule='round')
    add(507,'200kg 이상/비행 상대 실패 · 동시 들어올리기 대신 명중 후 이번 상대 직접 피해½',bulk_rule='sky_drop')
    add(510,'명중 시 상대 나무열매를 태워 영구 소모 · 열매 효과는 발동하지 않음',bulk_rule='incinerate')
    for mid in [518,519,520]:add(mid,'같은 턴 다른 동료의 다른 맹세와 조합하면 위력2배 · 두 기술에 따라 습지/불바다/무지개4턴',bulk_rule='pledge')
    for mid,other in [(558,559),(559,558)]:add(mid,'이번 턴 앞서 반대 크로스 기술을 사용했다면 위력2배',bulk_rule='fusion',partner=other)
    add(560,'격투와 비행 상성을 곱해 계산 · 격투 타입 자속 유지',bulk_rule='flying_press')
    add(562,'이번 전투에 자신이 나무열매를 소모한 뒤에만 사용 가능',bulk_rule='belch')
    add(565,'이 공격으로 상대를 쓰러뜨리면 공격+3',bulk_rule='fell')
    for mid in [662,677]:add(mid,'명중 후 상대 자발 교대 봉쇄 · 시전자/대상 이탈·기절 시 해제',bulk_rule='lock')
    add(664,'명중 후 상대 화상 치료',bulk_rule='cure_burn')
    add(686,'자신의 첫 타입으로 공격',bulk_rule='hidden')
    add(687,'특성 대신 명중 후 상대 양수 능력 단계 제거',bulk_rule='suppress')
    add(698,'상대 현재HP의¾ 고정 피해 · 타입 무효/보호 적용',bulk_rule='guardian')
    add(703,'명중 후 사이코필드5턴',bulk_rule='terrain_psychic')
    add(704,'직전 상대 행동에 물리 직접 피해를 받은 경우에만 사용 가능',bulk_rule='shell_trap')
    add(707,'직전 자기 기술의 효과가 실패했으면 위력2배',bulk_rule='stomping')
    add(721,'명중 후 이번 턴 양쪽 노말 기술을 전기로 변환 · 발버둥 제외',bulk_rule='plasma')
    add(723,'현재 보정된 공격/특공 중 높은 쪽으로 물리/특수 분류 선택',bulk_rule='higher_offense')
    add(727,'명중 후 모든 필드 제거',bulk_rule='clear_terrain')
    for mid,weather in [(757,'sun'),(763,'snow'),(765,'rain'),(770,'sand')]:add(mid,'명중 후 해당 날씨5턴 · 다이맥스 변신 없이 카드 효과 적용',bulk_rule='max_weather',after_weather=weather)
    for mid,terrain in [(759,'electric'),(767,'misty'),(769,'psychic'),(773,'grassy')]:add(mid,'명중 후 해당 필드5턴 · 다이맥스 변신 없이 카드 효과 적용',bulk_rule='max_terrain',after_terrain=terrain)
    for mid,stat,self_target in [(758,'special_attack',False),(760,'speed',False),(761,'attack',True),(762,'defense',False),(764,'special_attack',True),(766,'speed',True),(768,'attack',False),(771,'special_defense',True),(772,'special_defense',False),(774,'defense',True)]:
        add(mid,'명중 후 아군 전원 능력+1' if self_target else '명중 후 상대 능력-1',bulk_rule='party_stat' if self_target else 'max_drop',after_stat=stat)
    for mid in [754,755]:add(mid,'현재 스피드가 상대보다 높으면 위력2배 · 순서 대신 스피드 조건',bulk_rule='faster')
    add(808,'현재 자신의 음수 능력 단계가 있으면 위력2배 · 원작 해당 턴 감소 조건 각색',bulk_rule='negative')
    add(809,'상대가 소지품을 지니고 있어야 사용 가능 · 물건 무효 상태와 별개',bulk_rule='poltergeist')
    # Late-generation moves whose official CSV lacks effect metadata.
    add(827,'화상/독/마비 중 유효한 상태를 공개 순환으로 부여',bulk_rule='fatal')
    add(828,'공격 후 자신의 방어+1',stat_changes={'defense':1},stat_target='self')
    add(830,'명중 후 스텔스록 설치',extension='rocks',high_crit=True)
    add(831,'공격 후 상대 공격-1',stat_changes={'attack':-1},stat_target='enemy')
    add(832,'공격 후 자신의 특공+1',stat_changes={'special_attack':1},stat_target='self')
    for mid in [833,834]:add(mid,'실제 HP 피해의⅓ 자기 반동',drain_percent=-33)
    add(835,'사용 후 자신 최대HP½ 반동 · 명중 여부와 무관',bulk_rule='chloroblast')
    add(836,'공격 후 상대 스피드-1',stat_changes={'speed':-1},stat_target='enemy')
    for mid in [839,844]:add(mid,'상대 상태이상 시 위력2배 · 독3회 부여',variable='hex',poison=3)
    add(840,'확률 대신 공격 후 자신의 공격/특공 중 높은 쪽+1',bulk_rule='esper')
    add(841,'공격 후 상대 특방-1',stat_changes={'special_defense':-1},stat_target='enemy')
    add(843,'높은 급소율·상대 방어-1·풀죽음 대신 피해 경감',high_crit=True,pressure_down=True,stat_changes={'defense':-1},stat_target='enemy')
    add(845,'명중 후 압정 설치',extension='spikes')
    add(846,'공격 후 상대 스피드-1',stat_changes={'speed':-1},stat_target='enemy')
    add(847,'명중 후 마비3회',paralysis=3)
    add(848,'명중 후 화상3회',burn=3)
    add(852,'이번 상대 행동 보호 · 접촉 기술 사용자는 스피드-1',guard='protect',bulk_rule='silk')
    out['852'].pop('stat_changes',None);out['852'].pop('stat_target',None)
    add(853,'풀죽음 대신 이번 상대 공격 피해20% 감소 · 명중 추첨 없음',pressure_down=True)
    add(854,'이번 전투에 기절한 아군 수마다 위력+50 · 현재 기절 상태 기준/최대150 추가',bulk_rule='last_respects')
    add(856,'물속 상대에게도 명중 · 2배 위력 · 삼키기/싸리용은 별도 구현하지 않음',bulk_rule='order')
    add(864,'매 상대 행동 뒤 대상 최대HP⅛ 지속 피해 · 물/강철은¼ · 이탈/기절 시 해제',bulk_rule='salt')
    add(865,'같은 상대에게 개별3타 · 강화는 타당 위력+15',hit_weights=[1,1,1])
    add(868,'자신 최대HP½를 소비한 뒤 공격/특공/스피드+2 · HP가 절반보다 많아야 사용',bulk_rule='shed_tail_cost')
    add(869,'반드시 급소 · 방어 단계/공격 감소 무시',critical=True)
    add(873,'종별 타입 결정 유지 · 상대 장막을 피해 전에 제거',bulk_rule='break_screens')
    add(875,'일렉트릭필드에서 접지한 자신 위력1.5배',bulk_rule='psyblade')
    for mid in [878,879]:add(mid,'효과가 굉장하면 위력4/3배',bulk_rule='super')
    add(882,'양쪽 설치/대타 제거 · 자신 공격/스피드+1 유지',bulk_rule='tidy')
    add(887,'보호를 관통하고 그 보호를 제거',bulk_rule='drill')
    add(888,'같은 상대에게 개별2타 · 강화는 타당 위력+15',hit_weights=[1,1])
    add(891,'실제 HP 피해의½ 흡수 회복',drain_percent=50)
    add(895,'높은 급소율 · 추첨 대신 기존 급소 보정',high_crit=True)
    for mid,field in [(896,{'burn':3}),(897,{'pressure_down':True}),(898,{'poison':3}),(899,{'stat_changes':{'defense':-1},'stat_target':'enemy'}),(900,{'confusion':3})]:add(mid,'자동차 계열은 원작 부가효과를 카드 효과로 연결 · 확률 대신 확정/기존 각색',**field)
    add(901,'자신이 이 기술을 쓴 직후에는 같은 기술 사용 불가 · 다른 기술/교대 후 가능',bulk_rule='bloodmoon')
    add(902,'실제 HP 피해의½ 회복 · 원작 낮은 확률 대신 매4회째 자신 최대HP⅓ 반동 추가',drain_percent=50,bulk_rule='matcha')
    add(903,'이후3상대턴 종료마다 상대 스피드-1 · 즉시 감소는 하지 않음',bulk_rule='syrup')
    out['903'].pop('stat_changes',None);out['903'].pop('stat_target',None)
    add(904,'종별 타입 결정 유지 · 높은 급소율',high_crit=True)
    add(906,'전투 전용 테라폼 없이 원래 타입/위력120의 특수 공격 · 추가 폼 효과 없음',bulk_rule='plain')
    add(910,'공격 후 상대 공격-1',stat_changes={'attack':-1},stat_target='enemy')
    add(914,'상대에게 양수 능력 단계가 있으면 혼란3회',bulk_rule='alluring')
    add(916,'명중/빗나감 추첨 대신 확정 명중 · 보호/타입 무효로 실패하면 최대HP½ 충돌 피해',bulk_rule='crash')
    add(917,'명중 후 상대 회복2턴 봉인',bulk_rule='noise')
    add(919,'명중 후 독5회 · 별도 맹독 누적 대신 지속 시간으로 각색',poison=5)
    # Weather/status-only upgrades are cost changes; attack upgrades stay +15 power.
    audit = {}
    for key,v in merged.items():
        kind = 'batch' if key in out else 'signature' if key in signatures else 'standard'
        audit[key] = {'name':v['name'],'mode':kind}
    assert len(audit)==919
    placeholders=[k for k,v in merged.items() if k not in signatures and v.get('damage_class')=='status' and v.get('block')==5]
    assert len(placeholders)==29 and set(placeholders)<=set(out)
    return {'schema_version':1,'route_version':23,'player_moves_version':15,'base_sha256':hashes,
            'scope':'Original move traits adapted to the existing card battle; no new PP, abilities or battle-only forms.',
            'source':json.loads((game/'data/player_move_cards_v10.json').read_text()).get('source',{}),
            'moves':out,'audit':audit,'total_enhanced':len(signatures|set(out)), 'remaining_placeholder_status':0}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    d=generate(a.game_dir);(a.game_dir/'data/player_move_bulk_v23.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    print(len(d['moves']),'changed;',d['total_enhanced'],'enhanced;',len(d['audit']),'audited')
