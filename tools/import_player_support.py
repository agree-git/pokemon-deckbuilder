#!/usr/bin/env python3
"""Generate v25 conditional support overlays; original engine/data stay frozen."""
import argparse, hashlib, json
from pathlib import Path

BASES = {'data/player_move_cards_v10.json':'cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255', 'data/player_move_interactions_v24.json':'9cda3ca64e304c33c24777c90ed83b54a3e897db4d3e17d7ae1b51bc70003341'}
RULES = {
    74:('growth','쾌청이면 공격/특공+2 · 그 외 +1'),
    563:('till','양쪽 출전 중 접지한 풀 타입 공격/특공+1 · 대타/보호와 무관'),
    579:('flower','양쪽 출전 중 풀 타입 방어+1 · 대타/보호와 무관'),
    597:('mist','살아 있는 다른 동료 전원 특방+1 · 적은 강화하지 않음'),
    599:('venom','독 상태인 상대만 공격/특공/스피드-1 · 보호/대타/흰안개/클리어참 적용'),
    602:('flux','특성 대신 살아 있는 전기/강철 동료 전원 방어/특방+1 · 자신 포함'),
    674:('gear','특성 대신 살아 있는 전기/강철 동료 전원 공격/특공+1 · 자신 포함'),
    777:('decorate','살아 있는 다른 동료 전원 공격/특공+2 · 적은 강화하지 않음'),
    811:('coach','살아 있는 다른 동료 전원 공격/방어+1 · 자신 제외'),
}
CHANGES = {'till':{'attack':1,'special_attack':1}, 'flower':{'defense':1}, 'mist':{'special_defense':1}, 'flux':{'defense':1,'special_defense':1}, 'gear':{'attack':1,'special_attack':1}, 'decorate':{'attack':2,'special_attack':2}, 'coach':{'attack':1,'defense':1}}
POWDER = [77,78,79,147,178,600,750]
def generate(game):
    for name,sha in BASES.items():assert hashlib.sha256((game/name).read_bytes()).hexdigest()==sha,name
    moves={str(id):{'support_rule':tag,'card_notes':[note], **({'support_changes':CHANGES[tag]} if tag in CHANGES else {})} for id,(tag,note) in RULES.items()}
    for id in POWDER:
        moves[str(id)]={'card_notes':['가루/포자 기술 · 풀 타입에게 무효 · 미리보기와 양쪽 실행에 적용']}
    return {'schema_version':1,'route_version':25,'player_moves_version':17,'base_sha256':BASES,'source':{'repository':'smogon/pokemon-showdown','commit':'7b02eb39878f4b486f658a752b38c161379bd352','path':'data/moves.ts','sha256':'61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7','license':'licenses/pokemon-showdown-MIT.txt'},'powder':POWDER,'moves':moves}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    result=generate(a.game_dir);(a.game_dir/'data/player_move_support_v25.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(len(result['moves']),'support/powder overlays')
