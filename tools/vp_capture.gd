extends SceneTree
## QA experiment: render the real Main scene inside an oversized SubViewport and
## save a PNG, bypassing the OS window clamp. Needs a renderer (not --headless).
## godot --path . --script tools/vp_capture.gd -- 2560 1440 out.png
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var w: int = int(args[0]) if args.size() > 0 else 1920
	var h: int = int(args[1]) if args.size() > 1 else 1080
	var out: String = args[2] if args.size() > 2 else "screenshots/vp.png"
	var sub := SubViewport.new()
	sub.size = Vector2i(w, h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	sub.add_child(main)
	# Known limit: current_scene must be a child of root, so enemy/player spawns
	# that use get_tree().current_scene log script errors here (HUD/layout unaffected).
	for i in range(90):
		await process_frame
	var img: Image = sub.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
