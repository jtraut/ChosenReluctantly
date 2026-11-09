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
## Run mode: the bot ends a duel it cannot win by dodging (see _deadlocked_on_last_enemy) after this long with no kill.
const DEADLOCK_SECONDS := 45.0

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
## Sim time of the last kill in this room (reset per room; the deadlock breaker reads it).
var _last_kill_time: float = 0.0
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
## `--sim-deck=<preset>` (wave sim -Deck): start every run with a debug preset deck from data/debug_decks (T-decks), so
## armor comparisons use legal decks. "" or "standard" = the normal starting deck. The preset is the whole run's deck
## start (Try again is not used in the sim); rewards then change it as usual.
var _deck_family: String = ""
## `--light-heavy-only`: the bot never presses any card slot (H1: it used to skip only the two attack slots, which left Ward, blinks and
## heals in play), so only light, heavy and dodge are used. Rest rooms still run through the reward policy.
## A bot attack policy, not a deck. It draws the same random numbers as without the flag, so the standard policy is unchanged.
var _light_heavy_only: bool = false
## `--sim-class=<id>` (wave sim -Class): play whole runs (-Run) as that character (data/characters.json). "" = the default Rogue.
## A ranged class (its light attack is a projectile) gets a different bot stand-off, see _bot_step.
var _sim_class: String = ""
## `--wizard-no-kite` (wave sim -WizardNoKite): a ranged class does not back off to a stand-off; it uses the melee bot's numbers (backs off
## inside 2.3 m, closes in beyond 4.5 m, crowd radius 3 m), i.e. it walks in like the Rogue bot. A bot movement policy only; the Rogue is untouched.
var _no_kite: bool = false
## `--boss-log` (wave sim -BossLog): in a boss room, record every boss attack and every hit the player takes from it (see _boss_hit).
var _boss_log: bool = false
## `--dodge-pellets` (wave sim -DodgePellets, run mode): the bot also reacts to enemy projectiles already in flight. Without it the bot only
## leaves a boss wind-up area and rolls just before the attack lands (the pellets arrive about half a second later), so it never dodges a pellet.
var _dodge_pellets: bool = false
## `--plan` (wave sim -Plan): the plan-aware card policy (PlanPolicy) replaces the random slot presses: it casts a payoff when its
## condition is live (or after a 1.5 s hold), swaps a card that cannot pay off soon, and spends Movement offensively. Everything
## else (movement, dodge, light and heavy attacks) is the standard bot, so the two policies are comparable. Off: the sim is unchanged.
var _plan: bool = false
var _plan_policy: PlanPolicy = PlanPolicy.new()
## Plan mode counters, printed in the summary: casts, swaps, and casts made while a condition was live.
## slot type -> sim time before which the plan bot does not press that slot again; the gap is the press-to-release delivery.
var _plan_busy_until: Dictionary = {}
const PLAN_PRESS_GAP := 0.1
var _plan_stats: Dictionary = {"casts": 0, "swaps": 0, "live_casts": 0, "held_casts": 0}

