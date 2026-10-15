extends "res://tests/test_merchant_ui.gd"
func bag(key: String) -> void:
    await click(ui.camp_tabs["bag"])
    var button: Button = ui.page.find_child("Bag_"+key,true,false)
    var scroll: ScrollContainer = ui.page.get_node("BagScroll")
    await process_frame
    scroll.ensure_control_visible(button)
    await process_frame
    settle()
    scroll.ensure_control_visible(button)
    await process_frame
    await click(button)
func key_escape() -> void:
    if native:
        print("OS_KEY Escape")
        await create_timer(0.2).timeout
    else:
        var event := InputEventKey.new()
        event.keycode = KEY_ESCAPE
        event.pressed = true
        root.push_input(event)
        await process_frame
    settle()
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var j: TacticalJourney
    # Pick a reproducible merchant offering Thunder Stone to the fixture party.
    for seed_value in 100:
        j = TacticalJourney.new(seed_value,"field_kit",[25,64,366],true)
        for step in j.route.stops.size():
            if j.route.stops[step]["kind"] != "rest" or j.route.stops[step]["camp"]["kind"] != "merchant": continue
            j.phase = TacticalJourney.MAP
            j.step = step
            j.enter_next()
            break
        if j.camp()["evolution_offer"] == "thunder_stone": break
    j.gold = 600
    # A full bag verifies clipping and scrolling. Purchases/evolutions use actual input.
    for material: String in EvolutionItems.ITEMS:
        if material != "thunder_stone": j.inventory[material] = 1
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/evolution_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/evolution_ui_journey.json"))
    session.adopt_journey(j)
    ui = load("res://scenes/tactical_journey.tscn").instantiate()
    ui.journey = j
    root.add_child(ui)
    await process_frame
    settle()
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.2).timeout
    await click(ui.camp_tabs["shop"])
    var purchase: Button = ui.page.find_child("Buy_thunder_stone",true,false)
    check(not purchase.disabled and purchase.get_parent().tooltip_text.contains("진화"),"The fourth supply advertises an actual evolution material")
    await click(purchase)
    check(j.quantity("thunder_stone") == 1 and j.gold == 420 and j.shop_stock["thunder_stone"] == 0,"Material purchase charges its visible price and sells out")
    check(ui.page.find_child("Buy_thunder_stone",true,false).disabled,"Sold material cannot be bought again")
    await picture("evolution-merchant")
    for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)]:
        root.size = dimensions
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.12).timeout
        await bag("thunder_stone")
        check(not ui.bag_item.is_empty(),"A scrolled material opens its target popup at %s" % dimensions)
        var target: Button = ui.page.find_child("Use_thunder_stone_0",true,false)
        check(not target.disabled and target.get_children().filter(func(n: Node): return n is TextureRect).size() == 2,"Valid target shows both current and evolved sprites")
        check(ui.page.find_child("Use_thunder_stone_1",true,false).disabled and ui.page.find_child("Use_thunder_stone_2",true,false).disabled,"Unrelated species are disabled with reasons")
        await key_escape()
        check(ui.bag_item.is_empty() and j.quantity("thunder_stone") == 1 and j.party[0].species_id == 25,"Esc cancels without spending the item or changing species")
    root.size = Vector2i(1280,720)
    await process_frame
    await bag("thunder_stone")
    check(ui.page.find_child("Use_thunder_stone_0",true,false).tooltip_text.contains("새로 배울 기술이 없습니다"),"Preview explains Raichu's lack of later level-up moves before consuming the stone")
    await picture("evolution-target-preview")
    var uid := j.party[0].uid
    var xp := j.party[0].experience
    var cards := j.deck.duplicate()
    await click(ui.page.find_child("Use_thunder_stone_0",true,false))
    check(j.party[0].species_id == 26 and j.party[0].uid == uid and j.party[0].experience == xp and j.deck == cards and j.quantity("thunder_stone") == 0,"Target click performs the previewed evolution and keeps card identities")
    check(ui.bag_item.is_empty() and ui.page.has_node("EvolutionReveal"),"Evolution displays a focused result rather than jumping past it")
    var saved: TacticalJourney = session.get("save_store").load_journey()
    check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Evolution is autosaved before dismissing its presentation")
    await picture("evolution-result")
    var before := JourneySnapshot.encode(j)
    # The centered result blocks underlying tabs; clicking its body is inert.
    await click(ui.camp_tabs["shop"])
    check(JourneySnapshot.encode(j) == before and ui.page.has_node("EvolutionReveal"),"Result modal blocks underlying camp interactions")
    await click(ui.page.find_child("CloseEvolution",true,false))
    check(not ui.page.has_node("EvolutionReveal") and j.rested_steps.is_empty(),"Dismissing the result leaves the rest/upgrade action available")
    await bag("linking_cord")
    check(not ui.page.find_child("Use_linking_cord_1",true,false).disabled,"A trade evolution targets Kadabra")
    await click(ui.page.find_child("Use_linking_cord_1",true,false))
    check(j.party[1].species_id == 65 and j.quantity("linking_cord") == 0,"Solo trade material evolves Kadabra without changing party membership")
    await key_escape()
    await bag("deep_sea_scale")
    check(not ui.page.find_child("Use_deep_sea_scale_2",true,false).disabled,"A material on the last bag row remains reachable by scrolling")
    await click(ui.page.find_child("Use_deep_sea_scale_2",true,false))
    check(j.party[2].species_id == 368 and j.quantity("deep_sea_tooth") == 1,"Clamperl follows the selected branch and leaves the other material untouched")
    await key_escape()
    check(j.statistics["counts"]["items_used"] == 3 and j.statistics["counts"]["camp_healing"] == 0,"Presentation never repeats evolution or inflates healing")
    print("EVOLUTION_ITEMS_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
