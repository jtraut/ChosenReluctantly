extends Node
## QA repro (UX1b review): prints MapScreen.human_session() when the game is hosted as a scene (as tools/WaveSim.tscn does, so watch mode) in a window.
## Run windowed: godot --path . res://tools/ProbeHumanSession.tscn   (expect "human_session=true" there; under --headless it is false).

func _ready() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	print("PROBE display=%s loop_script_null=%s human_session=%s" % [DisplayServer.get_name(), str(loop.get_script() == null), str(MapScreen.human_session())])
	get_tree().quit()
