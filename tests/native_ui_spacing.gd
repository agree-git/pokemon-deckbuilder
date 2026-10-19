extends SceneTree
const W := preload("res://scripts/ui/combat_widgets.gd")
var checks := 0
var failures := 0
var clicks := 0
var folder := "/tmp/pokemon-ui-spacing"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func click(control: Control) -> void:
    if not is_instance_valid(control) or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
        check(false,"Available click target");quit(2);return
    print("OS_MOVE 960 40");await create_timer(.12).timeout
    var pos := root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))+Vector2(root.position)
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_CLICK ",roundi(pos.x)," ",roundi(pos.y)); clicks += 1
    await create_timer(.28).timeout
func key(value: String) -> void:
    print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
    print("OS_KEY ",value);await create_timer(.28).timeout
func shot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(folder.path_join(name_text+".png"))==OK,"Screenshot "+name_text)
func horizontal(controls: Array,gap := 23.9) -> bool:
    for i in range(1,controls.size()):
        if controls[i].get_global_rect().position.x-controls[i-1].get_global_rect().end.x<gap:return false
    return true
func vertical(controls: Array,gap := 23.9) -> bool:
    for i in range(1,controls.size()):
        if controls[i].get_global_rect().position.y-controls[i-1].get_global_rect().end.y<gap:return false
    return true
func contained(controls: Array,bounds: Rect2) -> bool:
    for control: Control in controls:
        if not bounds.grow(.1).encloses(control.get_global_rect()):return false
    return true
