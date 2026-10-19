#!/usr/bin/env python3
"""Verify local sprite atlases, or reproduce audited mappings from pinned source pixels.
Rebuild requires Pillow 12.3.0 for byte-identical PNGs. No guessed form-ID conversion.
"""
import argparse,json,urllib.request,concurrent.futures,hashlib,io,math,time
from pathlib import Path
from PIL import Image
SOURCES = {
 "smogon": ("smogon/sprites","a9214714f00974a8c28586829e6315d9ca5a6348"),
 "rogue": ("pagefaultgames/pokerogue-assets","009cac30c39d3615c7b2c320c3984af368871031"),
 "ebdx": ("ChromeValiant/Pokemon-Essentials-21-With-Unofficial-EBDX","4bd3abfe4185af0561f01d6dcd448bc1d02e0f8d"),
}
def digest(b):return hashlib.sha256(b).hexdigest()
def fetch(kind,path):
 repo,rev=SOURCES[kind];url=f'https://raw.githubusercontent.com/{repo}/{rev}/{path}';dest=CACHE/kind/path;dest.parent.mkdir(parents=True,exist_ok=True)
 for attempt in range(3):
  try:
   if not dest.exists():dest.write_bytes(urllib.request.urlopen(urllib.request.Request(url.replace(' ','%20')),timeout=45).read())
   b=dest.read_bytes()
   if digest(b)!=EXPECTED[url]:raise ValueError('Pinned source checksum mismatch: '+url)
   return b,{'url':url,'sha256':digest(b)}
  except Exception:
   if attempt==2:raise
   time.sleep(.25)
def json_frames(x):
 rows=x['textures'][0]['frames'] if 'textures' in x else x['frames']
 if isinstance(rows,dict):rows=[dict(v,filename=k) for k,v in rows.items()]
 return sorted(rows,key=lambda v:v['filename'])
