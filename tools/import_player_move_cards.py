#!/usr/bin/env python3
"""Freeze characteristic player-card effects for new v10 journeys, without changing old cards."""
import argparse,csv,hashlib,json
from pathlib import Path
PIN='5ee47a9a9c1229632ec4b473a9c1c53026e005dd'
EXTRA_SHA={'move_flag_map.csv':'399cf005933418f406b94729903bd1528e9088bddc3bc1966be6c442a625da1b','move_effect_prose.csv':'f6d9bf0d28433a010a8b8b6a0a14d1ef72fbfcb997717f71b0e34483b7ee9697'}
VARIABLE_NAMES={'low-kick':'weight','grass-knot':'weight','flail':'flail','reversal':'flail','return':'return','frustration':'frustration','magnitude':'magnitude','facade':'facade','focus-punch':'focus','endeavor':'endeavor','eruption':'eruption','water-spout':'eruption','dragon-energy':'eruption','gyro-ball':'gyro','brine':'brine','payback':'payback','assurance':'assurance','trump-card':'trump','wring-out':'crush','punishment':'punishment','avalanche':'avalanche','crush-grip':'crush','heavy-slam':'heavy','electro-ball':'electro','foul-play':'foul','stored-power':'stored','hex':'hex','acrobatics':'acrobatics','retaliate':'retaliate','heat-crash':'heavy','power-trip':'stored','photon-geyser':'higher','body-press':'body_press','shell-side-arm':'shell','rage-fist':'rage','fickle-beam':'fickle','hard-press':'hard_press','temper-flare':'temper','weather-ball':'weather','burning-jealousy':'jealousy'}
CUSTOM_NAMES={'counter':'counter','seismic-toss':'level','dragon-rage':'forty','night-shade':'level','sonic-boom':'twenty','psywave':'psywave','super-fang':'half','natures-madness':'half','ruination':'half','metal-burst':'metal_burst','comeuppance':'metal_burst','mirror-coat':'mirror_coat','final-gambit':'final_gambit','guillotine':'ohko','horn-drill':'ohko','fissure':'ohko','sheer-cold':'ohko','dream-eater':'dream','rest':'rest','sleep-talk':'sleep_talk','substitute':'substitute','haze':'haze','heal-bell':'party_cure','aromatherapy':'party_cure','refresh':'refresh','yawn':'yawn','focus-energy':'focus_energy','belly-drum':'belly','clear-smog':'clear_stages','light-screen':'screen','reflect':'reflect','safeguard':'safeguard','curse':'curse','defog':'defog','u-turn':'pivot','volt-switch':'pivot','flip-turn':'pivot','fake-out':'fake_out','sucker-punch':'sucker','hydro-steam':'hydro_steam','take-heart':'refresh','purify':'purify','stockpile':'stockpile','swallow':'swallow','spit-up':'spit_up','wish':'wish','aqua-ring':'ring','ingrain':'root','attract':'attract','throat-chop':'silence','eerie-spell':'seal','tar-shot':'tar','knock-off':'knock','thief':'thief','destiny-bond':'destiny','double-shock':'double_shock','glaive-rush':'glaive','gigaton-hammer':'hammer','beak-blast':'beak'}
CHARGE_NAMES={'razor-wind':'','fly':'air','solar-beam':'sun','dig':'burrow','skull-bash':'','sky-attack':'','dive':'dive','bounce':'air','shadow-force':'vanish','freeze-shock':'','ice-burn':'','phantom-force':'vanish','geomancy':'','solar-blade':'sun','meteor-beam':'','electro-shot':'rain'}
GUARD_NAMES={'protect':'protect','detect':'protect','endure':'endure','wide-guard':'protect','quick-guard':'protect','crafty-shield':'protect','kings-shield':'king','spiky-shield':'spiky','baneful-bunker':'baneful','obstruct':'obstruct','burning-bulwark':'burning'}
SELF_DROP={276,315,354,359,370,434,437,557,620,621,665,705,838,874,890}
STAT={2:'attack',3:'defense',4:'special_attack',5:'special_defense',6:'speed'}
AIL={1:'paralysis',2:'sleep',3:'sleep',4:'burn',5:'poison',6:'confusion'}
def generate(game,csv_dir):
 expansion=json.loads((game/'data/pokedex_expansion.json').read_text())
 for name,expected in {**EXTRA_SHA,**{n+'.csv':expansion['csv_sources'][n]['sha256'] for n in ['moves','move_meta']}}.items():
  if hashlib.sha256((csv_dir/name).read_bytes()).hexdigest()!=expected:raise ValueError('Unexpected pinned CSV: '+name)
 raw=expansion['move_definitions']
 ids={r['identifier']:int(r['id']) for r in csv.DictReader((csv_dir/'moves.csv').open())}
 VARIABLE={ids[k]:v for k,v in VARIABLE_NAMES.items()};CUSTOM={ids[k]:v for k,v in CUSTOM_NAMES.items()}
 CHARGES={ids[k]:v for k,v in CHARGE_NAMES.items()};GUARDS={ids[k]:v for k,v in GUARD_NAMES.items()}
 meta={r['move_id']:r for r in csv.DictReader((csv_dir/'move_meta.csv').open())}
 flags={}
 for r in csv.DictReader((csv_dir/'move_flag_map.csv').open()):flags.setdefault(r['move_id'],[]).append(int(r['move_flag_id']))
 out={};coverage={}
 for key,r in raw.items():
  i=int(key);mt=meta.get(key,{});families=[];notes=[]
  v={'move_id':i,'name':r['name'],'type':r['type'],'cost':2 if r['power']>=90 else 1,'damage_class':{1:'status',2:'physical',3:'special'}[r['category']]}
  if r['category']!=1:v.update(damage=1,move_power=r['power'] or 40)
  if r['stats'] and i!=851:
   changes={STAT[s['stat_id']]:s['change'] for s in r['stats'] if s['stat_id'] in STAT}
   if changes:
    v.update(stat_changes=changes,stat_target='self' if i in SELF_DROP or i==850 or r['target'] in [4,7,13] or (r['category']!=1 and any(s['change']>0 for s in r['stats'])) else 'enemy')
   if any(s['stat_id']==7 and s['change']<0 for s in r['stats']):v['pressure_down']=True;families.append('accuracy');notes.append('명중 약화 대신 이번 상대 행동의 공격 피해20% 감소 · 중첩 없음')
   if any(s['stat_id']==8 and s['change']>0 for s in r['stats']):v['block']=8;notes.append('회피 추첨 대신 보호막')
  if i==838:v.update(stat_changes={'defense':-1,'special_defense':-1},stat_target='self');families.append('self_cost')
  if i in SELF_DROP:families.append('self_cost')
  if i==73:v['seed']=3
  elif r['ailment'] in AIL:v[AIL[r['ailment']]]=1 if AIL[r['ailment']]=='sleep' else 3
  if r['healing']>0:
   v['heal']=round(48*r['healing']/100);families.append('healing')
   notes.append('원래 회복 비율 적용 · 잃은 HP까지만 회복')
   if i in [234,235,236,659]:v['weather_heal']=True;notes.append('날씨에 따라 회복량 변경')
  if r['healing']<0 or i in [720,796]:v['hp_cost']=abs(r['healing']) if r['healing']<0 else 50;families.append('self_cost')
  if r['drain']:
   v['drain_percent']=r['drain'];families.append('drain' if r['drain']>0 else 'recoil')
   notes.append('실제 HP 피해의 %d%% %s · 보호막/과잉 피해 제외' % (abs(r['drain']),'흡수 회복' if r['drain']>0 else '자기 반동'))
  lo=int(mt.get('min_hits') or 1);hi=int(mt.get('max_hits') or 1)
  if hi>1:
   count=lo if lo==hi else 3
   v['hit_weights']=[1]*count
   if i in [167,813]:v['hit_weights']=[1,2,3]
   if i==251:v['party_hits']=True
   families.append('multi_hit');notes.append('%d회 타격 · 대상 기절 시 중단 · 부가상태/단계는 카드당1회' % count)
  if i in [ids['population-bomb'],ids['tachyon-cutter']]:v['hit_weights']=[1]*(10 if i==ids['population-bomb'] else 2);families.append('multi_hit')
  if i in [ids['flower-trick'],ids['wicked-blow']] or int(mt.get('crit_rate') or 0)>=6:v['critical']=True;families.append('critical');notes.append('확정 급소1.5배 · 불리한 공격/방어 단계 무시 · 화상 감소 유지')
  elif int(mt.get('crit_rate') or 0)>0:v['high_crit']=True;families.append('high_crit');notes.append('높은 급소율 대신 피해15% 증가 · 추첨 없음')
  if int(mt.get('flinch_chance') or 0)>0:v['pressure_down']=True;families.append('flinch');notes.append('풀죽음 대신 이번 상대 행동의 공격 피해20% 감소 · 중첩 없음')
  if i in [130,800,905]:v['charge_boost']={'defense' if i==130 else 'special_attack':1}
  if i in CHARGES:v['charge']=CHARGES[i];families.append('charge');notes.append('먼저 충전해 카드를 보존 · 다음 아군턴부터 비용0 발사 · 교대 시 충전 취소')
  if 3 in flags.get(key,[]) or r['effect_id']==81:v['recharge']=True;families.append('recharge');notes.append('사용 뒤 다음 아군턴 종료까지 이 동료의 기술 사용 불가 · 다른 동료/도구 가능')
  if i in VARIABLE:v['variable']=VARIABLE[i];families.append('variable')
  if i in CUSTOM:v['special']=CUSTOM[i];families.append(CUSTOM[i])
  if i in GUARDS:v['guard']=GUARDS[i];families.append('guard');notes.append('이번 상대 공격에 HP1을 남기고 버팀 · 지속 피해 제외' if GUARDS[i]=='endure' else '이번 상대 행동까지 보호 · 한 동료당 턴1회 · 조건부 가드는 공용 보호로 각색')
  if i in [498,533,663]:v['ignore_defense']=True;families.append('ignore_defense');notes.append('상대 방어 단계 무시')
  if i in [205,210,301,497]:v['chain']=True;families.append('chain');notes.append('같은 기술 연속 사용 시 위력 증가 · 다른 기술/교대/턴 공백으로 초기화')
  if i in [120,153,262,515]:v['self_ko']=True;families.append('self_ko');notes.append('사용 후 자신 기절')
  if i in [136,26]:v['crash']=50;families.append('crash');notes.append('타입 무효로 실패하면 자신 최대HP/2 충돌 반동 · 중력 중 사용 불가')
  if i in [240,241,258,201]:v={'move_id':i,'name':r['name'],'type':r['type'],'cost':1,'damage_class':'status','weather':{240:'rain',241:'sun',258:'snow',201:'sand'}[i]}
  if i==150:v['cost']=0;notes.append('아무 효과 없음')
  if i==851:v.pop('stat_changes',None);v.pop('stat_target',None);families.append('tera_blast');notes.append('테라스탈이 없는 전투에서는 노말 특수 기술')
  if i in [68,243,368,69,101,82,49,149,162,283,515,717]:v.update(damage=1,move_power=1)
  if i in [12,32,90,329]:v['move_power']=160;notes.append('일격 기절 대신 위력160 강공격 · 더 높은 레벨/타입 무효에는 실패')
  if i in GUARDS or i in [164,156,114,215,312,287,281,116,187,113,115,219,174,432,214] or v.get('special') in ['wish','ring','root','stockpile','attract','destiny']:
   for f in ['block','heal','stat_changes','stat_target','poison','sleep','confusion','pressure_down']:v.pop(f,None)
  if i==156:v['heal']=48;notes.append('최대 회복·화상/독/마비 해제 후 다음 두 아군턴 수면')
  if i==187:v['cost']=2
  if v.get('special')=='stockpile':v.update(stat_changes={'defense':1,'special_defense':1},stat_target='self')
  if v.get('special')=='swallow':v['heal']=12
  if v.get('special')=='spit_up':v.update(damage=1,move_power=100)
  if v.get('special') in ['wish','party_cure','ring','root']:v['exhaust']=True
  if i in [369,521,812]:notes.append('공격 후 이번 턴 수동 교대 비용0 · 교대를 강요하지 않음')
  if r['priority']>0 and r['category']!=1:
   v['cost']=max(0,v['cost']-1);v['exhaust']=True;families.append('priority');notes.append('선공 대신 비용1 감소·소진 · 턴 순서는 유지')
  if not any(f in v for f in ['damage','heal','stat_changes','block','seed','burn','poison','sleep','paralysis','confusion','special','guard','weather','pressure_down']):
   if i!=150:v['block']=5
  special_notes={'counter':'직전 상대턴의 마지막 물리 HP 피해2배 반환','mirror_coat':'직전 상대턴의 마지막 특수 HP 피해2배 반환','metal_burst':'직전 상대턴의 마지막 HP 피해1.5배 반환','level':'레벨과 같은 고정 피해 · 능력/상성 배율 무시 · 타입 무효 유지','twenty':'고정 피해20 · 타입 무효 유지','forty':'고정 피해40 · 타입 무효 유지','psywave':'변동 추첨 대신 레벨과 같은 고정 피해','half':'상대 현재HP의 절반 피해 · 타입 무효 유지','final_gambit':'자신의 현재HP와 같은 피해를 주고 기절','dream':'수면 중인 상대에게만 피해/흡수','substitute':'자신 최대HP의¼ 소비 · 같은HP의 대타 생성 · 교대 시 해제','haze':'자신과 상대의 능력 단계 초기화','party_cure':'동료 전원의 상태이상 제거','refresh':'자신의 상태이상 제거','yawn':'상대가 다음 행동을 마친 뒤 수면1회 · 이미 주 상태가 있으면 실패','focus_energy':'다음 자신의 공격을 확정 급소로 강화','belly':'최대HP의½ 소비 · 자신의 공격을+6단계로','screen':'다음5아군턴 특수 공격 피해 절반','reflect':'다음5아군턴 물리 공격 피해 절반','safeguard':'다음5아군턴 상태이상 부여 방어','curse':'비고스트: 공격/방어+1·스피드-1; 고스트: HP½ 소비·상대에 매턴HP¼ 저주','clear_stages':'명중 후 상대 능력 단계 초기화','defog':'스텔스록/장막/신비의부적 제거','fake_out':'이 동료의 전투 첫 기술에서만 성공','sucker':'카드 전투에서는 직전 상대턴에 이 동료가 직접 HP 피해를 받았을 때 성공','hydro_steam':'쾌청에서도 물 피해가 약해지지 않고1.5배'}
  special_notes.update({'purify':'상대 상태이상을 치유하고 자신의HP 절반 회복','stockpile':'3회까지 비축하며 방어/특방+1','swallow':'비축1/2/3회 소비 → HP25/50/100% 회복 · 비축 방어도 해제','spit_up':'비축 횟수×100 위력 · 비축과 그 방어 상승을 소비','wish':'다음 아군턴 시작에 자신 최대HP의 절반 회복','ring':'출전 중 자기 턴 종료마다 최대HP의1/16 회복 · 교대 시 해제','root':'출전 중 턴마다HP1/16 회복 · 뿌리를 내려 교대 불가 · 고스트는 탈출 가능','attract':'성별/추첨 대신 다음2상대턴 동안 자신에게 받는 공격 피해 절반 · 교대 시 해제','silence':'다음2상대턴 음성 기술 봉인','seal':'대상이 직전 사용한 기술을 다음3상대턴 봉인 · PP 대신 기술 봉인','tar':'상대 스피드-1 · 이번 전투 상대가 받는 불꽃 피해2배','knock':'상대가 장비 보유 시 위력1.5배·장비 무효 · 현재 보스는 별도 장비 없음','thief':'상대 장비 무효 · 현재 보스는 별도 장비 없음','destiny':'다음 자기 기술 전 상대의 직접 공격으로 쓰러지면 그 상대도 기절 · 지속 피해 제외','double_shock':'성공 후 전기 타입 소모 · 재사용 실패 · 교대하면 전기 타입 복구 · 도감/폼은 유지','glaive':'공격 후 다음 자기 기술까지 받는 공격 피해2배','hammer':'성공 직후 같은 기술 연속 사용 불가','beak':'이 카드 이후 이번 상대 행동에서 접촉한 상대에게 화상'})
  if v.get('special') in special_notes:notes.append(special_notes[v['special']])
  if v.get('variable')=='endeavor':notes.append('상대 HP를 자신의 현재HP까지 낮추는 고정 피해')
  if v.get('variable') in ['payback','avalanche']:notes.append('직전 상대턴에 자신이 HP 피해를 받았다면 위력2배')
  if v.get('variable')=='body_press':notes.append('공격 대신 자신의 방어 능력치로 공격')
  if v.get('variable')=='foul':notes.append('자신 대신 상대의 공격 능력치로 공격')
  if v.get('variable')=='temper':notes.append('직전 자신의 기술이 실패했다면 위력2배')
  fixed={'counter','mirror_coat','metal_burst','level','twenty','forty','psywave','half','final_gambit','ohko'}
  if v.get('special') in fixed|{'swallow','rest'} or v.get('variable')=='endeavor':v['upgrade']={'cost':max(0,v['cost']-1)}
  elif 'variable' in v or 'chain' in v:v['upgrade']={'power_upgrade':15}
  elif 'damage' in v:v['upgrade']={'move_power':v['move_power']+max(1,15//sum(v.get('hit_weights',[1])))}
  v['card_notes']=notes;out[key]=v
  if families:coverage[key]=sorted(set(families))
 return {'schema_version':1,'route_version':10,'player_moves_version':2,'source':{'pokeapi_commit':PIN,'csv_sha256':{n:hashlib.sha256((csv_dir/n).read_bytes()).hexdigest() for n in ['moves.csv','move_meta.csv','move_flag_map.csv','move_effect_prose.csv']}},'moves':out,'enhanced':coverage,'flags':flags,'weights':json.loads((game/'data/boss_move_effects_v9.json').read_text())['weights']}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--csv-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.csv_dir)
 (a.game_dir/'data/player_move_cards_v10.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 print(len(d['moves']),'cards',len(d['enhanced']),'with characteristic rules')
