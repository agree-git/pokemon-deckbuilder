extends SceneTree
## Full public-action runs, including clue/rest tradeoffs and earned rare captures.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func capture_action(j: TacticalJourney) -> String:
    var b := j.battle
    if b.phase == TacticalBattle.REPLACE: return TacticalPolicy.apply(b,TacticalPolicy.action(b))
    if j.capture_reason().is_empty(): return j.capture()
    var target_hp := floori(b.enemy().max_hp*int(RareEncounter.rule(b.enemy().species_id)["hp_percent"])/100.0)
    var snapshot := JourneySnapshot.encode(j)
    var selected := 0
    var score := -1.0
    for card: BattleCardInstance in b.hand:
        if not b.card_reason(card.uid).is_empty(): continue
        var view := b.card_view(card)
        # Avoid damage over time that can defeat the target before the next draw.
        if ["burn","poison","seed","cash"].any(func(key: String): return view.has(key)): continue
        var simulated := JourneySnapshot.restore(snapshot)
        simulated.battle.play_card(card.uid)
        var remaining := simulated.battle.enemy().hp
        if remaining <= 0: continue
        var dealt := b.enemy().hp-remaining
        var value := float(dealt)*2.0
        if remaining <= target_hp: value += 300
        if view.has("draw"): value += int(view["draw"])*4
        if view.has("energy"): value += int(view["energy"])*10
        if view.has("block"): value += mini(int(view.get("preview_block",0)),int(b.intent().get("value",0)))
        if view.has("heal"): value += mini(int(view.get("preview_heal",0)),b.active().max_hp-b.active().hp)
        if value > score and value > 0:
            score = value
            selected = card.uid
    return b.play_card(selected) if selected > 0 else b.end_turn()
func run() -> void:
    for target_id: int in [144,151,150]:
        var chosen_seed := 0
        for seed_value in 400:
            if RareEncounter.target(seed_value) == target_id:
                chosen_seed = seed_value
                break
        var j := TacticalJourney.new(chosen_seed,"field_kit",[1,4,7],true)
        var guard := 0
        var captures := 0
        while j.phase not in [TacticalJourney.CLEARED,TacticalJourney.FAILED] and guard < 20000:
            guard += 1
            var reason := ""
            match j.phase:
                TacticalJourney.BATTLE:
                    if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]: reason = j.settle()
                    elif j.current().get("rare",false):
                        var caught := j.captured_ids.size()
                        reason = capture_action(j)
                        if j.captured_ids.size() > caught: captures += 1
                    else: reason = CampaignPolicy.apply(j,CampaignPolicy.action(j))
                TacticalJourney.LEARN: reason = j.resolve_learning(CampaignPolicy.learn(j))
                TacticalJourney.CAPTURE: reason = j.resolve_capture(-1)
                TacticalJourney.REWARD: reason = j.choose_reward(CampaignPolicy.reward(j))
                TacticalJourney.MAP: reason = j.enter_next()
                TacticalJourney.REST:
                    if j.investigate_reason().is_empty() and j.party.all(func(p: BattlePokemon): return p.hp >= p.max_hp*0.6):
                        check(j.investigate().is_empty(),"Earn a clue by trading a healthy camp's rest action")
                    CampaignPolicy.camp(j)
                    var cost: int = RareEncounter.rule(target_id)["balls"]
                    while j.balls < cost and j.buy_reason("ball").is_empty(): j.buy("ball")
                    if j.rare_challenge_reason().is_empty():
                        check(j.challenge_rare().is_empty(),"Earned badges, clues and purchased balls reserve a rare encounter")
                        var encoded := JourneySnapshot.encode(j)
                        check(JourneySnapshot.validate(encoded),"Earned campaign reservation is a valid checkpoint")
                        j = JourneySnapshot.restore(encoded)
                    if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty(): j.resolve_camp(0)
                    reason = j.leave_camp()
            if not reason.is_empty():
                check(false,"Public campaign action failed: "+reason)
                break
        print("RARE_CAMPAIGN target=",target_id," seed=",chosen_seed," phase=",j.phase," wins=",j.wins," captures=",captures," actions=",guard)
        check(captures == 1 and target_id in j.captured_ids,"Capture a full-health rare through real card actions without editing HP, XP, balls or energy")
        check(j.phase == TacticalJourney.CLEARED and j.wins == 69 and j.statistics["battles"].size() == 69,"Complete all 69 battles after the one rare capture and its rest/resource tradeoffs")
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Complete rare campaign retains a valid ending snapshot")
    print("RARE_CAMPAIGN: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
