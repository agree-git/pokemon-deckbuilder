class_name JourneySnapshot
extends RefCounted
## A plain Variant graph. UID references preserve shared Pokemon/card instances.
const RUN_FIELDS := ["phase","seed_value","relic","step","wins","total_turns","badges","full_campaign","badge_records","elite_wins","reward_options","history","starter_ids","balls","_next_pokemon_uid","growth_reports","pending_learning","gold","inventory","loot","rested_steps","camp_states","run_id","captured_ids","relics","held_inventory","_next_card_uid"]
const BATTLE_FIELDS := ["full_type_chart","enemy_definitions","enemy_states","active_index","enemy_index","phase","energy","turn","events","history","seed_value","relic","relics","powers","turn_flags","turn_actors","retained","next_attack_bonus","switch_bonus","temporary_strength","_turn_changed","_ace_uid","_next_uid","_pending","_relay"]
const POKEMON_FIELDS := ["uid","species_id","display_name","type","types","max_hp","hp","block","strength","statuses","knocked_out","level","evolution_power","learned_skills","progression_initialized","_experience_tenths","held_item"]
const CARD_FIELDS := ["uid","key","owner_uid","injury_owner_uid","upgraded"]
static func fields(object: Object, names: Array) -> Dictionary:
    var result := {}
    for key: String in names:
        var value: Variant = object.get(key)
        result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    return result
static func ids(objects: Array) -> Array:
    return objects.map(func(object: RefCounted): return object.get("uid"))
static func encode(j: TacticalJourney) -> Dictionary:
    var pokemon := {}
    var cards := {}
    var b := j.battle
    for p: BattlePokemon in j.party+b.party+b.enemies+j.pending_captures: pokemon[p.uid] = fields(p,POKEMON_FIELDS)
    for c: BattleCardInstance in j.deck+b.hand+b.draw_pile+b.discard+b.exhausted: cards[c.uid] = fields(c,CARD_FIELDS)
    var state := fields(j,RUN_FIELDS)
    state["party"] = ids(j.party)
    state["deck"] = ids(j.deck)
    state["pending_captures"] = ids(j.pending_captures)
    state["settled"] = j._settled == b
    var combat := fields(b,BATTLE_FIELDS)
    combat["party"] = ids(b.party)
    combat["enemies"] = ids(b.enemies)
    combat["piles"] = [ids(b.hand),ids(b.draw_pile),ids(b.discard),ids(b.exhausted)]
    combat["rng"] = b._rng.state
    return {"run":state,"battle":combat,"pokemon":pokemon,"cards":cards,"route":j.route.signature if j.full_campaign else ""}
static func restore(data: Dictionary) -> TacticalJourney:
    # Call only after validate(). Constructors provide defaults, never saved Objects.
    var state: Dictionary = data["run"]
    var j := TacticalJourney.new(state["seed_value"],state["relic"],[],state["full_campaign"])
    var pokemon := {}
    var cards := {}
    for uid: int in data["pokemon"]:
        var row: Dictionary = data["pokemon"][uid]
        var p := BattlePokemon.new({"id":row["species_id"],"name":row["display_name"],"type":row["type"],"types":row["types"],"max_hp":row["max_hp"],"level":row["level"]},uid)
        for key: String in POKEMON_FIELDS: p.set(key,row[key])
        pokemon[uid] = p
    for uid: int in data["cards"]:
        var row: Dictionary = data["cards"][uid]
        var c := BattleCardInstance.new(uid,row["key"],row["owner_uid"])
        for key: String in CARD_FIELDS: c.set(key,row[key])
        cards[uid] = c
    for key: String in RUN_FIELDS: j.set(key,state[key])
    j.party.assign(state["party"].map(func(uid: int): return pokemon[uid]))
    j.deck.assign(state["deck"].map(func(uid: int): return cards[uid]))
    j.pending_captures.assign(state["pending_captures"].map(func(uid: int): return pokemon[uid]))
    var b := TacticalBattle.new()
    var combat: Dictionary = data["battle"]
    for key: String in BATTLE_FIELDS: b.set(key,combat[key])
    b.party.assign(combat["party"].map(func(uid: int): return pokemon[uid]))
    b.enemies.assign(combat["enemies"].map(func(uid: int): return pokemon[uid]))
    var piles: Array = [b.hand,b.draw_pile,b.discard,b.exhausted]
    for i in 4: piles[i].assign(combat["piles"][i].map(func(uid: int): return cards[uid]))
    b._rng.seed = b.seed_value
    b._rng.state = combat["rng"]
    j.battle = b
    j._settled = b if state["settled"] else null
    j.shop_stock = j.camp_states[j.step]["stock"] if j.camp_states.has(j.step) else {}
    j.bind_battle()
    return j
