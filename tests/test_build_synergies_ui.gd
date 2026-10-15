extends "res://tests/test_enemy_tactics_ui.gd"
## Reuse actual pointer input and 1920x1080 capture helpers.
func build_ui(specs: Array, relics: Array[String]) -> TacticalUI:
    var members: Array[BattlePokemon] = []
    for definition: Dictionary in TacticalContent.PARTY: members.append(BattlePokemon.new(definition,definition["uid"]))
    var cards: Array[BattleCardInstance] = []
    for spec: Array in specs: cards.append(BattleCardInstance.new(cards.size()+1,spec[0],spec[1]))
    var b := TacticalBattle.new()
    b.start_with(members,cards,TacticalContent.ENEMIES,71,"field_kit",true,relics)
    b.energy = 12
    b.enemy().max_hp = 500
    b.enemy().hp = 500
    b.hand.assign(cards)
    b.draw_pile.clear()
    for i in 8: b.draw_pile.append(BattleCardInstance.new(100+i,"guard",0))
    var ui: TacticalUI = load("res://scenes/tactical_battle.tscn").instantiate()
    ui.battle = b
    root.add_child(ui)
    return ui
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    root.mode = Window.MODE_WINDOWED
    var ui := build_ui([["water_gun",7],["relay_cover",0],["shield_cell",0],["shield_strike",0],["ace_order",0]],["relay_cell"])
    await process_frame
    UiMotion.finish_tree(ui)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.trainer_buttons[2].tooltip_text.contains("(미충족)"),"Card tooltip explains the missing technique-switch condition")
    await picture("build-relay-before")
    await click(ui.trainer_buttons[1])
    check(ui.battle.active().uid == 7 and ui.battle.energy == 12,"Pointer technique switch triggers exactly one generator energy")
    check(ui.trainer_buttons[2].effect_label.text.contains("✓") and ui.trainer_buttons[2].tooltip_text.contains("(충족)"),"Condition updates on the actual hand card")
    await picture("build-relay-ready")
    var count := ui.battle.hand.size()
    await click(ui.trainer_buttons[2])
    check(ui.battle.hand.size() == count+1,"Pointer plays qualified cover and draws two cards")
    await click(ui.trainer_buttons[3])
    var shield := ui.battle.active().block
    check(ui.shield_badges[0].visible and ui.trainer_buttons[4].effect_label.text.contains("피해 %d" % shield),"Battery shield and conversion preview agree on screen")
    await picture("build-shield-conversion")
    var hp := ui.battle.enemy().hp
    await click(ui.trainer_buttons[4])
    check(ui.battle.active().block == 0 and ui.battle.enemy().hp == hp-shield,"Pointer conversion consumes shield for the displayed damage")
    check("shield_spent" in ui.playback_kinds and "damage" in ui.playback_kinds,"Shield loss and enemy damage have separate presentation steps")
    ui.free()
    ui = build_ui([["tackle",4],["tackle",4],["ace_order",0],["status_plan",0],["toxic_flask",0]],["ace_emblem","status_flask"])
    await process_frame
    UiMotion.finish_tree(ui)
    check(ui.trainer_buttons[5].effect_label.text.contains("독 4회"),"Poison card shows the relic-extended duration")
    await click(ui.trainer_buttons[1])
    check(not ui.trainer_buttons[3].effect_label.text.contains("✓"),"One technique leaves ace payoff inactive")
    await click(ui.trainer_buttons[2])
    check(ui.trainer_buttons[3].effect_label.text.contains("✓") and ui.battle.turn_flags.has("ace_emblem"),"Second technique activates the payoff and emblem")
    await picture("build-ace-ready")
    await click(ui.trainer_buttons[3])
    check(ui.battle.next_attack_bonus == 5,"Pointer concentration order installs its real bonus")
    await click(ui.trainer_buttons[4])
    check(ui.battle.powers.get("attrition") == 1 and ui.relic_chip.tooltip_text.contains("소모전"),"Installed attrition appears in the existing effect tooltip")
    await click(ui.trainer_buttons[5])
    check(ui.battle.enemy().statuses["poison"]["turns"] == 4,"Pointer capsule applies the displayed duration")
    hp = ui.battle.enemy().hp
    await click(ui.end_button)
    check(ui.battle.enemy().hp == hp-PokemonStats.scale(ui.battle.enemy(),3),"Enemy turn resolves the stronger DOT tick")
    await picture("build-attrition")
    ui.free()
    print("BUILD_SYNERGIES_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
