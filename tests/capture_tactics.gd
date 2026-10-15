extends "res://tests/test_deck_ui.gd"
# Render current card combat, rewards and camp instead of the removed break trial.
func _initialize() -> void:
    capture_images = DisplayServer.get_name() != "headless"
    if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
    super._initialize()
