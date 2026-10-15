#!/usr/bin/env python3
"""Build the modern 18-type chart from the catalog's pinned PokéAPI revision."""
import json
from import_pokemon_assets import ROOT, MANIFEST, records, table


def main():
    try:
        types = {int(row['id']): row['identifier'] for row in table('types') if int(row['id']) <= 18}
        chart = {key: {} for key in types.values()}
        for row in table('type_efficacy'):
            attack, defend = int(row['damage_type_id']), int(row['target_type_id'])
            if attack in types and defend in types:
                chart[types[attack]][types[defend]] = int(row['damage_factor']) / 100
        assert len(chart) == 18 and all(len(row) == 18 for row in chart.values())
        (ROOT / 'data/type_chart.json').write_text(json.dumps(chart, indent=2) + '\n')
    finally:
        MANIFEST.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
