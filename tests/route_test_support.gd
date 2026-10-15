extends RefCounted
## Existing battle/capture tests skip rest decisions; full route tests exercise them.
static func next_encounter(run: RunState) -> String:
    var reason := run.next_battle()
    if not reason.is_empty():
        return reason
    while run.phase in [RunState.MAP,RunState.REST]:
        reason = run.choose_node(0) if run.phase == RunState.MAP else run.rest("skip")
        if not reason.is_empty():
            return reason
    return "" if run.phase == RunState.BATTLE else "원정 종료"