## `--start-room=N` (wave sim -StartRoom, run mode): every run starts at room N (1-based) with the class's starter deck and full HP, so a
## boss-room measurement needs no 9 rooms of luck first. 0 = from room 1.
var _start_room: int = 0
var _boss_runs: Array[Dictionary] = []
var _boss_cur: Dictionary = {}
var _run_results: Array[Dictionary] = []
var _card_casts: Dictionary = {}
var _slot_stuck_since: Dictionary = {}
var _room_min_hp: float = INF
## `--sim-relics=<id>+<id>` (wave sim -Relics, run mode): every run starts holding these relics (BD2-B). `--sim-relic-cap=N` (-RelicCap) lowers the
## relic cap so the give-one-up step is reached in a short run. Both are checked at launch (an unknown id exits 2).
## `--sim-swap=<old>=<new>` (-Swap, run mode): after the run starts, one copy of card <old> in the deck is replaced by <new> (checked against the
## deck rules), so a removal-pain measurement needs no temporary preset file.
## `--sim-no-relics` (-NoRelics, run mode): plays with `relics.enabled` false, i.e. today's run exactly (no relic room, cards after an elite).
var _no_relics: bool = false
var _swap_out: String = ""
var _swap_in: String = ""
## `--sim-route=first|relic|safe|random` (wave sim -Route, run mode, MAP1-B): the runs walk the branching map and the bot follows that route policy (RouteBot).
## `--sim-map` (-Map) turns the map on with the `first` route. Either one forces the map on for this process. "" = whatever data/map.json says (on as shipped); `--sim-no-map` forces the straight run.
var _route_policy: String = ""
## `--sim-no-map` (-NoMap): the straight run, whatever data/map.json says (RunSession.map_override = 0). Not combinable with -Route / -Map.
var _no_map: bool = false
## `--sim-merchant` (-Merchant, MAP2-B): the merchant is on for this process (MerchantSwitch: data/merchant_on.json). Implies the map (the `first` route when no -Route is given).
var _merchant: bool = false
var _route: Array[int] = []
## MAP3-B: one RouteBot.summary per act of the current run, and one record per act played ({act, cleared, seconds, hp, max_hp, relics, gold}).
var _route_summaries: Array[Dictionary] = []
var _act_records: Array[Dictionary] = []
## Damage the player's side dealt to enemies, by origin, for the current run and for all runs (BD2-B; run mode). Fed by CombatEvents.hit_landed.
var _damage_run: Dictionary = {}
## qa MAP2: relic id -> how many times its triggers fired this run (counted from the controller's relic_triggered signal; output only).
var _trigger_run: Dictionary = {}
var _damage_all: Dictionary = {}
var _damage_by_run: Array[Dictionary] = []
## 3b: the reward bot's own stream (seeded per run, so the picks repeat from --seed and never touch the combat bot).
var _policy_rng := RandomNumberGenerator.new()
const REJECT_CHANCE := 0.25
## `--sim-random-picks` (-RandomPicks): the reward bot takes any not-yet-owned card at random, as before BD3a's dilution guard (the old baselines).
var _random_picks: bool = false
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
		elif arg == "--light-heavy-only":
			_light_heavy_only = true
		elif arg == "--wizard-no-kite":
			_no_kite = true
		elif arg == "--boss-log":
			_boss_log = true
		elif arg == "--dodge-pellets":
			_dodge_pellets = true
		elif arg == "--plan":
			_plan = true
		elif arg.begins_with("--start-room="):
			_start_room = maxi(int(arg.substr(13)), 0)
		elif arg.begins_with("--sim-deck="):
			_deck_family = arg.substr(11)
			if _deck_family == "standard":
				_deck_family = ""
			elif _deck_family != "":
				var directory: Dictionary = DebugDecks.read_dir()
				if not (directory["presets"] as Dictionary).has(_deck_family):
					push_error("wave sim: -Deck must be a debug deck (valid: %s) or standard, got '%s'" % [", ".join(directory["names"] as Array[String]), _deck_family])
					get_tree().quit(2)
					return
				RunSession.debug_deck = (directory["presets"] as Dictionary)[_deck_family]
		elif arg.begins_with("--sim-class="):
			_sim_class = arg.substr(12)
			if not CharacterDatabase.has(_sim_class):
				push_error("wave sim: -Class must be one of %s, got '%s'" % [", ".join(CharacterDatabase.ids()), _sim_class])
				get_tree().quit(2)
				return
			RunSession.selected_character = _sim_class
		elif arg.begins_with("--sim-relics="):
			var held: Array[String] = RelicArgs.parse_ids(arg.substr(13))
			var held_problems: Array[String] = RelicArgs.id_problems("-Relics", held, 0)
			if not held_problems.is_empty():
				push_error("wave sim: " + "; ".join(held_problems))
				get_tree().quit(2)
				return
			RunSession.start_relics = held
		elif arg.begins_with("--sim-relic-cap="):
			if not arg.substr(16).is_valid_int() or arg.substr(16).to_int() < 1:
				push_error("wave sim: -RelicCap needs a whole number from 1")
				get_tree().quit(2)
				return
			RunSession.relic_cap = arg.substr(16).to_int()
		elif arg == "--sim-no-relics":
			_no_relics = true
		elif arg == "--sim-random-picks":
			_random_picks = true
		elif arg == "--sim-no-map":
			_no_map = true
		elif arg.begins_with("--sim-acts="):
			if not arg.substr(11).is_valid_int() or arg.substr(11).to_int() < 1 or arg.substr(11).to_int() > RunState.MAX_ACTS:
				push_error("wave sim: -Acts needs a whole number from 1 to %d" % RunState.MAX_ACTS)
				get_tree().quit(2)
				return
			RunSession.acts_override = arg.substr(11).to_int()
		elif arg == "--sim-merchant":
			_merchant = true
		elif arg == "--sim-map":
			if _route_policy == "":
				_route_policy = "first"
		elif arg.begins_with("--sim-route="):
			_route_policy = arg.substr(12)
			if not RouteBot.is_policy(_route_policy):
				push_error("wave sim: -Route must be one of %s, got '%s'" % [", ".join(RouteBot.POLICIES), _route_policy])
				get_tree().quit(2)
				return
		elif arg.begins_with("--sim-swap="):
			_swap_out = arg.substr(11).get_slice("=", 0)
			_swap_in = arg.substr(11).get_slice("=", 1)
		elif arg.begins_with("--room-timeout="):
			_room_timeout = maxf(10.0, float(arg.substr(15)))
	# A preset deck is for one class: refuse a clash like a real launch does, and let a preset alone pick its class.
	if not RunSession.debug_deck.is_empty():
		var preset_class: String = RunSession.preset_character(RunSession.debug_deck)
		if _sim_class != "" and _sim_class != preset_class:
			push_error("wave sim: -Deck %s is a %s deck but -Class %s was given; they must agree" % [_deck_family, preset_class, _sim_class])
			get_tree().quit(2)
			return
		RunSession.selected_character = preset_class
	if _route_policy != "" and not _run_mode:
		push_error("wave sim: -Route and -Map need -Run")
		get_tree().quit(2)
		return
	if _merchant and _route_policy == "" and not _no_map:
		_route_policy = "first"
	if _merchant and _no_map:
		push_error("wave sim: -Merchant needs the map; it cannot be combined with -NoMap")
		get_tree().quit(2)
		return
	if _merchant and not MerchantSwitch.apply():
		push_error("wave sim: -Merchant could not apply data/merchant_on.json")
		get_tree().quit(2)
		return
	if _no_map and _route_policy != "":
		push_error("wave sim: -NoMap cannot be combined with -Route or -Map")
		get_tree().quit(2)
		return
	if _no_map:
		RunSession.map_override = MapLaunch.OVERRIDE_OFF
	if _route_policy != "":
		RunSession.map_override = MapLaunch.OVERRIDE_ON
	if _no_relics:
		(RunConfig.get_config()["relics"] as Dictionary)["enabled"] = false  # the cached config, for this process only
	if (_swap_out != "" or _swap_in != "") and not _run_mode:
		push_error("wave sim: -Swap needs -Run")
		get_tree().quit(2)
		return
	if (_swap_out != "" or _swap_in != "") and (not CardDatabase.has_card(_swap_out) or not CardDatabase.has_card(_swap_in)):
		push_error("wave sim: -Swap needs two card ids, as old=new (got '%s' and '%s')" % [_swap_out, _swap_in])
		get_tree().quit(2)
		return
	if _sim_class != "" and not _run_mode:
		print("note: -Class only applies to whole runs (-Run); the endless arena always plays the Rogue")
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
	_last_kill_time = 0.0
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
	_plan_policy = PlanPolicy.new()
	_plan_busy_until.clear()
	_plan_stats = {"casts": 0, "swaps": 0, "live_casts": 0, "held_casts": 0}
	_pellet_sidestep = Vector3.ZERO
	_pellet_imminent = false
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
			_last_kill_time = _sim_time
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
	return text.begins_with("slot_") or text.begins_with("attack_") or text.begins_with("dead_card_swap_")


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
		if d < (RANGED_CROWD_RADIUS if _kites() else 3.0):
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
	# A ranged character (projectile light) keeps its distance: back off inside RANGED_BACK_OFF, close in beyond
	# RANGED_CLOSE_IN, otherwise strafe. The melee numbers are untouched, so Rogue sims repeat exactly.
	var ranged: bool = _kites()
	var back_off: float = RANGED_BACK_OFF if ranged else 2.3
	var close_in: float = RANGED_CLOSE_IN if ranged else 4.5
	if nearest_d < back_off:
		want = away
	elif _run_mode and _hunting(enemies) and nearest_d > (close_in if ranged else 2.0):
		want = -away  # a room needs its last enemies dead: with only a few left (or only shooters) go and get them
	elif nearest_d > close_in:
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
	if _dodge_pellets and _run_mode and _scan_pellets(me):
		want = _pellet_sidestep
	var deadlocked: bool = _deadlocked_on_last_enemy(enemies)
	if deadlocked:
		# Close in and stand still beside it: no arena-edge push into the enemy, and no dodge (below), so the light attack can land.
		want = Vector3.ZERO if nearest_d <= 2.0 else -away
	_pin_want = want
	_drive(want)
	# Dodge whenever the player could: the Player's own availability (a charge and no roll under way) is the gate,
	# and the throttle is only the roll length, so charges (not a timer) limit the bot.
	var can_dodge: bool = _sim_time >= _dodge_cooldown_until and bool(_player.get_dodge_state()["available"]) and not deadlocked
	if boss_threat and danger != null and can_dodge:
		_press(&"dodge")
		if _boss_log and not _boss_cur.is_empty():
			_boss_cur["dodges"] = int(_boss_cur.get("dodges", 0)) + 1
		_dodge_cooldown_until = _sim_time + _player.dodge_duration
	elif _pellet_imminent and can_dodge:
		_press(&"dodge")
		_dodge_cooldown_until = _sim_time + _player.dodge_duration
		if _boss_log and not _boss_cur.is_empty():
			_boss_cur["dodges"] = int(_boss_cur.get("dodges", 0)) + 1
	elif danger != null and not (danger is Boss) and can_dodge:
		_press(&"dodge")
		if _boss_log and not _boss_cur.is_empty():
			_boss_cur["dodges"] = int(_boss_cur.get("dodges", 0)) + 1
		_dodge_cooldown_until = _sim_time + _player.dodge_duration
	if crowd >= 2 and _sim_time >= _heavy_until:
		_press(&"attack_heavy")
		_heavy_until = _sim_time + 1.9
	if _plan:
		if not _light_heavy_only:
			# Charges are what limits an escape, not the sim's 0.25 s dodge throttle: with a charge left the dodge answers danger and
			# the Movement card stays in hand (reading the throttle, or the state after this frame's press, would burn Movement on every dodge).
			var charge_left: bool = bool(_player.get_dodge_state()["enabled"]) and int(_player.get_dodge_state()["current"]) > 0
			_plan_cards(danger != null or boss_threat, charge_left)
	elif _rng.randf() < 0.3:
		var slot_number: int = _rng.randi_range(1, 5)
		if not _light_heavy_only:
			_press(StringName("slot_%d" % slot_number))
	if _rng.randf() < 0.5:
		_press(&"attack_light")