def decode(kind,path):
 raw,record=fetch(kind,path);records=[record];frames=[];durations=[]
 if path.endswith('.gif'):
  im=Image.open(io.BytesIO(raw))
  for i in range(im.n_frames):
   im.seek(i);frames.append(im.convert('RGBA'));durations.append(max(10,im.info.get('duration',100))/1000)
 elif path.lower().endswith('.png'):
  strip=Image.open(io.BytesIO(raw)).convert('RGBA');w,h=strip.size
  assert w%h==0,(kind,path,strip.size,'not a square-frame strip')
  for i in range(w//h):frames.append(strip.crop((i*h,0,(i+1)*h,h)));durations.append(1/12)
 else:
  meta=json.loads(raw);pngpath=path.removesuffix('.json')+'.png';b,record=fetch(kind,pngpath);records.append(record);sheet=Image.open(io.BytesIO(b)).convert('RGBA')
  for row in json_frames(meta):
   rect=row['frame'];f=sheet.crop((rect['x'],rect['y'],rect['x']+rect['w'],rect['y']+rect['h']))
   if row.get('rotated',False):f=f.transpose(Image.Transpose.ROTATE_90)
   sz=row['sourceSize'];pos=row['spriteSourceSize'];canvas=Image.new('RGBA',(sz['w'],sz['h']));canvas.paste(f,(pos['x'],pos['y']));frames.append(canvas);durations.append(max(10,row.get('duration',1000/12))/1000)
 if len(frames)<2 or len({digest(f.tobytes()) for f in frames})<2:return None,records
 assert len(set(f.size for f in frames))==1,(kind,path,'frame canvas changes')
 bounds=None
 for f in frames:
  bb=f.getchannel('A').getbbox()
  if bb:bounds=bb if bounds is None else (min(bounds[0],bb[0]),min(bounds[1],bb[1]),max(bounds[2],bb[2]),max(bounds[3],bb[3]))
 assert bounds,(kind,path,'empty animation')
 frames=[f.crop(bounds) for f in frames];w,h=frames[0].size
 # Preserve sequence/timing; only losslessly deduplicate identical packed images.
 unique=[];lookup={};sequence=[]
 for f,t in zip(frames,durations):
  key=digest(f.tobytes())
  if key not in lookup:lookup[key]=len(unique);unique.append(f)
  idx=lookup[key]
  if sequence and sequence[-1][0]==idx:sequence[-1][1]+=t
  else:sequence.append([idx,t])
 columns=math.ceil(math.sqrt(len(unique)*h/w));columns=min(columns,max(1,4096//w));rows=math.ceil(len(unique)/columns)
 atlas=Image.new('RGBA',(columns*w,rows*h))
 for i,f in enumerate(unique):atlas.paste(f,((i%columns)*w,(i//columns)*h))
 identity=digest((kind+':'+path).encode())[:20];rel=f'assets/pokemon/animated/{identity}.png';dest=GAME/rel;OUT.mkdir(parents=True,exist_ok=True);atlas.save(dest,compress_level=6)
 result={'sheet':'res://'+rel,'width':w,'height':h,'frames':[[idx%columns*w,idx//columns*h,w,h,round(t,6)] for idx,t in sequence],'source_kind':kind,'source_path':path,'sha256':digest(dest.read_bytes()),'sources':records,'unique_frames':len(unique),'sheet_size':list(atlas.size)}
 return result,records
def main():
 global GAME,CACHE,OUT,EXPECTED
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game-dir',type=Path,default=Path.cwd())
 parser.add_argument('--cache-dir',type=Path)
 parser.add_argument('--rebuild',action='store_true')
 args=parser.parse_args();GAME=args.game_dir.resolve();OUT=GAME/'assets/pokemon/animated'
 manifest=json.loads((OUT/'manifest.json').read_text());views=manifest['views'];sheets=manifest['sheets']
 ids={str(p['id']) for p in json.loads((GAME/'data/pokedex_expansion.json').read_text())['pokemon']}
 assert set(views)=={id+'/'+side for id in ids for side in ['front','back']}
 EXPECTED={s['url']:s['sha256'] for record in sheets.values() for s in record['sources']}
 if args.rebuild:
  if args.cache_dir is None:parser.error('--rebuild requires --cache-dir outside the game checkout')
  CACHE=args.cache_dir.resolve()
  if CACHE==GAME or GAME in CACHE.parents:parser.error('Keep the input cache outside the game checkout')
  def worker(item):
   path,record=item;value,_=decode(record['source_kind'],record['source_path'])
   assert value and value['sheet']==path and value['sha256']==record['sha256'],path
   return path,value
  with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
   for path,value in executor.map(worker,sheets.items()):
    for view in views.values():
     if view['sheet']==path:assert view['frames']==value['frames'] and view['width']==value['width'] and view['height']==value['height']
 used=set()
 for key,view in views.items():
  assert view.get('sheet') in sheets and len(view['frames'])>1,key
  record=sheets[view['sheet']];used.add(view['sheet']);assert record['unique_frames']>1,key
  for x,y,w,h,t in view['frames']:
   assert x>=0 and y>=0 and w==view['width'] and h==view['height'] and t>0,key
   assert x+w<=record['sheet_size'][0] and y+h<=record['sheet_size'][1],key
 assert used==set(sheets)
 for path,record in sheets.items():
  dest=GAME/path.removeprefix('res://');assert digest(dest.read_bytes())==record['sha256'],path
  with Image.open(dest) as image:
   assert list(image.size)==record['sheet_size'] and image.mode=='RGBA',path
   image.verify()
 assert {str(p.resolve()) for p in OUT.glob('*.png')}=={str((GAME/p.removeprefix('res://')).resolve()) for p in sheets}
 print('POKEMON_ANIMATION_ASSETS',len(ids),'forms /',len(views),'animated views /',len(sheets),'valid lossless atlases; no fallback')
if __name__=='__main__':main()
