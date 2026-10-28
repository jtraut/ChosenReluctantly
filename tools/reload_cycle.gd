extends Node
## Real scene-reload soak test for Slice 1 (death and game over).
## Loads the real Main scene, then repeatedly: kill the player, wait for
## game_over_ready, restart_arena() (called twice on purpose), and check the
## fresh arena. Also covers a restart issued mid slow-mo and a restart while
## the old scene still has a pending death-beat timer.
##
## Runs as a scene (autoloads like Juice are only resolvable that way).
## Run: powershell -File tools\run_reload_cycle.ps1 [-Cycles 5]
## Exits 0 on success, 1 on any failed check. Engine errors (push_error, script
## errors) are NOT caught here; the wrapper script scans the output for them.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const SETTLE_FRAMES := 8
const BEAT_TIMEOUT_MSEC := 6000

var _failures: Array[String] = []
var _cycles: int = 5


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="):
			_cycles = maxi(1, int(arg.substr(9)))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
		print("  FAIL: " + message)


func _main() -> Main:
	return get_tree().current_scene as Main


func _enemy_count(main: Node) -> int:
	var count := 0
	for child in main.get_children():
		if child is Enemy:
			count += 1
	return count


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _snapshot(label: String) -> Dictionary:
	var snap := {
		"label": label,
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"time_scale": Engine.time_scale,
	}
	print("  [%s] orphans=%d objects=%d nodes=%d time_scale=%s" % [label, snap["orphans"], snap["objects"], snap["nodes"], snap["time_scale"]])
	return snap


## Fresh-arena invariants, checked after every (re)load.
func _check_fresh(label: String) -> void:
	var main := _main()
	_check(main != null, "%s: no current_scene Main" % label)
	if main == null:
		return
	var player := main.player
	_check(not main.is_game_over(), "%s: is_game_over() still true" % label)
	_check(not player.is_dead(), "%s: player still dead" % label)
	_check(is_equal_approx(player.health.current_health, player.health.get_max_health()), "%s: HP %s not full" % [label, player.health.current_health])
	_check(player.health.current_health > 0.0, "%s: HP not above 0" % label)
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s: time_scale %s" % [label, Engine.time_scale])
	_check(not get_tree().paused, "%s: tree paused" % label)
	_check(main.enemy_spawner.enemies_per_wave == _enemy_count(main), "%s: enemy count %d != first wave %d" % [label, _enemy_count(main), main.enemy_spawner.enemies_per_wave])
	_check(float(main.enemy_spawner.get("_wave_timer")) > main.enemy_spawner.wave_interval - 1.0, "%s: wave timer %s not reset to interval" % [label, main.enemy_spawner.get("_wave_timer")])
	_check(is_instance_valid(main.camera_rig) and main.camera_rig.camera.current, "%s: no current camera" % label)
	var go: Node = main.get_node_or_null("GameOverScreen")
	_check(go != null and not (go as CanvasLayer).visible, "%s: Game Over screen missing or visible on fresh arena" % label)

func _wait_game_over(main: Main) -> bool:
	var deadline := Time.get_ticks_msec() + BEAT_TIMEOUT_MSEC
	while not main.is_game_over() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return main.is_game_over()


func _kill(main: Main) -> void:
	main.player.health.take_damage(main.player.health.get_max_health() * 2.0, "physical")


