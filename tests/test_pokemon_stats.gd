extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func pokemon(id: int, level := 100, uid := 1) -> BattlePokemon:
    var p := BattlePokemon.new(TacticalContent.member_definition(id,VisualCatalog.new()),uid)
    p.level = level
    PokemonStats.apply(p,true)
    return p
func fixture(ally: int, foe: int, level := 50) -> TacticalBattle:
    var p := pokemon(ally,level)
    var definition := TacticalContent.member_definition(foe,VisualCatalog.new())
    definition["level"] = level
    definition["intents"] = [{"kind":"attack","value":999,"move_id":33,"type":"normal"}]
    var b := TacticalBattle.new()
    b.start_with([p],[],[definition],71,"field_kit")
    b.full_type_chart = true
    return b
func play(b: TacticalBattle, key: String, owner := 1) -> Dictionary:
    var card := BattleCardInstance.new(10000+b.discard.size()+b.exhausted.size(),key,owner)
    b.hand.append(card)
    var view := b.card_view(card)
    check(b.play_card(card.uid).is_empty(),"Drawn test card resolves: "+key)
    return view
func run() -> void:
    check(PokemonStats.data()["species"].size() == 386,"All first three generations have six original base stats")
    check(PokemonStats.base(25)["defense"] == 30 and PokemonStats.base(26)["speed"] == 100,"Historical Gen III base stats precede later buffs")
    var p := pokemon(6)
    check([p.max_hp,p.attack,p.defense,p.special_attack,p.special_defense,p.speed] == [266,173,161,223,175,205],"Independent Lv.100 Charizard species-and-level-only reference")
    p = pokemon(1,5)
    check([p.max_hp,p.attack,p.defense,p.special_attack,p.special_defense,p.speed] == [19,9,9,11,11,9],"Independent Lv.5 Bulbasaur reference")
    check(pokemon(292,5).max_hp == 1 and pokemon(292).max_hp == 1,"Shedinja always has one HP")
    var physical := {"move_id":33,"move_power":80,"damage_class":"physical","type":"normal"}
    var special := {"move_id":85,"move_power":80,"damage_class":"special","type":"normal"}
    var alakazam := pokemon(65)
    var machamp := pokemon(68)
    var target := pokemon(143)
    check(PokemonStats.damage(alakazam,target,special,1) > PokemonStats.damage(alakazam,target,physical,1),"Alakazam uses its higher special attack")
    check(PokemonStats.damage(machamp,target,physical,1) > PokemonStats.damage(machamp,target,special,1),"Machamp uses its higher physical attack")
    check(PokemonStats.damage(alakazam,pokemon(91),special,1) > PokemonStats.damage(alakazam,pokemon(91),physical,1),"Cloyster's physical defense resists physical damage")
    var fire := {"move_id":53,"move_power":95,"damage_class":"special","type":"fire"}
    check(PokemonStats.damage(pokemon(6),pokemon(3),fire,2) == 158,"Independent deterministic damage: Lv100 Flamethrower, STAB and weakness, scale 0.6")
    check(PokemonStats.damage(pokemon(6),pokemon(3),fire,0) == 0,"Immunity wins over flat bonuses and STAB")
    check(PokemonStats.damage(pokemon(6),pokemon(3),fire,4) == 316 and PokemonStats.damage(pokemon(6),pokemon(3),fire,0.25) == 19,"Exact double weakness and double resistance before final flooring")
    var burned := pokemon(6)
    var physical_before := PokemonStats.damage(burned,target,physical,1)
    var special_before := PokemonStats.damage(burned,target,special,1)
    burned.statuses["burn"] = {"turns":3,"source_uid":-1}
    check(PokemonStats.damage(burned,target,physical,1) <= physical_before/2.0 and PokemonStats.damage(burned,target,special,1) == special_before,"Burn halves physical damage while preserving special attacks")
    p = pokemon(6)
    var hp: int
    p.hp -= 7
    TacticalGrowth.evolve(p,3,VisualCatalog.new())
    check(p.max_hp-p.hp == 7,"Species changes preserve missing HP")
    p.hp = 0
    p.level = 80
    PokemonStats.apply(p)
    check(p.hp == 0 and p.knocked_out,"Stat recalculation never revives a fainted Pokemon")
    var b := fixture(65,143)
    check(b.energy == 4 and b.turn_energy_bonus == 1,"Fast active gets energy four on opening turn")
    b = fixture(143,65)
    check(b.energy == 3 and b.turn_energy_bonus == 0,"Slower active gets energy three")
    b = fixture(65,65)
    check(b.energy == 3,"Equal speed gets no bonus")
    b = fixture(65,143)
    var slow := pokemon(143,50,2)
    b.party.append(slow)
    var captured_speed := b.turn_speed_actor
    var view := play(b,"move_33",2)
    check(b.active() == slow and b.energy == 3 and b.turn_speed_actor == captured_speed,"Technique auto-switch spends only card cost and never regrants speed energy")
    b.end_turn()
    check(b.energy == 3 and b.turn_energy_bonus == 0 and b.turn_speed_owner_uid == 2,"Next turn uses the new active and tie grants no bonus")
    b = fixture(65,143)
    b.enemy().hp = 1
    b.enemies.append(pokemon(65,50,-2))
    b.enemy_definitions.append(b.enemy_definitions[0].duplicate(true))
    b.enemy_states.append({"intent":0})
    play(b,"move_33")
    check(b.enemy_index == 1 and b.energy == 3 and b.turn_speed_target_uid == -1,"Same-turn enemy replacement preserves original grant")
    b = fixture(65,143)
    var expected := b.intent()["value"] as int
    b.active().block = 0
    hp = b.active().hp
    b.end_turn()
    check(b.active().hp == hp-expected,"Enemy telegraph matches actual original-formula damage")
    b = fixture(6,3,100)
    b.active().block = 0
    b.enemy().block = 9
    hp = b.enemy().hp
    view = play(b,"move_53")
    check(b.enemy().hp == hp-maxi(0,int(view["preview_damage"])-9),"Player preview includes STAB/type and protection absorbs afterwards")
    b = fixture(65,143)
    b.energy = 8
    play(b,"move_97") # Agility.
    check(b.active().stat_stages.get("speed") == 2 and PokemonStats.effective(b.active(),"speed") == b.active().speed*2,"Original Agility raises speed two stages")
    check(b.energy == 7 and b.turn_speed_actor == captured_speed,"Speed stages do not retroactively grant energy")
    play(b,"move_45") # Growl.
    check(b.enemy().stat_stages.get("attack") == -1 and not b.active().stat_stages.has("attack"),"Growl changes enemy Attack rather than generic damage bonus")
    var prior := PokemonStats.damage(b.enemy(),b.active(),physical,1)
    b.enemy().stat_stages.clear()
    check(PokemonStats.damage(b.enemy(),b.active(),physical,1) > prior,"Original stat stages affect damage")
    b.active().statuses["paralysis"] = {"turns":3,"source_uid":-1}
    check(PokemonStats.effective(b.active(),"speed") == b.active().speed,"Paralysis halves current staged speed")
    b.active().stat_stages["speed"] = 6
    b.energy = 10
    play(b,"move_97")
    check(b.active().stat_stages["speed"] == 6,"Stage gains cap at plus six")
    var second := pokemon(143,50,2)
    b.party.append(second)
    b.energy = 1
    b.switch_to(2)
    check(b.member(1).stat_stages.is_empty(),"Leaving the field clears original stat stages")
    b = fixture(65,94)
    b.active().statuses["paralysis"] = {"turns":3,"source_uid":-1}
    b.end_turn()
    check(b.energy == 3 and b.turn_energy_bonus == 0,"Paralysis changes the next turn's speed comparison")
    b = fixture(65,143)
    b.party.append(pokemon(6,50,2))
    b.active().hp = 1
    b.active().block = 0
    b.end_turn()
    check(b.phase == TacticalBattle.REPLACE and b.turn == 1,"Enemy knockout waits for a replacement before next-turn energy")
    b.switch_to(2)
    check(b.turn == 2 and b.energy == 4 and b.turn_speed_owner_uid == 2,"Forced replacement grants the new turn exactly once")
    b = fixture(65,143)
    b.party.append(pokemon(6,50,2))
    b.active().hp = 1
    b.active().statuses["burn"] = {"turns":2,"source_uid":-1}
    b.end_turn()
    check(b.phase == TacticalBattle.REPLACE and b._pending == "enemy","DOT knockout defers the pending enemy action")
    b.switch_to(2)
    check(b.turn == 2 and b.energy == 4,"DOT forced switch runs enemy action and grants only the actual next turn")
    b = fixture(65,143)
    b.energy = 10
    play(b,"move_229")
    check(b.active().stat_stages.get("speed") == 1 and b.enemy().stat_stages.is_empty(),"Rapid Spin's positive secondary stages target its user")
    play(b,"move_246")
    check(b.active().stat_stages.get("special_attack") == 1,"Ancient Power raises user stats")
    var before_preview := b.snapshot()
    b.card_view(BattleCardInstance.new(777,"move_97",1))
    check(b.snapshot() == before_preview,"Repeated card preview never applies stat stages")
    b = fixture(65,143)
    b.energy = 10
    play(b,"move_315")
    check(b.active().stat_stages.get("special_attack") == -2,"Overheat lowers the user's special attack after damage")
    b = fixture(6,3,100)
    b.active().hp -= 100
    view = play(b,"potion_card",0)
    check(view["preview_heal"] == 89 and b.active().hp == b.active().max_hp-11,"Healing tool scales with HP and matches preview")
    view = play(b,"guard",0)
    check(b.active().block == PokemonStats.scale(b.active(),5)+view["preview_block"],"Opening relic and shield card scale independently")
    # A true campaign graph ensures speed grants/stages survive serialization.
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    j.battle.active().stat_stages["speed"] = 2
    j.battle.energy -= 1
    var encoded := JourneySnapshot.encode(j)
    check(JourneySnapshot.validate(encoded),"Original stats and captured turn-speed data validate")
    var resumed := JourneySnapshot.restore(encoded)
    check(JourneySnapshot.encode(resumed) == encoded,"Reload preserves stats, stages and already-spent energy")
    var malformed := encoded.duplicate(true)
    malformed["battle"]["turn_energy_bonus"] = 2
    check(not JourneySnapshot.validate(malformed),"Invalid energy grant rejected")
    malformed = encoded.duplicate(true)
    malformed["pokemon"][j.party[0].uid]["stat_stages"]["speed"] = 7
    check(not JourneySnapshot.validate(malformed),"Invalid stat stages rejected")
    print("POKEMON_STATS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