## The no-card Rogue soft lock (BD1 qa carry-over, seed 7 room 1): the last enemy stood between the bot and the arena centre while the
## bot was pushed toward that centre, and the bot rolled through every wind-up. A roll cancels the bot's own light wind-up and gives
## i-frames, so neither side ever landed a hit. After DEADLOCK_SECONDS with no kill, one enemy left and no boss, the bot stops dodging
## and stands beside it. Rooms that finish normally never get this far, so every other seeded run is untouched.
func _deadlocked_on_last_enemy(enemies: Array[Enemy]) -> bool:
	if not _run_mode or enemies.size() != 1 or _sim_time - _last_kill_time <= DEADLOCK_SECONDS:
		return false
	return not (enemies[0] is Boss)


## --plan: one PlanPolicy decision per slot, sent through the real input path (slot key to cast, the swap action to swap).
func _plan_cards(in_danger: bool, dodge_ready: bool) -> void:
	var view: Dictionary = SlotSynergyView.view_for(_player)
	var hp_fraction: float = _player.health.get_current_health() / maxf(_player.health.get_max_health(), 1.0)
	var decisions: Dictionary = _plan_policy.decide_all(_player.card_slots.slots, view, hp_fraction, in_danger, dodge_ready)
	for index in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		var slot_type: String = CardSlotController.SLOT_TYPE_ORDER[index]
		if _sim_time < float(_plan_busy_until.get(slot_type, 0.0)):
			continue  # a key press on this slot is still being delivered (a cast happens on release)
		match String(decisions.get(slot_type, PlanPolicy.WAIT)):
			PlanPolicy.CAST:
				var card: Dictionary = CardDatabase.get_card(_player.card_slots.get_slot(slot_type).current_card_id)
				_plan_stats["casts"] = int(_plan_stats["casts"]) + 1
				if SlotSynergy.is_live(card, view):
					_plan_stats["live_casts"] = int(_plan_stats["live_casts"]) + 1
				elif not SlotSynergy.conditional_effects(card).is_empty():
					_plan_stats["held_casts"] = int(_plan_stats["held_casts"]) + 1
				_press(StringName("slot_%d" % (index + 1)))
				_plan_busy_until[slot_type] = _sim_time + PLAN_PRESS_GAP
			PlanPolicy.SWAP:
				_plan_stats["swaps"] = int(_plan_stats["swaps"]) + 1
				_press(StringName("dead_card_swap_%d" % (index + 1)))
				_plan_busy_until[slot_type] = _sim_time + PLAN_PRESS_GAP


## The Wizard stand-off (metres): its bolt reaches 12 m and its heavy disc 7 m, melee enemies close in on it.
const RANGED_BACK_OFF := 5.0
const RANGED_CLOSE_IN := 9.0
const RANGED_CROWD_RADIUS := 6.0


## --dodge-pellets: looks at every enemy-team projectile in the room. One that flies toward the bot and would pass within PELLET_LANE of it
## sets `_pellet_sidestep` (a step out of its lane) and, when it is within PELLET_ROLL_TIME of hitting, `_pellet_imminent` (roll now).
const PELLET_LANE := 0.9
const PELLET_SEE_TIME := 0.7
const PELLET_ROLL_TIME := 0.2
var _pellet_sidestep: Vector3 = Vector3.ZERO
var _pellet_imminent: bool = false


func _scan_pellets(me: Vector3) -> bool:
	_pellet_sidestep = Vector3.ZERO
	_pellet_imminent = false
	var soonest: float = INF
	for child in _main.get_children():
		if not (child is Projectile) or String((child as Projectile)._exclude_team) != "enemy":
			continue
		var pellet: Projectile = child
		var rel: Vector3 = me - pellet.global_position
		rel.y = 0.0
		var dir: Vector3 = pellet._direction
		dir.y = 0.0
		var along: float = rel.dot(dir)
		if along <= 0.0 or pellet._speed <= 0.0:
			continue
		var across: Vector3 = rel - dir * along
		if across.length() > PELLET_LANE:
			continue
		var time_left: float = along / pellet._speed
		if time_left < PELLET_SEE_TIME and time_left < soonest:
			soonest = time_left
			_pellet_sidestep = across.normalized() if across.length() > 0.05 else Vector3(-dir.z, 0.0, dir.x).normalized()
			_pellet_imminent = time_left < PELLET_ROLL_TIME
	return _pellet_sidestep != Vector3.ZERO


## True when the bot should kite: a ranged class, unless `--wizard-no-kite`.
func _kites() -> bool:
	return _is_ranged_class() and not _no_kite


