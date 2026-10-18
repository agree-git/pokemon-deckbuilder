#!/usr/bin/env python3
"""Write the current role-qualified boss roster and supplied music mapping."""
import argparse,hashlib,json
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',required=True,type=Path);p.add_argument('--output-dir',required=True,type=Path);a=p.parse_args();g=a.game_dir
 read=lambda path:json.loads((g/path).read_text(encoding='utf-8'))
 expansion=read('data/boss_expansion.json');league=read('data/league.json');music=read('assets/audio/boss_music/manifest.json');sprites=read('assets/sources/trainer_sprites.json');parties=read('data/boss_parties.json')['entries'];names={int(p['id']):p['name'] for p in read('data/pokedex_expansion.json')['pokemon']}
 rosters={'gym':read('data/gym_leaders.json')['leaders']+expansion['gyms'],'elite':league['elite']+expansion['elite'],'champion':league['champions']+expansion['champions']};roles={'gym':'관장','elite':'사천왕','champion':'챔피언'};entries=[]
 for role,rows in rosters.items():
  for row in rows:
   id=row.get('leader_id',row.get('id'));key=role+':'+id
   entries.append({'role':role,'role_ko':roles[role],'id':id,'key':key,'name':row.get('leader',row.get('name')),'region':row['region'],'type':row['type'],'party':parties[key]['party'],'fixed_aces':parties[key]['fixed_aces'],'music':music['trainers'][key],'music_fallback':music['fallbacks'].get(key),'sprite':sprites['entries'][key]['path'],'new_matchup':key in expansion['tactics']})
 d={'checked_on':'2026-10-18','route_version':5,'source_files_sha256':{p:hashlib.sha256((g/p).read_bytes()).hexdigest() for p in ['data/gym_leaders.json','data/league.json','data/boss_expansion.json','data/boss_parties.json','assets/audio/boss_music/manifest.json']},'counts':{**{k:len(v) for k,v in rosters.items()},'total':len(entries)},'entries':entries}
 a.output_dir.mkdir(parents=True,exist_ok=True);(a.output_dir/'boss-roster.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 lines=['# 관장·사천왕·챔피언 목록과 BGM 배정','','확인: 2026-10-18. **관장86·사천왕36·챔피언15, 총137대진**. 원정은 관장8→사천왕4→챔피언1, 기존69전투를 유지합니다. 새 원정(v5)은 같은 인물도 역할이 다르면 별개 대진으로 추첨합니다. 이전 저장(v1~v4)은 기존 경로와 파티를 복원합니다.','','사용자 제공39파일을36개 녹음으로 중복 제거해 역할별로 연결했습니다. BW/BW2처럼 같은 역할에 두 곡이 있으면 등장할 때 하나를 고르고 해당 전투 내에서는 유지합니다. 레드는 챔피언입니다. 알로라 섬의왕/여왕은 요청한 관장 역할 후보에 포함합니다. 블루베리는 하나지방의 아카데미이며 첨부 파일의 팔데아 표기는 SV DLC 분류로 처리했습니다.','','비트·마리·타임은 첨부 파일명에 없어 해당 지방의 일반 관장곡을 사용합니다. 표의 `지역 공용`으로 구분합니다. 파티는 사용자 승인한 [원작 기반 목록](boss-party-review.md)을 적용했습니다. 엑셀 대표는 마지막에 고정하며 원작 외 보충은 해당 목록에 표시했습니다. 풍·란은 공동 대진의 솔록/루나톤 두 자리를 고정합니다. 신규13대진 모두 개별 대사3단계·전술·도트·적합한 배경을 연결했습니다.','','[기계 판독 JSON](boss-roster.json) · [음원/ZIP 출처와 지문](https://github.com/agree-git/pokemon-deckbuilder/blob/main/assets/audio/boss_music/manifest.json) · [스프라이트 출처](https://github.com/agree-git/pokemon-deckbuilder/blob/main/assets/sources/trainer_sprites.json)','']
 for role in rosters:
  lines += ['## '+roles[role]+' · '+str(len(rosters[role]))+'대진','','| 지방 | 이름 | 역할 키 | 적용 파티(마지막 대표) | 배정 녹음 | 비고 |','|---|---|---|---|---|---|']
  for e in entries:
   if e['role']!=role:continue
   notes=[]
   if e['new_matchup']:notes.append('추가')
   if e['music_fallback']:notes.append('지역 공용')
   lines.append('| '+' | '.join([e['region'],e['name'],'`'+e['key']+'`',' · '.join(names[int(p)] for p in e['party']),', '.join(e['music']),' · '.join(notes)])+' |')
  lines.append('')
 (a.output_dir/'boss-roster.md').write_text('\n'.join(lines).rstrip()+'\n',encoding='utf-8')
if __name__=='__main__':main()
