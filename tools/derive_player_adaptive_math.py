#!/usr/bin/env python3
"""Derive v26 hooks from SHA-pinned, frozen v21/v24 inputs."""
import argparse,hashlib,re
from pathlib import Path
PINS={'held_item_math.gd':'f597e3926119d3d690db14771643f0538085b8a78188d74d08bedb963dfb9817','player_interaction_hooks.gd':'05e6d86180b26b1c0bf146093fce3e8131a3b645aa856df4c11a3e9bd70ac567'}
MATH=['player_base','enemy_exchange','boss_preview','enemy_field','enemy_critical','damage_preview','unique_conditional']
CONTACT={'held_damage':'v','item_preview':'v','player_after_enemy':'a','boss_filter_view':'v','boss_after_card':'v','aimed_filter_view':'v','bulk_after_enemy':'a'}
def contact_calls(body,view):
    marker='PlayerMoveInteractions.flag(';start=0
    while (at:=body.find(marker,start))>=0:
        end=at+len(marker);depth=1
        while depth:
            depth+=(body[end]=='(')-(body[end]==')');end+=1
        args=body[at+len(marker):end-1]
        if args.rsplit(',',1)[-1].strip()=='1':body=body[:at]+'PlayerMoveAdaptive.contact('+view+')'+body[end:];start=at+len('PlayerMoveAdaptive.contact('+view+')')
        else:start=end
    return body
def generate(game):
    output='class_name PlayerAdaptiveMath\nextends RefCounted\n## v26: generated from frozen math/hooks; dynamic category/contact and move-ID affinity.\n'
    for file,sha in PINS.items():
        source=(game/'scripts/tactics'/file).read_text();assert hashlib.sha256(source.encode()).hexdigest()==sha,file
        starts=list(re.finditer(r'^static func (\w+)\(',source,re.M));funcs={m[1]:source[m.start():starts[i+1].start() if i+1<len(starts) else len(source)] for i,m in enumerate(starts)}
        base='HeldItemMath' if file=='held_item_math.gd' else 'PlayerInteractionHooks'
        for name in MATH if base=='HeldItemMath' else funcs:
            body=funcs[name]
            for helper in funcs:
                body=re.sub(r'(?<!func )(?<![.\w])'+helper+r'\(',base+'.'+helper+'(',body)
            for helper in MATH:body=body.replace('HeldItemMath.'+helper+'(','PlayerAdaptiveMath.'+helper+'(')
            body=body.replace('PlayerInteractionHooks.','PlayerAdaptiveMath.')
            body=body.replace('b.multiplier(str(v["type"]),target)','b.multiplier(str(v["type"]),target,int(v["move_id"]))')
            body=body.replace('b.multiplier(str(m["type"]),target)','b.multiplier(str(m["type"]),target,int(m["move_id"]))').replace('b.multiplier(m["type"],target)','b.multiplier(m["type"],target,int(m["move_id"]))').replace('b.multiplier(move["type"],target)','b.multiplier(move["type"],target,int(move["move_id"]))')
            body=body.replace('b.multiplier(str(v.get("type","normal")),p)','b.multiplier(str(v.get("type","normal")),p,PlayerMoveInteractions.move_id(v))')
            if name in CONTACT:body=contact_calls(body,CONTACT[name])
            if name=='boss_preview':body=body.replace('    var converted:=PlayerMoveReactions.move_type(b,actor,move)','    move=PlayerMoveAdaptive.enemy_move(b,actor,target,move)\n    var converted:=PlayerMoveReactions.move_type(b,actor,move)')
            if name=='enemy_field':body=body.replace('m=PlayerMoveAirFields.attack_view(b,b.enemy(),p,m);m=PlayerMoveReactions.move_type(b,b.enemy(),m)','m=PlayerMoveAirFields.attack_view(b,b.enemy(),p,m);m=PlayerMoveAdaptive.enemy_move(b,b.enemy(),p,m);m=PlayerMoveReactions.move_type(b,b.enemy(),m)')
            output+=body
    return output
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    code=generate(a.game_dir);(a.game_dir/'scripts/tactics/player_adaptive_math.gd').write_text(code);print(len(re.findall(r'^static func ',code,re.M)),'derived hooks')
