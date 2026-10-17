#!/usr/bin/env python3
"""Verify included trainer pixels offline; --fetch restores exact pinned upstream bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'assets/sources/trainer_sprites.json').read_text())
    gyms = json.loads((ROOT / 'data/gym_leaders.json').read_text())['leaders']
    league = json.loads((ROOT / 'data/league.json').read_text())
    expected = {f'{role}:{p.get("leader_id", p.get("id"))}'
                for role, pool in [('gym', gyms), ('elite', league['elite']), ('champion', league['champions'])]
                for p in pool}
    assert set(manifest['entries']) == expected, 'Roster mapping drift'
    referenced = {e['path'] for e in manifest['entries'].values() if e['status'] == 'included'}
    assert referenced == set(manifest['assets']), 'Orphan or missing sprite'
    for local, source in manifest['assets'].items():
        target = ROOT / local
        assert source['url'] == f'https://raw.githubusercontent.com/smogon/sprites/{manifest["commit"]}/{source["upstream_path"]}'
        assert '/canonical/trainers/' in source['upstream_path']
        if args.fetch:
            data = urllib.request.urlopen(source['url'], timeout=30).read()
            assert hashlib.sha256(data).hexdigest() == source['sha256'], local
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        data = target.read_bytes()
        assert hashlib.sha256(data).hexdigest() == source['sha256'], local
        assert data[:8] == b'\x89PNG\r\n\x1a\n', local
        width, height = struct.unpack('>II', data[16:24])
        assert [width, height] == source['size'], local
        x, y, w, h = source['bounds']
        assert w > 0 and h > 0 and x >= 0 and y >= 0 and x+w <= width and y+h <= height, local
    count = sum(e['status'] == 'included' for e in manifest['entries'].values())
    print(f'TRAINER_SPRITES: {len(expected)} rosters; {count} included, {len(expected)-count} explicit fallbacks; {len(referenced)} pinned PNGs verified')


if __name__ == '__main__':
    main()
