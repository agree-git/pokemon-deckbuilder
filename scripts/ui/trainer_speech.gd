class_name TrainerSpeech
extends Panel
## Temporary speech during locked presentation, or a persistent result quote.
const W = preload("res://scripts/ui/combat_widgets.gd")
var compact := false
var speaker: Label
var quote: Label
var symbol: TextureRect
var phase := ""
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel",W.box(Color(0.035,0.075,0.095,0.97),Color("897b55"),10))
    symbol = W.icon(self,"badge",Rect2(16,12,24,24))
    speaker = W.label(self,"",Rect2(50,8,size.x-68,30),17 if compact else 19,W.GOLD)
    quote = W.label(self,"",Rect2(20,36 if compact else 44,size.x-40,48 if compact else 72),20 if compact else 24,W.TEXT)
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hide()
func present(trainer: Dictionary,event: String) -> void:
    phase = event
    quote.text = TrainerDialogue.line(trainer,event)
    speaker.text = TrainerDialogue.title(trainer)+(" · 마지막 포켓몬" if event == "last" else "")
    symbol.texture = W.texture("badge" if trainer.get("kind","") == "champion" or trainer.get("mixed",false) else str(trainer.get("type","normal")))
    tooltip_text = speaker.text+"\n"+quote.text
    visible = not quote.text.is_empty()
