extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=6
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"v14 card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func power(b:TacticalBattle,id:int) -> int:return int(b.card_view(card(b,id))["preview_damage"])
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveSeals.data()["total_enhanced"]==393 and PlayerMoveSeals.data()["moves"].size()==3,"Three new overlays /393 distinct enhanced")
    var immutable:=var_to_bytes(PlayerMoveSeals.data())
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:=card(b,int(key));var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c),"Pure deterministic preview: "+key)
        check(v["player_rules"]==6 and not v["description"].is_empty() and not CardEffectText.render(v).is_empty(),"Full/compact card explanation: "+key)
        b.player_moves_version=5
        check(v.get("preview_damage",-1)==b.card_view(c).get("preview_damage",-1),"Inactive v14 seals preserve v13 damage: "+key)
    var b:=fixture();quiet(b);var p:=b.active();p.held_item="power_band";var boosted:=power(b,33);cast(b,478)
    check(power(b,33)<boosted and p.held_item=="power_band" and b.effective_item(p).is_empty(),"Magic Room suppresses attack item without removing ownership")
    check(b.card_view(card(b,512))["move_power"]==55,"A suppressed held item still prevents Acrobatics doubling")
    cast(b,478);check(power(b,33)==boosted and PlayerMoveSeals.read(b)["magic"]==0,"Magic Room toggles off and restores item effects immediately")
    p.held_item="guard_charm";var guard:int=b.card_view(BattleCardInstance.new(b._next_uid,"guard",0))["preview_block"];cast(b,478)
    check(b.defense_bonus(p)==0 and b.card_view(BattleCardInstance.new(b._next_uid,"guard",0))["preview_block"]<guard,"Magic Room suppresses guard item in preview")
    p.held_item="healing_bell";p.hp=1;var tool:=BattleCardInstance.new(b._next_uid,"potion_card",0);var healing:int=b.card_view(tool)["preview_heal"];cast(b,478)
    check(b.card_view(tool)["preview_heal"]>healing,"Tool healing item returns when room ends")
    cast(b,478);b._next_uid+=1;b.hand.append(tool);b.energy=100;b.play_card(tool.uid)
    check(p.hp==1+healing,"Suppressed healing item preview equals actual tool healing")
    b=fixture();quiet(b);var reserve:=b.party[1];reserve.held_item="relay_ribbon";cast(b,478);b.energy=100;b.switch_to(reserve.uid)
    check(reserve.block==0 and not b.turn_flags.has("ribbon_%d" % reserve.uid),"Suppressed ribbon grants no switch block and consumes no once-per-turn flag")
    cast(b,478);b.switch_to(b.party[0].uid);b.energy=100;b.switch_to(reserve.uid)
    check(reserve.block==PokemonStats.scale(reserve,5),"Ribbon can activate after Magic Room ends")
    b=fixture();quiet(b);p=b.active();p.held_item="seed_charm";p.hp-=50;b.enemy().statuses["burn"]={"turns":8,"source_uid":p.uid};cast(b,478);var hp:=p.hp;b.end_turn()
    check(p.hp==hp,"Seed Charm's real end-player healing is suppressed")
    cast(b,478);b.end_turn();check(p.hp>hp,"Seed Charm resumes without reconstructing item ownership")
    b=fixture();quiet(b);p=b.active();p.held_item="ace_band";cast(b,478);b.end_turn();check(p.strength==0,"Ace Band's stayed-active boost is suppressed")
    for i in 4:b.end_turn()
    check(PlayerMoveSeals.read(b)["magic"]==0 and p.strength==1 and p.held_item=="ace_band","Magic Room expires after five enemy actions before the next turn's item grant")
    b=fixture(143,241,"gym:whitney");p=b.active();p.held_item="power_band";cast(b,478);var c:=BossBattleRules.write(b);c["removed_items"][p.uid]=p.held_item;p.held_item="";cast(b,478)
    check(b.effective_item(p).is_empty(),"Room cancellation never resurrects an item removed by an enemy")
    b._clear_statuses();check(p.held_item=="power_band" and b.seal_context.is_empty(),"Existing boss cleanup restores its removed item once and clears seals")
    b=fixture();cast(b,381);check(PlayerMoveSeals.read(b)["ally"]==5,"Lucky Chant starts five actions of side protection")
    cast(b,756);check(PlayerMoveSeals.read(b)["ally"]==0 and PlayerMoveSeals.read(b)["foe"]==5,"Court Change transfers Lucky Chant's exact duration")
    p=b.active();p.stat_stages["attack"]=-4;b.enemy().stat_stages["defense"]=4
    var plain:=power(b,818);PlayerMoveSeals.write(b)["foe"]=0;boosted=power(b,818)
    check(plain<boosted and b.card_view(card(b,818))["critical"],"Transferred Chant blocks guaranteed critical multiplier and stage bypass")
    PlayerMoveSeals.write(b)["foe"]=5;var v:=b.card_view(card(b,818));check(not v["critical"],"Suppressed critical is visible in player preview")
    plain=power(b,163);PlayerMoveSeals.write(b)["foe"]=0;check(power(b,163)>plain,"Chant also removes deterministic high-crit bonus")
    PlayerMoveSeals.write(b)["foe"]=5;cast(b,432);check(PlayerMoveSeals.read(b)["foe"]==5,"Defog preserves Lucky Chant")
    b=fixture(242,10191,"gym:mustard");p=b.active();p.stat_stages["defense"]=4;b.enemy().stat_stages["attack"]=-4
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==818:b.opening()["intent"]=i
    var incoming:int=b.intent()["value"];cast(b,381);var action:=b.intent()
    check(action["value"]<incoming and action.get("critical_blocked",false) and action["hits"]==3,"Chant neutralizes boss guaranteed crit while preserving all three hits")
    cast(b,472);action=b.intent();p.block=10000;var uid:=p.uid;b.end_turn();var dealt:=0
    for e:Dictionary in b.events:
        if e["kind"]=="damage" and e.get("target")==uid:dealt+=int(e.get("amount",0))+int(e.get("blocked",0))
    check(dealt==action["value"],"Wonder Room plus Lucky Chant boss multi-hit preview matches actual damage")
    b=fixture();quiet(b);cast(b,381);b.energy=100;b.switch_to(b.party[1].uid);check(PlayerMoveSeals.read(b)["ally"]==5,"Chant is a side effect and survives switching")
    for i in 5:b.end_turn()
    check(PlayerMoveSeals.read(b)["ally"]==0,"Chant expires after exactly five enemy actions")
    b=fixture();quiet(b);cast(b,587);reserve=b.party[1];var tech:=card(b,33,reserve.uid);var before:=var_to_bytes(b.snapshot())
    check(not b.switch_to(reserve.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Fairy Lock rejects manual switch atomically")
    check(not b.play_card(tech.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Fairy Lock rejects owner-card automatic switch atomically")
    cast(b,33);b.end_turn();check(not b.switch_reason(reserve.uid).is_empty() and PlayerMoveSeals.read(b)["fairy"]==1,"Lock allows current actor cards and persists through the next player turn")
    b.end_turn();b.energy=100;check(b.switch_to(reserve.uid).is_empty(),"Fairy Lock expires after the next enemy action")
    b=fixture(94);cast(b,587);b.energy=100;check(b.switch_to(b.party[1].uid).is_empty(),"Ghost active Pokemon can leave Fairy Lock")
    check(not b.switch_reason(b.party[0].uid).is_empty(),"Incoming Ghost type does not exempt a non-Ghost outgoing actor")
    b=fixture();cast(b,587);b._damage(b.active(),b.active().hp,true);b.phase=TacticalBattle.REPLACE
    check(b.switch_to(b.party[1].uid).is_empty(),"Mandatory replacement after KO remains legal")
    b=fixture(143,241,"gym:whitney");cast(b,587);var old_uid:=b.active().uid;BossBattleEffectsP3.force_switch(b)
    check(b.active().uid!=old_uid,"Opponent-forced switch remains legal under Fairy Lock")
    b=fixture();cast(b,478);cast(b,381);cast(b,587);var frame:=BattleFrame.capture(b)
    check(frame["seal_context"]==b.seal_context,"Presentation frame captures seal timers")
    PlayerMoveSeals.write(b)["magic"]=0;check(frame["seal_context"]["magic"]==5,"Presentation frame detaches seal context")
    b._clear_statuses();check(b.seal_context.is_empty(),"Battle cleanup clears every seal")
    check(immutable==var_to_bytes(PlayerMoveSeals.data()),"Definitions remain immutable across previews and play")
    h.free();print("Player move seals: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
