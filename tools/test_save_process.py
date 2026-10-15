#!/usr/bin/env python3
"""Verify save/continue across fresh Godot processes in isolated user directories."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true', help='Use the existing X11 OS pointer bridge')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='pokemon-save-process-') as directory:
        env = os.environ.copy()
        env.update(XDG_DATA_HOME=directory+'/data', XDG_CONFIG_HOME=directory+'/config',
                   XDG_CACHE_HOME=directory+'/cache', POKEMON_SAVE_TEST_ROOT=directory)
        for phase in ['write', 'read', 'camp_write', 'camp_read', 'recover']:
            env['POKEMON_SAVE_TEST_PHASE'] = phase
            if phase == 'recover':
                saves = list(Path(directory).rglob('journey.json'))
                assert len(saves) == 1, 'Expected exactly one isolated game save'
                saves[0].write_text('{interrupted write', encoding='utf-8')
            command = (['python3', 'tools/test_native_pointer.py', '--probe', 'native_save_probe'] if args.native else
                       ['godot', '--headless', '--path', '.', '--script', 'res://tests/test_save_process.gd'])
            result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=180)
            print(result.stdout, end='', flush=True)
            if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
                return result.returncode or 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
