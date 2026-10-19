class_name TacticalBattle
extends RefCounted
signal changed
## Shared card combat. Rules finish atomically before animation or autosave.
const PLAYER := "player"
const REPLACE := "replace"
const WON := "won"
const LOST := "lost"
const MAX_BLOCK := 100000 # Existing v3 storage bound, also enforced during play.
var full_type_chart := false
var boss_context: Dictionary = {}
var player_moves_version:=1
var move_context:Dictionary={}
var technique_context:Dictionary={}
var exchange_context:Dictionary={}
var field_context:Dictionary={}
var seal_context:Dictionary={}
var altitude_context:Dictionary={}
var trap_context:Dictionary={}
var item_context:Dictionary={}
var assist_context:Dictionary={}
var fate_context:Dictionary={}
var reaction_context:Dictionary={}
var held_context:Dictionary={}
var held_attack:Dictionary={}
var turn_speed_inverted:=false # Cached at energy grant; a room may change later this turn.
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
var bulk_context: Dictionary = {}
var bulk_action: Dictionary = {}
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
    if BossBattleRules.modern(self):BossBattleEffectsP3.restore_items(self)
    if player_moves_version>=9:PlayerMoveItems.restore(self)
    if player_moves_version>=13:HeldItems.restore(self)
    if not exchange_context.is_empty():PlayerMoveExchange.clear(self)
    bulk_context.clear();bulk_action.clear()
    boss_context.clear()
    move_context.clear()
    technique_context.clear()
    field_context.clear()
    seal_context.clear()
    altitude_context.clear()
    trap_context.clear()
    item_context.clear()
    assist_context.clear()
    fate_context.clear()
    reaction_context.clear()
    held_context.clear()
    held_attack.clear();bulk_action.clear()
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
    if player_moves_version>=13:HeldItems.initialize(self)
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
    _draw(CoreRelics.draw_count(relics))
    _record("turn","턴 1 · 에너지 %d" % energy)
func active() -> BattlePokemon: return party[active_index]
func enemy() -> BattlePokemon: return enemies[enemy_index]
func opening() -> Dictionary: return enemy_states[enemy_index]
func has_relic(key: String) -> bool: return key in relics
func _grant_turn_energy() -> void:
    _stat("turns_started")
    turn_speed_actor = PokemonStats.effective(active(),"speed")
    turn_speed_enemy = PokemonStats.effective(enemy(),"speed")
    if player_moves_version>=5:
        turn_speed_actor=PlayerMoveFields.speed(self,active());turn_speed_enemy=PlayerMoveFields.speed(self,enemy())
    if player_moves_version>=13:
        turn_speed_actor=HeldItems.speed(self,active(),turn_speed_actor);turn_speed_enemy=HeldItems.speed(self,enemy(),turn_speed_enemy)
    if player_moves_version>=15:turn_speed_enemy=PlayerMoveBulk.speed(self,turn_speed_enemy)
    turn_speed_owner_uid = active().uid
    turn_speed_target_uid = enemy().uid
    turn_energy_bonus = 1 if turn_speed_actor > turn_speed_enemy else 0
    turn_speed_inverted=player_moves_version>=5 and PlayerMoveFields.read(self)["trick"]>0
    if turn_speed_inverted:turn_energy_bonus=1 if turn_speed_actor<turn_speed_enemy else 0
    energy = 3+turn_energy_bonus
func intent() -> Dictionary:
    return intent_for(active())
func intent_for(defender: BattlePokemon) -> Dictionary:
    var definitions: Array = enemy_definitions[enemy_index]["intents"]
    var result: Dictionary = definitions[int(opening()["intent"]) % definitions.size()].duplicate(true)
    if enemy_definitions[enemy_index].has("boss_moves_version"):
        var authored:=BossEffects.preview(self,defender,result)
        return PlayerTechniques.enemy_preview(self,defender,authored) if PlayerTechniques.active(self) else authored
    result["tactic"] = str(enemy_definitions[enemy_index].get("tactic",""))
    result["boss_style"] = str(enemy_definitions[enemy_index].get("boss_style",""))
    if result["kind"] in ["attack","charge","barrage"]:
        var move := TacticalMoves.definition(TacticalMoves.key_for(int(result["move_id"]))).duplicate(true)
        move["type"] = result.get("type",move.get("type","normal"))
        if player_moves_version>=12:move=PlayerMoveReactions.move_type(self,enemy(),move);result["type"]=move["type"]
        result["damage_class"] = move.get("damage_class","physical")
        var pressure := 0.55 if result["kind"] == "barrage" else (1.2 if result["kind"] == "charge" else 1.0)
        result["value"] = HeldItems.calculate(self,enemy(),defender,move,1.0 if int(result["move_id"]) == 165 else multiplier(move["type"],defender,int(result["move_id"])),0,pressure,BattleWeather.kind(powers))
        if result["kind"] == "barrage":
            result["per_hit"] = result["value"]
            result["value"] = int(result["per_hit"])*int(result["hits"])
    elif result["kind"] in ["block","fortify"]:
        result["value"] = PokemonStats.scale(enemy(),int(result["value"]))
        if result["kind"] == "fortify": result["stat_delta"] = mini(1,6-int(enemy().stat_stages.get(result["stat"],0)))
    elif result["kind"] == "recover": result["value"] = mini(enemy().max_hp-enemy().hp,PokemonStats.scale(enemy(),int(result["value"])))
    if enemy().statuses.has("sleep"): result["asleep"] = true
    return PlayerTechniques.enemy_preview(self,defender,result) if PlayerTechniques.active(self) else result
