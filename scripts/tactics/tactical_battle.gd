class_name TacticalBattle
extends RefCounted
signal changed
## Shared card combat. Rules finish atomically before animation or autosave.
const PLAYER := "player"
const REPLACE := "replace"
const WON := "won"
const LOST := "lost"
var full_type_chart := false
var party: Array[BattlePokemon] = []
var enemies: Array[BattlePokemon] = []
var enemy_definitions: Array = []
var enemy_states: Array[Dictionary] = []
var active_index := 0
var enemy_index := 0
var phase := PLAYER
var energy := 3
# Captured once per player turn; switching never grants energy.
var turn_energy_bonus := 0
var turn_speed_actor := 0
var turn_speed_enemy := 0
var turn_speed_owner_uid := 0
var turn_speed_target_uid := 0
var turn := 1
var hand: Array[BattleCardInstance] = []
var draw_pile: Array[BattleCardInstance] = []
var discard: Array[BattleCardInstance] = []
var exhausted: Array[BattleCardInstance] = []
var events: Array[Dictionary] = []
var history: Array[String] = []
var statistics: Dictionary = {}
var seed_value := 2026
var relic := "field_kit"
var relics: Array[String] = []
var powers: Dictionary = {}
var turn_flags: Dictionary = {}
var turn_actors: Array[int] = []
var retained: Array[int] = []
var next_attack_bonus := 0
var switch_bonus: Dictionary = {}
var temporary_strength: Dictionary = {}
var _turn_changed := false
var _ace_uid := 0
var _next_uid := 1
var _rng := RandomNumberGenerator.new()
var _pending := ""
var _relay: Dictionary = {}

func _init(battle_seed: int = 2026, selected_relic: String = "field_kit", opponents: Array = TacticalContent.ENEMIES) -> void:
    restart(battle_seed,selected_relic,opponents)
func restart(battle_seed: int = 2026, selected_relic: String = "field_kit", opponents: Array = TacticalContent.ENEMIES) -> void:
    var members: Array[BattlePokemon] = []
    for definition: Dictionary in TacticalContent.PARTY:
        members.append(BattlePokemon.new(definition,int(definition["uid"])))
    var cards := TacticalContent.starting_deck(members)
    start_with(members,cards,opponents,battle_seed,selected_relic,true)
func start_with(members: Array[BattlePokemon], cards: Array[BattleCardInstance], opponents: Array, battle_seed: int, selected_relic: String, _lead_first := true, acquired: Array[String] = []) -> void:
    statistics = RunStatistics.battle()
    seed_value = battle_seed
    relic = selected_relic if TacticalContent.RELICS.has(selected_relic) else "field_kit"
    relics.assign(acquired)
    if relic not in relics: relics.push_front(relic)
    party.assign(members)
    enemies.clear()
    enemy_states.clear()
    enemy_definitions = opponents.duplicate(true)
    for i in opponents.size():
        enemies.append(BattlePokemon.new(opponents[i],-i-1))
        PokemonStats.apply(enemies[-1],true)
        enemy_states.append({"intent":0})
    active_index = 0
    for i in party.size():
        var pokemon := party[i]
        PokemonStats.apply(pokemon)
        pokemon.stat_stages.clear()
        pokemon.block = PokemonStats.scale(pokemon,5) if has_relic("field_kit") else 0
        pokemon.strength = 0
        pokemon.statuses.clear()
        pokemon.knocked_out = not pokemon.alive()
        if not party[active_index].alive() and pokemon.alive(): active_index = i
    if has_relic("field_kit"): _relic_stat("field_kit")
    enemy_index = 0
    phase = PLAYER
    _grant_turn_energy()
    turn = 1
    hand.clear()
    draw_pile.assign(cards)
    discard.clear()
    exhausted.clear()
    powers.clear()
    turn_flags.clear()
    turn_actors.clear()
    retained.clear()
    next_attack_bonus = 0
    switch_bonus.clear()
    temporary_strength.clear()
    _turn_changed = false
    _ace_uid = 0
    _pending = ""
    _relay.clear()
    events.clear()
    history.clear()
    _next_uid = 1
    for card: BattleCardInstance in cards: _next_uid = maxi(_next_uid,card.uid+1)
    _rng.seed = battle_seed
    _shuffle(draw_pile)
    _draw(5)
    _record("turn","턴 1 · 에너지 %d" % energy)
