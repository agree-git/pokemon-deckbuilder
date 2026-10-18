extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:
    var folder:String=get_script().resource_path.get_base_dir()
    var helper=load(folder.path_join("test_boss_move_effects_p2.gd")).new()
    var b:TacticalBattle=helper.fixture("gym:roxie",545)
    helper.select_move(b,182);helper.step(b)
    b.next_attack_bonus=5
    var c:BattleCardInstance=helper.card(b,34)
    var hp:=b.enemy().hp
    check(b.card_view(c)["preview_damage"]==0,"Protected ordinary attack preview is zero")
    b.play_card(c.uid)
    check(b.enemy().hp==hp and b.next_attack_bonus==0,"Blocked attack still consumes one-use attack bonus")
    check(not b.enemy().statuses.has("paralysis"),"Protected secondary effect does not leak")
    b.active().block=50
    var shield:=BattleCardInstance.new(b._next_uid,"shield_strike",0)
    b._next_uid+=1;b.hand.append(shield)
    check(b.card_view(shield)["preview_damage"]==0,"Protected shield conversion preview matches zero damage")
    b.play_card(shield.uid)
    check(b.active().block==0 and b.enemy().hp==hp,"Shield conversion spends its own shield while protection prevents HP damage")
    b.active().hp-=10
    var heal:=BattleCardInstance.new(b._next_uid,"potion_card",0);b._next_uid+=1;b.hand.append(heal)
    var ally_hp:=b.active().hp;b.play_card(heal.uid)
    check(b.active().hp>ally_hp and not b.events.any(func(e:Dictionary):return e["kind"]=="cancel"),"Protect never reports cancellation for a self-healing tool")
    b=helper.fixture("elite:wikstrom",681)
    helper.select_move(b,588);helper.step(b)
    b.active().block=50;shield=BattleCardInstance.new(b._next_uid,"shield_strike",0);b._next_uid+=1;b.hand.append(shield)
    b.play_card(shield.uid)
    check(not b.active().stat_stages.has("attack"),"Trainer card's visual move ID does not falsely count as a contact technique")
    c=helper.card(b,33);b.play_card(c.uid)
    check(b.active().stat_stages.get("attack")==-2,"Real contact technique still receives King's Shield penalty")
    helper.free()
    print("Boss protection resources: %d checks / %d failures" % [checks,failures])
    quit(1 if failures else 0)
