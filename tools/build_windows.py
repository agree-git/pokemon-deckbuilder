#!/usr/bin/env python3
"""Build a portable Windows x86_64 preview from an isolated game snapshot (stdlib)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile
import uuid
from windows_resources import ico_frames, verify_icon

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.7.2'
ERROR = re.compile(r'SCRIPT ERROR:|(?:^|\n)ERROR:|leaked at exit',re.I)
RUNTIME = ['assets','data','scripts','scenes']

def digest(path, algorithm='sha256'):
    h=hashlib.new(algorithm)
    with path.open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def run(command,env,log,timeout=300):
    result=subprocess.run(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    log.write_text(result.stdout,encoding='utf-8')
    if result.returncode or ERROR.search(result.stdout):
        raise RuntimeError(f'Engine failed (exit {result.returncode}); see {log}')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game-dir',type=Path,required=True)
    p.add_argument('--godot',required=True)
    p.add_argument('--toolchain-dir',type=Path,required=True)
    p.add_argument('--output-dir',type=Path,required=True,help='New output directory; existing files are never replaced')
    args=p.parse_args()
    game=args.game_dir.resolve();out=args.output_dir.resolve();toolchain=args.toolchain_dir.resolve()
    binary=shutil.which(args.godot)
    if not binary:raise RuntimeError('Godot editor not found')
    version=subprocess.check_output([binary,'--version'],text=True).strip()
    if not version.startswith(VERSION+'.'):raise RuntimeError('Expected Godot '+VERSION+'; found '+version)
    if (toolchain/'templates/version.txt').read_text().strip() != VERSION+'.stable':raise RuntimeError('Template version mismatch')
    for name in ['windows_debug_x86_64.exe','windows_release_x86_64.exe']:
        if not (toolchain/'templates'/name).is_file():raise RuntimeError('Missing template '+name)
    if not (game/'export_presets.cfg').is_file():raise RuntimeError('Missing game export_presets.cfg')
    if out.exists():raise RuntimeError('Use a new output directory: '+str(out))
    out.mkdir(parents=True)
    logs=out/'logs';logs.mkdir()
    bundle=out/'PokemonExpedition';bundle.mkdir()
    validation=out/'validation';validation.mkdir()
    check_user_dir='pokemon-export-check-'+uuid.uuid4().hex
    revision=subprocess.check_output(['git','-C',str(game),'rev-parse','HEAD'],text=True).strip()
    dirty=bool(subprocess.check_output(['git','-C',str(game),'status','--porcelain'],text=True).strip())
    source_hash=hashlib.sha256()
    inputs=[]
    for folder in RUNTIME:
        inputs.extend(path for path in (game/folder).rglob('*') if path.is_file())
    inputs += [game/'project.godot',game/'export_presets.cfg',game/'ASSET_SOURCES.md']
    for source in sorted(inputs):
        source_hash.update(source.relative_to(game).as_posix().encode()+b'\0')
        source_hash.update(bytes.fromhex(digest(source)))
    with tempfile.TemporaryDirectory(prefix='pokemon-windows-build-') as directory:
        temporary=Path(directory);snapshot=temporary/'game';snapshot.mkdir()
        for folder in RUNTIME:shutil.copytree(game/folder,snapshot/folder)
        shutil.copy2(game/'project.godot',snapshot/'project.godot')
        preset=(game/'export_presets.cfg').read_text(encoding='utf-8')
        for mode in ['debug','release']:
            template=(toolchain/'templates'/f'windows_{mode}_x86_64.exe').as_posix()
            preset=preset.replace(f'custom_template/{mode}=""',f'custom_template/{mode}="{template}"')
        (snapshot/'export_presets.cfg').write_text(preset,encoding='utf-8')
        env=os.environ.copy()
        for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('APPDATA','roaming'),('LOCALAPPDATA','local')]:
            value=temporary/folder;value.mkdir();env[key]=str(value)
        common=[binary,'--headless','--path',str(snapshot)]
        run(common+['--editor','--import','--quit'],env,logs/'import.log')
        print('PASS isolated import',flush=True)
        run(common+['--export-release','Windows Desktop',str(bundle/'PokemonExpedition.exe')],env,logs/'export.log')
        # Official 4.7 export templates intentionally disable external --script/
        # --main-pack overrides. A separate test-only export uses a real main scene;
        # all game entries are later compared against the actual distribution PCK.
        shutil.copy2(ROOT/'tests/test_export.gd',snapshot/'export_check.gd')
        (snapshot/'export_check.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://export_check.gd" id="1"]\n[node name="ExportCheck" type="Node"]\nscript = ExtResource("1")\n',encoding='utf-8')
        settings=(snapshot/'project.godot').read_text(encoding='utf-8')
        settings=settings.replace('run/main_scene="res://scenes/main_menu.tscn"','run/main_scene="res://export_check.tscn"')
        settings=settings.replace('config/name="포켓몬 원정대"','config/name="포켓몬 원정대"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+check_user_dir+'"')
        (snapshot/'project.godot').write_text(settings,encoding='utf-8')
        run(common+['--editor','--import','--quit'],env,logs/'validation-import.log')
        run(common+['--export-release','Windows Desktop',str(validation/'ExportCheck.exe')],env,logs/'validation-export.log')
        (validation/'validation-info.json').write_text(json.dumps({'custom_user_dir':check_user_dir,'source_revision':revision},indent=2)+'\n',encoding='utf-8')

    exe=bundle/'PokemonExpedition.exe';pack=bundle/'PokemonExpedition.pck'
    with exe.open('rb') as source:
        header=source.read(4096)
    pe=struct.unpack_from('<I',header,0x3c)[0]
    if header[:2]!=b'MZ' or header[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',header,pe+4)[0]!=0x8664:
        raise RuntimeError('Expected a Windows x86_64 PE executable')
    with pack.open('rb') as source:
        if source.read(4)!=b'GDPC':raise RuntimeError('Missing/invalid standalone PCK')
    icon_frames=ico_frames(game/'assets/branding/expedition.ico')
    for executable in [exe,validation/'ExportCheck.exe']:
        verify_icon(executable,icon_frames)
    print('PASS embedded Windows game icon: 16/32/48/64/128/256px',flush=True)
    # Keep attribution files outside the executable so players can read them.
    notice_files=[game/'ASSET_SOURCES.md',game/'assets/fonts/OFL.txt',game/'assets/audio/cries/UPSTREAM_LICENSE',game/'assets/audio/cries/UPSTREAM_README.md']
    notice_files += [path for path in (game/'assets/sources').rglob('*') if path.is_file()]
    notice_files += [path for path in (game/'licenses').rglob('*') if path.is_file()]
    notice_files += [game/name for name in ['PLAY_GUIDE.md','CHANGELOG.md'] if (game/name).is_file()]
    for source in notice_files:
        target=bundle/source.relative_to(game);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    licenses=bundle/'licenses';licenses.mkdir(exist_ok=True)
    for name in ['LICENSE.txt','COPYRIGHT.txt']:
        shutil.copy2(toolchain/'godot-notices'/name,licenses/('Godot-'+name))
    readme='''포켓몬 원정대 · Windows 시험 배포\n\n1. ZIP 전체를 새 폴더에 압축 해제합니다.\n2. PokemonExpedition.exe를 실행합니다. Godot 설치는 필요하지 않습니다.\n3. PokemonExpedition.pck는 실행 파일과 같은 폴더에 둡니다.\n\n마우스로 카드를 선택합니다. 1/2/3 교대, Q/W/E/R 손패, Enter 턴 종료,\nC 포획, Esc 메뉴, F1 도움말, F11 전체 화면입니다.\n\n저장/설정 위치: %APPDATA%\\Godot\\app_userdata\\포켓몬 원정대\n새 빌드는 다른 폴더에 풀어도 같은 사용자 저장을 이어서 읽습니다.\n실행 폴더와 PCK를 삭제해도 사용자 저장은 별도로 남습니다.\n\n처음이라면 시작 화면의 튜토리얼에서 카드·교대·포획·야영을 연습하세요.\n새 원정은 도전 난도입니다. 상성·교대·야영지 강화와 회복약을 준비하세요.\n기존 원정은 시작 당시 난도를 유지합니다. 자세한 내용은 PLAY_GUIDE.md를 확인하세요.\n\n이 빌드는 완성된 정식 출시판이 아닙니다.\n에셋 권리/출처는 ASSET_SOURCES.md와 assets 폴더, 엔진 고지는 licenses 폴더를 확인하세요.\n'''
    (bundle/'README-Windows.txt').write_text(readme,encoding='utf-8-sig')
    metadata={'engine':version,'target':'Windows x86_64','source_revision':revision,'source_dirty':dirty,
              'source_sha256':source_hash.hexdigest(),'materials_revision':subprocess.check_output(['git','-C',str(ROOT if (ROOT/'.git').exists() else game),'rev-parse','HEAD' if (ROOT/'.git').exists() else 'origin/development-materials'],text=True).strip(),
              'materials_files_sha256':{name:digest(ROOT/name) for name in ['tools/build_windows.py','tools/prepare_godot.py','tools/verify_export.py','tools/windows_resources.py','tests/test_export.gd']},
              'branding':{'icon_frames_sha256':icon_frames,'icon_sha256':digest(game/'assets/branding/expedition.ico'),'splash_sha256':digest(game/'assets/branding/boot_splash.png')},
              'layout_sha256':digest(game/'data/battlefield_layouts.json'),
              'files':{path.relative_to(bundle).as_posix():{'bytes':path.stat().st_size,'sha256':digest(path)} for path in sorted(bundle.rglob('*')) if path.is_file()}}
    (bundle/'build-info.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    archive=out/f'PokemonExpedition-Windows-x86_64-{revision[:7]}.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as zipped:
        for path in sorted(bundle.rglob('*')):
            if path.is_file():zipped.write(path,path.relative_to(out))
    (out/'SHA256SUMS.txt').write_text(digest(archive)+'  '+archive.name+'\n',encoding='utf-8')
    print('PASS Windows x86_64 PE and external PCK')
    print('Bundle: '+str(bundle));print('Archive: '+str(archive));print('SHA256: '+digest(archive))

if __name__=='__main__':
    try:main()
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:raise SystemExit(str(error))
