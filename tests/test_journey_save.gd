extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(text)
func copy(j: TacticalJourney) -> TacticalJourney:
    var bytes := var_to_bytes(JourneySnapshot.encode(j))
    var data: Variant = bytes_to_var(bytes)
    check(JourneySnapshot.validate(data),"Encoded public state validates: "+j.phase+" at "+str(j.step))
    if not JourneySnapshot.validate(data): return null
    var result := JourneySnapshot.restore(data)
    check(JourneySnapshot.encode(result) == JourneySnapshot.encode(j),"Round trip preserves all fields and RNG")
    for p: BattlePokemon in result.party:
        if result.battle.party.has(p): check(p == result.battle.member(p.uid),"Party and battle share restored instances")
    return result
func run() -> void:
    var j := TacticalJourney.new(2026,"seed_relay",[1,4,7],true)
    var r := copy(j)
    if r == null:
        quit(1)
        return
    for pending: String in ["enemy","player"]:
        var forced := TacticalJourney.new(42,"seed_relay",[1,4,7],true)
        forced.battle.active().hp = 1
        if pending == "enemy": forced.battle.active().statuses["burn"] = {"turns":2,"source_uid":-1}
        forced.battle.end_turn()
        check(forced.battle.phase == TacticalBattle.REPLACE and forced.battle._pending == pending,"Fixture reaches forced replacement")
        var resumed := copy(forced)
        if resumed != null:
            forced.battle.switch_to(4)
            resumed.battle.switch_to(4)
            check(JourneySnapshot.encode(forced) == JourneySnapshot.encode(resumed),"Resume forced switch, injury card and deferred "+pending+" action")
    var path := "user://tests/save_%d/journey.json" % Time.get_ticks_usec()
    var store := JourneySave.new(path)
    check(store.save(j).is_empty(),"Initial checkpoint writes")
    var loaded := store.load_journey()
    check(loaded != null and JourneySnapshot.encode(loaded) == JourneySnapshot.encode(j),"File reload matches run")
    if loaded == null:
        print(store.last_error)
        quit(1)
        return
    var states := {}
    for guard in 10000:
        if j.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED]: break
        if not states.has(j.phase) or (j.phase == TacticalJourney.BATTLE and j.battle.turn > 1 and not states.has("mid_turn")):
            r = copy(j)
            states[j.phase] = true
            if j.phase == TacticalJourney.BATTLE and j.battle.turn > 1: states["mid_turn"] = true
            if r == null: break
        match j.phase:
            TacticalJourney.BATTLE:
                if j.battle.phase in [TacticalBattle.WON,TacticalBattle.LOST]:
                    # Saving before settlement must pay once after loading.
                    r = copy(j)
                    if r == null: break
                    j.settle()
                    r.settle()
                    check(JourneySnapshot.encode(j) == JourneySnapshot.encode(r),"Win settlement matches after load")
                else:
                    var action := CampaignPolicy.action(j)
                    r = copy(j) if guard%41 == 0 else null
                    CampaignPolicy.apply(j,action)
                    if r != null:
                        CampaignPolicy.apply(r,action)
                        check(JourneySnapshot.encode(j) == JourneySnapshot.encode(r),"Same action gives same draw/damage after reload")
            TacticalJourney.LEARN: j.resolve_learning(CampaignPolicy.learn(j))
            TacticalJourney.REWARD:
                r = copy(j)
                if r == null: break
                var coins := r.gold
                var xp := r.party[0].experience
                r.settle()
                check(r.gold == coins and r.party[0].experience == xp,"Loaded reward cannot be settled twice")
                j.choose_reward(-1)
            TacticalJourney.MAP: j.enter_next()
            TacticalJourney.REST:
                j.rest()
                if j.camp()["kind"] in ["event","discovery"] and not j.camp()["resolved"] and j.camp_choice_reason(0).is_empty(): j.resolve_camp(0)
                r = copy(j)
                if r == null: break
                check(not r.rest().is_empty(),"Loaded camp cannot rest twice")
                if j.camp()["resolved"]: check(not r.resolve_camp(0).is_empty(),"Loaded event cannot pay twice")
                if j.camp()["kind"] == "merchant":
                    j.buy("ball")
                    r = copy(j)
                    check(r != null and r.shop_stock == j.shop_stock,"Merchant stock is restored")
                    if r != null:
                        r.buy("ball")
                        check(r.shop_stock == r.camp()["stock"],"Shop and camp stock remain aliased")
                j.leave_camp()
    check(j.phase == TacticalJourney.CLEARED and j.wins == 69,"Full campaign survives round trips through all stages")
    print("JOURNEY_SAVE: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
