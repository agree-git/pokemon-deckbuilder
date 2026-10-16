class_name BattleHandLayout
extends Control
## Keep every card in the hand area; compress spacing after five cards.
const EDGE := 24.0
const MAX_STEP := 214.0
const CARD_Y := 32.0
var _cards: Array[TrainerActionCard] = []
var _focused: TrainerActionCard
func arrange(cards: Array[TrainerActionCard]) -> void:
    _cards.assign(cards)
    if not is_instance_valid(_focused) or _focused not in _cards: _focused = null
    for i in cards.size():
        var card := cards[i]
        move_child(card,i)
        if not card.hand_hover_changed.is_connected(_on_hover): card.hand_hover_changed.connect(_on_hover)
    _layout()
func _on_hover(card: TrainerActionCard,value: bool) -> void:
    if value: _focused = card
    elif _focused == card: _focused = null
    call_deferred("_layout")
func _layout() -> void:
    _cards = _cards.filter(func(card: TrainerActionCard): return is_instance_valid(card) and card.get_parent() == self and not card.is_queued_for_deletion())
    if not is_instance_valid(_focused) or _focused not in _cards: _focused = null
    var cards := _cards
    if cards.is_empty(): return
    var step := minf(MAX_STEP,(size.x-2*EDGE-TrainerActionCard.SLOT_SIZE.x)/maxi(1,cards.size()-1))
    var width := TrainerActionCard.SLOT_SIZE.x+step*(cards.size()-1)
    var left := (size.x-width)/2.0
    var focused := cards.find(_focused)
    var extra := maxf(20,TrainerActionCard.FACE_SIZE.x*1.05+10-step)
    var targets: Array[Vector2] = []
    for i in cards.size():
        var x := left+i*step
        # Keep the focused card under the pointer. Nearby cards move furthest;
        # the outer cards move less so the entire hand stays inside its area.
        if focused >= 0 and i < focused:
            x -= minf(extra*(i+1)/focused,maxf(0,x-12))
        elif focused >= 0 and i > focused:
            x += minf(extra*(cards.size()-i)/(cards.size()-focused-1),maxf(0,size.x-12-TrainerActionCard.SLOT_SIZE.x-x))
        targets.append(Vector2(x,CARD_Y))
    for i in cards.size():
        var card := cards[i]
        card.hand_exposed_width = targets[i+1].x-targets[i].x if i < cards.size()-1 else TrainerActionCard.FACE_SIZE.x
        var target := targets[i]
        if card.has_meta("hand_home") and card.get_meta("hand_home") != target:
            UiMotion.begin(card,"hand_position").tween_property(card,"position",target,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        elif not card.has_meta("hand_home"):
            card.position = target
        card.set_meta("hand_home",target)
