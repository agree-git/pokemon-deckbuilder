#!/usr/bin/env python3
"""Build the National Dex expansion from pinned PokeAPI CSVs; preserve legacy inputs."""
import argparse,collections,csv,hashlib,json,re
from pathlib import Path
from move_presentation import presentation

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args();g=a.game_dir;c=a.cache_dir
 def rows(n):return list(csv.DictReader((c/'csv'/(n+'.csv')).open(encoding='utf-8')))
 def read(n):return json.loads((g/'data'/(n+'.json')).read_text())
 species={int(x['id']):x for x in rows('pokemon_species')};pokemon={int(x['id']):x for x in rows('pokemon')};forms=rows('pokemon_forms');forms_by_id={int(x['id']):x for x in forms};defaults={int(x['species_id']):int(x['id']) for x in pokemon.values() if x['is_default']=='1'}
 names={int(x['pokemon_species_id']):x['name'] for x in rows('pokemon_species_names') if x['local_language_id']=='3'}
 form_names={int(x['pokemon_form_id']):x['form_name'] for x in rows('pokemon_form_names') if x['local_language_id']=='3'}
 type_keys={int(x['id']):x['identifier'] for x in rows('types')};type_names={x['key']:x['name'] for x in read('catalog')['types']};types=collections.defaultdict(list);form_types=collections.defaultdict(list)
 for x in rows('pokemon_types'):types[int(x['pokemon_id'])].append((int(x['slot']),type_keys[int(x['type_id'])]))
 for x in rows('pokemon_form_types'):form_types[int(x['pokemon_form_id'])].append((int(x['slot']),type_keys[int(x['type_id'])]))
 excluded={};selected=[];used_ids=set()
 for f in forms:
  fid=int(f['id']);pk=int(f['pokemon_id']);dex=int(pokemon[pk]['species_id']);key=f['identifier']
  reason=''
  if f['is_mega']=='1' or f['is_battle_only']=='1':reason='Temporary battle-only transformation (out of requested scope)'
  elif pk!=dex and key.startswith(('koraidon-','miraidon-')):reason='Travel animation pose, not a separate permanent battle form'
  elif key=='eternatus-eternamax':reason='Scripted temporary boss transformation despite upstream battle-only flag'
  elif key=='arceus-unknown':reason='Obsolete unknown type, outside current eighteen types'
  if reason:excluded[str(fid)]={'key':key,'reason':reason};continue
  id=pk if f['is_default']=='1' else 20000+fid
  assert id not in used_ids,(id,key);used_ids.add(id);selected.append((id,pk,dex,f))
 assert set(range(1,1026)).issubset(used_ids)
 by_form={int(f['id']):id for id,pk,dex,f in selected};by_id={id:(pk,dex,f) for id,pk,dex,f in selected};by_dex=collections.defaultdict(list)
 for id,pk,dex,f in selected:by_dex[dex].append(id)
 old={int(x['id']):x for x in read('catalog')['pokemon']};legacy_ids=set(old)
 ability_names={int(x['ability_id']):x['name'] for x in rows('ability_names') if x['local_language_id']=='3'};abilities={int(x['id']):{'id':int(x['id']),'key':x['identifier'],'name':ability_names.get(int(x['id']),x['identifier'])} for x in rows('abilities')};pk_abilities=collections.defaultdict(list)
 for x in rows('pokemon_abilities'):
  pk_abilities[int(x['pokemon_id'])].append({'id':int(x['ability_id']),'hidden':x['is_hidden']=='1','slot':int(x['slot'])})
 stats=collections.defaultdict(dict)
 for x in rows('pokemon_stats'):stats[int(x['pokemon_id'])][['hp','attack','defense','special_attack','special_defense','speed'][int(x['stat_id'])-1]]=int(x['base_stat'])
 groups={int(x['id']):x for x in rows('version_groups')};learn=collections.defaultdict(lambda:collections.defaultdict(list));compatible=collections.defaultdict(lambda:collections.defaultdict(set));nonlevel=collections.defaultdict(lambda:collections.defaultdict(set))
 # Stream the largest CSV rather than retaining every historical learnset row.
 with (c/'csv/pokemon_moves.csv').open(encoding='utf-8') as file:
  for x in csv.DictReader(file):
   pk=int(x['pokemon_id']);vg=int(x['version_group_id']);move=int(x['move_id'])
   compatible[pk][vg].add(move)
   if x['pokemon_move_method_id']!='1':nonlevel[pk][vg].add(move)
   if x['pokemon_move_method_id']=='1':learn[pk][vg].append((max(1,int(x['level'])),int(x['order'] or 0),move))
 move_names={int(x['move_id']):x['name'] for x in rows('move_names') if x['local_language_id']=='3'};metas={int(x['move_id']):x for x in rows('move_meta')};changes=collections.defaultdict(list)
 for x in rows('move_meta_stat_changes'):changes[int(x['move_id'])].append({'stat_id':int(x['stat_id']),'change':int(x['change'])})
 moves={};move_views=[]
 for x in rows('moves'):
  mid=int(x['id']);t=int(x['type_id'])
  if t not in range(1,19):continue
  meta=metas.get(mid,{});st=changes[mid];vfx=presentation(x,meta,st)
  raw={'id':mid,'name':move_names.get(mid,x['identifier']),'type':type_keys[t],'power':int(x['power'] or 0),'category':int(x['damage_class_id']),'target':int(x['target_id']),'stats':st,'ailment':int(meta.get('meta_ailment_id') or 0),'healing':int(meta.get('healing') or 0),'drain':int(meta.get('drain') or 0),'vfx':vfx,'accuracy':int(x['accuracy'] or 100),'pp':int(x['pp'] or 0),'priority':int(x['priority'] or 0),'effect_id':int(x['effect_id'] or 0)}
  moves[str(mid)]=raw;move_views.append({'id':mid,'key':x['identifier'],'name':raw['name'],'type':raw['type'],'category':{1:'status',2:'physical',3:'special'}[raw['category']],'power':raw['power'],'accuracy':raw['accuracy'],'stat_changes':st,'ailment_chance':int(meta.get('ailment_chance') or 0),'vfx':vfx})
 move_ids={int(x) for x in moves};progress={};learn_sources={};entries=[];assets={};missing_labels=[]
 regions={1:'kanto',2:'johto',3:'hoenn',4:'sinnoh',5:'unova',6:'kalos',7:'alola',8:'galar',9:'paldea'}
 # Remaining labels are either standardized Korean terms or explicit cosmetic labels.
 labels={'alola':'알로라','galar':'가라르','hisui':'히스이','paldea-combat-breed':'팔데아 컴뱃종','paldea-blaze-breed':'팔데아 블레이즈종','paldea-aqua-breed':'팔데아 워터종','bloodmoon':'붉은 달','female':'암컷','male':'수컷','totem':'주인','starter':'파트너','own-tempo':'마이페이스','battle-bond':'유대변화 특성','eternal':'영원의 꽃','original':'오리지널','white-striped':'백색근','three-segment':'세 마디','family-of-three':'세 식구','roaming':'도보폼','dada':'아빠','ice':'백마 탄 모습','shadow':'흑마 탄 모습','dusk':'황혼의 갈기','dawn':'새벽의 날개','rapid-strike':'연격의 태세'}
 labels.update(type_names)
 labels.update({'spiky-eared':'삐쭉귀','rock-star':'하드록','belle':'마담','pop-star':'아이돌','phd':'닥터','libre':'마스크드','cosplay':'옷갈아입기','sandy':'모래땅','trash':'슈레','polar':'설국','tundra':'빙설','continental':'대륙','garden':'정원','elegant':'기품','meadow':'꽃밭','modern':'모던','marine':'마린','archipelago':'군도','high-plains':'황야','sandstorm':'사진','river':'대하','monsoon':'스콜','savanna':'사바나','sun':'태양','ocean':'오션','jungle':'정글','fancy':'팬시','poke-ball':'볼','antique':'진품','origin':'오리진폼','therian':'영물폼','paldea':'팔데아','droopy':'늘어진 모습','stretchy':'뻗은 모습','blue-plumage':'블루 페더','yellow-plumage':'옐로 페더','white-plumage':'화이트 페더'})
 flavours={'vanilla-cream':'밀키바닐라','ruby-cream':'밀키루비','matcha-cream':'밀키말차','mint-cream':'밀키민트','lemon-cream':'밀키레몬','salted-cream':'밀키솔트','ruby-swirl':'루비믹스','caramel-swirl':'캐러멜믹스','rainbow-swirl':'트리플믹스'}
 sweets={'strawberry':'딸기','berry':'베리','love':'하트','star':'스타','clover':'클로버','flower':'플라워','ribbon':'리본'}
 for flavour,ko in flavours.items():
  for sweet,sko in sweets.items():labels[flavour+'-'+sweet+'-sweet']=ko+' · '+sko+'사탕'
 def label(fid,f):
  if fid in form_names and form_names[fid]:return form_names[fid]
  key=f['form_identifier']
  if key in labels:return labels[key]
  if key.startswith('totem-'):return '주인 · '+labels.get(key[6:],key[6:])
  missing_labels.append((fid,f['identifier'],key));return key
 for id,pk,dex,f in selected:
  s=species[dex];fid=int(f['id']);national=id==dex;regional=next((x for x in ['alola','galar','hisui','paldea'] if x in pokemon[pk]['identifier'].split('-')),None)
  if dex == 25:regional=None
  name=names[dex] if national else names[dex]+' ('+label(fid,f)+')'
  parent=int(s['evolves_from_species_id'] or 0)
  if pk == 10149:regional='alola'
  if not national and parent:
   match=[rid for rid in by_dex[parent] if by_id[rid][2]['form_identifier']==f['form_identifier']]
   if match:parent=match[0]
   elif regional:
    regional_parents=[rid for rid in by_dex[parent] if regional in pokemon[by_id[rid][0]]['identifier'].split('-')]
    if regional_parents:parent=regional_parents[0]
  if pk in [10061,10080,10081,10082,10083,10084,10085,10094,10095,10096,10097,10098,10099,10148,10158,10160,10272]:parent=0
  ts=[t for _,t in sorted(form_types[fid] or types[pk])];assert all(t in type_names for t in ts)
  entry={'id':id,'dex_id':dex,'key':f['identifier'],'name':name,'generation':int(s['generation_id']),'region':regional or regions[int(s['generation_id'])],'evolves_from':parent,'is_baby':s['is_baby']=='1','is_legendary':s['is_legendary']=='1','is_mythical':s['is_mythical']=='1','types':ts,'front':f'res://assets/pokemon/front/{id:03d}.png','back':f'res://assets/pokemon/back/{id:03d}.png','form':f['form_identifier'] if not national else '', 'regional':regional or '', 'source_pokemon_id':pk,'source_form_id':fid,'form_generation':int(groups[int(f['introduced_in_version_group_id'])]['generation_id']),'gender_rate':int(s['gender_rate']),'abilities':sorted(pk_abilities[pk],key=lambda x:x['slot']),'height_dm':int(pokemon[pk]['height']),'weight_hg':int(pokemon[pk]['weight'])}
  if id in old:
   # Preserve every historical visible name/type and old combat base-stat row.
   entry.update(old[id]);entry['dex_id']=dex
  entries.append(entry)
  source_pk=pk;versions=learn[source_pk]
  if not versions:source_pk=defaults[dex];versions=learn[source_pk]
  assert versions,(id,f['identifier'],'no level-up source')
  # Legends Z-A replaces levels with real-time upgrade metadata for some species.
  # Pick the latest complete level-up table, preserving traditional level learning.
  vg=max(versions,key=lambda v:int(groups[v]['order']));ls=[];seen=set()
  for level,order,move in sorted(set(versions[vg])):
   if move not in move_ids or (level,move) in seen:continue
   ls.append({'level':level,'move':move});seen.add((level,move))
  assert ls and any(x['level']<=5 for x in ls),(id,'no starting move')
  progress[str(id)]={'growth_rate':int(s['growth_rate_id']),'base_experience':int(pokemon[pk]['base_experience'] or pokemon[defaults[dex]]['base_experience'] or 200),'learnset':ls,'compatible_moves':sorted(compatible[source_pk][vg]&move_ids),'nonlevel_moves':sorted(nonlevel[source_pk][vg]&move_ids)}
  learn_sources[str(id)]={'pokemon_id':source_pk,'version_group':vg,'version':groups[vg]['identifier'],'shared_base_learnset':source_pk!=pk}
  filename=str(pk)+('' if f['is_default']=='1' else '-'+f['form_identifier'])
  # Burmy-origin Mothim and pre-Vivillon pattern carriers are visually identical.
  shared_visual=dex in [414,664,665] and f['is_default']=='0'
  assets[str(id)]={'sprite_file':str(pk) if shared_visual else filename,'cry_id':pk,'shared_visual':shared_visual,'source_form_id':fid}
 # All supported evolution branches, choosing the latest default condition per pair.
 itemrows={int(x['id']):x for x in rows('items')};itemnames={int(x['item_id']):x['name'] for x in rows('item_names') if x['local_language_id']=='3'};rules={};itemdefs={};triggers={int(x['id']):x['identifier'] for x in rows('evolution_triggers')}
 entries_by_id={x['id']:x for x in entries}
 for x in rows('pokemon_evolution'):
  if x['is_default']!='1':continue
  dex=int(x['evolved_species_id']);parent=int(species[dex]['evolves_from_species_id'] or 0)
  if not parent:continue
  source=by_form.get(int(x['required_pokemon_form_id'])) if x['required_pokemon_form_id'] else parent
  target=by_form.get(int(x['evolved_pokemon_form_id'])) if x['evolved_pokemon_form_id'] else dex
  if source not in used_ids or target not in used_ids:continue
  conditions={k:(int(v) if re.fullmatch(r'-?\d+',v) else v) for k,v in x.items() if v and k not in ['id','evolved_species_id','required_pokemon_form_id','evolved_pokemon_form_id','is_default','version_group_id'] and v!='0'}
  # Aesthetic lineage carriers inherit the same stage evolution below.
  trigger=int(x['evolution_trigger_id']);item=int(x['trigger_item_id'] or x['held_item_id'] or 0);method='item' if item or trigger in [2,3,6,7,17] else 'level'
  itemkey=''
  if item:
   itemkey=itemrows[item]['identifier'].replace('-','_');itemkey={'up_grade':'upgrade','scroll_of_darkness':'darkness_scroll'}.get(itemkey,itemkey);itemdefs[itemkey]={'name':itemnames.get(item,itemrows[item]['identifier']),'price':180 if trigger==3 else 220,'stock':1}
  elif trigger in [2,6,7,17]:itemkey={2:'linking_cord',6:'darkness_scroll',7:'waters_scroll',17:'metal_candy'}[trigger];itemdefs[itemkey]={'name':{2:'연결의끈',6:'악의족자',7:'물의족자',17:'멜탄의사탕'}[trigger],'price':220,'stock':1}
  external=any(k in conditions for k in ['location_id','needs_overworld_rain','turn_upside_down','needs_multiplayer','near_special_rock','region_id','used_move_id','minimum_steps','minimum_damage_taken','condition_expression','nature_bitmask','party_species_id','party_type_id','trade_species_id']) or trigger not in [1,2,3,4,6,7,17] or x['time_of_day'] not in ['', 'day','night']
  rule={'from':source,'to':target,'level':max(1,int(x['minimum_level'] or 1)),'method':method,'item':itemkey,'prepare':external,'trigger':triggers[trigger],'conditions':conditions,'source_rule_id':int(x['id']),'version_group':int(x['version_group_id'])};pair=(source,target)
  if pair not in rules or int(groups[rule['version_group']]['order'])>=int(groups[rules[pair]['version_group']]['order']):rules[pair]=rule
 # Cosmetic descendants carry their colour/pattern through the complete family.
 for id,pk,dex,f in selected:
  if f['is_default']=='1':continue
  for (source,target),rule in list(rules.items()):
   if source!=pk:continue
   targetdex=entries_by_id[target]['dex_id'];matches=[rid for rid in by_dex[targetdex] if by_id[rid][2]['form_identifier']==f['form_identifier']]
   if matches:
    new=rule.copy();new.update({'from':id,'to':matches[0]});rules[(id,matches[0])]=new
 for entry in entries:
  incoming=[r['from'] for r in rules.values() if r['to']==entry['id']]
  if incoming and len(set(incoming))==1:entry['evolves_from']=incoming[0]
 # Correct parent-only cosmetic carrier links (e.g. evolved Vivillon pattern).
 for entry in entries:
  if entry['evolves_from'] not in used_ids:entry['evolves_from']=0
 rare_ids=set(json.loads(re.search(r'const IDS := (\[[^\n]+\])',(g/'scripts/tactics/rare_encounter.gd').read_text()).group(1)))
 biomes=read('biomes')
 for b in biomes:
  encounters=[]
  for e in entries:
   if e['types'] and b['type'] in e['types'] and not e['is_legendary'] and not e['is_mythical'] and e['id'] not in rare_ids and by_id[e['id']][2]['is_default']=='1':
    depth=0;current=e;visited=set()
    while current['evolves_from'] and current['id'] not in visited:
     visited.add(current['id']);depth+=1;current=entries_by_id[current['evolves_from']]
    tier='common' if depth==0 else ('uncommon' if depth==1 else 'rare');encounters.append({'pokemon_id':e['id'],'tier':tier,'weight':{'common':8,'uncommon':4,'rare':1}[tier]})
  assert encounters;b['encounters']=encounters;b['encounter_note']='전 세대 기본종·지역폼/상시폼 · 전설/환상은 조사와 폼 준비로 해금'
 data={'schema_version':1,'type_ids':{str(k):v for k,v in type_keys.items() if k in range(1,19)},'national_species_count':1025,'runtime_form_count':len(entries),'scope':'All National Dex species plus permanent regional, functional and cosmetic forms; excludes battle-only transformations, travel poses and obsolete unknown Arceus type','pokemon':entries,'moves':move_views,'move_definitions':moves,'stats':{str(id):stats[pk] for id,pk,dex,f in selected if id not in legacy_ids},'progression':progress,'learnset_sources':learn_sources,'abilities':abilities,'evolutions':sorted(rules.values(),key=lambda r:(r['from'],r['to'])),'evolution_items':itemdefs,'biomes':biomes,'excluded_forms':excluded,'asset_plan':assets,'csv_sources':json.loads((c/'csv_manifest.json').read_text())}
 (g/'data/pokedex_expansion.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8');(c/'missing_form_labels.json').write_text(json.dumps(missing_labels,ensure_ascii=False,indent=2)+'\n');print('National species1025 /runtime',len(entries),'/moves',len(moves),'/evolutions',len(rules),'/missing labels',len(missing_labels))
if __name__=='__main__':main()
