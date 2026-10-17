#!/usr/bin/env python3
"""Verify included trainer pixels offline; --fetch restores exact pinned upstream bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import urllib.request
import re

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    parser.add_argument('--game-root', type=Path, default=ROOT, help='Current main checkout to validate')
    parser.add_argument('--credits-index', type=Path, default=ROOT / 'assets/sources/trainer_gallery_credits.php.txt')
    parser.add_argument('--expected-included', type=int)
    args = parser.parse_args()
    root = args.game_root.resolve()
    manifest = json.loads((root / 'assets/sources/trainer_sprites.json').read_text())
    gyms = json.loads((root / 'data/gym_leaders.json').read_text())['leaders']
    league = json.loads((root / 'data/league.json').read_text())
    expected = {f'{role}:{p.get("leader_id", p.get("id"))}'
                for role, pool in [('gym', gyms), ('elite', league['elite']), ('champion', league['champions'])]
                for p in pool}
    assert set(manifest['entries']) == expected, 'Roster mapping drift'
    referenced = {e['path'] for e in manifest['entries'].values() if e['status'] == 'included'}
    assert referenced == set(manifest['assets']), 'Orphan or missing sprite'
    for local, source in manifest['assets'].items():
        target = root / local
        repository = source.get('source_repository', manifest['source'])
        commit = source.get('source_commit', manifest['commit'])
        assert (repository, commit) in {
            ('https://github.com/smogon/sprites', manifest['commit']),
            ('https://github.com/SDM0/sprites', 'b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f'),
        }, 'Unreviewed sprite source'
        slug = repository.removeprefix('https://github.com/')
        assert source['url'] == f'https://raw.githubusercontent.com/{slug}/{commit}/{source["upstream_path"]}'
        if source.get('kind', 'canonical') == 'fan':
            if repository == 'https://github.com/smogon/sprites':
                assert '/noncanonical/trainers/' in source['upstream_path']
            else:
                assert source['upstream_path'] == 'sprites/trainers/' + source['gallery_file']
            proof = args.credits_index.read_bytes()
            assert hashlib.sha256(proof).hexdigest() == source['credit_source_sha256']
            credits = dict(re.findall(r'"([^"]+\.png)"\s*=>\s*"([^"]+)"', proof.decode()))
            assert credits[source['gallery_file']] == source['artist'], local
            assert 'Credit must be given' in source['usage_notice']
            assert 'DO NOT EDIT without permission.' in source['usage_notice']
            assert source['credit_source'] == 'https://github.com/smogon/pokemon-showdown-client/blob/74056bbbb55d6ce15f9dd254186b94a51fe94b14/play.pokemonshowdown.com/sprites/trainers/index.php'
        else:
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
    if args.expected_included is not None:
        assert count == args.expected_included, (count, args.expected_included)
    print(f'TRAINER_SPRITES: {len(expected)} rosters; {count} included, {len(expected)-count} explicit fallbacks; {len(referenced)} pinned PNGs verified')


if __name__ == '__main__':
    main()
