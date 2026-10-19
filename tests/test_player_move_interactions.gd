extends SceneTree
var checks:=0
var failures:=0
var h:SceneTree
func check(ok:bool,msg:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(msg)
func fixture(boss:=false) -> TacticalBattle:
    var b:TacticalBattle=h.fixture(143,241 if boss else 143,"gym:whitney" if boss else "")
    b.player_moves_version=16;HeldItems.initialize(b);return b
func card(b:TacticalBattle,id:int) -> BattleCardInstance:return h.card(b,id)
func cast(b:TacticalBattle,id:int) -> Dictionary:
    var c:=card(b,id);var v:=b.card_view(c);var why:=b.play_card(c.uid)
    check(why.is_empty(),"Cast %d: %s" % [id,why]);return v
func generic(b:TacticalBattle,id:int,type_name:="normal") -> void:
    b.enemy_definitions[0]["intents"]=[{"kind":"attack","value":10,"type":type_name,"move_id":id}]
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
    check(CampaignRoute.VERSION==24 and PlayerTechniques.version(24)==16 and PlayerMoveInteractions.data()["flags"].size()==919 and PlayerMoveInteractions.data()["changed"].size()==36,"v24 / complete flag catalog /36 corrections")
    var immutable:=var_to_bytes(PlayerMoveInteractions.data())
    for key:String in PlayerMoveInteractions.data()["changed"]:
        var id:=int(key);var b:=fixture();var c:=card(b,id);var before:=var_to_bytes(b.snapshot());var v:=b.card_view(c)
        check(before==var_to_bytes(b.snapshot()) and v==b.card_view(c) and v["player_rules"]==16,"Pure new interaction preview "+key)
        c.upgraded=true;check(not CardEffectText.render(b.card_view(c)).is_empty(),"Upgraded text remains available "+key)
    for id:int in [19,91,165,264,291,340]:check(PlayerMoveInteractions.flag(id,1),"Multiline source flags retain legacy contact "+str(id))
    for id:int in [623,625,657]:check(PlayerMoveInteractions.data()["flags"][str(id)]==PlayerMoveCards.data()["flags"].get(str(id),[]),"Missing special Z variant preserves original flags")
    var b:=fixture();b.enemy().held_item="rocky_helmet";HeldItems.initialize(b);b.active().hp=1
    var c:=card(b,865);var v:=b.card_view(c);var hp:=b.enemy().hp;var own:=b.active();b.play_card(c.uid)
    check(not own.alive() and b.phase==TacticalBattle.REPLACE and hp-b.enemy().hp==v["preview_hp_loss"],"Contact multi-hit preview stops when Helmet KOs attacker")
    check(b.events.filter(func(e:Dictionary):return e["kind"]=="damage" and e.get("target",0)==b.enemy().uid).size()==1,"Triple Dive ends after first damaging contact")
    b=fixture();b.enemy().held_item="rocky_helmet";HeldItems.initialize(b);hp=b.active().hp;cast(b,879)
    check(hp-b.party[0].hp==maxi(1,b.party[0].max_hp/6),"Special Electro Drift still makes contact")
    b=fixture();b.enemy().held_item="rocky_helmet";HeldItems.initialize(b);hp=b.active().hp;cast(b,888)
    check(b.party[0].hp==hp,"Noncontact Twin Beam never triggers Helmet")
    for id:int in [871,914,917]:
        b=fixture(true);BossBattleRules.write(b)["substitutes"][b.enemy().uid]=10000
        if id==914:b.enemy().stat_stages["attack"]=1
        c=card(b,id);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
        check(hp-b.enemy().hp==v["preview_hp_loss"] and v["preview_hp_loss"]>0 and BossBattleRules.read(b)["substitutes"][b.enemy().uid]==10000,"New sound bypasses Substitute in preview and execution "+str(id))
        if id==914:check(b.enemy().statuses.has("confusion"),"Alluring Voice secondary confusion also bypasses Substitute")
        if id==917:check(PlayerMoveTactics.read(b)["heal_block"].get(b.enemy().uid,0)>=b.turn,"Psychic Noise heal block bypasses Substitute")
        b=fixture(true);BossBattleRules.write(b)["silence"][b.active().uid]=b.turn+2;c=card(b,id);var before:=var_to_bytes(b.snapshot())
        check(b.card_reason(c.uid).contains("음성") and not b.play_card(c.uid).is_empty() and before==var_to_bytes(b.snapshot()),"Throat Chop refusal is atomic for new sound "+str(id))
    b=fixture(true);BossBattleRules.write(b)["substitutes"][b.enemy().uid]=10000;hp=b.enemy().hp;cast(b,33)
    check(b.enemy().hp==hp and BossBattleRules.read(b)["substitutes"][b.enemy().uid]<10000,"Ordinary attacks still hit Substitute")
    b=fixture();generic(b,871,"fire");PlayerMoveRules.write(b)["substitutes"][b.active().uid]=10000;var a:=b.intent();hp=b.active().hp;b.end_turn()
    check(hp-b.party[0].hp==a["value"] and PlayerMoveRules.read(b)["substitutes"][b.party[0].uid]==10000,"Opponent sound bypasses player's Substitute")
    b=fixture();generic(b,917,"psychic");PlayerMoveRules.write(b)["silence"][b.enemy().uid]=b.turn+2;hp=b.active().hp;check(b.intent().get("player_sealed",false),"New opposing sound is previewed as sealed");b.end_turn()
    check(b.party[0].hp==hp and b.opening()["intent"]==1,"Sealed opposing sound never attacks and advances once")
    b=fixture();generic(b,879,"electric");b.active().held_item="rocky_helmet";HeldItems.initialize(b);hp=b.enemy().hp;b.end_turn()
    check(hp-b.enemy().hp==maxi(1,b.enemy().max_hp/6),"Opponent special contact triggers player's Helmet")
    for id:int in [887,910]:
        b=fixture(true);BossBattleRules.write(b)["guards"][b.enemy().uid]="king";c=card(b,id);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
        check(hp-b.enemy().hp==v["preview_hp_loss"] and v["preview_hp_loss"]>0 and BossBattleRules.read(b)["guards"].get(b.enemy().uid)=="king","Guard bypass preserves actual guard "+str(id))
        check(b.active().stat_stages.get("attack",0)==0 and b.enemy().stat_stages.get("attack",0)==0,"Bypass has no contact guard retaliation or fabricated attack drop")
        hp=b.enemy().hp;cast(b,33);check(b.enemy().hp==hp and b.active().stat_stages.get("attack",0)==-2,"Preserved King's Shield blocks and counters next regular contact")
        b=fixture();generic(b,id);cast(b,588);hp=b.active().hp;a=b.intent();b.end_turn()
        check(a["value"]>0 and hp-b.party[0].hp==a["value"] and b.enemy().stat_stages.get("attack",0)==0,"Opponent bypass ignores player's King's Shield without retaliation")
    b=fixture();generic(b,910,"rock");cast(b,852);hp=b.active().hp;b.end_turn()
    check(b.party[0].hp<hp and b.enemy().stat_stages.get("speed",0)==0,"Silk Trap does not retaliate against guard-bypassing contact")
    b=fixture();generic(b,872,"water");cast(b,852);hp=b.active().hp;b.end_turn()
    check(b.party[0].hp==hp and b.enemy().stat_stages.get("speed",0)==-1,"Silk Trap recognizes new contact move")
    b=fixture(true);BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";c=card(b,871);v=b.card_view(c);b.play_card(c.uid)
    check(not v.has("stat_changes") and b.active().stat_stages.get("special_attack",0)==0,"Protected Torch Song never grants on-hit self boost")
    b=fixture();b.enemy().types.assign(["ghost"]);b.enemy().type="ghost";hp=b.enemy().hp;v=cast(b,370)
    check(b.enemy().hp==hp and not v.has("stat_changes") and b.active().stat_stages.is_empty(),"Immune Close Combat never applies on-hit self drops")
    b=fixture();cast(b,370);check(b.active().stat_stages.get("defense",0)==-1 and b.active().stat_stages.get("special_defense",0)==-1,"Successful Close Combat keeps its normal penalties")
    b=fixture(true);BossBattleRules.write(b)["airborne"][b.enemy().uid]=true;c=card(b,614);v=b.card_view(c);hp=b.enemy().hp;b.play_card(c.uid)
    check(v["move_id"]==614 and hp-b.enemy().hp==v["preview_hp_loss"] and v["preview_hp_loss"]>0,"New filter preserves Thousand Arrows true ID and aerial hit")
    check(not BossBattleRules.read(b)["airborne"].get(b.enemy().uid,false) and BossBattleRules.read(b)["last_moves"][b.active().uid]["move"]==614,"Thousand Arrows grounds and records original move")
    b=fixture();b.enemy().types.assign(["ground"]);b.enemy().type="ground";BattleWeather.apply(b,"rain");hp=b.enemy().hp;cast(b,905)
    check(b.enemy().hp==hp and b.active().stat_stages.get("special_attack",0)==1,"Legitimate Electro Shot preparation boost survives final attack immunity")
    b=fixture(true);b.player_moves_version=15;BossBattleRules.write(b)["guards"][b.enemy().uid]="protect";cast(b,871)
    check(b.active().stat_stages.get("special_attack",0)==1 and not PlayerMoveCards.flag(871,9),"Frozen v23 keeps its old effect and flag table")
    check(PlayerTechniques.definition(TacticalMoves.key_for(910),15).get("stat_changes",{}).get("attack",0)==-1 and not PlayerTechniques.definition(TacticalMoves.key_for(910),16).has("stat_changes"),"Mighty Cleave correction applies only to new effect version")
    var j:=journey();var pending:=jcard(j,248);check(j.battle.play_card(pending.uid).is_empty(),"New expedition retains pending future attack");pending=jcard(j,871);var state:=JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(state),"Live v24 flags with existing contexts validate")
    if JourneySnapshot.validate(state):
        var copy:=JourneySnapshot.restore(state);check(JourneySnapshot.encode(copy)==state,"Live v24 state restores exactly")
        check(j.battle.play_card(pending.uid).is_empty() and copy.battle.play_card(pending.uid).is_empty() and JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Same sound card after save produces same state/RNG")
        j.battle.end_turn();copy.battle.end_turn();check(JourneySnapshot.encode(j)==JourneySnapshot.encode(copy),"Same following opponent action and existing timers after reload")
    var save:=JourneySave.new("user://interactions-v24.json");check(save.save(j).is_empty() and save.load_journey()!=null,"Actual v24 save envelope reloads")
    var f:=FileAccess.open("/tmp/player-v23-before.bin",FileAccess.READ)
    if f!=null:
        var old:Dictionary=f.get_var();check(JourneySnapshot.validate(old["state"]),"Actual pre-edit v23 checkpoint remains valid")
        if JourneySnapshot.validate(old["state"]):
            var restored:=JourneySnapshot.restore(old["state"]);check(JourneySnapshot.encode(restored)==old["state"],"Actual v23 state remains exact")
            restored.battle.end_turn();check(JourneySnapshot.encode(restored)==old["next"],"Actual v23 next input/effects/RNG remain exact")
        check(JourneySave.compatible_content(old["fingerprint"]),"Actual previous fingerprint accepted")
        var bad:Dictionary=old["state"].duplicate(true);bad["battle"]["player_moves_version"]=16;check(not JourneySnapshot.validate(bad),"Old route rejects forced new interaction rules")
    check(var_to_bytes(PlayerMoveInteractions.data())==immutable,"New metadata stays immutable")
    h.free();print("Player interactions: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
