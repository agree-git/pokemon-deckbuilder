extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(gear:="",foe_gear:="",ally:=143,foe:=143,boss:="") -> TacticalBattle:
    var b:TacticalBattle=h.fixture(ally,foe,boss);b.player_moves_version=13
    b.active().held_item=gear;b.enemy().held_item=foe_gear;HeldItems.initialize(b)
    return b
func card(b:TacticalBattle,id:int,owner:=0) -> BattleCardInstance:return h.card(b,id,owner)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);check(b.play_card(c.uid).is_empty(),"Card executes: "+str(id));return v
func power(b:TacticalBattle,id:int) -> int:return int(b.card_view(card(b,id))["preview_damage"])
func generic(b:TacticalBattle,id:int,type_name:="normal",hits:=1) -> void:
    b.enemy_definitions[0]["intents"]=[{"kind":"barrage" if hits>1 else "attack","value":10,"move_id":id,"type":type_name,"hits":hits}]
func select_move(b:TacticalBattle,id:int) -> void:
    for i in b.enemy_definitions[0]["intents"].size():
        if b.enemy_definitions[0]["intents"][i]["move_id"]==id:b.opening()["intent"]=i;return
    check(false,"Authored move exists")
func journey(version:=21,gear:="sitrus_berry") -> TacticalJourney:
    var j:=TacticalJourney.new(712,"field_kit",[143,6,9],true,version)
    for p:BattlePokemon in j.party:p.level=50;PokemonStats.apply(p,true)
    if version>=21:j.party[0].held_item=gear
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"]!="rest" and j.route.opponents(i).size()>1:j.step=i;j.phase=TacticalJourney.MAP;j.enter_next();break
    return j
func jcast(j:TacticalJourney,id:int) -> void:
    var c:=card(j.battle,id);j.deck.append(c);j._next_card_uid=j.battle._next_uid
    check(j.battle.play_card(c.uid).is_empty(),"Real journey card executes")
