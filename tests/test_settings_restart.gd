extends SceneTree
## Run twice in the same isolated user directory: first --write, then --read.
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var preferences := root.get_node("Preferences")
    if "--write" in OS.get_cmdline_user_args():
        preferences.set_battle_speed(1.5)
        preferences.set_hit_motion(false)
        preferences.set_display_mode("windowed")
        if not preferences.last_error.is_empty(): quit(1); return
        print("SETTINGS RESTART: preferences written")
    elif "--read" in OS.get_cmdline_user_args():
        if preferences.battle_speed != 1.5 or preferences.hit_motion or preferences.display_mode != "windowed":
            push_error("A new process did not load its preferences")
            quit(1)
            return
        print("SETTINGS RESTART: all three preferences restored by startup")
    else:
        quit(1)
        return
    quit(0)
