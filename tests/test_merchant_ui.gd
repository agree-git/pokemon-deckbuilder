extends SceneTree
var native := false
var checks := 0
var failures := 0
var clicks := 0
var ui: TacticalJourneyUI
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func settle() -> void:
    UiMotion.finish_tree(ui)
    UiMotion.finish_tree(ui)
func click(control: Control,vertical := 0.5) -> void:
    settle()
    var local: Vector2 = control.visible_point(vertical) if control is TrainerActionCard else Vector2(control.size.x/2,lerpf(3,control.size.y-3,vertical))
    var at := root.get_final_transform()*(control.get_global_transform_with_canvas()*local)
    if native:
        at += Vector2(root.position)
        print("OS_CLICK ",roundi(at.x)," ",roundi(at.y))
        await create_timer(0.20).timeout
    else:
        TacticalUIPlayer.click(self,control,local)
        await process_frame
    clicks += 1
    settle()
    await process_frame
func picture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    var prior := root.size
    root.size = Vector2i(1920,1080)
    await process_frame
    settle()
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("/tmp/pokemon-shop/"+label+".png") == OK,"Save actual rendered shop for visual inspection")
    root.size = prior
    root.position = Vector2i.ZERO
    await process_frame
    if native:
        print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
        await create_timer(0.15).timeout
func run() -> void:
    DirAccess.make_dir_recursive_absolute("/tmp/pokemon-shop")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1280,720)
    root.position = Vector2i.ZERO
    var j := TacticalJourney.new(2026,"field_kit",[1,4,7],true)
    for i in j.route.stops.size():
        if j.route.stops[i]["kind"] == "rest" and j.route.stops[i]["camp"]["kind"] == "merchant":
            j.phase = TacticalJourney.MAP
            j.step = i
            j.enter_next()
            break
    j.gold = 500 # Funds fixture; every purchase below uses real UI input.
    var session := root.get_node("BattleSession")
    session.set("profile",PlayerProfile.new("user://tests/shop_ui_collection.json"))
    session.set("save_store",JourneySave.new("user://tests/shop_ui_journey.json"))
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
    check(ui.page.find_children("ShopCard_*","Button",true,false).size() == 3,"Shop shows three complete card faces")
    var technique: TrainerActionCard = ui.page.find_child("ShopCard_2",true,false)
    check(technique.definition["species_id"] > 0 and not technique.definition["owner_name"].is_empty(),"Technique stock includes the actual owner sprite and name")
    check(j.shop_cards().filter(func(o: Dictionary): return o["sale"]).size() == 1,"Exactly one displayed offer has a sale quote")
    await picture("stock")
    var initial := j.deck.size()
    for i in 3:
        root.size = [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800)][i]
        root.position = Vector2i.ZERO
        await process_frame
        settle()
        if native:
            print("OS_FOCUS ",DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
            await create_timer(0.1).timeout
        var stock := j.shop_cards().duplicate(true)
        var gold := j.gold
        var button: Button = ui.page.find_child("BuyCard_%d" % i,true,false)
        check(not button.disabled and button.text.contains(str(stock[i]["price"])),"Buy button advertises its exact stored price")
        await click(button,[0.08,0.5,0.92][i])
        check(j.deck.size() == initial+i+1 and j.gold == gold-int(stock[i]["price"]) and j.shop_cards()[i]["sold"],"Top/center/bottom pointer purchase works at three window ratios")
        var sold: Button = ui.page.find_child("BuyCard_%d" % i,true,false)
        check(sold.disabled and sold.text == "판매 완료","Bought card remains visible with disabled sold state")
        var data := JourneySnapshot.encode(j)
        await click(sold)
        check(JourneySnapshot.encode(j) == data,"Clicking sold stock has no effect")
        if i == 0:
            await click(ui.deck_button)
            check(ui.deck_open,"Deck viewer opens for comparing shop offers")
            var before := j.gold
            await click(ui.page.find_child("BuyCard_1",true,false))
            check(j.gold == before and not j.shop_cards()[1]["sold"],"Deck modal blocks buying through the overlay")
            await click(ui.deck_close)
    await picture("sold-stock")
    var gold := j.gold
    var balls := j.balls
    await click(ui.page.find_child("Buy_ball",true,false))
    check(j.balls == balls+1 and j.gold == gold-35,"Compact supplies column still buys the correct item")
    gold = j.gold
    var count := j.deck.size()
    var price := j.removal_price()
    var target := j.deck[0].uid
    await click(ui.page.find_child("Remove",true,false))
    check(ui.deck_open,"Removal button opens the priced card selector")
    await click(ui.page.find_child("Card_%d" % target,true,false))
    check(ui.removal_preview_uid == target and j.deck.size() == count and j.gold == gold,"Selecting removal opens a preview before spending gold")
    await click(ui.page.find_child("RemovalConfirm",true,false))
    check(not ui.deck_open and j.deck.size() == count-1 and j.gold == gold-price,"Removal shares the same limited gold budget")
    check(ui.page.find_child("Remove",true,false).disabled,"Removal remains once per merchant")
    await click(ui.camp_tabs["rest"])
    check(not ui.rest_button.disabled,"Shopping and removal preserve the rest/upgrade choice")
    await click(ui.rest_button)
    check(j.step in j.rested_steps,"Rest remains usable after shopping")
    await click(ui.camp_tabs["shop"])
    check(ui.page.find_child("BuyCard_0",true,false).disabled and j.shop_stock["ball"] == 3,"Tab changes preserve sold cards and item stock")
    var saved: TacticalJourney = session.get("save_store").load_journey()
    check(saved != null and JourneySnapshot.encode(saved) == JourneySnapshot.encode(j),"Real UI actions autosave exact quotes, cards, gold, removal and rest")
    j.gold = 0
    ui.refresh()
    await process_frame
    check(ui.page.find_child("Buy_ball",true,false).disabled,"Unaffordable supplies clearly disable purchases")
    await picture("finished")
    # A compatible existing shop displays its retained supplies-only inventory.
    j.camp().erase("card_offers")
    ui.refresh()
    await process_frame
    check(ui.page.find_children("ShopCard_*","Button",true,false).is_empty() and ui.page.find_child("Buy_ball",true,false) != null,"Legacy shop remains usable without silently generating new card stock")
    ui.free()
    print("MERCHANT_UI native=",native,": ",checks," checks, ",failures," failures; ",clicks," pointer actions")
    quit(0 if failures == 0 else 1)