func active() -> BattlePokemon: return party[active_index]
func enemy() -> BattlePokemon: return enemies[enemy_index]
func opening() -> Dictionary: return enemy_states[enemy_index]
func has_relic(key: String) -> bool: return key in relics
func _grant_turn_energy() -> void:
    _stat("turns_started")
    turn_speed_actor = PokemonStats.effective(active(),"speed")
    turn_speed_enemy = PokemonStats.effective(enemy(),"speed")
    turn_speed_owner_uid = active().uid
    turn_speed_target_uid = enemy().uid
    turn_energy_bonus = 1 if turn_speed_actor > turn_speed_enemy else 0
    energy = 3+turn_energy_bonus
func intent() -> Dictionary:
    return intent_for(active())
func intent_for(defender: BattlePokemon) -> Dictionary:
    var definitions: Array = enemy_definitions[enemy_index]["intents"]
    var result: Dictionary = definitions[int(opening()["intent"]) % definitions.size()].duplicate(true)
    result["tactic"] = str(enemy_definitions[enemy_index].get("tactic",""))
    if result["kind"] in ["attack","charge"]:
        var move := TacticalMoves.definition(TacticalMoves.key_for(int(result["move_id"]))).duplicate(true)
        move["type"] = result.get("type",move.get("type","normal"))
        result["damage_class"] = move.get("damage_class","physical")
        result["value"] = PokemonStats.damage(enemy(),defender,move,1.0 if int(result["move_id"]) == 165 else multiplier(move["type"],defender),0,1.2 if result["kind"] == "charge" else 1.0)
    elif result["kind"] == "block": result["value"] = PokemonStats.scale(enemy(),int(result["value"]))
    if enemy().statuses.has("sleep"): result["asleep"] = true
    return result
func card_view(card: BattleCardInstance) -> Dictionary:
    var view := TacticalContent.definition(card)
    var actor := member(card.owner_uid) if card.owner_uid != 0 else active()
    view["owner_name"] = actor.display_name if card.owner_uid != 0 and actor != null else ""
    view["species_id"] = actor.species_id if card.owner_uid != 0 and actor != null else 0
    view["switches"] = card.owner_uid != 0 and actor != active()
    view["retained"] = card.uid in retained
    if actor != null:
        if view.has("damage"): view["preview_damage"] = attack_damage(view,actor)
        if view.has("shield_attack"): view["preview_damage"] = actor.block
        if has_relic("status_flask") and not turn_flags.has("status_flask"):
            for status: String in ["burn","poison","seed"]:
                if view.has(status): view["preview_"+status] = int(view[status])+1
        if view.has("condition"): view["condition_active"] = bool(turn_flags.get("technique_switch",false)) if view["condition"] == "relay" else bool(turn_flags.get("double_technique_%d" % actor.uid,false))
        if view.has("heal"): view["preview_heal"] = PokemonStats.scale(actor,int(view["heal"])+(6 if actor.held_item == "healing_bell" and view["category"] == "tool" else 0))
        if view.has("block"): view["preview_block"] = PokemonStats.scale(actor,int(view["block"]))+defense_bonus(actor)
        if view.has("bonus"): view["preview_bonus"] = PokemonStats.scale(actor,int(view["bonus"]))
        view["description"] = TacticalContent.description(view)
    return view
func attack_damage(view: Dictionary, actor: BattlePokemon) -> int:
    var switched_attack := int(switch_bonus.get(actor.uid,0))
    if actor != active() and has_relic("switch_power"): switched_attack = 3
    var bonus := next_attack_bonus+switched_attack
    if actor.held_item == "power_band": bonus += 3
    if enemy().statuses.has("exposed"): bonus += 2
    return PokemonStats.damage(actor,enemy(),view,1.0 if int(view.get("move_id",0)) == 165 else multiplier(view.get("type","normal"),enemy()),bonus)
