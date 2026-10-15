#!/usr/bin/env python3
"""Combine completed campaign measurements into a reproducible JSON/Markdown report."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
PARTIES = {
    'kanto': '관동 기본', 'johto': '성도 기본', 'hoenn': '호연 기본', 'bugs': '벌레',
    'babies': '아기', 'psychic': '보조형 에스퍼', 'slow': '저속 물리', 'ghost': '고스트',
    'water': '물 보조형', 'mixed': '이브이·배루키·루브도', 'sublegend': '준전설 포함',
    'mythical': '환상 포함', 'superlegend': '초전설 포함', 'solo': '이상해씨 단독',
    'solo_fish': '잉어킹 단독',
}
STYLES = {'baseline': '기존 기준', 'relay': '교대', 'ace': '에이스', 'status': '상태',
          'shield': '보호막', 'supply': '도구'}


def load_reports(paths):
    report = None
    rows = []
    seen = set()
    for path in paths:
        data = json.loads(path.read_text())
        if data.get('version') != 1 or not isinstance(data.get('rows'), list) or not data['rows']:
            raise ValueError(f'{path}: missing version or measurements')
        if report is None:
            report = {key: data[key] for key in ('version', 'engine', 'ruleset', 'rules_fingerprint', 'policy', 'scope')}
        elif any(report[key] != data.get(key) for key in ('engine', 'ruleset', 'rules_fingerprint', 'policy', 'scope')):
            raise ValueError(f'{path}: measurements use different engine, rules or policies')
        for row in data['rows']:
            identity = (row['party'], row['style'], row['seed'])
            if identity in seen:
                raise ValueError(f'{path}: duplicate measurement {identity}')
            seen.add(identity)
            if row['phase'] not in ('cleared', 'failed') or row['error'] or row['incomplete'] or not row['statistics_valid']:
                raise ValueError(f'{path}: incomplete or invalid measurement {identity}')
            if not (0 <= row['wins'] <= 69) or (row['phase'] == 'cleared' and row['wins'] != 69):
                raise ValueError(f'{path}: inconsistent victory count {identity}')
            for key in ('turns', 'actions', 'damage_taken', 'knockouts', 'gold_spent', 'deck_size'):
                if type(row[key]) is not int or row[key] < 0:
                    raise ValueError(f'{path}: invalid metric {key} for {identity}')
            rows.append(row)
    report['rows'] = rows
    return report


def format_report(report):
    catalog = json.loads((ROOT/'data/catalog.json').read_text())['pokemon']
    names = {entry['id']: entry['name'] for entry in catalog}
    groups = defaultdict(list)
    for row in report['rows']:
        groups[(row['party'], row['style'])].append(row)
    lines = ['# 스타팅·빌드 원정 측정', '',
             f"엔진: `{report['engine']}` · 규칙: `{report['ruleset']}` · {len(report['rows'])}개 원정.", '']
    lines += [f"코드·데이터 지문: `{report['rules_fingerprint']}`.", '']
    if report.get('rules_revision'):
        lines += [f"전투 규칙 기준 커밋: `{report['rules_revision']}`.", '']
    lines += ['## 측정 조건', '',
              '같은 시드·같은 전투/기술 선택 정책으로 비교한다. HP·경험치·골드·카드·유물·에너지를 직접 바꾸지 않고 공개 행동만 사용한다. '
              '기존 기준은 매 야영지에서 휴식·장비·일반 회복약을 사용한다. 다른 전략은 같은 정책에 선호 주제의 보상·상점 구매와 야영지 만남 선택을 더한다. '
              '카드·유물을 강제로 지급하지 않는다.', '',
              '**포획·희귀 조우·진화 재료 구매·카드 강화/제거는 사용하지 않는다.** '
              '단독/보조형 편성도 동료를 영입하지 않는 조건이다. 희귀 포함 편성은 이미 포획하여 해금한 계정을 가정한다. '
              '이 정책의 결과이며 사람의 승률이나 모든 파티·모든 빌드의 균형을 뜻하지 않는다.', '',
              '## 파티별 기존 기준', '',
              '| 편성 | 포켓몬 | 시드 | 완주 | 승리 전투 수 | 완주한 원정의 평균 턴 |',
              '|---|---|---|---:|---|---:|']
    for (party, style), rows in groups.items():
        if style != 'baseline':
            continue
        cleared = [row for row in rows if row['phase'] == 'cleared']
        seeds = ', '.join(str(row['seed']) for row in rows)
        wins = ', '.join(str(row['wins']) for row in rows)
        turns = f"{mean(row['turns'] for row in cleared):.1f}" if cleared else '—'
        members = '·'.join(names[value] for value in rows[0]['starters'])
        lines.append(f"| {PARTIES.get(party, party)} | {members} | {seeds} | {len(cleared)}/{len(rows)} | {wins} | {turns} |")
    lines += ['', '## 같은 파티의 전략별 선택', '',
              '턴·피해·기절·지출·덱은 해당 묶음의 모든 원정 평균이다. 서로 다른 파티끼리 승패를 섞어 비교하지 않는다. '
              '지출은 카드·일반 보급·만남을 합산한다. 시작 때 쓰는 공용 카드도 전체 덱 크기에 포함한다.', '',
              '| 파티 | 선호 전략 | 완주 | 평균 턴 | 받은 HP 피해 | 기절 | 골드 지출 | 최종 덱 |',
              '|---|---|---:|---:|---:|---:|---:|---:|']
    varied = {party for party, style in groups if style != 'baseline'}
    for (party, style), rows in groups.items():
        if party not in varied:
            continue
        clears = sum(row['phase'] == 'cleared' for row in rows)
        metrics = [f"{mean(row[key] for row in rows):.1f}" for key in ('turns', 'damage_taken', 'knockouts', 'gold_spent', 'deck_size')]
        lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} | {clears}/{len(rows)} | " + ' | '.join(metrics) + ' |')
    lines.append('')
    for party in dict.fromkeys(party for party, style in groups if style != 'baseline'):
        measured = [row for row in report['rows'] if row['party'] == party]
        relic_sets = {tuple(sorted(row['relics'])) for row in measured}
        if len(relic_sets) == 1:
            lines += [f"{PARTIES.get(party, party)} {len(measured)}개 측정은 최종 유물 {len(next(iter(relic_sets)))}종의 구성이 같았다. "
                      '유물을 우선하는 정책의 영향과 작은 공용 유물 풀의 수렴 양상을 다음 콘텐츠 조정에서 함께 검토한다.', '']
    lines += ['## 해석 범위', '',
              '- 세 시드의 작은 표본이다. 자동 전투 정책이 특정 기술·상태·교대를 더 선호하며 전략별 최적 플레이를 구현한 것은 아니다.',
              '- 보조형·아기·단독 편성의 초반 탈락은 원작 능력치/기술과 영입을 하지 않는 조건의 영향을 함께 받는다. 종족값이나 관장 레벨을 즉시 일괄 조정할 근거로 쓰지 않는다.',
              '- 스타팅 화면의 출발 덱·Lv.5 능력치 미리보기로 실제 공격 카드와 발버둥 여부를 알린다. 초기 기술·진화·희귀 포획 조건을 바꾸지 않는다.',
              '- 다음 비교에서는 초반 포획, 진화 재료, 강화/제거와 휴식 선택, 더 많은 시드, 수동 플레이를 함께 다룬다.', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', type=Path, nargs='+')
    parser.add_argument('--json', type=Path, required=True)
    parser.add_argument('--markdown', type=Path, required=True)
    parser.add_argument('--revision', help='Commit of the measured battle rules')
    args = parser.parse_args()
    try:
        report = load_reports(args.inputs)
        if args.revision:
            report['rules_revision'] = args.revision
        text = format_report(report)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f'Measurement error: {error}\n')
    for target, contents in ((args.json, json.dumps(report, ensure_ascii=False, indent=2)+'\n'),
                             (args.markdown, text)):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)
    print(f"Saved {len(report['rows'])} completed measurements to {args.markdown}")


if __name__ == '__main__':
    main()
