extends Node
## True-size capture: hosts the real Main scene in an oversized SubViewport (the OS window is
## clamped to the monitor, so --resolution cannot exceed it). Needs a renderer (not --headless).
## Run via tools/capture_screenshot.ps1 -TrueSize WxH, or directly:
##   godot --path . res://tools/VpCapture.tscn -- --size=2560x1440 --scenario=waves --screenshot-after=3 --screenshot-out=screenshots/a.png
## Everything except --size is the normal capture args (CaptureArgs); Main reads them itself and its
## ScreenshotCapture node saves the SubViewport texture, then quits the tree cleanly.
## Main registers with WorldRef, so spawners and card effects work although current_scene is null here.

func _ready() -> void:
	var size := Vector2i(1920, 1080)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.substr(7).split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				size = Vector2i(parts[0].to_int(), parts[1].to_int())
			else:
				push_error("vp_capture: bad --size '%s' (need WxH)" % arg)
				get_tree().quit(1)
				return
	# A container forwards real input events (scenario key presses) into the SubViewport.
	var container := SubViewportContainer.new()
	container.stretch = false
	add_child(container)
	var sub := SubViewport.new()
	sub.size = size
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub)
	# --run plays the run (RunMain, the normal launch); without it the endless arena that scenarios use.
	var scene_path := "res://scenes/main/RunMain.tscn" if OS.get_cmdline_user_args().has("--run") else "res://scenes/main/Main.tscn"
	var main: Node = (load(scene_path) as PackedScene).instantiate()
	sub.add_child(main)
	# The Game Over screen binds to current_scene (null here), so bind it by hand.
	(main.get_node("GameOverScreen") as GameOverScreen).bind(main)
