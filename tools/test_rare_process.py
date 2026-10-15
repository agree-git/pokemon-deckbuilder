#!/usr/bin/env python3
"""Verify each rarity's investigation, encounter, capture and unlock across fresh processes."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    for target in (144, 151, 150):
        with tempfile.TemporaryDirectory(prefix='pokemon-rare-process-') as directory:
            env = os.environ.copy()
            env.update(XDG_DATA_HOME=directory+'/data', XDG_CONFIG_HOME=directory+'/config',
                       XDG_CACHE_HOME=directory+'/cache', POKEMON_RARE_TARGET=str(target))
            for phase in ('prepare', 'reserve', 'capture', 'continue', 'failure', 'finished'):
                env['POKEMON_RARE_PHASE'] = phase
                result = subprocess.run(
                    ['godot', '--headless', '--path', '.', '--script', 'res://tests/test_rare_encounter_process.gd'],
                    cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, timeout=60)
                print(result.stdout, end='', flush=True)
                if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
                    return result.returncode or 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
