#!/usr/bin/env python3
"""Freeze v12 exchange/copy traits over the unchanged v10 and v11 inputs."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE='ee46cbac553dd2736ff20c4781205c3024fe39e4ef52b8c1761a54d95666ab53'
GROUPS={'power_swap':['power-swap'],'guard_swap':['guard-swap'],'heart_swap':['heart-swap'],'psych_up':['psych-up'],'invert':['topsy-turvy'],'steal':['spectral-thief'],'power_trick':['power-trick'],'power_split':['power-split'],'guard_split':['guard-split'],'speed_swap':['speed-swap'],'water':['soak'],'psychic':['magic-powder'],'ghost':['trick-or-treat'],'grass':['forests-curse'],'reflect_type':['reflect-type'],'conversion':['conversion'],'conversion2':['conversion-2'],'camouflage':['camouflage'],'roost':['roost'],'burn_up':['burn-up'],'shift':['psycho-shift']}
COPY=['mimic','mirror-move','copycat','me-first','metronome','assist','nature-power','sketch','instruct']
NOTES={'power_swap':'상대와 공격/특공 능력 단계 교환','guard_swap':'상대와 방어/특방 능력 단계 교환','heart_swap':'상대와 모든 능력 단계 교환','psych_up':'상대의 능력 단계를 자신에게 복사','invert':'상대의 양수/음수 능력 단계 반전','steal':'공격 전에 상대의 양수 능력 단계를 훔쳐 자신의 단계에 더함','power_trick':'자신의 공격/방어 기본 능력치 교환 · 능력 단계는 유지','power_split':'양쪽 공격/특공 기본 능력치를 각각 평균으로 조정 · 단계 유지','guard_split':'양쪽 방어/특방 기본 능력치를 각각 평균으로 조정 · 단계 유지','speed_swap':'상대와 스피드 기본 능력치 교환 · 이번 턴 지급 에너지 유지','water':'상대의 전투 타입을 물 하나로 변경','psychic':'상대의 전투 타입을 에스퍼 하나로 변경 · 풀 타입은 가루 면역','ghost':'상대에게 고스트 타입 추가 · 추가 타입은 하나만 유지','grass':'상대에게 풀 타입 추가 · 추가 타입은 하나만 유지','reflect_type':'자신의 전투 타입을 상대와 같게 변경','conversion':'자신의 첫 습득 기술 타입 하나로 변경','conversion2':'상대가 직전 사용한 공격을 반감/무효로 받는 다른 타입을 공개된 순서로 선택','camouflage':'날씨에 맞는 전투 타입: 비 물/쾌청 불꽃/눈 얼음/모래 바위/그 외 노말','roost':'회복 뒤 이번 상대 행동까지 자신의 비행 타입 제거','burn_up':'불꽃 타입일 때만 사용 · 성공 후 불꽃 타입 소모 · 타입 재부여/교대하면 다시 사용 가능','shift':'자신의 주 상태이상을 상대에게 옮기고 자신은 해제 · 상대 상태/타입/보호를 확인'}
COPY_NOTES={'mimic':'상대의 직전 공격 기술 복사','mirror-move':'상대의 직전 공격 중 따라하기 허용 플래그의 기술만 복사','copycat':'양쪽이 마지막으로 사용한 기술이 공격이면 복사','me-first':'상대가 다음에 예고한 공격 기술을 복사하고 피해1.5배','metronome':'시드/사용자별 공개18타입 공격 순환 · 사용 시에만 다음 순서','assist':'살아 있는 다른 동료의 첫 복사 가능한 습득 공격 호출','nature-power':'날씨에 맞는 공격: 비 파도타기/쾌청 화염방사/눈 냉동빔/모래 파워젬/그 외 트라이어택','sketch':'첫 복사 공격을 이번 전투에 고정 · 소진 · 영구 기술 슬롯은 유지','instruct':'자신이 직전 사용한 공격을 반복'}
POOL=['tackle','ember','water-gun','thunder-shock','vine-whip','powder-snow','karate-chop','poison-sting','mud-slap','gust','confusion','fury-cutter','rock-throw','lick','dragon-breath','bite','metal-claw','fairy-wind']
def generate(game,csv_dir):
 v11=game/'data/player_move_tactics_v11.json';assert hashlib.sha256(v11.read_bytes()).hexdigest()==BASE
 old=json.loads(v11.read_text());base=json.loads((game/'data/player_move_cards_v10.json').read_text())
 assert hashlib.sha256((game/'data/player_move_cards_v10.json').read_bytes()).hexdigest()==old['base_sha256']
 for n,h in old['source']['csv_sha256'].items():assert hashlib.sha256((csv_dir/n).read_bytes()).hexdigest()==h,n
 ids={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())};out={}
 groups={**GROUPS,'copy':COPY}
 for tag,names in groups.items():
  for name in names:
   k=ids[name];v=json.loads(json.dumps(old['moves'].get(k,base['moves'][k])));v['exchange']=tag
   v.pop('block',None);v['card_notes']=v.get('card_notes',[])+[NOTES[tag] if tag!='copy' else COPY_NOTES[name]]
   if tag=='copy':v['copy_mode']=name;v['card_notes']+=['충전/재충전/자폭/복사/반격/일격기 제외 · 현재 사용자 능력치 · 복사 카드 비용 유지 · 추가 카드/UID 없음']
   if name=='sketch':v['exhaust']=True
   if name!='spectral-thief':v['upgrade']={'cost':max(0,v['cost']-1)}
   if tag not in ['copy','shift','roost']:v['card_notes'].append('교대/전투 종료 시 원래 능력치·타입 복구 · 도감/폼/HP 유지')
   out[k]=v
 return {'schema_version':1,'route_version':12,'player_moves_version':4,'base_sha256':BASE,'source':old['source'],'moves':out,'total_enhanced':len(set(out)|set(old['moves'])|set(base['enhanced'])),'pool':[int(ids[n]) for n in POOL],'nature':{w:int(ids[n]) for w,n in {'rain':'surf','sun':'flamethrower','snow':'ice-beam','sand':'power-gem','':'tri-attack'}.items()},'type_order':['normal','fire','water','electric','grass','ice','fighting','poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy']}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_exchange_v12.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
