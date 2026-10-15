#!/usr/bin/env python3
"""Fetch pinned, offline medicine and evolution material sprites from PokeAPI/sprites."""
import json
import import_pokemon_assets as assets
ITEMS = {'potion': 'potion', 'super_potion': 'super-potion', 'revive': 'revive', 'ball': 'poke-ball'}
ITEMS.update({key: key.replace('_', '-') for key in [
    'fire_stone', 'water_stone', 'thunder_stone', 'leaf_stone', 'moon_stone', 'sun_stone',
    'linking_cord', 'kings_rock', 'metal_coat', 'dragon_scale', 'upgrade', 'deep_sea_tooth', 'deep_sea_scale']})
# The pinned item set predates Linking Cord. Reuse its rope icon without relabeling the source.
ITEMS['linking_cord'] = 'escape-rope'
ITEMS['upgrade'] = 'up-grade'
# A blue shard represents the expedition's simplified blue Pokeblock.
ITEMS['blue_pokeblock'] = 'blue-shard'
if __name__ == '__main__':
    try:
        for key, name in ITEMS.items():
            assets.fetch(f'{assets.RAW}/PokeAPI/sprites/{assets.SPRITES_REV}/sprites/items/{name}.png', f'assets/items/{key}.png', (30, 30))
        print(f'Fetched {len(ITEMS)} item sprites.')
    finally:
        assets.MANIFEST.write_text(json.dumps(dict(sorted(assets.records.items())), indent=2)+'\n', encoding='utf-8')
