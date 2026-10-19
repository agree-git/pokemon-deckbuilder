#!/usr/bin/env python3
"""Import contact/sound/substitute facts without executing the external TypeScript."""
import argparse, hashlib, json, re
from pathlib import Path

COMMIT = '7b02eb39878f4b486f658a752b38c161379bd352'
BLOB = 'd240d3e4d4e32fa9ded709110d80a20133b105ce'
SOURCE_SHA = '61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7'
BASE_SHA = 'd2fa0fa25059099f5290139a261a71d8deb12b663985d451ba4e51c11e470a87'
FLAGS = {'contact':1, 'sound':9, 'bypasssub':14}

def generate(game, cache):
    raw=(cache/'moves.ts').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==SOURCE_SHA
    assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BLOB
    prior_path=game/'data/player_move_bulk_v23.json'
    assert hashlib.sha256(prior_path.read_bytes()).hexdigest()==BASE_SHA
    prior=json.loads(prior_path.read_text());old=json.loads((game/'data/player_move_cards_v10.json').read_text())['flags']
    rows={}
    for m in re.finditer(r'(?ms)^\t(?:"([^"\n]+)"|(\w+)): \{\n(.*?)(?=^\t(?:"[^"\n]+"|\w+): \{|^\};)',raw.decode()):
        body=m[3];num=re.search(r'^\t\tnum: (-?\d+),',body,re.M);flags=re.search(r'^\t\tflags: \{([^}]*)\}',body,re.M)
        if num and 1<=int(num[1])<=919:
            rows[str(int(num[1]))]={'name':m[1] or m[2], 'flags':dict((k,int(v)) for k,v in re.findall(r'(\w+): (\d+)',flags[1] if flags else '')), 'breaks':bool(re.search(r'^\t\tbreaksProtect: true,',body,re.M))}
    assert len(rows)==901
    flags={};changed={};fallback=[]
    for id in range(1,920):
        key=str(id);values=set(old.get(key,[]));delta=[]
        if key in rows:
            for name,n in FLAGS.items():
                present=bool(rows[key]['flags'].get(name,0))
                if present!=(n in values):delta.append(name)
                if present:values.add(n)
                else:values.discard(n)
        else:fallback.append(id)
        flags[key]=sorted(values)
        if delta:changed[key]=delta
    # Pokemon Showdown shares physical/special Z-move entries; preserve old counterparts.
    assert fallback==list(range(623,658,2))
    assert not rows['887']['flags'].get('protect') and not rows['910']['flags'].get('protect')
    guard=sorted({165,364,467,566,593,621,887,910}|{int(k) for k,v in rows.items() if v['breaks']})
    mighty=json.loads(json.dumps(prior['moves']['910']))
    for key in ['stat_changes','stat_target']:mighty.pop(key,None)
    mighty['bulk_rule']='bypass';mighty['card_notes']=['보호 관통 · 보호 상태를 해제하지 않음 · 대타 적용 · 상대 공격 저하 없음']
    drill=json.loads(json.dumps(prior['moves']['887']));drill['bulk_rule']='bypass';drill['card_notes']=['보호 관통 · 보호 상태를 해제하지 않음 · 대타는 그대로 적용']
    return {'schema_version':1,'route_version':24,'player_moves_version':16,'source':{'repository':'smogon/pokemon-showdown','commit':COMMIT,'blob':BLOB,'sha256':SOURCE_SHA,'path':'data/moves.ts'},'base_sha256':BASE_SHA,'flags':flags,'changed':changed,'fallback':fallback,'breaks_guard':guard,'moves':{'887':drill,'910':mighty}}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--cache-dir',type=Path,required=True);a=p.parse_args();d=generate(a.game_dir,a.cache_dir)
    (a.game_dir/'data/player_move_interactions_v24.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    print(len(d['flags']),'moves;',len(d['changed']),'changed;',sum(map(len,d['changed'].values())),'flag corrections; guard breakers',d['breaks_guard'])
