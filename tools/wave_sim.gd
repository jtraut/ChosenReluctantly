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
##
## --run (Milestone 3a): plays WHOLE seeded runs through scenes/main/RunMain.tscn instead of the endless arena
## (--seed is the first run seed, --runs the number of runs). Each run goes room to room until the win, a death or
## a soft lock (a room that does not end within --room-timeout sim seconds, default 240). Reports per run: rooms
## reached, the outcome, the room types, crashes and NaN (the same world checks), and qa N3 checks (an empty deck,
## a stuck cooldown), then the room-type distribution and the per-card pick rates over all runs.

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

# ---- run mode (3a) ----
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
var _run_mode: bool = false
var _room_timeout: float = 240.0
var _run_results: Array[Dictionary] = []
var _card_casts: Dictionary = {}
var _slot_stuck_since: Dictionary = {}
var _room_min_hp: float = INF
## 3b: the reward bot's own stream (seeded per run, so the picks repeat from --seed and never touch the combat bot).
var _policy_rng := RandomNumberGenerator.new()
const REJECT_CHANCE := 0.25
const HEAL_BELOW_FRACTION := 0.7


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
		elif arg == "--run":
			_run_mode = true
		elif arg.begins_with("--room-timeout="):
			_room_timeout = maxf(10.0, float(arg.substr(15)))
	_run_all.call_deferred()


func _run_all() -> void:
	# This node is the main scene; hand "current scene" to a placeholder so change_scene can replace it.
	var placeholder := Node.new()
	placeholder.name = "Placeholder"
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	print("Wave sim: %d run(s) x %.0f sim-seconds, seed %d (rerun with --seed=%d), %s, time_scale %.0f" % [_runs, _seconds, _seed, _seed, ("god mode" if _god else "real HP") + (", idle bot" if _idle else ""), _scale])
	for run_index in range(_runs):
		if _run_mode:
			await _run_whole(_seed + run_index)
		else:
			await _run_one(_seed + run_index)
	if _run_mode:
		_run_summary()
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
	elif _run_mode and _hunting(enemies) and nearest_d > 2.0:
		want = -away  # a room needs its last enemies dead: with only a few left (or only shooters) go and get them
	elif nearest_d > 4.5:
		want = -away
	else:
		want = Vector3(-away.z, 0.0, away.x) * (1.0 if int(_sim_time / 3.0) % 2 == 0 else -1.0)
	# Stay inside the arena.
	var limit: float = float(_main.enemy_spawner.plan.config["arena_half_extent"]) - 3.0
	if absf(me.x) > limit or absf(me.z) > limit:
		want = (-me).normalized()
	# Run mode, boss fight: leave the area of a wind-up by the shortest way (Boss.escape_direction), and dodge if the
	# telegraph is nearly over and the bot is still inside it. Plain enemies never trigger this.
	var boss_threat: bool = false
	if _run_mode:
		for enemy in enemies:
			if enemy is Boss and (enemy as Boss).in_threat(me):
				boss_threat = true
				want = (enemy as Boss).escape_direction(me)
				var left: float = (enemy as Boss).telegraph_left()
				if (enemy as Boss).state_name() == "ACTIVE" or left < 0.3:
					danger = enemy
				break
	_pin_want = want
	_drive(want)
	if boss_threat and danger != null and _sim_time >= _dodge_cooldown_until:
		_press(&"dodge")
		_dodge_cooldown_until = _sim_time + 0.9
	elif danger != null and not (danger is Boss) and _sim_time >= _dodge_cooldown_until:
		_press(&"dodge")
		_dodge_cooldown_until = _sim_time + 0.9
	if crowd >= 2 and _sim_time >= _heavy_until:
		_press(&"attack_heavy")
		_heavy_until = _sim_time + 1.9
	if _rng.randf() < 0.3:
		_press(StringName("slot_%d" % _rng.randi_range(1, 5)))
	if _rng.randf() < 0.5:
		_press(&"attack_light")


## Run mode only: true when the room is down to 2 enemies or fewer, or only ranged ones, so waiting for them to
## come never ends. (The endless-arena bot keeps its old behaviour so the seeded baselines do not move.)
func _hunting(enemies: Array[Enemy]) -> bool:
	if enemies.size() <= 2:
		return true
	for enemy in enemies:
		if not enemy.is_ranged:
			return false
	return true


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


# ---- Whole runs (Milestone 3a) ----

