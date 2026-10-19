#!/usr/bin/env python3
"""Derive v21 equipment damage/execute hooks without modifying published engines."""
import argparse,hashlib,re
from pathlib import Path
SOURCES={'player_move_exchange.gd': ['afed60ae603a042a80c9a469eb49ab09f3534433bead99787051aabc1173d667', 'PlayerMoveExchange', [('raw_damage', 'player_base'), ('enemy_math', 'enemy_exchange')]], 'player_move_item_math.gd': ['0dd6db5f4289580bfc558a5ae21a2ac72ce774f1ed1bc428179a5714088493dc', 'PlayerMoveItemMath', [('arrow_base', 'arrow_base')]], 'player_move_reaction_math.gd': ['4bb0f8416648f120905cabb590578e55d62832e6280c6f9a361bb7a6b85e4f99', 'PlayerMoveReactionMath', [('boss_preview', 'boss_preview'), ('field_math', 'enemy_field'), ('critical_math', 'enemy_critical'), ('arrow_math', 'enemy_arrow')]], 'boss_move_effects_p3.gd': ['ca4fc3c94ce30ffa9bbe3f7807564fef5772bdcd17714f2e5a205629642ba933', 'BossMoveEffectsP3', [('_damage_preview', 'damage_preview'), ('_unique_conditional', 'unique_conditional'), ('execute', 'boss_execute'), ('_execute', 'boss_perform')]]}
a=argparse.ArgumentParser();a.add_argument('--game-dir',type=Path,required=True);p=a.parse_args().game_dir
code='class_name HeldItemMath\nextends RefCounted\n## v21: pinned math with official equipment and contact-KO handling.\n'
for name,(sha,base,methods) in SOURCES.items():
 path=p/'scripts/tactics'/name;assert hashlib.sha256(path.read_bytes()).hexdigest()==sha,name
 src=path.read_text();starts=list(re.finditer(r'^static func (\w+)\(',src,re.M));fs={m[1]:src[m.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,m in enumerate(starts)}
 for method,title in methods:
  body=fs[method].replace('static func '+method,'static func '+title)
  for helper in fs:body=re.sub(r'(?<!func )(?<![.\w])'+helper+r'\(',base+'.'+helper+'(',body)
  body=body.replace('PokemonStats.damage(','HeldItems.calculate(b,')
  if title=='boss_preview':body=body.replace('BossMoveEffectsP3._damage_preview(','HeldItemMath.damage_preview(').replace('BossMoveEffectsP3._unique_conditional(','HeldItemMath.unique_conditional(')
  if title=='unique_conditional':body=body.replace('PokemonStats.effective(','HeldItems.effective(b,')
  if title=='boss_execute':body=body.replace('BossMoveEffectsP3._execute(','HeldItemMath.boss_perform(')
  if title=='boss_perform':
   body=body.replace('if not target.alive(): break','if not target.alive() or not actor.alive(): break')
   body=body.replace('if target.alive() and not a["immune"]:','if target.alive() and actor.alive() and not a["immune"]:')
   body=body.replace('lost += before-target.hp','lost += int(b.held_attack.get("last_loss",before-target.hp))')
  code+=body
(p/'scripts/tactics/held_item_math.gd').write_text(code)
