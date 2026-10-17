extends SceneTree
func _initialize() -> void:
    var failures := 0
    for id: int in RareEncounter.IDS:
        var cry: AudioStream = load("res://assets/audio/cries/%d.ogg" % id)
        if cry == null or cry.get_length() <= 0:
            failures += 1
            push_error("Unable to decode cry "+str(id))
    print("RARE_AUDIO: 103 decoded / ",failures," failures")
    quit(0 if failures == 0 else 1)
