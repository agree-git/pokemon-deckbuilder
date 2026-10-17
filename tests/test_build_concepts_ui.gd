extends "res://tests/test_build_synergies_ui.gd"
const W = preload("res://scripts/ui/combat_widgets.gd")
var view: TacticalUI
func fresh(specs: Array,acquired: Array[String]) -> void:
    if is_instance_valid(view): view.free()
    view = build_ui(specs,acquired)
    await process_frame
    UiMotion.finish_tree(view)
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.12).timeout
func use(uid: int) -> void:
    check(view.trainer_buttons.has(uid),"Requested actual drawn instance is visible")
    if view.trainer_buttons.has(uid): await click(view.trainer_buttons[uid])
func run() -> void:
    Engine.max_fps = 60
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-concepts")
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    await fresh([["relay_formation",0],["relay_accelerate",0],["relay_command",0],["relay_cycle_plan",0],["water_gun",7]],["relay_signal","manual_pin"])
    await use(1)
    await use(4)
    await use(5)
    check(view.trainer_buttons[2].effect_label.text.contains("✓"),"Real automatic switch activates accelerator face")
    var energy := view.battle.energy
    await use(2)
    check(view.battle.energy == energy+1,"Conditional accelerator grants the previewed energy")
    await use(3)
    check(view.battle.next_attack_bonus == 4 and view.battle.powers.get("relay_cycle",0) == 1,"Team command and first-switch plan run from actual hand")
    await picture("concept-relay-battle")
    await fresh([["ace_reserve",0],["ace_breathing",0],["ace_retrieve",0],["ace_precision",0],["tackle",4]],["ace_sight","ace_calm"])
    view.battle.discard.append(BattleCardInstance.new(500,"tackle",4))
    await use(2)
    await use(1)
    await use(5)
    await use(3)
    await use(500)
    check(view.trainer_buttons[4].effect_label.text.contains("✓"),"Two same-owner techniques activate precision")
    await use(4)
    await click(view.end_button)
    check(not view.battle.powers.has("energy_bank") and view.battle.energy == 4+view.battle.turn_energy_bonus,"Reserved energy survives presentation and pays only at next turn")
    await picture("concept-ace-battle")
    await fresh([["status_catalyst",0],["status_ampoule",0],["status_analysis",0],["status_absorption",0],["status_pulse",0]],["status_ember","status_vial"])
    view.battle.active().hp = 1
    view.battle.enemy().statuses["poison"] = {"turns":2,"source_uid":4}
    view._refresh()
    await use(4)
    await use(2)
    await use(1)
    check(view.trainer_buttons[3].effect_label.text.contains("✓") and view.battle.enemy().statuses["burn"]["turns"] == 4,"New ailment plus catalyst updates DOT and conditional card")
    await use(3)
    await use(5)
    check(view.battle.active().hp > 1 and view.battle.next_attack_bonus == 3,"Immediate DOT presents absorption healing and residue bonus")
    await picture("concept-status-battle")
    await fresh([["shield_lock",0],["shield_inspect",0],["shield_regroup",0],["shield_fortress",0]],["shield_pad","shield_badge","shield_battery"])
    view.battle.active().block = 60
    view._refresh()
    await use(4)
    await use(1)
    await use(3)
    await use(2)
    await click(view.end_button)
    check(view.battle.active().block >= 60 and view.battle.energy == 4+view.battle.turn_energy_bonus,"Fortress, pinned shield and full-guard resources compose on screen")
    await picture("concept-shield-battle")
    await fresh([["supply_recycle",0],["supply_pack",0],["supply_dynamo",0],["supply_assembly",0]],["tool_pouch","tool_discount"])
    view.battle.active().hp = 1
    view._refresh()
    check(view.trainer_buttons[3].cost_label.text == "0" and view.trainer_buttons[3].tooltip_text.contains("정밀 공구"),"First tool discount appears in cost and tooltip")
    await use(4)
    await use(3)
    await use(1)
    check(view.trainer_buttons.has(3) and view.trainer_buttons[3].cost_label.text == "1","Recovered exact tool returns with its now-spent discount reflected")
    await use(3)
    await use(2)
    check(view.battle.active().hp > 1 and view.battle.next_attack_bonus == 4,"Reused tool cannot repeat the first-tool assembly payoff")
    await picture("concept-supply-battle")
    await fresh([["cycle_engine",0],["cycle_preserve",0],["cycle_opportunity",0],["cycle_filter",0],["ether_card",0]],["cycle_spring","cycle_bookmark"])
    view.battle.draw_pile.clear()
    view.battle.discard.assign([BattleCardInstance.new(500,"tackle",4),BattleCardInstance.new(501,"guard",0),BattleCardInstance.new(502,"guard",0)])
    await use(1)
    await use(3)
    await use(4)
    check(view.battle.turn_flags.get("reshuffled",false) and "cards_discarded" in view.playback_kinds,"Selective discard and real reshuffle have separate stages")
    await use(2)
    var retained := view.battle.retained.duplicate()
    await click(view.end_button)
    check(not retained.is_empty() and retained.all(func(uid: int): return view.battle.hand.any(func(c: BattleCardInstance): return c.uid == uid)),"Whole-hand retention preserves actual card instances across turn")
    check(view.battle.energy >= 4+view.battle.turn_energy_bonus,"Bookmark supplies next-turn energy")
    await picture("concept-cycle-battle")
    view.free()
    for concept: String in BuildConceptContent.GROUPS: await gallery(concept)
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.15).timeout
    print("BUILD_CONCEPTS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
func gallery(concept: String) -> void:
    var page := Control.new()
    root.add_child(page)
    W.panel(page,Rect2(0,0,1920,1080),Color("0b1d24"))
    W.label(page,BuildConceptContent.TITLES[concept]+" · 카드 4종과 유물 2종",Rect2(80,18,1760,48),32,W.GOLD)
    W.label(page,"위: 기본 카드 / 아래: 강화 카드 · 상세 조건은 전체 효과 설명 참고",Rect2(80,70,1760,32),18,W.MUTED)
    for i in 4:
        var key: String = BuildConceptContent.GROUPS[concept][i]
        for row in 2:
            var card := BattleCardInstance.new(1,key,0)
            card.upgraded = row == 1
            var face := CardStackView.new()
            face.definition = TacticalContent.definition(card)
            face.key = key
            face.position = Vector2(150+i*450,108+row*334)
            face.scale = Vector2.ONE*1.15
            page.add_child(face)
    for i in 2:
        var key: String = BuildConceptContent.RELICS[concept][i]
        var definition: Dictionary = TacticalContent.RELICS[key]
        var panel := W.panel(page,Rect2(80+i*900,826,860,190),Color("19313a"),Color("647b76"),10)
        W.icon(panel,definition["icon"],Rect2(18,18,30,30))
        W.label(panel,definition["name"],Rect2(62,10,772,46),26,W.GOLD)
        var text := W.label(panel,definition["description"],Rect2(24,68,812,100),23,W.TEXT)
        text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    await process_frame
    await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png("/tmp/pokemon-concepts/"+concept+".png") == OK,"Capture native base/upgraded concept gallery: "+concept)
    page.free()