func _run_whole(run_seed: int) -> void:
	_reset_run_state(run_seed)
	Player.default_rng_seed = run_seed
	Juice.hit_stop_enabled = false
	RunSession.clear()
	RunSession.begin_new_run(run_seed)
	var rooms: Array[Dictionary] = RunGenerator.generate(run_seed, RunConfig.get_config())
	if _god:
		RunSession.current.max_hp = 9999.0
		RunSession.current.hp = 9999.0
	_policy_rng.seed = run_seed * 977 + 13
	var result: Dictionary = {"seed": run_seed, "rooms_total": rooms.size(), "rooms_reached": 0, "outcome": "unfinished", "types": [], "wall_ms": 0, "sim_s": 0.0, "room_s": [], "room_min_hp": []}
	for room: Dictionary in rooms:
		(result["types"] as Array).append(String(room["type"]))
	var wall_start := Time.get_ticks_msec()
	var run_sim_total: float = 0.0
	get_tree().change_scene_to_packed(load(RUN_MAIN_PATH) as PackedScene)
	var previous: Node = null
	var room_index: int = 0
	while room_index < rooms.size():
		var main_node: Node = await _await_new_main(previous)
		if not (main_node is Main) or (main_node as Main).run_controller == null:
			_fail("run %d: room %d did not load as a run room" % [run_seed, room_index + 1])
			result["outcome"] = "crash"
			break
		_main = main_node as Main
		_player = _main.player
		previous = _main
		result["rooms_reached"] = room_index + 1
		var controller: RunController = _main.run_controller
		_begin_run_room(run_seed, rooms[room_index])
		var room_result: String = await _play_room(run_seed, controller, rooms[room_index])
		(result["room_s"] as Array).append(snappedf(_sim_time, 0.1))
		(result["room_min_hp"] as Array).append(snappedf(_room_min_hp, 0.1))
		if _boss_start >= 0.0:
			var fight: float = (_boss_end if _boss_end >= 0.0 else _sim_time) - _boss_start
			result["boss_fight_s"] = snappedf(fight, 0.1)
			print("    boss fight (spawn to death): %.1f s, %s | player lowest HP %.1f" % [fight, "boss died" if _boss_end >= 0.0 else "boss NOT dead", _room_min_hp])
		run_sim_total += _sim_time
		if room_result == "lost":
			result["outcome"] = "lost"
			break
		if room_result != "cleared":
			result["outcome"] = room_result
			break
		if controller.is_last_room():
			result["outcome"] = "won"
			break
		if controller.has_choice():
			var guard: int = 0
			while controller.has_choice() and guard < 8:
				guard += 1
				var choice_id: String = _policy_choose(controller)
				var outcome: Dictionary = controller.choose(choice_id)
				if not bool(outcome["ok"]):
					_fail("run %d room %d: the bot choice '%s' was refused: %s" % [run_seed, room_index + 1, choice_id, str(outcome.get("reason", ""))])
					break
		else:
			controller.continue_to_next_room()
		room_index += 1
	result["wall_ms"] = Time.get_ticks_msec() - wall_start
	result["sim_s"] = run_sim_total
	result["hp_end"] = snappedf(RunSession.current.hp, 0.1) if RunSession.current != null else -1.0
	_record_deck_and_hp(result)
	Engine.time_scale = 1.0
	_release_all()
	Player.default_rng_seed = -1
	Juice.reset()
	_run_results.append(result)
	var type_letters: Array[String] = []
	for t: String in (result["types"] as Array):
		type_letters.append(t.substr(0, 1))
	print("  run seed %d: %s | rooms reached %d of %d | sim %.0f s in %.1f s wall | types %s | room seconds %s | lowest HP in each room %s | HP at last room clear %s" % [
		run_seed, String(result["outcome"]).to_upper(), int(result["rooms_reached"]), rooms.size(), float(result["sim_s"]), float(result["wall_ms"]) / 1000.0, ",".join(type_letters), str(result["room_s"]), str(result["room_min_hp"]), str(result["hp_end"])])
	print("    HP at each room end %s (max %s) | deck %d cards %s | picks %d, rejects used %d, removals %d, rest heals %d" % [
		str(result["room_hp_end"]), str(result["max_hp"]), int(result["deck_size"]), str(result["deck_slots"]), int(result["picks"]), int(result["rejects_used"]), int(result["removals"]), int(result["heals"])])
	# Leave nothing of this run behind for the next one.
	var last: Node = get_tree().current_scene
	if last != null and last is Main:
		get_tree().current_scene = null
		last.queue_free()
	RunSession.clear()