func card_view(card: BattleCardInstance) -> Dictionary:
    var view := TacticalContent.definition(card,player_moves_version)
    var actor := member(card.owner_uid) if card.owner_uid != 0 else active()
    view["owner_name"] = actor.display_name if card.owner_uid != 0 and actor != null else ""
    view["species_id"] = actor.species_id if card.owner_uid != 0 and actor != null else 0
    view["switches"] = card.owner_uid != 0 and actor != active()
    view["retained"] = card.uid in retained
    if actor != null:
        if PlayerTechniques.active(self):view=PlayerTechniques.prepare(self,actor,view)
        if actor.content_version >= 2 and card.owner_uid != 0 and view.has("move_id"):
            view["type"] = PokedexExpansion.move_type(actor.species_id,int(view["move_id"]),str(view.get("type","normal")))
        if player_moves_version>=12:view=PlayerMoveReactions.card_type(self,actor,view)
        if player_moves_version>=16:view=PlayerMoveInteractions.finalize(self,actor,view)
        if card.owner_uid == turn_speed_owner_uid and has_relic("ace_core") and not turn_flags.has("ace_core"):
            view["core_discount"] = mini(1,int(view["cost"]))
            view["cost"] = maxi(0,int(view["cost"])-1)
        if view["category"] == "tool" and has_relic("tool_discount") and not turn_flags.has("tool_discount"):
            view["tool_discount"] = mini(1,int(view["cost"]))
            view["cost"] = maxi(0,int(view["cost"])-1)
        if view.has("damage"): view["preview_damage"] = attack_damage(view,actor)
        if PlayerTechniques.active(self) and card.owner_uid!=0:PlayerMoveCards.after_preview(self,actor,view)
        if player_moves_version>=16:PlayerInteractionHooks.item_preview(self,actor,view)
        elif player_moves_version>=13:HeldItems.after_preview(self,actor,view)
        if player_moves_version>=15:PlayerMoveBulk.after_preview(self,actor,view)
        if view.has("shield_attack"): view["preview_damage"] = BossBattleRules.player_damage(self,view,actor.block)
        if view.has("double_block"): view["preview_block_gain"] = block_gain(actor,actor.block)
        if has_relic("status_flask") and not turn_flags.has("status_flask"):
            for status: String in ["burn","poison","seed"]:
                if view.has(status): view["preview_"+status] = int(view[status])+1
        if view.has("condition"): view["condition_active"] = BuildConceptRules.condition(self,actor,str(view["condition"]))
        if view.has("heal"): view["preview_heal"] = PokemonStats.scale(actor,int(view["heal"])+(6 if effective_item(actor) == "healing_bell" and view["category"] == "tool" else 0))
        if view.has("heal") and has_relic("shield_core"): view["preview_heal"] = maxi(1,floori(int(view["preview_heal"])*0.5))
        if view.has("block"): view["preview_block"] = mini(PokemonStats.scale(actor,int(view["block"]))+defense_bonus(actor),MAX_BLOCK-_block_on_entry(actor))
        if view.has("bonus"): view["preview_bonus"] = PokemonStats.scale(actor,int(view["bonus"]))
        view["description"] = TacticalContent.description(view)
        if BossBattleRules.active_in(self):
            var notice:=BossBattleRules.card_notice(self,view,actor)
            if not notice.is_empty():view["description"] += "\n"+notice
    return view
func attack_damage(view: Dictionary, actor: BattlePokemon) -> int:
    var switched_attack := int(switch_bonus.get(actor.uid,0))
    if actor != active() and has_relic("switch_power"): switched_attack = 3
    var bonus := next_attack_bonus+switched_attack
    if effective_item(actor) == "power_band": bonus += 3
    if enemy().statuses.has("exposed"): bonus += 2
    if view.get("omit_card_bonus",false):bonus-=next_attack_bonus+switched_attack
    var amount := PlayerTechniques.raw_damage(self,actor,enemy(),view,bonus) if PlayerTechniques.active(self) and view.get("category")=="technique" else PokemonStats.damage(actor,enemy(),view,1.0 if int(view.get("move_id",0)) == 165 else multiplier(view.get("type","normal"),enemy()),bonus,1.0,BattleWeather.kind(powers))
    if amount > 0 and view.get("category","technique") == "technique" and has_relic("status_core"): amount = maxi(1,floori(amount*0.8))
    if amount > 0 and BuildConceptRules.sight_active(self,view,actor): amount = maxi(1,floori(amount*1.25))
    if view.get("category","technique") == "technique" and turn_flags.get("finisher_%d" % actor.uid,false): amount *= 2
    return BossBattleRules.player_damage(self,PlayerMoveBulk.guard_view(view) if player_moves_version>=15 else view,amount)
func _block_on_entry(actor: BattlePokemon) -> int:
    if actor == active(): return actor.block
    var protection := actor.block+PokemonStats.scale(actor,3*int(powers.get("relay",0)))
    if effective_item(actor) == "relay_ribbon" and not turn_flags.has("ribbon_%d" % actor.uid): protection += PokemonStats.scale(actor,5)
    if has_relic("relay_cloak") and not turn_flags.has("relay_cloak"): protection += active().block
    return mini(MAX_BLOCK,protection)
func block_gain(actor: BattlePokemon,amount: int) -> int:
    return clampi(amount,0,maxi(0,MAX_BLOCK-actor.block))
func _gain_block(actor: BattlePokemon,amount: int) -> int:
    var gained := block_gain(actor,amount)
    actor.block += gained
    return gained
func effective_item(actor:BattlePokemon) -> String:
    return "" if (player_moves_version>=6 and PlayerMoveSeals.read(self)["magic"]>0) or (player_moves_version>=9 and PlayerMoveItems.suppressed(self,actor)) else actor.held_item
