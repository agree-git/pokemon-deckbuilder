class_name CampaignChallenge
extends RefCounted
## New expeditions only. Pressure changes the announced direct hit, never hidden RNG.
const VERSION := 28
const PATH := "res://data/campaign_challenge_v28.json"
const FIELDS := ["challenge_version","challenge_pressure","challenge_block"]
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func decorate(definitions:Array,node:Dictionary) -> Array:
    var result:Array=definitions.duplicate(true)
    for definition:Dictionary in result:
        var role:=str(node["kind"])
        definition["challenge_version"]=VERSION
        definition["challenge_pressure"]=int(data()["pressure_percent"][role][mini(8,int(node["chapter"]))])
        definition["challenge_block"]=ceili(int(definition["max_hp"])*float(data()["opening_block_percent"][role])/100.0)
    return result
static func rest_percent(j:TacticalJourney) -> int:
    return int(data()["rest_percent"][mini(8,int(j.current()["chapter"]))]) if j.full_campaign and j.route.generation>=VERSION else 50
static func intent(b:TacticalBattle,source:Dictionary) -> Dictionary:
    var definition:Dictionary=b.enemy_definitions[b.enemy_index]
    if definition.get("challenge_version",0)!=VERSION or source.has("fixed_damage") or int(source.get("value",0))<=0:return source
    if source.get("kind") not in ["attack","charge","barrage","move"] or source.get("damage_class","")=="status":return source
    var result:=source.duplicate(true)
    var factor:=int(definition["challenge_pressure"])/100.0
    if result.has("per_hit"):
        result["per_hit"]=ceili(int(result["per_hit"])*factor)
        result["value"]=int(result["per_hit"])*int(result.get("hits",1))
        var effects:Array=result.get("effects",[])
        for i in effects.size():
            if str(effects[i]).contains("대상 기절 시 남은 타격 중단"):effects[i]="%d × %d회 · 대상 기절 시 남은 타격 중단"%[result["per_hit"],result.get("hits",1)]
    else:result["value"]=ceili(int(result["value"])*factor)
    return result
static func valid(definition:Dictionary,route:CampaignRoute,combat_step:int) -> bool:
    if route.generation<VERSION:return not FIELDS.any(func(field:String):return definition.has(field))
    if combat_step<0 or combat_step>=route.stops.size() or route.stops[combat_step]["kind"]=="rest":return false
    var expected:Dictionary=decorate([definition],route.stops[combat_step])[0]
    for field:String in FIELDS:
        if not definition.get(field) is int or definition[field]!=expected[field]:return false
    return true
