class_name ScreenshotCapture
extends Node
## Saves viewport PNGs at the requested elapsed times, then quits cleanly.
## Added by Main only when capture args are present; needs a real renderer.

var times: Array[float] = []
var out: String = CaptureArgs.DEFAULT_OUT
## When set (--at-boss-attack=<id>), `times` count from the moment a boss starts winding up that attack, not from launch.
var anchor_boss_attack: String = ""
## Real seconds to wait for the anchor attack before giving up (a capture that never fires must fail, not hang).
const ANCHOR_TIMEOUT := 90.0

var _elapsed: float = 0.0
var _index: int = 0
var _busy: bool = false
var _anchored: bool = true
var _waited: float = 0.0


func _ready() -> void:
	if anchor_boss_attack == "":
		return
	_anchored = false
	for node: Node in get_parent().get_children():
		_watch(node)
	get_tree().node_added.connect(_watch)


func _watch(node: Node) -> void:
	if node is Boss and not (node as Boss).attack_telegraphed.is_connected(_on_attack_telegraphed):
		(node as Boss).attack_telegraphed.connect(_on_attack_telegraphed)


func _on_attack_telegraphed(attack_id: String, _label: String, _windup: float) -> void:
	if not _anchored and attack_id == anchor_boss_attack:
		_anchored = true
		_elapsed = 0.0
		print("ScreenshotCapture: boss started '%s', shots count from here" % attack_id)


func _process(delta: float) -> void:
	if not _anchored:
		_waited += delta
		if _waited > ANCHOR_TIMEOUT:
			push_error("ScreenshotCapture: no boss started '%s' within %d s" % [anchor_boss_attack, int(ANCHOR_TIMEOUT)])
			get_tree().quit(1)
		return
	_elapsed += delta
	if _busy or _index >= times.size() or _elapsed < times[_index]:
		return
	_busy = true
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path := CaptureArgs.output_path(out, _index, times.size())
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("ScreenshotCapture: no image (headless has no renderer; run windowed)")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := image.save_png(path)
	if err != OK:
		push_error("ScreenshotCapture: failed to save '%s' (error %d)" % [path, err])
		get_tree().quit(1)
		return
	print("ScreenshotCapture: saved ", ProjectSettings.globalize_path(path))
	_index += 1
	_busy = false
	if _index >= times.size():
		get_tree().quit()