func defense_bonus(actor: BattlePokemon) -> int:
    return (PokemonStats.scale(actor,4) if effective_item(actor) == "guard_charm" else 0)+(PokemonStats.scale(actor,3) if has_relic("shield_pad") and not turn_flags.has("shield_pad") else 0)
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
        if BossEffects.active_in(self) and actor.statuses.has("sleep") and not (PlayerTechniques.active(self) and int(TacticalMoves.definition(card.key)["move_id"])==214): return "수면 중인 포켓몬은 이번 턴 기술을 쓸 수 없습니다. 다른 동료의 기술이나 도구를 사용하세요."
    if BossBattleRules.active_in(self) and card.owner_uid != 0:
        var actor:=member(card.owner_uid)
        if BossBattleRules.read(self)["gravity"]>0 and BossBattleRules.flag(int(TacticalContent.definition(card).get("move_id",0)),10):return "중력 중에는 공중 기술을 사용할 수 없습니다."
        if actor!=active():
            if PlayerTechniques.active(self) and PlayerMoveRules.rooted(self):return "뿌리박기 중에는 기술 카드로 교대할 수 없습니다."
            if BossBattleRules.trapped(self):return "구속 중에는 기술 카드로 자동 교대할 수 없습니다."
            if BossBattleRules.entry_damage(self,actor)>=actor.hp:return "스텔스록 입장 피해로 기절해 기술을 쓸 수 없습니다. 다른 동료를 선택하세요."
    if BossBattleRules.modern(self):
        var actor:=member(card.owner_uid) if card.owner_uid!=0 else active()
        var why:=PlayerInteractionHooks.boss_card_reason(self,card_view(card),actor) if player_moves_version>=16 else BossBattleEffectsP3.card_reason(self,card_view(card),actor)
        if not why.is_empty():return why
    if PlayerTechniques.active(self):
        if card.owner_uid!=0 and member(card.owner_uid)!=active() and PlayerMoveRules.rooted(self):return "뿌리박기 중에는 기술 카드로 교대할 수 없습니다."
        var why:=PlayerTechniques.reason(self,member(card.owner_uid) if card.owner_uid!=0 else active(),card_view(card))
        if not why.is_empty():return why
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
    if player_moves_version>=13:HeldItems.begin_action(self,actor,target,view)
    if BossBattleRules.active_in(self):
        BossBattleRules.on_card(self,view,actor)
        view=BossBattleRules.filter_view(self,view)
    if PlayerTechniques.active(self) and card.owner_uid!=0:PlayerTechniques.on_card(self,view,actor,target)
    if view["category"] == "tool" and has_relic("tool_discount") and not turn_flags.has("tool_discount"):
        turn_flags["tool_discount"] = true
        if int(view.get("tool_discount",0)) > 0: BuildConceptRules.relic(self,"tool_discount","정밀 공구 · 도구 비용 -1")
    _record("skill" if card.owner_uid != 0 else "card",("%s · " % actor.display_name if card.owner_uid != 0 else "")+str(view["name"]),{"move_id":view["move_id"],"actor":actor.uid,"card_uid":card.uid})
    if card.owner_uid == turn_speed_owner_uid and has_relic("ace_core") and not turn_flags.has("ace_core"):
        turn_flags["ace_core"] = true
        if int(view.get("core_discount",0)) > 0: _record("relic","고정 조준경 · 기술 비용 -1",{"relic_key":"ace_core"})
    if view.has("damage"):
        var amount := attack_damage(view,actor)
        var hit_values:Array[int]=[]
        if PlayerTechniques.active(self) and card.owner_uid!=0:hit_values=PlayerMoveCards.damage_values(self,view,actor)
        if BuildConceptRules.sight_active(self,view,actor):
            turn_flags["ace_sight"] = true
            BuildConceptRules.relic(self,"ace_sight","에이스 조준기 · 첫 공격 기술 +25%")
        next_attack_bonus = 0
        switch_bonus.erase(actor.uid)
        if card.owner_uid != 0: turn_flags.erase("finisher_%d" % actor.uid)
        if player_moves_version>=16 and card.owner_uid!=0:PlayerInteractionHooks.player_hits(self,view,actor,target,hit_values)
        elif player_moves_version>=13 and card.owner_uid!=0:HeldItems.deal_damage(self,view,actor,target,hit_values)
        elif PlayerTechniques.active(self) and card.owner_uid!=0:PlayerMoveRules.deal_damage(self,view,actor,target,hit_values)
        else:_damage(target,amount,false,str(view.get("damage_class","physical")),BossBattleRules.flag(int(view["move_id"]),9) or BossBattleRules.flag(int(view["move_id"]),14) if BossBattleRules.active_in(self) else false)
    if view.has("shield_attack"):
        var amount := actor.block
        actor.block = 0
        _record("shield_spent",actor.display_name+" 보호막 소비",{"target":actor.uid,"amount":amount})
        _damage(target,0 if view.get("boss_blocked",false) else amount,false,"physical")
    if target.alive():
        var fresh := false
        var fresh_dot := false
        var extend := has_relic("status_flask") and not turn_flags.has("status_flask") and ["burn","poison","seed"].any(func(key: String): return view.has(key))
        for status: String in ["burn","seed","poison","sleep","paralysis","confusion"]:
            if view.has(status):
                fresh = fresh or not target.statuses.has(status)
                if status in ["burn","poison","seed"] and not target.statuses.has(status): fresh_dot = true
                target.statuses[status] = {"turns":int(view[status])+(1 if extend and status in ["burn","poison","seed"] else 0),"source_uid":actor.uid}
        if extend:
            turn_flags["status_flask"] = true
            _record("relic","잔류 시약 · 지속 횟수 +1",{"relic_key":"status_flask"})
        if fresh and has_relic("status_lens") and not turn_flags.has("status_lens"):
            turn_flags["status_lens"] = true
            energy += 1
            _record("relic","상태 관측경 · 에너지 +1",{"relic_key":"status_lens"})
        if fresh_dot and has_relic("status_dish") and not turn_flags.has("status_dish") and ["burn","poison","seed"].filter(func(key: String): return target.statuses.has(key)).size() >= 2:
            turn_flags["status_dish"] = true
            _draw(2)
            _record("relic","배양 접시 · 카드 2장",{"relic_key":"status_dish"})
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
        var protection := _gain_block(actor,PokemonStats.scale(actor,int(view["block"]))+defense_bonus(actor))
        _record("shield",actor.display_name+" 보호막",{"target":actor.uid,"amount":protection})
        if protection > 0 and has_relic("shield_pad") and not turn_flags.has("shield_pad"):
            turn_flags["shield_pad"] = true
            BuildConceptRules.relic(self,"shield_pad","완충 패드 · 첫 보호막 카드 추가 보호")
    if view.has("double_block"):
        var protection := _gain_block(actor,actor.block)
        if protection > 0: _record("shield","방벽 압축",{"target":actor.uid,"amount":protection})
    if view.has("finisher"):
        turn_flags["finisher_%d" % actor.uid] = true
        _record("status",actor.display_name+" · 이번 턴 다음 공격 기술 2배",{"target":actor.uid})
    if view.has("pulse_status"):
        for status: String in ["burn","seed","poison"]:
            if target.alive() and target.statuses.has(status): _status_hit(target,status,target.statuses[status])
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
    if view.has("weather"): BattleWeather.apply(self,str(view["weather"]))
    BuildConceptRules.apply(self,view,actor,target)
    if view.has("retain") and not hand.is_empty():
        var candidates: Array[BattleCardInstance] = []
        for candidate: BattleCardInstance in hand:
            if candidate.uid not in retained: candidates.append(candidate)
        candidates.sort_custom(func(a: BattleCardInstance,b: BattleCardInstance): return int(card_view(a)["cost"]) > int(card_view(b)["cost"]))
        for i in mini(int(view.get("retain_count",1)),candidates.size()): retained.append(candidates[i].uid)
    if view.has("retrieve"):
        var returned := 0
        for candidate: BattleCardInstance in _retrieval_candidates(view,actor):
            if hand.size() >= 10 or returned >= int(view.get("retrieve_count",1)): break
            discard.erase(candidate)
            hand.append(candidate)
            returned += 1
        if returned > 0: _record("cards_returned","기술 %d장 회수" % returned,{"amount":returned})
    if view.has("redraw"):
        var count := hand.size()
        discard.append_array(hand)
        hand.clear()
        retained.clear()
        _draw(count+int(view.get("redraw_bonus",0)))
    if view.has("draw"): _draw(int(view["draw"]))
    if view.get("condition_active",false) and view.has("conditional_draw"): _draw(int(view["conditional_draw"]))
    if card.owner_uid != 0:
        BuildConceptRules.technique(self,actor)
        var first_technique := "technique_%d" % actor.uid
        if turn_flags.has(first_technique):
            if turn_flags.has("double_technique_%d" % actor.uid) and has_relic("ace_medal") and not turn_flags.has("ace_medal"):
                turn_flags["ace_medal"] = true
                energy += 1
                _record("relic","돌파 훈장 · 에너지 +1",{"relic_key":"ace_medal"})
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
        var supplied := _gain_block(actor,PokemonStats.scale(actor,5*int(powers.get("supply",0))))
        if supplied > 0: _record("shield","보급 작전",{"target":actor.uid,"amount":supplied})
        if has_relic("tool_belt") and not turn_flags.has("tool_belt"):
            turn_flags["tool_belt"] = true
            _draw(1)
            _record("relic","보급 벨트 · 카드 1장",{"relic_key":"tool_belt"})
        if view.get("exhaust",false) and has_relic("supply_core") and not turn_flags.has("supply_core"):
            turn_flags["supply_core"] = true
            energy += 1
            _draw(2)
            _record("relic","비상 보급함 · 에너지 +1 · 카드 2장",{"relic_key":"supply_core"})
    if PlayerTechniques.active(self) and card.owner_uid!=0:PlayerTechniques.after_card(self,view,actor,target)
    var contact_stages:=actor.stat_stages.duplicate() if player_moves_version>=5 else {}
    if BossBattleRules.active_in(self):BossBattleRules.after_card(self,view,actor)
    if player_moves_version>=5:PlayerMoveFields.prevent_drops(self,actor,contact_stages)
    BuildConceptRules.after_card(self,view,actor)
    if PlayerTechniques.active(self) and card.owner_uid!=0:PlayerMoveRules.finish_card(self,view,actor)
    if BossBattleRules.modern(self):BossBattleEffectsP3.finish_card(self)
    if PlayerTechniques.active(self) and view.get("preparing",false):
        hand.append(card);retained.append(card.uid)
    elif view.get("exhaust",false) or view.has("power"): exhausted.append(card)
    else: discard.append(card)
    if PlayerTechniques.active(self):PlayerMoveRules.clean_charges(self)
    held_attack.clear();bulk_action.clear()
    _outcome()
    if (BossBattleRules.modern(self) or PlayerTechniques.active(self)) and phase==PLAYER and not active().alive():
        phase=REPLACE
        _pending="card"
    return notify_changed()
