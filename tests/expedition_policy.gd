extends RefCounted
## Deterministic play policy for whole-run tests; uses only legal public actions.
static func decision(run: RunState) -> Dictionary:
    var battle := run.battle
    if battle.phase == BattleState.REPLACE:
        var best := -1
        var hp := -1
        for pokemon: BattlePokemon in battle.party:
            if battle.switch_reason(pokemon.uid).is_empty() and pokemon.hp > hp:
                best = pokemon.uid
                hp = pokemon.hp
        return {"kind":"switch","uid":best}
    if not battle.capture_reason().is_empty() or run.balls <= 0:
        pass
    elif run.capture_count < 2 and battle.enemy.species_id in [43,7]:
        return {"kind":"capture"}
    var best_score := -1.0
    var best_uid := -1
    for card: BattleCardInstance in battle.hand:
        if battle.card_reason(card.uid).is_empty():
            var view := battle.card_view(card)
            var score := float(view.get("preview_damage",0))
            if score >= battle.enemy.hp:
                score += 1000
            if view.has("burn") and not battle.enemy.statuses.has("burn"):
                score += 8
            if view.has("seed") and not battle.enemy.statuses.has("seed"):
                score += 10
            if view.has("strength"):
                score += 9 if battle.turn < 4 else 2
            score += int(view.get("draw",0))*4
            if view.has("block") and battle.intent()["kind"] == "attack":
                score += minf(int(view["block"]),maxi(0,int(battle.intent()["value"])-battle.active().block))*0.85
            if score > best_score:
                best_score = score
                best_uid = card.uid
    if best_uid != -1:
        return {"kind":"card","uid":best_uid}
    if not battle.switched:
        for pokemon: BattlePokemon in battle.party:
            if battle.switch_reason(pokemon.uid).is_empty():
                for card: BattleCardInstance in battle.hand:
                    if card.owner_uid == pokemon.uid and int(BattleContent.card_definition(card)["cost"]) <= battle.energy:
                        return {"kind":"switch","uid":pokemon.uid}
    return {"kind":"end"}

static func apply(run: RunState, action: Dictionary) -> String:
    match action["kind"]:
        "card": return run.battle.play_card(int(action["uid"]))
        "switch": return run.battle.switch_to(int(action["uid"]))
        "capture": return run.battle.capture()
        "end": return run.battle.end_turn()
    return "unknown action"

static func resolve_reward(run: RunState) -> int:
    var best := -1
    var score := -1
    for i in run.reward_options.size():
        var view := run.reward_view(i)
        var value := int(view.get("damage",0)) + (6 if view.has("burn") else 0)
        if value > score:
            score = value
            best = i
    return best

static func choose_route(run: RunState) -> int:
    return 1 if run.step == 6 else 0

static func rest_action(run: RunState) -> Dictionary:
    var total := 0.0
    var maximum := 0.0
    for pokemon: BattlePokemon in run.party:
        total += pokemon.hp
        maximum += pokemon.max_hp
    if run.step == 2 and total/maximum > 0.9 and not run.rest_options().is_empty():
        return {"kind":"upgrade","uid":run.rest_options()[0].uid}
    if run.step == 5 and total/maximum > 0.45 and run.evolve_reason(4).is_empty():
        return {"kind":"evolve","uid":4}
    return {"kind":"heal","uid":0}

static func complete(run: RunState, route_pattern: int = 4) -> Array[String]:
    var log: Array[String] = []
    for guard in 2000:
        if run.phase in [RunState.CLEARED,RunState.FAILED]:
            break
        if run.phase == RunState.MAP:
            var slot: int = {1:0,4:1,6:2}.get(run.step,0)
            run.choose_node((route_pattern >> slot) & 1 if run.options().size() > 1 else 0)
        elif run.phase == RunState.REST:
            var action := rest_action(run)
            run.rest(action["kind"],int(action["uid"]))
        elif run.battle.phase in [BattleState.WON,BattleState.LOST,BattleState.CAPTURED]:
            run.settle()
            log.append("%d:%s:%s turns=%d HP=%s" % [run.step,run.current_node["name"],run.battle.phase,run.battle.turn,run.party.map(func(p: BattlePokemon): return p.hp)])
            if run.pending_capture != null:
                run.resolve_capture(1 if run.member(1) != null else run.pending_capture.uid)
            if run.reward_pending:
                run.choose_reward(resolve_reward(run))
            if run.phase == RunState.BATTLE:
                run.next_battle()
        else:
            var reason := apply(run,decision(run))
            if not reason.is_empty():
                log.append("ERROR " + reason)
                break
    return log
