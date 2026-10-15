extends SceneTree
const Policy = preload("res://tests/expedition_policy.gd")
const Player = preload("res://tests/expedition_ui_player.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func win(run: RunState) -> void:
    run.battle.enemy.hp = 0
    run.battle._check_outcome()
    run.settle()
func advance(run: RunState) -> void:
    if run.reward_pending:
        run.choose_reward(-1)
    check(run.next_battle().is_empty(),"Completed battle opens map")
func reach_rest(run: RunState) -> void:
    win(run)
    advance(run)
    run.choose_node(0)
    win(run)
    advance(run)
    run.choose_node(0)
func fingerprint(run: RunState) -> String:
    var cards: Array = []
    for card: BattleCardInstance in run.deck:
        cards.append([card.uid,card.key,card.owner_uid,card.upgraded,card.injury_owner_uid])
    return str([run.phase,run.step,run.route_history,run.party.map(func(p: BattlePokemon): return p.snapshot()),cards,run.battle.snapshot()])
func run_tests() -> void:
    var run := RunState.new()
    var before := fingerprint(run)
    check(not run.choose_node(0).is_empty() and fingerprint(run) == before,"Cannot use map during battle")
    check(not run.rest("heal").is_empty() and fingerprint(run) == before,"Cannot heal outside camp")
    run.battle.party[1].hp = 0
    win(run)
    check(run.party[0].experience == 1 and run.party[1].experience == 0,"Only survivors gain XP")
    run.settle()
    check(run.party[0].experience == 1,"Settlement grants XP only once")
    run.restart()
    run.battle.enemy.hp = 16
    run.battle.capture()
    run.settle()
    check(run.party[0].experience == 1 and run.party[2].experience == 1,"Capture grants XP to survivors and the joining Pokemon")
    run.restart()
    reach_rest(run)
    check(run.phase == RunState.REST and run.step == 2,"First camp follows two battles")
    before = fingerprint(run)
    check(not run.choose_node(0).is_empty() and fingerprint(run) == before,"Cannot bypass camp using stale map action")
    check(not run.rest("evolve",4).is_empty() and fingerprint(run) == before,"Insufficient XP prevents evolution atomically")
    check(not run.rest("upgrade",-99).is_empty() and fingerprint(run) == before,"Invalid upgrade does not consume camp")
    run.party[0].hp = 0
    run.party[0].knocked_out = true
    run.party[1].hp = 47
    var injury := BattleCardInstance.new(500,"injury",0)
    injury.injury_owner_uid = 4
    run.deck.append(injury)
    var old_cards := run.deck.size()
    check(run.rest("heal").is_empty(),"Camp recovery succeeds")
    check(run.party[0].hp == 14 and not run.party[0].knocked_out and run.party[1].hp == 48,"Recovery revives at ceil(30%) and clamps to max HP")
    check(run.deck.size() == old_cards-1 and injury not in run.deck,"Recovery removes only linked injuries")
    before = fingerprint(run)
    check(not run.rest("heal").is_empty() and fingerprint(run) == before,"Cannot use camp twice")
    run.choose_node(0)
    run.battle._damage(run.battle.party[0],999,true)
    check(run.battle.injuries.has(4),"Revived Pokemon can generate a new injury if knocked out again")
    # Evolution preserves IDs, card count, upgrades and HP ratio; next battle uses trait.
    for species in [1,4,7]:
        run.restart()
        reach_rest(run)
        var pokemon := run.member(1 if species == 1 else 4)
        if species == 7:
            pokemon.species_id = 7
            pokemon.display_name = "꼬부기"
            pokemon.type = "water"
            for card: BattleCardInstance in run.deck:
                if card.owner_uid == pokemon.uid and card.key == "ember":
                    card.key = "water_gun"
        pokemon.experience = 4
        pokemon.hp = pokemon.max_hp / 2
        var ratio := float(pokemon.hp)/pokemon.max_hp
        var uid := pokemon.uid
        var evolution: Dictionary = ExpeditionContent.EVOLUTIONS[species]
        var count := run.deck.size()
        var old_uid := -1
        for card: BattleCardInstance in run.deck:
            if card.owner_uid == uid and card.key == evolution["from_card"]:
                card.upgraded = true
                old_uid = card.uid
                break
        check(run.rest("evolve",uid).is_empty(),"Evolution allowed with four XP")
        check(pokemon.uid == uid and pokemon.species_id == evolution["id"] and pokemon.hp == int(ceil(ratio*pokemon.max_hp)),"Evolution preserves instance and HP ratio")
        check(run.deck.size() == count,"Evolution changes a card without adding one")
        for card: BattleCardInstance in run.deck:
            if card.uid == old_uid:
                check(card.key == evolution["to_card"] and card.upgraded,"Evolution retains upgraded card's instance and upgrade")
        run.choose_node(0)
        if species == 1:
            check(pokemon.block == 4,"Ivysaur trait grants opening block")
        elif species == 4:
            check(pokemon.strength == 1,"Charmeleon trait grants strength")
        else:
            check(run.battle.energy == 4,"Wartortle trait grants first-turn energy")
            run.battle.end_turn()
            check(run.battle.energy == 3,"Extra energy does not repeat on later turns")
    run.restart()
    reach_rest(run)
    var chosen := run.rest_options()[0]
    var key := chosen.key
    var definition: Dictionary = BattleContent.CARDS[key].duplicate(true)
    var deck_size := run.deck.size()
    check(run.rest("upgrade",chosen.uid).is_empty() and chosen.upgraded and run.deck.size() == deck_size,"Upgrade affects one existing card")
    check(BattleContent.CARDS[key] == definition,"Upgrade does not mutate content definitions")
    run.choose_node(0)
    check(run.battle.card_view(chosen)["name"].ends_with(" +"),"Battle view uses upgraded definition")
    # All authored routes terminate, with no forced outcomes or HP/resource mutations.
    var cleared := 0
    for seed_value in range(2026,2056):
        var expedition := RunState.new(seed_value)
        var log := Policy.complete(expedition)
        check(expedition.phase in [RunState.CLEARED,RunState.FAILED],"Seed %d reaches an ending: %s" % [seed_value,log])
        if expedition.phase == RunState.CLEARED:
            cleared += 1
            check(expedition.route_history.size() == 9 and expedition.wins+expedition.capture_count == 6,"Clear contains all nine stops and six battle resolutions")
            check(not expedition.reward_pending and not expedition.battle.wild,"Final boss gives ending and cannot be captured")
            before = fingerprint(expedition)
            check(not expedition.next_battle().is_empty() and not expedition.choose_node(0).is_empty() and fingerprint(expedition) == before,"Cleared expedition cannot continue or reroll")
    check(cleared >= 20,"Basic legal strategy must complete a substantial share of seeds")
    var branch_clears := 0
    for pattern in range(8):
        for seed_value in range(2026,2029):
            var branch := RunState.new(seed_value)
            var log := Policy.complete(branch,pattern)
            check(branch.phase in [RunState.CLEARED,RunState.FAILED],"Branch %d, seed %d terminates: %s" % [pattern,seed_value,log])
            branch_clears += 1 if branch.phase == RunState.CLEARED else 0
    check(branch_clears >= 12,"Alternate paths remain playable with a basic strategy")
    # A zero-cost upgrade must change both validation and actual spending.
    run.restart()
    reach_rest(run)
    var seed_card: BattleCardInstance
    for card: BattleCardInstance in run.deck:
        if card.key == "seed":
            seed_card = card
    run.rest("upgrade",seed_card.uid)
    run.choose_node(0)
    run.battle.switch_to(1)
    for pile: Array in [run.battle.hand,run.battle.draw_pile,run.battle.discard]:
        pile.erase(seed_card)
    run.battle.hand.append(seed_card)
    run.battle.energy = 0
    check(run.battle.play_card(seed_card.uid).is_empty() and run.battle.energy == 0 and run.battle.enemy.statuses.has("seed"),"Upgraded seed validates and resolves for zero energy")
    # Typed enemy intent changes when a resistant ally switches into the attack.
    run.restart()
    var opponent: Dictionary = ExpeditionContent.ROUTE[8][0]["enemy"]
    run.battle.start_with(run.party,run.deck,opponent,2026,2)
    check(run.battle.intent()["value"] == 7,"Boss grass attack preview includes fire resistance")
    run.battle.switch_to(1)
    check(run.battle.intent()["value"] == 7,"Boss preview remains correct for a grass ally")
    run.battle.party.append(BattlePokemon.new(BattleContent.ENCOUNTERS[1],100))
    run.battle.switch_to(100)
    check(run.battle.intent()["value"] == 15,"Switching to a water ally updates grass weakness preview")
    var hp_before := run.battle.active().hp
    run.battle.end_turn()
    check(run.battle.active().hp == hp_before-15,"Enemy damage equals the visible intent")
    # A Squirtle captured at stop two can evolve at the last camp in this short run.
    run.restart()
    win(run)
    advance(run)
    run.choose_node(0)
    run.battle.enemy.hp = 13
    run.battle.capture()
    run.settle()
    var water_uid := run.party[2].uid
    advance(run)
    run.choose_node(0)
    run.rest("heal")
    run.choose_node(0)
    win(run)
    advance(run)
    run.choose_node(0)
    win(run)
    advance(run)
    run.choose_node(0)
    run.rest("heal")
    run.choose_node(1)
    win(run)
    advance(run)
    run.choose_node(0)
    check(run.step == 7 and run.member(water_uid).experience == 4 and run.evolve_reason(water_uid).is_empty(),"Captured Squirtle reaches evolution threshold before the boss")
    check(run.rest("evolve",water_uid).is_empty() and run.member(water_uid).species_id == 8,"Caught starter evolves within the nine-stop expedition")
    # Full UI run: every gameplay request is a pointer click through controls.
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    var session_run: RunState = root.get_node("BattleSession").get("run")
    session_run.restart(2026)
    var ui: BattleUI = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    var actions := 0
    var phases: Dictionary = {}
    var reentered: Dictionary = {}
    for guard in 800:
        phases[session_run.phase] = true
        if session_run.phase in [RunState.MAP,RunState.REST] and not reentered.has(session_run.phase):
            var saved := fingerprint(session_run)
            reentered[session_run.phase] = true
            ui.queue_free()
            await process_frame
            ui = load("res://scenes/battle_preview.tscn").instantiate()
            root.add_child(ui)
            await process_frame
            check(fingerprint(session_run) == saved and ui.expedition.visible,"Map/camp state survives scene reentry without repeating rewards or rest")
        if session_run.phase in [RunState.CLEARED,RunState.FAILED]:
            break
        var reason: String = await Player.step(ui,self)
        check(reason.is_empty(),"UI action succeeds: " + reason)
        if not reason.is_empty():
            break
        actions += 1
    check(session_run.phase == RunState.CLEARED and ui.expedition.visible,"Whole pointer-driven UI run reaches visible completion")
    check(phases.has(RunState.MAP) and phases.has(RunState.REST),"Whole run traverses route map and camps")
    check(session_run.member(4).species_id == 5,"Whole run includes a real evolution")
    check(session_run.deck.any(func(card: BattleCardInstance): return card.upgraded),"Whole run includes a real card upgrade")
    var final_state := fingerprint(session_run)
    ui.queue_free()
    await process_frame
    ui = load("res://scenes/battle_preview.tscn").instantiate()
    root.add_child(ui)
    await process_frame
    check(session_run.phase == RunState.CLEARED and fingerprint(session_run) == final_state and ui.expedition.visible,"Final result survives scene reentry")
    var old_seed := session_run.seed_value
    var fresh: Button
    for child: Node in ui.expedition.get_children():
        if child is Button and child.text == "새 시드로 출발":
            fresh = child
    Player.click(self,fresh)
    await process_frame
    check(session_run.seed_value != old_seed and session_run.phase == RunState.BATTLE,"Visible new-seed button starts a different expedition")
    var new_seed := session_run.seed_value
    ui.restart_battle()
    check(session_run.seed_value == new_seed,"Normal restart preserves the selected seed")
    check(session_run.phase == RunState.BATTLE and session_run.step == 0 and session_run.route_history.is_empty() and session_run.party.size() == 2,"Restart resets completed expedition")
    for pokemon: BattlePokemon in session_run.party:
        pokemon.hp = 1
    ui.battle.end_turn()
    ui._refresh()
    if ui.battle.phase == BattleState.REPLACE:
        ui.set_active(1)
        if ui.animating:
            ui.stage.canvas.effect._process(MoveEffect.DURATION)
        for i in 4:
            if ui.battle.phase != BattleState.PLAYER:
                break
            ui._end_turn()
            if ui.animating:
                ui.stage.canvas.effect._process(MoveEffect.DURATION)
    check(session_run.phase == RunState.FAILED and ui.expedition.visible,"Party wipe reaches visible failed expedition")
    ui.restart_battle()
    ui.free()
    print("EXPEDITION_TESTS: %d checks, %d failures; %d/30 cleared; alternate paths %d/24; pointer run %d actions" % [checks,failures,cleared,branch_clears,actions])
    quit(0 if failures == 0 else 1)
