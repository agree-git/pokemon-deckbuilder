#!/usr/bin/env python3
"""Run current game checks from a separate, portable materials directory (stdlib only)."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
SUITES = {
    'player-support': ['test_player_move_support.gd'],
    'player-interactions': ['test_player_move_interactions.gd'],
    'player-bulk': ['test_player_move_bulk.gd','test_player_move_bulk_edges.gd'],
    'player-training': ['test_player_move_training.gd'],
    'held-items': ['test_held_items.gd'],
    'player-reactions': ['test_player_move_reactions.gd'],
    'player-fate': ['test_player_move_fate.gd'],
    'player-assist': ['test_player_move_assist.gd'],
    'player-items': ['test_player_move_items.gd'],
    'player-traps': ['test_player_move_traps.gd'],
    'player-altitude-new': ['test_player_move_altitude.gd','test_player_altitude_saves.gd'],
    'player-altitude': ['test_player_move_altitude.gd','test_player_altitude_saves.gd'],
    'player-seals-new': ['test_player_move_seals.gd','test_player_seal_saves.gd'],
    'player-seals': ['test_player_move_seals.gd','test_player_seal_saves.gd'],
    'player-fields': ['test_player_move_fields.gd','test_player_field_saves.gd','test_player_move_exchange.gd','test_player_exchange_saves.gd','test_player_move_tactics.gd','test_player_tactics_saves.gd','test_player_move_cards.gd','test_player_move_edges.gd','test_player_move_saves.gd','test_boss_move_effects_p3.gd','test_boss_v8_compatibility.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd','test_machines.gd','test_start.gd'],
    'player-exchange': ['test_player_move_exchange.gd', 'test_player_exchange_saves.gd', 'test_player_move_tactics.gd', 'test_player_tactics_saves.gd', 'test_player_move_cards.gd', 'test_player_move_edges.gd', 'test_player_move_saves.gd', 'test_boss_move_effects_p3.gd', 'test_boss_v8_compatibility.gd', 'test_boss_routes.gd', 'test_battle.gd', 'test_stats.gd', 'test_weather.gd', 'test_save.gd', 'test_national_progression.gd', 'test_deck_run.gd', 'test_machines.gd', 'test_start.gd'],
    'player-tactics': ['test_player_move_tactics.gd','test_player_tactics_saves.gd','test_player_move_cards.gd','test_player_move_edges.gd','test_player_move_saves.gd','test_boss_move_effects_p3.gd','test_boss_v8_compatibility.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd','test_machines.gd','test_start.gd'],
    'player-cards': ['test_player_move_cards.gd','test_player_move_edges.gd','test_player_move_saves.gd','test_boss_move_effects_p3.gd','test_boss_v8_compatibility.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd','test_machines.gd','test_start.gd'],
    'smoke': ['test_start.gd','test_battle.gd','test_stats.gd','test_weather.gd'],
    'reactions': ['test_rare_reactions.gd','test_visibility.gd','test_compatibility.gd','test_rare_capture.gd'],
    'soundscape': ['test_soundscape.gd','test_region_music.gd','test_pause_audio.gd'],
    'campaign': ['test_deck_run.gd','test_save.gd','test_boss_routes.gd'],
    'boss-effects-p3': ['test_boss_move_effects_p3.gd','test_boss_unique_edges.gd','test_boss_unique_saves.gd','test_boss_v8_compatibility.gd','test_boss_move_effects_p2.gd','test_boss_protection_resources.gd','test_boss_effects_p2_parity.gd','test_boss_move_effects_p1.gd','test_boss_effects_parity.gd','test_boss_move_effects.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd'],
    'boss-effects-p2': ['test_boss_move_effects_p2.gd','test_boss_protection_resources.gd','test_boss_effects_p2_parity.gd','test_boss_move_effects_p1.gd','test_boss_effects_parity.gd','test_boss_move_effects.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd'],
    'boss-effects-p1': ['test_boss_move_effects_p1.gd','test_boss_effects_parity.gd','test_boss_move_effects.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_weather.gd','test_save.gd','test_national_progression.gd','test_deck_run.gd'],
    'boss-effects': ['test_boss_move_effects.gd','test_boss_routes.gd','test_battle.gd','test_stats.gd','test_save.gd','test_national_progression.gd'],
    'boss': ['test_boss_parties.gd','test_boss_music.gd','test_boss_routes.gd'],
    'boss-party-regression': ['test_boss_music.gd','test_boss_routes.gd','test_deck_run.gd','test_save.gd','test_national_progression.gd','test_machines.gd'],
    'pokedex': ['test_pokedex.gd','test_national_progression.gd','test_machines.gd'],
    'camp': ['test_machines.gd','test_national_progression.gd','test_deck_run.gd','test_save.gd','test_boss_routes.gd'],
    'rare': ['test_rare.gd','test_rare_capture.gd','test_rare_stories.gd',
             'test_visibility.gd','test_compatibility.gd','test_growth.gd','test_audio.gd'],
}
SUITES['player-seals'] += SUITES['player-fields']
SUITES['player-altitude'] += SUITES['player-seals']
ERROR = re.compile(r'SCRIPT ERROR:|(?:^|\n)ERROR:|leaked at exit', re.I)
SUMMARY = re.compile(r'(\d+)\s+(?:checks?|decoded)\s*(?:/|,)\s*(\d+)\s+failures?')

def execute(command, env, timeout, verbose, summary=False):
    try:
        run = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except (OSError,subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f'Could not complete {Path(command[-1]).name}: {exc}') from exc
    text = run.stdout
    matches = SUMMARY.findall(text)
    if run.returncode or ERROR.search(text) or (summary and (not matches or any(int(n) for _,n in matches))):
        print(text,end='')
        raise RuntimeError(f'Check failed: {Path(command[-1]).name} (exit {run.returncode})')
    if verbose:
        print(text,end='')
    if summary:
        result = [(int(n),int(f)) for n,f in matches]
        print(f'PASS {Path(command[-1]).name}: {sum(n for n,_ in result)} checks',flush=True)
        return sum(n for n,_ in result)
    return 0

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir',type=Path,required=True,help='Current main checkout containing project.godot')
    parser.add_argument('--suite',choices=[*SUITES,'all'],default='smoke')
    parser.add_argument('--godot',default='godot')
    parser.add_argument('--timeout',type=int,default=300,help='Timeout in seconds for each engine process')
    parser.add_argument('--verbose',action='store_true')
    args=parser.parse_args()
    game=args.game_dir.resolve()
    if not (game/'project.godot').is_file():parser.error('--game-dir must point to the main game, not development-materials')
    binary=shutil.which(args.godot)
    if not binary:parser.error('Godot not found; install 4.7.2 or pass --godot /path/to/godot')
    version=subprocess.check_output([binary,'--version'],text=True).strip()
    if not re.match(r'^4\.7\.2(?:\.|$)',version):parser.error(f'Expected Godot 4.7.2; found {version}')
    cases=list(dict.fromkeys(case for name,cases in SUITES.items() if args.suite in [name,'all'] for case in cases))
    print(f'{version} | {game} | {args.suite}: {len(cases)} test scripts',flush=True)
    with tempfile.TemporaryDirectory(prefix='pokemon-checks-') as directory:
        env=os.environ.copy()
        # Keep fixture profiles/settings away from real player data on every OS.
        for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','roaming'),('LOCALAPPDATA','local')]:
            value=Path(directory)/folder;value.mkdir();env[key]=str(value)
        # Snapshot runtime inputs only. Unique app name also isolates user:// on
        # platforms where native app-data APIs ignore XDG/APPDATA environment vars.
        snapshot=Path(directory)/'game';snapshot.mkdir()
        for folder in ['assets','data','scripts','scenes']:
            shutil.copytree(game/folder,snapshot/folder)
        app_name='pokemon-checks-'+uuid.uuid4().hex
        settings=(game/'project.godot').read_text(encoding='utf-8')
        settings=re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir(?:_name)?)=.*\n?','',settings,flags=re.M)
        settings,count=re.subn(r'^config/name=.*$',f'config/name="{app_name}"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{app_name}"',settings,count=1,flags=re.M)
        if count != 1:raise RuntimeError('Expected one application config/name in project.godot')
        (snapshot/'project.godot').write_text(settings,encoding='utf-8')
        common=[binary,'--headless','--path',str(snapshot)]
        execute(common+['--editor','--import','--quit'],env,args.timeout,args.verbose)
        print('PASS project import',flush=True)
        probe=subprocess.run(common+['--script',str(ROOT/'tools/user_data.gd')],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace",timeout=args.timeout)
        found=re.search(r'^CHECK_USER_DIR (.+)$',probe.stdout,re.M)
        if probe.returncode or ERROR.search(probe.stdout) or not found:raise RuntimeError('Could not verify isolated user:// directory: '+probe.stdout)
        user_dir=Path(found.group(1).strip())
        if user_dir.name != app_name:raise RuntimeError('User data path is not isolated: '+str(user_dir))
        total=0
        try:
            for case in cases:
                total+=execute(common+['--script',str(ROOT/'tests'/case)],env,args.timeout,args.verbose,True)
        finally:
            if user_dir.is_dir():shutil.rmtree(user_dir)
    print(f'PASS {len(cases)} scripts / {total} checks; isolated test data removed')

if __name__=='__main__':
    try:main()
    except (RuntimeError,subprocess.CalledProcessError) as exc:
        print(str(exc),file=sys.stderr);sys.exit(1)
