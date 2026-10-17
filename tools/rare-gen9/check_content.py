import json,subprocess,hashlib
from pathlib import Path
from PIL import Image
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--project-dir',type=Path,required=True);args=parser.parse_args()
R=args.project_dir.resolve();D=Path(__file__).resolve().parent
def old(n):return json.loads(subprocess.check_output(['git','show',f'07b0c41:{n}'],cwd=R))
def new(n):return json.loads((R/n).read_text())
checks=0
def check(ok,msg):
 global checks
 checks+=1
 assert ok,msg
for n in ['catalog','base_stats','progression']:
 a=old('data/'+n+'.json');b=new('data/'+n+'.json')
 if n=='catalog':
  for key in ['pokemon','moves']:
   mapped={r['id']:r for r in b[key]}
   for row in a[key]:check(mapped[row['id']]==row,f'Preserve original {key} {row["id"]}')
 else:
  for key in ['species']+(['moves','curves'] if n=='progression' else []):
   for id,row in a[key].items():check(b[key][id]==row,f'Preserve {n}.{key}.{id}')
for rel,row in new('assets/sources/manifest.json').items():
 if not (R/rel).exists():
  check(rel in old('assets/sources/manifest.json'),'Missing new asset '+rel)
  continue
 check(hashlib.sha256((R/rel).read_bytes()).hexdigest()==row['sha256'],f'Asset hash {rel}')
for row in new('assets/audio/cries/manifest.json')['files']:
 check(hashlib.sha256((R/f'assets/audio/cries/{row["id"]}.ogg').read_bytes()).hexdigest()==row['sha256'],'Cry '+str(row['id']))
check(hashlib.sha256((R/'data/battlefield_layouts.json').read_bytes()).hexdigest()=='b0f2e796afbb02eb04bef728ae28cfd113b1b8a8d6939911d5d0371ba89724f3','Preserve calibrated floor coordinates')
for sid,pair in json.loads((D/'sprite_paths.json').read_text()).items():
 for back in [False,True]:
  im=Image.open(R/f'assets/pokemon/{"back" if back else "front"}/{int(sid):03d}.png')
  check(im.mode in ['RGBA','P'] and im.convert('RGBA').getextrema()[3][0]==0,'Transparent pixel sprite')
print('CONTENT',checks,'checks passed')