## True when the played character's light attack is a projectile (it can hit from far away).
func _is_ranged_class() -> bool:
	if _player == null or _player.attacks == null:
		return false
	return String(_player.attacks.get_def(&"light").get("shape", "arc")) == "projectile"


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
	if _plan:
		print("    plan policy: %d card casts (%d with the condition live, %d held payoff casts), %d dead-card swaps" % [int(_plan_stats["casts"]), int(_plan_stats["live_casts"]), int(_plan_stats["held_casts"]), int(_plan_stats["swaps"])])
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
	if not _apply_swap(run_seed):
		return
	_damage_run = {}
	_trigger_run = {}
	var relay: CombatEventsRelay = CombatLink.events()
	var tally := _on_hit_for_tally
	if relay != null:
		relay.hit_landed.connect(tally)
	_route_summaries = []
	_act_records = []
	var rooms: Array[Dictionary] = _setup_route(run_seed)
	var run_state_at_start: RunState = RunSession.current
	var acts_in_run: int = run_state_at_start.acts_total if run_state_at_start != null and not run_state_at_start.map.is_empty() else 1
	var rooms_in_run: int = run_state_at_start.run_room_total() if acts_in_run > 1 or (run_state_at_start != null and not run_state_at_start.map.is_empty()) else rooms.size()
	if _god:
		RunSession.current.max_hp = 9999.0
		RunSession.current.hp = 9999.0
	_policy_rng.seed = run_seed * 977 + 13
	var result: Dictionary = {"seed": run_seed, "rooms_total": rooms_in_run, "rooms_reached": 0, "outcome": "unfinished", "types": [], "wall_ms": 0, "sim_s": 0.0, "room_s": [], "room_min_hp": []}
	for room: Dictionary in rooms:
		(result["types"] as Array).append(String(room["type"]))
	var wall_start := Time.get_ticks_msec()
	var run_sim_total: float = 0.0
	get_tree().change_scene_to_packed(load(RUN_MAIN_PATH) as PackedScene)
	var previous: Node = null
	var room_index: int = clampi(_start_room - 1, 0, rooms.size() - 1) if _start_room > 0 else 0
	var rooms_played: int = room_index  # rooms of the whole run played so far (acts after the first add their own)
	var act_seconds: float = 0.0
	if _start_room > rooms.size():
		# Said out loud, not silently clamped. (A plain note, not an engine warning: the wrapper fails a sim on any WARNING line.)
		print("note: -StartRoom %d is past the last room; every run starts at room %d (the boss) instead" % [_start_room, rooms.size()])
	if room_index > 0:
		RunSession.current.room_index = room_index
		if not _route.is_empty():
			RunSession.current.path = _route.slice(0, room_index + 1)
	while room_index < rooms.size():
		var main_node: Node = await _await_new_main(previous)
		if not (main_node is Main) or (main_node as Main).run_controller == null:
			_fail("run %d: room %d did not load as a run room" % [run_seed, room_index + 1])
			result["outcome"] = "crash"
			break
		_main = main_node as Main
		_player = _main.player
		previous = _main
		result["rooms_reached"] = rooms_played + 1
		var controller: RunController = _main.run_controller
		controller.relic_triggered.connect(func(relic_id: String, _index: int, _event: String) -> void: _trigger_run[relic_id] = int(_trigger_run.get(relic_id, 0)) + 1)
		_begin_run_room(run_seed, rooms[room_index])
		var room_result: String = await _play_room(run_seed, controller, rooms[room_index])
		(result["room_s"] as Array).append(snappedf(_sim_time, 0.1))
		(result["room_min_hp"] as Array).append(snappedf(_room_min_hp, 0.1))
		if _boss_start >= 0.0:
			var fight: float = (_boss_end if _boss_end >= 0.0 else _sim_time) - _boss_start
			result["boss_fight_s"] = snappedf(fight, 0.1)
			result["boss_died"] = _boss_end >= 0.0
			print("    boss fight (spawn to death): %.1f s, %s | player lowest HP %.1f" % [fight, "boss died" if _boss_end >= 0.0 else "boss NOT dead", _room_min_hp])
		if _boss_log:
			_boss_room_done(run_seed, room_result)
		run_sim_total += _sim_time
		act_seconds += _sim_time
		var run_state: RunState = controller.state()
		if room_result != "cleared":
			result["outcome"] = "lost" if room_result == "lost" else room_result
			_record_act(run_state, false, act_seconds, run_state.act)
			break
		if controller.is_last_room() and not RunNodes.has_next_act(run_state):
			result["outcome"] = "won"
			_record_act(run_state, true, act_seconds, run_state.act)
			break
		var act_ended: bool = controller.is_last_room()  # a mini-boss cleared in an act before the last
		var act_before: int = run_state.act
		if not controller.has_choice():
			controller.continue_to_next_room()  # a straight run swaps scenes here; a map run opens its pick-next-node choice
		var next_room_index: int = room_index + 1
		if controller.has_choice():
			var guard: int = 0
			while controller.has_choice() and guard < 60:  # a merchant visit is many choices
				guard += 1
				if run_state.act != act_before:
					# The mini-boss rewards are done and the next act's map is open: record the act, plan its route, and the next choice is the first pick.
					_record_act(run_state, true, act_seconds, act_before)
					act_seconds = 0.0
					act_before = run_state.act
					rooms = _plan_route(run_seed, false)
					for room_entry: Dictionary in rooms:
						(result["types"] as Array).append(String(room_entry["type"]) if not String(room_entry["type"]).is_empty() else "?")
					next_room_index = 0
				var choice_id: String = _policy_choose(controller)
				var outcome: Dictionary = controller.choose(choice_id)
				if not bool(outcome["ok"]):
					_fail("run %d room %d: the bot choice '%s' was refused: %s" % [run_seed, room_index + 1, choice_id, str(outcome.get("reason", ""))])
					break
		if act_ended and next_room_index != 0:
			_fail("run %d: the act ended but the bot did not move on to the next one" % run_seed)
		room_index = next_room_index
		rooms_played += 1
	if relay != null and relay.hit_landed.is_connected(tally):
		relay.hit_landed.disconnect(tally)
	_damage_by_run.append(_damage_run)
	for origin: Variant in _damage_run.keys():
		_damage_all[origin] = float(_damage_all.get(origin, 0.0)) + float(_damage_run[origin])
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
		type_letters.append("R" if t == RunConfig.RELIC_ROOM else t.substr(0, 1))  # "r" is the rest room
	print("  run seed %d: %s | rooms reached %d of %d | sim %.0f s in %.1f s wall | types %s | room seconds %s | lowest HP in each room %s | HP at last room clear %s" % [
		run_seed, String(result["outcome"]).to_upper(), int(result["rooms_reached"]), int(result["rooms_total"]), float(result["sim_s"]), float(result["wall_ms"]) / 1000.0, ",".join(type_letters), str(result["room_s"]), str(result["room_min_hp"]), str(result["hp_end"])])
	print("    HP at each room end %s (max %s) | deck %d cards %s | picks %d, rejects used %d, removals %d, rest heals %d" % [
		str(result["room_hp_end"]), str(result["max_hp"]), int(result["deck_size"]), str(result["deck_slots"]), int(result["picks"]), int(result["rejects_used"]), int(result["removals"]), int(result["heals"])])
	print("    run stat: seed %d outcome %s rooms_reached %d damage_taken %.1f" % [run_seed, String(result["outcome"]), int(result["rooms_reached"]), _damage_taken])
	print("    relics: held %s | given up %s | offers taken %d, skipped %d, swapped %d" % [str(RunSession.current.relics if RunSession.current != null else []), str(RunSession.current.relics_given_up if RunSession.current != null else []), int(result["relic_picks"]), int(result["relic_skips"]), int(result["relic_swaps"])])
	print("    damage by source (HP removed from enemies): %s" % _damage_line(_damage_run))
	if not _trigger_run.is_empty():
		print("    relic triggers fired: %s" % str(_trigger_run))
	if result.has("route_summary"):
		var route_info: Dictionary = result["route_summary"]
		print("    route (%s): nodes %s | fights %d, elites %d, relic stages %d (chests %s), rests %d | gold %d, relics held %d" % [_route_policy, str(_route), int(route_info["fights"]), int(route_info["elites"]), int(route_info["relic_nodes"]), str(route_info["chests"]), int(route_info["rest"]), int(result["gold"]), int(result["relics_held"])])
	if _merchant or (result.has("route_summary") and MerchantSwitch.shipped_is_on()):  # qa MAP2: the merchant ships on, so a plain -Route reports it too
		print("    merchant: visited %s | gold spent %d | relics bought %d, cards bought %d, removals %d, rerolls %d" % [str(_visited_merchant(result)), int(result["gold_spent"]), int(result["shop_relics"]), int(result["shop_cards"]), int(result["shop_removals"]), int(result["shop_rerolls"])])
	if _plan:
		print("    plan policy: %d card casts (%d with the condition live, %d held payoff casts), %d dead-card swaps" % [int(_plan_stats["casts"]), int(_plan_stats["live_casts"]), int(_plan_stats["held_casts"]), int(_plan_stats["swaps"])])
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
			if not _random_picks:
				# BD3a: do not dilute a slot. An attack card whose cycling DPS is below the slot's average in the deck would lower the damage the
				# random-press bot does (the three-act Rogue lost its 8/12 floor to this). Take the candidates that do not, else (nothing left) the pool as it was.
				var useful: Array[Dictionary] = []
				for option: Dictionary in pool:
					if not _dilutes_attack_slot(String(option["card_id"]), state.deck):
						useful.append(option)
				if not useful.is_empty():
					pool = useful
			return String(pool[_policy_rng.randi_range(0, pool.size() - 1)]["id"])
		RunState.PENDING_RELIC:
			return RelicPolicy.offer_choice(options, state.deck)
		RunState.PENDING_RELIC_SWAP:
			return RelicPolicy.giveup_choice(options)
		RunState.PENDING_NODE:
			return "node:%d" % _route[state.path.size()]  # the route bot follows its planned route (RouteBot); a new act's path is empty, so its first pick is route[0]
		RunState.PENDING_MERCHANT, RunState.PENDING_MERCHANT_REMOVE, RunState.PENDING_MERCHANT_SWAP:
			return MerchantPolicy.choose(String(model["choice"]), options, state, _route_policy)  # no random draws: the other seeded choices do not shift
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


