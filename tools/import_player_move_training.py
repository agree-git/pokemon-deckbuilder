#!/usr/bin/env python3
"""Generate four v22 self-stat overlays without changing published definitions."""
import argparse, csv, hashlib, json
from pathlib import Path

RULES = {
    'acupressure': ('random', {}, '최고 단계가 아닌 공격·방어·특공·특방·스피드 중 무작위 하나 +2 · 명중/회피 단계 제외 · 사용 시에만 추첨'),
    'power-shift': ('shift', {}, '자신 공격↔방어 및 특공↔특방의 전투 능력치 교환 · 능력 단계/HP/스피드 유지 · 재사용 시 되돌림 · 교대/전투 종료 시 해제'),
    'victory-dance': ('dance', {'attack': 1, 'defense': 1, 'speed': 1}, '공격·방어·스피드 각 +1 · 스칼렛/바이올렛 기준 · 별도 회피/행동 순서 없음'),
    'shelter': ('shelter', {'defense': 2}, '방어 +2 · 스칼렛/바이올렛 기준 · 레전드 아르세우스의 회피 효과는 사용하지 않음'),
}

def generate(game, csv_dir):
    base_path = game/'data/player_move_cards_v10.json'
    assert hashlib.sha256(base_path.read_bytes()).hexdigest() == 'cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255'
    base = json.loads(base_path.read_text())
    prior_path = game/'data/player_move_reactions_v20.json'
    assert hashlib.sha256(prior_path.read_bytes()).hexdigest() == 'ffd3bfb2485c4e61790d0e2ee09629b079dbeb72e9305aebb9a6d49e7b03b283'
    prior = json.loads(prior_path.read_text())
    for name, expected in prior['source']['csv_sha256'].items():
        assert hashlib.sha256((csv_dir/name).read_bytes()).hexdigest() == expected, name
    ids = {r['identifier']: r['id'] for r in csv.DictReader((csv_dir/'moves.csv').open())}
    moves = {}
    for name, (rule, changes, note) in RULES.items():
        key = ids[name]
        v = json.loads(json.dumps(base['moves'][key]))
        assert v.pop('block') == 5
        v.update(training_rule=rule, card_notes=[note], upgrade={'cost': max(0, v['cost']-1)})
        if changes:
            v.update(stat_changes=changes, stat_target='self')
        moves[key] = v
    return {'schema_version': 1, 'route_version': 22, 'player_moves_version': 14,
            'base_sha256': hashlib.sha256(prior_path.read_bytes()).hexdigest(),
            'source': prior['source'], 'references': [f'https://bulbapedia.bulbagarden.net/wiki/{name.replace("-", "_").title()}_(move)' for name in RULES],
            'moves': moves, 'total_enhanced': prior['total_enhanced']+len(moves)}

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game-dir', type=Path, required=True)
    p.add_argument('--csv-dir', type=Path, required=True)
    a = p.parse_args()
    result = generate(a.game_dir, a.csv_dir)
    (a.game_dir/'data/player_move_training_v22.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(len(result['moves']), 'overlays;', result['total_enhanced'], 'enhanced total')