## The seeded reward policy. It reads the choice model (option kinds and the state HP and deck counts), never a
## card content: a reject 25% of the time while any are left, else a random not-yet-owned card (any if all are
## owned); at a rest room it heals under 70% HP, else removes a duplicate (any removable card if none), else heals.
func _policy_choose(controller: RunController) -> String:
	var model: Dictionary = controller.current_choice()
	var options: Array = model["options"]
	var state: RunState = controller.state()
	match String(model["choice"]):
		RunState.PENDING_REWARD:
			var skip_id: String = ""
			var cards: Array[Dictionary] = []
			var unowned: Array[Dictionary] = []
			for option: Dictionary in options:
				if String(option["kind"]) == "skip" and bool(option["enabled"]):
					skip_id = String(option["id"])
				elif String(option["kind"]) == "card" and bool(option["enabled"]):
					cards.append(option)
					if not state.deck.has(String(option["card_id"])):
						unowned.append(option)
			if skip_id != "" and (_policy_rng.randf() < REJECT_CHANCE or cards.is_empty()):
				return skip_id
			var pool: Array[Dictionary] = unowned if not unowned.is_empty() else cards
			return String(pool[_policy_rng.randi_range(0, pool.size() - 1)]["id"])
		RunState.PENDING_REST:
			var heal_id: String = ""
			var menu_id: String = ""
			for option: Dictionary in options:
				if String(option["kind"]) == "heal":
					heal_id = String(option["id"])
				elif bool(option["opens_list"]) and bool(option["enabled"]):
					menu_id = String(option["id"])
			if state.hp_fraction() >= HEAL_BELOW_FRACTION and menu_id != "":
				return menu_id
			return heal_id
		RunState.PENDING_REST_REMOVE:
			var best: String = ""
			var any: String = ""
			var back_id: String = ""
			for option: Dictionary in options:
				if String(option["kind"]) == "back":
					back_id = String(option["id"])
				elif String(option["kind"]) == "remove" and bool(option["enabled"]):
					if any == "":
						any = String(option["id"])
					if best == "" and int(option["count"]) > 1:
						best = String(option["id"])
			return best if best != "" else (any if any != "" else back_id)
	return ""


## Run end report data: HP at each room end, the final deck size and per-slot composition, and what the policy did.
func _record_deck_and_hp(result: Dictionary) -> void:
	var state: RunState = RunSession.current
	var hp_ends: Array[float] = []
	var slots: Dictionary = {}
	var picks: int = 0
	var rejects_used: int = 0
	var removals: int = 0
	var heals: int = 0
	if state != null:
		for entry: Dictionary in state.history:
			hp_ends.append(snappedf(float(entry["hp_end"]), 0.1))
		for card_id: String in state.deck:
			var slot_type: String = String(CardDatabase.get_card(card_id).get("slot_type", "?"))
			slots[slot_type] = int(slots.get(slot_type, 0)) + 1
		for entry: Dictionary in state.choice_log:
			match String(entry["kind"]):
				"pick": picks += 1
				"reject": rejects_used += 1
				"remove": removals += 1
				"heal": heals += 1
	result["room_hp_end"] = hp_ends
	result["max_hp"] = snappedf(state.max_hp, 0.1) if state != null else -1.0
	result["deck_size"] = state.deck.size() if state != null else 0
	result["deck_slots"] = slots
	result["picks"] = picks
	result["rejects_used"] = rejects_used
	result["removals"] = removals
	result["heals"] = heals
	if state != null and state.deck.is_empty():
		_fail("run %d: the deck ended empty" % int(result["seed"]))


## Waits for a Main that is not `old` to become the current scene (the scene swap is deferred).
func _await_new_main(old: Node) -> Node:
	for i in range(120):
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene is Main and scene != old and is_instance_valid(scene) and scene.is_node_ready():
			await get_tree().process_frame
			return scene
	return null


