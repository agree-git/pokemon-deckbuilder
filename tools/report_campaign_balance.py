#!/usr/bin/env python3
"""Combine completed campaign measurements into a reproducible JSON/Markdown report."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
from statistics import mean
from campaign_diagnostics_report import format_diagnostics, validate_diagnostics

ROOT = Path(__file__).resolve().parents[1]
PARTIES = {
    'kanto': '관동 기본', 'johto': '성도 기본', 'hoenn': '호연 기본', 'bugs': '벌레',
    'babies': '아기', 'psychic': '보조형 에스퍼', 'slow': '저속 물리', 'ghost': '고스트',
    'water': '물 보조형', 'mixed': '이브이·배루키·루브도', 'sublegend': '준전설 포함',
    'mythical': '환상 포함', 'superlegend': '초전설 포함', 'solo': '이상해씨 단독',
    'solo_fish': '잉어킹 단독',
}
CAMPS = {'rest': '매번 휴식', 'develop': '육성·덱 관리'}
RECRUITMENT = {'off': '영입 없음', 'early': '초반 영입'}
CORES = {'relay_core': '순환 엔진', 'ace_core': '고정 조준경', 'status_core': '침식 촉매',
         'shield_core': '잔류 방벽', 'supply_core': '비상 보급함'}
STYLES = {'baseline': '기존 기준', 'relay': '교대', 'ace': '에이스', 'status': '상태',
          'shield': '보호막', 'supply': '도구'}


def load_reports(paths):
    report = None
    catalog = json.loads((ROOT/'data/catalog.json').read_text())['pokemon']
    ordinary = {p['id'] for p in catalog if not p['is_legendary'] and not p['is_mythical']}
    rows = []
    seen = set()
    for path in paths:
        data = json.loads(path.read_text())
        if data.get('version') not in (1, 2) or not isinstance(data.get('rows'), list) or not data['rows']:
            raise ValueError(f'{path}: missing version or measurements')
        fields = ('version', 'engine', 'ruleset', 'rules_fingerprint', 'policy', 'scope')
        if data['version'] == 2:
            fields += ('stat_basis', 'limits')
            if data.get('stat_basis') != 'species-level-v1':
                raise ValueError(f'{path}: missing or unsupported stat basis')
            limits = data.get('limits')
            if not isinstance(limits, dict) or any(type(limits.get(key)) is not int or limits[key] <= 0 for key in ('battle_turns', 'actions')):
                raise ValueError(f'{path}: invalid measurement limits')
        if report is None:
            report = {key: data[key] for key in fields}
        elif any(report.get(key) != data.get(key) for key in fields):
            raise ValueError(f'{path}: measurements use different engine, rules or policies')
        for row in data['rows']:
            identity = (row['party'], row['style'], row['seed'], row.get('camp_policy', 'rest'), row.get('recruitment', 'off'))
            if 'core_relic' in row:
                core = row['core_relic']
                acquired = [key for key in row['relics'] if key in CORES]
                if core not in ('', *CORES) or acquired != ([] if core == '' else [core]):
                    raise ValueError(f'{path}: inconsistent exclusive core {identity}')
            if data['version'] == 2:
                if row.get('camp_policy') not in CAMPS:
                    raise ValueError(f'{path}: invalid camp policy {identity}')
                economy = row.get('economy')
                keys = ('rests', 'cards_upgraded', 'cards_removed', 'items_used',
                        'gold_cards', 'gold_supplies', 'gold_removal', 'gold_events')
                if not isinstance(economy, dict) or any(type(economy.get(key)) is not int or economy[key] < 0 for key in keys):
                    raise ValueError(f'{path}: invalid economy {identity}')
                if row['gold_spent'] != sum(economy[key] for key in keys[4:]):
                    raise ValueError(f'{path}: inconsistent spending {identity}')
                if economy['rests'] + economy['cards_upgraded'] > min(row['wins'], 68):
                    raise ValueError(f'{path}: too many camp actions {identity}')
            if 'recruitment' in row:
                mode = row['recruitment']
                catches, recruits = row.get('captures'), row.get('recruits')
                if (mode not in RECRUITMENT or not isinstance(catches, list) or not isinstance(recruits, list)
                        or len(catches) > (2 if mode == 'early' else 0) or len(recruits) != len(catches)
                        or type(row.get('balls_remaining')) is not int or row['balls_remaining'] < 0):
                    raise ValueError(f'{path}: invalid recruitment trace {identity}')
                previous = -1
                for catch, decision in zip(catches, recruits):
                    if (not isinstance(catch, dict) or not isinstance(decision, dict)
                            or type(catch.get('species')) is not int or type(catch.get('step')) is not int or catch['step'] not in (0, 2, 4, 6, 8)
                            or catch['step'] <= previous or catch.get('species') not in ordinary
                            or any(decision.get(key) != catch[key] for key in ('step', 'species'))
                            or type(decision.get('joined')) is not bool
                            or type(decision.get('replaced')) is not int
                            or decision['replaced'] not in range(387)
                            or (not decision['joined'] and decision['replaced'] != 0)):
                        raise ValueError(f'{path}: inconsistent recruitment decision {identity}')
                    previous = catch['step']
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
            validate_diagnostics(row)
            rows.append(row)
    report['rows'] = rows
    return report


def format_report(report):
    catalog = json.loads((ROOT/'data/catalog.json').read_text())['pokemon']
    names = {entry['id']: entry['name'] for entry in catalog}
    groups = defaultdict(list)
    for row in report['rows']:
        groups[(row['party'], row['style'], row.get('camp_policy', 'rest'), row.get('recruitment', 'off'))].append(row)
    recruiting = any(row.get('recruitment') == 'early' for row in report['rows'])
    def camp_label(camp, mode):
        return CAMPS[camp] + (' / ' + RECRUITMENT[mode] if recruiting else '')
    lines = ['# 스타팅·빌드 원정 측정', '',
             f"엔진: `{report['engine']}` · 규칙: `{report['ruleset']}` · {len(report['rows'])}개 원정.", '']
    lines += [f"코드·데이터 지문: `{report['rules_fingerprint']}`.", '']
    if report.get('rules_revision'):
        lines += [f"전투 규칙 기준 커밋: `{report['rules_revision']}`.", '']
    if report.get('stat_basis'):
        lines += [f"능력치 기준: `{report['stat_basis']}` — 개체값·노력치 없이 종족값과 레벨만 적용.", '']
        lines += [f"안전 제한: 전투당 {report['limits']['battle_turns']}턴 · 원정당 {report['limits']['actions']:,}행동. 제한에 걸린 미완료 결과는 합산하지 않는다.", '']
    lines += ['## 측정 조건', '',
              '같은 시드·같은 전투/기술 선택 정책으로 비교한다. HP·경험치·골드·카드·유물·에너지를 직접 바꾸지 않고 공개 행동만 사용한다. '
              '기존 기준은 매 야영지에서 휴식·장비·일반 회복약을 사용한다. 다른 전략은 같은 정책에 선호 주제의 보상·상점 구매와 야영지 만남 선택을 더한다. '
              '카드·유물을 강제로 지급하지 않는다.', '',
              ('`영입 없음`과 `초반 영입`을 구분한다. 초반 영입은 첫 지역 야생에서 최대 두 번, 실제 볼·에너지와 체력 25% 조건으로 포획한다. 희귀 조우는 사용하지 않는다. ' if recruiting else '**포획·희귀 조우는 사용하지 않는다.** 단독/보조형 편성도 동료를 영입하지 않는 조건이다. ')
              + '희귀 포함 편성은 이미 포획하여 해금한 계정을 가정한다. 이 정책의 결과이며 사람의 승률이나 모든 파티·모든 빌드의 균형을 뜻하지 않는다.', '',
              '야영지 `매번 휴식`은 이전 정책을 유지한다. `육성·덱 관리`는 만남을 해결하고 현재 쓸 수 있는 진화 재료를 구매·사용한다. '
              'HP 75% 미만·기절·미완료 친밀도 진화에는 휴식하고, 그 외에는 카드를 강화한다. 상인에게 낮게 평가한 보조 기술을 제거하며 '
              '공격·씨앗·회복 기술과 동료의 마지막 기술은 보존한다. 재료·제거·주제 카드 구매 후 100골드를 남긴다. '
              '재료는 먼저 사용 가능한 분기를 택하며 원작 기술표를 고려한 최적 진화 시점을 찾지는 않는다. '
              '전투·기술 학습 정책은 두 야영지 정책에서 같다. 이전 v1 측정에는 육성 정책이 없다.', '',
              '## 파티별 기존 기준', '',
              '| 편성 | 포켓몬 | 야영지 | 시드 | 완주 | 승리 전투 수 | 완주한 원정의 평균 턴 |',
              '|---|---|---|---|---:|---|---:|']
    for (party, style, camp, mode), rows in groups.items():
        if style != 'baseline':
            continue
        cleared = [row for row in rows if row['phase'] == 'cleared']
        seeds = ', '.join(str(row['seed']) for row in rows)
        wins = ', '.join(str(row['wins']) for row in rows)
        turns = f"{mean(row['turns'] for row in cleared):.1f}" if cleared else '—'
        members = '·'.join(names[value] for value in rows[0]['starters'])
        lines.append(f"| {PARTIES.get(party, party)} | {members} | {camp_label(camp, mode)} | {seeds} | {len(cleared)}/{len(rows)} | {wins} | {turns} |")
    lines += ['', '## 같은 파티의 전략별 선택', '',
              '턴·피해·기절·지출·덱은 해당 묶음의 모든 원정 평균이다. 서로 다른 파티끼리 승패를 섞어 비교하지 않는다. '
              '지출은 카드·일반 보급·만남을 합산한다. 시작 때 쓰는 공용 카드도 전체 덱 크기에 포함한다.', '',
              '| 파티 | 선호 전략 | 야영지 | 완주 | 평균 턴 | 받은 HP 피해 | 기절 | 골드 지출 | 최종 덱 |',
              '|---|---|---|---:|---:|---:|---:|---:|---:|']
    varied = {party for party, style, camp, mode in groups if style != 'baseline'}
    for (party, style, camp, mode), rows in groups.items():
        if party not in varied:
            continue
        clears = sum(row['phase'] == 'cleared' for row in rows)
        metrics = [f"{mean(row[key] for row in rows):.1f}" for key in ('turns', 'damage_taken', 'knockouts', 'gold_spent', 'deck_size')]
        lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} | {camp_label(camp, mode)} | {clears}/{len(rows)} | " + ' | '.join(metrics) + ' |')
    lines.append('')
    if any('core_relic' in row for row in report['rows']):
        lines += ['## 핵심 유물 선택', '',
                  '원정당 핵심 유물은 하나다. 각 보상 주제는 제시된 세 후보 안에서만 선호 유물을 선택하며 없는 유물을 강제로 받지 않는다. '
                  '미획득에는 첫 관장 도달 전 전멸도 포함한다. 동일한 구성 수는 완주한 원정에서만 센다.', '',
                  '| 파티 | 선호 전략 | 야영지 | 핵심 선택 분포 | 미획득 | 완주 유물 구성 수 |',
                  '|---|---|---|---|---:|---:|']
        for (party, style, camp, mode), rows in groups.items():
            distribution = ', '.join(f"{name} {sum(row.get('core_relic') == key for row in rows)}"
                                     for key, name in CORES.items() if any(row.get('core_relic') == key for row in rows)) or '—'
            missing = sum(not row.get('core_relic') for row in rows)
            sets = {tuple(sorted(row['relics'])) for row in rows if row['phase'] == 'cleared'}
            lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} | {camp_label(camp, mode)} | {distribution} | {missing} | {len(sets)} |")
        lines.append('')
    for party in dict.fromkeys(party for party, style, camp, mode in groups if style != 'baseline'):
        measured = [row for row in report['rows'] if row['party'] == party and row['phase'] == 'cleared']
        relic_sets = {tuple(sorted(row['relics'])) for row in measured}
        if len(relic_sets) == 1:
            lines += [f"{PARTIES.get(party, party)} 완주 {len(measured)}개 측정은 최종 유물 {len(next(iter(relic_sets)))}종의 구성이 같았다. "
                      '유물을 우선하는 정책의 영향과 작은 공용 유물 풀의 수렴 양상을 다음 콘텐츠 조정에서 함께 검토한다.', '']
    if report['version'] == 2:
        lines += ['## 야영지 경제', '',
                  '각 행은 같은 편성·보상 선호·야영지 정책의 평균이다. 초반 전멸과 완주를 합친 값이므로 오래 진행한 그룹의 지출·강화 횟수가 커질 수 있다.', '',
                  '| 파티 | 선호 전략 | 야영지 | 휴식 | 강화 | 제거 | 아이템 사용 | 카드 지출 | 보급·진화 재료 | 제거 지출 | 만남 지출 |',
                  '|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
        for (party, style, camp, mode), rows in groups.items():
            keys = ('rests', 'cards_upgraded', 'cards_removed', 'items_used',
                    'gold_cards', 'gold_supplies', 'gold_removal', 'gold_events')
            metrics = [f"{mean(row['economy'][key] for row in rows):.1f}" for key in keys]
            lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} | {camp_label(camp, mode)} | " + ' | '.join(metrics) + ' |')
        lines.append('')
        paired = defaultdict(dict)
        for row in report['rows']:
            paired[(row['party'], row['style'], row.get('recruitment', 'off'))].setdefault(row['seed'], {})[row['camp_policy']] = row
        if any({'rest', 'develop'} <= set(pair) for seeds in paired.values() for pair in seeds.values()):
            lines += ['## 같은 시드에서 두 운영 모두 완주한 경우', '',
                      '같은 파티·보상 주제·시드에서 양쪽 모두 완주한 쌍만 비교한다. 한쪽이 일찍 전멸한 원정의 짧은 턴 수를 속도 향상으로 계산하지 않는다. '
                      '전체 완주/전멸 결과는 앞 표와 함께 본다.', '',
                      '| 파티 | 선호 전략·영입 | 완주한 쌍 | 휴식 턴 | 육성 턴 | 턴 변화 | 휴식 HP 피해 | 육성 HP 피해 |',
                      '|---|---|---:|---:|---:|---:|---:|---:|']
            for (party, style, mode), seeds in paired.items():
                matches = [pair for pair in seeds.values() if {'rest', 'develop'} <= set(pair)
                           and all(pair[camp]['phase'] == 'cleared' for camp in CAMPS)]
                if not matches:
                    continue
                turns = [mean(pair[camp]['turns'] for pair in matches) for camp in CAMPS]
                damage = [mean(pair[camp]['damage_taken'] for pair in matches) for camp in CAMPS]
                change = (turns[1]/turns[0]-1)*100 if turns[0] else 0
                lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} / {RECRUITMENT[mode]} | {len(matches)} | "
                             f"{turns[0]:.1f} | {turns[1]:.1f} | {change:+.1f}% | {damage[0]:.1f} | {damage[1]:.1f} |")
            lines.append('')
    if recruiting:
        lines += ['## 초반 영입 비교', '',
                  '같은 편성·보상 선호·야영지·시드의 두 정책만 짝지어 비교한다. 포획에 쓴 턴·볼·에너지를 그대로 포함한다. '
                  '공통 전투 정책에 첫 지역 최대 두 포획을 더하며, 한 야생에서 세 턴 안에 포획하지 못하면 일반 전투로 돌아간다. '
                  '포획을 시도하는 동안의 카드 선택도 달라져 실제 영입이 없어도 결과가 바뀔 수 있다. 중복 진화 계열은 피하고 빈자리를 채운다. 가득 찬 파티는 현재 6능력치 합과 최고 기술 평가가 최약 동료보다 15% 이상 높을 때 교체한다. '
                  '성장 뒤 교체 가치가 떨어지면 풀어줄 수 있다. 미래 진화나 상성을 최적화하는 정책은 아니다.', '',
                  '| 파티 | 선호 전략 | 야영지 | 같은 시드 쌍 | 영입 없음 완주 | 초반 영입 완주 | 포획 / 합류 / 교체 총수 |',
                  '|---|---|---|---:|---:|---:|---|']
        paired = defaultdict(dict)
        for row in report['rows']:
            paired[(row['party'], row['style'], row.get('camp_policy', 'rest'))].setdefault(row['seed'], {})[row.get('recruitment', 'off')] = row
        for (party, style, camp), seeds in paired.items():
            matches = [pair for pair in seeds.values() if set(RECRUITMENT) <= set(pair)]
            if not matches:
                continue
            clear = [sum(pair[mode]['phase'] == 'cleared' for pair in matches) for mode in RECRUITMENT]
            catches = sum(len(pair['early']['captures']) for pair in matches)
            joins = sum(d['joined'] for pair in matches for d in pair['early']['recruits'])
            replaced = sum(d['replaced'] > 0 for pair in matches for d in pair['early']['recruits'])
            lines.append(f"| {PARTIES.get(party, party)} | {STYLES.get(style, style)} | {CAMPS[camp]} | {len(matches)} | {clear[0]} | {clear[1]} | {catches} / {joins} / {replaced} |")
        lines += ['', '포획 종·장소 순서·합류/방출·빠진 동료·최종 파티·남은 볼은 원본 JSON에 보관한다. '
                  '실패한 원정의 짧은 턴을 속도 개선으로 계산하지 않는다. 영입이 있어도 생존·드로우·육성 판단이 부족하면 패배할 수 있다.', '']
    lines += format_diagnostics(report['rows'], PARTIES, STYLES, CAMPS, RECRUITMENT, names)
    lines += ['## 해석 범위', '',
              f"- 시드 {len({row['seed'] for row in report['rows']})}개의 고정 표본이다. 자동 전투 정책이 특정 기술·상태·교대를 더 선호하며 전략별 최적 플레이를 구현한 것은 아니다.",
              '- 보조형·아기·단독 편성의 초반 탈락은 원작 능력치/기술과 영입 정책의 영향을 함께 받는다. 종족값이나 관장 레벨을 즉시 일괄 조정할 근거로 쓰지 않는다.',
              '- 스타팅 화면의 출발 덱·Lv.5 능력치 미리보기로 실제 공격 카드와 발버둥 여부를 알린다. 초기 기술·진화·희귀 포획 조건을 바꾸지 않는다.',
              '- 다음 비교에서는 정책의 포획·진화 시점·전투 판단, 더 많은 시드와 수동 플레이를 함께 다룬다.', '']
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