func run() -> void:
    if DisplayServer.get_name()=="headless" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
    DirAccess.make_dir_recursive_absolute(folder)
    root.mode=Window.MODE_FULLSCREEN;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
    var session := root.get_node("BattleSession")
    var starters: Array[int] = [1,4,7]
    check(session.start_journey(starters,2026).is_empty(),"Actual isolated expedition")
    var actual: TacticalJourney = session.journey
    var baseline := JourneySnapshot.encode(actual)
    var saved := FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)
    var screen := Rect2(0,0,1920,1080)
    var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
    root.add_child(menu);current_scene=menu
    await create_timer(.5).timeout
    check(horizontal([menu.tutorial_button,menu.collection_button]),"Title secondary actions have 24px gap")
    check(vertical([menu.continue_button,menu.start_button,menu.tutorial_button]),"Title action groups have breathing room")
    check(contained([menu.start_button,menu.collection_button],screen),"Title controls remain on screen")
    await shot("01-title")
    await click(menu.settings_button)
    var settings: Control = root.get_node("Preferences").panel
    check(settings.body.size.x==1280 and contained([settings.body],screen),"Settings uses bounded wide two-column layout")
    check(horizontal(settings.mode_buttons.values()) and horizontal(settings.speed_buttons.values()),"Display/speed controls have common 24px gutters")
    check(horizontal([settings.preview_button,settings.cry_preview_button]),"Audio preview controls are separated")
    check(settings.mode_buttons.values()[2].get_global_rect().end.x+64<settings.mute_button.get_global_rect().position.x,"Display and audio groups have independent columns")
    await click(settings.preview_button)
    await shot("02-settings")
    await click(settings.close_button)
    menu._choose_starters();await create_timer(.3).timeout
    var choices := menu.grid.get_children()
    check(choices.size()>=3 and horizontal(choices.slice(0,3)),"Collection tile gutters are 24px")
    check(menu.grid.get_theme_constant("v_separation")==24,"Collection vertical rhythm")
    menu.selection.assign(starters);menu._sync_selection()
    await click(menu.loadout_button)
    var loadout: StarterLoadoutPanel = menu.loadout_panel
    check(loadout.card_grid.get_theme_constant("h_separation")==48 and loadout.card_grid.get_theme_constant("v_separation")==24,"Starting deck uses the available width and spaced rows")
    await key("Escape")
    menu.queue_free();await process_frame
    # Rich camp contents are explicit UI fixtures; never adopted by BattleSession.
    var j := TutorialLesson.camp_practice()
    j.relics.assign(TacticalContent.RELICS.keys());j.held_inventory.assign(TacticalContent.HELD_ITEMS.keys());j.gold=5000
    var stock := {}
    for item: String in j.items():stock[item]=2
    j.camp_states[j.step]={"kind":"merchant","title":"떠돌이 상인","icon":"bag","description":"간격 확인용 야영지","resolved":false,"outcome":"","stock":stock,"offers":["potion","super_potion","revive","ball"],"evolution_offer":"water_stone","card_offers":MerchantContent.generate(j.seed_value,j.step,0,j.deck,j.party,j.relics),"machine_offers":TechnicalMachines.generate(j.seed_value,j.step,j.party,true)}
    j.shop_stock=stock
    var ui: TacticalJourneyUI = load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=j;root.add_child(ui);current_scene=ui
    await create_timer(.4).timeout
    var fixture := JourneySnapshot.encode(j)
    check(horizontal(ui.camp_tabs.values()),"All five camp tabs have 24px gutters")
    var upgrade: Control = ui.page.find_child("Upgrade",true,false)
    check(horizontal([ui.rest_button,upgrade]) and ui.rest_button.size.y==64,"Rest/upgrade buttons have spaced full-size targets")
    check(ui.rest_button.position.y>700 and ui.rest_button.get_global_rect().end.y<850,"Camp action card stays clear of fixed footer")
    check(ui.page.find_child("Time_day",true,false).get_parent()==ui.page.find_child("Time_night",true,false).get_parent(),"Time switch forms its own group")
    await shot("03-camp-rest")
    await click(ui.page.find_child("PokedexWorkshopButton",true,false))
    var workshop: PokedexWorkshop = ui.workshop
    var tabs: Array = []
    for name_text: String in ["evolution","forms","moves","machines"]:tabs.append(workshop.content.find_child("WorkshopTab_"+name_text,true,false))
    check(horizontal(tabs) and contained([workshop.content],screen),"Workshop tabs and wide bounded panel")
    await click(tabs[2])
    var search: Control = workshop.content.find_child("WorkshopSearch",true,false)
    var slots: Array = []
    for i in 4:slots.append(workshop.content.find_child("WorkshopSlot_%d"%i,true,false))
    check(horizontal(slots) and slots[0].size.x==176,"Technique choices use compact buttons with 24px gutters")
    check(slots[0].get_global_rect().position.y-search.get_global_rect().end.y>=23.9,"Search and technique rows are separated")
    var rows: ScrollContainer = workshop.content.find_child("WorkshopScroll",true,false)
    check(rows.get_global_rect().position.y-slots[0].get_global_rect().end.y>=23.9,"Technique selection clears result list")
    await shot("04-workshop")
    await click(search);await key("Escape")
    check(not is_instance_valid(ui.workshop),"Focused research search still closes with Esc")
    await click(ui.deck_button)
    var deck_filter: Control = ui.page.find_child("DeckFilter_0",true,false)
    var deck_scroll: ScrollContainer = ui.page.find_child("JourneyDeckCards",true,false)
    var deck_grid: GridContainer = deck_scroll.get_child(0)
    check(deck_grid.columns==4 and deck_grid.get_theme_constant("h_separation")==40 and deck_grid.get_theme_constant("v_separation")==24,"Deck uses four columns with readable card gaps")
    await click(deck_filter)
    check(ui.deck_owner_filter==0,"Deck filter still works through OS click")
    await shot("05-deck")
    await click(ui.page.find_child("DeckClose",true,false))
    await click(ui.camp_tabs["gear"])
    var relics: ScrollContainer = ui.page.find_child("RelicScroll",true,false)
    var relic_grid: GridContainer = relics.get_child(0)
    check(relic_grid.get_theme_constant("h_separation")==24 and relic_grid.get_theme_constant("v_separation")==16,"Dense relic list has deliberate row/column gutters")
    check(relics.get_global_rect().end.y<870,"Relics remain clipped above footer")
    await click(ui.page.find_child("Equipment_%d"%j.party[0].uid,true,false))
    var picker: Control = ui.page.find_child("EquipmentPicker",true,false)
    var equip: Control = picker.find_child("Equip_",true,false)
    check(equip.get_parent().get_theme_constant("separation")==24,"Equipment picker row spacing")
    await key("Escape")
    await click(ui.camp_tabs["shop"])
    var supplies: ScrollContainer = ui.page.find_child("ShopSupplyScroll",true,false)
    check(supplies.get_child(0).get_theme_constant("separation")==24,"Supply cards have space between purchases")
    await shot("06-camp-shop")
    await click(ui.camp_tabs["rest"])
    await click(ui.page.find_child("EncounterPreparation",true,false))
    var prep: Control = ui.page.find_child("PreparationTab_attack",true,false)
    check(prep!=null,"Battle preparation opens")
    check(horizontal([prep,ui.page.find_child("PreparationTab_immune",true,false),ui.page.find_child("PreparationTab_conditional",true,false)]),"Preparation group tabs are separated")
    var cards: ScrollContainer = ui.page.find_child("PreparationCards",true,false)
    check(cards.size.y>=TrainerActionCard.SLOT_SIZE.y+16,"Preparation keeps whole cards and scrollbar visible")
    await key("Escape")
    check(JourneySnapshot.encode(j)==fixture,"All camp browsing leaves fixture HP/gold/deck/RNG unchanged")
    ui.queue_free();await process_frame
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=actual;root.add_child(ui);current_scene=ui
    await create_timer(.4).timeout
    var battle := ui.battle_ui
    check(horizontal([battle.history_button,battle.help_button,battle.menu_button]),"Combat header controls have 24px gap")
    check(vertical([battle.draw_button,battle.discard_button]),"Draw and discard have 24px vertical gap")
    check(vertical(battle.party_buttons,19.9),"Party rows have increased readable spacing")
    check(battle.ally_roster.get_global_rect().end.y<714,"Roster clears hand area")
    await click(battle.menu_button)
    check(vertical([battle.bag_button,battle.settings_button,battle.home_button,battle.restart_button]),"Battle menu groups have roomy vertical spacing")
    check(contained([battle.menu_panel.get_node("Body")],screen),"Battle menu remains in viewport")
    await shot("07-battle-menu")
    await click(battle.settings_button)
    settings=root.get_node("Preferences").panel
    check(horizontal(settings.mode_buttons.values()),"Shared settings layout also works inside battle")
    await click(settings.close_button);await key("Escape")
    check(JourneySnapshot.encode(actual)==baseline and FileAccess.get_file_as_bytes(JourneySave.SAVE_PATH)==saved,"Actual expedition and save bytes are unchanged after all navigation")
    check(JourneySnapshot.validate(baseline) and JourneySnapshot.encode(JourneySnapshot.restore(baseline))==baseline,"Exact snapshot/UID/RNG restore after presentation changes")
    ui.queue_free();await process_frame
    var state: Dictionary = FileAccess.open("/tmp/pokemon-challenge-review/results/seed-2026-false-boss-136.bin",FileAccess.READ).get_var()
    var champion := JourneySnapshot.restore(state)
    ui=load("res://scenes/tactical_journey.tscn").instantiate();ui.journey=champion;root.add_child(ui);current_scene=ui
    await create_timer(.4).timeout
    check(ui.battle_ui.enemy_slots.size()==6 and vertical(ui.battle_ui.enemy_slots,19.9),"Six-member boss roster has readable row gaps")
    check(ui.battle_ui.enemy_roster.get_global_rect().end.y<714,"Largest roster stays clear of hand/actions")
    check(JourneySnapshot.encode(champion)==state,"Actual boss snapshot untouched")
    ui.queue_free();await process_frame
    print("UI_SPACING_NATIVE ",checks," checks / ",failures," failures / ",clicks," OS clicks")
    quit(0 if failures==0 else 1)
