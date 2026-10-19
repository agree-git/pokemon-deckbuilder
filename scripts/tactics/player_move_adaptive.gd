class_name PlayerMoveAdaptive
extends RefCounted
## v26: resolve dynamic types before immunity filtering and keep math/contact aligned.
const PATH:="res://data/player_move_adaptive_v26.json"
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveSupport.definition(key)
    if not v.is_empty():v["player_rules"]=18
    return v
static func resolved_type(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var id:=int(v.get("move_id",0));var kind:String=v.get("type","normal")
    if id in [237,686]:
        var types:=PlayerMoveCards.effective_types(b,p)
        return str(types[0]) if not types.is_empty() else "normal"
    if id==311:return {"sun":"fire","rain":"water","snow":"ice","sand":"rock"}.get(BattleWeather.kind(b.powers),"normal")
    if id==805 and PlayerMoveAltitude.grounded(b,p) and not PlayerMoveFields.read(b)["terrain"].is_empty():return {"electric":"electric","grassy":"grass","misty":"fairy","psychic":"psychic"}[PlayerMoveFields.read(b)["terrain"]]
    if id==363 and PlayerMoveBulk.berry(b,p):return PlayerMoveBulk.BERRY_TYPES[b.effective_item(p)]
    if id in [449,546,718]:
        var held:=HeldItems.item(b,p)
        if held.get("rule")=="type" and not held.get("types",[]).is_empty():return str(held["types"][0])
    var species:=PlayerMoveBulk.visual_species(PlayerMoveBulk.read(b),p)
    return PokedexExpansion.move_type(species,id,kind)
static func seed(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")=="technique":
        v["type"]=resolved_type(b,p,v);v=PlayerMoveReactions.move_type(b,p,v)
        # Type was resolved here; the frozen v23 branch indexes the first type again.
        if int(v.get("move_id",0)) in [237,686]:v["bulk_rule"]="adaptive_hidden"
    return v
static func category(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary) -> void:
    var id:=int(v.get("move_id",0))
    if id not in [722,801]:return
    var actor:=PlayerMoveFields.room_clone(b,p);var defender:=PlayerMoveFields.room_clone(b,target)
    var left:=HeldItems.effective(b,actor,"attack");var right:=HeldItems.effective(b,actor,"special_attack")
    if id==801:left*=HeldItems.effective(b,defender,"special_defense");right*=HeldItems.effective(b,defender,"defense")
    v["damage_class"]="physical" if left>right else "special"
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=18;category(b,p,b.enemy(),v)
    var note:String=data()["moves"].get(str(v.get("move_id",0)),{}).get("adaptive_note","")
    if not note.is_empty():v["card_notes"].append(note)
    return v
static func enemy_move(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary) -> Dictionary:
    v=v.duplicate(true);v["type"]=resolved_type(b,p,v);category(b,p,target,v);return v
static func contact(v:Dictionary) -> bool:
    var id:=PlayerMoveInteractions.move_id(v)
    if id==801:return v.get("damage_class",v.get("copied_view",{}).get("damage_class","special"))=="physical"
    return PlayerMoveInteractions.flag(id,1)
static func affinity(b:TacticalBattle,attack:String,target:BattlePokemon,base:float,id:int) -> float:
    if id==573 and "water" in PlayerMoveCards.effective_types(b,target):return base*2.0/TypeMatchup.multiplier(attack,["water"])
    return base
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    if int(v.get("move_id",0))!=573:return PlayerMoveBulk.raw_damage(b,p,target,v,bonus)
    var n:=PlayerAdaptiveMath.player_base(b,PlayerMoveFields.room_clone(b,p),PlayerMoveFields.room_clone(b,target),v,bonus)
    return maxi(1,floori(n*PlayerMoveAirFields.factor(b,p,target,v))) if n>0 else 0
static func boss_filter(b:TacticalBattle,v:Dictionary) -> Dictionary:
    var result:=PlayerAdaptiveMath.aimed_filter_view(b,v) if v.get("aimed",false) else PlayerAdaptiveMath.boss_filter_view(b,PlayerMoveItems.boss_proxy(b,v))
    if int(v.get("move_id",0))==614:result["move_id"]=614
    return result
static func boss_damage(b:TacticalBattle,v:Dictionary,n:int) -> int:return PlayerAdaptiveMath.aimed_player_damage(b,v,n) if v.get("aimed",false) else PlayerAdaptiveMath.boss_player_damage(b,PlayerMoveItems.boss_proxy(b,v),n)
static func boss_notice(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> String:return PlayerAdaptiveMath.aimed_card_notice(b,v,p) if v.get("aimed",false) else PlayerAdaptiveMath.boss_card_notice(b,PlayerMoveItems.boss_proxy(b,v),p)
static func boss_on_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    if int(v.get("move_id",0))==614:PlayerMoveItems.boss_card(b,v,p)
    elif v.get("aimed",false):PlayerAdaptiveMath.aimed_on_card(b,v,p)
    else:PlayerAdaptiveMath.boss_on_card(b,v,p)
static func lines(v:Dictionary) -> Array[String]:return PlayerMoveSupport.lines(v)
