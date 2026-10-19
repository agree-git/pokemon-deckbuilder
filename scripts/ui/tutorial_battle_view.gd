extends TacticalUI
## Action gates belong to practice UI, never to the normal combat engine.
var teacher: Node
func _card(uid:int) -> void:
    if teacher.permits("card",uid):super._card(uid)
    else:_notify("금색 테두리로 표시한 카드부터 사용해 보세요.")
func _switch(uid:int) -> void:
    _notify("다른 동료의 기술 카드를 사용하면 추가 교대 비용이 없습니다.")
func _end() -> void:
    if teacher.permits("end"):super._end()
    else:_notify("안내한 행동을 먼저 연습해 보세요.")
func _capture() -> void:
    if teacher.permits("capture"):super._capture()
    else:_notify("포획은 잠시 뒤 별도 상황에서 연습합니다.")
func _skill(_key:String) -> void:pass
func restart(_selected_relic:String="") -> void:teacher.restart_lesson()
func _home() -> void:teacher.leave(false)
func _opening_cries() -> void:
    # A practice phase can replace this view before its deferred entrance runs.
    if is_inside_tree():super._opening_cries()
