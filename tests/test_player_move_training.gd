extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture() -> TacticalBattle:
    var b:TacticalBattle=h.fixture();b.player_moves_version=14;HeldItems.initialize(b);return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c)
    check(b.play_card(c.uid).is_empty(),"Technique executes: "+str(id));return v
func journey() -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    j.party[0].held_item="sitrus_berry"
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcard(j:TacticalJourney,id:int) -> BattleCardInstance:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid;return c
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==22 and PlayerTechniques.version(22)==14 and PlayerMoveTraining.data()["total_enhanced"]==430,"Four new techniques /430 enhanced")
    var immutable:=var_to_bytes(PlayerMoveTraining.data())
    for id:int in [367,829,837,842]:
        var b:=fixture();var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(v==b.card_view(c) and before==var_to_bytes(b.snapshot()) and not v.has("block") and v["player_rules"]==14,"Pure preview and RNG; no placeholder block")
        c.upgraded=true;var u:=b.card_view(c)
        check(u["cost"]==0 and u["training_rule"]==v["training_rule"] and not CardEffectText.render(u).is_empty(),"Upgrade lowers cost and retains feature/text")
        b.player_moves_version=13;check(b.card_view(c).get("block")==9 and not b.card_view(c).has("training_rule"),"v21 retains original upgraded block")
    var b:=fixture();var r:=RandomNumberGenerator.new();r.state=b._rng.state
    var chosen:String=PlayerMoveTraining.STATS[r.randi_range(0,4)];cast(b,367)
    check(b.active().stat_stages=={chosen:2} and b._rng.state==r.state and b.active().block==0,"Acupressure draws only at execution and raises exactly selected stat")
    b=fixture()
    for stat:String in PlayerMoveTraining.STATS:b.active().stat_stages[stat]=6
    b.active().stat_stages["speed"]=5;cast(b,367)
    check(b.active().stat_stages.values().all(func(n:Variant):return n==6),"Exclude capped stats and clamp +5 to +6")
    var c:=card(b,367,b.party[1].uid)
    for stat:String in PlayerMoveTraining.STATS:b.party[1].stat_stages[stat]=6
    var before:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"All capped refusal preserves auto switch, RNG, energy and card")
    b=fixture();b.active().stat_stages={"attack":5,"defense":6,"speed":-2};cast(b,837)
    check(b.active().stat_stages=={"attack":6,"defense":6,"speed":-1} and b.active().block==0,"Victory Dance raises attack/defense/speed, bounded and self-only")
    b=fixture();var incoming:=b.party[1];c=card(b,842,incoming.uid);check(b.play_card(c.uid).is_empty() and b.active()==incoming and incoming.stat_stages=={"defense":2} and b.party[0].stat_stages.is_empty(),"Shelter automatically switches owner then raises its Defense +2")
    b=fixture();var own:=b.active();var hp:=own.hp;var speed:=PokemonStats.effective(own,"speed");own.stat_stages={"attack":2,"special_defense":-1}
    var stats:Dictionary={}
    for stat:String in PlayerMoveTraining.STATS:stats[stat]=PlayerMoveExchange.base_stat(own,stat)
    cast(b,829)
    check(PlayerMoveExchange.base_stat(own,"attack")==stats["defense"] and PlayerMoveExchange.base_stat(own,"defense")==stats["attack"] and PlayerMoveExchange.base_stat(own,"special_attack")==stats["special_defense"] and PlayerMoveExchange.base_stat(own,"special_defense")==stats["special_attack"],"Power Shift swaps both raw offensive/defensive pairs")
    check(own.hp==hp and PokemonStats.effective(own,"speed")==speed and own.stat_stages=={"attack":2,"special_defense":-1},"Power Shift preserves HP, Speed and stat stages")
    c=card(b,33);var v:=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(hp-b.enemy().hp==v["preview_hp_loss"],"Post-shift actual item-aware damage matches preview")
    cast(b,829);check(PlayerMoveTraining.STATS.all(func(stat:String):return PlayerMoveExchange.base_stat(own,stat)==stats[stat]),"Second Power Shift restores raw stats")
    cast(b,829);c=card(b,33,b.party[1].uid);b.play_card(c.uid)
    check(own.battle_stats.is_empty() and own.stat_stages.is_empty() and not PlayerMoveExchange.read(b)["stats"].has(own.uid),"Automatic switch clears shifted stats and stages")
    b=fixture();b.active().held_item="assault_vest";c=card(b,837);before=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Existing Assault Vest still atomically blocks new status moves")
    b=fixture();b.active().held_item="choice_band";HeldItems.initialize(b);cast(b,837);c=card(b,842);before=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Choice lock still blocks a different training move")
    b=fixture();b.active().learned_skills.assign(["move_837","move_33","move_214"]);b.active().statuses["sleep"]={"turns":3,"source_uid":b.active().uid};v=cast(b,214)
    check(v["move_id"]==33 and not v.has("training_rule") and b.active().stat_stages.is_empty(),"Sleep Talk keeps attack-only selection and skips self training moves")
    var j:=journey();c=jcard(j,829);check(j.battle.play_card(c.uid).is_empty(),"Real expedition Power Shift executes")
    c=jcard(j,367);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Live shifted stats, pending random card and held ownership validate")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Existing exchange context restores all shifted stats")
        var frame:=BattleFrame.capture(j.battle);var detached:=var_to_bytes(frame)
        j.battle.card_view(c);copy.battle.card_view(copy.battle.hand.filter(func(item:BattleCardInstance):return item.uid==c.uid)[0])
        check(j.battle.play_card(c.uid).is_empty() and copy.battle.play_card(c.uid).is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Save/load pending Acupressure chooses same stat with same RNG")
        j.battle.end_turn();copy.battle.end_turn()
        check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy) and var_to_bytes(frame)==detached,"Same next enemy action and detached animation frame")
    var save:=JourneySave.new("user://training-v22.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual save envelope reloads with new fingerprint")
    var f:=FileAccess.open("/tmp/player-v21-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=f.get_var();var old:Dictionary=captured["state"]
        check(JourneySnapshot.validate(old),"Actual pre-edit v21 save validates")
        if JourneySnapshot.validate(old):
            var restored:=JourneySnapshot.restore(old);check(JourneySnapshot.encode(restored)==old,"Actual v21 state restores byte-equivalent contents")
            restored.battle.end_turn();check(JourneySnapshot.encode(restored)==captured["next"],"Actual v21 next input preserves old effects, route and RNG")
        check(JourneySave.compatible_content(captured["fingerprint"]),"Actual previous v21 fingerprint accepted")
    check(JourneySave.compatible_content("0f77fb493cb20ec6a587c6b4118ff2cb1bfa194c5690ce7eb1c59ebc0b8c9a8d"),"Published previous fingerprint remains accepted")
    check(var_to_bytes(PlayerMoveTraining.data())==immutable,"Definitions stay immutable")
    j.battle._clear_statuses();check(j.battle.exchange_context.is_empty() and j.party[0].battle_stats.is_empty(),"Battle cleanup clears shifted stats without persistent species changes")
    h.free();print("Player training: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
