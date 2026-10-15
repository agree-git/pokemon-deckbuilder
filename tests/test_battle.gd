extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures.append(message)
        push_error(message)

func give(state: BattleState, key: String) -> BattleCardInstance:
    for pile: Array in [state.hand, state.draw_pile, state.discard]:
        for card: BattleCardInstance in pile:
            if card.key == key:
                pile.erase(card)
                state.hand.append(card)
                return card
    push_error("Test fixture card missing: " + key)
    return null

func invariant(state: BattleState) -> void:
    var ids: Dictionary = {}
    var total := 0
    for pile: Array in [state.hand, state.draw_pile, state.discard, state.removed]:
        for card: BattleCardInstance in pile:
            check(not ids.has(card.uid), "Card instance exists in multiple piles")
            ids[card.uid] = true
            total += 1
            if pile != state.removed and card.owner_uid != 0:
                check(state._ally(card.owner_uid).alive(), "Fainted owner's card remained playable")
    check(total == 14 + state.injuries.size(), "Card conservation failed")
    check(state.energy >= 0, "Negative energy")
    for pokemon: BattlePokemon in state.party + [state.enemy]:
        check(pokemon.hp >= 0 and pokemon.hp <= pokemon.max_hp and pokemon.block >= 0, "HP/block bounds failed")

