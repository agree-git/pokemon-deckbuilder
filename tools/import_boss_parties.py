#!/usr/bin/env python3
"""Import the approved party review without rewriting historical route inputs."""
import argparse
import hashlib
import json
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game-dir',required=True,type=Path)
parser.add_argument('--review',type=Path,default=Path(__file__).resolve().parents[1]/'docs/boss-party-review.json')
args=parser.parse_args()
review=json.loads(args.review.read_text(encoding='utf-8'))
assert review['status'] in ['approved_for_application','applied']
entries={}
for row in review['entries']:
    party=row['proposed_party']
    assert len(party)==len(row['current_party']) and party[-len(row['fixed_aces']):]==row['fixed_aces']
    entries[row['key']]={'party':party,'fixed_aces':row['fixed_aces'],
                         'reference_game':row['reference']['game'],'reference_battle':row['reference']['battle'],
                         'reference_party':row['reference']['party'],'sources':row['reference']['sources'],
                         'supplemental_members':row['supplements']}
assert len(entries)==137
canonical={key:{'party':value['party'],'fixed_aces':value['fixed_aces']} for key,value in sorted(entries.items())}
digest=hashlib.sha256(json.dumps(canonical,sort_keys=True,separators=(',',':')).encode()).hexdigest()
output={'schema_version':1,'route_version':5,'approved_on':'2026-10-18',
        'spreadsheet_sha256':review['spreadsheet_sha256'],'reviewed_parties_sha256':digest,'entries':entries}
destination=args.game_dir/'data/boss_parties.json'
destination.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Imported {len(entries)} approved role parties; proposal SHA256 {digest}')
