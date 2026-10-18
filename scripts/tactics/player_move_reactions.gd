class_name PlayerMoveReactions
extends RefCounted
## v20: one-round move typing and Powder. Previews never mutate state.
const PATH:="res://data/player_move_reactions_v20.json"
const DEFAULT:Dictionary={"plasma":false,"electric":{},"powder":{}}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.reaction_context if not b.reaction_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.reaction_context.is_empty():b.reaction_context=DEFAULT.duplicate(true)
    return b.reaction_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveFate.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=12;v["description"]=TacticalContent.description(v)
    return v
static func conversion(b:TacticalBattle,p:BattlePokemon) -> bool:return read(b)["plasma"] or read(b)["electric"].get(p.uid,false)
static func move_type(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if int(v.get("move_id",0))==165:return v
    var type_name:String=v.get("type","normal")
    if read(b)["electric"].get(p.uid,false) or (read(b)["plasma"] and type_name=="normal"):
        v=v.duplicate(true);v["type"]="electric"
    return v
static func card_type(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    var result:=move_type(b,p,v)
    if result["type"]!=v["type"]:result["card_notes"].append("이번 턴 기술 타입 → 전기 · 포켓몬 타입 유지")
    return result
static func prepare(b:TacticalBattle,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=12
    if v.get("reaction_rule","") in ["electric","powder"]:
        v["reaction_blocked"]=PlayerMoveAssist.blocked(b,v) or (v["reaction_rule"]=="powder" and "grass" in PlayerMoveCards.effective_types(b,b.enemy()))
        if v["reaction_blocked"]:v["card_notes"].append("보호/대타/공중 회피 또는 풀 타입이 대상 효과 차단 · 원본 우회 플래그 반영")
    return v
static func after_card(b:TacticalBattle,v:Dictionary,target:BattlePokemon) -> void:
    var tag:String=v.get("reaction_rule","")
    if tag.is_empty() or v.get("preparing",false) or v.get("failed",false):return
    if tag=="plasma":write(b)["plasma"]=true
    elif target.alive() and not v.get("reaction_blocked",false) and not v.get("target_effect_blocked",false):write(b)[tag][target.uid]=true
    b._record("field",str(v["name"])+" · 이번 상대 행동까지 타입/반응 효과")
static func enemy_preview(b:TacticalBattle,a:Dictionary) -> Dictionary:
    if b.reaction_context.is_empty():return a
    var id:int=int(a.get("copied_view",{}).get("move_id",a.get("effective_move",a.get("move_id",0))))
    var raw:Dictionary=a.get("copied_view",TacticalMoves.definition(TacticalMoves.key_for(id)))
    var detail:=raw.duplicate(true);detail["type"]=a.get("type",raw.get("type","normal"))
    detail=move_type(b,b.enemy(),detail)
    a=a.duplicate(true);a["type"]=detail["type"]
    var using:bool=a["kind"] not in ["wait","recharge","guard","block","fortify","boost","recover"] and not a.get("asleep",false) and not a.get("player_sealed",false) and not a.get("failed_move",false) and not a.get("failed_charge",false)
    if using and read(b)["powder"].get(b.enemy().uid,false) and a["type"]=="fire":
        a["powdered"]=true;a["powder_damage"]=maxi(1,b.enemy().max_hp/4);a["failed_move"]=true;a["advance"]=1;a["value"]=0
        if a.has("per_hit"):a["per_hit"]=0
        a["effects"]=a.get("effects",[])+["분진 폭발 · 불꽃 기술 취소 · 자신 HP -%d" % a["powder_damage"]]
    return a
static func explode(b:TacticalBattle,a:Dictionary) -> void:
    var foe:=b.enemy()
    if b.enemy_definitions[b.enemy_index].get("boss_moves_version")==4:b.opening()["effects_v4"]=BossMoveEffectsP3.state(b).duplicate(true)
    b._record("cancel",foe.display_name+" · 분진 폭발로 불꽃 기술 취소")
    b._damage(foe,int(a["powder_damage"]),true)
    for key:String in ["effects_v4","effects_v3","effects_v2"]:
        if b.opening().has(key):b.opening()[key].merge({"charge":0,"recharge":false,"lock":0,"lock_left":0},true)
    if b.opening().has("effects_v4"):
        b.opening()["effects_v4"]["actions"]+=1
        b.opening()["effects_v4"]["last_failed"]=true
        b.opening()["effects_v4"]["last_move"]=int(a.get("effective_move",a["move_id"]))
        b.opening()["effects_v4"]["air_cancel"]=false
static func on_switch(b:TacticalBattle,uid:int) -> void:
    if b.reaction_context.is_empty():return
    for key:String in ["electric","powder"]:b.reaction_context[key].erase(uid)
static func after_enemy(b:TacticalBattle) -> void:b.reaction_context.clear()
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=3 or not c.get("plasma") is bool:return false
    var ids:Array=b["party"]+b["enemies"]
    for key:String in ["electric","powder"]:
        if not c.get(key) is Dictionary:return false
        for uid:Variant in c[key]:
            if not uid is int or uid not in ids or not c[key][uid] is bool or not c[key][uid]:return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveFate.lines(v)
    if v.has("reaction_rule"):rows.push_front({"plasma":"이번 턴 양쪽 노말 기술 → 전기","electric":"상대 다음 기술 → 전기","powder":"불꽃 기술 취소 · 상대 최대HP¼ 피해"}[v["reaction_rule"]])
    return rows.slice(0,5)