func _run() -> void:
    var state := BattleState.new(2026)
    check(state.hand.size() == 5 and state.draw_pile.size() == 9 and state.energy == 3, "Initial draw and energy")
    check(state.snapshot() == BattleState.new(2026).snapshot(), "Same seed must reproduce complete initial state")
    check(state.snapshot()["piles"] != BattleState.new(2027).snapshot()["piles"], "Different seeds should shuffle differently")
    var ember := give(state, "ember")
    var health := state.enemy.hp
    check(state.play_card(ember.uid).is_empty(), "Ember should play")
    check(state.energy == 2 and state.enemy.hp == health - 6, "Spend 1 and apply fire weakness with floor")
    check(not state.hand.has(ember) and state.discard.has(ember), "Used card goes to discard")
    check(int(state.enemy.statuses["burn"]["turns"]) == 3, "Apply burn")
    var snapshot := state.snapshot()
    check(not state.play_card(ember.uid).is_empty() and state.snapshot() == snapshot, "Reusing discarded card must be atomic rejection")
    var vine := give(state, "vine")
    snapshot = state.snapshot()
    check(not state.play_card(vine.uid).is_empty() and state.snapshot() == snapshot, "Wrong owner rejection must not mutate state/RNG")
    state.energy = 0
    var tackle := give(state, "tackle")
    snapshot = state.snapshot()
    check(not state.play_card(tackle.uid).is_empty() and state.snapshot() == snapshot, "Insufficient energy must be atomic rejection")
    check(state.switch_to(1).is_empty() and state.energy == 0, "First switch is free at zero energy")
    snapshot = state.snapshot()
    check(not state.switch_to(4).is_empty() and state.snapshot() == snapshot, "Additional switch needs energy")
    state.energy = 2
    var hand_ids := state.hand.duplicate()
    check(state.switch_to(4).is_empty() and state.energy == 1 and state.hand == hand_ids, "Paid switch preserves hand and spends 1")
    snapshot = state.snapshot()
    check(not state.switch_to(4).is_empty() and not state.switch_to(999).is_empty() and state.snapshot() == snapshot, "Invalid switches must not spend energy")
    check(BattleContent.multiplier("normal", "grass") == 1 and BattleContent.multiplier("water", "fire") == 1.5, "Neutral and weakness")
    check(BattleContent.multiplier("grass", "fire") == 0.75 and BattleContent.multiplier("grass", "grass") == 0.75, "Resistance and same type")
    state = BattleState.new()
    ember = give(state, "ember")
    var view := state.card_view(ember)
    view["cost"] = 0
    view["damage"] = 999
    health = state.enemy.hp
    state.play_card(ember.uid)
    check(state.energy == 2 and state.enemy.hp == health - 6, "Editing a view must not mutate immutable content")

    state = BattleState.new()
    state.enemy.block = 4
    tackle = give(state, "tackle")
    health = state.enemy.hp
    state.play_card(tackle.uid)
    check(state.enemy.hp == health - 2 and state.enemy.block == 0, "Direct attack consumes shield before HP")
    state = BattleState.new()
    var guard := give(state, "guard")
    state.play_card(guard.uid)
    var before := state.active().hp
    check(int(state.intent()["value"]) == 8, "Intent must reveal exact next damage")
    state.end_turn()
    check(state.party[0].hp == before - 3, "Enemy damage must respect shield")
    check(state.phase == BattleState.PLAYER and state.turn == 2 and state.energy == 3 and not state.switched, "Next player turn reset")
    check(state.party[0].block == 0 and state.hand.size() == 5, "Clear player shields and draw five")
    check(state.intent()["kind"] == "block", "Intent pattern must advance")
    state.end_turn()
    check(state.enemy.block == 7, "Enemy defense persists into the player turn")
    state.end_turn()
    check(state.enemy.block == 0, "Enemy defense expires on its next action")
    state.end_turn()
    check(int(state.intent()["value"]) == 10, "Visible attack includes enemy strength")

    state = BattleState.new()
    state.active().block = 9
    state.switch_to(1)
    state.end_turn()
    check(state.party[0].block == 0 and state.party[0].hp == 45 and state.party[1].hp == 40, "Shield belongs to user; attack hits current ally")
    state = BattleState.new()
    state.discard.append_array(state.draw_pile)
    state.draw_pile.clear()
    var focus := give(state, "focus")
    var size_before := state.hand.size()
    state.play_card(focus.uid)
    check(state.hand.size() == size_before + 1 and state.discard.has(focus), "Draw two and reshuffle, keeping resolving card out of draw")
    invariant(state)
    state = BattleState.new()
    state.hand.clear()
    state.draw_pile.clear()
    state.discard.clear()
    state._draw(5)
    check(state.hand.is_empty(), "An exhausted deck must stop drawing cleanly")

    state = BattleState.new()
    ember = give(state, "ember")
    state.play_card(ember.uid)
    state.enemy.block = 20
    health = state.enemy.hp
    state._tick_statuses(state.enemy)
    check(state.enemy.hp == health - 2 and state.enemy.block == 20, "Burn bypasses shield and type")
    check(int(state.enemy.statuses["burn"]["turns"]) == 2, "Burn duration counts down")
    state.enemy.statuses["burn"]["turns"] = 1
    var another := give(state, "ember")
    state.play_card(another.uid)
    check(int(state.enemy.statuses["burn"]["turns"]) == 3 and state.enemy.statuses.size() == 1, "Reapply refreshes instead of stacking")
    for i in 3:
        state._tick_statuses(state.enemy)
    check(not state.enemy.statuses.has("burn"), "Burn expires after three ticks")
    state = BattleState.new()
    state.switch_to(1)
    state.party[1].hp = 40
    var seed_card := give(state, "seed")
    state.play_card(seed_card.uid)
    state.energy = 3
    state.switch_to(4)
    state._tick_statuses(state.enemy)
    check(state.party[1].hp == 42 and state.party[0].hp == 45, "Seed heals its original user, including bench")
    state.party[1].hp = 48
    state._tick_statuses(state.enemy)
    check(state.party[1].hp == 48, "Healing cannot exceed max HP")
    state.party[1].statuses["burn"] = {"turns": 3, "source_uid": -1}
    state.end_turn()
    check(state.party[1].hp == 48, "Bench burn ticks, then seed heals its living source")
    state._damage(state.party[1], 999, true)
    health = state.enemy.hp
    state.enemy.statuses["seed"] = {"turns": 2, "source_uid": 1}
    state._tick_statuses(state.enemy)
    check(state.party[1].hp == 0 and state.enemy.hp == health - 2, "Seed persists after source KO but cannot revive its owner")
    check(state.party[1].statuses.is_empty(), "Fainting clears statuses on that combatant")
    state = BattleState.new()
    state.switch_to(1)
    var growth := give(state, "growth")
    state.play_card(growth.uid)
    vine = give(state, "vine")
    health = state.enemy.hp
    state.play_card(vine.uid)
    check(state.party[1].strength == 2 and state.enemy.hp == health - 7, "Strength is per Pokemon; damage floors after resistance")

    state = BattleState.new()
    state.party[0].hp = 1
    state.switched = true
    state.energy = 0
    state.end_turn()
    check(state.phase == BattleState.REPLACE and state.hand.is_empty(), "KO must pause before new hand for a replacement")
    check(state.injuries == [4] and state.removed.size() == 4, "KO removes owner cards from every pile and adds one injury")
    check(not state.play_card(1).is_empty() and not state.end_turn().is_empty(), "Forced replacement blocks other actions")
    check(state.switch_to(1).is_empty() and state.phase == BattleState.PLAYER and not state.switched and state.energy == 3, "Forced switch free; new turn's free switch remains")
    invariant(state)
    state = BattleState.new()
    state.party[0].hp = 1
    state.party[0].statuses["burn"] = {"turns": 1, "source_uid": -1}
    before = state.party[1].hp
    state.end_turn()
    check(state.phase == BattleState.REPLACE and state.party[1].hp == before, "Player-end KO pauses before enemy targets a replacement")
    state.switch_to(1)
    check(state.phase == BattleState.PLAYER and state.party[1].hp == before - 8, "Enemy then attacks chosen replacement exactly once")
    state = BattleState.new()
    state.party[0].hp = 1
    state.party[1].hp = 1
    state.end_turn()
    state.switch_to(1)
    state.end_turn()
    state.end_turn()
    check(state.phase == BattleState.LOST, "Full party KO loses")
    snapshot = state.snapshot()
    check(not state.end_turn().is_empty() and not state.switch_to(4).is_empty() and state.snapshot() == snapshot, "Terminal state cannot continue")
    state = BattleState.new()
    state.enemy.hp = 1
    tackle = give(state, "tackle")
    state.play_card(tackle.uid)
    check(state.phase == BattleState.WON and state.enemy.hp == 0 and state.enemy.statuses.is_empty(), "Direct kill wins and clears status")
    state.restart(2026)
    check(state.snapshot() == BattleState.new(2026).snapshot(), "Restart resets all piles, health, RNG, buffs, and outcome")
    state.enemy.hp = 1
    state.enemy.statuses["burn"] = {"turns": 1, "source_uid": 4}
    state.party[0].hp = 1
    state.end_turn()
    check(state.phase == BattleState.WON and state.party[1].alive(), "Enemy status death wins before asking unnecessary replacement")
    state = BattleState.new()
    state.party[0].hp = 1
    state.party[1].hp = 0
    state.party[1].knocked_out = true
    state.enemy.hp = 1
    state.enemy.statuses["burn"] = {"turns": 1, "source_uid": 4}
    state.end_turn()
    check(state.phase == BattleState.LOST and state.enemy.hp == 1, "Last ally death ends battle before enemy-end status")

    var wins := 0
    for battle_seed in range(30):
        state = BattleState.new(battle_seed)
        for step in range(180):
            invariant(state)
            if state.phase in [BattleState.WON, BattleState.LOST]:
                break
            if state.phase == BattleState.REPLACE:
                for pokemon: BattlePokemon in state.party:
                    if pokemon.alive():
                        state.switch_to(pokemon.uid)
                        break
                continue
            var played := false
            for card: BattleCardInstance in state.hand.duplicate():
                if state.card_reason(card.uid).is_empty():
                    state.play_card(card.uid)
                    played = true
                    break
            if not played:
                if not state.switched:
                    var other := state.party[1 - state.active_index]
                    if other.alive():
                        state.switch_to(other.uid)
                        continue
                state.end_turn()
        check(state.phase in [BattleState.WON, BattleState.LOST], "Seed %d did not reach a result" % battle_seed)
        if state.phase == BattleState.WON:
            wins += 1
    check(wins > 0, "A full playable winning route must exist")
    if failures.is_empty():
        print("BATTLE_TESTS_OK: %d checks; 30 seeded battles (%d wins); draw/energy/switch/status/KO/outcomes" % [checks, wins])
        quit(0)
    else:
        print("BATTLE_TESTS_FAILED: %d / %d" % [failures.size(), checks])
        quit(1)
