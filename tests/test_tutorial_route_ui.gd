extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func frames() -> void:
    for tick in 4:await process_frame
func click(control:Control) -> void:
    var point:=control.get_global_rect().get_center()
    var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
    root.push_input(motion,true)
    var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
    root.push_input(event,true)
    event=event.duplicate();event.pressed=false;root.push_input(event,true)
    await frames()
func key(code:int) -> void:
    var event:=InputEventKey.new();event.keycode=code;event.pressed=true
    root.push_input(event,true)
    event=event.duplicate();event.pressed=false;root.push_input(event,true)
    await frames()
func complete_motion(t:TutorialUI) -> void:
    if is_instance_valid(t.battle_view):t.battle_view.finish_presentation()
    await frames()
func run() -> void:
    if not OS.get_user_data_dir().begins_with("/tmp/pokemon-tutorial-route/"):quit(2);return
    root.size=Vector2i(1920,1080)
    var session:=root.get_node("BattleSession")
    session.save_store=JourneySave.new("user://protected.json")
    var starters:Array[int]=[1,4,7]
    check(session.start_journey(starters,712).is_empty(),"Create protected real expedition")
    var protected:=JourneySnapshot.encode(session.journey)
    var save_bytes:=FileAccess.get_file_as_bytes("user://protected.json")
    var captures:Array=session.profile.captured_ids.duplicate()
    var t:=TutorialUI.new();root.add_child(t)
    await frames()
    var before:=JourneySnapshot.encode(t.practice)
    await click(t.battle_view.menu_button)
    await key(KEY_ENTER)
    check(t.step==0 and not t.battle_view._overlay_open() and JourneySnapshot.encode(t.practice)==before,"Intro blocks menu and premature keyboard turn end")
    await click(t.next_button);await click(t.next_button)
    check(t.step==2,"Only designated next buttons advance the introduction")
    await complete_motion(t)
    for lesson in [2,3,4]:
        var allowed_uid:int=[TutorialLesson.FIRST_CARD,TutorialLesson.SWITCH_CARD,TutorialLesson.GUARD_CARD][lesson-2]
        before=JourneySnapshot.encode(t.practice)
        await click(t.battle_view.trainer_buttons[104])
        await click(t.battle_view.end_button)
        await click(t.battle_view.help_button)
        await key(KEY_ENTER);await key(KEY_C);await key(KEY_1)
        check(t.step==lesson and JourneySnapshot.encode(t.practice)==before and not t.battle_view._overlay_open(),"Wrong card, other buttons and shortcuts cannot bypass the current card lesson")
        var target:Control=t.battle_view.trainer_buttons[allowed_uid]
        check(not t.input_gate.call("_has_point",target.get_global_rect().get_center()),"Pointer shield opens only over designated card")
        await click(target);await complete_motion(t)
        check(t.step==lesson+1,"Designated real card remains clickable and progresses the lesson")
    await click(t.battle_view.end_button);await complete_motion(t)
    check(t.step==6 and t.practice.battle.turn==2,"Only guided end-turn advances real battle")
    await click(t.next_button);await frames()
    check(t.step==7,"Capture practice starts through its designated next button")
    before=JourneySnapshot.encode(t.practice)
    await click(t.battle_view.menu_button);await click(t.battle_view.end_button)
    check(JourneySnapshot.encode(t.practice)==before,"Capture lesson blocks unrelated controls")
    await key(KEY_C);await complete_motion(t)
    check(t.step==8 and t.camp_view!=null,"Guided capture shortcut reaches camp practice")
    before=JourneySnapshot.encode(t.practice)
    var upgrade:Control=t.camp_view.page.find_child("Upgrade",true,false)
    await click(upgrade);await key(KEY_ENTER)
    check(t.step==8 and not t.camp_view.deck_open and JourneySnapshot.encode(t.practice)==before,"Rest lesson blocks upgrade and keyboard shortcuts")
    await click(t.camp_view.rest_button)
    check(t.step==9,"Only designated rest button spends the practice camp action")
    await click(t.next_button)
    check(t.step==10,"Next practice starts with a fresh camp action")
    await click(t.camp_view.page.find_child("Upgrade",true,false))
    check(t.camp_view.deck_open,"Upgrade lesson permits opening the card picker")
    await click(t.camp_view.deck_close)
    check(t.camp_view.deck_open,"Card picker close button is outside the current lesson targets")
    var card:BaseButton
    for control:Control in t.input_targets():
        if control is BaseButton and str(control.name).begins_with("Card_"):card=control;break
    check(card!=null,"Upgrade lesson exposes selectable upgrade cards")
    if card!=null:
        await click(card)
        check(t.camp_view.upgrade_preview_uid!=0,"Selecting an allowed card opens the real preview")
        await click(t.camp_view.page.find_child("UpgradeCancel",true,false))
        check(t.camp_view.upgrade_preview_uid!=0,"Unspecified cancel button cannot dismiss guided confirmation")
        await click(t.camp_view.page.find_child("UpgradeConfirm",true,false))
        check(t._finishing and t.stage_view.find_child("TutorialStartJourney",true,false)!=null,"Designated confirmation completes the tutorial")
    check(JourneySnapshot.encode(session.journey)==protected and FileAccess.get_file_as_bytes("user://protected.json")==save_bytes and session.profile.captured_ids==captures,"Full guided flow preserves real expedition/save bytes/RNG/collection")
    t.free();await frames()
    # Geometry and navigation for each biome plus the league; no battle simulation.
    for chapter in 9:
        var j:=TacticalJourney.new(712,"field_kit",starters,true)
        for i in j.route.stops.size():
            if int(j.route.stops[i]["chapter"])==chapter and j.route.stops[i]["kind"]!="rest":j.step=i;break
        j.phase=TacticalJourney.MAP
        before=JourneySnapshot.encode(j)
        var view:=TacticalJourneyUI.new();view.journey=j;root.add_child(view)
        await frames()
        var strip:ScrollContainer=view.page.find_child("JourneyStageStrip",true,false)
        var expected:=5 if chapter==8 else 8
        var cards:Array=strip.body.get_children().filter(func(node:Node):return str(node.name).begins_with("Encounter_"))
        var arrows:Array=strip.body.get_children().filter(func(node:Node):return str(node.name).begins_with("StageArrow_"))
        check(cards.size()==expected and arrows.size()==expected-1 and strip.size.x==1190,"Ordered stage cards have arrows between them and a four-card viewport")
        check(cards.all(func(control:Control):return control.position.y==0 and control.size==Vector2(260,280)),"Stage cards form one horizontal row instead of a grid")
        var viewport_rect:=Rect2(strip.scroll_horizontal,0,strip.size.x,strip.size.y)
        check(cards.filter(func(control:Control):return viewport_rect.encloses(control.get_rect())).size()==4,"Exactly four complete stage cards are displayed")
        await click(view.page.find_child("NextStages",true,false))
        check(strip.scroll_horizontal==strip.max_scroll() and view.page.find_child("NextStages",true,false).disabled,"Next arrow scrolls to the final cards and disables at the end")
        await click(view.page.find_child("PreviousStages",true,false))
        check(strip.scroll_horizontal==0 and view.page.find_child("PreviousStages",true,false).disabled,"Previous arrow returns to the first cards")
        check(JourneySnapshot.encode(j)==before,"Stage scrolling never changes route/save/RNG or advances the expedition")
        view.free();await frames()
    var later:=TacticalJourney.new(712,"field_kit",starters,true)
    later.step=8;later.phase=TacticalJourney.MAP
    var view:=TacticalJourneyUI.new();view.journey=later;root.add_child(view);await frames()
    var strip:ScrollContainer=view.page.find_child("JourneyStageStrip",true,false)
    check(strip.scroll_horizontal==strip.max_scroll() and strip.body.find_child("Encounter_8",true,false).get_global_rect().intersects(strip.get_global_rect()),"Current stage five opens in its second four-card group")
    view.free();await frames()
    print("TUTORIAL_ROUTE_UI ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