## True when an attack card would pull its slot's average cycling DPS (CardDamageRule: cast damage / cycle) down: the card's DPS is below the mean DPS of the
## attack cards of that slot already in the deck. Non-attack cards and a slot with no attack card yet never dilute.
func _dilutes_attack_slot(card_id: String, deck: Array[String]) -> bool:
	var card: Dictionary = CardDatabase.get_card(card_id)
	if not CardDamageRule.is_damage_card(card):
		return false
	var slot_type: String = String(card["slot_type"])
	var mine: float = _card_dps(card)
	var total: float = 0.0
	var count: int = 0
	for owned_id: String in deck:
		var owned: Dictionary = CardDatabase.get_card(owned_id)
		if String(owned.get("slot_type", "")) == slot_type:
			total += _card_dps(owned)
			count += 1
	return count > 0 and mine < total / float(count)


func _card_dps(card: Dictionary) -> float:
	var statuses: Dictionary = {}
	for status_id: String in CardSummary.status_ids(card):
		statuses[status_id] = StatusDatabase.get_status(status_id)
	var base: float = float(SlotTypeDatabase.get_definition(String(card["slot_type"])).get("base_cooldown", 1.0))
	var cycle: float = CardDamageRule.cycle_cooldown(card, base)
	return CardDamageRule.cast_damage(card, statuses, cycle) / cycle


## Run end report data: HP at each room end, the final deck size and per-slot composition, and what the policy did.
func _record_deck_and_hp(result: Dictionary) -> void:
	var state: RunState = RunSession.current
	var hp_ends: Array[float] = []
	var slots: Dictionary = {}
	var picks: int = 0
	var rejects_used: int = 0
	var removals: int = 0
	var heals: int = 0
	var relic_picks: int = 0
	var relic_skips: int = 0
	var relic_swaps: int = 0
	var shop_relics: int = 0
	var shop_cards: int = 0
	var shop_removals: int = 0
	var shop_rerolls: int = 0
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
				"relic": relic_picks += 1
				"relic_skip": relic_skips += 1
				"relic_swap":
					relic_picks += 1
					relic_swaps += 1
				"merchant_relic": shop_relics += 1
				"merchant_card": shop_cards += 1
				"merchant_remove": shop_removals += 1
				"merchant_reroll": shop_rerolls += 1
	result["room_hp_end"] = hp_ends
	result["max_hp"] = snappedf(state.max_hp, 0.1) if state != null else -1.0
	result["deck_size"] = state.deck.size() if state != null else 0
	result["deck_slots"] = slots
	result["picks"] = picks
	result["rejects_used"] = rejects_used
	result["removals"] = removals
	result["heals"] = heals
	result["relic_picks"] = relic_picks
	result["relic_skips"] = relic_skips
	result["relic_swaps"] = relic_swaps
	result["shop_relics"] = shop_relics
	result["shop_cards"] = shop_cards
	result["shop_removals"] = shop_removals
	result["shop_rerolls"] = shop_rerolls
	result["gold_spent"] = state.gold_spent_merchant if state != null else 0
	if state != null and not _route.is_empty():
		result["gold"] = state.gold
		result["relics_held"] = state.relics.size()
		result["route_summary"] = _combined_route_summary()
		result["acts"] = _act_records.duplicate(true)
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
	_plan_busy_until.clear()  # _sim_time restarts every room, so a busy time from the last room would lock slots in this one
	_plan_policy = PlanPolicy.new()
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


## "Name@(x, z) hp velocity" of every enemy still alive, for the soft-lock detail line.
func _alive_enemies_text() -> String:
	var parts: Array[String] = []
	for enemy: Enemy in _enemies():
		parts.append("%s@(%.1f, %.1f) hp %.1f vel %s stunned %s attack cooldown %.2f telegraph %.2f statuses %s" % [enemy.name, enemy.global_position.x, enemy.global_position.z, enemy.health.current_health, str(enemy.velocity), str(enemy.is_stunned()), float(enemy.get("_attack_cooldown_remaining")), float(enemy.get("_telegraph_remaining")), str(enemy.status_manager.active_status_ids())])
	return "; ".join(parts) if not parts.is_empty() else "none"


## Plays one room to "cleared", "lost" or "soft_lock".
func _play_room(run_seed: int, controller: RunController, room: Dictionary) -> String:
	var cap: int = _main.enemy_spawner.plan.max_alive()
	var prev_enemies: Dictionary = {}
	await get_tree().process_frame
	var hp_before: float = _player.health.current_health
	while true:
		Engine.time_scale = _scale
		await get_tree().process_frame
		# HP lost over the run (info for the sim reports): every drop between two frames, healing not netted off.
		_damage_taken += maxf(hp_before - _player.health.current_health, 0.0)
		hp_before = _player.health.current_health
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
			print("    soft lock detail: %s | player at %s hp %.1f immune %s light ready %s wind-up %s heavy ready %s" % [_alive_enemies_text(), str(_player.global_position), _player.health.current_health, str(_player.health.damage_immune), str(_player.attacks.is_ready(&"light")), str(_player.attacks.is_winding_up(&"light")), str(_player.attacks.is_ready(&"heavy"))])
			return "soft_lock"
		_room_min_hp = minf(_room_min_hp, _player.health.current_health)
		var enemies := _enemies()
		_check_world(enemies, cap, dt)
		_check_cooldowns(run_seed, room)
		_count_kills(enemies, prev_enemies)
		_track_boss(enemies)
		_bot_step(enemies)
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
			if _boss_log and not bool(_boss_cur.get("hooked", false)):
				_hook_boss_log(enemy as Boss)
	if has_boss and _boss_start < 0.0:
		_boss_start = _sim_time
	elif not has_boss and _boss_start >= 0.0 and _boss_end < 0.0:
		_boss_end = _sim_time


## --boss-log. Hooks the boss's attack signal and the player's damage signal for this room. Boss hits are told apart by the damage
## source (Health.last_source_id is a Boss) and the attack by its raw damage in data/bosses.json (the boss attacks have distinct damage
## values; a tie would list both ids). Anything else the player takes in the room (the adds) is "adds".
func _hook_boss_log(boss: Boss) -> void:
	_boss_cur["hooked"] = true
	_boss_cur["boss_id"] = boss.enemy_id
	_boss_cur["attacks"] = {}
	_boss_cur["adds"] = {"hits": 0, "hp": 0.0}
	_boss_cur["dodges"] = 0
	_boss_cur["phase_hp"] = [0.0, 0.0, 0.0]
	_boss_cur["volleys_in_lane"] = 0
	_boss_cur["volley_seq"] = 0
	_boss_cur["volleys_hit"] = {}  # volley number -> pellets that hit (PL3: volleys hit / volleys seen)
	_boss_cur["hp_at_spawn"] = _player.health.current_health
	boss.attack_landed.connect(func(attack_id: String, _hit_player: bool) -> void:
		var entry: Dictionary = _boss_entry(attack_id)
		entry["thrown"] = int(entry["thrown"]) + 1
		if attack_id == "volley":
			_boss_cur["volley_seq"] = int(_boss_cur["volley_seq"]) + 1
		if attack_id == "volley" and is_instance_valid(_player) and boss.in_threat(_player.global_position):
			_boss_cur["volleys_in_lane"] = int(_boss_cur["volleys_in_lane"]) + 1)
	_player.health.damaged.connect(func(amount: float, damage_type: String, _knockback: Vector3) -> void:
		_boss_hit(boss, amount, damage_type))


func _boss_entry(attack_id: String) -> Dictionary:
	var attacks: Dictionary = _boss_cur["attacks"]
	if not attacks.has(attack_id):
		attacks[attack_id] = {"thrown": 0, "hits": 0, "hp": 0.0}
	return attacks[attack_id]


