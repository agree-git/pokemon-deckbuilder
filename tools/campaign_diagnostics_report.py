"""Validate optional battle snapshots and summarize failure/long boss evidence."""
from collections import defaultdict
from statistics import mean


def validate_diagnostics(row):
    if 'battle_diagnostics' not in row:
        return
    battles = row['battle_diagnostics']
    expected = row['wins'] + (row['phase'] == 'failed')
    if not isinstance(battles, list) or len(battles) != expected:
        raise ValueError('Battle diagnostics must cover every completed battle')

    def integer(value, minimum=0):
        return type(value) is int and value >= minimum

    def members(values, enemies=False):
        if not isinstance(values, list) or not 1 <= len(values) <= (6 if enemies else 3):
            raise ValueError('Invalid diagnostic party size')
        uids = set()
        for p in values:
            if (not isinstance(p, dict) or not integer(p.get('species'), 1) or p['species'] > 386
                    or not integer(p.get('level'), 1) or p['level'] > 100
                    or not integer(p.get('max_hp'), 1) or not integer(p.get('hp')) or p['hp'] > p['max_hp']
                    or type(p.get('uid')) is not int or (p['uid'] >= 0 if enemies else p['uid'] <= 0)
                    or p['uid'] in uids or not isinstance(p.get('skills'), list)
                    or len(p['skills']) > 4 or any(not isinstance(key, str) for key in p['skills'])):
                raise ValueError('Invalid diagnostic Pokemon state')
            uids.add(p['uid'])

    for index, b in enumerate(battles):
        kind = ('wild' if index % 8 < 5 else ('trainer', 'veteran', 'gym')[index % 8 - 5]) if index < 64 else ('elite' if index < 68 else 'champion')
        if (not isinstance(b, dict) or b.get('step') != index * 2 or b.get('kind') != kind
                or not isinstance(b.get('place'), str) or not b['place']
                or b.get('outcome') != ('won' if index < row['wins'] else 'lost')
                or not integer(b.get('turns'), 1)
                or any(not integer(b.get(key)) for key in ('deck_size', 'living_cards', 'direct_cards', 'fallback_cards'))
                or not 0 <= b['fallback_cards'] <= b['direct_cards'] <= b['living_cards'] <= b['deck_size']):
            raise ValueError('Invalid diagnostic battle order, outcome or deck counts')
        members(b.get('party_before'))
        members(b.get('party_after'))
        members(b.get('opponents_after'), True)
        before, after = b['party_before'], b['party_after']
        if any([p['uid'], p['species'], p['level'], p['skills']] != [q['uid'], q['species'], q['level'], q['skills']]
               for p, q in zip(before, after)) or len(before) != len(after):
            raise ValueError('Diagnostic snapshots must precede XP and evolution settlement')
        if b['outcome'] == 'lost' and any(p['hp'] for p in after):
            raise ValueError('Defeat must be a real party wipe')
        foes = b.get('coverage')
        if not isinstance(foes, list) or len(foes) != len(b['opponents_after']):
            raise ValueError('Missing diagnostic opponent coverage')
        for foe, state in zip(foes, b['opponents_after']):
            if (not isinstance(foe, dict) or any(foe.get(key) != state[key] for key in ('species', 'level'))
                    or any(not integer(foe.get(key)) for key in ('attack', 'immune', 'conditional', 'strong'))
                    or foe['attack'] + foe['immune'] != b['direct_cards']
                    or foe['strong'] > foe['attack'] or foe['conditional'] > b['living_cards']):
                raise ValueError('Inconsistent diagnostic type coverage')
        if (not isinstance(b.get('cards'), dict) or any(not integer(n) for n in b['cards'].values())
                or not isinstance(b.get('counts'), dict)
                or any(not integer(b['counts'].get(key)) for key in ('damage_taken', 'knockouts'))):
            raise ValueError('Invalid diagnostic counters')
    for key in ('turns', 'damage_taken', 'knockouts'):
        total = sum(b['turns'] if key == 'turns' else b['counts'][key] for b in battles)
        if total != row[key]:
            raise ValueError(f'Diagnostic {key} does not match run total')


def format_diagnostics(rows, parties, styles, camps, recruitment, names):
    measured = [row for row in rows if 'battle_diagnostics' in row]
    if not measured:
        return []
    groups = defaultdict(list)
    for row in measured:
        groups[row['party'], row['style'], row['camp_policy'], row.get('recruitment', 'off')].append(row)
    lines = ['## 전투별 진단', '',
             f'{len(rows)}개 중 진단을 켠 {len(measured)}개 원정만 집계한다. 출전 전 파티·실제 생존 소유자의 카드·상대별 상성과 정산 전 HP·사용 카드를 보관한다. '
             '공격 장수는 실제 사본 수이며 피해량·손패 운·승리 가능성을 뜻하지 않는다. 발버둥도 직접 공격에 포함한다. '
             '기절 후 XP 손실과 이후 성장의 관계는 개별 전투 기록으로 확인하며 이 표만으로 원인을 단정하지 않는다.', '',
             '| 편성 / 보상 | 야영지 / 영입 | 표본 | 완주 | 첫 관장 전 / 첫 관장 / 이후 전멸 | 첫 전투 평균 턴 | 첫 덱 발버둥 / 직접 공격 |',
             '|---|---|---:|---:|---|---:|---|']
    for (party, style, camp, mode), group in groups.items():
        failed = [r for r in group if r['phase'] == 'failed']
        stages = [sum(r['wins'] < 7 for r in failed), sum(r['wins'] == 7 for r in failed), sum(r['wins'] > 7 for r in failed)]
        first = [r['battle_diagnostics'][0] for r in group]
        lines.append(f"| {parties[party]} / {styles[style]} | {camps[camp]} / {recruitment[mode]} | {len(group)} | "
                     f"{sum(r['phase'] == 'cleared' for r in group)} | {' / '.join(map(str, stages))} | "
                     f"{mean(b['turns'] for b in first):.1f} | {mean(b['fallback_cards'] for b in first):.1f} / {mean(b['direct_cards'] for b in first):.1f} |")
    bosses = [(r, b) for r in measured for b in r['battle_diagnostics'] if b['kind'] in ('gym', 'elite', 'champion')]
    lines += ['', '진단 표본에서 가장 긴 보스전 최대 10개다. 승리·패배를 함께 표시하며 원정별 최장 기록만 고르는 표가 아니다.', '',
              '| 편성 / 시드 / 영입 | 장소 | 결과 | 턴 | 시작 파티 Lv. / HP | 시작 발버둥 / 직접 공격 |',
              '|---|---|---|---:|---|---|']
    for row, b in sorted(bosses, key=lambda pair: -pair[1]['turns'])[:10]:
        members = ' · '.join(f"{names[p['species']]} {p['level']} / {p['hp']}:{p['max_hp']}" for p in b['party_before'])
        lines.append(f"| {parties[row['party']]} / {row['seed']} / {recruitment[row.get('recruitment', 'off')]} | {b['place']} | "
                     f"{'승리' if b['outcome'] == 'won' else '패배'} | {b['turns']} | {members} | {b['fallback_cards']} / {b['direct_cards']} |")
    return lines + ['']
