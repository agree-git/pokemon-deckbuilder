#!/usr/bin/env python3
"""Check measurement separation, economy integrity and historical report reading."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from report_campaign_balance import format_report, load_reports


class CampaignReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='pokemon-report-test-')
        self.addCleanup(self.directory.cleanup)
        economy = {key: 0 for key in ('rests', 'cards_upgraded', 'cards_removed', 'items_used',
                                     'gold_cards', 'gold_supplies', 'gold_removal', 'gold_events')}
        economy['rests'] = 68
        self.data = dict(version=2, engine='4.7.2', ruleset='v3', stat_basis='species-level-v1',
                         limits=dict(battle_turns=200, actions=15000),
                         rules_fingerprint='same', policy='test', scope='public actions', rows=[
                             dict(party='kanto', starters=[1, 4, 7], style='baseline', seed=42,
                                  camp_policy='rest', economy=economy, phase='cleared', wins=69,
                                  error='', incomplete='', statistics_valid=True, turns=265,
                                  actions=1000, damage_taken=500, knockouts=0, gold_spent=0,
                                  deck_size=20, relics=['field_kit'])])

    def write(self, data, name='report.json'):
        path = Path(self.directory.name)/name
        path.write_text(json.dumps(data))
        return path

    def reject(self, data):
        with self.assertRaises((ValueError, KeyError, TypeError)):
            load_reports([self.write(data)])

    def test_camp_policies_are_independent_groups(self):
        developed = copy.deepcopy(self.data['rows'][0])
        developed.update(camp_policy='develop', turns=228)
        developed['economy'].update(rests=44, cards_upgraded=24)
        self.data['rows'].append(developed)
        report = load_reports([self.write(self.data)])
        text = format_report(report)
        self.assertIn('매번 휴식 | 42 | 1/1', text)
        self.assertIn('육성·덱 관리 | 42 | 1/1', text)
        self.assertIn('44.0 | 24.0', text)
        self.assertIn('species-level-v1', text)
        self.assertNotIn('2/2', text)
        self.assertIn('265.0 | 228.0 | -14.0%', text)

    def test_early_defeat_is_not_counted_as_faster_completion(self):
        defeated = copy.deepcopy(self.data['rows'][0])
        defeated.update(camp_policy='develop', phase='failed', wins=7, turns=20)
        defeated['economy'].update(rests=7)
        self.data['rows'].append(defeated)
        report = load_reports([self.write(self.data)])
        text = format_report(report)
        self.assertIn('0/1', text)
        self.assertNotIn('-92.5%', text)

    def test_duplicate_same_policy_is_rejected(self):
        self.data['rows'] *= 2
        self.reject(self.data)

    def test_core_choice_must_be_exclusive_and_owned(self):
        row = self.data['rows'][0]
        row['core_relic'] = 'relay_core'
        self.reject(self.data)
        row['relics'].append('relay_core')
        text = format_report(load_reports([self.write(self.data)]))
        self.assertIn('순환 엔진 1', text)
        row['relics'].append('ace_core')
        self.reject(self.data)
        row['core_relic'] = ''
        self.reject(self.data)

    def test_incomplete_is_rejected(self):
        for key, value in [('incomplete', 'action_limit'), ('error', 'invalid action'),
                           ('statistics_valid', False), ('phase', 'battle')]:
            with self.subTest(key=key):
                data = copy.deepcopy(self.data)
                data['rows'][0][key] = value
                self.reject(data)

    def test_economy_must_match_real_spending_and_action_budget(self):
        for changes in [dict(gold_removal=50), dict(rests=-1), dict(cards_upgraded=1),
                        dict(items_used=True)]:
            with self.subTest(changes=changes):
                data = copy.deepcopy(self.data)
                data['rows'][0]['economy'].update(changes)
                self.reject(data)

    def test_missing_or_unknown_camp_fields_are_rejected(self):
        for field in ['camp_policy', 'economy']:
            data = copy.deepcopy(self.data)
            del data['rows'][0][field]
            self.reject(data)
        self.data['rows'][0]['camp_policy'] = 'free-upgrades'
        self.reject(self.data)

    def test_missing_stat_basis_is_rejected(self):
        del self.data['stat_basis']
        self.reject(self.data)

    def test_different_rules_and_policies_cannot_mix(self):
        original = self.write(self.data)
        for field in ['version', 'engine', 'ruleset', 'rules_fingerprint', 'policy', 'scope', 'stat_basis', 'limits']:
            with self.subTest(field=field):
                data = copy.deepcopy(self.data)
                data[field] = 1 if field == 'version' else (dict(battle_turns=100, actions=15000) if field == 'limits' else 'different')
                with self.assertRaises(ValueError):
                    load_reports([original, self.write(data, 'other.json')])

    def recruitment_row(self, mode='early'):
        row = copy.deepcopy(self.data['rows'][0])
        row.update(recruitment=mode, captures=[], recruits=[], balls_remaining=2)
        return row

    def test_recruitment_axis_and_trace_are_preserved(self):
        off = self.recruitment_row('off')
        early = self.recruitment_row()
        early.update(captures=[dict(step=2, species=41)],
                     recruits=[dict(step=2, species=41, joined=True, replaced=4)],
                     balls_remaining=1)
        self.data['rows'] = [off, early]
        report = load_reports([self.write(self.data)])
        text = format_report(report)
        self.assertEqual(2, len(report['rows']))
        self.assertIn('매번 휴식 / 영입 없음 | 42 | 1/1', text)
        self.assertIn('매번 휴식 / 초반 영입 | 42 | 1/1', text)
        self.assertIn('| 1 | 1 | 1 | 1 / 1 / 1 |', text)
        self.assertNotIn('**포획·희귀 조우는 사용하지 않는다.**', text)

    def test_invalid_recruitment_traces_are_rejected(self):
        good = self.recruitment_row()
        good.update(captures=[dict(step=2, species=41)],
                    recruits=[dict(step=2, species=41, joined=True, replaced=4)])
        for change in [dict(recruitment='forced'), dict(recruitment='off'), dict(balls_remaining=-1),
                       dict(captures=[dict(step=10, species=41)]),
                       dict(captures=[dict(step=2, species=150)]), dict(recruits=[]),
                       dict(recruits=[dict(step=2, species=41, joined=False, replaced=4)]),
                       dict(recruits=[dict(step=2, species=41, joined=True, replaced=-1)])]:
            with self.subTest(change=change):
                self.data['rows'] = [{**good, **change}]
                self.reject(self.data)

    def test_camp_pairs_cannot_mix_recruitment_modes(self):
        off = self.recruitment_row('off')
        early = self.recruitment_row()
        early.update(camp_policy='develop', turns=1)
        self.data['rows'] = [off, early]
        text = format_report(load_reports([self.write(self.data)]))
        self.assertNotIn('## 같은 시드에서 두 운영 모두 완주한 경우', text)
        self.assertNotIn('265.0 | 1.0', text)

    def test_recruitment_defeat_is_not_faster_completion(self):
        off = self.recruitment_row('off')
        early = self.recruitment_row()
        early.update(phase='failed', wins=7, turns=20)
        early['economy'].update(rests=7)
        self.data['rows'] = [off, early]
        text = format_report(load_reports([self.write(self.data)]))
        self.assertIn('| 1 | 1 | 0 | 0 / 0 / 0 |', text)
        self.assertNotIn('-92.5%', text)

    def test_historical_v1_can_be_read_on_its_own(self):
        self.data['version'] = 1
        del self.data['stat_basis']
        del self.data['rows'][0]['camp_policy']
        del self.data['rows'][0]['economy']
        report = load_reports([self.write(self.data)])
        self.assertEqual(1, report['version'])
        self.assertIn('매번 휴식 | 42 | 1/1', format_report(report))

    def diagnostics_row(self):
        row = self.recruitment_row('off')
        row.update(phase='failed', wins=0, turns=3, damage_taken=17, knockouts=1)
        row['economy']['rests'] = 0
        member = dict(uid=129, species=129, level=5, hp=17, max_hp=17, skills=['move_150'])
        row['battle_diagnostics'] = [dict(step=0, kind='wild', place='야생 조우 1', outcome='lost', turns=3,
            party_before=[member], party_after=[{**member, 'hp': 0}],
            opponents_after=[dict(uid=-1, species=81, level=6, hp=12, max_hp=19, skills=[])],
            deck_size=16, living_cards=16, direct_cards=8, fallback_cards=8,
            coverage=[dict(species=81, level=6, tactic='balanced', attack=8, immune=0, conditional=0, strong=0)],
            counts=dict(damage_taken=17, knockouts=1), cards=dict(move_165=7))]
        return row

    def test_diagnostics_keep_defeat_separate_from_completed_bosses(self):
        self.data['rows'] = [self.diagnostics_row()]
        text = format_report(load_reports([self.write(self.data)]))
        self.assertIn('## 전투별 진단', text)
        self.assertIn('| 1 | 0 | 1 / 0 / 0 | 3.0 | 8.0 / 8.0 |', text)

    def test_diagnostics_reject_missing_battles_and_false_totals(self):
        row = self.diagnostics_row()
        for key, value in [('turns', 4), ('damage_taken', 18), ('knockouts', 2), ('battle_diagnostics', [])]:
            with self.subTest(key=key):
                self.data['rows'] = [{**row, key: value}]
                self.reject(self.data)

    def test_diagnostics_reject_impossible_snapshots_and_coverage(self):
        for field, change in [('battle', dict(step=2)), ('battle', dict(kind='gym')),
                              ('battle', dict(outcome='won')), ('battle', dict(fallback_cards=9)),
                              ('party_after', dict(hp=1)), ('party_after', dict(level=6)),
                              ('coverage', dict(attack=7)), ('coverage', dict(conditional=17))]:
            with self.subTest(field=field, change=change):
                row = self.diagnostics_row()
                b = row['battle_diagnostics'][0]
                (b if field == 'battle' else b[field][0]).update(change)
                self.data['rows'] = [row]
                self.reject(self.data)

    def route(self, version=2):
        from campaign_route_report import BOSS_STEPS
        bosses = []
        for index, step in enumerate(BOSS_STEPS):
            kind = 'gym' if index < 8 else ('elite' if index < 12 else 'champion')
            bosses.append(dict(step=step, kind=kind, id=f'person_{index}', name=f'보스 {index}',
                region='관동', type='grass', party=list(range(1, 6 if kind == 'elite' else 7)),
                level=100 if kind == 'champion' else min(99, 15+index*7)))
        return dict(version=version, signature='a'*64, bosses=bosses)

    def test_route_provenance_survives_roundtrip(self):
        self.data['route_version'] = 2
        self.data['rows'][0]['route'] = self.route()
        report = load_reports([self.write(self.data)])
        self.assertEqual(2, report['route_version'])
        self.assertIn('대진 버전: **2**', format_report(report))
        self.assertEqual(report, load_reports([self.write(report, 'roundtrip.json')]))

    def test_unrecorded_route_is_not_silently_assumed_legacy(self):
        report = load_reports([self.write(self.data)])
        self.assertNotIn('route_version', report)
        self.assertIn('대진 버전: 미기록', format_report(report))
        self.assertEqual(report, load_reports([self.write(report, 'roundtrip.json')]))

    def test_route_versions_and_unrecorded_reports_cannot_mix(self):
        first = self.write(self.data, 'unrecorded.json')
        self.data['route_version'] = 2
        self.data['rows'][0].update(seed=43, route=self.route())
        second = self.write(self.data, 'recorded.json')
        with self.assertRaises(ValueError):
            load_reports([first, second])
        legacy = copy.deepcopy(self.data)
        legacy['route_version'] = 1
        legacy['rows'][0].update(seed=44, route=self.route(1))
        with self.assertRaises(ValueError):
            load_reports([second, self.write(legacy, 'legacy.json')])

    def test_route_contract_rejects_missing_or_corrupt_boss_evidence(self):
        for change in ['missing', 'version', 'signature', 'count', 'step', 'species', 'level', 'id', 'type', 'bool']:
            with self.subTest(change=change):
                data = copy.deepcopy(self.data)
                data['route_version'] = 2
                route = data['rows'][0]['route'] = self.route()
                if change == 'missing': del data['rows'][0]['route']
                elif change == 'version': route['version'] = 1
                elif change == 'signature': route['signature'] = 'not-a-signature'
                elif change == 'count': route['bosses'].pop()
                elif change == 'step': route['bosses'][0]['step'] = 12
                elif change == 'species': route['bosses'][0]['party'][0] = 387
                elif change == 'level': route['bosses'][-1]['level'] = 99
                elif change == 'id': route['bosses'][1]['id'] = route['bosses'][0]['id']
                elif change == 'type': route['bosses'][0]['type'] = 'unknown'
                elif change == 'bool': data['route_version'] = True
                self.reject(data)

    def test_same_seed_must_have_same_route_across_parties(self):
        self.data['route_version'] = 2
        row = self.data['rows'][0]
        row['route'] = self.route()
        other = copy.deepcopy(row)
        other.update(party='solo', starters=[1])
        self.data['rows'].append(other)
        load_reports([self.write(self.data)])
        other['route']['signature'] = 'b'*64
        self.reject(self.data)

    def test_first_gym_table_does_not_call_pre_gym_wipe_a_boss_loss(self):
        self.data['route_version'] = 2
        row = self.diagnostics_row()
        row['route'] = self.route()
        self.data['rows'] = [row]
        text = format_report(load_reports([self.write(self.data)]))
        self.assertIn('## 새 대진의 첫 관장 도달', text)
        self.assertIn('도달 전 전멸', text)
        self.assertIn('person_0', text)

    def test_actual_boss_must_match_the_scheduled_roster(self):
        from campaign_route_report import validate_route
        row = dict(route=self.route(), battle_diagnostics=[])
        boss = row['route']['bosses'][0]
        battle = dict(step=boss['step'], kind=boss['kind'], place=boss['name'],
            opponents_after=[dict(species=s, level=boss['level']) for s in boss['party']])
        row['battle_diagnostics'] = [battle]
        validate_route(row, 2)
        battle['opponents_after'][0]['species'] = 386
        with self.assertRaises(ValueError):
            validate_route(row, 2)


if __name__ == '__main__':
    unittest.main()