func defense_bonus(actor: BattlePokemon) -> int:
    return PokemonStats.scale(actor,4) if actor.held_item == "guard_charm" else 0
# Old input/API callers must also own a drawn card; fixed skills cannot bypass draw.
func skill_view(key: String) -> Dictionary:
    for card: BattleCardInstance in hand:
        if card.key == key and card.owner_uid == active().uid: return card_view(card)
    return TacticalMoves.definition(key).duplicate(true)
func skill_reason(key: String) -> String:
    for card: BattleCardInstance in hand:
        if card.key == key and card.owner_uid == active().uid: return card_reason(card.uid)
    return "손패의 기술 카드를 사용하세요."
func use_skill(key: String) -> String:
    for card: BattleCardInstance in hand:
        if card.key == key and card.owner_uid == active().uid: return play_card(card.uid)
    return "손패의 기술 카드를 사용하세요."
func card_reason(uid: int) -> String:
    if phase != PLAYER: return "현재 카드를 사용할 수 없습니다."
    var card := _hand(uid)
    if card == null: return "손패에 없는 카드입니다."
    if card.owner_uid != 0:
        var actor := member(card.owner_uid)
        if actor == null or not actor.alive(): return "기절했거나 파티를 떠난 포켓몬의 기술입니다."
    if energy < int(card_view(card)["cost"]): return "에너지가 부족합니다."
    return ""