func _retrieval_candidates(view: Dictionary,actor: BattlePokemon) -> Array[BattleCardInstance]:
    var result: Array[BattleCardInstance] = []
    for i in range(discard.size()-1,-1,-1):
        var card := discard[i]
        var owner := member(card.owner_uid)
        if owner == null or not owner.alive(): continue
        if view.get("retrieve_scope","") == "reserve" and owner == actor: continue
        if view.get("retrieve_scope","") == "active" and owner != actor: continue
        result.append(card)
    return result

func _change_active(uid: int, technique := false) -> void:
    if uid == active().uid: return
    var old := active()
    var inherited := 0
    if technique and has_relic("relay_cloak") and not turn_flags.has("relay_cloak"):
        turn_flags["relay_cloak"] = true
        inherited = old.block
        old.block = 0
        if inherited > 0: _record("shield_spent",old.display_name+" · 보호막 인계",{"target":old.uid,"amount":inherited})
    old.strength -= int(temporary_strength.get(old.uid,0))
    temporary_strength.erase(old.uid)
    old.stat_stages.clear()
    for i in party.size():
        if party[i].uid == uid: active_index = i
    _turn_changed = true
    if technique:
        turn_flags["technique_switch"] = true
        _gain_block(active(),PokemonStats.scale(active(),3*int(powers.get("relay",0))))
        _stat("auto_switches")
        if has_relic("switch_power"):
            switch_bonus[uid] = 3
            _relic_stat("switch_power")
    var ribbon := "ribbon_%d" % uid
    if effective_item(active()) == "relay_ribbon" and not turn_flags.has(ribbon):
        turn_flags[ribbon] = true
        _gain_block(active(),PokemonStats.scale(active(),5))
    _record("switch",active().display_name+" 출전",{"actor":uid})
    if inherited > 0:
        var received := _gain_block(active(),inherited)
        _record("shield","인계 망토 · 보호막 인수",{"target":uid,"amount":received})
        _record("relic","인계 망토 · 보호막 이동",{"relic_key":"relay_cloak"})
    if technique and has_relic("relay_core") and not turn_flags.has("relay_core"):
        turn_flags["relay_core"] = true
        _draw(2)
        _record("relic","순환 엔진 · 카드 2장",{"relic_key":"relay_core"})
    if technique and has_relic("relay_cell") and not turn_flags.has("relay_cell"):
        turn_flags["relay_cell"] = true
        energy += 1
        _record("relic","릴레이 발전기 · 에너지 +1",{"relic_key":"relay_cell"})
    BuildConceptRules.after_switch(self,technique)
    if BossBattleRules.active_in(self):BossBattleRules.on_switch(self,old.uid)
    if PlayerTechniques.active(self):PlayerTechniques.on_switch(self,old.uid)