func _boss_hit(boss: Boss, amount: float, damage_type: String) -> void:
	var health: Health = _player.health
	var source: Object = instance_from_id(health.last_source_id) if health.last_source_id != 0 else null
	if not (source is Boss):
		var adds: Dictionary = _boss_cur["adds"]
		adds["hits"] = int(adds["hits"]) + 1
		adds["hp"] = float(adds["hp"]) + amount
		return
	var ids: Array[String] = []
	var table: Dictionary = (BossConfig.boss(boss.enemy_id)["attacks"] as Dictionary)
	for id: Variant in table.keys():
		var attack: Dictionary = table[id]
		if is_equal_approx(float(attack["damage"]), health.last_raw_amount) and String(attack["damage_type"]) == damage_type:
			ids.append(String(id))
	var key: String = "|".join(ids) if not ids.is_empty() else "unknown"
	if key == "volley":
		# Pellets fly about 1.8 s and volleys are further apart than that, so a pellet hit belongs to the latest volley thrown.
		var volleys_hit: Dictionary = _boss_cur["volleys_hit"]
		volleys_hit[int(_boss_cur["volley_seq"])] = int(volleys_hit.get(int(_boss_cur["volley_seq"]), 0)) + 1
	var entry: Dictionary = _boss_entry(key)
	entry["hits"] = int(entry["hits"]) + 1
	entry["hp"] = float(entry["hp"]) + amount
	var phase: int = clampi(boss.phase_index, 0, 2)
	(_boss_cur["phase_hp"] as Array)[phase] = float((_boss_cur["phase_hp"] as Array)[phase]) + amount


## One boss room's log line, then stored for the summary.
func _boss_room_done(run_seed: int, outcome: String) -> void:
	if _boss_cur.is_empty() or not bool(_boss_cur.get("hooked", false)):
		_boss_cur = {}
		return
	_boss_cur["seed"] = run_seed
	_boss_cur["outcome"] = outcome
	var parts: Array[String] = []
	var total: float = float((_boss_cur["adds"] as Dictionary)["hp"])
	for id: Variant in (_boss_cur["attacks"] as Dictionary).keys():
		var entry: Dictionary = (_boss_cur["attacks"] as Dictionary)[id]
		total += float(entry["hp"])
		parts.append("%s: %d thrown, %d hits, %.1f HP" % [id, int(entry["thrown"]), int(entry["hits"]), float(entry["hp"])])
	var adds: Dictionary = _boss_cur["adds"]
	print("    boss log seed %d (%s): %.1f HP taken in the boss room (phase 1/2/3: %s) | %s | adds: %d hits, %.1f HP | dodges pressed %d | volleys fired with the bot inside a lane: %d" % [
		run_seed, outcome, total, str(_boss_cur["phase_hp"]), "; ".join(parts), int(adds["hits"]), float(adds["hp"]), int(_boss_cur["dodges"]), int(_boss_cur["volleys_in_lane"])])
	_boss_runs.append(_boss_cur)
	_boss_cur = {}


## --boss-log summary over all the runs that reached the boss: per attack, thrown, hits, HP, the hit rate, and the share of all boss-room HP.
func _boss_summary() -> void:
	if _boss_runs.is_empty():
		print("BOSS LOG: no run reached the boss room")
		return
	var totals: Dictionary = {}
	var adds_hp: float = 0.0
	var adds_hits: int = 0
	var all_hp: float = 0.0
	var dodges: int = 0
	var lane: int = 0
	var phase_hp: Array[float] = [0.0, 0.0, 0.0]
	var volleys_hit_total: int = 0
	var deaths: int = 0
	var wins: int = 0
	for run: Dictionary in _boss_runs:
		adds_hp += float((run["adds"] as Dictionary)["hp"])
		adds_hits += int((run["adds"] as Dictionary)["hits"])
		dodges += int(run["dodges"])
		lane += int(run["volleys_in_lane"])
		volleys_hit_total += (run["volleys_hit"] as Dictionary).size()
		for i in range(3):
			phase_hp[i] += float((run["phase_hp"] as Array)[i])
		if String(run["outcome"]) == "lost":
			deaths += 1
		elif String(run["outcome"]) == "cleared":
			wins += 1
		for id: Variant in (run["attacks"] as Dictionary).keys():
			var entry: Dictionary = (run["attacks"] as Dictionary)[id]
			if not totals.has(id):
				totals[id] = {"thrown": 0, "hits": 0, "hp": 0.0}
			totals[id]["thrown"] = int(totals[id]["thrown"]) + int(entry["thrown"])
			totals[id]["hits"] = int(totals[id]["hits"]) + int(entry["hits"])
			totals[id]["hp"] = float(totals[id]["hp"]) + float(entry["hp"])
			all_hp += float(entry["hp"])
	all_hp += adds_hp
	var n: float = float(_boss_runs.size())
	print("BOSS LOG over %d run(s) that reached the boss (%d won, %d died there): mean boss-room HP taken %.1f (phase 1/2/3 %.1f / %.1f / %.1f), dodges pressed per run %.1f" % [
		_boss_runs.size(), wins, deaths, all_hp / n, phase_hp[0] / n, phase_hp[1] / n, phase_hp[2] / n, float(dodges) / n])
	var volley_count: int = int(BossConfig.boss(String((_boss_runs[0])["boss_id"]))["attacks"]["volley"]["count"])
	for id: Variant in totals.keys():
		var t: Dictionary = totals[id]
		var rate_text: String = ""
		if String(id) == "volley":
			var pellets: int = int(t["thrown"]) * volley_count
			rate_text = " | %d of %d pellets hit (%.0f%%); bot inside a lane at fire time in %d of %d volleys | volleys hit %d of %d seen (%.0f%%), %.2f pellets and %.1f HP per hit volley" % [int(t["hits"]), pellets, 100.0 * float(t["hits"]) / maxf(float(pellets), 1.0), lane, int(t["thrown"]), volleys_hit_total, int(t["thrown"]), 100.0 * float(volleys_hit_total) / maxf(float(t["thrown"]), 1.0), float(t["hits"]) / maxf(float(volleys_hit_total), 1.0), float(t["hp"]) / maxf(float(volleys_hit_total), 1.0)]
		elif int(t["thrown"]) > 0:
			rate_text = " | hit rate %.0f%%" % (100.0 * float(t["hits"]) / float(t["thrown"]))
		print("  %-8s thrown %3d, hits %3d, HP %6.1f (%.0f%% of boss-room damage, %.1f HP per run)%s" % [id, int(t["thrown"]), int(t["hits"]), float(t["hp"]), 100.0 * float(t["hp"]) / maxf(all_hp, 0.001), float(t["hp"]) / n, rate_text])
	print("  adds     hits %3d, HP %6.1f (%.0f%%, %.1f HP per run)" % [adds_hits, adds_hp, 100.0 * adds_hp / maxf(all_hp, 0.001), adds_hp / n])


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
	_print_boss_times()
	_print_damage_summary()
	if _route_policy != "":
		_print_route_summary()
	_print_act_summary()
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
	for room_type: String in ["elite", "rest", "relic_room"]:
		var parts: Array[String] = []
		for index in range(1, 11):
			var n: int = int(index_counts.get("%s@%d" % [room_type, index], 0))
			if n > 0:
				parts.append("room %d: %.0f%%" % [index, 100.0 * float(n) / float(seeds)])
		print("    %s position: %s" % [room_type, ", ".join(parts)])
	_print_pick_rates()
	if _boss_log:
		_boss_summary()


## True when the run's route held a merchant node (MAP2-B report line).
func _visited_merchant(result: Dictionary) -> bool:
	return (result["types"] as Array).has("merchant") and int(result["rooms_reached"]) >= (result["types"] as Array).find("merchant") + 1