func play_card(uid: int) -> String:
    var reason := card_reason(uid)
    if not reason.is_empty(): return reason
    events.clear()
    var card := _hand(uid)
    var view := card_view(card)
    hand.erase(card)
    retained.erase(card.uid)
    energy -= int(view["cost"])
    _stat("energy_spent",int(view["cost"]))
    _stat("cards_played")
    _stat({"technique":"techniques","trainer":"trainers","tool":"tools","status":"status_cards"}[view["category"]])
    RunStatistics.increment(statistics["cards"],card.key)
    if card.owner_uid != 0 and card.owner_uid != active().uid: _change_active(card.owner_uid,true)
    var actor := active()
    var target := enemy()
    _record("skill" if card.owner_uid != 0 else "card",("%s · " % actor.display_name if card.owner_uid != 0 else "")+str(view["name"]),{"move_id":view["move_id"],"actor":actor.uid,"card_uid":card.uid})
    if view.has("damage"):
        var amount := attack_damage(view,actor)
        next_attack_bonus = 0
        switch_bonus.erase(actor.uid)
        _damage(target,amount)
    if view.has("shield_attack"):
        var amount := actor.block
        actor.block = 0
        _record("shield_spent",actor.display_name+" 보호막 소비",{"target":actor.uid,"amount":amount})
        _damage(target,amount)
    if target.alive():
        var fresh := false
        var extend := has_relic("status_flask") and not turn_flags.has("status_flask") and ["burn","poison","seed"].any(func(key: String): return view.has(key))
        for status: String in ["burn","seed","poison","sleep","paralysis","confusion"]:
            if view.has(status):
                fresh = fresh or not target.statuses.has(status)
                target.statuses[status] = {"turns":int(view[status])+(1 if extend and status in ["burn","poison","seed"] else 0),"source_uid":actor.uid}
        if extend:
            turn_flags["status_flask"] = true
            _record("relic","잔류 시약 · 지속 횟수 +1",{"relic_key":"status_flask"})
        if fresh and has_relic("status_lens") and not turn_flags.has("status_lens"):
            turn_flags["status_lens"] = true
            energy += 1
            _record("relic","상태 관측경 · 에너지 +1",{"relic_key":"status_lens"})
        if view.has("weaken"): target.strength = maxi(-6,target.strength-int(view["weaken"]))
        if view.has("expose"): target.statuses["exposed"] = {"turns":3,"source_uid":actor.uid}
        if view.has("weaken") or view.has("expose") or ["burn","seed","poison","sleep","paralysis","confusion"].any(func(status: String): return view.has(status)):
            _record("status",target.display_name+" 상태 변화",{"target":target.uid})
    if view.has("stat_changes"):
        var recipient := actor if view.get("stat_target","enemy") == "self" else target
        if recipient.alive():
            for stat: String in view["stat_changes"]:
                recipient.stat_stages[stat] = clampi(int(recipient.stat_stages.get(stat,0))+int(view["stat_changes"][stat]),-6,6)
            _record("stat",recipient.display_name+" 능력 변화",{"target":recipient.uid})
    if view.has("heal"):
        var recovered := mini(actor.max_hp-actor.hp,int(view["preview_heal"]))
        actor.hp += recovered
        _record("heal",actor.display_name+" 회복",{"target":actor.uid,"amount":recovered})
    if view.has("block"):
        var protection := PokemonStats.scale(actor,int(view["block"]))+defense_bonus(actor)
        actor.block += protection
        _record("shield",actor.display_name+" 보호막",{"target":actor.uid,"amount":protection})
    if view.has("strength"): actor.strength += int(view["strength"])
    if view.has("bonus"): next_attack_bonus += int(view["bonus"])
    if view.has("temporary_strength"):
        var bonus := int(view["temporary_strength"])
        actor.strength += bonus
        temporary_strength[actor.uid] = int(temporary_strength.get(actor.uid,0))+bonus
    if view.has("energy"): energy += int(view["energy"])
    if view.has("cleanse"): actor.statuses.clear()
    if view.has("power"):
        var power: String = view["power"]
        powers[power] = int(powers.get(power,0))+1
        _record("power",str(view["name"])+" 설치")
    if view.has("cash"):
        var ticks := 0
        for status: String in ["burn","poison","seed"]:
            ticks += int(target.statuses.get(status,{}).get("turns",0))
            target.statuses.erase(status)
        _damage(target,PokemonStats.scale(target,ticks*4),true)
    if view.has("retain") and not hand.is_empty():
        var candidates: Array[BattleCardInstance] = []
        for candidate: BattleCardInstance in hand:
            if candidate.uid not in retained: candidates.append(candidate)
        candidates.sort_custom(func(a: BattleCardInstance,b: BattleCardInstance): return int(card_view(a)["cost"]) > int(card_view(b)["cost"]))
        for i in mini(int(view.get("retain_count",1)),candidates.size()): retained.append(candidates[i].uid)
    if view.has("retrieve"):
        for i in range(discard.size()-1,-1,-1):
            if discard[i].owner_uid != 0 and member(discard[i].owner_uid).alive() and hand.size() < 10:
                hand.append(discard.pop_at(i))
                break
    if view.has("redraw"):
        var count := hand.size()
        discard.append_array(hand)
        hand.clear()
        retained.clear()
        _draw(count+int(view.get("redraw_bonus",0)))
    if view.has("draw"): _draw(int(view["draw"]))
    if view.get("condition_active",false): _draw(int(view["conditional_draw"]))
    if card.owner_uid != 0:
        var first_technique := "technique_%d" % actor.uid
        if turn_flags.has(first_technique):
            turn_flags["double_technique_%d" % actor.uid] = true
            if has_relic("ace_emblem") and not turn_flags.has("ace_emblem"):
                turn_flags["ace_emblem"] = true
                _draw(1)
                _record("relic","집중 문장 · 카드 1장",{"relic_key":"ace_emblem"})
        turn_flags[first_technique] = true
        if actor.uid not in turn_actors: turn_actors.append(actor.uid)
        if turn_actors.size() >= 3 and has_relic("relay_draw") and not turn_flags.has("relay_draw"):
            turn_flags["relay_draw"] = true
            _draw(2)
            _record("relic","릴레이 수첩 · 카드 2장",{"relic_key":"relay_draw"})
    if view["category"] == "tool":
        var supplied := PokemonStats.scale(actor,5*int(powers.get("supply",0)))
        actor.block += supplied
        if supplied > 0: _record("shield","보급 작전",{"target":actor.uid,"amount":supplied})
        if has_relic("tool_belt") and not turn_flags.has("tool_belt"):
            turn_flags["tool_belt"] = true
            _draw(1)
            _record("relic","보급 벨트 · 카드 1장",{"relic_key":"tool_belt"})
    if view.get("exhaust",false) or view.has("power"): exhausted.append(card)
    else: discard.append(card)
    _outcome()
    return notify_changed()
