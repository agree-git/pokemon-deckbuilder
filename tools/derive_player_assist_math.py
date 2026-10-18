#!/usr/bin/env python3
"""Derive v18 aimed attacks from frozen boss protection rules."""
import argparse,hashlib,re
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument('--game-dir',type=Path,required=True);p=a.parse_args().game_dir
source=p/'scripts/tactics/boss_battle_effects_p3.gd'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='87a91b071f11c968d4c65fc00d4e270197bb2a0ad5fe07adfcdb2d09b56ccace'
src=source.read_text();starts=list(re.finditer(r'^static func (\w+)\(',src,re.M))
fs={x[1]:src[x.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,x in enumerate(starts)}
code='class_name PlayerMoveAssistMath\nextends RefCounted\n## v18: aimed attacks bypass aerial evasion, preserving native guards and substitutes.\n'
for name in ['player_damage','filter_view','on_card','card_notice']:
 body=fs[name].replace('static func '+name,'static func boss_'+name)
 body=body.replace(' or airborne_miss(b,view)','').replace(' or airborne_miss(b,v)','').replace('[479,615]','[479,614]')
 body=re.sub(r'^    if airborne_miss\(b,original\):\n(?:        .*\n)+','',body,flags=re.M)
 body=re.sub(r'^    if airborne_miss\(b,v\):.*\n','',body,flags=re.M)
 for helper in fs:body=re.sub(r'(?<![.\w])'+helper+r'\(','BossBattleEffectsP3.'+helper+'(',body)
 body=body.replace('TARGET_EFFECTS','BossBattleEffectsP3.TARGET_EFFECTS')
 code+=body
(p/'scripts/tactics/player_move_assist_math.gd').write_text(code)
