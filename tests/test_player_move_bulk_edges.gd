extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_bulk.gd")).new()
    h.h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    for id:int in [387,507,809]:
        var b:TacticalBattle=h.fixture();var c:BattleCardInstance=h.card(b,id);var before:=var_to_bytes(b.snapshot())
        check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Conditional refusal is atomic "+str(id))
        h.setup(b,id);check(b.play_card(c.uid).is_empty(),"Correct precondition allows "+str(id))
    var j:TacticalJourney=h.journey();h.jcast(j,33);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Baseline new state validates before corruption")
    for forged:Dictionary in [{"extra":true},PlayerMoveBulk.DEFAULT.merged({"cover":999999},true),PlayerMoveBulk.DEFAULT.merged({"forms":{999999:{"species":143,"moves":[33]}}},true)]:
        var bad:=state.duplicate(true);bad["battle"]["bulk_context"]=forged;check(not JourneySnapshot.validate(bad),"Reject malformed shape/timer/UID")
    var b:TacticalBattle=h.h.fixture(143,241,"gym:whitney");b.player_moves_version=15;HeldItems.initialize(b)
    BossBattleRules.write(b)["rocks"]=true;b.party[1].hp=1;b.party[2].hp=0;b.party[2].knocked_out=true
    var c:BattleCardInstance=h.card(b,913);check(b.card_reason(c.uid).is_empty(),"Party cheer does not require its ally to survive hypothetical entry hazards")
    c=h.card(b,502);check(not b.card_reason(c.uid).is_empty(),"Ally Switch still rejects lethal entry")
    b=h.h.fixture(143,241,"gym:whitney");b.player_moves_version=15;HeldItems.initialize(b)
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==34:b.opening()["intent"]=i
    h.cast(b,266);var preview:=b.intent();var hp:=b.active().hp;b.end_turn()
    check(hp-b.party[0].hp==mini(hp,int(preview["value"])),"Authored opponent's covered damage equals preview")
    b=h.h.fixture(143,241,"gym:whitney");b.player_moves_version=15;HeldItems.initialize(b);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect"
    c=h.card(b,887);var v:=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(v["preview_hp_loss"]>0 and hp-b.enemy().hp==v["preview_hp_loss"] and not BossBattleRules.read(b)["guards"].has(b.enemy().uid),"Hyper Drill preview and actual protection bypass agree")
    j=h.journey();h.jcast(j,248);b=j.battle;var old_foe:=b.enemy();old_foe.hp=0;old_foe.knocked_out=true;b._outcome();b.turn=2;var next:=b.enemy();hp=next.hp
    PlayerMoveBulk.after_enemy(b,old_foe,b.active(),{"move_id":33},{});check(next.hp<hp and b.bulk_context["future"].is_empty(),"Due future hit targets current opponent after original opponent departs")
    j=h.journey();h.jcast(j,662);state=JourneySnapshot.encode(j);check(JourneySnapshot.validate(state) and JourneySnapshot.encode(JourneySnapshot.restore(state))==state,"New attack's trapping uses compatible link/save representation")
    j=h.journey();var reserve:=j.party[1];var owned:BattleCardInstance=h.card(j.battle,33,reserve.uid);j.deck.append(owned);j._next_card_uid=j.battle._next_uid
    j.battle._damage(reserve,reserve.hp,true);h.jcast(j,863);state=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state) and JourneySnapshot.encode(JourneySnapshot.restore(state))==state,"Revival and returned KO cards retain valid saved ownership")
    check(load("res://scripts/ui/tactical_ui.gd")!=null,"Changed status badges and transformed battle sprite UI compile headlessly")
    late_cases()
    final_items()
    check(h.failures==0,"Shared helper casts succeeded")
    h.h.free();h.free();print("Player bulk edges: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
func late_cases() -> void:
    var b:TacticalBattle=h.fixture();h.cast(b,901);var owner:=b.active();var c:BattleCardInstance=h.card(b,901)
    check(not b.card_reason(c.uid).is_empty(),"Blood Moon initially locks repeat")
    b._change_active(b.party[1].uid);b._change_active(owner.uid)
    check(b.card_reason(c.uid).is_empty(),"Switch alone resets Blood Moon repeat lock")
    b=h.fixture();b.enemy().held_item="clear_amulet";HeldItems.initialize(b);h.generic(b,45,"status");b.enemy_definitions[0]["intents"][0]["status"]="poison";h.cast(b,277);b.end_turn()
    check(b.enemy().stat_stages.get("attack",0)==0 and b.party[0].stat_stages.get("attack",0)==0,"Reflected stat drop still respects foe Clear Amulet")
    b=h.fixture();h.generic(b,227,"status");b.enemy_definitions[0]["intents"][0]["status"]="poison";PlayerMoveTactics.write(b)["last"][b.enemy().uid]=33;h.cast(b,277);b.end_turn()
    check(PlayerMoveTactics.read(b)["encore"].get(b.enemy().uid,{}).get("move",0)==33 and not b.party[0].statuses.has("poison"),"Reflected Encore applies prior move restriction instead of silently dropping effect")
    b=h.fixture();h.cast(b,144);check(PlayerMoveBulk.known_moves(b,b.active())==[33],"Transform exposes copied battle moves to move-dependent restrictions")
func final_items() -> void:
    var b:TacticalBattle=h.fixture();b.enemy().held_item="clear_amulet";HeldItems.initialize(b);h.generic(b,45,"status");b.enemy_definitions[0]["intents"][0]["status"]="poison";h.cast(b,277);b.end_turn()
    check(b.enemy().stat_stages.get("attack",0)==0 and b.party[0].stat_stages.get("attack",0)==0,"Reflected stat drop respects actual Clear Amulet rule")
    b=h.fixture();var owner:=b.active();owner.held_item="choice_band";HeldItems.initialize(b);h.cast(b,502)
    check(b.active()!=owner and not HeldItems.read(b)["choice"].has(owner.uid),"Ally Switch clears Choice lock after action bookkeeping")