func switch_reason(uid: int) -> String:
    if phase not in [PLAYER,REPLACE]: return "전투가 끝났습니다."
    var pokemon := member(uid)
    if pokemon == null or not pokemon.alive() or pokemon == active(): return "살아 있는 대기 포켓몬을 선택하세요."
    if phase==PLAYER and PlayerTechniques.active(self) and PlayerMoveRules.rooted(self):return "뿌리박기 중에는 교대할 수 없습니다."
    if phase == PLAYER and BossBattleRules.active_in(self) and BossBattleRules.trapped(self):return "구속 중에는 교대할 수 없습니다. 상대의 기절/구속 해제를 기다리세요."
    if phase==PLAYER and player_moves_version>=8 and PlayerMoveTraps.blocked(self,active()):return "구속 중에는 교대할 수 없습니다. 시전자 이탈/기절 또는 강제 교대를 기다리세요."
    if phase==PLAYER and player_moves_version>=6 and PlayerMoveSeals.locked(self,active()):return "페어리록 중에는 교대할 수 없습니다."
    if phase == PLAYER and energy < manual_switch_cost(): return "수동 교대에는 에너지 %d이 필요합니다. 기술 카드는 무료로 교대합니다." % manual_switch_cost()
    return ""
func manual_switch_cost() -> int:
    if PlayerTechniques.active(self) and PlayerMoveRules.pivot_free(self):return 0
    var base := 2 if has_relic("ace_core") else 1
    return maxi(0,base-1) if has_relic("manual_pin") and not turn_flags.has("manual_pin") else base
func switch_to(uid: int) -> String:
    var reason := switch_reason(uid)
    if not reason.is_empty(): return reason
    events.clear()
    var forced := phase == REPLACE
    if not forced:
        energy -= manual_switch_cost()
        _stat("energy_spent",manual_switch_cost())
    if not forced and has_relic("manual_pin") and not turn_flags.has("manual_pin"):
        turn_flags["manual_pin"] = true
        BuildConceptRules.relic(self,"manual_pin","안전 교대핀 · 직접 교대 비용 -1")
    _stat("forced_switches" if forced else "manual_switches")
    _change_active(uid)
    if not active().alive():
        if _outcome():return notify_changed()
        phase=REPLACE
        if not forced:_pending="hazard"
        return notify_changed()
    if forced:
        if _pending in ["hazard","card"]:phase=PLAYER;_pending=""
        elif _pending == "enemy": _enemy_action()
        else: _start_player()
    return notify_changed()
func capture_reason() -> String:
    if phase != PLAYER: return "지금은 포획할 수 없습니다."
    if energy < 1: return "포획에는 에너지 1이 필요합니다."
    if enemy().hp*4 > enemy().max_hp: return "체력을 25% 이하로 낮추세요."
    return ""
func capture_enemy(energy_cost: int = 1) -> String:
    var reason := capture_reason()
    if not reason.is_empty(): return reason
    if energy_cost not in [1,2,3] or energy < energy_cost: return "포획 에너지가 부족합니다."
    events.clear()
    energy -= energy_cost
    _stat("energy_spent",energy_cost)
    _stat("captures")
    var target := enemy()
    target.hp = 0
    target.knocked_out = true
    if player_moves_version>=11:PlayerMoveFate.on_knockout(self,target.uid)
    if player_moves_version>=12:PlayerMoveReactions.on_switch(self,target.uid)
    target.statuses.clear()
    opening()["captured"] = true
    if BossBattleRules.modern(self):BossBattleEffectsP3.source_left(self,target.uid)
    _relay.clear()
    _record("capture",target.display_name+" 포획 성공!",{"species_id":target.species_id})
    _outcome()
    return ""
