import json,hashlib,subprocess,urllib.request,concurrent.futures,io
from pathlib import Path
from PIL import Image
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--project-dir',type=Path,required=True);parser.add_argument('--cache-dir',type=Path,required=True);parser.add_argument('--sprite-repo',type=Path,required=True);args=parser.parse_args()
D=args.cache_dir.resolve();R=args.project_dir.resolve();clone=args.sprite_repo.resolve();SOURCE=Path(__file__).resolve().parent
REV='a9214714f00974a8c28586829e6315d9ca5a6348'; CRY='b3a9044bb839b5e3152aaa536c7b463a0fcf0140';SPR='0dc105d5b12416932f29b594078282ab4be045f5'
paths=json.loads((SOURCE/'sprite_paths.json').read_text()); assets={};cries=[]; (D/'cache').mkdir(exist_ok=True)
def fetch(url):
 cache=D/'cache'/hashlib.sha256(url.encode()).hexdigest()
 if not cache.exists():cache.write_bytes(urllib.request.urlopen(url,timeout=45).read())
 return cache.read_bytes()
def sprite(args):
 sid,pair=args;i=int(sid);records={}
 for n,source in enumerate(pair):
  back=n==1
  if source:
   raw=subprocess.check_output(['git','show',f'{REV}:{source}'],cwd=clone);url=f'https://raw.githubusercontent.com/smogon/sprites/{REV}/{source}'
  else:
   url=f'https://raw.githubusercontent.com/PokeAPI/sprites/{SPR}/sprites/pokemon/'+('back/' if back else '')+f'{i}.png';raw=fetch(url)
  im=Image.open(io.BytesIO(raw)); im.seek(0); rgba=im.convert('RGBA'); assert rgba.getbbox(),i
  rel=f'assets/pokemon/{"back" if back else "front"}/{i:03d}.png';target=R/rel
  if not source or source.endswith('.png'):payload=raw; transform='none'
  else:
   output=io.BytesIO();rgba.save(output,format='PNG');payload=output.getvalue();transform='GIF first frame to RGBA PNG' if source else 'none'
  target.write_bytes(payload)
  records[rel]={'url':url,'sha256':hashlib.sha256(payload).hexdigest(),'source_sha256':hashlib.sha256(raw).hexdigest(),'transformation':transform,'width':im.width,'height':im.height,'source_repository':'smogon/sprites' if source else 'PokeAPI/sprites'}
 return records
def cry(sid):
 i=int(sid);url=f'https://raw.githubusercontent.com/PokeAPI/cries/{CRY}/cries/pokemon/latest/{i}.ogg'
 try:raw=fetch(url)
 except Exception:
  if i not in [10169,10170,10171]:raise
  url=f'https://raw.githubusercontent.com/PokeAPI/cries/{CRY}/cries/pokemon/latest/{i-10025}.ogg';raw=fetch(url)
 rel=f'assets/audio/cries/{i}.ogg'
 source_hash=hashlib.sha256(raw).hexdigest(); transform='none'
 if not raw.startswith(b'OggS'):
  raw=subprocess.check_output(['ffmpeg','-v','error','-i','pipe:0','-c:a','libvorbis','-q:a','6','-f','ogg','pipe:1'],input=raw)
  transform='Upstream misnamed MP3 transcoded to Ogg Vorbis (quality 6)'
 (R/rel).write_bytes(raw)
 meta=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_entries','format=duration','-of','json',str(R/rel)]))
 pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(R/rel),'-f','s16le','-acodec','pcm_s16le','-'])
 return {'id':i,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'decoded_pcm_sha256':hashlib.sha256(pcm).hexdigest(),'duration':float(meta['format']['duration']),'url':url,'source_sha256':source_hash,'transformation':transform}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for records in pool.map(sprite,paths.items()):assets.update(records)
print('Sprites',len(assets),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for record in pool.map(cry,paths):cries.append(record)
manifest=json.loads((R/'assets/sources/manifest.json').read_text());manifest.update(assets);(R/'assets/sources/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
m=json.loads((R/'assets/audio/cries/manifest.json').read_text());m['files']=[r for r in m['files'] if str(r['id']) not in paths]+sorted(cries,key=lambda r:r['id']);(R/'assets/audio/cries/manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(D/'new_asset_manifest.json').write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n');print('Cries',len(cries))
