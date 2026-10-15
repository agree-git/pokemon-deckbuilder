#!/usr/bin/env python3
"""Fetch four pinned, offline camp item sprites from PokeAPI/sprites."""
import json
import import_pokemon_assets as assets
ITEMS = {'potion': 'potion', 'super_potion': 'super-potion', 'revive': 'revive', 'ball': 'poke-ball'}
if __name__ == '__main__':
    try:
        for key, name in ITEMS.items():
            assets.fetch(f'{assets.RAW}/PokeAPI/sprites/{assets.SPRITES_REV}/sprites/items/{name}.png', f'assets/items/{key}.png', (30, 30))
        print(f'Fetched {len(ITEMS)} item sprites.')
    finally:
        assets.MANIFEST.write_text(json.dumps(dict(sorted(assets.records.items())), indent=2)+'\n', encoding='utf-8')
