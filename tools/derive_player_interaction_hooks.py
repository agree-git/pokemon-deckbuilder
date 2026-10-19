#!/usr/bin/env python3
"""Derive flag-sensitive hooks from pinned engines; never edit published sources."""
import argparse, hashlib, re
from pathlib import Path

SOURCES = {'held_items.gd': ('fb5b1376e136b81ebbdc2bb8924da69bcf2cbdfdf0d5953ee341b4f3dbfb4a01', 'HeldItems', [('on_damage', 'held_damage'), ('deal_damage', 'player_hits'), ('after_preview', 'item_preview')]), 'player_move_rules.gd': ('fa404fce13604640400a3b1ae21ed3f67727ead1ef83ada4e88f191efbf18dee', 'PlayerMoveRules', [('on_card', 'player_card'), ('after_enemy', 'player_after_enemy'), ('absorb', 'player_absorb')]), 'player_move_item_math.gd': ('0dd6db5f4289580bfc558a5ae21a2ac72ce774f1ed1bc428179a5714088493dc', 'PlayerMoveItemMath', [('enemy_rules', 'enemy_rules')]), 'boss_battle_effects_p3.gd': ('87a91b071f11c968d4c65fc00d4e270197bb2a0ad5fe07adfcdb2d09b56ccace', 'BossBattleEffectsP3', [('protected', 'boss_protected'), ('filter_view', 'boss_filter_view'), ('after_card', 'boss_after_card'), ('card_reason', 'boss_card_reason'), ('player_damage', 'boss_player_damage'), ('card_notice', 'boss_card_notice'), ('on_card', 'boss_on_card')]), 'player_move_assist_math.gd': ('b32d1800ad6633f1a7441eb59a8d7d73ae513f44acf595689d86d2ec4c38a0ea', 'PlayerMoveAssistMath', [('boss_filter_view', 'aimed_filter_view'), ('boss_on_card', 'aimed_on_card'), ('boss_player_damage', 'aimed_player_damage'), ('boss_card_notice', 'aimed_card_notice')]), 'player_move_bulk.gd': ('9dd65a105af21705e9f4c204855011649d39727be83a5159354ea55eafd04968', 'PlayerMoveBulk', [('after_enemy', 'bulk_after_enemy')])}

def generate(game):
    out='class_name PlayerInteractionHooks\nextends RefCounted\n## v24: pinned hooks with contact/sound/substitute facts and guard bypass.\n'
    redirects={base+'.'+old:'PlayerInteractionHooks.'+new for _,base,methods in SOURCES.values() for old,new in methods}
    for name,(sha,base,methods) in SOURCES.items():
        path=game/'scripts/tactics'/name;assert hashlib.sha256(path.read_bytes()).hexdigest()==sha,name
        src=path.read_text();starts=list(re.finditer(r'^static func (\w+)\(',src,re.M))
        fs={m[1]:src[m.start():starts[i+1].start() if i+1<len(starts) else len(src)] for i,m in enumerate(starts)}
        constants=re.findall(r'^const (\w+)',src,re.M)
        for old,new in methods:
            body=fs[old].replace('static func '+old,'static func '+new)
            for helper in fs:body=re.sub(r'(?<!func )(?<![.\w])'+helper+r'\(',base+'.'+helper+'(',body)
            for key in constants:body=re.sub(r'(?<![.\w])'+key+r'\b',base+'.'+key,body)
            for before,after in redirects.items():body=body.replace(before+'(',after+'(')
            body=body.replace('PlayerMoveCards.flag(','PlayerMoveInteractions.flag(').replace('BossBattleEffectsP3.flag(','PlayerMoveInteractions.flag(')
            for source in ['int(a.get("effective_move",a.get("move_id",0)))','int(a.get("effective_move",a["move_id"]))']:
                body=body.replace(source,'PlayerMoveInteractions.move_id(a)')
            if new=='boss_protected':body=body.replace('if id in [165,364,467,566,593,621]:','if PlayerMoveInteractions.bypasses_guard(id):')
            if new=='player_absorb':
                body=body.replace('if b.phase=="enemy" and not mode.is_empty() and mode!="endure":return 0', 'if b.phase=="enemy" and not mode.is_empty() and mode!="endure" and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(b.held_attack.get("view",{}))):return 0')
            if new=='enemy_rules':body=body.replace('if targeted and not mode.is_empty()', 'if targeted and not PlayerMoveInteractions.bypasses_guard(mid) and not mode.is_empty()')
            if new=='player_after_enemy':
                body=body.replace('and a["kind"] not in ["prepare","recharge","wait"]','and not a.get("powdered",false) and not a.has("bulk_cancel") and a["kind"] not in ["prepare","recharge","wait"]')
                body=body.replace('and contact and foe.alive():','and contact and foe.alive() and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(a)):')
            if new=='bulk_after_enemy':
                body=body.replace('if c["silk"].get(p.uid,0)==b.turn and ', 'if c["silk"].get(p.uid,0)==b.turn and not PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(a)) and not a.get("powdered",false) and not a.has("bulk_cancel") and ')
            out+=body
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path,required=True);a=p.parse_args()
    code=generate(a.game_dir);(a.game_dir/'scripts/tactics/player_interaction_hooks.gd').write_text(code)
    print(sum(len(v[2]) for v in SOURCES.values()),'derived hooks')
