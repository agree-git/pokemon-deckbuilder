#!/usr/bin/env python3
"""Build one offline HTML file from the game's unchanged PNGs and floor data."""
import argparse
import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return json.loads((ROOT / 'data' / f'{name}.json').read_text())


def payload():
    layout, catalog, backdrops, league = map(read, ['battlefield_layouts', 'catalog', 'battle_backdrops', 'league'])
    types = {row['key']: row['name'] for row in catalog['types']}
    rooms = []
    for biome in read('biomes'):
        rooms.append(dict(group='바이옴', title=f"{types[biome['type']]} · {biome['name']}",
                          background=biome['background'], cell=biome['cell'], ally=2,
                          enemy=biome['encounters'][0]['pokemon_id']))
    for type_key, room in backdrops['elite'].items():
        trainers = [t for t in league['elite'] if t['type'] == type_key]
        names = ' / '.join(t['name'] for t in trainers) or '예비 룸'
        rooms.append(dict(group='사천왕', title=f'{types[type_key]} · {names}', **room,
                          ally=3, enemy=trainers[0]['party'][0] if trainers else 1))
    champions = {t['id']: t for t in league['champions']}
    for key, room in backdrops['champions'].items():
        trainer = champions[key]
        rooms.append(dict(group='챔피언', title=f"{trainer['region']} · {trainer['name']}",
                          **room, ally=3, enemy=trainer['party'][0]))
    rooms.append(dict(group='챔피언', title='공용 리그 홀', **backdrops['fallback_champion'], ally=3, enemy=18))
    expected = {(path, cell) for path, cells in layout['backgrounds'].items() for cell in range(len(cells))}
    if len(rooms) != 48 or {(r['background'], r['cell']) for r in rooms} != expected:
        raise ValueError('Editor must cover every one of the 48 unique rooms')
    assets = {}
    paths = set(layout['backgrounds'])
    pokemon = []
    for species in catalog['pokemon']:
        pokemon.append({key: species[key] for key in ('id', 'name', 'front', 'back')})
        paths.update([species['front'], species['back']])
    for path in sorted(paths):
        content = (ROOT / path.removeprefix('res://')).read_bytes()
        assets[path] = 'data:image/png;base64,' + base64.b64encode(content).decode('ascii')
    return dict(layout=layout, rooms=rooms, pokemon=pokemon, assets=assets,
                layout_sha256=hashlib.sha256((ROOT / 'data/battlefield_layouts.json').read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    template = (ROOT / 'tools/battlefield_editor.html').read_text()
    encoded = json.dumps(payload(), ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')
    if template.count('__EDITOR_PAYLOAD__') != 1:
        raise ValueError('Missing or duplicate template payload slot')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(template.replace('__EDITOR_PAYLOAD__', encoded))
    print(f'{args.output}: {args.output.stat().st_size:,} bytes; 48 rooms, 386 species, no external assets')


if __name__ == '__main__':
    main()
