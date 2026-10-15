#!/usr/bin/env python3
"""Build generation-three base stats for species 1..386 from pinned PokeAPI CSVs."""
import json
import import_pokemon_assets as assets

STAT_NAMES = {1: 'hp', 2: 'attack', 3: 'defense', 4: 'special_attack',
              5: 'special_defense', 6: 'speed'}


def main():
    species = {str(i): {} for i in range(1, 387)}
    for row in assets.table('pokemon_stats'):
        sid, stat = int(row['pokemon_id']), int(row['stat_id'])
        if 1 <= sid <= 386 and stat in STAT_NAMES:
            species[str(sid)][STAT_NAMES[stat]] = int(row['base_stat'])
    # generation_id is the LAST generation for which the historical value applied.
    # Select the earliest such boundary >= 3 independently for every stat.
    boundaries = {}
    for row in assets.table('pokemon_stats_past'):
        sid, stat, generation = (int(row[key]) for key in
                                 ['pokemon_id', 'stat_id', 'generation_id'])
        key = (sid, stat)
        if 1 <= sid <= 386 and stat in STAT_NAMES and generation >= 3:
            if key not in boundaries or generation < boundaries[key]:
                boundaries[key] = generation
                species[str(sid)][STAT_NAMES[stat]] = int(row['base_stat'])
    assert len(species) == 386
    assert all(set(row) == set(STAT_NAMES.values()) and min(row.values()) >= 1
               for row in species.values())
    assert species['25']['defense'] == 30  # Pikachu before the Gen VI buff.
    assert species['26']['speed'] == 100  # Raichu before the Gen VI buff.
    assert species['292']['hp'] == 1
    output = {'generation': 3, 'iv': 31, 'ev': 0, 'nature': 'neutral', 'species': species}
    (assets.ROOT / 'data/base_stats.json').write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Built Gen III base stats for {len(species)} species.')


if __name__ == '__main__':
    try:
        main()
    finally:
        assets.MANIFEST.write_text(json.dumps(dict(sorted(assets.records.items())), indent=2) + '\n', encoding='utf-8')
