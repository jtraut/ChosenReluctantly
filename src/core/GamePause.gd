extends Node
## Autoload "GamePause": the one pause switch. The settings screen (Slice 6b) calls
## GamePause.pause() when it opens and GamePause.resume() when it closes; nothing else
## should touch get_tree().paused.
##
## What a pause does beyond get_tree().paused:
##  - Juice.freeze_time(): Engine.time_scale goes back to 1.0 (the pause screen is never in
##    slow-mo) and the unfinished part of a hit-stop or the death slow-mo is remembered;
##    resume() hands it back, so the beat finishes as long as it had left, no more, no less.
##  - paused_changed is emitted, and the Player cancels any held card preview (the key
##    release would be lost to the pause, so a fresh press is needed after resuming).
## Nodes that must keep working under a pause (the pause screen itself, the preview
## hiding itself) set process_mode = PROCESS_MODE_ALWAYS.
##
## pause() is refused (returns false) when already paused, when there is no tree, and
## once the Game Over screen is up (it has its own input; "Try again" restarts the arena).

signal paused_changed(is_paused: bool)

var _paused: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_paused() -> bool:
	return _paused


## True if the game is now paused by this call.
func pause() -> bool:
	if _paused or not is_inside_tree() or _game_over_is_up():
		return false
	_paused = true
	Juice.freeze_time()
	get_tree().paused = true
	paused_changed.emit(true)
	return true


## True if the game was paused and now runs again.
func resume() -> bool:
	if not _paused:
		return false
	_paused = false
	if is_inside_tree():
		get_tree().paused = false
	Juice.thaw_time()
	paused_changed.emit(false)
	return true


## Flips the state; returns the new is_paused().
func toggle() -> bool:
	if _paused:
		resume()
	else:
		pause()
	return _paused


## Forgets a pause without signals or time changes. For scene reloads (Main calls it
## after Juice.reset()): the old scene and its listeners are going away.
func reset() -> void:
	_paused = false


func _game_over_is_up() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.has_method("is_game_over") and bool(scene.call("is_game_over"))
