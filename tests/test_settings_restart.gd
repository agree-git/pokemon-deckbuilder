extends SceneTree
## Run twice in the same isolated user directory: first --write, then --read.
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var preferences := root.get_node("Preferences")
    if "--write" in OS.get_cmdline_user_args():
        preferences.set_battle_speed(1.5)
        preferences.set_hit_motion(false)
        preferences.set_display_mode("windowed")
        preferences.set_audio_volume("master", 0.35)
        preferences.set_audio_volume("effects", 0.6)
        preferences.set_audio_volume("music", 0.45)
        preferences.set_audio_muted(true)
        if not preferences.last_error.is_empty(): quit(1); return
        print("SETTINGS RESTART: preferences written")
    elif "--read" in OS.get_cmdline_user_args():
        if preferences.battle_speed != 1.5 or preferences.hit_motion or preferences.display_mode != "windowed" or preferences.master_volume != 0.35 or preferences.effects_volume != 0.6 or not preferences.audio_muted or preferences.music_volume != 0.45:
            push_error("A new process did not load its preferences")
            quit(1)
            return
        print("SETTINGS RESTART: display, animation and all audio preferences restored by startup")
    else:
        quit(1)
        return
    quit(0)