func _change_active(uid: int, technique := false) -> void:
    if uid == active().uid: return
    var old := active()
    old.strength -= int(temporary_strength.get(old.uid,0))
    temporary_strength.erase(old.uid)
    old.stat_stages.clear()
    for i in party.size():
        if party[i].uid == uid: active_index = i
    _turn_changed = true
    if technique:
        turn_flags["technique_switch"] = true
        active().block += PokemonStats.scale(active(),3*int(powers.get("relay",0)))
        _stat("auto_switches")
        if has_relic("switch_power"):
            switch_bonus[uid] = 3
            _relic_stat("switch_power")
    var ribbon := "ribbon_%d" % uid
    if active().held_item == "relay_ribbon" and not turn_flags.has(ribbon):
        turn_flags[ribbon] = true
        active().block += PokemonStats.scale(active(),5)
    _record("switch",active().display_name+" 출전",{"actor":uid})
    if technique and has_relic("relay_cell") and not turn_flags.has("relay_cell"):
        turn_flags["relay_cell"] = true
        energy += 1
        _record("relic","릴레이 발전기 · 에너지 +1",{"relic_key":"relay_cell"})
func switch_reason(uid: int) -> String:
    if phase not in [PLAYER,REPLACE]: return "전투가 끝났습니다."
    var pokemon := member(uid)
    if pokemon == null or not pokemon.alive() or pokemon == active(): return "살아 있는 대기 포켓몬을 선택하세요."
    if phase == PLAYER and energy < 1: return "수동 교대에는 에너지 1이 필요합니다. 기술 카드는 무료로 교대합니다."
    return ""
func switch_to(uid: int) -> String:
    var reason := switch_reason(uid)
    if not reason.is_empty(): return reason
    events.clear()
    var forced := phase == REPLACE
    if not forced:
        energy -= 1
        _stat("energy_spent")
    _stat("forced_switches" if forced else "manual_switches")
    _change_active(uid)
    if forced:
        if _pending == "enemy": _enemy_action()
        else: _start_player()
    return notify_changed()
func capture_reason() -> String:
    if phase != PLAYER: return "지금은 포획할 수 없습니다."
    if energy < 1: return "포획에는 에너지 1이 필요합니다."
    if enemy().hp*4 > enemy().max_hp: return "체력을 25% 이하로 낮추세요."
    return ""
func capture_enemy() -> String:
    var reason := capture_reason()
    if not reason.is_empty(): return reason
    events.clear()
    energy -= 1
    _stat("energy_spent")
    _stat("captures")
    var target := enemy()
    target.hp = 0
    target.knocked_out = true
    target.statuses.clear()
    opening()["captured"] = true
    _relay.clear()
    _record("capture",target.display_name+" 포획 성공!",{"species_id":target.species_id})
    _outcome()
    return ""
func end_turn() -> String:
    if phase != PLAYER: return "현재 턴을 종료할 수 없습니다."
    events.clear()
    _stat("unused_energy",energy)
    _ace_uid = active().uid if not _turn_changed else 0
    for card: BattleCardInstance in hand.duplicate():
        if card.uid not in retained:
            hand.erase(card)
            discard.append(card)
    retained.clear()
    phase = "enemy"
    for pokemon: BattlePokemon in party:
        if pokemon.alive() and pokemon.held_item == "seed_charm" and ["burn","seed","poison"].any(func(key: String): return enemy().statuses.has(key)):
            var recovered := mini(pokemon.max_hp-pokemon.hp,PokemonStats.scale(pokemon,2))
            pokemon.hp += recovered
            if recovered > 0: _record("heal","생명의 부적",{"target":pokemon.uid,"amount":recovered})
        _tick(pokemon)
        if _outcome(): return notify_changed()
    if not active().alive():
        phase = REPLACE
        _pending = "enemy"
    else: _enemy_action()
    return notify_changed()