## MAP1-B: the route bots' report. Wins, relics held and gold per run (mean and median), fights and elites on the routes, the chest sizes the runs passed,
## and the MAP.md section 8 checks (informational): the relic route's median relics against its estimate, and the clear rate by route.
func _print_route_summary() -> void:
	var wins: int = 0
	var relics: Array[float] = []
	var golds: Array[float] = []
	var fights: Array[float] = []
	var elites: Array[float] = []
	var chest_counts: Dictionary = {}
	for result: Dictionary in _run_results:
		if String(result["outcome"]) == "won":
			wins += 1
		if not result.has("route_summary"):
			continue
		var info: Dictionary = result["route_summary"]
		relics.append(float(result["relics_held"]))
		golds.append(float(result["gold"]))
		fights.append(float(info["fights"]))
		elites.append(float(info["elites"]))
		for size_id: Variant in (info["chests"] as Array):
			chest_counts[String(size_id)] = int(chest_counts.get(String(size_id), 0)) + 1
	print("  ROUTE SUMMARY (%s, %s): %d of %d run(s) won | relics per run mean %.2f median %.1f | gold per run mean %.1f median %.1f | fights per route mean %.1f | elites per route mean %.1f | chest sizes on the routes %s" % [
		_route_policy, _sim_class if _sim_class != "" else CharacterDatabase.DEFAULT_ID, wins, _run_results.size(), _mean(relics), _median(relics), _mean(golds), _median(golds), _mean(fights), _mean(elites), str(chest_counts)])
	if _merchant or (_route_policy != "" and MerchantSwitch.shipped_is_on()):
		var spent: Array[float] = []
		var bought: Array[float] = []
		var removed: Array[float] = []
		var cards: Array[float] = []
		var visits: int = 0
		for result: Dictionary in _run_results:
			if result.has("route_summary"):
				spent.append(float(result["gold_spent"]))
				bought.append(float(result["shop_relics"]))
				removed.append(float(result["shop_removals"]))
				cards.append(float(result["shop_cards"]))
				visits += 1 if _visited_merchant(result) else 0
		print("  MERCHANT SUMMARY (%s, %s): %d of %d run(s) visited the merchant | gold spent per run mean %.1f median %.1f | relics bought per run mean %.2f median %.1f | removals per run mean %.2f | cards bought per run mean %.2f" % [
			_route_policy, _sim_class if _sim_class != "" else CharacterDatabase.DEFAULT_ID, visits, _run_results.size(), _mean(spent), _median(spent), _mean(bought), _median(bought), _mean(removed), _mean(cards)])
	print("  MAP.md section 8 checks (informational): the %s route's median relics %.1f (the estimate for relic routes is %s); clear rate %d%%" % [
		_route_policy, _median(relics), str(MapConfig.get_config()["path_rules"]["relic_route"]), roundi(100.0 * float(wins) / maxf(float(_run_results.size()), 1.0))])


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	return sorted[mid] if sorted.size() % 2 == 1 else (sorted[mid - 1] + sorted[mid]) / 2.0


## The rooms a run walks. A straight run: RunGenerator's list. With the map on: the route the policy plans through this seed's map. The run state is
## set to its first node (the bot skips the start pick), and each room is {index, type, wave_id, node_id, chest} like RunController's room list.
func _setup_route(run_seed: int) -> Array[Dictionary]:
	_route = []
	var state: RunState = RunSession.current
	if state == null or state.map.is_empty():
		return RunGenerator.generate(run_seed, RunConfig.get_config())
	return _plan_route(run_seed, true)


## The route through the current act's map (MAP3-B: called again at every act start). `skip_pick` puts the run on the route's first node (the bot skips the
## start pick of the first act); a later act leaves its pick open and the bot's first choice takes route[0].
func _plan_route(run_seed: int, skip_pick: bool) -> Array[Dictionary]:
	var state: RunState = RunSession.current
	var act_config: Dictionary = MapConfig.for_act(MapConfig.get_config(), state.act, state.acts_total)
	_route = RouteBot.plan(state.map, _route_policy if _route_policy != "" else "first", act_config, run_seed + state.act - 1)
	_route_summaries.append(RouteBot.summary(state.map, _route))
	if skip_pick:
		state.path = [_route[0]] as Array[int]
		state.pending = RunState.PENDING_NONE
		state.room_index = 0
	var rooms: Array[Dictionary] = []
	for index in range(_route.size()):
		var node: Dictionary = MapGraph.node(state.map, _route[index])
		rooms.append({"index": index, "type": String(node["type"]), "wave_id": String(node["wave_id"]), "node_id": int(node["id"]), "chest": RunNodes.chest_of(node) if String(node["type"]) == RunConfig.RELIC_ROOM else ""})
	return rooms


## The route reports of every act of this run added up ({fights, elites, relic_nodes, rest, chests}).
func _combined_route_summary() -> Dictionary:
	var total: Dictionary = {"fights": 0, "elites": 0, "relic_nodes": 0, "rest": 0, "chests": [] as Array[String]}
	for part: Dictionary in _route_summaries:
		for key: String in ["fights", "elites", "relic_nodes", "rest"]:
			total[key] = int(total[key]) + int(part[key])
		(total["chests"] as Array[String]).append_array(part["chests"] as Array[String])
	return total


## One act's end for the report: whether the act was cleared, the sim seconds its rooms took, and HP, relics and gold at its end.
func _record_act(state: RunState, cleared: bool, seconds: float, act_number: int) -> void:
	_act_records.append({
		"act": act_number, "cleared": cleared, "seconds": snappedf(seconds, 0.1), "hp": snappedf(state.hp, 0.1), "max_hp": snappedf(state.max_hp, 0.1),
		"relics": state.relics.size(), "gold": state.gold,
	})


## MAP3-B: the per-act report of the whole-run sim: clear rate, time, HP, relics and gold at each act's end, the time of each act against act 1, and the run totals.
func _print_act_summary() -> void:
	var by_act: Dictionary = {}
	var totals: Array[float] = []
	var finals: Array[float] = []
	var unspent: Array[float] = []
	var wins: int = 0
	for result: Dictionary in _run_results:
		if not result.has("acts"):
			continue
		var run_seconds: float = 0.0
		for record: Dictionary in (result["acts"] as Array):
			var key: int = int(record["act"])
			if not by_act.has(key):
				by_act[key] = {"reached": 0, "cleared": 0, "seconds": [] as Array[float], "hp": [] as Array[float], "hp_share": [] as Array[float], "relics": [] as Array[float], "gold": [] as Array[float]}
			var entry: Dictionary = by_act[key]
			entry["reached"] = int(entry["reached"]) + 1
			run_seconds += float(record["seconds"])
			if bool(record["cleared"]):
				entry["cleared"] = int(entry["cleared"]) + 1
				(entry["seconds"] as Array[float]).append(float(record["seconds"]))
				(entry["hp"] as Array[float]).append(float(record["hp"]))
				(entry["hp_share"] as Array[float]).append(float(record["hp"]) / maxf(float(record["max_hp"]), 1.0))
				(entry["relics"] as Array[float]).append(float(record["relics"]))
				(entry["gold"] as Array[float]).append(float(record["gold"]))
		if String(result["outcome"]) == "won":
			wins += 1
			totals.append(run_seconds)
			finals.append(float(result.get("relics_held", 0)))
			unspent.append(float(result.get("gold", 0)))
	if by_act.is_empty():
		return
	var keys: Array = by_act.keys()
	keys.sort()
	var act1_time: float = _median((by_act[keys[0]] as Dictionary)["seconds"] as Array[float])
	for key: Variant in keys:
		var entry: Dictionary = by_act[key]
		var median_time: float = _median(entry["seconds"] as Array[float])
		var versus: String = "" if int(key) == int(keys[0]) or act1_time <= 0.0 else " (%+.0f%% vs act 1)" % (100.0 * (median_time / act1_time - 1.0))
		print("  ACT %d: reached by %d run(s), cleared by %d | time median %.0f s mean %.0f s%s | HP at the act's end median %.1f (%.0f%% of max) | relics median %.1f | gold median %.0f" % [
			int(key), int(entry["reached"]), int(entry["cleared"]), median_time, _mean(entry["seconds"] as Array[float]), versus, _median(entry["hp"] as Array[float]),
			100.0 * _median(entry["hp_share"] as Array[float]), _median(entry["relics"] as Array[float]), _median(entry["gold"] as Array[float])])
	print("  ACTS TOTAL: %d of %d run(s) won every act | total sim time of the won runs median %.0f s mean %.0f s | relics at the end median %.1f | unspent gold median %.0f" % [
		wins, _run_results.size(), _median(totals), _mean(totals), _median(finals), _median(unspent)])


