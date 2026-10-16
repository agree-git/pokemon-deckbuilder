extends SceneTree
const Policy = preload("res://tools/campaign_recruitment_policy.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(starters: Array[int] = [1,4,7]) -> TacticalJourney:
    var j := TacticalJourney.new(42,"field_kit",starters,true)
    j.battle.enemy().hp = 1 # Explicit capture-boundary fixture.
    check(j.capture().is_empty() and j.settle().is_empty(),"Capture and settlement use the public rules")
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    return j
func identity(cards: Array[BattleCardInstance]) -> Array:
    return cards.map(func(c: BattleCardInstance): return [c.uid,c.key,c.owner_uid,c.upgraded,c.injury_owner_uid])
func run() -> void:
    var j := fixture()
    var outgoing := j.party[0]
    outgoing.held_item = "power_band"
    for c: BattleCardInstance in j.deck:
        if c.owner_uid == outgoing.uid: c.upgraded = true
    var injury := BattleCardInstance.new(j._next_card_uid,"injury",0)
    j._next_card_uid += 1
    injury.injury_owner_uid = outgoing.uid
    j.deck.append(injury)
    var before := JourneySnapshot.encode(j)
    var view := RecruitmentPreview.describe(j,0)
    check(not view.is_empty() and view["incoming"] == j.pending_captures[0] and view["outgoing"] == outgoing,"Preview identifies the actual pending recruit and replacement")
    var removals := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == outgoing.uid or c.injury_owner_uid == outgoing.uid)
    check(view["removed"].size() == removals.size() and view["removed"].any(func(v: Dictionary): return v["key"] == "injury"),"All departing techniques and linked injury are shown")
    check(view["removed"].any(func(v: Dictionary): return v["name"].ends_with(" +")),"Removed cards preserve actual upgrades in their faces")
    check(view["returned_item"] == "power_band","Preview names the held item returned to the bag")
    for i in 4: RecruitmentPreview.describe(j,i)
    check(JourneySnapshot.encode(j) == before,"Preview, invalid selection and rebrowsing cannot change UIDs, deck, XP, items, capture, RNG or currency")
    var shared := identity(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == 0 and c.injury_owner_uid == 0))
    var caught := j.pending_captures[0]
    check(j.resolve_capture(0).is_empty(),"Confirm the previewed replacement")
    var added := j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == caught.uid)
    check(j.deck.size() == view["after"] and added.map(func(c: BattleCardInstance): return c.key) == view["added"].map(func(v: Dictionary): return v["key"]),"The preview exactly matches the actual added deck and final count")
    check(not j.deck.any(func(c: BattleCardInstance): return c.owner_uid == outgoing.uid or c.injury_owner_uid == outgoing.uid) and "power_band" in j.held_inventory,"Replacement removes only outgoing cards and returns the actual equipment")
    check(identity(j.deck.filter(func(c: BattleCardInstance): return c.owner_uid == 0 and c.injury_owner_uid == 0)) == shared,"Shared cards and unrelated identities are preserved")
    check(added.all(func(c: BattleCardInstance): return not c.upgraded) and j._next_card_uid == int(before["run"]["_next_card_uid"])+added.size(),"Only confirmation allocates unique unupgraded recruit card IDs")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Confirmed replacement remains a valid save")
    j = fixture([1])
    view = RecruitmentPreview.describe(j,0)
    before = JourneySnapshot.encode(j)
    check(view["outgoing"] == null and view["removed"].is_empty() and view["returned_item"] == "","A vacant slot removes no ally, card or item")
    j.resolve_capture(0)
    check(j.party.size() == 2 and j.deck.size() == view["after"],"Vacant-slot confirmation matches its preview")
    j = fixture()
    view = RecruitmentPreview.describe(j,0)
    var cards := identity(j.deck)
    var balls := j.balls
    var id := j.pending_captures[0].species_id
    j.resolve_capture(-1)
    check(identity(j.deck) == cards and j.balls == balls and id in j.captured_ids,"Release preserves the deck and capture unlock without refunding a ball")
    check(RecruitmentPreview.describe(j,0).is_empty(),"The completed decision cannot show stale recruitment")
    # All 386 actual initial learnsets produce their real recruitment cards.
    var catalog := VisualCatalog.new()
    for species in range(1,387):
        var p := BattlePokemon.new(TacticalContent.member_definition(species,catalog),1000)
        TacticalGrowth.initialize(p)
        var known := p.learned_skills.duplicate()
        var keys := RecruitmentPreview.keys_for(p)
        check(keys.size() >= 2 and p.learned_skills == known,"Every species has safe recruit cards without learning moves: %d" % species)
        if known.size() == 1: check(keys == [known[0],known[0]],"Single known technique keeps its two actual copies")
    # The comparison policy may reason about enemies without initializing live opponents.
    j = TacticalJourney.new(2026,"field_kit",[1],true)
    var policy := Policy.new()
    before = JourneySnapshot.encode(j)
    policy.wants(j)
    policy.action(j)
    check(JourneySnapshot.encode(j) == before,"Capture planning cannot change live stats, learned skills, resources or RNG")
    j.battle.enemy().hp = 1
    var energy := j.battle.energy
    balls = j.balls
    check(policy.action(j) == ["capture"] and policy.apply(j,["capture"]).is_empty(),"Capture policy uses the public capture action at the real threshold")
    check(j.balls == balls-1 and j.battle.energy == energy-1 and policy.captures.size() == 1,"Actual capture spends one ball and energy and records one catch")
    j.settle()
    while j.phase == TacticalJourney.LEARN: j.resolve_learning(-1)
    check(policy.resolve(j).is_empty() and j.party.size() == 2 and policy.decisions[0]["joined"],"The policy joins a real recruit into a vacant slot")
    # Decision policy boundaries: no duplicate families or forced replacements.
    var same := BattlePokemon.new(TacticalContent.member_definition(2,catalog),5000)
    TacticalGrowth.initialize(same)
    check(policy.choice(j,same) == -1,"Recruitment avoids duplicate evolution families even with a vacant slot")
    var strong := BattlePokemon.new(TacticalContent.member_definition(143,catalog),5001)
    strong.level = 50
    TacticalGrowth.initialize(strong)
    var full := TacticalJourney.new(42,"field_kit",[1,4,7],true)
    check(policy.choice(full,strong) >= 0,"A sufficiently stronger different family can replace the current weakest ally")
    var weak := BattlePokemon.new(TacticalContent.member_definition(129,catalog),5002)
    TacticalGrowth.initialize(weak)
    check(policy.choice(full,weak) == -1,"A weak candidate is released instead of forcibly replacing a full party")
    var bounded := TacticalJourney.new(2026,"field_kit",[1],true)
    var bounded_policy := Policy.new()
    bounded_policy.attempts[bounded.step] = bounded.battle.turn-3
    check(bounded_policy.action(bounded) == CampaignPolicy.action(bounded),"A three-turn capture attempt falls back to normal combat without altering stats or HP")
    bounded.balls = 0 # Decision-boundary fixture.
    check(not bounded_policy.wants(bounded),"No capture attempt without a real ball")
    bounded.balls = 2
    bounded.current()["rare"] = true # Explicit route-boundary fixture.
    check(not bounded_policy.wants(bounded),"Early recruitment never tries a rare encounter")
    bounded.current().erase("rare")
    bounded_policy.captures.assign([{"step":0,"species":41},{"step":2,"species":316}])
    check(not bounded_policy.wants(bounded),"The comparison policy cannot exceed two successful captures")
    print("RECRUITMENT: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
