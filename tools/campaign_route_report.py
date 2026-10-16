"""Read-only route provenance; old reports remain explicitly unrecorded."""
import re

TYPES = {'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground',
         'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy'}
BOSS_STEPS = list(range(14, 127, 16)) + [128, 130, 132, 134, 136]


def validate_route(row, version):
    route = row.get('route')
    if version is None:
        if 'route' in row:
            raise ValueError('Route evidence needs an explicit report route version')
        return
    if (not isinstance(route, dict) or type(route.get('version')) is not int
            or route['version'] != version or not isinstance(route.get('signature'), str)
            or not re.fullmatch(r'[0-9a-f]{64}', route['signature'])):
        raise ValueError('Missing or inconsistent route provenance')
    bosses = route.get('bosses')
    if not isinstance(bosses, list) or len(bosses) != 13:
        raise ValueError('Route evidence must contain eight gyms, four elite and one champion')
    ids = set()
    for index, (boss, step) in enumerate(zip(bosses, BOSS_STEPS)):
        kind = 'gym' if index < 8 else ('elite' if index < 12 else 'champion')
        size = 5 if kind == 'elite' else 6
        if (not isinstance(boss, dict) or type(boss.get('step')) is not int or boss['step'] != step
                or boss.get('kind') != kind
                or any(not isinstance(boss.get(key), str) or not boss[key] for key in ('id', 'name', 'type'))
                or boss['type'] not in TYPES or not isinstance(boss.get('region'), str)
                or type(boss.get('level')) is not int or not 1 <= boss['level'] <= 100
                or (kind == 'champion' and boss['level'] != 100)
                or not isinstance(boss.get('party'), list) or len(boss['party']) != size
                or any(type(species) is not int or not 1 <= species <= 386 for species in boss['party'])
                or len(set(boss['party'])) != size or boss['id'] in ids):
            raise ValueError('Invalid planned boss identity, stage or roster')
        ids.add(boss['id'])
    planned = {boss['step']: boss for boss in bosses}
    for battle in row.get('battle_diagnostics', []):
        if battle.get('step') not in planned:
            continue
        boss = planned[battle['step']]
        states = battle.get('opponents_after', [])
        if (battle.get('kind') != boss['kind'] or battle.get('place') != boss['name']
                or [p['species'] for p in states] != boss['party']
                or any(p['level'] != boss['level'] for p in states)):
            raise ValueError('Actual boss diagnostics disagree with the planned route')


def format_first_gyms(rows, parties, recruitment):
    measured = [row for row in rows if 'route' in row and 'battle_diagnostics' in row]
    if not measured:
        return []
    lines = ['## 새 대진의 첫 관장 도달', '',
             '예정 대진과 실제 도달 결과를 나눈다. 도달 전 전멸을 관장에게 패배한 것으로 세지 않는다. '
             '같은 시드의 예정 대진은 편성과 영입 정책이 달라도 같아야 한다.', '',
             '| 편성 / 시드 / 영입 | 예정 첫 관장 | 타입 / Lv. | 실제 결과 | 턴 |',
             '|---|---|---|---|---:|']
    for row in measured:
        boss = row['route']['bosses'][0]
        fought = next((battle for battle in row['battle_diagnostics'] if battle['step'] == boss['step']), None)
        outcome = ('승리' if fought['outcome'] == 'won' else '패배') if fought else '도달 전 전멸'
        lines.append(f"| {parties[row['party']]} / {row['seed']} / {recruitment[row.get('recruitment', 'off')]} | "
                     f"{boss['name']} (`{boss['id']}`) | {boss['type']} / {boss['level']} | {outcome} | "
                     f"{fought['turns'] if fought else '—'} |")
    return lines + ['']