func _run() -> void:
	var packed: PackedScene = load(MAIN_PATH)
	var first: Node = packed.instantiate()
	get_tree().root.add_child(first)
	get_tree().current_scene = first
	# The first instance was added before it was current_scene, so its Game Over
	# screen could not find Main in _ready. Bind by hand; every reloaded arena
	# (cycles 1..N) goes through the real reload path and binds itself.
	(first.get_node("GameOverScreen") as GameOverScreen).bind(first)
	await _frames(SETTLE_FRAMES)
	print("Reload cycle soak: %d full cycles + mid-slow-mo + double-call" % _cycles)
	_check_fresh("initial")
	var baseline := _snapshot("baseline")
	var snaps: Array[Dictionary] = []

	for cycle in range(1, _cycles + 1):
		var main := _main()
		var old_id := main.get_instance_id()
		_kill(main)
		_check(main.player.is_dead(), "cycle %d: player not dead after lethal damage" % cycle)
		_check(is_equal_approx(Engine.time_scale, 0.25), "cycle %d: slow-mo not active (time_scale %s)" % [cycle, Engine.time_scale])
		# Hit again while dead: must not die twice or restart anything.
		main.player.health.take_damage(5.0, "physical")
		var reached := await _wait_game_over(main)
		_check(reached, "cycle %d: game_over_ready never fired within %d ms" % [cycle, BEAT_TIMEOUT_MSEC])
		_check((main.get_node("GameOverScreen") as CanvasLayer).visible, "cycle %d: Game Over screen not visible" % cycle)
		# Juice resets time_scale by wall clock in its own _process; the Game Over timer can fire
		# a frame earlier than that clock, so allow a short grace period (a real leak never ends).
		var grace_deadline := Time.get_ticks_msec() + 250
		await _frames(2)
		while not is_equal_approx(Engine.time_scale, 1.0) and Time.get_ticks_msec() < grace_deadline:
			await get_tree().process_frame
		_check(is_equal_approx(Engine.time_scale, 1.0), "cycle %d: time_scale %s after beat" % [cycle, Engine.time_scale])
		main.restart_arena()
		main.restart_arena()  # double-call must be ignored
		await _frames(SETTLE_FRAMES)
		_check(_main() != null and _main().get_instance_id() != old_id, "cycle %d: scene was not replaced" % cycle)
		_check(not is_instance_valid(main), "cycle %d: old Main not freed" % cycle)
		_check_fresh("cycle %d" % cycle)
		snaps.append(_snapshot("cycle %d" % cycle))

	# Restart issued mid slow-mo, before game_over_ready.
	var mid := _main()
	var mid_id := mid.get_instance_id()
	_kill(mid)
	await _frames(3)
	_check(is_equal_approx(Engine.time_scale, 0.25), "mid-slow-mo: time_scale %s, expected 0.25" % Engine.time_scale)
	_check(not mid.is_game_over(), "mid-slow-mo: game over announced too early")
	mid.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != mid_id, "mid-slow-mo: scene not replaced")
	_check_fresh("mid-slow-mo restart")
	# Outlive the old beat timer (0.9 s wall clock): nothing should fire on the new scene.
	var wait_until := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < wait_until:
		await get_tree().process_frame
	_check(not _main().is_game_over(), "stale beat timer announced game over on the new arena")
	_check(is_equal_approx(Engine.time_scale, 1.0), "stale beat: time_scale %s" % Engine.time_scale)
	snaps.append(_snapshot("after mid-slow-mo"))

	# Orphan / object growth: compare last full cycle to the first.
	if snaps.size() >= 2:
		var first_cycle: Dictionary = snaps[0]
		var last_cycle: Dictionary = snaps[_cycles - 1]
		_check(int(last_cycle["orphans"]) <= int(first_cycle["orphans"]) + 2, "orphan nodes grew: %d -> %d" % [first_cycle["orphans"], last_cycle["orphans"]])
		_check(int(last_cycle["nodes"]) <= int(first_cycle["nodes"]) + 40, "node count grew: %d -> %d" % [first_cycle["nodes"], last_cycle["nodes"]])
		_check(int(last_cycle["objects"]) <= int(first_cycle["objects"]) + 200, "object count grew: %d -> %d" % [first_cycle["objects"], last_cycle["objects"]])
	print("baseline orphans=%d objects=%d" % [baseline["orphans"], baseline["objects"]])

	if _failures.is_empty():
		print("RELOAD CYCLE OK")
		get_tree().quit(0)
	else:
		print("RELOAD CYCLE FAILED: %d problem(s)" % _failures.size())
		get_tree().quit(1)
