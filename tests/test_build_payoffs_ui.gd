extends "res://tests/test_build_synergies_ui.gd"
const W = preload("res://scripts/ui/combat_widgets.gd")
func run() -> void:
    Engine.max_fps = 60
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-tactics")
    root.mode = Window.MODE_WINDOWED
    root.position = Vector2i.ZERO
    root.size = Vector2i(1920,1080)
    var ui := build_ui([["ace_finisher",0],["shield_double",0],["status_pulse",0],["relay_retrieve",0]],["relay_cloak","status_dish"])
    ui.battle.active().block = 12
    ui.battle.enemy().statuses = {"burn":{"turns":2,"source_uid":4},"poison":{"turns":3,"source_uid":4}}
    var reserve_card := BattleCardInstance.new(500,"water_gun",7)
    var other_card := BattleCardInstance.new(501,"seed",1)
    ui.battle.discard.assign([other_card,reserve_card])
    await process_frame
    UiMotion.finish_tree(ui)
    ui._refresh()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    check(ui.trainer_buttons[4].tooltip_text.contains("대기 동료") and ui.trainer_buttons[3].tooltip_text.contains("남은 횟수 유지"),"Live cards retain recipient and duration rules in their tooltips")
    check(ui.trainer_buttons[2].effect_label.text.contains("+12 획득"),"Compression shows actual current shield gain")
    await picture("payoffs-before")
    await click(ui.trainer_buttons[1])
    check(ui.battle.turn_flags.get("finisher_4",false),"Native finisher click commits the owner marker")
    var chips := ui.find_children("*","Button",true,false)
    check(chips.any(func(c: Button): return c.tooltip_text.contains("이번 턴 이 멤버의 다음 공격 기술 피해 2배")),"Pending finisher is visible as an explained status chip")
    await click(ui.trainer_buttons[2])
    check(ui.battle.active().block == 24 and ui.shield_values[0].text == "24","Compression click displays exact doubled shield")
    var hp := ui.battle.enemy().hp
    var ticks := ui.battle.status_damage(ui.battle.enemy(),"burn")*2
    await click(ui.trainer_buttons[3])
    check(ui.battle.enemy().hp == hp-ticks and ui.battle.enemy().statuses["poison"]["turns"] == 3,"Pulse click stages real DOT without consuming duration")
    check(ui.playback_kinds.count("damage") == 2,"Each immediate status tick has its own presentation step")
    await click(ui.trainer_buttons[4])
    check(ui.battle.hand.has(reserve_card) and ui.battle.hand.has(other_card) and "cards_returned" in ui.playback_kinds,"Recovery shows the actual returned cards in the hand")
    await click(ui.trainer_buttons[500])
    check(ui.battle.active().uid == 7 and ui.battle.member(4).block == 0 and ui.battle.member(7).block >= 24,"Returned reserve technique performs the mantle handoff")
    check(ui.battle.turn_flags.get("finisher_4",false),"Handoff leaves the other owner's finisher intact")
    await picture("payoffs-handoff")
    ui.free()
    ui = build_ui([["tackle",4],["tackle",4],["tackle",4]],["ace_medal"])
    await process_frame
    for uid in [1,2,3]: await click(ui.trainer_buttons[uid])
    check(ui.battle.energy == 10 and ui.battle.turn_flags.has("ace_medal"),"Three actual card clicks refund medal energy only on the third technique")
    ui.free()
    ui = build_ui([["shield_double",0]],["shield_battery"])
    ui.battle.active().block = 100
    await process_frame
    UiMotion.finish_tree(ui)
    await click(ui.trainer_buttons[1])
    await click(ui.end_button)
    check(ui.battle.energy == 4+ui.battle.turn_energy_bonus and ui.playback_kinds.has("relic"),"Full guard visibly grants next-turn battery energy")
    await picture("payoffs-battery")
    ui.free()
    await gallery()
    root.get_node("GameMusic").stop_music()
    root.get_node("GameCries").stop_all()
    await create_timer(0.15).timeout
    print("BUILD_PAYOFFS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
func gallery() -> void:
    var gallery := Control.new()
    root.add_child(gallery)
    W.panel(gallery,Rect2(0,0,1920,1080),Color("0b1d24"))
    W.label(gallery,"네 가지 빌드 · 새 카드와 유물",Rect2(80,20,1760,48),32,W.GOLD)
    var keys := ["relay_retrieve","ace_finisher","status_pulse","shield_double"]
    var relics := ["relay_cloak","ace_medal","status_dish","shield_battery"]
    var names := ["교대 · 기술 순환","에이스 · 결정타","상태이상 · 즉시 발동","보호막 · 다음 턴 준비"]
    for i in 4:
        W.label(gallery,names[i],Rect2(80+i*450,80,410,35),24,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        for row in 2:
            var card := BattleCardInstance.new(1,keys[i],0)
            card.upgraded = row == 1
            var face := CardStackView.new()
            face.definition = TacticalContent.definition(card)
            face.key = keys[i]
            face.position = Vector2(174+i*450,125+row*324)
            face.scale = Vector2.ONE*1.08
            gallery.add_child(face)
        var definition: Dictionary = TacticalContent.RELICS[relics[i]]
        var panel := W.panel(gallery,Rect2(80+i*450,818,410,196),Color("19313a"),Color("647b76"),10)
        W.icon(panel,definition["icon"],Rect2(18,18,30,30))
        W.label(panel,definition["name"],Rect2(62,10,328,46),25,W.GOLD)
        var text := W.label(panel,definition["description"],Rect2(20,64,370,120),20,W.TEXT)
        text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    await process_frame
    await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png("/tmp/pokemon-tactics/payoffs-cards.png") == OK,"Capture actual base/upgraded card faces and relic descriptions")
    gallery.free()
