extends Node
## Headless wave-density bot-sim (Slice 5a, ROADMAP criterion 5). Loads the real Main scene
## (spawner, enemies, player, HUD), seeds the spawner, and plays it with a simple bot that
## uses the real input actions: kite away from the nearest enemy, face it, dodge a telegraph
## that is about to land, heavy attack into groups, press the card slots at random.
##
## Reports per run: survival, damage taken, kills, max and mean alive, cap violations, NaN or
## out-of-arena positions, stalls (waves held back with no progress), and rough per-frame cost.
## Headless frame times exclude rendering, so they are CPU-side game logic only.
##
## Runs as a scene (autoloads resolve only that way). Usage:
##   powershell -File tools\run_wave_sim.ps1 [-Seed 1] [-Seconds 90] [-Runs 3] [-God]
## --god keeps the player alive (9999 HP) so the full wave table and soft locks get exercised.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const STALL_SECONDS := 45.0

var _seed: int = 1
var _seconds: float = 90.0
var _runs: int = 1
var _god: bool = false
var _scale: float = 3.0
var _idle: bool = false
var _clock: float = 0.0
var _issues: Array[String] = []

var _main: Main
var _player: Player
var _sim_time: float = 0.0
var _release_next: Array[StringName] = []
var _rng := RandomNumberGenerator.new()
var _dodge_cooldown_until: float = 0.0
var _heavy_until: float = 0.0
var _kills: int = 0
var _casts: int = 0
var _damage_taken: float = 0.0
var _last_hp: float = 0.0
var _max_alive: int = 0
var _alive_time_sum: float = 0.0
var _cap_violations: int = 0
var _last_stage_count: int = 0
var _last_progress_time: float = 0.0
var _max_stall: float = 0.0
var _frame_times_ms: Array[float] = []
var _physics_ms_sum: float = 0.0
var _process_ms_sum: float = 0.0
var _perf_samples: int = 0
var _died_at: float = -1.0
## Crowd spacing metric (5d): per frame with 2+ non-ranged enemies within NEAR_RADIUS of the player,
## the smallest pairwise distance among them. Reported as the mean, the minimum, and the share of
## those frames at or above SPACING_OK.
var NEAR_RADIUS: float = EnemyConfig.near_player_radius()
var SPACING_OK: float = EnemyConfig.readable_spacing()
var _pair_frames: int = 0
var _pair_ok_frames: int = 0
var _pair_min_sum: float = 0.0
var _pair_min_all: float = INF
## Pinned-stretch metric (C1-c, read-only): a frame is "pinned" when the bot commanded movement last
## frame but the player moved under PIN_FRACTION of the distance that speed allows. Reports the count
## and the longest unbroken stretch, so solid enemies (body.collide_with_enemies) can be judged.
const PIN_FRACTION := 0.25
var _pin_want: Vector3 = Vector3.ZERO
var _pin_prev_pos: Vector3 = Vector3.ZERO
var _pin_frames: int = 0
var _pin_streak: int = 0
var _pin_streak_max: int = 0
var _pin_frames_total: int = 0
## Highest the player's feet got and the frames above CLIMB_Y: solid enemies must never let it stand on a head.
const CLIMB_Y := 0.3
var _max_player_y: float = 0.0
var _climb_frames: int = 0


## --trace: print the state hash once per sim second (find where two runs of a seed diverge).
var _trace: bool = false
var _trace_next: float = 1.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--runs="):
			_runs = maxi(1, int(arg.substr(7)))
		elif arg.begins_with("--scale="):
			_scale = clampf(float(arg.substr(8)), 1.0, 8.0)
		elif arg == "--idle":
			_idle = true
		elif arg == "--god":
			_god = true
		elif arg == "--trace":
			_trace = true
	_run_all.call_deferred()


func _run_all() -> void:
	# This node is the main scene; hand "current scene" to a placeholder so change_scene can replace it.
	var placeholder := Node.new()
	placeholder.name = "Placeholder"
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	print("Wave sim: %d run(s) x %.0f sim-seconds, seed %d (rerun with --seed=%d), %s, time_scale %.0f" % [_runs, _seconds, _seed, _seed, ("god mode" if _god else "real HP") + (", idle bot" if _idle else ""), _scale])
	for run_index in range(_runs):
		await _run_one(_seed + run_index)
	print("")
	if _issues.is_empty():
		print("WAVE SIM OK")
		get_tree().quit(0)
	else:
		print("WAVE SIM FAILED - %d issue(s):" % _issues.size())
		for issue in _issues:
			print(" - " + issue)
		get_tree().quit(1)