## Per-room setup of the sim counters (the world checks and the stall watch are per room).
func _begin_run_room(run_seed: int, room: Dictionary) -> void:
	_sim_time = 0.0
	_clock = 0.0
	_boss_start = -1.0
	_boss_end = -1.0
	_last_stage_count = 0
	_last_progress_time = 0.0
	_kills = 0
	set_meta("kills_mark", -1)
	_dodge_cooldown_until = 0.0
	_heavy_until = 0.0
	_rng.seed = run_seed * 131 + int(room["index"])
	_player.card_slots.card_cast.connect(func(_slot_type: String, card_id: String) -> void: _card_casts[card_id] = int(_card_casts.get(card_id, 0)) + 1)
	_slot_stuck_since.clear()
	_room_min_hp = _player.health.current_health
	# N3: a deck with an empty slot is a broken run.
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot: CardSlot = _player.card_slots.get_slot(slot_type)
		if slot == null or not slot.has_cards():
			_fail("run %d room %d: empty deck for slot '%s'" % [run_seed, int(room["index"]) + 1, slot_type])
	if _player.card_slots.owned_card_ids().is_empty():
		_fail("run %d room %d: the deck is empty" % [run_seed, int(room["index"]) + 1])
	Engine.time_scale = _scale


## Plays one room to "cleared", "lost" or "soft_lock".
func _play_room(run_seed: int, controller: RunController, room: Dictionary) -> String:
	var cap: int = _main.enemy_spawner.plan.max_alive()
	var prev_enemies: Dictionary = {}
	await get_tree().process_frame
	while true:
		Engine.time_scale = _scale
		await get_tree().process_frame
		var dt: float = _clock - _sim_time
		_sim_time = _clock
		for action in _release_next:
			_release_action(action)
		_release_next.clear()
		if _player.is_dead():
			return "lost"
		if controller.is_cleared():
			_release_all()
			return "cleared"
		if _sim_time > _room_timeout:
			_fail("SOFT LOCK: run %d room %d (%s, %s) not finished after %.0f sim seconds (alive %d, plan finished %s)" % [
				run_seed, int(room["index"]) + 1, room["type"], room["wave_id"], _room_timeout, _main.enemy_spawner.alive_count(), str(_main.enemy_spawner.plan.is_finished())])
			return "soft_lock"
		_room_min_hp = minf(_room_min_hp, _player.health.current_health)
		var enemies := _enemies()
		_check_world(enemies, cap, dt)
		_check_cooldowns(run_seed, room)
		_count_kills(enemies, prev_enemies)
		_track_boss(enemies)
		_bot_step(enemies)
		if OS.has_environment("BOSS_TRACE") and int(_sim_time * 60.0) % 300 == 0:
			for e: Enemy in enemies:
				if e is Boss:
					print("  trace t=%.0f boss_hp=%.0f phase=%d state=%s dist=%.1f me_hp=%.0f" % [_sim_time, e.health.current_health, (e as Boss).phase_index, (e as Boss).state_name(), e.global_position.distance_to(_player.global_position), _player.health.current_health])
		if _god:
			_player.health.heal(9999.0)
	return "unreachable"


## Boss fight timing: from the boss appearing to its death (the death beat and the win wait are not counted: the beat
## runs on the wall clock, which at sim speed is many sim seconds).
var _boss_start: float = -1.0
var _boss_end: float = -1.0


func _track_boss(enemies: Array[Enemy]) -> void:
	var has_boss: bool = false
	for enemy in enemies:
		if enemy is Boss:
			has_boss = true
	if has_boss and _boss_start < 0.0:
		_boss_start = _sim_time
	elif not has_boss and _boss_start >= 0.0 and _boss_end < 0.0:
		_boss_end = _sim_time


## N3: a slot cooldown that is negative, longer than its own duration, or frozen above zero for 10 s.
func _check_cooldowns(run_seed: int, room: Dictionary) -> void:
	for slot_key: Variant in _player.card_slots.slots.keys():
		var slot: CardSlot = _player.card_slots.slots[slot_key]
		var remaining: float = slot.cooldown_remaining
		var label: String = "run %d room %d slot %s" % [run_seed, int(room["index"]) + 1, str(slot_key)]
		if remaining < 0.0 or remaining > 120.0 or remaining > slot.last_cooldown_duration + 0.05:
			_fail("stuck/invalid cooldown: %s has %.2f s left of a %.2f s cooldown at t=%.1f" % [label, remaining, slot.last_cooldown_duration, _sim_time])
		if remaining > 0.0:
			var frozen: Dictionary = _slot_stuck_since.get(slot_key, {})
			if frozen.is_empty() or not is_equal_approx(float(frozen["value"]), remaining):
				_slot_stuck_since[slot_key] = {"value": remaining, "since": _sim_time}
			elif _sim_time - float(frozen["since"]) > 10.0:
				_fail("stuck cooldown: %s frozen at %.2f s for 10 s (t=%.1f)" % [label, remaining, _sim_time])
		else:
			_slot_stuck_since.erase(slot_key)