## Boss fight times (spawn to death) over the runs that reached the boss. A fight the boss survived to the room timeout is not a time: it is
## listed on its own, so one stuck fight cannot skew the median (BD1 qa carry-over).
func _print_boss_times() -> void:
	var finished: Array[float] = []
	var timed_out: Array[String] = []
	for result: Dictionary in _run_results:
		if not result.has("boss_fight_s"):
			continue
		if bool(result.get("boss_died", false)):
			finished.append(float(result["boss_fight_s"]))
		elif String(result["outcome"]) == "soft_lock":
			timed_out.append("seed %d" % int(result["seed"]))
	if finished.is_empty() and timed_out.is_empty():
		return
	finished.sort()
	var median: float = 0.0
	if not finished.is_empty():
		var mid: int = finished.size() / 2
		median = finished[mid] if finished.size() % 2 == 1 else (finished[mid - 1] + finished[mid]) / 2.0
	var mean: float = 0.0
	for t: float in finished:
		mean += t
	mean /= maxf(float(finished.size()), 1.0)
	print("  BOSS TIMES (spawn to boss death): %d finished: median %.1f s, mean %.1f s, range %.1f to %.1f s | %d TIMED OUT (boss alive at the %.0f s room limit; not in the median): %s" % [
		finished.size(), median, mean, finished[0] if not finished.is_empty() else 0.0, finished[finished.size() - 1] if not finished.is_empty() else 0.0, timed_out.size(), _room_timeout, ", ".join(timed_out) if not timed_out.is_empty() else "none"])


# ---- Damage by source (BD2-B; the run fingerprint check of BUILD_DEPTH 2) ----

## Records HP the player's side removed from an enemy, by origin. Enemy-on-player damage is player_damaged, not counted here.
func _on_hit_for_tally(target: Node, amount: float, _damage_type: String, _kind: StringName, origin: String, _position: Vector3) -> void:
	if CombatEventsRelay.team_of(target) != "enemy":
		return
	var key: String = origin if origin != "" else "unknown"
	_damage_run[key] = float(_damage_run.get(key, 0.0)) + amount


## Origins grouped for the fingerprint: light, heavy, each card by its slot type ("slot:attack_single"), each status ("status:burn"), each relic ("relic:<id>").
func _damage_group(origin: String) -> String:
	if origin.begins_with("card:"):
		return "slot:" + String(CardDatabase.get_card(origin.substr(5)).get("slot_type", "?"))
	return origin


## "light 45.2 (30%), slot:attack_single 33.0 (22%), status:burn 12.0 (8%) | total 150.3", biggest first.
func _damage_line(by_origin: Dictionary) -> String:
	var grouped: Dictionary = {}
	var total: float = 0.0
	for origin: Variant in by_origin.keys():
		var group: String = _damage_group(String(origin))
		grouped[group] = float(grouped.get(group, 0.0)) + float(by_origin[origin])
		total += float(by_origin[origin])
	var keys: Array = grouped.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(grouped[a]) > float(grouped[b]))
	var parts: Array[String] = []
	for key: Variant in keys:
		parts.append("%s %.1f (%.0f%%)" % [str(key), float(grouped[key]), 100.0 * float(grouped[key]) / maxf(total, 0.001)])
	return "%s | total %.1f" % [", ".join(parts), total]


## All runs together: the grouped line, then each card's damage (so a card that carries a plan shows), and the L1 distance of each
## run's grouped shares from the mean run (the "fingerprint spread": 0 = every run spends damage alike, 2 = nothing in common).
func _print_damage_summary() -> void:
	if _damage_by_run.is_empty():
		return
	print("  DAMAGE BY SOURCE over %d run(s): %s" % [_damage_by_run.size(), _damage_line(_damage_all)])
	var cards: Array[String] = []
	var keys: Array = _damage_all.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(_damage_all[a]) > float(_damage_all[b]))
	for key: Variant in keys:
		if String(key).begins_with("card:") or String(key).begins_with("relic:"):
			cards.append("%s %.1f" % [str(key), float(_damage_all[key])])
	print("    per card and relic: %s" % ", ".join(cards))
	var shares: Array[Dictionary] = []
	var names: Dictionary = {}
	for run: Dictionary in _damage_by_run:
		var grouped: Dictionary = {}
		var total: float = 0.0
		for origin: Variant in run.keys():
			var group: String = _damage_group(String(origin))
			grouped[group] = float(grouped.get(group, 0.0)) + float(run[origin])
			total += float(run[origin])
		for group: Variant in grouped.keys():
			grouped[group] = float(grouped[group]) / maxf(total, 0.001)
			names[group] = true
		shares.append(grouped)
	var mean: Dictionary = {}
	for group: Variant in names.keys():
		var sum: float = 0.0
		for run_shares: Dictionary in shares:
			sum += float(run_shares.get(group, 0.0))
		mean[group] = sum / float(shares.size())
	var distances: Array[String] = []
	var distance_total: float = 0.0
	for run_shares: Dictionary in shares:
		var distance: float = 0.0
		for group: Variant in names.keys():
			distance += absf(float(run_shares.get(group, 0.0)) - float(mean[group]))
		distances.append("%.2f" % distance)
		distance_total += distance
	print("    fingerprint spread (L1 distance of each run's shares from the mean run; mean %.2f): %s" % [distance_total / float(shares.size()), ", ".join(distances)])


## --sim-swap: replaces one copy of <old> by <new> in the fresh run's deck. False (and a failed run) when the swap breaks the deck rules.
func _apply_swap(run_seed: int) -> bool:
	if _swap_out == "":
		return true
	var state: RunState = RunSession.current
	var index: int = state.deck.find(_swap_out)
	if index < 0:
		_fail("run %d: -Swap: the starting deck has no '%s' to take out" % [run_seed, _swap_out])
		return false
	var problems: Array[String] = DeckRules.can_swap(state.deck, _swap_out, _swap_in, DeckRules.shipped_config(), DeckRules.slot_map_from_database(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())
	if not problems.is_empty():
		_fail("run %d: -Swap %s=%s breaks the deck rules: %s" % [run_seed, _swap_out, _swap_in, "; ".join(problems)])
		return false
	state.deck[index] = _swap_in
	return true


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
	# Only the cards of the pools the played character draws from (the Rogue's by default), so a class's report
	# does not list the other class's cards as never cast.
	var played_pools: Array[String] = CharacterDatabase.pools(_sim_class if _sim_class != "" else CharacterDatabase.DEFAULT_ID)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var ids: Array[String] = []
		for card: Variant in CardDatabase.cards_for_slot_type(slot_type):
			if played_pools.has(String((card as Dictionary).get("pool", ""))):
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
