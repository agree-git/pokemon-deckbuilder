extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:
    var fingerprints:={"res://data/boss_move_effects_v6.json":"311bb2cc005a3d15ae6738d144a5054b3f86554dfaa68f97d11a7fa8ee098a20","res://data/boss_move_effects_v7.json":"bb837507dbd26367aa755ffbbf5dfdf55385eee64e931d58b26e296df7fb111d","res://data/boss_move_effects_v8.json":"3b37632ee6a9b5eb9d67eb9f78e1e7656d27858243946e900fd361057c28d0bd","res://data/boss_parties.json":"0fd9f5ab5efcd2b4628e7bdaecbfb786e0cceede9c78d7a1d5c1eef99325e354"}
    for path:String in fingerprints:
        var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(FileAccess.get_file_as_bytes(path))
        check(hash.finish().hex_encode()==fingerprints[path],"Frozen input preserved: "+path)
    var helper=load(get_script().resource_path.get_base_dir().path_join("test_boss_move_effects_p2.gd")).new()
    for key:String in BossMoveEffectsP2.data()["profiles"]:
        var p:Dictionary=BossMoveEffectsP2.data()["profiles"][key]
        var b:TacticalBattle=helper.fixture(p["boss"],p["species"])
        check(not BossBattleRules.modern(b) and BossBattleRules.active_in(b),"v8 uses frozen helper")
        check(BossBattleRules.read(b)==BossBattleEffects.read(b),"v8 default context unchanged")
        var c:BattleCardInstance=helper.card(b,33)
        var v:=b.card_view(c)
        check(v.get("owner_uid")==c.owner_uid and BossBattleRules.player_damage(b,v,100)==BossBattleEffects.player_damage(b,v,100),"v8 cards and numeric hook remain unchanged")
        var shared:=BossBattleEffects.DEFAULT.duplicate(true);shared["screen"]=5
        b.boss_context=shared
        var before:=var_to_bytes(b.snapshot())
        b.intent();b.card_view(c)
        check(before==var_to_bytes(b.snapshot()),"v8 facade preview remains read-only")
    helper.free()
    print("Boss v8 compatibility: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
