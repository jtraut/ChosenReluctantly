class_name TestClock
extends RefCounted
## Test helper: wait a real (wall-clock) number of seconds.
##
## Do NOT use SceneTree.create_timer(t, true, false, true) (ignore_time_scale) for this. Godot divides the
## frame delta by the CURRENT Engine.time_scale, so a frame that ran at 1.0 and is counted after a hit-stop
## set the scale to 0.1 is overcounted 10x and the timer fires early (measured: a 0.1 s timer fired after
## 76 ms). That made a 50 ms hit-stop look still running in pause_6a_test (C1-t).
## process_frame keeps firing while the tree is paused, and is not affected by the time scale.


## Waits until `seconds` of wall-clock time have passed, then one more frame so every _process has seen it.
static func wait_real(tree: SceneTree, seconds: float) -> void:
	var end_msec: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
	await tree.process_frame
