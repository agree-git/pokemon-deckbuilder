extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=5
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"v13 public card executes: "+str(id)+why)
    return v
func quiet(b:TacticalBattle) -> void:b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}]
func power(b:TacticalBattle,id:int) -> int:return int(b.card_view(card(b,id))["preview_damage"])
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(PlayerMoveFields.data()["moves"].size()==20 and PlayerMoveFields.data()["total_enhanced"]==390,"20 field overlays /390 distinct enhanced moves")
    var immutable:=var_to_bytes(PlayerMoveFields.data());var old:=fixture();old.player_moves_version=4
    for key:String in PlayerMoveCards.data()["moves"]:
        var b:=fixture();var c:=card(b,int(key));var state:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(state==var_to_bytes(b.snapshot()) and v==b.card_view(c),"919 card previews preserve state/UID/RNG: "+key)
        check(v["player_rules"]==5 and not v["description"].is_empty() and not CardEffectText.render(v).is_empty(),"919 cards have v13 compact/full explanations: "+key)
        if not PlayerMoveFields.data()["moves"].has(key):check(v.get("preview_damage",-1)==old.card_view(c).get("preview_damage",-1),"899 unchanged attacks preserve unmodified v12 damage: "+key)
    var b:=fixture();var plain:=power(b,85);cast(b,604)
    check(power(b,85)>plain and PlayerMoveFields.read(b)["left"]==5,"Electric Terrain boosts grounded electric attacks and starts five rounds")
    cast(b,581);check(PlayerMoveFields.read(b)["terrain"]=="misty" and PlayerMoveFields.read(b)["left"]==5,"A new terrain replaces the shared terrain and refreshes duration")
    var dragon:=power(b,82);PlayerMoveFields.write(b)["terrain"]="";PlayerMoveFields.write(b)["left"]=0
    check(power(b,82)==dragon and dragon==40,"New terrain modifiers do not halve fixed Dragon Rage")
    plain=power(b,406);cast(b,581);check(power(b,406)<plain,"Misty Terrain halves a grounded target's incoming Dragon attack")
    b=fixture(6);plain=power(b,85);cast(b,604);check(power(b,85)==plain,"Flying users do not get grounded terrain bonuses")
    b.active().hp/=2;cast(b,355);check(power(b,85)>plain,"Roost's temporary grounding enables terrain bonuses immediately")
    b=fixture();quiet(b);b.active().hp-=30;b.enemy().hp-=30;var own_hp:=b.active().hp;var foe_hp:=b.enemy().hp;cast(b,580);b.end_turn()
    check(b.active().hp==own_hp+b.active().max_hp/16 and b.enemy().hp==foe_hp+b.enemy().max_hp/16,"Grassy Terrain heals the two original grounded recipients after the enemy action")
    for _i in 4:b.end_turn()
    check(PlayerMoveFields.read(b)["terrain"].is_empty() and PlayerMoveFields.read(b)["left"]==0,"Terrain expires after exactly five enemy actions")
    b=fixture();plain=power(b,89);cast(b,580);check(power(b,89)<plain,"Grassy Terrain reduces Earthquake against grounded targets")
    b=fixture();cast(b,604);var c:=card(b,156);var state:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Rest under sleep-blocking terrain is an atomic refusal")
    c=card(b,147);check(not b.card_view(c).has("sleep"),"Electric Terrain removes new sleep effects from the public player preview")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"status","value":3,"status":"burn","move_id":261}];cast(b,581);b.end_turn()
    check(not b.active().statuses.has("burn"),"Misty Terrain prevents the real enemy's new status")
    b=fixture(468);b.enemy_definitions[0]["intents"]=[{"kind":"status","value":3,"status":"burn","move_id":261}];cast(b,581);b.end_turn()
    check(not PlayerMoveFields.grounded(b,b.active()) and b.active().statuses.has("burn"),"Flying Pokemon remain outside terrain status protection")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"normal","move_id":98}];cast(b,678)
    c=card(b,98);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Psychic Terrain atomically blocks priority attacks against a grounded foe")
    own_hp=b.active().hp;check(b.intent().get("player_sealed",false),"Psychic Terrain previews the blocked enemy priority attack");b.end_turn();check(b.active().hp==own_hp,"Blocked enemy priority attack deals no actual damage")
    b=fixture(9,25);quiet(b);check(b.turn_energy_bonus==0,"Chosen fixture starts slower than the enemy")
    cast(b,366);var cached:=b.turn_speed_actor;b.end_turn();check(b.turn_energy_bonus==1 and b.turn_speed_actor==cached*2,"Tailwind affects the next energy comparison without re-granting current energy")
    cast(b,433);check(b.turn_energy_bonus==1,"Trick Room leaves the already granted bonus intact");b.end_turn();check(b.turn_energy_bonus==0,"Trick Room gives the extra energy to the slower side even under Tailwind")
    cast(b,433);check(PlayerMoveFields.read(b)["trick"]==0,"Using Trick Room again cancels it")
    b=fixture(143,95);plain=power(b,33);var incoming:int=b.intent()["value"];var base_def:=b.enemy().defense;cast(b,472)
    check(power(b,33)>plain and b.intent()["value"]<incoming and b.enemy().defense==base_def,"Wonder Room swaps defensive base stats only for damage calculations on both sides")
    cast(b,472);check(power(b,33)==plain,"Toggling Wonder Room restores ordinary damage without mutating permanent stats")
    b=fixture();c=card(b,694);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Aurora Veil requires snow without consuming anything")
    BattleWeather.apply(b,"snow");cast(b,694);var veiled:int=b.intent()["value"];cast(b,115)
    check(b.intent()["value"]==veiled,"Aurora Veil does not multiply the same native screen reduction twice")
    BattleWeather.clear(b.powers);check(b.intent()["value"]==veiled,"Aurora Veil remains after snow ends")
    b=fixture();plain=power(b,85);cast(b,300);check(power(b,85)==maxi(1,plain/3),"Mud Sport reduces both sides' Electric attacks independently of grounding")
    plain=power(b,53);cast(b,346);check(power(b,53)==maxi(1,plain/3),"Water Sport reduces Fire attacks")
    b=fixture();cast(b,604);var v:=b.card_view(card(b,805));check(v["type"]=="electric" and v["move_power"]==100,"Terrain Pulse changes actual type and doubles power")
    cast(b,678);v=b.card_view(card(b,797));check(v["move_power"]==120,"Expanding Force gets its Psychic Terrain identity")
    cast(b,604);v=b.card_view(card(b,804));check(v["move_power"]==140,"Rising Voltage doubles against a grounded Electric Terrain target")
    cast(b,580);v=b.card_view(card(b,803));check(v["cost"]==0,"Grassy Glide expresses priority as lower card cost")
    b=fixture();c=card(b,798);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Steel Roller requires an active terrain atomically")
    cast(b,604);cast(b,798);check(PlayerMoveFields.read(b)["terrain"].is_empty(),"Steel Roller removes terrain after hitting")
    cast(b,580);cast(b,861);check(PlayerMoveFields.read(b)["terrain"].is_empty(),"Ice Spinner removes terrain")
    b=fixture();cast(b,581);v=cast(b,802);check(v["move_power"]==150 and not b.party[0].alive(),"Misty Explosion boosts on terrain and actually knocks its user out")
    b=fixture();cast(b,678);v=b.card_view(card(b,267));check(v["move_id"]==94,"Nature Power prioritizes active terrain over its weather fallback")
    b.active().learned_skills.assign(["move_805","move_214"]);b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};v=cast(b,214)
    check(v["move_id"]==805 and v["type"]=="psychic" and v["player_rules"]==5,"Sleep Talk retains the v13 called move's field rule")
    b=fixture();b.active().learned_skills.assign(["move_802","move_214"]);b.active().statuses["sleep"]={"turns":2,"source_uid":b.active().uid};c=card(b,214);state=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Sleep Talk cannot bypass the new self-KO exclusion")
    b=fixture(143,241,"gym:whitney");var move:=PlayerMoveRules.write(b);move["screen"]=6;move["reflect"]=4;move["safeguard"]=3
    var field:=PlayerMoveFields.write(b);field["ally"]["tailwind"]=4;field["ally"]["veil"]=5;field["ally"]["mist"]=2
    var boss:=BossBattleRules.write(b);boss["screen"]=2;boss["safeguard"]=5;boss["rocks"]=true
    PlayerMoveTactics.write(b)["hazards"]={"rocks":1,"spikes":3,"toxic":2,"web":1};own_hp=b.active().hp;cast(b,756)
    check(field["ally"]["screen"]==2 and field["foe"]["screen"]==6 and field["foe"]["reflect"]==4 and field["foe"]["tailwind"]==4,"Court Change swaps native and new conditions with exact remaining durations")
    check(field["hazards"]["spikes"]==3 and PlayerMoveTactics.read(b)["hazards"]=={"rocks":1,"spikes":0,"toxic":0,"web":0} and not boss["rocks"] and b.active().hp==own_hp,"Court Change swaps all four hazards without applying entry damage to current actors")
    field["ally"]["safeguard"]=0;boss["rocks"]=true;var reserve:=b.party[2];var loss:=PlayerMoveFields.entry_damage(b,reserve)+BossBattleRules.entry_damage(b,reserve)
    check(loss==maxi(1,reserve.max_hp/8)+maxi(1,reserve.max_hp/4),"Native and transferred Stealth Rock cannot stack duplicate entry damage")
    own_hp=reserve.hp;b.energy=100;b.switch_to(reserve.uid)
    check(reserve.hp==own_hp-loss and reserve.statuses.get("poison",{}).get("turns",0)==5 and reserve.stat_stages.get("speed",0)==-1,"Transferred incoming hazards apply real entry damage, poison and Web once")
    boss["rocks"]=false;b.party[0].hp=1;c=card(b,33,b.party[0].uid);state=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and state==var_to_bytes(b.snapshot()),"Lethal new entry hazards block automatic switching without consuming a card")
    cast(b,432);check(field["hazards"]==PlayerMoveFields.HAZARDS and field["foe"]["veil"]==0 and field["foe"]["tailwind"]==4,"Defog clears new hazards/screens but preserves Tailwind")
    b=fixture(143,241,"gym:whitney");field=PlayerMoveFields.write(b);field["terrain"]="electric";field["left"]=5;BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,432)
    check(field["terrain"]=="electric","Protection blocks Defog's terrain removal")
    BossBattleRules.write(b)["guards"].clear();cast(b,432);check(field["terrain"].is_empty(),"Unblocked Defog removes terrain")
    b=fixture(143,241,"gym:whitney");cast(b,54);BossBattleRules.write(b)["guards"][b.enemy().uid]="king";b.active().stat_stages["attack"]=2;cast(b,33)
    check(b.active().stat_stages["attack"]==2 and PlayerMoveFields.read(b)["foe"]["mist"]==0,"Mist blocks an opponent contact guard's Attack drop and does not leak to the other side")
    BossBattleRules.write(b)["guards"].clear();cast(b,504);check(b.active().stat_stages.get("defense")==-1,"Mist does not undo its user's own Shell Smash cost")
    PlayerMoveFields.write(b)["foe"]["mist"]=5;cast(b,204);check(b.enemy().stat_stages.get("attack",0)==0,"Transferred Mist blocks player-caused enemy stage drops")
    b=fixture(242,10191,"gym:mustard")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==818:b.opening()["intent"]=i
    incoming=b.intent()["value"];cast(b,472);var altered:int=b.intent()["value"];check(altered<incoming,"Wonder Room preserves authored critical multi-hit behavior while changing defensive stats")
    b.active().block=10000;var uid:=b.active().uid;b.end_turn();var dealt:=0
    for e:Dictionary in b.events:
        if e["kind"]=="damage" and e.get("target",0)==uid:dealt+=int(e.get("amount",0))+int(e.get("blocked",0))
    check(dealt==altered,"Authored critical multi-hit executes exactly the room-adjusted preview")
    b=fixture(143,241,"gym:whitney");quiet(b)
    BossBattleRules.write(b)["drowsy"][b.active().uid]={"source":b.enemy().uid,"due":b.turn}
    cast(b,604);b.end_turn();check(not b.active().statuses.has("sleep"),"Electric Terrain blocks an already queued NPC Yawn at the player-status tick boundary")
    b=fixture();quiet(b);cast(b,581);b.active().statuses["burn"]={"turns":3,"source_uid":b.enemy().uid};var status_turns:=int(b.active().statuses["burn"]["turns"]);b.end_turn()
    check(b.active().statuses.has("burn") and int(b.active().statuses["burn"]["turns"])<status_turns,"Misty Terrain prevents new statuses without curing a pre-existing burn")
    b=fixture();b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"electric","move_id":85}];incoming=b.intent()["value"];cast(b,604)
    check(b.intent()["value"]>incoming,"Shared terrain also boosts an ordinary enemy's grounded Electric attack")
    b=fixture();cast(b,581);b.active().statuses["burn"]={"turns":3,"source_uid":b.enemy().uid};cast(b,375)
    check(b.active().statuses.has("burn") and not b.enemy().statuses.has("burn"),"Terrain-blocked Psycho Shift keeps its user's status")
    b=fixture(143,18,"champion:blue");cast(b,98)
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==119:b.opening()["intent"]=i
    cast(b,678);check(b.intent().get("player_sealed",false),"Psychic Terrain checks the actual copied attack's priority when an authored NPC uses Mirror Move")
    b=fixture(143,230,"gym:clair")
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==281:b.opening()["intent"]=i
    cast(b,604);PlayerMoveFields.write(b)["left"]=1;b.end_turn()
    check(not BossBattleRules.read(b)["drowsy"].has(b.active().uid) and PlayerMoveFields.read(b)["terrain"].is_empty(),"A blocked NPC Yawn cannot queue sleep to escape after the last terrain round expires")
    var ace:=fixture(143,10191,"gym:mustard");var regular:=fixture();regular.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":"fairy","move_id":584}]
    b=TacticalBattle.new();b.player_moves_version=5;b.start_with(ace.party,ace.draw_pile,[regular.enemy_definitions[0],ace.enemy_definitions[0]],712,"field_kit");b.full_type_chart=true
    check(BossBattleRules.modern(b) and not b.enemy_definitions[0].has("boss_moves_version") and b.intent()["value"]>0,"Ordinary member before an authored ace uses the ordinary move definition")
    cast(b,472);check(b.intent()["value"]>0,"Wonder Room also previews ordinary attacks in mixed ordinary/ace encounters")
    check(immutable==var_to_bytes(PlayerMoveFields.data()),"Field definitions remain immutable after all previews and actions")
    h.free();print("Player move fields: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