func _run_summary() -> void:
	print("")
	var outcomes: Dictionary = {}
	var reached: Dictionary = {}
	var played_types: Dictionary = {}
	for result: Dictionary in _run_results:
		outcomes[result["outcome"]] = int(outcomes.get(result["outcome"], 0)) + 1
		reached[int(result["rooms_reached"])] = int(reached.get(int(result["rooms_reached"]), 0)) + 1
		for t: String in (result["types"] as Array):
			played_types[t] = int(played_types.get(t, 0)) + 1
	print("RUN SUMMARY over %d run(s): outcomes %s | rooms reached (rooms: runs) %s" % [_run_results.size(), str(outcomes), str(reached)])
	print("  room types in the played runs: %s" % str(played_types))
	_print_attrition()
	# Distribution of the generator alone over many seeds (cheap and pure).
	var counts: Dictionary = {}
	var index_counts: Dictionary = {}
	var seeds: int = 1000
	for seed_value in range(1, seeds + 1):
		for room: Dictionary in RunGenerator.generate(seed_value, RunConfig.get_config()):
			counts[room["type"]] = int(counts.get(room["type"], 0)) + 1
			var key: String = "%s@%d" % [room["type"], int(room["index"]) + 1]
			index_counts[key] = int(index_counts.get(key, 0)) + 1
	var per_run: Dictionary = {}
	for key: Variant in counts.keys():
		per_run[key] = snappedf(float(counts[key]) / float(seeds), 0.01)
	print("  generator, %d seeds: rooms per run by type %s" % [seeds, str(per_run)])
	for room_type: String in ["elite", "rest"]:
		var parts: Array[String] = []
		for index in range(1, 9):
			var n: int = int(index_counts.get("%s@%d" % [room_type, index], 0))
			if n > 0:
				parts.append("room %d: %.0f%%" % [index, 100.0 * float(n) / float(seeds)])
		print("    %s position: %s" % [room_type, ", ".join(parts)])
	_print_pick_rates()


## 3b: HP at the end of each room, averaged over the runs that got that far (is there attrition?), and the deck sizes.
func _print_attrition() -> void:
	var sums: Array[float] = []
	var counts: Array[int] = []
	var sizes: Array[int] = []
	for result: Dictionary in _run_results:
		sizes.append(int(result.get("deck_size", 0)))
		var ends: Array = result.get("room_hp_end", [])
		for i in range(ends.size()):
			while sums.size() <= i:
				sums.append(0.0)
				counts.append(0)
			sums[i] += float(ends[i]) / maxf(float(result.get("max_hp", 30.0)), 1.0)
			counts[i] += 1
	var parts: Array[String] = []
	for i in range(sums.size()):
		parts.append("room %d: %.0f%% (%d runs)" % [i + 1, 100.0 * sums[i] / float(counts[i]), counts[i]])
	print("  mean HP at room end, as a share of max: %s" % ", ".join(parts))
	sizes.sort()
	if not sizes.is_empty():
		print("  final deck sizes: %s (min %d, max %d)" % [str(sizes), sizes[0], sizes[sizes.size() - 1]])


## N3: per-card pick rates. Within one slot type the bot presses at random, so cards should be cast at similar
## rates apart from their cooldowns. A card far from its slot mean (under 0.4x or over 2.0x), or never cast, is
## reported for balance review (a NOTE, not a failure: cooldowns differ on purpose).
func _print_pick_rates() -> void:
	var total: int = 0
	for card_id: Variant in _card_casts.keys():
		total += int(_card_casts[card_id])
	print("  card pick rates (%d casts over all runs; OUTLIER = under 0.4x or over 2.0x of its slot mean):" % total)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var ids: Array[String] = []
		for card: Variant in CardDatabase.cards_for_slot_type(slot_type):
			ids.append(String((card as Dictionary)["id"]))
		var in_slot: int = 0
		for card_id: String in ids:
			in_slot += int(_card_casts.get(card_id, 0))
		var mean: float = float(in_slot) / maxf(float(ids.size()), 1.0)
		var row: Array[String] = []
		for card_id: String in ids:
			var n: int = int(_card_casts.get(card_id, 0))
			var ratio: float = float(n) / maxf(mean, 0.0001)
			var flag: String = ""
			if n == 0:
				flag = " <-- NEVER CAST"
			elif ratio < 0.4 or ratio > 2.0:
				flag = " <-- OUTLIER"
			row.append("%s %d (%.2fx)%s" % [card_id, n, ratio, flag])
		print("    %s: %s" % [slot_type, "; ".join(row)])