func end_turn() -> String:
    if phase != PLAYER: return "현재 턴을 종료할 수 없습니다."
    events.clear()
    BuildConceptRules.end_turn(self)
    _stat("unused_energy",energy)
    _ace_uid = active().uid if not _turn_changed else 0
    for card: BattleCardInstance in hand.duplicate():
        if card.uid not in retained and not (PlayerTechniques.active(self) and PlayerMoveRules.keep_charge(self,card.uid)):
            hand.erase(card)
            discard.append(card)
    retained.clear()
    if player_moves_version>=3:PlayerMoveTactics.end_player(self)
    phase = "enemy"
    for pokemon: BattlePokemon in party:
        if pokemon.alive() and effective_item(pokemon) == "seed_charm" and ["burn","seed","poison"].any(func(key: String): return enemy().statuses.has(key)):
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
    var weather_foe := enemy()
    var state := opening()
    if BossBattleRules.active_in(self):BossBattleRules.begin_enemy(self)
    var action := intent()
    var enemy_hp_before:=weather_foe.hp
    var player_actor:=active()
    var player_status:=player_actor.statuses.duplicate(true)
    var foe_status:=weather_foe.statuses.duplicate(true) if player_moves_version>=5 else {}
    var player_stages:=player_actor.stat_stages.duplicate()
    var bulk_foe_stages:=weather_foe.stat_stages.duplicate() if player_moves_version>=15 else {}
    var player_marks:=boss_context.duplicate(true)
    var player_sub:bool=PlayerTechniques.active(self) and PlayerMoveRules.read(self)["substitutes"].get(player_actor.uid,0)>0
    if player_moves_version>=13:HeldItems.begin_action(self,weather_foe,player_actor,action)
    var p1: bool = enemy_definitions[enemy_index].get("boss_moves_version") in [2,3,4]
    if PlayerTechniques.active(self) and (action.get("player_sealed",false) or action.has("support_cancel")):
        _record("cancel",str(action.get("support_cancel","봉인 효과 · 상대 기술 사용 불가")))
        for key:String in ["effects_v4","effects_v3","effects_v2"]:
            if state.has(key):state[key].merge({"charge":0,"recharge":false,"lock":0,"lock_left":0},true)
        if state.has("effects_v4"):
            state["effects_v4"]["actions"]+=1;state["effects_v4"]["last_failed"]=true;state["effects_v4"]["air_cancel"]=false
    elif player_moves_version>=15 and action.has("bulk_cancel"):PlayerMoveBulk.cancel_enemy(self,action)
    elif player_moves_version>=12 and action.get("powdered",false):PlayerMoveReactions.explode(self,action)
    elif PlayerTechniques.active(self) and action.get("player_guarded",false) and not enemy_definitions[enemy_index].has("boss_moves_version") and action["kind"]=="status":
        _record("cancel","보호 기술 · 상대 상태 효과 차단")
    elif enemy_definitions[enemy_index].get("boss_moves_version") == 4:
        var resolved:=action.duplicate(true)
        if action.get("player_stop_switch",false):resolved["immune"]=true
        if player_moves_version>=13:HeldItemMath.boss_execute(self,resolved)
        else:BossMoveEffectsP3.execute(self,resolved)
    elif enemy_definitions[enemy_index].get("boss_moves_version") == 3:
        BossMoveEffectsP2.execute(self,action)
    elif p1:
        BossMoveEffectsP1.execute(self,action)
    elif enemy().statuses.has("sleep"):
        _record("cancel",enemy().display_name+"은 잠들어 행동할 수 없습니다.")
    elif enemy_definitions[enemy_index].has("boss_moves_version"):
        BossMoveEffects.execute(self,action)
    else:
        var titles := {"block":"방어","boost":"위력 강화","fortify":"방벽","recover":"회복","status":"상태 지시"}
        var title: String = str(TacticalMoves.visual(int(action["move_id"]))["name"]) if action["kind"] in ["attack","charge","barrage"] else titles[action["kind"]]
        _record("enemy_action",enemy().display_name+" · "+title,action.merged({"action":action["kind"]}))
        match action["kind"]:
            "attack","charge","barrage":
                for hit in (int(action["hits"]) if action["kind"] == "barrage" else 1):
                    if not active().alive() or (player_moves_version>=13 and not weather_foe.alive()): break
                    if hit > 0: _record("enemy_hit",enemy().display_name+" · 연속 공격",action.merged({"action":"barrage"}))
                    _damage(active(),int(action["per_hit"] if action["kind"] == "barrage" else action["value"]))
            "block","fortify":
                if action["kind"] == "fortify":
                    var stat: String = action["stat"]
                    enemy().stat_stages[stat] = int(enemy().stat_stages.get(stat,0))+int(action["stat_delta"])
                    _record("stat",enemy().display_name+" · "+str(PokemonStats.TITLES[stat])+" 강화",{"target":enemy().uid})
                enemy().block = int(action["value"])
                _record("shield",enemy().display_name+" 보호막",{"target":enemy().uid,"amount":int(action["value"])})
            "boost": enemy().strength += int(action["value"])
            "recover":
                enemy().hp += int(action["value"])
                _record("heal",enemy().display_name+" 회복",{"target":enemy().uid,"amount":int(action["value"])})
            "status":
                active().statuses[action["status"]] = {"turns":int(action["value"]),"source_uid":enemy().uid}
                _record("status",active().display_name+" · "+str({"burn":"화상","poison":"독","seed":"씨뿌리기"}[action["status"]]),{"target":active().uid})
    if player_moves_version>=13:HeldItems.after_enemy_action(self,player_actor,weather_foe,player_stages)
    held_attack.clear();bulk_action.clear()
    if player_moves_version>=3:PlayerMoveTactics.limit_healing(self,weather_foe,enemy_hp_before)
    if PlayerTechniques.active(self):PlayerMoveRules.finish_enemy_hit(self)
    state["intent"] = int(state["intent"])+(int(action.get("advance",1)) if p1 and not action.get("asleep",false) else 1)
    if _outcome(): return
    _tick(weather_foe if p1 else enemy())
    if _outcome(): return
    var end_hp_before:=weather_foe.hp
    if BossBattleRules.active_in(self):BossBattleRules.end_enemy(self,weather_foe)
    if player_moves_version>=3:PlayerMoveTactics.limit_healing(self,weather_foe,end_hp_before)
    var contact_foe_stages:=weather_foe.stat_stages.duplicate() if player_moves_version>=5 else {}
    if player_moves_version>=7:PlayerMoveAltitude.synchronize(self,player_actor,action)
    var saved_air:Dictionary=PlayerMoveTraps.air_charge(self,player_actor,action) if player_moves_version>=8 else {}
    if player_moves_version>=16:PlayerInteractionHooks.player_after_enemy(self,weather_foe,player_actor,action,player_status,player_sub,player_stages,player_marks)
    elif PlayerTechniques.active(self):PlayerMoveRules.after_enemy(self,weather_foe,player_actor,action,player_status,player_sub,player_stages,player_marks)
    if not saved_air.is_empty() and player_actor.alive() and player_actor==active():PlayerMoveRules.write(self)["charges"][player_actor.uid]=saved_air
    if player_moves_version>=8:PlayerMoveTraps.after_enemy(self,weather_foe,player_actor,action,player_sub)
    if player_moves_version>=9:PlayerMoveItems.after_enemy(self,player_actor,action,player_sub)
    if player_moves_version>=3:PlayerMoveTactics.after_enemy(self,weather_foe,action,end_hp_before)
    if player_moves_version>=4:PlayerMoveExchange.after_enemy(self,weather_foe,action)
    if player_moves_version>=5:
        PlayerMoveFields.prevent_drops(self,weather_foe,contact_foe_stages)
        if player_moves_version>=7:
            PlayerMoveAirFields.after_enemy(self,weather_foe,player_actor,action,player_status,foe_status,player_stages)
            PlayerMoveAltitude.after_enemy(self)
        else:PlayerMoveFields.after_enemy(self,weather_foe,player_actor,action,player_status,foe_status,player_stages)
    if player_moves_version>=6:PlayerMoveSeals.after_enemy(self)
    if player_moves_version>=10:PlayerMoveAssist.after_enemy(self)
    BattleWeather.end_round(self,weather_foe)
    if player_moves_version>=13:HeldItems.end_round(self,weather_foe)
    if player_moves_version>=11:PlayerMoveFate.after_enemy(self)
    if player_moves_version>=12:PlayerMoveReactions.after_enemy(self)
    if player_moves_version>=16:PlayerInteractionHooks.bulk_after_enemy(self,weather_foe,player_actor,action,bulk_foe_stages)
    elif player_moves_version>=15:PlayerMoveBulk.after_enemy(self,weather_foe,player_actor,action,bulk_foe_stages)
    if _outcome(): return
    if not active().alive():
        phase = REPLACE
        _pending = "player"
    else: _start_player()
