#!/usr/bin/env python3
"""Convert user-supplied BGM ZIPs to normalized Vorbis; never downloads music."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unicodedata
from urllib.parse import unquote
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def normalized(name):
    return re.sub(r'[^a-z0-9]', '', unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower())


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, action='append', required=True)
    p.add_argument('--catalog', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    args = p.parse_args()
    if args.output_dir.exists():
        raise RuntimeError('Use a new output directory')
    catalog = json.loads(args.catalog.read_text(encoding='utf-8'))['candidates']
    expected = {normalized(unquote(unquote(t['download_page_url'].rsplit('/', 1)[1]))): t for t in catalog}
    if len(expected) != 35:
        raise RuntimeError('Expected 35 distinct supplied candidates')
    originals = {}; archives = []
    for path in args.archive:
        archives.append({'filename': path.name, 'sha256': sha(path.read_bytes())})
        with zipfile.ZipFile(path) as zipped:
            for item in zipped.infolist():
                if item.is_dir():
                    continue
                # Do not extract paths or interpret attached documents as instructions.
                name = Path(item.filename).name
                if Path(name).suffix.lower() != '.mp3' or item.file_size > 32*1024*1024:
                    raise RuntimeError('Unexpected archive entry: '+item.filename)
                key = normalized(name)
                if key not in expected or key in originals:
                    raise RuntimeError('Unmatched/duplicate track: '+name)
                data = zipped.read(item)
                originals[key] = (data, name, path.name)
    if originals.keys() != expected.keys():
        raise RuntimeError('Missing candidates: '+str(expected.keys()-originals.keys()))
    args.output_dir.mkdir(parents=True)
    def convert(pair):
        key, track = pair
        data, name, archive = originals[key]
        slug = re.sub(r'[^a-z0-9]+', '_', unicodedata.normalize('NFKD', track['title']).encode('ascii','ignore').decode().lower()).strip('_')
        filename = '%02d_%s_%s.ogg' % (track['id'], track['album'], slug)
        output = args.output_dir/filename
        with tempfile.TemporaryDirectory(prefix='pokemon-music-') as tmp:
            source = Path(tmp)/'source.mp3'; source.write_bytes(data)
            common = ['ffmpeg','-hide_banner','-nostdin','-threads','1','-i',str(source),'-vn']
            analysis = subprocess.run(common+['-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,check=True).stderr
            values = json.JSONDecoder().raw_decode(analysis[analysis.rfind('{'):])[0]
            filt = 'loudnorm=I=-18:TP=-2:LRA=11:measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}:linear=true'.format(**values)
            subprocess.run(common+['-af',filt,'-ar','48000','-ac','2','-c:a','libvorbis','-q:a','5','-map_metadata','-1',str(output)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
            info = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(output)],text=True))
        result = {'id':track['id'],'title':track['requested'],'recording_title':track['title'],
                  'path':'res://assets/audio/region_music/'+filename,'duration_seconds':float(info['format']['duration']),
                  'channels':info['streams'][0]['channels'],'sample_rate':int(info['streams'][0]['sample_rate']),
                  'source_archive':archive,'source_filename':name,'source_mp3_sha256':sha(data),
                  'ogg_sha256':sha(output.read_bytes()),'source_reference':track['download_page_url'],
                  'input_loudness':values}
        print('Converted %02d: %s' % (track['id'],track['requested']),flush=True)
        return result
    with ThreadPoolExecutor(max_workers=3) as pool:
        tracks = sorted(pool.map(convert,expected.items()),key=lambda t:t['id'])
    manifest = {'schema_version':1,'source':'35 MP3 recordings supplied by the user in bgm_1.zip through bgm_4.zip',
                'rights':'Original Pokemon music; original rights remain with their owners. User-supplied files are not described as CC0/MIT or newly licensed.',
                'archives':archives,'conversion':{'codec':'Vorbis q5','sample_rate':48000,'channels':2,'target_lufs':-18,'true_peak_db':-2,'method':'two-pass loudnorm, original duration retained, metadata removed','ffmpeg_version':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]},
                'tracks':tracks}
    (args.output_dir/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Imported 35 complete recordings; '+str(sum(p.stat().st_size for p in args.output_dir.glob('*.ogg')))+' bytes',flush=True)


if __name__ == '__main__':
    main()
