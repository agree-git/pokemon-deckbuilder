#!/usr/bin/env python3
"""Prepare the pinned official Godot 4.7.2 editor/templates in a local cache (stdlib)."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import urllib.request
import zipfile

VERSION = '4.7.2'
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/'
ARCHIVES = {
    'Godot_v4.7.2-stable_export_templates.tpz': 'ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079',
    'Godot_v4.7.2-stable_win64.exe.zip': '83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993',
    'Godot_v4.7.2-stable_linux.x86_64.zip': '9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65',
}
MEMBERS = ['version.txt','windows_release_x86_64.exe','windows_debug_x86_64.exe',
           'windows_release_x86_64_console.exe','windows_debug_x86_64_console.exe',
           'linux_release.x86_64']

def download(url, path):
    if path.exists(): return
    temporary = path.with_suffix(path.suffix+'.part')
    print('Downloading '+path.name,flush=True)
    try:
        with urllib.request.urlopen(url,timeout=120) as source, temporary.open('wb') as target:
            shutil.copyfileobj(source,target)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)

def archive(cache, name):
    path = cache/name
    download(BASE+name,path)
    with path.open('rb') as source:
        digest = hashlib.sha512()
        for chunk in iter(lambda:source.read(1024*1024),b''): digest.update(chunk)
        actual = digest.hexdigest()
    if actual != ARCHIVES[name]: raise RuntimeError('Official SHA512 mismatch: '+str(path))
    print('Verified SHA512: '+name,flush=True)
    return path

def extract_member(zipped, member, destination):
    # Fixed member allowlist, not archive-provided filesystem paths.
    with zipped.open(member) as source, destination.open('wb') as target:
        shutil.copyfileobj(source,target)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache-dir',type=Path,required=True)
    parser.add_argument('--skip-editor',action='store_true')
    args = parser.parse_args()
    cache = args.cache_dir.resolve();cache.mkdir(parents=True,exist_ok=True)
    templates = cache/'templates';templates.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive(cache,'Godot_v4.7.2-stable_export_templates.tpz')) as zipped:
        for member in MEMBERS:
            extract_member(zipped,'templates/'+member,templates/member)
    if (templates/'version.txt').read_text().strip() != VERSION+'.stable':
        raise RuntimeError('Unexpected template version')
    (templates/'linux_release.x86_64').chmod(0o755)
    godot = None
    if not args.skip_editor:
        if platform.system() not in ['Windows','Linux'] or platform.machine().lower() not in ['amd64','x86_64']:
            raise RuntimeError('This bootstrap supports Windows/Linux x86_64 only')
        executable = 'Godot_v4.7.2-stable_'+('win64.exe' if platform.system() == 'Windows' else 'linux.x86_64')
        with zipfile.ZipFile(archive(cache,executable+'.zip')) as zipped:
            godot = cache/executable
            extract_member(zipped,executable,godot)
            # Windows console companion allows reliable command-line output.
            companion = executable.replace('.exe','_console.exe')
            if platform.system() == 'Windows' and companion in zipped.namelist():
                extract_member(zipped,companion,cache/companion)
                godot = cache/companion
        godot.chmod(0o755)
    notices = cache/'godot-notices';notices.mkdir(exist_ok=True)
    for name in ['LICENSE.txt','COPYRIGHT.txt']:
        download(f'https://raw.githubusercontent.com/godotengine/godot/{VERSION}-stable/{name}',notices/name)
    metadata = {'version':VERSION,'godot':str(godot) if godot else None,'templates':str(templates),'notices':str(notices),'archives_sha512':ARCHIVES}
    (cache/'toolchain.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print('Toolchain manifest: '+str(cache/'toolchain.json'))

if __name__ == '__main__': main()
