extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func identity(cards: Array[BattleCardInstance]) -> Array:
    return cards.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid,c.upgraded,c.injury_owner_uid])
func run() -> void:
    for slot in [0,1,6]:
        var j := RemovalFixture.make()
        var injury := j._allocate_card("injury",0)
        injury.injury_owner_uid = j.party[0].uid
        j.deck.append(injury)
        var target: BattleCardInstance = j.deck[slot]
        var before := JourneySnapshot.encode(j)
        var view := RemovalPreview.describe(j,target.uid)
        check(JourneySnapshot.validate(before),"Boundary fixture is a valid merchant save")
        check(not view.is_empty() and view["reason"].is_empty(),"Available single-instance removal can be previewed")
        check(view["copies_before"] == (3 if slot == 1 else (2 if slot == 6 else 1)),"Copy count distinguishes owner and upgrade state")
        check(view["after"] == j.deck.size()-1 and view["copies_after"] == view["copies_before"]-1,"One selected instance leaves both deck and matching copy counts")
        check(view["card"]["name"] == TacticalContent.definition(target)["name"] and view["card"]["uid"] == target.uid,"Face preserves the exact selected instance and upgrade")
        if target.owner_uid != 0: check(view["card"]["species_id"] == 1 and view["card"]["owner_name"] == j.party[0].display_name,"Technique face keeps the actual owner")
        for card: BattleCardInstance in view["deck_after"]: check(not j.deck.has(card),"Hypothetical deck is detached from all live cards")
        check(JourneySnapshot.encode(j) == before,"Inspection preserves cards, gold, action, IDs, RNG, stock, history and save fields")
        check(j.remove_card(target.uid).is_empty(),"Confirmation uses the public removal rule")
        check(identity(j.deck) == identity(view["deck_after"]) and j.gold == view["gold_after"],"Actual removal exactly matches every previewed UID, owner, upgrade, injury and gold")
        for row: Dictionary in view["coverage"]:
            var actual := EncounterPreparation.analyze(j,row["opponent"])
            check(row["attack"][1] == actual["groups"]["attack"].size() and row["strong"][1] == actual["strong"] and row["conditional"][1] == actual["groups"]["conditional"].size(),"Every opponent's preview matches the actual remaining deck")
        check(j.camp()["removed"] and j.step not in j.rested_steps and j.statistics["counts"]["gold_removal"] == view["price"],"Removal spends gold and merchant allowance while preserving the main camp action")
        check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Confirmed deck remains a valid resumable save")
        before = JourneySnapshot.encode(j)
        check(not j.remove_card(j.deck[0].uid).is_empty() and JourneySnapshot.encode(j) == before,"No second removal or duplicate charge is possible")
    var j := RemovalFixture.make(true)
    var uid := j.deck[0].uid
    var before := JourneySnapshot.encode(j)
    var view := RemovalPreview.describe(j,uid)
    check(view["coverage"].size() == 6 and view["coverage"].all(func(row: Dictionary): return row["attack"] == [1,0]),"Removing a final effective attack is visible for every actual gym opponent")
    check(JourneySnapshot.encode(j) == before,"Last-attack warning cannot remove or replace the real card")
    j.party[0].hp = 0
    j.party[0].knocked_out = true
    view = RemovalPreview.describe(j,uid)
    check(view["coverage"].all(func(row: Dictionary): return row["attack"] == [0,0]),"A fainted owner's attack is excluded on both sides without a false loss warning")
    j = RemovalFixture.make()
    uid = j.deck[0].uid
    j.gold = 0
    view = RemovalPreview.describe(j,uid)
    before = JourneySnapshot.encode(j)
    check(not view["reason"].is_empty() and not j.remove_card(uid).is_empty() and JourneySnapshot.encode(j) == before,"Insufficient gold preserves the exact state and explains unavailability")
    j.gold = 500
    var last := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == 1)[0] as BattleCardInstance
    j.deck.assign(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid != 1 or c.uid == last.uid))
    check(RemovalPreview.describe(j,last.uid)["reason"].contains("마지막 기술"),"The last owned technique remains protected by the actual removal rule")
    j.deck.resize(5)
    check(not RemovalPreview.describe(j,j.deck[0].uid)["reason"].is_empty(),"The minimum five-card deck cannot be pruned")
    check(RemovalPreview.describe(j,-1).is_empty(),"Unknown instance IDs have no preview")
    j.phase = TacticalJourney.MAP
    check(RemovalPreview.describe(j,j.deck[0].uid).is_empty(),"Removal preview is restricted to an actual merchant camp")
    print("REMOVAL_PREVIEW: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
