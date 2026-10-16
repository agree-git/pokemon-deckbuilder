extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func compare(b: TacticalBattle,card: BattleCardInstance,capture_check: Callable = Callable()) -> Dictionary:
    b.hand.assign([card,BattleCardInstance.new(9101,"guard",0)])
    var before := b.snapshot()
    var pokemon_refs := b.party.duplicate()
    var hand_refs := b.hand.duplicate()
    var forecast := BattleCardPreview.analyze(b,card.uid,capture_check)
    check(b.snapshot() == before,"Preview cannot alter combatants, piles, RNG, flags, history or statistics")
    check(b.party == pokemon_refs and b.hand == hand_refs,"Preview keeps live object identity")
    check(forecast["reason"] == "","Legal card has a forecast")
    if not str(forecast["reason"]).is_empty(): return forecast
    var target_index := b.enemy_index
    check(b.play_card(card.uid).is_empty(),"The predicted action is legal")
    check(forecast["actor_after"] == BattleFrame.member(b.active()),"Actor HP/shield/stages/status match actual card resolution")
    check(forecast["target_after"] == BattleFrame.member(b.enemies[target_index]),"Original target matches actual action even after KO/replacement")
    check(forecast["energy_after"] == b.energy,"Relics, discounts and energy match actual resolution")
    check(forecast["intent"] == b.intent(),"Next enemy intent uses the resulting actor and status")
    check(forecast["won"] == (b.phase == TacticalBattle.WON),"Victory forecast matches real outcome")
    check(not forecast.has("hand") and not forecast.has("draw_pile") and not forecast.has("events"),"Preview does not expose drawn cards or hidden pile order")
    return forecast
func run() -> void:
    var techniques := [33,52,55,73,92,105,115,156,162,165,182,207,276,315,354]
    for relic: String in ["field_kit","relay_core","ace_core","status_core","shield_core","supply_core"]:
        var keys: Array = TacticalContent.CARDS.keys()
        for move: int in techniques: keys.append(TacticalMoves.key_for(move))
        for key: String in keys:
            for upgraded: bool in [false,true]:
                var b := TacticalBattle.new(42,relic)
                b.full_type_chart = true
                b.energy = 20
                b.relics.append_array(["switch_power","relay_cell","relay_draw","tool_belt","ace_emblem","status_flask","status_lens"])
                b.powers = {"relay":1,"supply":1,"attrition":1}
                b.active().hp = maxi(1,b.active().max_hp-8)
                b.active().block = 14
                b.party[1].held_item = "relay_ribbon"
                b.party[1].friendship = 70
                b.party[1].hp = maxi(1,b.party[1].max_hp-7)
                b.enemy().block = 6
                b.enemy().statuses = {"poison":{"turns":2,"source_uid":b.active().uid},"seed":{"turns":2,"source_uid":b.active().uid}}
                var card := BattleCardInstance.new(9100,key,b.party[1].uid if key.begins_with("move_") else 0)
                card.upgraded = upgraded
                compare(b,card)
    # KO predicts the original target, never the newly sent-out Pokemon's HP.
    var b := TacticalBattle.new(42)
    b.enemy().hp = 1
    var forecast := compare(b,BattleCardInstance.new(9100,"move_33",b.active().uid))
    check(forecast["target_after"]["hp"] == 0 and forecast["enemy_changed"] and b.enemy_index == 1,"Enemy replacement cannot overwrite the KO preview")
    b = TacticalBattle.new(42)
    b.enemies.resize(1)
    b.enemy_states.resize(1)
    b.enemy_definitions.resize(1)
    b.enemy().hp = 1
    forecast = compare(b,BattleCardInstance.new(9100,"move_33",b.active().uid))
    check(forecast["won"],"Final enemy KO predicts victory")
    b = TacticalBattle.new(42)
    b.hand.assign([BattleCardInstance.new(9100,"move_33",b.party[1].uid)])
    b.energy = 0
    var before := b.snapshot()
    check(not str(BattleCardPreview.analyze(b,9100)["reason"]).is_empty(),"Energy shortage blocks forecast")
    check(not str(BattleCardPreview.analyze(b,-999)["reason"]).is_empty(),"Missing cards cannot be simulated")
    check(b.snapshot() == before,"Invalid previews leave state untouched")
    b.energy = 4
    b.party[1].hp = 0
    check(not str(BattleCardPreview.analyze(b,9100)["reason"]).is_empty(),"KO owner's card has no legal forecast")
    b = TacticalBattle.new(42,"ace_core")
    forecast = compare(b,BattleCardInstance.new(9100,"move_33",b.active().uid))
    check(forecast["energy_after"] == forecast["energy_before"],"First active owner's ace discount is included")
    b = TacticalBattle.new(42)
    b.full_type_chart = true
    b.enemy().species_id = 111
    b.enemy().types.assign(["ground","rock"])
    forecast = compare(b,BattleCardInstance.new(9100,"move_85",b.active().uid))
    check(forecast["target_before"]["hp"] == forecast["target_after"]["hp"],"Ground immunity produces no HP loss in forecast")
    var feebas := BattlePokemon.new(TacticalContent.member_definition(349,VisualCatalog.new()),99)
    TacticalGrowth.initialize(feebas)
    feebas.beauty = 170
    feebas.evolution_personality = 123
    check(BattleCardPreview.copy_member(feebas).snapshot() == feebas.snapshot(),"Cloned combatants retain optional growth and evolution state")
    # Ordinary capture, energy starvation, missing balls, KO and rare thresholds
    # all use the journey's same capture validation against the detached result.
    for species: int in [16,144,151,150]:
        for balls: int in [0,5]:
            for energy: int in [1,4]:
                var j := TacticalJourney.new(42,"field_kit",[1,4,7],true)
                j.enter_next()
                var rare := species != 16
                j.current()["kind"] = "wild"
                j.current()["rare"] = rare
                if rare: j.rare_hunt = {"target":species,"captured":false}
                var entry := VisualCatalog.new().species(species)
                j.battle.enemies.assign([BattlePokemon.new({"id":species,"name":entry["name"],"type":entry["types"][0],"types":entry["types"],"max_hp":100,"level":5},-1)])
                j.battle.enemy_states.assign([{"intent":0}])
                j.battle.enemy().hp = 9
                j.battle.energy = energy
                j.balls = balls
                var run_before := JourneySnapshot.encode(j)
                j.battle.hand.assign([BattleCardInstance.new(9100,"guard",0)])
                run_before = JourneySnapshot.encode(j)
                forecast = BattleCardPreview.analyze(j.battle,9100,j.capture_reason)
                check(JourneySnapshot.encode(j) == run_before,"Capture queries cannot change the live journey")
                j.battle.play_card(9100)
                check(forecast["capture_reason"] == j.capture_reason(),"Normal/rare capture eligibility matches actual remaining energy and ball costs")
    print("BATTLE_CARD_PREVIEW ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
