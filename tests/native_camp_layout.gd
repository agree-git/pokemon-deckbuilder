extends SceneTree
## Dense camp fixtures, real OS navigation, bounded content and untouched run save.
var checks:=0
var failures:=0
var clicks:=0
var folder:="/tmp/pokemon-camp-layout"
var ui:TacticalJourneyUI
var j:TacticalJourney
var baseline:Dictionary
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func click(control:Control) -> void:
    print("OS_MOVE 960 70");await create_timer(.25).timeout
    var available:bool=is_instance_valid(control) and control.is_visible_in_tree() and not (control is BaseButton and control.disabled)
    check(available,"Visible enabled click target")
    if not available:
        print("CLICK_FAILED ",control.get_path() if is_instance_valid(control) else "missing"," bag=",ui.bag_item," hp=",j.party[0].hp," reason=",j.item_reason("potion",0))
        await shot("click-failure")
        quit(2)
        await create_timer(1).timeout
        return
    var at:=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(at.x)," ",roundi(at.y));clicks+=1
    await create_timer(.4).timeout
func key(symbol:String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",symbol);await create_timer(.4).timeout
func wheel(at:Vector2i,steps:int) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_WHEEL ",at.x," ",at.y," ",steps)
    await create_timer(abs(steps)*.012+.3).timeout
func shot(name_text:String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
func distinct(controls:Array) -> bool:
    for i in controls.size():
        for k in range(i+1,controls.size()):
            if controls[i].get_global_rect().intersects(controls[k].get_global_rect()):return false
    return true
func navigation_only() -> void:
    check(JourneySnapshot.encode(j)==baseline,"UI navigation leaves inventory/gold/HP/deck/route/RNG unchanged")
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty() or not OS.get_user_data_dir().begins_with(OS.get_environment("XDG_DATA_HOME")):quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var session:=root.get_node("BattleSession")
    var starters:Array[int]=[1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Protected actual campaign")
    var protected:=JourneySnapshot.encode(session.journey)
    var saved:=FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    j=TutorialLesson.camp_practice()
    j.relics.assign(TacticalContent.RELICS.keys())
    j.held_inventory.assign(TacticalContent.HELD_ITEMS.keys())
    j.gold=5000;j.balls=5
    for item:String in j.items():
        if item!="ball":j.inventory[item]=5
    var stock:={}
    for item:String in j.items():stock[item]=2
    j.camp_states[j.step]={"kind":"merchant","title":"떠돌이 상인","icon":"bag","description":"목록이 많은 야영지 화면 확인","resolved":false,"outcome":"","stock":stock,"offers":["potion","super_potion","revive","ball"],"evolution_offer":"water_stone","card_offers":MerchantContent.generate(j.seed_value,j.step,0,j.deck,j.party,j.relics),"machine_offers":TechnicalMachines.generate(j.seed_value,j.step,j.party,true)}
    j.shop_stock=stock
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=j
    root.add_child(ui);current_scene=ui
    await create_timer(.5).timeout
    baseline=JourneySnapshot.encode(j)
    var research:Control=ui.page.find_child("PokedexWorkshopButton",true,false)
    check(research.get_global_rect().end.y<204,"Research has a dedicated header area above all tab content")
    check(distinct(ui.camp_tabs.values()),"Camp tabs do not overlap")
    await click(ui.camp_tabs["gear"])
    var relics:ScrollContainer=ui.page.find_child("RelicScroll",true,false)
    check(relics!=null and relics.clip_contents and relics.get_global_rect().end.y<870,"All relics stay inside a clipped viewport above messages/footer")
    var relic_buttons:=relics.get_child(0).get_children()
    check(relic_buttons.size()==j.relics.size() and distinct(relic_buttons),"All31 relic buttons remain reachable and separate")
    for child:Node in ui.page.get_children():
        if child is Label and child.text.begins_with("지닌 물건 ·"):check(not child.get_global_rect().intersects(ui.page.find_child("PokedexWorkshopButton",true,false).get_global_rect()),"Gear heading and research no longer overlap")
    await wheel(Vector2i(1200,820),60)
    check(relics.scroll_vertical>0,"Actual wheel reaches late relic rows")
    check(relic_buttons[-1].get_global_rect().end.y<=relics.get_global_rect().end.y+1,"Last relic stays above fixed footer even at bottom")
    await shot("01-many-relics")
    await click(ui.page.find_child("Equipment_%d"%j.party[0].uid,true,false))
    var held:String=j.held_inventory[0]
    await click(ui.page.find_child("Equip_"+held,true,false))
    check(j.party[0].held_item==held and ui.gear_open_for==0,"Visible equipment choice still applies correctly")
    baseline=JourneySnapshot.encode(j)
    await click(ui.camp_tabs["bag"])
    var bag:ScrollContainer=ui.page.find_child("BagScroll",true,false)
    check(not bag.get_global_rect().intersects(ui.page.find_child("PokedexWorkshopButton",true,false).get_global_rect()),"Bag list cannot cover research button")
    await wheel(Vector2i(1100,650),16)
    check(bag.scroll_vertical>0 and bag.clip_contents and bag.get_global_rect().end.y<870,"Large inventory scrolls inside content area")
    await wheel(Vector2i(1100,650),-80)
    await click(ui.page.find_child("Bag_potion",true,false))
    var hp:=j.party[0].hp;var count:=j.quantity("potion")
    await click(ui.page.find_child("Use_potion_0",true,false))
    check(j.party[0].hp>hp and j.quantity("potion")==count-1 and ui.bag_item.is_empty(),"Medicine click consumes only the intended item")
    baseline=JourneySnapshot.encode(j)
    await click(ui.camp_tabs["shop"])
    var supplies:ScrollContainer=ui.page.find_child("ShopSupplyScroll",true,false)
    check(supplies!=null and supplies.clip_contents and supplies.get_global_rect().end.y<870,"Supply rows/hint cannot cover message or departure buttons")
    var gold:=j.gold;count=j.quantity("potion")
    await click(ui.page.find_child("Buy_potion",true,false))
    check(j.gold==gold-int(j.items()["potion"]["price"]) and j.quantity("potion")==count+1,"Visible shop purchase retains price and stock behavior")
    baseline=JourneySnapshot.encode(j)
    supplies=ui.page.find_child("ShopSupplyScroll",true,false)
    await wheel(Vector2i(1550,650),20)
    check(supplies.scroll_vertical>0,"Actual wheel reaches additional supplies/hint")
    await shot("02-shop-bottom")
    await wheel(Vector2i(1550,650),-80)
    await shot("03-shop-prices")
    var names:Array=[]
    for move in range(1,920):
        var view:=TacticalMoves.definition(TacticalMoves.key_for(move))
        if view.has("name"):names.append({"id":move,"name":view["name"]})
    names.sort_custom(func(a:Dictionary,b:Dictionary):return str(a["name"]).length()>str(b["name"]).length())
    j.party[0].learned_skills.clear()
    for i in 4:j.party[0].learned_skills.append(TacticalMoves.key_for(names[i]["id"]))
    baseline=JourneySnapshot.encode(j)
    await click(ui.page.find_child("PokedexWorkshopButton",true,false))
    check(is_instance_valid(ui.workshop),"Header research still opens")
    await click(ui.workshop.find_child("WorkshopTab_moves",true,false))
    var slots:Array=[]
    for i in 4:
        var button:Button=ui.workshop.find_child("WorkshopSlot_%d"%i,true,false)
        slots.append(button)
        check(button.clip_text and button.tooltip_text==button.text and button.get_theme_font_size("font_size")>=14,"Long move name is bounded/readable with full hover name")
    check(distinct(slots),"Longest four move slot buttons have no overlap")
    await click(slots[1]);await shot("04-long-move-names")
    await click(ui.workshop.find_child("WorkshopTab_machines",true,false))
    await shot("05-machines")
    (ui.workshop.find_child("WorkshopSearch",true,false) as LineEdit).grab_focus()
    await key("Escape")
    check(not is_instance_valid(ui.workshop) and current_scene==ui,"Escape closes focused workshop without leaving camp")
    await click(ui.camp_tabs["rest"])
    await click(ui.page.find_child("Upgrade",true,false))
    await click(ui.page.find_child("Card_103",true,false))
    check(ui.upgrade_preview_uid==103,"Card-upgrade comparison still opens")
    await click(ui.page.find_child("UpgradeCancel",true,false));await key("Escape")
    check(not ui.deck_open and ui.upgrade_preview_uid==0,"Cancel/close returns to camp")
    navigation_only()
    check(JourneySnapshot.encode(session.journey)==protected and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Actual unrelated save/RNG remains byte-identical")
    ui.free()
    for name_text:String in ["GameMusic","GameAmbience","GameAudio","GameCries"]:root.get_node(name_text).stop_all()
    await create_timer(.3).timeout
    print("NATIVE_CAMP_LAYOUT ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)
