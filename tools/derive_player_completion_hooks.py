#!/usr/bin/env python3
"""Derive only passive recovery hooks; preserve all published engines."""
import argparse,hashlib,re
from pathlib import Path
PINS={'player_adaptive_math.gd':'bc68d6bad446a6698e40aea0adc1a4d57840f04214eb593948d6016b10923538','player_move_rules.gd':'fa404fce13604640400a3b1ae21ed3f67727ead1ef83ada4e88f191efbf18dee'}
def generate(game):
    out='class_name PlayerCompletionHooks\nextends RefCounted\n## v27: passive move healing respects the existing healing block.\n'
    for file,sha in PINS.items():
        p=game/'scripts/tactics'/file;assert hashlib.sha256(p.read_bytes()).hexdigest()==sha
        src=p.read_text();starts=list(re.finditer(r'^static func (\w+)\(',src,re.M));funcs={m[1]:src[m.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,m in enumerate(starts)}
        name='player_after_enemy' if file=='player_adaptive_math.gd' else 'start_player';base='PlayerAdaptiveMath' if file=='player_adaptive_math.gd' else 'PlayerMoveRules';body=funcs[name]
        for helper in funcs:body=re.sub(r'(?<!func )(?<![.\w])'+helper+r'\(',base+'.'+helper+'(',body)
        if name=='player_after_enemy':
            old='for group:String in ["roots","rings"]:';assert old in body
            body=body.replace(old,'for group:String in (["roots","rings"] if not PlayerMoveCompletion.healing_blocked(b,p) else []):')
        else:body=body.replace('if p==null or not p.alive():continue','if p==null or not p.alive() or PlayerMoveCompletion.healing_blocked(b,p):continue')
        out+=body
    return out
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args();code=generate(a.game_dir);(a.game_dir/'scripts/tactics/player_completion_hooks.gd').write_text(code);print('2 derived recovery hooks')
