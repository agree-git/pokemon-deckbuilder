#!/usr/bin/env python3
"""Derive v17 Arrow math/air exceptions without editing published engines."""
import argparse,hashlib,re
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument("--game-dir",type=Path,required=True);p=a.parse_args().game_dir
assert hashlib.sha256((p/"scripts/tactics/player_move_exchange.gd").read_bytes()).hexdigest()=="afed60ae603a042a80c9a469eb49ab09f3534433bead99787051aabc1173d667"
assert hashlib.sha256((p/"scripts/tactics/player_move_rules.gd").read_bytes()).hexdigest()=="fa404fce13604640400a3b1ae21ed3f67727ead1ef83ada4e88f191efbf18dee"
def funcs(src):
 starts=list(re.finditer(r'^static func (\w+)\(',src,re.M))
 return {x[1]:src[x.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,x in enumerate(starts)}
code='class_name PlayerMoveItemMath\nextends RefCounted\n## v17: generated frozen math with an explicit move ID and corrected air exception.\n'
for file,method,title,base in [('player_move_exchange.gd','raw_damage','arrow_base','PlayerMoveExchange'),('player_move_rules.gd','enemy_preview','enemy_rules','PlayerMoveRules')]:
 fs=funcs((p/'scripts/tactics'/file).read_text());body=fs[method].replace('static func '+method,'static func '+title)
 for name in fs:body=re.sub(r'(?<![.\w])'+name+r'\(',base+'.'+name+'(',body)
 if method=='raw_damage':body=body.replace('b.multiplier(str(v["type"]),target)','b.multiplier(str(v["type"]),target,int(v["move_id"]))')
 else:
  body=body.replace('[16,87,239,327,479,542,615]','[16,87,239,327,479,542,614]')
  body=body.replace('var mid:=int(a.get("effective_move",a.get("move_id",0)))','var mid:=int(a.get("copied_view",{}).get("move_id",a.get("effective_move",a.get("move_id",0))))')
 code+=body
(p/'scripts/tactics/player_move_item_math.gd').write_text(code)
