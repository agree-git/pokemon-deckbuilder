extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
    var folder:String=get_script().resource_path.get_base_dir()
    var previous=load(folder.path_join("test_boss_move_effects_p1.gd")).new()
    var current=load(folder.path_join("test_boss_move_effects_p2.gd")).new()
    for key:String in BossMoveEffectsP1.data()["profiles"]:
        var p:Dictionary=BossMoveEffectsP1.data()["profiles"][key]
        for level in [18,50,100]:
            for i in p["intents"].size():
                var old:TacticalBattle=previous.fixture(p["boss"],p["species"],143,level)
                var fresh:TacticalBattle=current.fixture(p["boss"],p["species"],143,level)
                for member:BattlePokemon in fresh.party:member.level=level;PokemonStats.apply(member,true)
                for b:TacticalBattle in [old,fresh]:
                    b.opening()["intent"]=i
                    b.enemy().hp=maxi(1,b.enemy().max_hp/2)
                    b.enemy().stat_stages={"attack":2,"defense":-2,"special_attack":1,"special_defense":-1,"speed":3}
                var a:=old.intent();var next:=fresh.intent()
                checks+=1
                if a["value"]!=next["value"] or a.get("healing",0)!=next.get("healing",0):failures+=1;push_error("P1 numeric preview changed in v8: "+key)
                BossMoveEffectsP1.execute(old,a);BossMoveEffectsP2.execute(fresh,next)
                checks+=1
                if old.enemy().snapshot()!=fresh.enemy().snapshot() or old.active().snapshot()!=fresh.active().snapshot():failures+=1;push_error("P1 actual HP/status/stages changed in v8: "+key)
    previous.free();current.free()
    print("Boss effects P2 parity: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
