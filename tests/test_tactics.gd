extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func card(b: TacticalBattle,key: String) -> void:
    for instance: BattleCardInstance in b.hand:
        if instance.key == key:
            check(b.play_card(instance.uid).is_empty(),"Legal trainer card: "+key)
            return
    # Isolated rule fixtures use a known hand; full encounters below use the real deck.
    var instance := b._new_card(key)
    b.hand.append(instance)
    check(b.play_card(instance.uid).is_empty(),"Fixture card: "+key)
func skill(b: TacticalBattle,key: String) -> void:
    check(b.use_skill(key).is_empty(),"Legal skill: "+key)
func switch(b: TacticalBattle,uid: int) -> void:
    check(b.switch_to(uid).is_empty(),"Legal switch")
func run() -> void:
    var b := TacticalBattle.new()
    check(b.snapshot() == TacticalBattle.new().snapshot(),"Seed reproduces complete opening")
    check(b.hand.size() == 5 and b.draw_pile.size() == 5,"Draw five from shared trainer deck")
    var before := b.snapshot()
    check(not b.use_skill("flame").is_empty() and before == b.snapshot(),"Wrong Pokemon skill rejects atomically")
    check(not b.play_card(-1).is_empty() and before == b.snapshot(),"Stale card rejects atomically")
    check(not b.switch_to(999).is_empty() and before == b.snapshot(),"Missing member rejects atomically")
    skill(b,"seed")
    check(b.opening()["points"] == 1 and b.enemy().statuses["seed"]["turns"] == 3,"Status creates one opening")
    before = b.snapshot()
    check(not b.use_skill("seed").is_empty() and b.snapshot() == before,"Each fixed skill once per Pokemon per turn")
    card(b,"analysis")
    b.end_turn()
    check(b.active().hp == 36 and b.enemy().hp == 38,"Telegraphed charge and seed heal resolve")
    check(b.enemy().statuses["seed"]["turns"] == 2 and b.energy == 3,"Status consumes tick and new turn refills energy")
    switch(b,4)
    skill(b,"ember")
    check(b.opening()["broken"] and b.opening()["burst"] and b.opening()["cancel"],"Weakness + analysis completes break")
    check(b.enemy().hp == 32 and b.energy == 3,"Trigger hit does not receive its own double; break refunds one")
    var hand_count := b.hand.size()
    skill(b,"flame")
    check(b.enemy_index == 1 and b.turn == 2 and b.phase == TacticalBattle.PLAYER,"Broken KO advances enemy within same player turn")
    check(b.energy == 2 and b.hand.size() == hand_count+1 and b.refunds == 2,"Finish refund preserves resources and draws one")
    check(b.enemy().hp == 48 and b.enemy().statuses["seed"]["turns"] == 2,"KO transfers remaining seed, not burn")
    check(b.opening()["points"] == 1 and not b.enemy().statuses.has("burn"),"Transferred status opens new enemy without leaking killing move's status")
    switch(b,7)
    check(b.energy == 1,"Second voluntary switch costs one")
    skill(b,"water_gun")
    check(b.enemy().hp == 36,"Same-turn attack hits newly entered enemy")
    before = b.snapshot()
    check(not b.use_skill("tackle").is_empty() and b.snapshot() == before,"Energy failure leaves every field unchanged")
    b.end_turn()
    check(b.enemy().hp == 34 and b.turn == 3,"Second enemy takes its own action then seed tick")
    card(b,"analysis")
    skill(b,"water_gun")
    check(b.opening()["broken"] and b.enemy().hp == 22,"Second enemy has independent break meter")
    skill(b,"tackle")
    check(b.enemy().hp == 10 and not b.opening()["burst"],"Double consumed once by next damage skill")
    var hp := b.active().hp
    b.end_turn()
    check(b.active().hp == hp and b.events.any(func(e: Dictionary): return e["kind"] == "cancel"),"Break cancels upcoming enemy action")
    skill(b,"water_gun")
    check(b.phase == TacticalBattle.WON and b.enemies.all(func(p: BattlePokemon): return p.hp == 0),"Victory only after final enemy")
    before = b.snapshot()
    check(not b.end_turn().is_empty() and before == b.snapshot(),"Terminal state immutable to stale actions")
    b._outcome()
    check(before == b.snapshot(),"Outcome settlement idempotent")
    # Same source cannot fill a meter repeatedly; break/finish share a strict cap.
    b.restart()
    b._opening("status","fixture")
    b._opening("status","fixture")
    check(b.opening()["points"] == 1,"One opening per source per enemy")
    b._opening("weakness","fixture")
    b._opening("analysis","fixture")
    b._opening("counter","fixture")
    check(b.energy == 4 and b.opening()["points"] == 3,"Broken enemy cannot break repeatedly")
    b._refund("finish")
    before = b.snapshot()
    b._refund("finish")
    check(b.snapshot() == before and b.refunds == 2,"Shared refund cap prevents energy/draw farming")
    # Trait costs and switch bonuses.
    b.restart(2026,"break_focus")
    var count := b.hand.size()
    b._opening("status","")
    b._opening("weakness","")
    b._opening("analysis","")
    check(b.free_card and b.hand.size() == count+1,"Break trait grants draw and one paid-card discount")
    card(b,"focus")
    check(b.free_card and b.exhausted.size() == 1,"Free draw does not consume discount and is exhausted")
    var energy := b.energy
    card(b,"guard")
    check(not b.free_card and b.energy == energy,"Next paid trainer card consumes discount")
    b.restart(2026,"switch_power")
    switch(b,4)
    check(b.skill_view("ember")["preview_damage"] == 10,"Switch trait affects preview with type multiplier")
    skill(b,"fire_guard")
    check(b.switch_bonus.has(4),"Support skill keeps next-attack bonus")
    skill(b,"ember")
    check(not b.switch_bonus.has(4) and b.skill_view("flame")["preview_damage"] == 18,"Only next damage skill consumes switch trait")
    b.end_turn()
    check(b.switch_bonus.is_empty(),"Unused switch bonuses expire at new turn")
    # Lethal status ticks transfer only ticks that actually remain.
    for remaining in [1,2]:
        b.restart()
        b.enemy().hp = 2
        b.enemy().statuses["seed"] = {"turns":remaining,"source_uid":1}
        b._tick(b.enemy())
        b._outcome()
        check(b.enemy_index == 1,"DOT KO advances enemy")
        check(b.enemy().statuses.has("seed") == (remaining == 2),"Final seed tick does not transfer an expired status")
        if remaining == 2: check(b.enemy().statuses["seed"]["turns"] == 1,"Lethal tick is consumed before relay")
        check(b.refunds == 0,"DOT KO cannot claim broken direct-hit finisher")
    b.restart()
    b.party[1].hp = 1
    b.end_turn()
    check(b.phase == TacticalBattle.REPLACE and b.active().hp == 0,"Active KO pauses for forced replacement")
    var injuries := b.discard.filter(func(c: BattleCardInstance): return c.key == "injury").size()
    switch(b,7)
    check(b.phase == TacticalBattle.PLAYER and not b.switched and b.energy == 3,"Forced replacement does not use voluntary switch or resources")
    check(injuries == 1,"KO creates one shared trainer-deck injury")
    b.restart()
    b.active().hp = 1
    for p: BattlePokemon in b.party:
        if p != b.active(): b._damage(p,999,true)
    b.enemy().hp = 1
    b.enemy().statuses["burn"] = {"turns":3,"source_uid":4}
    b.end_turn()
    check(b.phase == TacticalBattle.LOST and b.enemy_index == 0,"Last ally KO loses before later enemy DOT can grant victory")
    # Deck conservation through reshuffles, exhaustion, and seeded complete encounters.
    for trial_relic: String in TacticalContent.RELICS:
        for trial_seed in range(30):
            b.restart(trial_seed,trial_relic)
            for guard in 120:
                if b.phase in [TacticalBattle.WON,TacticalBattle.LOST]: break
                var action := TacticalPolicy.action(b)
                TacticalPolicy.apply(b,action)
                check(b.energy >= 0 and b.refunds <= 2,"Encounter never violates energy/refund bounds")
                var ids: Dictionary = {}
                for pile: Array in [b.hand,b.draw_pile,b.discard,b.exhausted]:
                    for instance: BattleCardInstance in pile: ids[instance.uid] = true
                var total := b.hand.size()+b.draw_pile.size()+b.discard.size()+b.exhausted.size()
                check(ids.size() == total and total == b._next_uid-1,"Cards conserved uniquely across every action")
            check(b.phase == TacticalBattle.WON,"Seed %d completes with tactical policy" % trial_seed)
    var six: Array = []
    for i in 6: six.append(TacticalContent.ENEMIES[i%2].duplicate(true))
    b.restart(42,"seed_relay",six)
    for i in 6:
        b._damage(b.enemy(),999,true)
        b._outcome()
        check(b.phase == (TacticalBattle.WON if i == 5 else TacticalBattle.PLAYER),"Enemy roster supports six sequential members")
    print("TACTICS: ",checks," checks, ",failures," failures; 90 complete battles across 30 seeds and 3 traits")
    quit(0 if failures == 0 else 1)