func _fail(message: String) -> void:
	if not _issues.has(message):
		_issues.append(message)
		print("  ISSUE: " + message)


func _reset_run_state(run_seed: int) -> void:
	_rng.seed = run_seed
	_sim_time = 0.0
	_clock = 0.0
	_kills = 0
	_casts = 0
	_damage_taken = 0.0
	_max_alive = 0
	_alive_time_sum = 0.0
	_cap_violations = 0
	_last_stage_count = 0
	_last_progress_time = 0.0
	_max_stall = 0.0
	_frame_times_ms.clear()
	_physics_ms_sum = 0.0
	_process_ms_sum = 0.0
	_perf_samples = 0
	_died_at = -1.0
	_pair_frames = 0
	_pin_want = Vector3.ZERO
	_pin_prev_pos = Vector3.ZERO
	_pin_frames = 0
	_pin_streak = 0
	_pin_streak_max = 0
	_pin_frames_total = 0
	_max_player_y = 0.0
	_climb_frames = 0
	_pair_ok_frames = 0
	_pair_min_sum = 0.0
	_pair_min_all = INF
	_dodge_cooldown_until = 0.0
	_heavy_until = 0.0
	_profiled_alive = 0
	_query_usec = 0.0
	_query_calls = 0


func _run_one(run_seed: int) -> void:
	_reset_run_state(run_seed)
	# Status rolls and card shuffles repeat from the seed (S6-4); the spawner and bot RNGs already did.
	Player.default_rng_seed = run_seed
	Juice.hit_stop_enabled = false  # wall-clock hit-stop would break repeatability
	# The real scene-change path (as restart_arena does), so every node sees a proper current_scene.
	get_tree().change_scene_to_packed(load(MAIN_PATH) as PackedScene)
	for i in range(30):
		await get_tree().process_frame
		if get_tree().current_scene is Main:
			break
	var main_node: Node = get_tree().current_scene
	if not (main_node is Main):
		_fail("Main scene did not load")
		return
	_main = main_node as Main
	_player = _main.player
	_player.card_slots.card_cast.connect(func(_slot_type: String, _card_id: String) -> void: _casts += 1)
	_main.enemy_spawner.set_seed(run_seed)
	if _god:
		_player.health.set_max_health(9999.0)
		_player.health.heal(9999.0)
	_last_hp = _player.health.current_health
	Engine.time_scale = _scale
	var wall_start := Time.get_ticks_msec()
	await get_tree().process_frame
	var cap: int = _main.enemy_spawner.plan.max_alive()
	var prev_enemies: Dictionary = {}
	while _sim_time < _seconds and not _player.is_dead():
		var frame_start := Time.get_ticks_usec()
		# Juice's hit-stop/slow-mo hand time_scale back as 1.0, so the speed-up is re-asserted every
		# frame (this also shortens hit-stop in the sim; the sim checks logic, not feel).
		Engine.time_scale = _scale
		await get_tree().process_frame
		# Game time = the sum of the (time-scaled) physics deltas, not wall time.
		var now_time: float = _clock
		var dt: float = now_time - _sim_time
		_sim_time = now_time
		for action in _release_next:
			_release_action(action)
		_release_next.clear()
		var enemies := _enemies()
		_check_world(enemies, cap, dt)
		if enemies.size() > _profiled_alive and enemies.size() >= 5 and not _player.is_dead():
			_profiled_alive = enemies.size()
			_profile_attack_query()  # keeps the busiest sample of the run
		_count_kills(enemies, prev_enemies)
		_sample_spacing(enemies)
		_sample_pin(dt)
		_bot_step(enemies)
		_track_progress()
		if _trace and _sim_time >= _trace_next:
			_trace_next += 1.0
			print("TRACE t=%.2f hash %d hp %.1f enemies %d casts %d" % [_sim_time, _state_hash(), _player.health.current_health, enemies.size(), _casts])
			for e: Enemy in enemies:
				print("   E %s pos %s vel %s hp %.2f" % [e.name, e.global_position, e.velocity, e.health.current_health])
			print("   P pos %s vel %s" % [_player.global_position, _player.velocity])
		_frame_times_ms.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
		_physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_process_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_perf_samples += 1
		var hp: float = _player.health.current_health
		if hp < _last_hp:
			_damage_taken += _last_hp - hp
		_last_hp = hp
		if _god:
			_player.health.heal(9999.0)
			_last_hp = _player.health.current_health
	if _player.is_dead():
		_died_at = _sim_time
	Engine.time_scale = 1.0
	_release_all()
	Player.default_rng_seed = -1
	_report(run_seed, Time.get_ticks_msec() - wall_start)
	Juice.reset()


