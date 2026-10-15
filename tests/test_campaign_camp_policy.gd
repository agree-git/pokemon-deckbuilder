extends SceneTree
const Policy = preload("res://tools/campaign_camp_policy.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fixture(starters: Array[int]) -> TacticalJourney:
    for seed_value in 100:
        var j := TacticalJourney.new(seed_value,"field_kit",starters,true)
        if j.route.stops[1]["camp"]["kind"] != "merchant": continue
        j.phase = TacticalJourney.MAP
        j.step = 1
        j.enter_next()
        return j
    check(false,"Find a deterministic merchant camp")
    return null
func run() -> void:
    var j := fixture([1,4,7])
    var route := j.route.signature
    var rng := j.battle._rng.state
    var xp := j.party.map(func(p: BattlePokemon): return p.experience)
    check(Policy.apply(j,"baseline").is_empty(),"A healthy party develops using public actions")
    check(j.statistics["counts"]["cards_upgraded"] == 1 and j.statistics["counts"]["rests"] == 0,"Healthy camp spends its one action on an actual upgrade")
    check(j.deck.any(func(c: BattleCardInstance): return c.upgraded),"The upgrade is present in the live deck")
    check(j.route.signature == route and j.battle._rng.state == rng and j.party.map(func(p: BattlePokemon): return p.experience) == xp,"Camp decisions cannot change route, battle RNG or grant XP")
    check(JourneySnapshot.validate(JourneySnapshot.encode(j)),"Developed checkpoint is a valid real game save")
    var before := JourneySnapshot.encode(j)
    check(not Policy.apply(j,"baseline").is_empty() and JourneySnapshot.encode(j) == before,"A repeated healthy-camp action fails without another upgrade")
    j = fixture([1,4,7])
    j.party[0].hp = 1
    j.party[1].hp = 0
    j.party[1].knocked_out = true
    j.deck.append(BattleCardInstance.new(j._next_card_uid,"injury",0))
    j._next_card_uid += 1
    check(Policy.apply(j,"relay").is_empty(),"Damaged and fainted party recovers before development")
    check(j.party.all(func(p: BattlePokemon): return p.alive()) and not j.deck.any(func(c: BattleCardInstance): return c.key == "injury"),"Rest revives allies and removes injury through normal rules")
    check(j.statistics["counts"]["rests"] == 1 and j.statistics["counts"]["cards_upgraded"] == 0,"Recovery cannot also grant a camp upgrade")
    j = fixture([172,4,7])
    var friendship := FriendshipEvolution.value(j.party[0])
    check(Policy.apply(j,"baseline").is_empty() and FriendshipEvolution.value(j.party[0]) == friendship+5 and j.statistics["counts"]["rests"] == 1,"Healthy friendship candidates still choose normal friendship rest")
    j = fixture([64,4,7])
    j.gold = 500
    check(j.camp()["evolution_offer"] == "linking_cord","Fixture offers an actually usable trade material")
    var uid := j.party[0].uid
    check(Policy.apply(j,"baseline").is_empty() and j.party[0].species_id == 65 and j.party[0].uid == uid,"Purchase and use a real evolution material without replacing identity")
    check(j.shop_stock["linking_cord"] == 0 and j.quantity("linking_cord") == 0 and j.statistics["counts"]["gold_supplies"] == 180,"Evolution consumes finite stock, material and actual gold")
    j = fixture([64,4,7])
    j.gold = 279
    check(Policy.prepare_evolutions(j).is_empty() and j.party[0].species_id == 64 and j.gold == 279 and j.shop_stock["linking_cord"] == 1,"An unaffordable reserve prevents buying rather than granting evolution")
    j = fixture([349,4,7])
    j.gold = 500
    xp = j.party.map(func(p: BattlePokemon): return p.experience)
    check(Policy.prepare_evolutions(j).is_empty() and j.party[0].beauty == 180 and j.party[0].species_id == 349,"Beauty preparation uses three actual items and waits for earned level-up")
    check(j.gold == 320 and j.shop_stock["blue_pokeblock"] == 0 and j.party.map(func(p: BattlePokemon): return p.experience) == xp,"Beauty consumes 180 gold and stock without awarding XP")
    before = JourneySnapshot.encode(j)
    check(Policy.prepare_evolutions(j).is_empty() and JourneySnapshot.encode(j) == before,"Prepared beauty cannot be bought or applied twice")
    j = fixture([1,4,7])
    j.gold = 500
    var candidate := Policy.removal_candidate(j)
    check(candidate != 0,"A low-rated support technique can be removed")
    var card: BattleCardInstance
    for c: BattleCardInstance in j.deck:
        if c.uid == candidate: card = c
    check(card != null and card.owner_uid != 0 and not TacticalContent.definition(card).has("damage"),"Candidate is neither a damaging technique nor a shared guard")
    var deck_size := j.deck.size()
    check(j.remove_card(candidate).is_empty() and j.deck.size() == deck_size-1 and j.gold == 450 and j.statistics["counts"]["cards_removed"] == 1,"Deck thinning pays the real removal price")
    check(Policy.removal_candidate(j) == 0,"No second removal at the same merchant")
    # No live session is adopted and no persistent collection or run is written.
    print("CAMPAIGN_CAMP_POLICY: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
