#!/usr/bin/env python3
"""Derive only type-sensitive NPC functions; published engines stay frozen."""
import argparse,hashlib,re
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument('--game-dir',type=Path,required=True);p=a.parse_args().game_dir
SOURCES={
 'boss_move_effects_p3.gd':('ca4fc3c94ce30ffa9bbe3f7807564fef5772bdcd17714f2e5a205629642ba933','BossMoveEffectsP3',[('preview','boss_preview')]),
 'player_move_air_fields.gd':('692651feffe3e330488c0d48749e239042863e7e477d84976316156d9803cdab','PlayerMoveAirFields',[('enemy_math','field_math'),('enemy_critical','critical_math')]),
 'player_move_items.gd':('c187c74d787a8f0c15bc1b01a79a426de303c9405539a0dfa5443ab8f47d1e93','PlayerMoveItems',[('enemy_math','arrow_math')])}
code='class_name PlayerMoveReactionMath\nextends RefCounted\n## v20: generated NPC type hooks after conditional/field typing, before damage math.\n'
for name,(sha,base,methods) in SOURCES.items():
 path=p/'scripts/tactics'/name;assert hashlib.sha256(path.read_bytes()).hexdigest()==sha,name
 src=path.read_text();starts=list(re.finditer(r'^static func (\w+)\(',src,re.M));fs={m[1]:src[m.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,m in enumerate(starts)}
 for method,title in methods:
  body=fs[method].replace('static func '+method,'static func '+title)
  for helper in fs:body=re.sub(r'(?<![.\w])'+helper+r'\(',base+'.'+helper+'(',body)
  if title=='boss_preview':
   body=body.replace('"boss_moves_version":VERSION','"boss_moves_version":BossMoveEffectsP3.VERSION')
   anchor='    a["damage_class"] = move["damage_class"]\n';assert body.count(anchor)==1
   body=body.replace(anchor,'    var converted:=PlayerMoveReactions.move_type(b,actor,move)\n    if converted["type"]!=move["type"]:\n        move=converted;a["type"]=move["type"];a["copied_view"]=move.duplicate(true)\n'+anchor)
  elif title in ['field_math','critical_math']:
   anchor='m=PlayerMoveAirFields.attack_view(b,';assert anchor in body
   body=re.sub(r'(m=PlayerMoveAirFields.attack_view\(b,(?:b.enemy\(\)|actor),(?:p|target),m\))',r'\1;m=PlayerMoveReactions.move_type(b,b.enemy(),m)',body)
  else:
   body=body.replace('m["type"]="ground"','m["type"]=PlayerMoveReactions.move_type(b,b.enemy(),m)["type"]')
   body=body.replace('b.multiplier("ground",p,614)','b.multiplier(str(m["type"]),p,614)')
  code+=body
(p/'scripts/tactics/player_move_reaction_math.gd').write_text(code)
