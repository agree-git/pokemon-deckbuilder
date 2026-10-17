#!/usr/bin/env python3
"""Fetch only pinned CSV/PNG/Ogg inputs referenced by the shipped expansion metadata."""
import argparse,concurrent.futures,hashlib,json,subprocess,urllib.request
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args();g=a.game_dir.resolve();c=a.cache_dir.resolve()
 if c==g or g in c.parents:raise RuntimeError('Use a cache outside the game checkout')
 d=json.loads((g/'data/pokedex_expansion.json').read_text(encoding='utf-8'));(c/'csv').mkdir(parents=True,exist_ok=True)
 def fetch(pair):
  name,record=pair;p=c/'csv'/(name+'.csv');url=record['url']
  if not url.startswith('https://raw.githubusercontent.com/PokeAPI/pokeapi/'):raise RuntimeError('Unexpected CSV publisher')
  if not p.exists():p.write_bytes(urllib.request.urlopen(url,timeout=90).read())
  if hashlib.sha256(p.read_bytes()).hexdigest()!=record['sha256']:raise RuntimeError('CSV checksum mismatch: '+name)
 with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:list(pool.map(fetch,d['csv_sources'].items()))
 (c/'csv_manifest.json').write_text(json.dumps(d['csv_sources'],indent=2)+'\n',encoding='utf-8')
 for name,revision in [('sprites','289e842364648ec0495ae4ba12f48d5cbfbf670b'),('cries','b3a9044bb839b5e3152aaa536c7b463a0fcf0140')]:
  repo=c/name;url='https://github.com/PokeAPI/'+name+'.git'
  existed=repo.exists()
  if not existed:subprocess.run(['git','clone','--filter=blob:none','--no-checkout','--depth','1',url,str(repo)],check=True)
  actual=subprocess.check_output(['git','remote','get-url','origin'],cwd=repo,text=True).strip()
  if actual!=url:raise RuntimeError('Unexpected cache origin: '+str(repo))
  if existed and subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip():raise RuntimeError('Cache checkout has local edits: '+str(repo))
  subprocess.run(['git','fetch','--depth','1','origin',revision],cwd=repo,check=True)
  paths=set()
  for plan in d['asset_plan'].values():
   if name=='sprites':
    for back in [False,True]:paths.add('/sprites/pokemon/'+('back/' if back else '')+plan['sprite_file']+'.png')
   else:paths.add('/cries/pokemon/latest/'+str(plan['cry_id'])+'.ogg')
  paths.update(['/README.md','/LICENCE.txt','/CONTRIBUTING_SPRITES.md'] if name=='sprites' else ['/README.md','/LICENSE'])
  if name=='sprites':
   for key in d['evolution_items']:
    if not (g/'assets/items'/(key+'.png')).exists():paths.add('/sprites/items/'+key.replace('_','-')+'.png')
  subprocess.run(['git','sparse-checkout','init','--no-cone'],cwd=repo,check=True)
  subprocess.run(['git','sparse-checkout','set','--no-cone','--stdin'],cwd=repo,input='\n'.join(sorted(paths))+'\n',text=True,check=True)
  subprocess.run(['git','checkout','--detach',revision],cwd=repo,check=True)
 print('Verified',len(d['csv_sources']),'CSV files and selected pinned asset inputs')
if __name__=='__main__':main()