func _enemy_action() -> void:
    _pending = ""
    enemy().block = 0
    var state := opening()
    var action := intent()
    if enemy().statuses.has("sleep"):
        _record("cancel",enemy().display_name+"은 잠들어 행동할 수 없습니다.")
    else:
        _record("enemy_action",enemy().display_name+" · "+(str(TacticalMoves.visual(int(action["move_id"]))["name"]) if action["kind"] in ["attack","charge"] else ("방어" if action["kind"] == "block" else "위력 강화")),action.merged({"action":action["kind"]}))
        match action["kind"]:
            "attack","charge": _damage(active(),int(action["value"]))
            "block":
                enemy().block = int(action["value"])
                _record("shield",enemy().display_name+" 보호막",{"target":enemy().uid,"amount":int(action["value"])})
            "boost": enemy().strength += int(action["value"])
    state["intent"] = int(state["intent"])+1
    if _outcome(): return
    _tick(enemy())
    if _outcome(): return
    if not active().alive():
        phase = REPLACE
        _pending = "player"
    else: _start_player()
func _start_player() -> void:
    phase = PLAYER
    _pending = ""
    turn += 1
    _grant_turn_energy()
    switch_bonus.clear()
    turn_flags.clear()
    turn_actors.clear()
    _turn_changed = false
    for pokemon: BattlePokemon in party: pokemon.block = 0
    if _ace_uid == active().uid:
        if has_relic("ace_focus"): _relic_stat("ace_focus")
        active().strength += 2*int(powers.get("ace",0))+(1 if has_relic("ace_focus") else 0)+(1 if active().held_item == "ace_band" else 0)
    _ace_uid = 0
    _draw(5)
    _record("turn","턴 %d · 에너지 %d" % [turn,energy])
func status_damage(pokemon: BattlePokemon, key: String) -> int:
    var bonus := int(powers.get("attrition",0)) if pokemon.uid < 0 and key in ["burn","poison","seed"] else 0
    return PokemonStats.scale(pokemon,2+bonus)
func _tick(pokemon: BattlePokemon) -> void:
    for key: String in ["burn","seed","poison","confusion"]:
        if not pokemon.alive() or not pokemon.statuses.has(key): continue
        var status: Dictionary = pokemon.statuses[key]
        status["turns"] = int(status["turns"])-1
        if int(status["turns"]) <= 0: pokemon.statuses.erase(key)
        var health_before := pokemon.hp
        _damage(pokemon,status_damage(pokemon,key),true)
        if key == "seed":
            var owner := member(int(status["source_uid"]))
            if owner != null and owner.alive():
                var recovered := mini(owner.max_hp-owner.hp,health_before-pokemon.hp)
                owner.hp += recovered
                _stat("healing",recovered)
    for key: String in ["sleep","paralysis","exposed"]:
        if pokemon.statuses.has(key):
            pokemon.statuses[key]["turns"] = int(pokemon.statuses[key]["turns"])-1
            if int(pokemon.statuses[key]["turns"]) <= 0: pokemon.statuses.erase(key)
func _damage(target: BattlePokemon, amount: int, piercing := false) -> void:
    var blocked := 0 if piercing else mini(target.block,maxi(0,amount))
    target.block -= blocked
    var lost := mini(target.hp,maxi(0,amount-blocked))
    target.hp -= lost
    _stat("damage_taken" if target.uid > 0 else "damage_dealt",lost)
    if target.uid > 0: _stat("shield_absorbed",blocked)
    _record("damage","%s · 피해 %d" % [target.display_name,lost],{"target":target.uid,"amount":lost,"blocked":blocked})
    if target.alive() or target.knocked_out: return
    target.knocked_out = true
    if target.uid < 0:
        if has_relic("seed_relay") and target.statuses.has("seed"): _relay = target.statuses["seed"].duplicate(true)
    else:
        _stat("knockouts")
        var injury := BattleCardInstance.new(_next_uid,"injury",0)
        _next_uid += 1
        injury.injury_owner_uid = target.uid
        discard.append(injury)
        for pile: Array in [hand,draw_pile,discard]:
            for card: BattleCardInstance in pile.duplicate():
                if card.owner_uid == target.uid:
                    pile.erase(card)
                    retained.erase(card.uid)
                    exhausted.append(card)
    target.statuses.clear()
    target.stat_stages.clear()
    _record("knockout",target.display_name+" 기절",{"target":target.uid})
