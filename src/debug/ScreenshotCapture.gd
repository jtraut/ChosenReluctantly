class_name ScreenshotCapture
extends Node
## Saves viewport PNGs at the requested elapsed times, then quits cleanly.
## Added by Main only when capture args are present; needs a real renderer.

var times: Array[float] = []
var out: String = CaptureArgs.DEFAULT_OUT

var _elapsed: float = 0.0
var _index: int = 0
var _busy: bool = false


func _process(delta: float) -> void:
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