func _physics_process(delta: float) -> void:
	_clock += delta


func _enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for child in _main.get_children():
		if child is Enemy and not (child as Enemy).health.is_dead():
			list.append(child)
	return list


func _sample_pin(dt: float) -> void:
	var here := _player.global_position
	if not _player.is_dead():
		_max_player_y = maxf(_max_player_y, here.y)
		if here.y > CLIMB_Y:
			_climb_frames += 1
	if _player.is_dead() or dt <= 0.0:
		_pin_streak = 0
	elif _pin_want.length_squared() > 0.0001:
		_pin_frames_total += 1
		var moved := Vector2(here.x - _pin_prev_pos.x, here.z - _pin_prev_pos.z).length()
		if moved < PIN_FRACTION * _player.get_move_speed() * dt:
			_pin_frames += 1
			_pin_streak += 1
			_pin_streak_max = maxi(_pin_streak_max, _pin_streak)
		else:
			_pin_streak = 0
	else:
		_pin_streak = 0
	_pin_prev_pos = here


func _sample_spacing(enemies: Array[Enemy]) -> void:
	if _player.is_dead():
		return
	var me := _player.global_position
	var best: float = INF
	var near: int = 0
	for i in range(enemies.size()):
		var a: Enemy = enemies[i]
		if a.is_ranged or me.distance_to(a.global_position) > NEAR_RADIUS:
			continue
		near += 1
		for j in range(i + 1, enemies.size()):
			var b: Enemy = enemies[j]
			if b.is_ranged or me.distance_to(b.global_position) > NEAR_RADIUS:
				continue
			best = minf(best, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
	if near < 2:
		return
	_pair_frames += 1
	_pair_min_sum += best
	_pair_min_all = minf(_pair_min_all, best)
	if best >= SPACING_OK:
		_pair_ok_frames += 1


func _check_world(enemies: Array[Enemy], cap: int, dt: float) -> void:
	_max_alive = maxi(_max_alive, enemies.size())
	_alive_time_sum += float(enemies.size()) * dt
	if enemies.size() > cap or _main.enemy_spawner.alive_count() > cap:
		_cap_violations += 1
		_fail("alive count %d exceeded the cap %d at t=%.1f" % [enemies.size(), cap, _sim_time])
	var limit: float = float(_main.enemy_spawner.plan.config["arena_half_extent"]) + 3.0
	for enemy in enemies:
		var p := enemy.global_position
		if is_nan(p.x) or is_nan(p.y) or is_nan(p.z) or is_nan(enemy.health.current_health):
			_fail("NaN on an enemy at t=%.1f" % _sim_time)
		elif absf(p.x) > limit or absf(p.z) > limit or p.y < -3.0:
			_fail("enemy left the arena (%s) at t=%.1f" % [str(p), _sim_time])
	var pp := _player.global_position
	if is_nan(pp.x) or is_nan(pp.y) or is_nan(pp.z) or is_nan(_player.health.current_health):
		_fail("NaN on the player at t=%.1f" % _sim_time)
	elif absf(pp.x) > limit or absf(pp.z) > limit or pp.y < -3.0:
		_fail("player left the arena (%s) at t=%.1f" % [str(pp), _sim_time])
	for slot_key: Variant in _player.card_slots.slots.keys():
		var slot: CardSlot = _player.card_slots.slots[slot_key]
		if is_nan(slot.cooldown_remaining):
			_fail("NaN slot cooldown (%s) at t=%.1f" % [str(slot_key), _sim_time])


func _count_kills(enemies: Array[Enemy], prev: Dictionary) -> void:
	var now: Dictionary = {}
	for enemy in enemies:
		now[enemy.get_instance_id()] = true
	for id: Variant in prev.keys():
		if not now.has(id) and not _player.is_dead():
			_kills += 1
	prev.clear()
	prev.merge(now)


## Progress = a wave stage opened or an enemy died. A long stretch with neither while
## enemies stand and the player lives is a stall (the table waits on a gate nobody can open).
func _track_progress() -> void:
	var started: int = _main.enemy_spawner.plan.stages_started()
	var progressed: bool = started != _last_stage_count
	_last_stage_count = started
	if progressed or _kills != int(get_meta("kills_mark", -1)):
		_last_progress_time = _sim_time
		set_meta("kills_mark", _kills)
	_max_stall = maxf(_max_stall, _sim_time - _last_progress_time)
	if _sim_time - _last_progress_time > STALL_SECONDS:
		_fail("stall: no stage opened and no kill for %.0f s (alive %d, next stage %d) at t=%.1f" % [STALL_SECONDS, _main.enemy_spawner.alive_count(), _main.enemy_spawner.plan.next_stage_index(), _sim_time])


# ---- The bot ----

func _press(action: StringName, strength: float = 1.0) -> void:
	if _is_latched_action(action):
		_send_action(action, true)
	else:
		Input.action_press(action, strength)
	_release_next.append(action)


## Light/heavy attacks and card slots are latched from input EVENTS in Player._unhandled_input;
## Input.action_press emits none, so those go through parse_input_event. Movement and dodge poll.
func _is_latched_action(action: StringName) -> bool:
	var text := String(action)
	return text.begins_with("slot_") or text.begins_with("attack_")


func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_action(action: StringName) -> void:
	if _is_latched_action(action):
		_send_action(action, false)
	else:
		Input.action_release(action)


func _hold(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
		_release_next.append(action)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "dodge", "attack_light", "attack_heavy", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]:
		Input.action_release(action)


func _bot_step(enemies: Array[Enemy]) -> void:
	if _idle:
		return  # a player who stands still: only the auto light attack acts (aim is frozen)
	if enemies.is_empty():
		_pin_want = Vector3.ZERO
		_hold_still()
		return
	var me := _player.global_position
	var nearest: Enemy = enemies[0]
	var nearest_d: float = INF
	var crowd: int = 0
	var danger: Enemy = null
	for enemy in enemies:
		var d: float = me.distance_to(enemy.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = enemy
		if d < 3.0:
			crowd += 1
		var wind: float = float(enemy.get("_telegraph_remaining"))
		if wind > 0.0 and wind < 0.2 and d < (enemy.attack_range + 1.0 if not enemy.is_ranged else 9.0):
			danger = enemy
	_player.aim_point_override = nearest.global_position
	# Kite: back off when something is close, close in on a lone enemy, otherwise strafe.
	var away := (me - nearest.global_position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var want: Vector3 = Vector3.ZERO
	if nearest_d < 2.3:
		want = away
	elif nearest_d > 4.5:
		want = -away
	else:
		want = Vector3(-away.z, 0.0, away.x) * (1.0 if int(_sim_time / 3.0) % 2 == 0 else -1.0)
	# Stay inside the arena.
	var limit: float = float(_main.enemy_spawner.plan.config["arena_half_extent"]) - 3.0
	if absf(me.x) > limit or absf(me.z) > limit:
		want = (-me).normalized()
	_pin_want = want
	_drive(want)
	if danger != null and _sim_time >= _dodge_cooldown_until:
		_press(&"dodge")
		_dodge_cooldown_until = _sim_time + 0.9
	if crowd >= 2 and _sim_time >= _heavy_until:
		_press(&"attack_heavy")
		_heavy_until = _sim_time + 1.9
	if _rng.randf() < 0.3:
		_press(StringName("slot_%d" % _rng.randi_range(1, 5)))
	if _rng.randf() < 0.5:
		_press(&"attack_light")


func _hold_still() -> void:
	_drive(Vector3.ZERO)


## World direction -> WASD strengths relative to the camera, the inverse of Player's movement input.
func _drive(world_dir: Vector3) -> void:
	if world_dir.length_squared() < 0.0001 or _player.camera == null:
		return
	var cam := _player.camera.global_transform.basis
	var f := Vector3(-cam.z.x, 0.0, -cam.z.z).normalized()
	var r := Vector3(cam.x.x, 0.0, cam.x.z).normalized()
	var fwd: float = world_dir.dot(f)
	var right: float = world_dir.dot(r)
	_hold(&"move_forward", fwd)
	_hold(&"move_back", -fwd)
	_hold(&"move_right", right)
	_hold(&"move_left", -right)


# ---- Profiling and report ----

var _profiled_alive: int = 0
var _query_usec: float = 0.0
var _query_calls: int = 0


## Cost of Player._attack_has_target, the per-frame physics query, with the arena full.
func _profile_attack_query() -> void:
	if not is_instance_valid(_player) or _player.is_dead() or not _player.is_inside_tree():
		return
	var n: int = 2000
	var start := Time.get_ticks_usec()
	for i in range(n):
		_player._attack_has_target(&"light")
	_query_usec = float(Time.get_ticks_usec() - start) / float(n)
	_query_calls = n


func _percentile(sorted_values: Array[float], q: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return sorted_values[clampi(int(float(sorted_values.size()) * q), 0, sorted_values.size() - 1)]


## Hash of where the player and every enemy stand at the end of the run (rounded to 1 mm).
func _state_hash() -> int:
	var parts: Array = [snappedf(_player.global_position.x, 0.001), snappedf(_player.global_position.z, 0.001), snappedf(_player.health.current_health, 0.001)]
	for enemy: Enemy in _enemies():
		parts.append([snappedf(enemy.global_position.x, 0.001), snappedf(enemy.global_position.z, 0.001), snappedf(enemy.health.current_health, 0.001)])
	return hash(parts)


func _report(run_seed: int, wall_ms: int) -> void:
	var sorted_times := _frame_times_ms.duplicate()
	sorted_times.sort()
	var mean_alive: float = _alive_time_sum / maxf(_sim_time, 0.001)
	print("  seed %d: sim %.0f s in %.1f s wall | %s | HP lost %.0f | kills %d | card casts %d | alive max %d mean %.1f | stages opened %d | max stall %.0f s" % [
		run_seed, _sim_time, float(wall_ms) / 1000.0,
		("died at %.1f s" % _died_at) if _died_at >= 0.0 else "survived",
		_damage_taken, _kills, _casts, _max_alive, mean_alive, _main.enemy_spawner.plan.stages_started(), _max_stall])
	print("    result: seed %d hp_lost %.3f kills %d casts %d alive_max %d stages %d sim_time %.3f state_hash %d" % [
		run_seed, _damage_taken, _kills, _casts, _max_alive, _main.enemy_spawner.plan.stages_started(), _sim_time, _state_hash()])
	print("    pinned: %d of %d move-commanded frames (%.1f%%), longest stretch %d frames (%.2f s)" % [
		_pin_frames, _pin_frames_total, 100.0 * float(_pin_frames) / maxf(float(_pin_frames_total), 1.0), _pin_streak_max, float(_pin_streak_max) / 60.0])
	print("    climb: player feet max y %.3f m, %d frames above %.1f m" % [_max_player_y, _climb_frames, CLIMB_Y])
	print("    spacing (melee within %.0f m of player, %d frames with 2+): mean min-pair %.2f m, worst %.2f m, %.0f%% of frames >= %.1f m" % [
		NEAR_RADIUS, _pair_frames, _pair_min_sum / maxf(float(_pair_frames), 1.0), (_pair_min_all if _pair_frames > 0 else 0.0), 100.0 * float(_pair_ok_frames) / maxf(float(_pair_frames), 1.0), SPACING_OK])
	print("    headless frame ms (wall, each frame steps ~%.0fx physics): p50 %.2f p95 %.2f max %.2f | engine process %.2f ms, physics %.2f ms avg per frame | _attack_has_target %.1f us/call with %d enemies alive (%d calls)" % [
		_scale, _percentile(sorted_times, 0.5), _percentile(sorted_times, 0.95), _percentile(sorted_times, 0.999),
		_process_ms_sum / maxf(float(_perf_samples), 1.0), _physics_ms_sum / maxf(float(_perf_samples), 1.0), _query_usec, _profiled_alive, _query_calls])
