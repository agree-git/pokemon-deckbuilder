extends RefCounted
## Measurement policy only. Every mutation goes through a public journey action.
const RESERVE := 100
static func resolve_encounter(j: TacticalJourney) -> String:
    var state := j.camp()
    if state.get("resolved",false) or state["kind"] not in ["event","discovery"]: return ""
    var choice := 0
    if state["kind"] == "event":
        match state["id"]:
            "spring": choice = 0 if j.party.any(func(p: BattlePokemon): return p.hp < p.max_hp) else 1
            "satchel": choice = 1 # No capture in this controlled comparison.
            "lesson": choice = 0 if j.deck.size() < 24 and j.gold >= RESERVE+50 else -1
    if not j.camp_choice_reason(choice).is_empty(): return ""
    return j.resolve_camp(choice)
static func prepare_evolutions(j: TacticalJourney) -> String:
    for i in j.party.size():
        var p := j.party[i]
        if not p.alive(): continue
        for key: String in EvolutionItems.options(p.species_id):
            if j.quantity(key) == 0 and j.gold-int(EvolutionItems.ITEMS[key]["price"]) >= RESERVE and j.buy_reason(key).is_empty():
                var error := j.buy(key)
                if not error.is_empty(): return error
            if j.item_reason(key,i).is_empty():
                var error := j.use_item(key,i)
                if not error.is_empty(): return error
                break
        while p.species_id == 349 and p.level < 100 and SpecialEvolution.beauty(p) < SpecialEvolution.BEAUTY_THRESHOLD:
            if j.quantity("blue_pokeblock") == 0:
                if j.gold-60 < RESERVE or not j.buy_reason("blue_pokeblock").is_empty(): break
                var error := j.buy("blue_pokeblock")
                if not error.is_empty(): return error
            var error := j.use_item("blue_pokeblock",i)
            if not error.is_empty(): return error
    return ""
static func upgrade_candidate(j: TacticalJourney, style: String) -> int:
    var best := -1.0
    var uid := 0
    for card: BattleCardInstance in j.deck:
        if not TacticalContent.can_upgrade(card): continue
        var view := TacticalContent.definition(card)
        var score := CampaignPolicy.score(view)
        if view.has("draw"): score += 15
        if view.has("energy"): score += 15
        if style in TacticalContent.CARD_THEMES.get(card.key,[]): score += 10
        if score > best:
            best = score
            uid = card.uid
    return uid
static func removal_candidate(j: TacticalJourney) -> int:
    # Remove weak or duplicate unupgraded support techniques. Public validation
    # protects the last owner card. Keep all attacks, seeds and recovery cards.
    var worst := 1000.0
    var uid := 0
    for card: BattleCardInstance in j.deck:
        if card.owner_uid == 0 or card.upgraded or not j.remove_card_reason(card.uid).is_empty(): continue
        var view := TacticalContent.definition(card)
        if view.has("damage") or view.has("seed") or view.has("heal"): continue
        var copies := 0
        for other: BattleCardInstance in j.deck:
            if other.owner_uid == card.owner_uid and other.key == card.key: copies += 1
        var score := CampaignPolicy.score(view)
        if copies < 2 and score > 9: continue
        if score < worst:
            worst = score
            uid = card.uid
    return uid
static func apply(j: TacticalJourney, style: String) -> String:
    if j.phase != TacticalJourney.REST: return "Development camp policy requires a camp"
    var error := resolve_encounter(j)
    if not error.is_empty(): return error
    # Recovery takes priority; friendship evolutions also benefit from resting.
    var needs_rest := j.party.any(func(p: BattlePokemon): return not p.alive() or p.hp < p.max_hp*0.75 or (p.level < 100 and FriendshipEvolution.eligible(p.species_id) and FriendshipEvolution.value(p) < FriendshipEvolution.THRESHOLD))
    if needs_rest:
        error = j.rest()
        if not error.is_empty(): return error
    error = prepare_evolutions(j)
    if not error.is_empty(): return error
    for p: BattlePokemon in j.party:
        if p.held_item.is_empty() and not j.held_inventory.is_empty():
            error = j.equip_held(j.held_inventory[0],p.uid)
            if not error.is_empty(): return error
    for i in j.party.size():
        var p := j.party[i]
        if p.hp >= p.max_hp*0.75: continue
        for key: String in ["revive","super_potion","potion"]:
            if (key == "revive") == p.alive(): continue
            if j.quantity(key) == 0 and j.buy_reason(key).is_empty():
                error = j.buy(key)
                if not error.is_empty(): return error
            if j.item_reason(key,i).is_empty():
                error = j.use_item(key,i)
                if not error.is_empty(): return error
            if p.hp >= p.max_hp*0.75: break
    if not needs_rest:
        var uid := upgrade_candidate(j,style)
        error = j.rest("upgrade",uid) if uid != 0 else j.rest()
        if not error.is_empty(): return error
    var remove := removal_candidate(j)
    if remove != 0 and j.gold-j.removal_price() >= RESERVE:
        error = j.remove_card(remove)
    return error