func _outcome() -> bool:
    if phase in [WON,LOST]: return true
    if not party.any(func(pokemon: BattlePokemon): return pokemon.alive()):
        phase = LOST
        _clear_statuses()
        _record("outcome","전투 패배")
        return true
    if not enemy().alive():
        if enemy_index+1 < enemies.size():
            enemy_index += 1
            if not _relay.is_empty():
                enemy().statuses["seed"] = _relay.duplicate(true)
                _relay.clear()
                _record("relic","씨앗이 "+enemy().display_name+"에게 전이되었습니다.",{"relic_key":"seed_relay"})
            _record("enemy_switch",enemy().display_name+" 출전 · 턴과 남은 자원 유지")
        else:
            phase = WON
            _clear_statuses()
            _record("outcome","전투 승리")
            return true
    return false
func _clear_statuses() -> void:
    _relay.clear()
    for pokemon: BattlePokemon in party+enemies:
        pokemon.statuses.clear()
        pokemon.stat_stages.clear()
func member(uid: int) -> BattlePokemon:
    for pokemon: BattlePokemon in party:
        if pokemon.uid == uid: return pokemon
    return null
func _hand(uid: int) -> BattleCardInstance:
    for card: BattleCardInstance in hand:
        if card.uid == uid: return card
    return null
func _draw(count: int) -> void:
    for i in count:
        if hand.size() >= 10: break
        if draw_pile.is_empty():
            if not discard.is_empty(): _stat("reshuffles")
            draw_pile.append_array(discard)
            discard.clear()
            _shuffle(draw_pile)
        if draw_pile.is_empty(): break
        var card := draw_pile.pop_back() as BattleCardInstance
        var owner := member(card.owner_uid)
        if card.owner_uid != 0 and (owner == null or not owner.alive()):
            exhausted.append(card)
            continue
        hand.append(card)
        _stat("drawn")
func _shuffle(cards: Array[BattleCardInstance]) -> void:
    for i in range(cards.size()-1,0,-1):
        var j := _rng.randi_range(0,i)
        var card := cards[i]
        cards[i] = cards[j]
        cards[j] = card
func _stat(key: String, amount := 1) -> void:
    if statistics.is_empty(): statistics = RunStatistics.battle(true)
    RunStatistics.increment(statistics["counts"],key,amount)
func _relic_stat(key: String) -> void:
    if statistics.is_empty(): statistics = RunStatistics.battle(true)
    RunStatistics.increment(statistics["relics"],key)
func _record(kind: String, caption: String, data: Dictionary = {}) -> void:
    if kind == "relic" and data.has("relic_key"): _relic_stat(data["relic_key"])
    if kind == "heal" and int(data.get("target",0)) > 0: _stat("healing",int(data["amount"]))
    var event := data.duplicate(true)
    event["kind"] = kind
    event["text"] = caption
    event["frame"] = BattleFrame.capture(self)
    events.append(event)
    history.append(caption)
    if history.size() > 160: history.pop_front()
func snapshot() -> Dictionary:
    return JourneySnapshot.fields(self,JourneySnapshot.BATTLE_FIELDS).merged({"statistics":statistics.duplicate(true),"rng":_rng.state,"party":party.map(func(p: BattlePokemon): return p.snapshot()),"enemies":enemies.map(func(p: BattlePokemon): return p.snapshot()),"piles":[hand,draw_pile,discard,exhausted].map(func(pile: Array): return pile.map(func(card: BattleCardInstance): return [card.uid,card.key,card.owner_uid,card.upgraded]))})
func multiplier(attack: String, target: BattlePokemon) -> float:
    return TypeMatchup.multiplier(attack,target.types) if full_type_chart else BattleContent.multiplier(attack,target.type)
func notify_changed() -> String:
    changed.emit()
    return ""