static func integer(value: Variant, minimum: int, maximum: int) -> bool:
    return value is int and value >= minimum and value <= maximum
static func references(values: Variant, registry: Dictionary, minimum: int, maximum: int) -> bool:
    if not values is Array or values.size() < minimum or values.size() > maximum: return false
    var seen := {}
    for uid: Variant in values:
        if not uid is int or not registry.has(uid) or seen.has(uid): return false
        seen[uid] = true
    return true
static func same_shape(row: Dictionary, defaults: Dictionary) -> bool:
    for key: String in defaults:
        if not row.has(key) or typeof(row[key]) != typeof(defaults[key]): return false
    return true
static func move(key: Variant) -> bool:
    if not key is String: return false
    if BattleContent.CARDS.has(key): return true
    return key.begins_with("move_") and key.trim_prefix("move_").is_valid_int() and TacticalGrowth.data()["moves"].has(key.trim_prefix("move_"))
static func validate(data: Variant) -> bool:
    if not data is Dictionary: return false
    for key: String in ["run","battle","pokemon","cards"]:
        if not data.get(key) is Dictionary: return false
    var r: Dictionary = data["run"]
    var b: Dictionary = data["battle"]
    var ps: Dictionary = data["pokemon"]
    var cs: Dictionary = data["cards"]
    if ps.size() < 2 or ps.size() > 16 or cs.size() < 1 or cs.size() > 512: return false
    if not same_shape(r,fields(TacticalJourney.new(),RUN_FIELDS)) or not r.get("settled") is bool: return false
    if not same_shape(b,fields(TacticalBattle.new(),BATTLE_FIELDS)) or not b.get("rng") is int: return false
    if not r["full_campaign"] or r["run_id"].length() != 32 or not r["run_id"].is_valid_hex_number(): return false
    if not TacticalContent.RELICS.has(r["relic"]) or b["relic"] != r["relic"] or not b["full_type_chart"]: return false
    for row: Dictionary in [r,b]:
        var seen := {}
        for key: Variant in row["relics"]:
            if not key is String or not TacticalContent.RELICS.has(key) or seen.has(key): return false
            seen[key] = true
        if row["relic"] not in row["relics"]: return false
    if not integer(r["_next_card_uid"],1,1000000): return false
    for key: Variant in r["held_inventory"]:
        if not key is String or not TacticalContent.HELD_ITEMS.has(key): return false
    if not integer(r["step"],0,136) or not integer(r["wins"],0,69) or not integer(r["badges"],0,8) or not integer(r["elite_wins"],0,4): return false
    if r["phase"] not in [TacticalJourney.BATTLE,TacticalJourney.LEARN,TacticalJourney.CAPTURE,TacticalJourney.REWARD,TacticalJourney.MAP,TacticalJourney.REST,TacticalJourney.CLEARED,TacticalJourney.FAILED]: return false
    for key: String in ["gold","balls","total_turns"]:
        if not integer(r[key],0,100000000): return false
    if not integer(r["_next_pokemon_uid"],1000,1000000) or r["starter_ids"].is_empty() or r["starter_ids"].size() > 3: return false
    var catalog := VisualCatalog.new()
    for id: Variant in r["captured_ids"]:
        if not integer(id,1,386): return false
    for key: String in ["history"]:
        for line: Variant in r[key]:
            if not line is String: return false
    for line: Variant in b["history"]:
        if not line is String: return false
    for id: Variant in r["starter_ids"]:
        if not integer(id,1,386): return false
    for uid: Variant in ps:
        var p: Variant = ps[uid]
        if not uid is int or not p is Dictionary or not same_shape(p,fields(BattlePokemon.new(TacticalContent.PARTY[0],1),POKEMON_FIELDS)): return false
        if p["uid"] != uid or uid == 0 or not integer(p["species_id"],1,386) or not integer(p["level"],1,100): return false
        if not integer(p["max_hp"],1,100000) or not integer(p["hp"],0,p["max_hp"]) or not integer(p["block"],0,100000): return false
        if not integer(p["_experience_tenths"],0,1000000000) or p["learned_skills"].size() > 4 or p["types"] != catalog.species(p["species_id"])["types"]: return false
        if p["type"] != p["types"][0] or p["display_name"] != catalog.species(p["species_id"])["name"]: return false
        if not p["held_item"].is_empty() and not TacticalContent.HELD_ITEMS.has(p["held_item"]): return false
        for key: Variant in p["learned_skills"]:
            if not move(key): return false
        for key: Variant in p["statuses"]:
            var status: Variant = p["statuses"][key]
            if key not in ["burn","seed","poison","sleep","paralysis","confusion","exposed"] or not status is Dictionary: return false
            if not integer(status.get("turns"),1,100) or not status.get("source_uid") is int: return false
    for uid: Variant in cs:
        var c: Variant = cs[uid]
        if not uid is int or not c is Dictionary or not same_shape(c,fields(BattleCardInstance.new(1,"guard",0),CARD_FIELDS)): return false
        if uid <= 0 or c["uid"] != uid: return false
        if c["owner_uid"] == 0:
            if not TacticalContent.CARDS.has(c["key"]): return false
        elif c["owner_uid"] < 1 or not ps.has(c["owner_uid"]) or not move(c["key"]): return false
    if not references(r.get("party"),ps,1,3) or not references(r.get("pending_captures"),ps,0,3) or not references(r.get("deck"),cs,1,512): return false
    if not references(b.get("party"),ps,1,3) or not references(b.get("enemies"),ps,1,6): return false
    if not b.get("piles") is Array or b["piles"].size() != 4: return false
    var pile_ids := {}
    for pile: Variant in b["piles"]:
        if not references(pile,cs,0,512): return false
        for uid: int in pile:
            if pile_ids.has(uid): return false
            pile_ids[uid] = true
    if not integer(b["active_index"],0,b["party"].size()-1) or not integer(b["enemy_index"],0,b["enemies"].size()-1): return false
    if b["phase"] not in [TacticalBattle.PLAYER,TacticalBattle.REPLACE,TacticalBattle.WON,TacticalBattle.LOST]: return false
    if not integer(b["energy"],0,10000) or not integer(b["turn"],1,1000000): return false
    if b["enemy_states"].size() != b["enemies"].size() or b["enemy_definitions"].size() != b["enemies"].size(): return false
    if b["_pending"] not in ["","player","enemy"]: return false
    if b["phase"] == TacticalBattle.REPLACE and b["_pending"].is_empty(): return false
    for definition: Variant in b["enemy_definitions"]:
        if not definition is Dictionary or not definition.get("intents") is Array or definition["intents"].is_empty(): return false
        for intent: Variant in definition["intents"]:
            if not intent is Dictionary or intent.get("kind") not in ["attack","charge","block","boost"]: return false
            if not integer(intent.get("value"),0,100000) or not integer(intent.get("move_id"),1,354): return false
            if intent["kind"] in ["attack","charge"] and intent.get("type") not in VisualCatalog.TYPE_COLORS: return false
    for key: Variant in b["powers"]:
        if key not in ["relay","ace","supply"] or not integer(b["powers"][key],1,512): return false
    for key: Variant in b["turn_flags"]:
        if not key is String or not b["turn_flags"][key] is bool: return false
    for uid: Variant in b["turn_actors"]:
        if not uid is int or uid not in b["party"]: return false
    for uid: Variant in b["retained"]:
        if not uid is int or uid not in b["piles"][0]: return false
    for event: Variant in b["events"]:
        if not event is Dictionary or not event.get("kind") is String or not event.get("text") is String: return false
    for state: Variant in b["enemy_states"]:
        if not state is Dictionary or not same_shape(state,{"intent":0}): return false
        if not integer(state["intent"],0,1000000): return false
    for mapping: Dictionary in [b["switch_bonus"],b["temporary_strength"]]:
        for uid: Variant in mapping:
            if not uid is int or uid not in b["party"] or not integer(mapping[uid],0,100000): return false
    for key: String in ["potion","super_potion","revive"]:
        if not integer(r["inventory"].get(key),0,100000): return false
    if r["badge_records"].size() != r["badges"]: return false
    var route := CampaignRoute.new(r["seed_value"])
    if not data.get("route") is String or data["route"] != route.signature: return false
    for step: Variant in r["camp_states"]:
        var camp: Variant = r["camp_states"][step]
        if not integer(step,0,136) or route.stops[step]["kind"] != "rest" or not camp is Dictionary: return false
        if not camp.get("resolved") is bool or not camp.get("outcome") is String or not camp.get("stock") is Dictionary: return false
        for key: String in route.stops[step]["camp"]:
            if camp.get(key) != route.stops[step]["camp"][key]: return false
        for key: Variant in camp["stock"]:
            if key not in ["potion","super_potion","revive","ball"] or not integer(camp["stock"][key],0,4): return false
    for step: Variant in r["rested_steps"]:
        if not integer(step,0,136) or route.stops[step]["kind"] != "rest": return false
    for entry: Variant in r["loot"]:
        if not entry is Dictionary or not entry.get("name") is String or not integer(entry.get("gold"),0,100000): return false
        if entry.get("item") not in ["","potion","super_potion","revive","ball"] or not integer(entry.get("quantity"),0,10000): return false
    for report: Variant in r["growth_reports"]:
        if not report is Dictionary or not same_shape(report,{"uid":0,"id":1,"name":"","before":5,"after":5,"xp":0.0,"hp":0,"learned":[],"offers":[],"evolutions":[]}): return false
        for name: Variant in report["learned"]:
            if not name is String: return false
        for evolution: Variant in report["evolutions"]:
            if not evolution is Dictionary or not evolution.get("name") is String: return false
    for offer: Variant in r["pending_learning"]:
        if not offer is Dictionary or offer.get("uid") not in r["party"] or not move(offer.get("key")) or not integer(offer.get("level"),1,100): return false
    if r["phase"] == TacticalJourney.LEARN and r["pending_learning"].is_empty(): return false
    if r["phase"] == TacticalJourney.CAPTURE and r["pending_captures"].is_empty(): return false
    if r["phase"] == TacticalJourney.REST and (route.stops[r["step"]]["kind"] != "rest" or not r["camp_states"].has(r["step"])): return false
    if r["phase"] in [TacticalJourney.LEARN,TacticalJourney.REWARD,TacticalJourney.CAPTURE,TacticalJourney.CLEARED,TacticalJourney.FAILED] and not r["settled"]: return false
    if r["phase"] == TacticalJourney.REWARD:
        if r["reward_options"].size() != 3: return false
        for option: Variant in r["reward_options"]:
            if not option is Dictionary or not option.get("key") is String: return false
            match option.get("kind",""):
                "card":
                    if not option.get("owner_uid") is int or not option.get("upgraded") is bool: return false
                    if option["owner_uid"] == 0:
                        if not TacticalContent.CARDS.has(option["key"]) or option["key"] == "injury": return false
                    elif option["owner_uid"] not in r["party"] or not move(option["key"]): return false
                "relic":
                    if not TacticalContent.RELICS.has(option["key"]) or option["key"] in r["relics"]: return false
                "held":
                    if not TacticalContent.HELD_ITEMS.has(option["key"]): return false
                _: return false
    if r["phase"] == TacticalJourney.BATTLE:
        if r["settled"] or r["party"] != b["party"] or route.stops[r["step"]]["kind"] == "rest": return false
    return true
