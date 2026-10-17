from pathlib import Path
import concurrent.futures,urllib.request,hashlib,json
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--cache-dir',type=Path,required=True);args=parser.parse_args()
W=args.cache_dir; (W/'csv').mkdir(parents=True,exist_ok=True)
rev='81d20919845b6a445969b9265aab5cec6b04cece'
files=['pokemon_species','pokemon_species_names','pokemon','pokemon_stats','pokemon_types','types','pokemon_moves','moves','move_names','move_meta','move_meta_stat_changes','pokemon_evolution','version_groups']
def get(n):
 u=f'https://raw.githubusercontent.com/PokeAPI/pokeapi/{rev}/data/v2/csv/{n}.csv';p=W/'csv'/(n+'.csv')
 if not p.exists():p.write_bytes(urllib.request.urlopen(u,timeout=45).read())
 return n,{'url':u,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
r=dict(concurrent.futures.ThreadPoolExecutor(max_workers=5).map(get,files));(W/'csv_manifest.json').write_text(json.dumps(r,indent=2)+'\n');print('CSV files',len(r),'bytes',sum(e['bytes'] for e in r.values()))
