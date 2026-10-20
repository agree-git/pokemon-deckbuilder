extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func key(code:int,unicode_value:=0,control:=false) -> void:
    var e:=InputEventKey.new();e.keycode=code;e.unicode=unicode_value;e.ctrl_pressed=control;e.pressed=true
    Input.parse_input_event(e)
    e=e.duplicate();e.pressed=false;Input.parse_input_event(e)
    for _frame in 4: await process_frame
func frames_for_commit() -> void:
    for _frame in 4: await process_frame
func visible_rows(ui:PokedexWorkshop) -> Array:
    return ui.rows.get_children().filter(func(panel:Control):return panel is Panel and panel.visible)
func run() -> void:
    if not OS.get_user_data_dir().begins_with("/tmp/pokemon-workshop-search/"):quit(2);return
    var j:=TacticalJourney.new(712,"field_kit",[25,4,7],true)
    j.step=1;j.phase=TacticalJourney.MAP;j.enter_next()
    var original:=JourneySnapshot.encode(j)
    var host:=TacticalJourneyUI.new();host.journey=j;root.add_child(host)
    host._open_workshop("moves")
    var ui:PokedexWorkshop=host.workshop
    await process_frame
    var search:TextEdit=ui.content.get_node("WorkshopSearch")
    var ids:=ui.rows.get_children().map(func(node:Node):return node.get_instance_id())
    check(visible_rows(ui).size()==j.training_offers(j.party[0].uid).size(),"Empty query displays the entire legal training catalog")
    check(ui.content.get_node("WorkshopTab_moves").text=="기술 가르침","Move teaching uses the requested name")
    var known_count:=j.party[0].learned_skills.size()
    var all_rows:=visible_rows(ui)
    check(all_rows.slice(0,known_count).all(func(panel:Control):return panel.get_node("WorkshopAction").text=="습득 완료") and all_rows.slice(known_count).all(func(panel:Control):return panel.get_node("WorkshopAction").text!="습득 완료"),"Already learned moves appear before every unlearned move")
    search.grab_focus()
    var expected:=""
    for letter:String in "전광석화":
        await key(0,letter.unicode_at(0));expected+=letter
        check(search.text==expected and ui.query==expected and search.has_focus(),"Continuous committed Korean input retains text and keyboard focus")
        check(ids==ui.rows.get_children().map(func(node:Node):return node.get_instance_id()),"Filtering does not replace any result Controls during input")
    check(not ui.empty_label.visible and visible_rows(ui).size()==1,"Full Korean move name finds its single matching technique")
    await key(KEY_A,0,true)
    for n:int in [1,2,9]:await key(KEY_0+n,48+n)
    check(search.text=="129" and ui.query=="129" and search.has_focus(),"Select-all and three physical number keys replace the query without activating camp shortcuts")
    check(visible_rows(ui).size()==1 and not ui.empty_label.visible,"Multi-character move number finds Swift")
    await key(KEY_LEFT)
    await key(KEY_0,48)
    check(search.text=="1209" and search.get_caret_column()==3 and ui.empty_label.visible,"Insertion in the middle preserves caret and filters results")
    await key(KEY_BACKSPACE)
    check(search.text=="129" and search.get_caret_column()==2 and visible_rows(ui).size()==1,"Backspace edits at the caret without recreating rows")
    await key(KEY_A,0,true)
    await key(KEY_BACKSPACE)
    check(search.text.is_empty() and visible_rows(ui).size()==j.training_offers(j.party[0].uid).size() and search.has_focus(),"Clearing the query restores the full existing list")
    var empty_id:=ui.empty_label.get_instance_id()
    for letter:String in "전기": await key(0,letter.unicode_at(0))
    check(ui.query=="전기" and not visible_rows(ui).is_empty() and ui.empty_label.get_instance_id()==empty_id,"Committed Korean text and type search work without creating empty labels")
    check(visible_rows(ui).all(func(panel:Control):return str(panel.get_meta("search_terms")).contains("전기")),"Displayed results match the current query")
    check(ui.rows.get_children().map(func(node:Node):return node.get_instance_id())==ids,"Result node identity remains stable through edit/delete/type search")
    ui.content.get_node("WorkshopTab_machines").pressed.emit()
    await process_frame
    var machine_search:TextEdit=ui.content.get_node("WorkshopSearch")
    machine_search.grab_focus()
    for letter:String in "없는기술":await key(0,letter.unicode_at(0))
    check(machine_search.text=="없는기술" and ui.query=="없는기술" and ui.empty_label.visible,"TM search also accepts multiple Korean characters")
    await key(KEY_ENTER)
    check(machine_search.get_line_count()==1 and machine_search.text=="없는기술","Enter commits search without inserting a hidden new line")
    check(JourneySnapshot.encode(j)==original,"Searching and changing tabs never mutate campaign/save/RNG state")
    machine_search.text="전기\n129"
    machine_search.call("_publish_query")
    await frames_for_commit()
    check(machine_search.get_line_count()==1 and ui.query=="전기 129","Multiline paste stays a single-line search without disturbing IME composition")
    ui.mode="moves";ui.query="";ui.rebuild()
    var p:=j.party[0]
    var fresh_move:=0
    for move:int in j.training_offers(p.uid):
        if TacticalMoves.key_for(move) not in p.learned_skills:fresh_move=move;break
    j.gold=1000
    var price:=j.train_move_price(p.uid,fresh_move)
    ui._train(p.uid,fresh_move,0)
    var learned:=visible_rows(ui).slice(0,p.learned_skills.size())
    var name:String=TacticalMoves.definition(TacticalMoves.key_for(fresh_move))["name"]
    check(j.gold==1000-price and j.rested_steps.is_empty() and learned.all(func(panel:Control):return panel.get_node("WorkshopAction").text=="습득 완료"),"Teaching keeps existing prices/actions and places the new learned set first")
    check(learned.any(func(panel:Control):return panel.get_children().any(func(node:Node):return node is Label and node.text.contains(" · "+name+" · "))),"Newly taught move appears in the top learned section")
    await key(KEY_ESCAPE)
    await process_frame
    check(not is_instance_valid(host.workshop),"Escape closes the workshop even while typing")
    host.free()
    await process_frame
    print("WORKSHOP_SEARCH ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
