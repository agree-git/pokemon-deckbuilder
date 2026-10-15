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

    def test_historical_v1_can_be_read_on_its_own(self):
        self.data['version'] = 1
        del self.data['stat_basis']
        del self.data['rows'][0]['camp_policy']
        del self.data['rows'][0]['economy']
        report = load_reports([self.write(self.data)])
        self.assertEqual(1, report['version'])
        self.assertIn('매번 휴식 | 42 | 1/1', format_report(report))


if __name__ == '__main__':
    unittest.main()
