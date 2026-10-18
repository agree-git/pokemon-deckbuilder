#!/usr/bin/env python3
"""Generate the v11 overlay; published v10 inputs and engines remain unchanged."""
import argparse,csv,hashlib,json
from pathlib import Path
BASE_SHA='cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255'
GROUPS={
 'push':['roar','whirlwind','dragon-tail','circle-throw'],
 'pivot':['teleport','parting-shot','chilly-reception'],
 'baton':['baton-pass'],'shed':['shed-tail'],
 'rocks':['stealth-rock'],'spikes':['spikes'],'toxic':['toxic-spikes'],'web':['sticky-web'],
 'bind':['bind','wrap','fire-spin','whirlpool','sand-tomb','magma-storm','infestation','snap-trap','thunder-cage'],
 'taunt':['taunt'],'encore':['encore'],'disable':['disable'],'torment':['torment'],'heal_block':['heal-block'],
 'split':['pain-split'],'sap':['strength-sap'],'clear':['defog'],'spin':['rapid-spin','mortal-spin']}
NOTES={
 'push':'파티 순서를 바꾸는 강제 교대 대신 상대의 행동 예고를 다음 칸으로 밀어냄 · 상대당 턴1회 · 충전/연속 행동 중단',
 'pivot':'사용 뒤 이번 턴 다음 수동 교대 비용0 · 구속/뿌리 제한 유지',
 'baton':'이번 턴 다음 교대에 자신의 능력 단계와 남은 대타HP 인계 · 수동 교대 비용0 · 구속/뿌리 제한 유지',
 'shed':'최대HP½ 소비 · 최대HP¼의 대타 생성 · 이번 턴 다음 교대에 대타 인계/수동 교대 비용0',
 'rocks':'상대 필드에 스텔스록 · 다음 상대 입장마다 최대HP⅛×바위 상성 피해 · 중첩 없음',
 'spikes':'상대 필드 압정1~3겹 · 땅에 닿은 다음 상대 입장 시 최대HP⅛/⅙/¼ 피해',
 'toxic':'상대 필드 독압정1~2겹 · 접지한 다음 상대에게 독3/5회 · 독 타입이 흡수하고 강철/비행은 면역',
 'web':'다음 상대가 땅에 닿아 입장하면 스피드-1 · 중첩 없음',
 'bind':'실제 명중 뒤4상대턴 동안 행동 종료마다 최대HP⅛ 구속 피해 · 시전자 교대/기절 시 해제 · 현재 NPC는 자발 교대 없음',
 'taunt':'이번부터3상대턴 동안 변화 기술 사용 금지 · 막힌 예고는 행동 실패 후 다음 칸 진행',
 'encore':'이번부터3상대턴 동안 직전 사용 기술만 허용 · 다른 예고는 행동 실패 후 다음 칸 진행 · 원래 순서 유지',
 'disable':'직전 사용 기술을 이번부터4상대턴 봉인 · 다른 기술은 허용',
 'torment':'이번부터4상대턴 동안 같은 기술 연속 성공 금지 · 막힌 행동은 다음 예고로 진행',
 'heal_block':'이번부터5상대턴 회복 기술 사용 금지 · 흡수/지속 회복도 HP 증가 차단',
 'split':'양쪽 현재HP 평균으로 조정 · 각 최대HP 상한 · 보호/대타에는 양쪽 모두 실패 · 자기 회복 증가에는 회복 감소 유물 반영',
 'sap':'상대의 감소 전 실제 공격 능력치만큼 자기HP 회복 후 상대 공격-1 · 보호/대타/공격-6에는 실패',
 'clear':'양쪽 기존 스텔스록/장막과 새 상대 설치4종 제거',
 'spin':'명중 시 자기 쪽 스텔스록/구속 해제 · 킬러스핀은 독3회'}
def generate(game,csv_dir):
 base=game/'data/player_move_cards_v10.json';assert hashlib.sha256(base.read_bytes()).hexdigest()==BASE_SHA
 old=json.loads(base.read_text());sources=old['source']['csv_sha256']
 for n,expected in sources.items():
  assert hashlib.sha256((csv_dir/n).read_bytes()).hexdigest()==expected,n
 names={r['identifier']:r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())}
 out={}
 for tag,names_in in GROUPS.items():
  for name in names_in:
   key=names[name];v=json.loads(json.dumps(old['moves'][key]));v['extension']=tag
   if v.get('damage_class')=='status':v.pop('block',None)
   v['card_notes']=v.get('card_notes',[])+[NOTES[tag]]
   if name=='chilly-reception':v['weather']='snow';v['card_notes'].append('눈 날씨5턴')
   if name=='mortal-spin':v['poison']=3
   if tag in ['baton','shed','pivot','rocks','spikes','toxic','web','taunt','encore','disable','torment','heal_block','split','sap']:v['upgrade']={'cost':max(0,v['cost']-1)}
   if tag=='shed':v['cost']=2;v['upgrade']={'cost':1}
   out[key]=v
 return {'schema_version':1,'route_version':11,'player_moves_version':3,'base_sha256':BASE_SHA,'source':old['source'],'moves':out,'total_enhanced':len(set(out)|set(old['enhanced']))}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_tactics_v11.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 print(len(d['moves']),'overlay cards;',d['total_enhanced'],'enhanced total')
