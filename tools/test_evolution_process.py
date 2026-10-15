#!/usr/bin/env python3
"""Verify purchase, evolution and continuation across three fresh Godot processes."""
import os
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--friendship', action='store_true', help='Verify friendship/time and an actual level-up battle')
    args = parser.parse_args()
    phases = ['prepare', 'evolve', 'continue'] if args.friendship else ['purchase', 'evolve', 'continue']
    script = 'test_friendship_process' if args.friendship else 'test_evolution_process'
    with tempfile.TemporaryDirectory(prefix='pokemon-evolution-process-') as directory:
        env = os.environ.copy()
        env.update(XDG_DATA_HOME=directory+'/data', XDG_CONFIG_HOME=directory+'/config',
                   XDG_CACHE_HOME=directory+'/cache', POKEMON_EVOLUTION_TEST_ROOT=directory)
        for phase in phases:
            env['POKEMON_EVOLUTION_TEST_PHASE'] = phase
            result = subprocess.run(
                ['godot', '--headless', '--path', '.', '--script', f'res://tests/{script}.gd'],
                cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, timeout=60)
            print(result.stdout, end='', flush=True)
            if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
                return result.returncode or 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
