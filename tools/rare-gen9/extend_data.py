import csv,json,collections,importlib.util,subprocess,re
from pathlib import Path
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--project-dir',type=Path,required=True);parser.add_argument('--cache-dir',type=Path,required=True);parser.add_argument('--sprite-repo',type=Path,required=True);args=parser.parse_args()
R=args.project_dir.resolve();D=args.cache_dir.resolve();SOURCE=Path(__file__).resolve().parent
def rows(n):return list(csv.DictReader((D/'csv'/f'{n}.csv').open()))
def read(n):return json.loads((R/'data'/f'{n}.json').read_text())
def save(n,x): (R/'data'/f'{n}.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
scope=json.loads((SOURCE/'scope.json').read_text()); ids=scope['base_ids']+[int(r['id']) for r in scope['forms']]
species={int(r['id']):r for r in rows('pokemon_species')}; pokes={int(r['id']):r for r in rows('pokemon')}; defaults={int(r['species_id']):r for r in pokes.values() if r['is_default']=='1'}
names={int(r['pokemon_species_id']):r['name'] for r in rows('pokemon_species_names') if r['local_language_id']=='3'}
move_names={int(r['move_id']):r['name'] for r in rows('move_names') if r['local_language_id']=='3'}
type_names={r['id']:r['identifier'] for r in rows('types')}
stats=collections.defaultdict(dict); types=collections.defaultdict(list)
for r in rows('pokemon_stats'): stats[int(r['pokemon_id'])][['hp','attack','defense','special_attack','special_defense','speed'][int(r['stat_id'])-1]]=int(r['base_stat'])
for r in rows('pokemon_types'): types[int(r['pokemon_id'])].append((int(r['slot']),type_names[r['type_id']]))
regions={4:'sinnoh',5:'unova',6:'kalos',7:'alola',8:'galar',9:'paldea'}
c=read('catalog'); b=read('base_stats'); p=read('progression'); old={int(r['id']) for r in c['pokemon']}; added=[]
for i in ids:
 if i<=386:continue
 pk=pokes[i] if i>10000 else defaults[i]; dex=int(pk['species_id']); s=species[dex]; gen=int(s['generation_id']); regional=i>10000
 entry={'id':i,'dex_id':dex,'key':pk['identifier'],'name':names[dex]+(' (가라르)' if regional else ''),'generation':8 if regional else gen,'region':'galar' if regional else regions[gen],'evolves_from':int(s['evolves_from_species_id'] or 0),'is_baby':s['is_baby']=='1','is_legendary':s['is_legendary']=='1','is_mythical':s['is_mythical']=='1','types':[t for _,t in sorted(types[int(pk['id'])])],'front':f'res://assets/pokemon/front/{i:03d}.png','back':f'res://assets/pokemon/back/{i:03d}.png'}
 if regional:entry.update(form='galar',evolves_from=0)
 c['pokemon']=[p for p in c['pokemon'] if int(p['id']) != i];c['pokemon'].append(entry);b['species'][str(i)]=stats[int(pk['id'])]; added.append((i,int(pk['id'])))
 p['species'][str(i)]={'growth_rate':int(s['growth_rate_id']),'base_experience':int(pk['base_experience'] or 200),'learnset':[]}
# Preserve the historical 386 species and move definitions verbatim.
learn=collections.defaultdict(lambda:collections.defaultdict(list)); added_pk={pk:i for i,pk in added}
for r in rows('pokemon_moves'):
 pk=int(r['pokemon_id'])
 if pk in added_pk and r['pokemon_move_method_id']=='1':learn[pk][int(r['version_group_id'])].append((int(r['level']),int(r['move_id']),int(r['order'] or 0)))
vg={int(r['id']):int(r['order']) for r in rows('version_groups')}
used=set(); sources={}
for i,pk in added:
 versions=learn[pk]; assert versions,(i,pk,'missing learnset')
 version=max(versions,key=lambda v:vg[v]); entries=sorted(set(versions[version]),key=lambda e:(max(1,e[0]),e[2],e[1])); seen=set();ls=[]
 for level,m,order in entries:
  pair=(max(1,level),m)
  if pair not in seen:ls.append({'level':pair[0],'move':m});seen.add(pair);used.add(m)
 p['species'][str(i)]['learnset']=ls;sources[str(i)]={'pokemon_id':pk,'version_group':version}
ms={int(r['id']):r for r in rows('moves')}; metas={int(r['move_id']):r for r in rows('move_meta')}; changes=collections.defaultdict(list)
for r in rows('move_meta_stat_changes'):changes[int(r['move_id'])].append({'stat_id':int(r['stat_id']),'change':int(r['change'])})
import move_presentation as mod
existing_moves={int(r['id']) for r in c['moves']}
for i in sorted(used):
 m=ms[i];meta=metas.get(i,{});st=changes[i]; vfx=mod.presentation(m,meta,st)
 if str(i) not in p['moves']:
  p['moves'][str(i)]={'id':i,'name':move_names.get(i,m['identifier']),'type':type_names[m['type_id']],'power':int(m['power'] or 0),'category':int(m['damage_class_id']),'target':int(m['target_id']),'stats':st,'ailment':int(meta.get('meta_ailment_id') or 0),'healing':int(meta.get('healing') or 0),'drain':int(meta.get('drain') or 0),'vfx':vfx}
 if i not in existing_moves:
  c['moves'].append({'id':i,'key':m['identifier'],'name':move_names.get(i,m['identifier']),'type':type_names[m['type_id']],'category':{1:'status',2:'physical',3:'special'}[int(m['damage_class_id'])],'power':int(m['power'] or 0),'accuracy':int(m['accuracy'] or 100),'stat_changes':st,'ailment_chance':int(meta.get('ailment_chance') or 0),'vfx':vfx})
c['max_generation']=9;c['ordinary_max_generation']=3;c['rare_max_generation']=9;c['regions']=['kanto','johto','hoenn','sinnoh','unova','kalos','alola','galar','paldea']; b['rare_max_generation']=9
for n,x in [('catalog',c),('base_stats',b),('progression',p)]:save(n,x)
e=read('evolutions')
if not any(r['from']==789 for r in e):e.append({'from':789,'to':790,'level':43})
save('evolutions',e)
(D/'learnset_sources.json').write_text(json.dumps(sources,indent=2)+'\n');(D/'added.json').write_text(json.dumps(added))
# Resolve Smogon pixel assets (underscores separate compound names).
tree=subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD'],cwd=args.sprite_repo,text=True).splitlines(); paths=set(tree); mapping={}
for i,pk in added:
 key=pokes[pk]['identifier']; key={'giratina-altered':'giratina','shaymin-land':'shaymin','deoxys-normal':'deoxys','wormadam-plant':'wormadam','tornadus-incarnate':'tornadus','thundurus-incarnate':'thundurus','landorus-incarnate':'landorus','keldeo-ordinary':'keldeo','meloetta-aria':'meloetta','zygarde-50':'zygarde','wishiwashi-solo':'wishiwashi','minior-red-meteor':'minior','mimikyu-disguised':'mimikyu','toxtricity-amped':'toxtricity','eiscue-ice':'eiscue','indeedee-male':'indeedee','morpeko-full-belly':'morpeko','urshifu-single-strike':'urshifu','enamorus-incarnate':'enamorus'}.get(key,key)
 key=key.replace('-galar','-ogalar').replace('-','_').replace('_ogalar','-ogalar')
 pair=[]
 for back in (False,True):
  stem='src/sprites/gen5/s'+key+('-b' if back else '')
  match=next((stem+ext for ext in ('.png','.gif') if stem+ext in paths),None)
  if match is None:print('POKEAPI_FALLBACK',i,key,back)
  pair.append(match)
 mapping[str(i)]=pair
(D/'sprite_paths.json').write_text(json.dumps(mapping,indent=2)+'\n')
print('species',len(c['pokemon']),'moves',len(c['moves']),'new',len(added),'pokeapi_fallbacks',sum(v is None for pair in mapping.values() for v in pair))
