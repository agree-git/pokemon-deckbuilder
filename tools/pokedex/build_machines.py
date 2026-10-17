#!/usr/bin/env python3
"""Extract actual machine compatibility from each Pokemon's selected learnset version."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game-dir', type=Path, required=True)
parser.add_argument('--cache-dir', type=Path, required=True)
args = parser.parse_args()
content = json.loads((args.game_dir / 'data/pokedex_expansion.json').read_text())
source = args.cache_dir / 'csv/pokemon_moves.csv'
source_metadata = content['csv_sources']['pokemon_moves']
expected = source_metadata['sha256']
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected
by_source = {}
for entry in content['learnset_sources'].values():
    by_source[(entry['pokemon_id'], entry['version_group'])] = set()
with source.open() as file:
    for row in csv.DictReader(file):
        key = (int(row['pokemon_id']), int(row['version_group_id']))
        move = int(row['move_id'])
        if row['pokemon_move_method_id'] == '4' and key in by_source and str(move) in content['move_definitions']:
            by_source[key].add(move)
compatibility = {id: sorted(by_source[(entry['pokemon_id'], entry['version_group'])])
                 for id, entry in content['learnset_sources'].items()}
result = {'schema_version': 1, 'source_sha256': expected, 'source_url': source_metadata['url'],
          'source_method': 4, 'compatibility': compatibility}
(args.game_dir / 'data/technical_machines.json').write_text(
    json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'{len(compatibility)} Pokemon / {len(set().union(*map(set, compatibility.values())))} machine moves')
