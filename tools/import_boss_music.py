#!/usr/bin/env python3
"""Import user boss music ZIPs; deduplicate identical recordings, preserve role mappings."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,re,subprocess,tempfile,unicodedata,zipfile
from pathlib import Path

def sha(b): return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--archive',type=Path,action='append',required=True);args=p.parse_args()
 game=args.game_dir;out=game/'assets/audio/boss_music'
 if out.exists():raise RuntimeError('Output directory must be new')
 expansion=json.loads((game/'data/boss_expansion.json').read_text());base=json.loads((game/'data/league.json').read_text())
 roster={'gym':json.loads((game/'data/gym_leaders.json').read_text())['leaders']+expansion['gyms'],'elite':base['elite']+expansion['elite'],'champion':base['champions']+expansion['champions']}
 lookup={role:{r.get('leader',r.get('name')):r.get('leader_id',r.get('id')) for r in entries} for role,entries in roster.items()}
 aliases={'희연':'회연','싵론':'시트론','보미카':'보미','풍&란':'풍·란','쿠쿠이박사':'쿠쿠이','은빛산의 레드':'레드'}
 recordings={};sources=[];archives=[];mapping={};fallbacks={}
 for archive in args.archive:
  archives.append({'filename':archive.name,'sha256':sha(archive.read_bytes())})
  with zipfile.ZipFile(archive) as z:
   for item in z.infolist():
    if item.is_dir():continue
    if Path(item.filename).suffix.lower()!='.mp3' or item.file_size>32*1024*1024:raise RuntimeError('Unexpected ZIP entry: '+item.filename)
    name=unicodedata.normalize('NFC',Path(item.filename).stem)
    role=next((v for k,v in [('관장','gym'),('사천왕','elite'),('챔피언','champion'),('특별보스','champion')] if k in name),None)
    if role is None:raise RuntimeError('Unknown encounter role: '+name)
    names=name.split(' - ',1)[1].split(', ');keys=[]
    for n in names:
     n=aliases.get(n,n)
     if n not in lookup[role]:raise RuntimeError('Unknown trainer '+role+':'+n)
     keys.append(role+':'+lookup[role][n])
    data=z.read(item);digest=sha(data)
    if digest not in recordings:recordings[digest]={'data':data,'id':'boss_%02d'%(len(recordings)+1),'sources':[]}
    record=recordings[digest];source={'archive':archive.name,'filename':item.filename,'mp3_sha256':digest,'track_id':record['id'],'trainer_keys':keys}
    sources.append(source);record['sources'].append(source)
    for key in keys:
     if record['id'] not in mapping.setdefault(key,[]):mapping[key].append(record['id'])
 # These existing leaders are absent from the supplied filename lists. Use the
 # supplied general gym theme for their region, never another character's solo.
 for key,reference in [('gym:bede','gym:milo'),('gym:marnie','gym:milo'),('gym:tyme','gym:brassius')]:
  if key not in mapping:mapping[key]=mapping[reference].copy();fallbacks[key]={'reference':reference,'reason':'Not individually named in supplied recordings; regional general gym theme'}
 expected={role+':'+r.get('leader_id',r.get('id')) for role,rows in roster.items() for r in rows}
 if set(mapping)!=expected:raise RuntimeError('Mapping mismatch: '+str(expected-set(mapping)))
 if len(sources)!=39 or len(recordings)!=36:raise RuntimeError('Expected 39 supplied files /36 distinct recordings')
 out.mkdir(parents=True)
 def convert(pair):
  digest,record=pair;output=out/(record['id']+'.ogg')
  with tempfile.TemporaryDirectory(prefix='pokemon-boss-music-') as tmp:
   source=Path(tmp)/'source.mp3';source.write_bytes(record['data'])
   common=['ffmpeg','-hide_banner','-nostdin','-threads','1','-i',str(source),'-vn']
   analysis=subprocess.run(common+['-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True).stderr
   values=json.JSONDecoder().raw_decode(analysis[analysis.rfind('{'):])[0]
   filt='loudnorm=I=-18:TP=-2:LRA=11:measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}:linear=true'.format(**values)
   subprocess.run(common+['-af',filt,'-ar','48000','-ac','2','-c:a','libvorbis','-q:a','5','-map_metadata','-1',str(output)],capture_output=True,check=True)
   info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(output)],text=True))
  result={'id':record['id'],'path':'res://assets/audio/boss_music/'+output.name,'duration_seconds':float(info['format']['duration']),'channels':info['streams'][0]['channels'],'sample_rate':int(info['streams'][0]['sample_rate']),'source_mp3_sha256':digest,'ogg_sha256':sha(output.read_bytes()),'input_loudness':values}
  print('Converted '+record['id'],flush=True);return result
 with ThreadPoolExecutor(max_workers=3) as pool:tracks=sorted(pool.map(convert,recordings.items()),key=lambda t:t['id'])
 manifest={'schema_version':1,'source':'39 MP3 files supplied by the user in bgm1.zip through bgm8.zip;36 distinct recordings','rights':'Original Pokemon music; original rights remain with their owners. Not CC0/MIT.','archives':archives,'sources':sources,'aliases':aliases,'conversion':{'codec':'Vorbis q5','sample_rate':48000,'channels':2,'target_lufs':-18,'true_peak_db':-2,'method':'two-pass loudnorm; full original duration retained; metadata removed'},'tracks':tracks,'trainers':mapping,'fallbacks':fallbacks}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print('Imported %d boss mappings /%d bytes'%(len(mapping),sum(p.stat().st_size for p in out.glob('*.ogg'))),flush=True)
if __name__=='__main__':main()