func _initialize() -> void:call_deferred("run")
func run() -> void:
    h=load(get_script().resource_path.get_base_dir().path_join("test_player_move_cards.gd")).new()
    check(CampaignRoute.VERSION==21 and HeldItems.catalog().size()==55 and TacticalContent.HELD_ITEMS.size()==61,"55 real items; six legacy definitions retained")
    check(HeldItems.reward_keys(21).size()==55 and HeldItems.reward_keys(20)==TacticalContent.LEGACY_HELD_ITEMS.keys(),"New rewards use only real items; old pool stays exact")
    var immutable:=var_to_bytes(HeldItems.data())
    for key:String in HeldItems.catalog():
        var b:=fixture(key);var c:=card(b,33);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c);var a:=b.intent();var d:Dictionary=TacticalContent.HELD_ITEMS[key]
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and a==b.intent(),"Item previews remain pure: "+key)
        check(not d["description"].is_empty() and CombatWidgets.texture(d["icon"])!=null and int(d["source_id"])>0,"Real localized item has imported sprite: "+key)
    var normal:=fixture();var physical:=power(normal,33);var special:=power(normal,94)
    var b:=fixture("choice_band");check(power(b,33)>physical and power(b,94)==special,"Choice Band boosts physical Attack only")
    cast(b,33);var c:=card(b,94);var before:=var_to_bytes(b.snapshot())
    check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Choice lock rejects other technique atomically")
    b.energy=100;b.switch_to(b.party[1].uid);b.switch_to(b.party[0].uid);check(b.card_reason(c.uid).is_empty(),"Switching releases choice lock")
    b=fixture("choice_specs");check(power(b,94)>special and power(b,33)==physical,"Choice Specs boosts Special Attack only")
    b=fixture("choice_scarf");var speed:=PokemonStats.effective(b.active(),"speed");b._grant_turn_energy();check(b.turn_speed_actor==floori(speed*1.5),"Choice Scarf affects the actual speed/energy comparison")
    b=fixture("assault_vest");c=card(b,45);before=var_to_bytes(b.snapshot());check(not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Assault Vest rejects status technique without spending or switching")
    var bare:=fixture("","",1);generic(bare,94,"psychic");b=fixture("eviolite","",1);generic(b,94,"psychic")
    check(b.intent()["value"]<bare.intent()["value"],"Eviolite reduces actual damage against an evolvable species")
    bare=fixture("","",3);generic(bare,94,"psychic");b=fixture("eviolite","",3);generic(b,94,"psychic")
    check(b.intent()["value"]==bare.intent()["value"],"Eviolite does not boost a final evolution")
    for pair:Array in [["light_ball",25],["thick_club",104],["deep_sea_tooth",366],["deep_sea_scale",366]]:
        bare=fixture("","",pair[1]);b=fixture(pair[0],"",pair[1])
        if pair[0]=="deep_sea_scale":generic(bare,94,"psychic");generic(b,94,"psychic");check(b.intent()["value"]<bare.intent()["value"],"Species-specific special defense effect")
        else:check(power(b,33 if pair[0]=="thick_club" else 94)>power(bare,33 if pair[0]=="thick_club" else 94),"Species-specific attack effect")
    b=fixture("charcoal");check(power(b,53)>power(fixture(),53) and power(b,33)==physical,"Type booster applies only to matching type")
    b=fixture("life_orb");var p:=b.active();var hp:=p.hp;var v:=cast(b,33)
    check(v["preview_damage"]>physical and hp-p.hp==maxi(1,p.max_hp/10),"Life Orb boosts damage and recoils once after a landed attack")
    b=fixture("life_orb","",143,94);hp=b.active().hp;cast(b,33);check(b.active().hp==hp,"Immune Life Orb attack causes no recoil")
    b=fixture("shell_bell");p=b.active();p.hp=p.max_hp/2;b.enemy().hp=8;hp=p.hp;cast(b,33)
    check(p.hp==hp+1,"Shell Bell heals from actual overkill-capped HP damage")
    b=fixture("focus_sash");p=b.active();b.enemy().strength=1000;generic(b,33);b.end_turn()
    check(p.hp==1 and p.held_item.is_empty() and b.held_context["used"].has(p.uid),"Full-health Focus Sash survives a lethal direct attack and is consumed")
    b._clear_statuses();check(p.held_item.is_empty(),"Consumed Sash is not restored after battle")
    b=fixture("focus_sash");p=b.active();b.enemy().strength=1000;generic(b,3,"normal",2);b.end_turn()
    check(not p.alive() and b.phase==TacticalBattle.REPLACE,"Sash survives first hit only; later multi-hit damage can KO")
    b=fixture("","focus_sash");b.active().strength=1000;c=card(b,33);v=b.card_view(c);b.play_card(c.uid)
    check(b.enemy().hp==1 and v["preview_target_hp"]==1,"Opponent Sash is represented in real card preview and damage")
    for key:String in ["oran_berry","sitrus_berry"]:
        b=fixture(key);p=b.active();var loss:=p.max_hp*3/4;hp=p.hp;b._damage(p,loss,true)
        var amount:=10 if key=="oran_berry" else maxi(1,p.max_hp/4)
        check(p.hp==mini(p.max_hp,hp-loss+amount) and p.held_item.is_empty(),"Healing berry triggers once after HP damage")
        b._clear_statuses();check(p.held_item.is_empty(),"Consumed berry remains spent after battle")
    b=fixture("lum_berry");p=b.active();p.statuses["seed"]={"turns":3,"source_uid":b.enemy().uid};HeldItems.react(b,p)
    check(p.held_item=="lum_berry","Lum does not waste itself on Leech Seed")
    p.statuses["poison"]={"turns":3,"source_uid":b.enemy().uid};p.statuses["confusion"]={"turns":3,"source_uid":b.enemy().uid};HeldItems.react(b,p)
    check(p.held_item.is_empty() and p.statuses.has("seed") and not p.statuses.has("poison") and not p.statuses.has("confusion"),"Lum cures major status/confusion, preserving unrelated effects")
    for key:String in ["liechi_berry","ganlon_berry","salac_berry","petaya_berry","apicot_berry"]:
        b=fixture(key);p=b.active();p.hp=maxi(1,p.max_hp/4);HeldItems.react(b,p)
        check(p.held_item.is_empty() and p.stat_stages[HeldItems.data()["items"][key]["stat"]]==1,"Low-HP stat berry boosts one correct stat and consumes")
    b=fixture("white_herb");p=b.active();p.stat_stages={"attack":-2,"defense":1};HeldItems.react(b,p)
    check(p.held_item.is_empty() and not p.stat_stages.has("attack") and p.stat_stages["defense"]==1,"White Herb clears only lowered stages")
    b=fixture("","clear_amulet");cast(b,45);check(int(b.enemy().stat_stages.get("attack",0))==0,"Clear Amulet prevents opposing Growl")
    b=fixture("weakness_policy");p=b.active();generic(b,280,"fighting");b.end_turn()
    check(p.alive() and p.held_item.is_empty() and p.stat_stages.get("attack")==2 and p.stat_stages.get("special_attack")==2,"Weakness Policy consumes after super-effective HP damage and boosts both attacks")
    b=fixture("leftovers");p=b.active();p.hp=p.max_hp/2;hp=p.hp;b.enemy_definitions[0]["intents"]=[{"kind":"block","value":0,"move_id":182}];b.end_turn()
    check(p.hp==hp+maxi(1,p.max_hp/16),"Leftovers heals only the active holder at round end")
    b=fixture("black_sludge","",94);p=b.active();p.hp=p.max_hp/2;hp=p.hp;HeldItems.end_round(b,b.enemy());check(p.hp==hp+maxi(1,p.max_hp/16),"Black Sludge heals a Poison holder")
    b=fixture("black_sludge");p=b.active();hp=p.hp;HeldItems.end_round(b,b.enemy());check(hp-p.hp==maxi(1,p.max_hp/8),"Black Sludge damages other holders")
    b=fixture("flame_orb");p=b.active();HeldItems.end_round(b,b.enemy());check(p.statuses.has("burn") and p.held_item=="flame_orb","Flame Orb applies status without consumption")
    b=fixture("flame_orb","",6);HeldItems.end_round(b,b.enemy());check(not b.active().statuses.has("burn"),"Fire type retains burn immunity")
    for boss:String in ["","gym:mustard"]:
        b=fixture("rocky_helmet","",143,10191 if not boss.is_empty() else 143,boss);b.enemy().hp=1;p=b.active();hp=p.hp
        if boss.is_empty():generic(b,24,"fighting",3)
        else:select_move(b,818)
        var expected:int=int(b.intent().get("per_hit",b.intent()["value"]));b.end_turn()
        check(b.phase==TacticalBattle.WON and hp-p.hp==mini(hp,expected),"Helmet KO stops remaining generic/authored contact hits")
    b=fixture("","rocky_helmet");p=b.active();p.hp=1;var foe_hp:=b.enemy().hp;v=cast(b,24)
    check(not p.alive() and b.enemy().hp==v["preview_target_hp"] and b.enemy().hp<foe_hp and b.phase==TacticalBattle.REPLACE,"Player contact KO also stops multi-hit sequence and agrees with preview")
    b=fixture("sitrus_berry");p=b.active();b._damage(p,p.max_hp*3/4,true);p.hp=p.max_hp;cast(b,278)
    check(p.held_item=="sitrus_berry" and b.held_context["used"].is_empty(),"Recycle restores consumed berry and clears permanent-spent token")
    b._clear_statuses();check(p.held_item=="sitrus_berry","Recycled item survives battle cleanup")
    b=fixture("sitrus_berry");p=b.active();cast(b,271);b._damage(b.enemy(),b.enemy().max_hp*3/4,true)
    check(b.held_context["used"].has(p.uid),"Opponent consuming traded berry marks original owner token")
    b._clear_statuses();check(p.held_item.is_empty() and b.enemy().held_item.is_empty(),"Traded/consumed item neither returns nor duplicates")
    b=fixture("sitrus_berry","sitrus_berry");p=b.active();var foe:=b.enemy();cast(b,271);b._damage(p,p.max_hp*3/4,true);b._clear_statuses()
    check(p.held_item=="sitrus_berry" and foe.held_item.is_empty(),"Two identical berries keep distinct original ownership through swap/consumption")
    b=fixture("thick_club");v=cast(b,374);p=b.active();check(v["move_power"]==90 and p.held_item.is_empty(),"Fling uses actual item power and consumes")
    b._clear_statuses();check(p.held_item.is_empty(),"Thrown item remains lost after battle")
    b=fixture("flame_orb");cast(b,374);check(b.enemy().statuses.has("burn"),"Thrown Flame Orb applies its original burn effect")
    b=fixture("choice_band");cast(b,478);check(power(b,33)==physical,"Magic Room disables real equipment bonuses")
    b=fixture("","leftovers");cast(b,373);var enemy_hp:=b.enemy().max_hp/2;b.enemy().hp=enemy_hp;HeldItems.end_round(b,b.enemy());check(b.enemy().hp==enemy_hp,"Embargo suppresses original item recovery")
    for id:int in [33,94,614,805]:
        b=fixture();c=card(b,id);v=b.card_view(c);b.player_moves_version=12;check(v["preview_damage"]==b.card_view(c)["preview_damage"],"Without official gear, selected v20 player damage remains exact")
    var j:=journey();p=j.party[0];j.battle._damage(p,p.max_hp*3/4,true);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Consumed equipment/ownership live save validates")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Ownership/consumption roundtrip exact")
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Loaded ownership preserves same next action and RNG")
        j.battle._clear_statuses();copy.battle._clear_statuses();check(p.held_item.is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Loaded consumed item remains lost after cleanup")
    j=journey(21,"choice_band");jcast(j,33);state=JourneySnapshot.encode(j);check(JourneySnapshot.validate(state) and HeldItems.read(j.battle)["choice"].has(j.party[0].uid),"Live choice-lock checkpoint validates")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(HeldItems.read(copy.battle)["choice"]==HeldItems.read(j.battle)["choice"],"Choice lock restores exact move UID ownership")
    var save:=JourneySave.new("user://held-items-v21.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual content envelope saves/reloads")
    var frame:=BattleFrame.capture(j.battle);var detached:=var_to_bytes(frame);j.battle.held_context["choice"].clear();check(var_to_bytes(frame)==detached,"Animation frame detaches item context")
    j.phase=TacticalJourney.REST;j.held_inventory.assign(["life_orb","sitrus_berry"])
    check(j.equip_held("life_orb",j.party[1].uid).is_empty() and j.equip_held("sitrus_berry",j.party[1].uid).is_empty() and "life_orb" in j.held_inventory,"Camp equipment replacement returns exactly one previous official item")
    var good:=state
    for changes:Dictionary in [{"originals":{999999:"life_orb"},"owners":{},"used":{},"spent":{},"choice":{}},{"originals":{},"owners":{},"used":{j.party[0].uid:true},"spent":{},"choice":{}},{"originals":{},"owners":{},"used":{},"spent":{},"choice":{j.party[0].uid:9999}}]:
        var bad:=good.duplicate(true);bad["battle"]["held_context"]=changes;check(not JourneySnapshot.validate(bad),"Reject forged gear ownership/consumption/move")
    var old:=journey(20,"");var old_state:=JourneySnapshot.encode(old);check(JourneySnapshot.validate(old_state) and JourneySnapshot.encode(JourneySnapshot.restore(old_state))==old_state,"Old v20 save remains exact")
    old_state["battle"]["held_context"]={};check(not JourneySnapshot.validate(old_state),"Old run rejects empty new equipment state")
    var f:=FileAccess.open("/tmp/player-v20-before.bin",FileAccess.READ)
    if f!=null:
        var captured:Dictionary=bytes_to_var(f.get_buffer(f.get_length()));check(JourneySnapshot.validate(captured) and JourneySnapshot.encode(JourneySnapshot.restore(captured))==captured,"Actual pre-edit v20 legacy trade/Perish/aim save remains exact")
        for group:String in ["base","spent"]:
            var bad:=captured.duplicate(true);bad["battle"]["item_context"][group][captured["battle"]["party"][0]]="life_orb"
            check(not JourneySnapshot.validate(bad),"Old item context rejects injected official item")
    check(JourneySave.compatible_content("ce4af07f1969b96ef5c76e2ae6190129bf97ad37942afc3bf76a0e6632a541d0"),"Actual previous fingerprint accepted")
    check(var_to_bytes(HeldItems.data())==immutable,"Catalog remains immutable")
    h.free();print("Held items: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
