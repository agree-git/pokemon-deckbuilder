extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var first := BattleCardInstance.new(11,"move_33",1)
    var second := BattleCardInstance.new(12,"move_33",1)
    var other := BattleCardInstance.new(13,"move_33",2)
    var upgraded := BattleCardInstance.new(14,"move_33",1)
    upgraded.upgraded = true
    var views: Array[Dictionary] = []
    for card: BattleCardInstance in [first,other,second,upgraded]:
        var view := TacticalContent.definition(card)
        view["owner_name"] = "같은 이름"
        view["species_id"] = 1
        views.append(view)
    var before := views.duplicate(true)
    var stacks := CardStacks.group(views)
    check(stacks.size() == 3 and stacks[0]["count"] == 2,"Identical copies group even when separated by another owner")
    check(stacks.map(func(s: Dictionary): return s["view"]["uid"]) == [11,13,14],"First appearance and representative identities are stable")
    check(stacks[1]["count"] == 1 and stacks[2]["count"] == 1,"Same-name owners and upgraded cards remain separate")
    check(views == before and first.uid == 11 and second.uid == 12 and not first.upgraded,"Grouping cannot mutate source views or card instances")
    stacks[0]["view"]["name"] = "미리보기"
    check(views == before,"Returned views are detached from the live source")
    var changed := views[0].duplicate(true)
    changed["cost"] = 0
    views.append(changed)
    changed = views[0].duplicate(true)
    changed["retained"] = true
    views.append(changed)
    check(CardStacks.group(views).size() == 5,"Temporary cost and retention differences never disappear into a stack")
    check(CardStacks.group([]).is_empty(),"Empty piles have no phantom card")
    var many: Array[Dictionary] = []
    for i in 100:
        var view := views[0].duplicate(true)
        view["uid"] = 100+i
        many.append(view)
    var stack := CardStacks.group(many)[0]
    var face := CardStackView.new()
    face.key = stack["view"]["key"]
    face.definition = stack["view"]
    face.stack_count = stack["count"]
    root.add_child(face)
    await process_frame
    check(face.count_label.text == "×100" and face.backs.size() == 2,"Large counts have exact numbers and bounded visual depth")
    check(face.disabled and face.face.modulate == Color.WHITE,"Browsing stacks remain readable and cannot play cards")
    for back: Panel in face.backs:
        check(Rect2(Vector2.ZERO,face.size).encloses(Rect2(back.position,back.size)),"Stack layers fit the stable input envelope")
    face.free()
    print("CARD_STACKS: ",checks," checks, ",failures," failures")
    quit(0 if failures == 0 else 1)
