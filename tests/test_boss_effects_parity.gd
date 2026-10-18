extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
    var helper=load(get_script().resource_path.get_base_dir().path_join("test_boss_move_effects_p1.gd")).new()
    for key:String in BossMoveEffects.data()["profiles"]:
        var p:Dictionary=BossMoveEffects.data()["profiles"][key]
        for level in [18,50,100]:
            for i in p["intents"].size():
                var old:TacticalBattle=helper.fixture(p["boss"],p["species"],143,level)
                var fresh:TacticalBattle=helper.fixture(p["boss"],p["species"],143,level)
                old.enemy_definitions[0].merge(BossMoveEffects.build(p["boss"],p["species"]),true)
                for b:TacticalBattle in [old,fresh]:
                    b.opening()["intent"]=i
                    b.enemy().hp=maxi(1,b.enemy().max_hp/2)
                    b.enemy().stat_stages={"attack":6,"defense":-6,"special_attack":1,"special_defense":-1,"speed":3}
                    b.active().stat_stages={"attack":-6,"defense":6,"special_attack":-1,"special_defense":1,"speed":-3}
                var a:=old.intent()
                var next:=fresh.intent()
                checks+=1
                if a["value"]!=next["value"] or a.get("healing",0)!=next.get("healing",0):failures+=1;push_error("P0 numeric preview changed in v7: "+key)
                BossMoveEffects.execute(old,a)
                BossMoveEffectsP1.execute(fresh,next)
                checks+=1
                if old.enemy().snapshot()!=fresh.enemy().snapshot() or old.active().snapshot()!=fresh.active().snapshot():failures+=1;push_error("P0 damage/stats/status/heal/block execution changed in v7: "+key)
    helper.free()
    print("Boss effects parity: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
