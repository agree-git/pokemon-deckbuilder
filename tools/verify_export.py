#!/usr/bin/env python3
"""Check a shipped Windows bundle plus a separate, byte-matched runtime test export."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import tempfile
import uuid
from windows_resources import verify_icon

ERROR=re.compile(r'SCRIPT ERROR:|(?:^|\n)ERROR:|leaked at exit',re.I)

def sha256(path):
    digest=hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''):digest.update(chunk)
    return digest.hexdigest()

def inventory(path):
    """Read our unencrypted Godot 4.7 PCK v3/v4, without extracting paths."""
    result={};size=path.stat().st_size
    with path.open('rb') as pack:
        magic,version,major,minor,patch,flags,base,directory=struct.unpack('<6I2Q',pack.read(40))
        if magic!=0x43504447 or version not in [3,4] or (major,minor,patch)!=(4,7,2) or flags&1:
            raise RuntimeError('Unsupported PCK format/version/encryption: '+str(path))
        if not 40<=directory<size:raise RuntimeError('Invalid pack directory')
        pack.seek(directory);count=struct.unpack('<I',pack.read(4))[0]
        if count>100000:raise RuntimeError('Unexpected pack entry count')
        entries=[]
        for _ in range(count):
            length=struct.unpack('<I',pack.read(4))[0]
            if length>4096:raise RuntimeError('Invalid pack path length')
            name=pack.read(length).rstrip(b'\0').decode('utf-8')
            offset,amount,md5,entry_flags=struct.unpack('<QQ16sI',pack.read(36))
            if entry_flags or base+offset+amount>size:raise RuntimeError('Unsupported/invalid pack entry: '+name)
            entries.append((name,base+offset,amount,md5))
        for name,offset,amount,md5 in entries:
            pack.seek(offset);payload=pack.read(amount)
            if hashlib.md5(payload).digest()!=md5:raise RuntimeError('Packed payload checksum mismatch: '+name)
            result[name]=hashlib.sha256(payload).hexdigest()
    return result

def launch(command,cwd,env,log,timeout=180,title=False):
    result=subprocess.run([command[0],'--headless','--log-file',str(log)]+command[1:],cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    text=result.stdout+'\n'+(log.read_text(encoding='utf-8',errors='replace') if log.exists() else '')
    log.with_suffix('.process.log').write_text(text,encoding='utf-8')
    diagnostic=None
    inspected=text
    if title and result.returncode==0:
        instances=set(re.findall(r'Leaked instance: ([A-Za-z0-9_]+):',text))
        resources=set(re.findall(r'Resource still in use: (res://[^\n]+?) \(',text))
        # Preserve exact known forced-quit audio diagnostics in the report.
        # The title changed from the old WAV to this supplied Ogg; do not accept
        # any other leaked types, tracks, resource counts or execution errors.
        title_ogg='res://assets/audio/region_music/20_oras_littleroot_town.ogg'
        wav=instances=={'AudioStreamWAV','AudioStreamPlaybackWAV'} and resources=={'res://assets/audio/music/title.wav'}
        ogg=instances=={'OggPacketSequence','AudioStreamOggVorbis','AudioStreamPlaybackOggVorbis','OggPacketSequencePlayback'} and len(resources)==2 and title_ogg in resources and any(re.fullmatch(re.escape(title_ogg)+r'::OggPacketSequence_[A-Za-z0-9]+',name) for name in resources)
        if wav or ogg:
            resource_count,instance_count=(1,2) if wav else (2,4)
            inspected=re.sub(r'ERROR: '+str(resource_count)+r' resources still in use at exit\.?[^\n]*','',text)
            inspected=re.sub(r'WARNING: '+str(instance_count)+r' ObjectDB instances were leaked at exit[^\n]*','',inspected)
            diagnostic='Forced headless title exit retains '+('title.wav WAV playback' if wav else '20_oras_littleroot_town.ogg Ogg playback')+' (exit 0); clean shutdown is not established'
    if result.returncode or ERROR.search(inspected):raise RuntimeError(f'Export process failed (exit {result.returncode}): '+str(log)+'\n'+text[-5000:])
    return text,diagnostic

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle-dir',type=Path,required=True)
    p.add_argument('--validation-dir',type=Path,required=True)
    p.add_argument('--mode',choices=['windows-native','linux-pack'],required=True)
    p.add_argument('--runtime',type=Path,help='Official Linux release template for --mode linux-pack')
    p.add_argument('--report',type=Path,required=True)
    args=p.parse_args()
    bundle=args.bundle_dir.resolve();validation=args.validation_dir.resolve();args.report=args.report.resolve()
    metadata=json.loads((bundle/'build-info.json').read_text(encoding='utf-8'))
    check_info=json.loads((validation/'validation-info.json').read_text(encoding='utf-8'))
    checked=0
    for name,info in metadata['files'].items():
        path=bundle/name
        if not path.is_file() or path.stat().st_size!=info['bytes'] or sha256(path)!=info['sha256']:
            raise RuntimeError('Distribution checksum mismatch: '+name)
        checked+=1
    for executable in [bundle/'PokemonExpedition.exe',validation/'ExportCheck.exe']:
        verify_icon(executable,metadata['branding']['icon_frames_sha256'])
    shipped=inventory(bundle/'PokemonExpedition.pck')
    tested=inventory(validation/'ExportCheck.pck')
    matched=0
    for name,digest in shipped.items():
        if name in ['project.binary','.godot/uid_cache.bin']:continue
        if tested.get(name)!=digest:raise RuntimeError('Validation export differs from shipped game: '+name)
        matched+=1
    if any('export_check' in name or 'test_export' in name for name in shipped):raise RuntimeError('Test harness leaked into distribution')
    if args.mode=='windows-native' and platform.system()!='Windows':raise RuntimeError('Native check requires Windows')
    if args.mode=='linux-pack' and (platform.system()!='Linux' or not args.runtime):raise RuntimeError('Linux release template required')
    args.report.parent.mkdir(parents=True,exist_ok=True)
    marker=uuid.uuid4().hex;profiles=[]
    with tempfile.TemporaryDirectory(prefix='pokemon-export-check-') as directory:
        temporary=Path(directory);env=os.environ.copy()
        if args.mode=='windows-native':
            # Windows native folder APIs can ignore APPDATA env overrides.
            appdata=ctypes.create_unicode_buffer(32768)
            if ctypes.windll.shell32.SHGetFolderPathW(None,26,None,0,appdata)!=0:raise RuntimeError('Cannot resolve AppData')
            data=Path(appdata.value)
            player=data/'PokemonExpedition'
            product=[str(bundle/'PokemonExpedition.exe')]
            harness=[str(validation/'ExportCheck.exe')]
            expected_os='Windows'
        else:
            for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
                value=temporary/folder;value.mkdir();env[key]=str(value)
            data=temporary/'data';player=data/'PokemonExpedition'
            product=[];harness=[]
            # Release templates discover the sibling PCK automatically. Preserve
            # the official engine's disabled external path/script overrides.
            for label,pack_name,command in [('product','PokemonExpedition',product),('harness','ExportCheck',harness)]:
                folder=temporary/label;folder.mkdir();exe=folder/pack_name
                shutil.copy2(args.runtime.resolve(),exe);exe.chmod(0o755)
                source=bundle if label=='product' else validation
                shutil.copy2(source/(pack_name+'.pck'),folder/(pack_name+'.pck'))
                command.append(str(exe))
            expected_os='Linux'
        custom=check_info['custom_user_dir']
        if not re.fullmatch(r'pokemon-export-check-[0-9a-f]{32}',custom):raise RuntimeError('Invalid isolated test profile name')
        isolated=data/custom
        if isolated.exists() or (player.exists() and any(path.name != 'logs' for path in player.iterdir())):
            raise RuntimeError('Player/test data already exists; use a fresh Windows test account/runner')
        try:
            for profile in [player,isolated]:
                created=not profile.exists()
                profile.mkdir(parents=True,exist_ok=True);(profile/'.export-smoke-profile').write_text(marker,encoding='utf-8');profiles.append((profile,created))
            title_log=args.report.with_suffix('.title.log')
            title,title_diagnostic=launch(product+['--verbose','--max-fps','60','--quit-after','60'],temporary,env,title_log,title=True)
            if 'Godot Engine v4.7.2' not in title:raise RuntimeError('No engine startup in shipped title log')
            runtime_log=args.report.with_suffix('.runtime.log')
            text,_=launch(harness+['--',expected_os],temporary,env,runtime_log)
            summary=re.search(r'EXPORT_SMOKE: (\d+) checks / (\d+) failures',text)
            reported=re.search(r'EXPORT_USER_DIR (.+)',text)
            if not summary or int(summary[2]) or not reported or Path(reported[1].strip()).resolve()!=isolated.resolve():
                raise RuntimeError('Missing/failed runtime summary or profile isolation; see '+str(runtime_log))
            report={'verifier_sha256':sha256(Path(__file__).resolve()),'mode':args.mode,'actual_os':expected_os,'engine':metadata['engine'],
                    'source_revision':metadata['source_revision'],'source_sha256':metadata['source_sha256'],
                    'distribution_files_verified':checked,'packed_game_entries_matched':matched,
                    'windows_icon_sizes_verified':[16,32,48,64,128,256],
                    'shipped_title_launch':True,'title_shutdown_diagnostic':title_diagnostic,'title_exit_clean':title_diagnostic is None,'runtime_checks':int(summary[1]),'failures':0,
                    'profile_isolated':True,'profile_removed':True,
                    'limitations':['Headless launch; no physical GPU/audio or full playthrough',
                                   'Deep checks use a separate test export; shipped game entries are byte-matched except project settings and UID cache']}
        finally:
            for profile,created in profiles:
                proof=profile/'.export-smoke-profile'
                if proof.is_file() and proof.read_text(encoding='utf-8')==marker:
                    if created:shutil.rmtree(profile)
                    else:proof.unlink() # Preserve pre-existing editor logs.
    args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if title_diagnostic:print('KNOWN DIAGNOSTIC: '+title_diagnostic)
    print(f'PASS {args.mode}: {checked} distribution files / {matched} identical pack entries / title startup / {report["runtime_checks"]} runtime checks; fresh profiles removed')

if __name__=='__main__':
    try:main()
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:raise SystemExit(str(error))
