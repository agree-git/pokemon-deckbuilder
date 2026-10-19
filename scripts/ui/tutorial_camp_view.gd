extends TacticalJourneyUI
var teacher: Node
func _camp_rest() -> void:
    if teacher.permits("rest"):super._camp_rest()
    else:_hint()
func _select_deck_action(action:String) -> void:
    if action=="upgrade" and teacher.permits("upgrade"):super._select_deck_action(action)
    else:_hint()
func _apply_deck_action(uid:int) -> void:
    if deck_action=="upgrade" and teacher.permits("upgrade"):super._apply_deck_action(uid)
    else:_hint()
func _camp_tab(tab:String) -> void:
    if tab=="rest":super._camp_tab(tab)
    else:_hint()
func _open_machines() -> void:_hint()
func _open_workshop(_initial_mode := "evolution") -> void:_hint()
func _open_preparation() -> void:_hint()
func _leave_camp() -> void:_hint()
func _home() -> void:teacher.leave(false)
func _hint() -> void:
    camp_notice="연습에서는 표시한 휴식·강화를 먼저 해 보세요. 다른 준비 메뉴는 마지막에 안내합니다."
    refresh()