func _start_player() -> void:
    var charged := has_relic("shield_battery") and bool(turn_flags.get("shield_battery",false))
    var previous_flags := turn_flags.duplicate(true)
    var stayed := _ace_uid == active().uid
    phase = PLAYER
    _pending = ""
    turn += 1
    if player_moves_version>=4:PlayerMoveExchange.start_player(self)
    _grant_turn_energy()
    switch_bonus.clear()
    turn_flags.clear()
    turn_actors.clear()
    _turn_changed = false
    var core_preserved := false
    for pokemon: BattlePokemon in party:
        if pokemon.alive() and previous_flags.get("keep_block_%d" % pokemon.uid,false): continue
        pokemon.block = floori(pokemon.block*0.5) if has_relic("shield_core") and pokemon.alive() else 0
        core_preserved = core_preserved or pokemon.block > 0
    if core_preserved: _record("relic","잔류 방벽 · 보호막 절반 보존",{"relic_key":"shield_core"})
    if _ace_uid == active().uid:
        if has_relic("ace_focus"): _relic_stat("ace_focus")
        active().strength += 2*int(powers.get("ace",0))+(1 if has_relic("ace_focus") else 0)+(1 if effective_item(active()) == "ace_band" else 0)
    _ace_uid = 0
    _draw(CoreRelics.draw_count(relics))
    _record("turn","턴 %d · 에너지 %d" % [turn,energy])
    if charged:
        energy += 1
        _record("relic","축전 방패 · 에너지 +1",{"relic_key":"shield_battery"})
    BuildConceptRules.start_turn(self,previous_flags,stayed)
    if PlayerTechniques.active(self):PlayerMoveRules.start_player(self)
func status_damage(pokemon: BattlePokemon, key: String) -> int:
    var bonus := int(powers.get("attrition",0)) if pokemon.uid < 0 and key in ["burn","poison","seed"] else 0
    var amount := PokemonStats.scale(pokemon,2+bonus)
    return floori(amount*1.5) if pokemon.uid < 0 and key in ["burn","poison","seed"] and has_relic("status_core") else amount
func _tick(pokemon: BattlePokemon) -> void:
    if player_moves_version>=11:PlayerMoveFate.tick(self,pokemon)
    var field_status_before:=pokemon.statuses.duplicate(true) if player_moves_version>=5 else {}
    for key: String in ["burn","seed","poison","confusion"]:
        if not pokemon.alive() or not pokemon.statuses.has(key): continue
        var status: Dictionary = pokemon.statuses[key]
        status["turns"] = int(status["turns"])-1
        var expired := int(status["turns"]) <= 0
        if expired: pokemon.statuses.erase(key)
        _status_hit(pokemon,key,status)
        if expired: BuildConceptRules.expired(self,pokemon,key)
    for key: String in ["sleep","paralysis","exposed"]:
        if pokemon.statuses.has(key):
            pokemon.statuses[key]["turns"] = int(pokemon.statuses[key]["turns"])-1
            if int(pokemon.statuses[key]["turns"]) <= 0: pokemon.statuses.erase(key)
    if BossBattleRules.active_in(self):BossBattleRules.tick_trap(self,pokemon)
    if player_moves_version>=7:PlayerMoveAirFields.prevent_status(self,pokemon,field_status_before)
    elif player_moves_version>=5:PlayerMoveFields.prevent_status(self,pokemon,field_status_before)
    if PlayerTechniques.active(self) and pokemon.uid>0:PlayerMoveRules.end_player(self,pokemon)
func _status_hit(pokemon: BattlePokemon,key: String,status: Dictionary) -> void:
    var health_before := pokemon.hp
    if pokemon.uid < 0 and key in ["burn","seed","poison"] and has_relic("status_core"): _record("relic","침식 촉매 · 지속 피해 +50%",{"relic_key":"status_core"})
    _damage(pokemon,status_damage(pokemon,key),true)
    BuildConceptRules.status_hit(self,pokemon,key,health_before-pokemon.hp)
    if key == "seed":
        var owner := member(int(status["source_uid"]))
        if owner == null:
            for foe: BattlePokemon in enemies:
                if foe.uid == int(status["source_uid"]): owner = foe
        if owner != null and owner.alive():
            var recovered := mini(owner.max_hp-owner.hp,health_before-pokemon.hp)
            owner.hp += recovered
            if recovered > 0: _record("heal","씨앗 흡수 · "+owner.display_name,{"target":owner.uid,"amount":recovered})
