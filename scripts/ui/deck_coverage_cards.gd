class_name DeckCoverageCards
extends RefCounted
const W = preload("res://scripts/ui/combat_widgets.gd")
static func draw(parent: Control, coverage: Array, origin: Vector2, prefix: String) -> void:
    for i in coverage.size():
        var row: Dictionary = coverage[i]
        var foe: Dictionary = row["opponent"]
        var cell := W.panel(parent,Rect2(origin+Vector2(i*201,0),Vector2(188,174)),Color("20383e"),Color("405960"))
        W.sprite(cell,int(foe["id"]),Rect2(70,4,48,48))
        W.label(cell,foe["name"],Rect2(4,52,180,28),16,W.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        for k in 3:
            var key: String = ["attack","strong","conditional"][k]
            var values: Array = row[key]
            var color := Color("a4d6b1") if values[1] > values[0] else (Color("e8a38d") if values[1] < values[0] else W.MUTED)
            W.label(cell,"%s %d → %d" % [["공격","약점","지속·조건"][k],values[0],values[1]],Rect2(6,84+k*27,176,26),16,color,HORIZONTAL_ALIGNMENT_CENTER).name = "%s_%s_%d" % [prefix,key,i]
