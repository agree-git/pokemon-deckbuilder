extends SceneTree
# One focused suite: changed effects, original equipment, previous save compatibility.
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=9
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func journey(v:=17) -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,v)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Journey card executes: "+str(id))
func checkpoint(j:TacticalJourney) -> TacticalJourney:
    var state:=JourneySnapshot.encode(j);var bytes:=var_to_bytes(state);check(JourneySnapshot.validate(state),"Live item checkpoint validates")
    if not JourneySnapshot.validate(state):return null
    var copy:=JourneySnapshot.restore(state)
    check(var_to_bytes(state)==bytes and JourneySnapshot.encode(copy)==state and j.battle.snapshot()==copy.battle.snapshot(),"Restore is exact without mutating input")
    return copy
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveItems.data()["moves"].size()==8 and PlayerMoveItems.data()["total_enhanced"]==411,"Eight overlays /411 enhanced")
    var immutable:=var_to_bytes(PlayerMoveItems.data())
    for id:int in [614,271,415,516,278,373,810,374]:
        var b:=fixture();b.active().held_item="power_band";var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==9,"Changed previews preserve state/UID/RNG: "+str(id))
        c.upgraded=true;check(b.card_view(c)["item_rule"]==v["item_rule"] and not CardEffectText.render(v).is_empty(),"Upgrade/text preserves feature: "+str(id))
    var b:=fixture(143,227);var target:=b.enemy();var types:=target.types.duplicate()
    check(b.multiplier("ground",target)==0 and b.multiplier("ground",target,614)==1,"Arrow first hit treats an ungrounded Flying/Steel target neutrally")
    var v:=cast(b,614);check(v["preview_damage"]>0 and PlayerMoveAltitude.grounded(b,target) and b.multiplier("ground",target)==2 and target.types==types,"Arrow damages, grounds and preserves actual Flying type")
    b=fixture(143,25);PlayerMoveAltitude.write(b)["rise"][b.enemy().uid]=5
    check(b.multiplier("ground",b.enemy())==0 and b.multiplier("ground",b.enemy(),614)==2,"Arrow ignores artificial levitation but keeps non-Flying Ground affinity")
    cast(b,614);check(not PlayerMoveAltitude.floating(b,b.enemy()),"Arrow removes Magnet Rise")
    b=fixture(143,620,"elite:marshal")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==340:b.opening()["intent"]=i
    b.end_turn();var hp:=b.enemy().hp;v=cast(b,614)
    check(b.enemy().hp<hp and not b.boss_context["airborne"].has(b.enemy().uid),"Arrow hits and cancels an actual authored Bounce")
    check(b.boss_context["last_moves"][b.active().uid]["move"]==614 and b.boss_context["mirror"][b.enemy().uid]["move"]==614,"Arrow true ID stays in copy memory")
    b=fixture(143,620,"elite:marshal");b.active().held_item="power_band"
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==340:b.opening()["intent"]=i
    b.end_turn();cast(b,516);check(b.active().held_item=="power_band" and b.enemy().held_item.is_empty(),"Bestow bypasses guards but still misses aerial preparation")
    b=fixture(143,18,"champion:blue");cast(b,614)
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==119:b.opening()["intent"]=i
    var mirrored:=b.intent();hp=b.active().hp;b.end_turn()
    check(mirrored.get("copied_view",{}).get("move_id",0)==614 and hp-b.active().hp==int(mirrored["value"]),"Actual champion Mirror Move copies and executes Arrow with matching preview")
    b=fixture(143,241,"gym:whitney");BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";hp=b.enemy().hp;cast(b,614)
    check(b.enemy().hp==hp and not PlayerMoveAltitude.read(b)["down"].has(b.enemy().uid),"Protect blocks damage and grounding")
    BossBattleRules.write(b)["guards"].clear();BossBattleRules.write(b)["substitutes"][b.enemy().uid]=10000;cast(b,614)
    check(not PlayerMoveAltitude.read(b)["down"].has(b.enemy().uid),"Substitute blocks secondary grounding")
    b=fixture(18);b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"ground","move_id":614}];cast(b,19);hp=b.active().hp;var incoming:int=b.intent()["value"];b.end_turn()
    check(incoming>0 and b.active().hp<hp and PlayerMoveRules.read(b)["charges"].is_empty() and PlayerMoveAltitude.grounded(b,b.active()),"NPC Arrow hits Fly, cancels charge and lands the player")
    b=fixture();b.active().held_item="power_band";b.enemy().held_item="guard_charm";cast(b,271)
    check(b.active().held_item=="guard_charm" and b.enemy().held_item=="power_band","Trick swaps real battle equipment")
    b._clear_statuses();check(b.active().held_item=="power_band" and b.enemy().held_item=="guard_charm","Cleanup restores both original owners")
    b=fixture();b.active().held_item="healing_bell";cast(b,415);check(b.active().held_item.is_empty() and b.enemy().held_item=="healing_bell","Switcheroo exchanges with an empty slot")
    b=fixture(143,241,"gym:whitney");b.active().held_item="power_band";BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";BossBattleRules.write(b)["substitutes"][b.enemy().uid]=100;cast(b,516)
    check(b.active().held_item.is_empty() and b.enemy().held_item=="power_band","Bestow respects pinned bypass flags for Protect/Substitute")
    b._clear_statuses();check(b.active().held_item=="power_band" and b.enemy().held_item.is_empty(),"Transferred gear returns after battle")
    b=fixture();var c:=card(b,271);var state:=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Empty Trick refusal is atomic")
    b=fixture(143,241,"gym:whitney");b.active().held_item="power_band";BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,271)
    check(b.active().held_item=="power_band" and b.enemy().held_item.is_empty(),"Protect blocks Trick")
    cast(b,374);check(b.active().held_item.is_empty() and PlayerMoveItems.read(b)["spent"][b.active().uid]=="power_band","Blocked Fling still consumes held item")
    cast(b,278);check(b.active().held_item=="power_band" and PlayerMoveItems.read(b)["spent"].is_empty(),"Recycle restores only the latest Fling consumption")
    BossBattleRules.write(b)["guards"].clear();cast(b,516);cast(b,810);c=card(b,278);state=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Recycle cannot recreate a transferred/corroded item")
    b._clear_statuses();check(b.active().held_item=="power_band" and b.enemy().held_item.is_empty(),"Corrosion remains battle-only without duplicating gear")
    b=fixture();quiet(b);b.active().held_item="ace_band";PlayerMoveItems.write(b)["embargo"][b.active().uid]=5
    var tool:=BattleCardInstance.new(b._next_uid,"potion_card",0);b._next_uid+=1;b.hand.append(tool);b.energy=100;state=var_to_bytes(b.snapshot())
    check(not b.play_card(tool.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Embargo atomically blocks trainer tool cards")
    c=card(b,374);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Embargo atomically blocks Fling")
    b.end_turn();check(b.active().strength==0,"Embargo suppresses existing held-item effects")
    for i in 4:b.end_turn()
    check(not PlayerMoveItems.suppressed(b,b.active()) and b.active().strength==1,"Embargo expires after five actions before next item grant")
    b=fixture();b.active().held_item="power_band";cast(b,478);c=card(b,374);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Magic Room prevents Fling without losing the item")
    b=fixture(143,241,"gym:whitney");b.active().held_item="guard_charm";cast(b,415);BossBattleRules.write(b)["removed_items"][b.active().uid]="guard_charm";b.active().held_item="";b._clear_statuses()
    check(b.active().held_item=="guard_charm" and b.enemy().held_item.is_empty(),"New baseline restoration and frozen boss restoration do not duplicate gear")
    var j:=journey();j.party[0].held_item="power_band";jcast(j,415);jcast(j,373);jcast(j,393);jcast(j,381);var copy:=checkpoint(j)
    if copy!=null:
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restored item transfer/timers with old float/Chant gives the same next action")
        j.battle._clear_statuses();copy.battle._clear_statuses();check(j.party[0].held_item=="power_band" and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Restored cleanup returns exact original equipment")
    j=journey();j.party[0].held_item="power_band";jcast(j,374);copy=checkpoint(j)
    if copy!=null:
        jcast(j,278);jcast(copy,278);check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Recycle after load returns the same consumed item/UID/RNG state")
    var save:=JourneySave.new("user://v17-items.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Real new content envelope saves/loads")
    var good:=JourneySnapshot.encode(j)
    for changes:Dictionary in [{"base":{999999:"power_band"},"spent":{},"embargo":{}},{"base":{},"spent":{j.party[0].uid:"power_band"},"embargo":{}},{"base":{},"spent":{},"embargo":{j.party[0].uid:6}},{"base":{j.party[0].uid:"unknown"},"spent":{},"embargo":{}},{"base":{},"spent":{},"embargo":{},"extra":true}]:
        var bad:=good.duplicate(true);bad["battle"]["item_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged item context/UID/gear/timer")
    var old:=journey(16);var old_state:=JourneySnapshot.encode(old);check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Frozen v16 save stays exact")
    old_state["battle"]["item_context"]={};check(not JourneySnapshot.validate(old_state),"Older route rejects empty new item context")
    var f:=FileAccess.open("/tmp/player-v16-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v16 trap checkpoint stays exact")
    check(JourneySave.compatible_content("c1df52b5a36bccf484c65fa924efeaca836536fe9bdf2701e4d67982d2ec552f"),"Actual prior content fingerprint accepted")
    check(var_to_bytes(PlayerMoveItems.data())==immutable,"Definitions stay immutable")
    h.free();print("Player move items: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
