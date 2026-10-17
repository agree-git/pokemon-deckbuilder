#!/usr/bin/env python3
"""Install audited pinned PNG/Ogg assets from sparse upstream checkouts; no fallback art."""
import argparse,concurrent.futures,hashlib,json,subprocess
from pathlib import Path
from PIL import Image
SPRITES_REV='289e842364648ec0495ae4ba12f48d5cbfbf670b';CRIES_REV='b3a9044bb839b5e3152aaa536c7b463a0fcf0140'
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args();g=a.game_dir;c=a.cache_dir
 data=json.loads((g/'data/pokedex_expansion.json').read_text());manifest=json.loads((g/'assets/sources/manifest.json').read_text());cry_manifest=json.loads((g/'assets/audio/cries/manifest.json').read_text());cry_records={int(x['id']):x for x in cry_manifest['files']};byid={int(x['id']):x for x in data['pokemon']};new=[]
 for sid,plan in data['asset_plan'].items():
  id=int(sid)
  for back in [False,True]:
   rel='assets/pokemon/'+('back/' if back else 'front/')+f'{id:03d}.png';dest=g/rel
   if dest.exists():
    if rel not in manifest or sha(dest.read_bytes())!=manifest[rel]["sha256"]:raise RuntimeError("Existing sprite has unrecorded edits: "+rel)
    continue
   source='sprites/pokemon/'+('back/' if back else '')+plan['sprite_file']+'.png';raw=(c/'sprites'/source).read_bytes()
   with Image.open(c/'sprites'/source) as im:
    assert im.format=='PNG' and im.convert('RGBA').getbbox(),(id,source,'empty sprite');size=im.size
   dest.write_bytes(raw);manifest[rel]={'url':f'https://raw.githubusercontent.com/PokeAPI/sprites/{SPRITES_REV}/{source}','sha256':sha(raw),'source_sha256':sha(raw),'transformation':'none','width':size[0],'height':size[1],'source_repository':'PokeAPI/sprites','source_note':'Gen5 style collection; National Dex650+ includes credited Smogon community artwork. PNG bytes preserved.','shared_visual':plan['shared_visual'],'source_form_id':plan['source_form_id']}
  cry_path=g/"assets/audio/cries"/f"{id}.ogg"
  if id not in cry_records or not cry_path.exists():new.append((id,plan))
  elif sha(cry_path.read_bytes())!=cry_records[id]["sha256"]:raise RuntimeError("Existing cry has unrecorded edits: "+str(id))
 def cry(pair):
  id,plan=pair;source='cries/pokemon/latest/'+str(plan['cry_id'])+'.ogg';raw=(c/'cries'/source).read_bytes();original=sha(raw);transformation='none';dest=g/'assets/audio/cries'/f'{id}.ogg'
  if not raw.startswith(b'OggS'):
   raw=subprocess.check_output(['ffmpeg','-v','error','-i','pipe:0','-c:a','libvorbis','-q:a','6','-f','ogg','pipe:1'],input=raw);transformation='Upstream misnamed audio transcoded to actual Ogg Vorbis q6'
  dest.write_bytes(raw);info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(dest)]));assert info['streams'][0]['codec_name']=='vorbis' and float(info['format']['duration'])>0
  pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(dest),'-f','s16le','-acodec','pcm_s16le','-']);assert any(pcm),(id,'silent cry')
  return {'id':id,'bytes':len(raw),'sha256':sha(raw),'decoded_pcm_sha256':sha(pcm),'duration':float(info['format']['duration']),'url':f'https://raw.githubusercontent.com/PokeAPI/cries/{CRIES_REV}/{source}','source_pokemon_id':plan['cry_id'],'source_sha256':original,'transformation':transformation}
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
  for n,record in enumerate(pool.map(cry,new)):
   cry_records[record['id']]=record
   if n%100==0:print('Decoded added cries',n+1,'/',len(new),flush=True)
 cry_manifest['files']=sorted(cry_records.values(),key=lambda r:r['id']);(g/'assets/audio/cries/manifest.json').write_text(json.dumps(cry_manifest,ensure_ascii=False,indent=2)+'\n');(g/'assets/sources/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 for key in data['evolution_items']:
  dest=g/'assets/items'/(key+'.png')
  if dest.exists():continue
  source='sprites/items/'+key.replace('_','-')+'.png';raw=(c/'sprites'/source).read_bytes()
  with Image.open(c/'sprites'/source) as im:assert im.convert('RGBA').getbbox()
  dest.write_bytes(raw);manifest[dest.relative_to(g).as_posix()]={'url':f'https://raw.githubusercontent.com/PokeAPI/sprites/{SPRITES_REV}/{source}','sha256':sha(raw),'transformation':'none'}
 (g/'assets/sources/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 for name,target in [('README.md','POKEAPI_SPRITES_README.md.txt'),('CONTRIBUTING_SPRITES.md','POKEAPI_SPRITES_CONTRIBUTING.md.txt')]: (g/'assets/sources'/target).write_bytes((c/'sprites'/name).read_bytes())
 provenance={'runtime_data_sha256':sha((g/'data/pokedex_expansion.json').read_bytes()),'species':1025,'runtime_forms':len(byid),'new_cries':len(set(byid)-{int(x['id']) for x in json.loads((g/'data/catalog.json').read_text())['pokemon']}),'source_data':data['csv_sources'],'sprite_revision':SPRITES_REV,'cry_revision':CRIES_REV,'scope':data['scope'],'same_appearance_forms':'Mothim Burmy-cloak origin and pre-Vivillon pattern carriers share their actual unchanged appearance, recorded per file. Cosmetic forms share the upstream cry of their Pokemon ID. No generic art or synthesized replacement cries.','licensing':'Original Pokemon rights remain with Nintendo / Creatures / GAME FREAK. Source repository notices retained; code MIT does not license character art/audio.'}
 (g/'assets/sources/pokedex_expansion.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n');print('Complete:',len(byid),'front/back pairs and cries;',len(new),'cries added',flush=True)
if __name__=='__main__':main()