func _damage(target: BattlePokemon, amount: int, piercing := false,damage_class := "",bypass_substitute := false) -> void:
    var interaction_target:bool=player_moves_version>=16 and not held_attack.is_empty() and int(held_attack.get("target",0))==target.uid
    var guard_bypass:bool=interaction_target and PlayerMoveInteractions.bypasses_guard(PlayerMoveInteractions.move_id(held_attack["view"]))
    if interaction_target and not piercing and PlayerMoveInteractions.bypasses_sub(held_attack["view"]):bypass_substitute=true
    if PlayerTechniques.active(self) and target.uid>0 and phase=="enemy" and not piercing and not guard_bypass and PlayerMoveRules.guard(self,target) not in ["","endure"]:amount=0
    var blocked := 0 if piercing else mini(target.block,maxi(0,amount))
    target.block -= blocked
    var lost := mini(target.hp,maxi(0,amount-blocked))
    if BossBattleRules.active_in(self):lost=BossBattleRules.absorb(self,target,lost,piercing,bypass_substitute)
    if player_moves_version>=16:lost=PlayerInteractionHooks.player_absorb(self,target,lost,piercing,bypass_substitute)
    elif PlayerTechniques.active(self):lost=PlayerMoveRules.absorb(self,target,lost,piercing,bypass_substitute)
    if player_moves_version>=15 and not piercing and target.uid<0 and held_attack.get("view",{}).get("bulk_rule")=="false_swipe":lost=mini(lost,maxi(0,target.hp-1))
    if player_moves_version>=13:lost=HeldItems.cap_damage(self,target,lost,piercing)
    target.hp -= lost
    if PlayerTechniques.active(self):
        var kind:=damage_class
        if target.uid>0 and phase=="enemy" and kind.is_empty() and not piercing:kind=str(intent().get("damage_class","physical"))
        PlayerMoveRules.track(self,target,lost,kind)
    if BossBattleRules.active_in(self):BossBattleRules.track(self,target,lost,damage_class)
    _stat("damage_taken" if target.uid > 0 else "damage_dealt",lost)
    if target.uid > 0: _stat("shield_absorbed",blocked)
    _record("damage","%s · 피해 %d" % [target.display_name,lost],{"target":target.uid,"amount":lost,"blocked":blocked})
    if phase == "enemy" and target.uid > 0 and blocked > 0 and lost == 0 and has_relic("shield_battery") and not turn_flags.has("shield_battery"):
        turn_flags["shield_battery"] = true
        _record("status","축전 방패 충전 · 다음 아군 턴 에너지 +1",{"target":target.uid})
    BuildConceptRules.full_guard(self,target,blocked,lost)
    if player_moves_version>=16:PlayerInteractionHooks.held_damage(self,target,lost,piercing,amount-blocked>0)
    elif player_moves_version>=13:HeldItems.on_damage(self,target,lost,piercing,amount-blocked>0)
    if player_moves_version>=15:PlayerMoveBulk.on_damage(self,target,lost,piercing)
    if target.alive() or target.knocked_out: return
    if player_moves_version>=15:PlayerMoveBulk.on_knockout(self,target)
    target.knocked_out = true
    if player_moves_version>=11:PlayerMoveFate.on_knockout(self,target.uid)
    if player_moves_version>=12:PlayerMoveReactions.on_switch(self,target.uid)
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
            if player_moves_version>=3:
                _record("enemy_switch",enemy().display_name+" 출전 · 턴과 남은 자원 유지")
                var entry_status:=enemy().statuses.duplicate(true) if player_moves_version>=5 else {}
                if player_moves_version>=7:PlayerMoveAltitude.enter_enemy(self)
                else:PlayerMoveTactics.enter_enemy(self)
                if player_moves_version>=7:PlayerMoveAirFields.prevent_status(self,enemy(),entry_status)
                elif player_moves_version>=5:PlayerMoveFields.prevent_status(self,enemy(),entry_status)
                if not enemy().alive():return _outcome()
            else:_record("enemy_switch",enemy().display_name+" 출전 · 턴과 남은 자원 유지")
        else:
            phase = WON
            _clear_statuses()
            _record("outcome","전투 승리")
            return true
    return false
func _clear_statuses() -> void:
    if BossBattleRules.modern(self):BossBattleEffectsP3.restore_items(self)
    if player_moves_version>=9:PlayerMoveItems.restore(self)
    if player_moves_version>=13:HeldItems.restore(self)
    if not exchange_context.is_empty():PlayerMoveExchange.clear(self)
    bulk_context.clear();bulk_action.clear()
    boss_context.clear()
    move_context.clear()
    technique_context.clear()
    field_context.clear()
    seal_context.clear()
    altitude_context.clear()
    trap_context.clear()
    item_context.clear()
    assist_context.clear()
    fate_context.clear()
    reaction_context.clear()
    held_context.clear()
    held_attack.clear();bulk_action.clear()
    BattleWeather.clear(powers)
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
            if not draw_pile.is_empty(): BuildConceptRules.reshuffle(self)
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
    var state := JourneySnapshot.fields(self,JourneySnapshot.BATTLE_FIELDS).merged({"statistics":statistics.duplicate(true),"rng":_rng.state,"party":party.map(func(p: BattlePokemon): return p.snapshot()),"enemies":enemies.map(func(p: BattlePokemon): return p.snapshot()),"piles":[hand,draw_pile,discard,exhausted].map(func(pile: Array): return pile.map(func(card: BattleCardInstance): return [card.uid,card.key,card.owner_uid,card.upgraded]))})
    if not boss_context.is_empty():state["boss_context"]=boss_context.duplicate(true)
    if player_moves_version>=2:state["player_moves_version"]=player_moves_version
    if not move_context.is_empty():state["move_context"]=move_context.duplicate(true)
    if not technique_context.is_empty():state["technique_context"]=technique_context.duplicate(true)
    if turn_speed_inverted:state["turn_speed_inverted"]=true
    if not field_context.is_empty():state["field_context"]=field_context.duplicate(true)
    if not seal_context.is_empty():state["seal_context"]=seal_context.duplicate(true)
    if not altitude_context.is_empty():state["altitude_context"]=altitude_context.duplicate(true)
    if not trap_context.is_empty():state["trap_context"]=trap_context.duplicate(true)
    if not item_context.is_empty():state["item_context"]=item_context.duplicate(true)
    if not assist_context.is_empty():state["assist_context"]=assist_context.duplicate(true)
    if not fate_context.is_empty():state["fate_context"]=fate_context.duplicate(true)
    if not reaction_context.is_empty():state["reaction_context"]=reaction_context.duplicate(true)
    if not held_context.is_empty():state["held_context"]=held_context.duplicate(true)
    if not bulk_context.is_empty():state["bulk_context"]=bulk_context.duplicate(true)
    if not exchange_context.is_empty():state["exchange_context"]=exchange_context.duplicate(true)
    return state
func multiplier(attack: String, target: BattlePokemon,move_id:=0) -> float:
    var affinity:=BossBattleRules.affinity(self,attack,target) if full_type_chart and BossBattleRules.active_in(self) else (TypeMatchup.multiplier(attack,target.types) if full_type_chart else BattleContent.multiplier(attack,target.type))
    if PlayerTechniques.active(self):affinity=PlayerMoveRules.affinity(self,attack,target,affinity)
    if player_moves_version>=7:affinity=PlayerMoveAltitude.affinity(self,attack,target,affinity)
    if player_moves_version>=9:affinity=PlayerMoveItems.affinity(self,attack,target,affinity,move_id)
    return PlayerMoveAssist.affinity(self,attack,target,affinity) if player_moves_version>=10 else affinity
func notify_changed() -> String:
    changed.emit()
    return ""
