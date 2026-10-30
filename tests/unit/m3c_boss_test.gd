class_name M3cBossTest
extends GdUnitTestSuite
## Milestone 3c: the boss. Data and its validator, phases and thresholds, attack selection, telegraph sizes against the
## real hit queries, fairness (every attack escapable), transition invulnerability, the unstun rule, the pinning rule,
## adds, and the death beat before the win screen.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const BOSS_ID := "boss_guardian"


func before_test() -> void:
	Juice.hit_stop_enabled = false  # no slow-mo or hit-stop: tests count frames
	RunSession.clear()


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0
	RunSession.clear()
	BossConfig.reset_cache()


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH)) as Dictionary


func _known() -> Array[String]:
	return EnemyConfig.enemy_ids()


func _boss_def() -> Dictionary:
	return (_config()["bosses"] as Dictionary)[BOSS_ID]


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


## A boss in `main`, `distance` metres in front of (-Z of) the player, chasing it. Its own physics process is on.
func _boss(main: Main, distance: float = 8.0) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -distance)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0  # phase and HP-bar tests count raw HP; armor has its own tests (a1_armor_test.gd)
	return boss


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


## Runs physics frames until `done` is true or `max_seconds` of game time pass. Returns whether it became true.
func _until(done: Callable, max_seconds: float) -> bool:
	var frames: int = int(max_seconds * float(Engine.physics_ticks_per_second))
	for i in range(frames):
		if done.call():
			return true
		await get_tree().physics_frame
	return bool(done.call())


# ---- Data ----

func test_shipped_boss_data_is_valid_and_loads() -> void:
	assert_array(BossConfig.validate(_config(), _known())).is_empty()
	assert_array(BossConfig.load_problems()).is_empty()
	assert_bool(BossConfig.has_boss(BOSS_ID)).is_true()
	assert_array(BossConfig.boss_ids()).contains([BOSS_ID])


func test_the_boss_is_a_boss_rank_enemy_in_the_enemy_table() -> void:
	assert_str(EnemyConfig.rank_for(BOSS_ID)).is_equal("boss")
	assert_str(EnemyConfig.scene_path_for(BOSS_ID)).is_equal(BOSS_PATH)
	assert_array(EnemyConfig.validate(JSON.parse_string(FileAccess.get_file_as_string(EnemyConfig.PATH)))).is_empty()


func test_the_boss_has_three_phases_and_at_least_three_attacks_within_the_rules() -> void:
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	assert_int((def["phases"] as Array).size()).is_equal(3)
	assert_int((def["attacks"] as Dictionary).size()).is_greater_equal(3)
	assert_array(BossRules.thresholds(def["phases"])).is_equal([0.66, 0.33])
	var rules: Dictionary = BossConfig.rules()
	assert_float(float((def["transition"] as Dictionary)["duration"])).is_less_equal(1.5)
	assert_float(float(rules["min_telegraph"])).is_greater_equal(0.6)
	# The attacks are all distinct kinds from the shared shapes.
	var kinds: Array = []
	for attack: Dictionary in (def["attacks"] as Dictionary).values():
		if not kinds.has(attack["kind"]):
			kinds.append(attack["kind"])
	assert_int(kinds.size()).is_greater_equal(3)


func test_adds_are_capped_well_under_the_room_cap() -> void:
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	var max_alive: int = int(WaveConfig.get_config()["max_alive"])
	assert_int(1 + int(def["max_adds_alive"])).is_less_equal(max_alive / 2)


func _mutated(mutator: Callable) -> Dictionary:
	var config: Dictionary = _config()
	mutator.call(config)
	return config


func test_validation_rejects_bad_boss_data() -> void:
	var cases: Dictionary = {
		"telegraph under the minimum": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["windup"] = 0.5,
		"windup scale pushes a telegraph under the minimum": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][2]["windup_scale"] = 0.5,
		"transition too long": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["transition"]["duration"] = 1.6,
		"resistance over the 50% cap": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["resistance"] = 0.6,
		"thresholds not descending": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][2]["enters_at"] = 0.7,
		"first phase not at 1.0": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][0]["enters_at"] = 0.9,
		"a threshold of 0": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][2]["enters_at"] = 0.0,
		"one phase only": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"] = [c["bosses"][BOSS_ID]["phases"][0]],
		"unknown attack id in a phase": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][0]["attacks"][0]["id"] = "nope",
		"unknown attack kind": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["kind"] = "laser",
		"unknown attack key": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["colour"] = "red",
		"a cone key on an aoe": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["slam"]["range"] = 3.0,
		"missing kind key": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["charge"].erase("distance"),
		"only two attacks": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"] = {"smash": c["bosses"][BOSS_ID]["attacks"]["smash"], "slam": c["bosses"][BOSS_ID]["attacks"]["slam"]},
		"weights add up to 0": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][0]["attacks"] = [{"id": "smash", "weight": 0}],
		"summon above the add cap": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1]["summon"]["count"] = 9,
		"summon of an unknown enemy": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1]["summon"]["enemy"] = "dragon",
		"boss that is not an enemy": func(c: Dictionary) -> void: c["bosses"]["ghost"] = c["bosses"][BOSS_ID],
		"unknown boss key": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["armor"] = 3,
		"min_range not below max_range": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["min_range"] = 9.0,
		"nan hp": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["max_health"] = "lots",
		"rules telegraph below 0.6": func(c: Dictionary) -> void: c["rules"]["min_telegraph"] = 0.3,
		"no bosses": func(c: Dictionary) -> void: c["bosses"] = {},
	}
	for label: String in cases.keys():
		var broken: Dictionary = _mutated(cases[label])
		assert_array(BossConfig.validate(broken, _known())).override_failure_message("accepted: " + label).is_not_empty()


func test_the_stun_rule_for_bosses_is_immunity_in_data() -> void:
	var stun: Dictionary = StatusDatabase.get_status("stun")
	assert_float(float((stun["rank_multipliers"] as Dictionary)["boss"])).is_less_equal(0.0)


# ---- Rules (pure) ----

func test_phase_for_fraction_and_floors() -> void:
	var phases: Array = BossConfig.boss(BOSS_ID)["phases"]
	assert_int(BossRules.phase_for_fraction(phases, 1.0)).is_equal(0)
	assert_int(BossRules.phase_for_fraction(phases, 0.67)).is_equal(0)
	assert_int(BossRules.phase_for_fraction(phases, 0.66)).is_equal(1)
	assert_int(BossRules.phase_for_fraction(phases, 0.4)).is_equal(1)
	assert_int(BossRules.phase_for_fraction(phases, 0.33)).is_equal(2)
	assert_int(BossRules.phase_for_fraction(phases, 0.0)).is_equal(2)
	assert_float(BossRules.floor_hp(phases, 1, 520.0)).is_equal_approx(343.2, 0.01)
	assert_float(BossRules.floor_hp(phases, 2, 520.0)).is_equal_approx(171.6, 0.01)
	assert_float(BossRules.floor_hp(phases, 3, 520.0)).is_equal(0.0)


func test_each_phase_picks_only_from_its_own_list_and_distance_window() -> void:
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	var phases: Array = def["phases"]
	var attacks: Dictionary = def["attacks"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen: Array[Dictionary] = [{}, {}, {}]
	for phase_index in range(3):
		for distance: float in [2.0, 3.0, 6.0, 10.0, 16.0]:
			var entries := BossRules.eligible(phases[phase_index], attacks, distance)
			for e: Dictionary in entries:
				var attack: Dictionary = attacks[String(e["id"])]
				assert_float(distance).is_between(float(attack["min_range"]), float(attack["max_range"]))
			for i in range(200):
				var picked := BossRules.pick(entries, rng)
				if picked != "":
					seen[phase_index][picked] = true
	assert_bool(seen[0].has("charge")).override_failure_message("phase 1 must not charge").is_false()
	assert_bool(seen[1].has("charge")).is_true()
	assert_bool(seen[2].has("charge")).is_true()
	for phase_index in range(3):
		assert_bool(seen[phase_index].has("smash")).is_true()
		assert_bool(seen[phase_index].has("volley")).is_true()
	# Close in only the close attacks; far away no smash.
	var close_ids: Array = []
	for e: Dictionary in BossRules.eligible(phases[2], attacks, 2.0):
		close_ids.append(e["id"])
	assert_array(close_ids).contains(["smash", "slam"])
	assert_bool(close_ids.has("charge")).is_false()
	assert_bool(close_ids.has("volley")).is_false()
	var far_ids: Array = []
	for e: Dictionary in BossRules.eligible(phases[2], attacks, 12.0):
		far_ids.append(e["id"])
	assert_bool(far_ids.has("smash")).is_false()
	assert_array(far_ids).contains(["slam", "charge", "volley"])


func test_weighted_pick_follows_the_weights_and_repeats_from_a_seed() -> void:
	var entries: Array[Dictionary] = [{"id": "a", "weight": 3.0}, {"id": "b", "weight": 1.0}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a_count: int = 0
	var first: Array[String] = []
	for i in range(2000):
		var p := BossRules.pick(entries, rng)
		if p == "a":
			a_count += 1
		if i < 20:
			first.append(p)
	assert_float(float(a_count) / 2000.0).is_between(0.70, 0.80)
	rng.seed = 5
	var again: Array[String] = []
	for i in range(20):
		again.append(BossRules.pick(entries, rng))
	assert_array(again).is_equal(first)
	assert_str(BossRules.pick([], rng)).is_equal("")


func test_every_telegraph_is_long_enough_in_every_phase() -> void:
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	var minimum: float = float(BossConfig.rules()["min_telegraph"])
	for phase: Dictionary in def["phases"]:
		for entry: Dictionary in phase["attacks"]:
			var attack: Dictionary = def["attacks"][String(entry["id"])]
			assert_float(BossRules.windup(attack, phase)).override_failure_message("%s in %s" % [entry["id"], phase["name"]]).is_greater_equal(minimum)


func test_volley_angles_span_the_spread_evenly() -> void:
	assert_array(BossRules.volley_angles(1, 40.0)).is_equal([0.0])
	var five := BossRules.volley_angles(5, 48.0)
	assert_float(five[0]).is_equal_approx(-24.0, 0.001)
	assert_float(five[4]).is_equal_approx(24.0, 0.001)
	assert_float(five[2]).is_equal_approx(0.0, 0.001)


func test_every_attack_can_be_escaped_by_walking_or_the_dodge() -> void:
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	var player: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	var walk: float = player.move_speed
	player.free()
	var dodge: Dictionary = PlayerConfig.dodge()
	var dodge_distance: float = float(dodge["speed"]) * float(dodge["duration"])
	assert_float(dodge_distance).is_equal_approx(5.0, 0.001)
	for phase: Dictionary in def["phases"]:
		for entry: Dictionary in phase["attacks"]:
			var attack: Dictionary = def["attacks"][String(entry["id"])]
			var windup: float = BossRules.windup(attack, phase)
			var gap: float = windup + float(attack["recover"]) + float(phase["attack_gap"])
			var result: Dictionary = BossRules.escape(attack, windup, walk, dodge_distance, gap, float(dodge["cooldown"]))
			assert_bool(bool(result["ok"])).override_failure_message("%s in %s: %s" % [entry["id"], phase["name"], str(result)]).is_true()
			# Stronger: shipped attacks need no dodge at all, walking is enough.
			assert_bool(bool(result["walk_ok"])).override_failure_message("%s in %s needs the dodge: %s" % [entry["id"], phase["name"], str(result)]).is_true()


func test_the_escape_check_catches_an_unfair_attack() -> void:
	var unfair: Dictionary = {"kind": "aoe", "radius": 9.0, "windup": 0.6}
	var tight: Dictionary = BossRules.escape(unfair, 0.6, 6.0, 5.0, 0.2, 0.8)
	assert_bool(bool(tight["ok"])).is_false()
	var dodge_only: Dictionary = {"kind": "aoe", "radius": 4.0, "windup": 0.6}
	assert_bool(bool(BossRules.escape(dodge_only, 0.6, 6.0, 5.0, 2.0, 0.8)["walk_ok"])).is_false()
	assert_bool(bool(BossRules.escape(dodge_only, 0.6, 6.0, 5.0, 2.0, 0.8)["ok"])).is_true()
	assert_bool(bool(BossRules.escape(dodge_only, 0.6, 6.0, 5.0, 0.5, 0.8)["ok"])).override_failure_message("a dodge-only attack needs a gap that covers the dodge cooldown").is_false()


# ---- The boss in a scene ----

func test_spawned_boss_takes_its_stats_from_data_and_resists_every_element_by_half() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	assert_float(boss.health.max_health).is_equal(float(def["max_health"]))
	assert_float(boss.health.current_health).is_equal(float(def["max_health"]))
	assert_str(boss.display_name()).is_equal(String(def["display_name"]))
	assert_str(boss.status_manager.rank).is_equal("boss")
	assert_bool(boss.is_in_group("boss")).is_true()
	var elements := TierRules.element_ids()
	assert_int(elements.size()).is_greater(0)
	for element: String in elements:
		assert_float(boss.health.get_resistance(element)).override_failure_message(element).is_equal_approx(0.5, 0.0001)
	var before := boss.health.current_health
	boss.health.hp_floor = 0.0
	boss.health.take_damage(10.0, "fire")
	assert_float(before - boss.health.current_health).is_equal_approx(5.0, 0.001)
	before = boss.health.current_health
	boss.health.base_armor = float(def["armor"])  # the helper zeroes it; the data value halves a physical hit (armor 50, K 50)
	boss.health.take_damage(10.0, "physical")
	assert_float(before - boss.health.current_health).override_failure_message("physical goes through armor, not resistance").is_equal_approx(5.0, 0.001)
	assert_array(boss.phase_thresholds()).is_equal([0.66, 0.33])
	assert_int(boss.phase_count()).is_equal(3)


func test_hurtbox_matches_the_body() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(1)
	var shape := (boss.hurtbox.get_node("HurtboxShape") as CollisionShape3D).shape as CapsuleShape3D
	var body_shape := (boss.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	assert_float(shape.radius).is_greater_equal(body_shape.radius)
	assert_float(shape.radius - body_shape.radius).is_less_equal(0.1)
	assert_float(boss.body_radius).is_equal_approx(body_shape.radius, 0.0001)
	var mesh := (boss.get_node("BodyMesh") as MeshInstance3D).mesh as CapsuleMesh
	assert_float(mesh.radius).is_equal_approx(body_shape.radius, 0.0001)


func test_the_boss_cannot_be_stunned_and_says_so() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(1)
	var before_popups := Juice.popup_count
	boss.status_manager.apply_status("stun", StatusDatabase.get_status("stun"), 3.0)
	assert_bool(boss.is_stunned()).is_false()
	assert_int(Juice.popup_count).override_failure_message("the IMMUNE popup path").is_greater(before_popups)
	# And it keeps attacking: a wind-up survives the stun attempt.
	boss._begin_windup("smash")
	boss.status_manager.apply_status("stun", StatusDatabase.get_status("stun"), 3.0)
	assert_bool(boss.is_stunned()).is_false()
	assert_str(boss.state_name()).is_equal("WINDUP")


## Puts the boss's wind-up fields in place for `attack_id` without needing a target or time passing.
func _arm(boss: Boss, attack_id: String) -> void:
	boss.set_physics_process(false)
	boss._attack_id = attack_id
	boss._attack = boss._attacks[attack_id]
	boss._state = Boss.State.WINDUP
	boss._lock_dir = Vector3(0.0, 0.0, -1.0)
	boss._lock_point = boss.global_position + Vector3(0.0, 0.0, -4.0)
	boss._charge_start = boss.global_position
	boss.global_transform.basis = Basis.looking_at(boss._lock_dir, Vector3.UP)


func _hurt_by(main: Main, boss: Boss, offset: Vector3, land: Callable) -> bool:
	main.player.health.damage_immune = false
	main.player.health.current_health = main.player.health.max_health
	main.player._knockback_velocity = Vector3.ZERO
	main.player.global_position = boss.global_position + offset
	await _frames(2)
	land.call()
	return main.player.health.current_health < main.player.health.max_health


func test_the_cone_telegraph_reach_is_where_the_hit_lands() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 30.0)
	await _frames(1)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	_arm(boss, "smash")
	boss.global_position = Vector3(0.0, 0.0, 6.0)
	boss._lock_dir = Vector3(0.0, 0.0, -1.0)
	var reach: float = BossRules.cone_reach(boss._attack)
	assert_float(reach).is_equal_approx(VfxSizing.lateral_reach_vs_player(3.4), 0.0001)
	var land := func() -> void: boss._land_attack()
	var inside := await _hurt_by(main, boss, Vector3(0.0, 0.0, -(reach - 0.05)), land)
	_arm(boss, "smash")
	var outside := await _hurt_by(main, boss, Vector3(0.0, 0.0, -(reach + 0.05)), land)
	assert_bool(inside).override_failure_message("just inside the drawn wedge must be hit").is_true()
	assert_bool(outside).override_failure_message("just outside the drawn wedge must be safe").is_false()
	# Beside the wedge (outside its half angle) is safe, just inside the angle is hit.
	_arm(boss, "smash")
	var half: float = deg_to_rad(float(boss._attack["half_angle_degrees"]))
	var dist: float = reach * 0.6
	var inside_angle := await _hurt_by(main, boss, Vector3(-sin(half - 0.05) * dist, 0.0, -cos(half - 0.05) * dist), land)
	_arm(boss, "smash")
	var outside_angle := await _hurt_by(main, boss, Vector3(-sin(half + 0.12) * dist, 0.0, -cos(half + 0.12) * dist), land)
	assert_bool(inside_angle).is_true()
	assert_bool(outside_angle).is_false()


func test_the_ground_pound_telegraph_radius_is_where_the_hit_lands() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 30.0)
	await _frames(1)
	boss.global_position = Vector3(0.0, 0.0, 12.0)
	_arm(boss, "slam")
	var center: Vector3 = Vector3(0.0, 0.0, 0.0)
	boss._lock_point = center
	var reach: float = BossRules.aoe_reach(boss._attack)
	assert_float(reach).is_equal_approx(VfxSizing.lateral_reach_vs_player(3.2), 0.0001)
	var land := func() -> void: boss._land_attack()
	var inside := await _hurt_by_at(main, center + Vector3(reach - 0.05, 0.0, 0.0), land)
	_arm(boss, "slam")
	boss._lock_point = center
	var outside := await _hurt_by_at(main, center + Vector3(reach + 0.05, 0.0, 0.0), land)
	assert_bool(inside).is_true()
	assert_bool(outside).is_false()


func _hurt_by_at(main: Main, point: Vector3, land: Callable) -> bool:
	main.player.health.damage_immune = false
	main.player.health.current_health = main.player.health.max_health
	main.player._knockback_velocity = Vector3.ZERO
	main.player.global_position = point
	await _frames(2)
	land.call()
	return main.player.health.current_health < main.player.health.max_health


func test_the_charge_lane_width_is_where_the_sweep_hits() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 30.0)
	await _frames(1)
	boss.global_position = Vector3(0.0, 0.0, 6.0)
	_arm(boss, "charge")
	var half_width: float = BossRules.charge_half_width(boss._attack)
	assert_float(half_width).is_equal_approx(VfxSizing.lateral_reach_vs_player(1.2), 0.0001)
	var sweep := func() -> void: boss._charge_sweep()
	var inside := await _hurt_by_at(main, boss.global_position + Vector3(half_width - 0.05, 0.0, 0.0), sweep)
	var outside := await _hurt_by_at(main, boss.global_position + Vector3(half_width + 0.05, 0.0, 0.0), sweep)
	assert_bool(inside).is_true()
	assert_bool(outside).is_false()
	assert_float(BossRules.charge_length(boss._attack)).is_equal_approx(11.0 + 2.0 * half_width, 0.0001)


func test_in_threat_matches_the_drawn_shapes_and_escape_direction_leaves_them() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 30.0)
	await _frames(1)
	boss.global_position = Vector3.ZERO
	for attack_id: String in ["smash", "slam", "volley", "charge"]:
		_arm(boss, attack_id)
		var found: int = 0
		for x in range(-20, 21, 2):
			for z in range(-20, 21, 2):
				var point := Vector3(float(x) * 0.5, 0.0, float(z) * 0.5)
				if not boss.in_threat(point):
					assert_vector(boss.escape_direction(point)).is_equal(Vector3.ZERO)
					continue
				found += 1
				var dir: Vector3 = boss.escape_direction(point)
				assert_float(dir.length()).is_equal_approx(1.0, 0.001)
				var out: bool = false
				for step in range(1, 49):
					if not boss.in_threat(point + dir * float(step) * 0.25):
						out = true
						break
				assert_bool(out).override_failure_message("%s: no way out from %s" % [attack_id, str(point)]).is_true()
		assert_int(found).override_failure_message("%s threatens nothing?" % attack_id).is_greater(0)


func test_walking_out_of_the_telegraph_beats_the_wind_up() -> void:
	# Fairness by simulation: from every spot in the area, walking the escape direction at walk speed leaves
	# the hazard before the attack lands (volley: the shots are checked analytically above).
	var main := _spawn_main()
	var boss := _boss(main, 30.0)
	await _frames(1)
	boss.global_position = Vector3.ZERO
	var walk: float = main.player.move_speed
	var def: Dictionary = BossConfig.boss(BOSS_ID)
	for phase: Dictionary in def["phases"]:
		for attack_id: String in ["smash", "slam", "charge"]:
			_arm(boss, attack_id)
			var windup: float = BossRules.windup(boss._attack, phase)
			var worst: float = 0.0
			for x in range(-30, 31):
				for z in range(-30, 31):
					var point := Vector3(float(x) * 0.4, 0.0, float(z) * 0.4)
					if not boss.in_threat(point):
						continue
					var dir: Vector3 = boss.escape_direction(point)
					var t: float = 0.0
					var probe: Vector3 = point
					while boss.in_threat(probe) and t < 5.0:
						t += 0.02
						probe = point + dir * walk * t
					worst = maxf(worst, t)
			assert_float(worst).override_failure_message("%s in %s: worst escape %.2f s against a %.2f s telegraph" % [attack_id, phase["name"], worst, windup]).is_less(windup)


func test_phase_transition_holds_at_the_threshold_is_invulnerable_and_short() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var started: Array[int] = []
	var ended: Array[int] = []
	var changed: Array[int] = []
	boss.transition_started.connect(func(index: int, _d: float) -> void: started.append(index))
	boss.transition_ended.connect(func(index: int) -> void: ended.append(index))
	boss.phase_changed.connect(func(index: int, _n: String) -> void: changed.append(index))
	var max_hp: float = boss.health.max_health
	# One huge hit crossing BOTH thresholds stops at the first one.
	boss.health.take_damage(max_hp * 0.8, "physical")
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.66, 0.01)
	assert_array(started).is_equal([1])
	assert_bool(boss.is_transitioning()).is_true()
	assert_int(boss.phase_index).is_equal(0)
	# Invulnerable meanwhile (and Burn ticks too: all damage is refused).
	var hp := boss.health.current_health
	boss.health.take_damage(50.0, "physical")
	boss.health.take_damage(50.0, "fire", Vector3.ZERO, null, Health.KIND_DOT)
	assert_float(boss.health.current_health).is_equal(hp)
	var duration: float = float((BossConfig.boss(BOSS_ID)["transition"] as Dictionary)["duration"])
	assert_float(duration).is_less_equal(1.5)
	var finished := await _until(func() -> bool: return not boss.is_transitioning(), duration + 0.3)
	assert_bool(finished).is_true()
	assert_array(ended).is_equal([1])
	assert_array(changed).is_equal([1])
	assert_int(boss.phase_index).is_equal(1)
	assert_bool(boss.health.damage_immune).is_false()
	# Vulnerable again, and the next floor is the second threshold.
	boss.health.take_damage(max_hp * 0.8, "physical")
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.33, 0.01)
	assert_array(started).is_equal([1, 2])
	await _until(func() -> bool: return boss.phase_index == 2, duration + 0.3)
	assert_int(boss.phase_index).is_equal(2)
	assert_float(boss.health.hp_floor).is_equal(0.0)
	# The last phase dies for real.
	boss.health.take_damage(max_hp, "physical")
	assert_bool(boss.health.is_dead()).is_true()
	assert_bool(boss.is_defeated()).is_true()


func test_a_transition_cancels_the_attack_in_progress() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 6.0)
	await _frames(2)
	boss._attack_cooldown_remaining = 0.0
	boss._begin_windup("smash")
	assert_str(boss.state_name()).is_equal("WINDUP")
	var landed: Array[String] = []
	boss.attack_landed.connect(func(id: String, _hit: bool) -> void: landed.append(id))
	boss.health.take_damage(boss.health.max_health * 0.5, "physical")
	assert_bool(boss.is_transitioning()).is_true()
	assert_float(boss.telegraph_left()).is_equal(0.0)
	await _frames(30)
	assert_array(landed).is_empty()


func test_the_boss_picks_telegraphs_and_lands_attacks_by_itself() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 7.0)
	var telegraphed: Array[String] = []
	var landed: Array[String] = []
	boss.attack_telegraphed.connect(func(id: String, _label: String, windup: float) -> void:
		telegraphed.append(id)
		assert_float(windup).is_greater_equal(0.6))
	boss.attack_landed.connect(func(id: String, _hit: bool) -> void: landed.append(id))
	var ok := await _until(func() -> bool: return landed.size() >= 3, 25.0)
	assert_bool(ok).override_failure_message("telegraphed %s landed %s" % [str(telegraphed), str(landed)]).is_true()
	assert_int(telegraphed.size()).is_greater_equal(landed.size())
	for id: String in landed:
		assert_bool((BossConfig.boss(BOSS_ID)["attacks"] as Dictionary).has(id)).is_true()
	assert_bool(boss.global_position.distance_to(main.player.global_position) < 40.0).is_true()


func test_each_attack_hurts_a_player_who_stays_and_not_one_who_leaves() -> void:
	# Whole-flow check per attack through the real wind-up timer: a stationary player is hurt, a walker is not.
	for attack_id: String in ["smash", "slam", "charge"]:
		var main := _spawn_main()
		var dist: float = 2.5 if attack_id == "smash" else (8.0 if attack_id == "charge" else 4.0)
		var boss := _boss(main, dist)
		boss.set_physics_process(true)
		boss._attack_cooldown_remaining = 99.0
		await _frames(2)
		main.player.global_position = Vector3(0.0, 0.0, 0.0)
		boss.global_position = Vector3(0.0, 0.0, -dist)
		await _frames(2)
		boss._begin_windup(attack_id)
		var start_hp: float = main.player.health.current_health
		await _until(func() -> bool: return boss.state_name() == "RECOVER" or boss.state_name() == "CHASE", 3.0)
		assert_float(main.player.health.current_health).override_failure_message("%s should hurt a player who stays" % attack_id).is_less(start_hp)
		main.queue_free()
		await get_tree().process_frame


func test_a_walking_player_escapes_every_attack_in_the_real_flow() -> void:
	for attack_id: String in ["smash", "slam", "charge"]:
		var main := _spawn_main()
		var dist: float = 2.5 if attack_id == "smash" else (8.0 if attack_id == "charge" else 4.0)
		var boss := _boss(main, dist)
		boss._attack_cooldown_remaining = 99.0
		await _frames(2)
		main.player.global_position = Vector3.ZERO
		boss.global_position = Vector3(0.0, 0.0, -dist)
		await _frames(2)
		boss._begin_windup(attack_id)
		var walker_hp: float = main.player.health.current_health
		var done := false
		var elapsed: float = 0.0
		while elapsed < 3.0 and not done:
			var dir: Vector3 = boss.escape_direction(main.player.global_position)
			main.player.global_position += dir * main.player.move_speed * (1.0 / 60.0)
			await get_tree().physics_frame
			elapsed += 1.0 / 60.0
			done = boss.state_name() == "RECOVER" or boss.state_name() == "CHASE"
		assert_float(main.player.health.current_health).override_failure_message("%s hit a walker" % attack_id).is_equal(walker_hp)
		main.queue_free()
		await get_tree().process_frame


# ---- Pinning ----

func test_the_boss_is_not_solid_while_it_charges_and_a_pinned_player_is_never_trapped() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 9.0)
	boss._attack_cooldown_remaining = 99.0
	await _frames(2)
	# Player pinned against the north wall, the boss charging at it from the south.
	main.player.global_position = Vector3(0.0, 0.0, -18.0)
	boss.global_position = Vector3(0.0, 0.0, -8.0)
	await _frames(2)
	assert_int(boss.collision_layer).is_equal(4)
	boss._begin_windup("charge")
	var became_phased := await _until(func() -> bool: return boss.is_phased(), 1.5)
	assert_bool(became_phased).is_true()
	assert_int(boss.collision_layer).override_failure_message("a charging boss has no body layer").is_equal(0)
	assert_int(boss.collision_mask & CollisionLayers.PLAYER_BODY).is_equal(0)
	# It runs through the player's spot without being stopped by it ...
	var passed := await _until(func() -> bool: return boss.state_name() == "RECOVER", 2.0)
	assert_bool(passed).is_true()
	assert_float(boss.global_position.z).override_failure_message("boss was stopped by the pinned player").is_less(-16.0)
	# ... and goes solid again only once the player's body is clear of its own.
	var clear := await _until(func() -> bool: return not boss.is_phased(), 3.0)
	assert_bool(clear).is_true()
	assert_int(boss.collision_layer).is_equal(4)
	var gap: float = Vector2(boss.global_position.x - main.player.global_position.x, boss.global_position.z - main.player.global_position.z).length()
	assert_float(gap).is_greater_equal(boss.body_radius + 0.4)
	# The player can walk away freely afterwards (sideways along the wall: the solid boss may be in front).
	var before: Vector3 = main.player.global_position
	for i in range(10):
		main.player.move_and_collide(Vector3(0.1, 0.0, 0.0))
		await get_tree().physics_frame
	assert_float(main.player.global_position.distance_to(before)).is_greater(0.5)


func test_the_boss_does_not_block_the_player_through_the_body_while_phased() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 3.0)
	boss.set_physics_process(false)
	await _frames(1)
	boss._set_phased(true)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	boss.global_position = Vector3(0.0, 0.0, -2.0)
	await _frames(2)
	for i in range(30):
		main.player.move_and_collide(Vector3(0.0, 0.0, -0.1))
		await get_tree().physics_frame
	assert_float(main.player.global_position.z).override_failure_message("player was blocked by a phased boss").is_less(-2.5)


func test_a_solid_boss_does_block_the_player_control_for_the_test_above() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 3.0)
	boss.set_physics_process(false)
	await _frames(1)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	boss.global_position = Vector3(0.0, 0.0, -2.0)
	await _frames(2)
	for i in range(30):
		main.player.move_and_collide(Vector3(0.0, 0.0, -0.1))
		await get_tree().physics_frame
	assert_float(main.player.global_position.z).override_failure_message("a solid boss should block").is_greater(-1.0)


# ---- Adds, death, win ----

func test_the_phase_summons_capped_adds_that_die_with_the_boss() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 10.0)
	await _frames(2)
	var summoned: Array = []
	boss.adds_summoned.connect(func(adds: Array) -> void: summoned.append_array(adds))
	boss.health.take_damage(boss.health.max_health * 0.5, "physical")
	await _until(func() -> bool: return boss.phase_index == 1, 2.0)
	assert_int(summoned.size()).is_equal(2)
	assert_int(boss.live_adds()).is_equal(2)
	# Asking for more never exceeds the cap.
	boss._summon("melee_chaser", 10)
	assert_int(boss.live_adds()).is_equal(int(BossConfig.boss(BOSS_ID)["max_adds_alive"]))
	for add: Enemy in summoned:
		assert_object(add.target).is_same(main.player)
	boss.health.hp_floor = 0.0
	boss.health.take_damage(boss.health.max_health * 2.0, "physical")
	await get_tree().process_frame
	assert_int(boss.live_adds()).is_equal(0)
	for add: Variant in summoned:
		assert_bool(not is_instance_valid(add) or (add as Node).is_queued_for_deletion()).is_true()


func test_death_beat_keeps_the_body_then_frees_it_and_protects_the_player() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 10.0)
	await _frames(2)
	boss._def["death"]["beat_seconds"] = 0.4
	var defeated: Array[int] = []
	boss.defeated.connect(func() -> void: defeated.append(1))
	boss.health.hp_floor = 0.0
	boss.health.take_damage(boss.health.max_health * 2.0, "physical")
	assert_array(defeated).has_size(1)
	assert_bool(boss.is_defeated()).is_true()
	assert_bool(main.player.health.damage_immune).override_failure_message("nothing may kill the player after the boss falls").is_true()
	await _frames(5)
	assert_bool(is_instance_valid(boss) and not boss.is_queued_for_deletion()).override_failure_message("the body stays through the beat").is_true()
	assert_bool(boss.is_phased()).is_true()
	await TestClock.wait_real(get_tree(), 0.6)
	assert_bool(not is_instance_valid(boss) or boss.is_queued_for_deletion()).is_true()


func _boss_room_main() -> Main:
	var state := RunSession.begin_new_run(42)
	state.room_index = 7
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func test_the_boss_room_spawns_the_data_boss_with_no_tier_stacking() -> void:
	var main := _boss_room_main()
	await get_tree().process_frame
	assert_str(main.run_controller.room_type()).is_equal("boss")
	main.enemy_spawner._process(3.0)
	var found: Boss = null
	for child in main.get_children():
		if child is Boss:
			found = child
	assert_object(found).is_not_null()
	assert_float(found.health.max_health).override_failure_message("no HP multiplier on top of the data").is_equal(float(BossConfig.boss(BOSS_ID)["max_health"]))
	for element: String in TierRules.element_ids():
		assert_float(found.health.get_resistance(element)).is_equal_approx(0.5, 0.0001)
	assert_str(found.tier).is_equal("boss")
	var room: Dictionary = RunConfig.get_config()["rooms"]["boss"][0]
	assert_str(String(room["id"])).is_equal("boss_guardian")
	assert_bool(found.spawn_index >= 0).is_true()


func test_boss_death_beat_comes_before_the_win_screen() -> void:
	var main := _boss_room_main()
	await get_tree().process_frame
	var wins: Array[int] = []
	main.run_controller.run_won.connect(func() -> void: wins.append(1))
	main.enemy_spawner._process(3.0)
	var boss: Boss = null
	for child in main.get_children():
		if child is Boss:
			boss = child
	assert_object(boss).is_not_null()
	boss._def["death"]["beat_seconds"] = 0.5
	boss.health.hp_floor = 0.0
	boss.health.take_damage(boss.health.max_health * 2.0, "physical")
	await _frames(10)
	assert_array(wins).override_failure_message("the win screen came during the death beat").is_empty()
	assert_bool((main.get_node("WinScreen") as CanvasLayer).visible).is_false()
	await TestClock.wait_real(get_tree(), 0.8)
	await _frames(3)
	assert_array(wins).has_size(1)
	assert_bool((main.get_node("WinScreen") as CanvasLayer).visible).is_true()
	assert_str(RunSession.current.outcome).is_equal("won")
	assert_bool(main.player.is_dead()).is_false()


# ---- Health floor, wedge reuse, scenario, relay ----

func test_health_floor_defaults_to_nothing_and_holds_when_set() -> void:
	var health := Health.new()
	health.max_health = 100.0
	add_child(health)
	auto_free(health)
	health.current_health = 100.0
	var died: Array[int] = []
	health.died.connect(func() -> void: died.append(1))
	assert_float(health.hp_floor).is_equal(0.0)
	health.hp_floor = 40.0
	health.take_damage(90.0)
	assert_float(health.current_health).is_equal(40.0)
	assert_array(died).is_empty()
	health.take_damage(5.0)  # already at the floor: nothing is taken, nothing is emitted
	assert_float(health.current_health).is_equal(40.0)
	health.hp_floor = 0.0
	health.take_damage(90.0)
	assert_float(health.current_health).is_equal(0.0)
	assert_array(died).has_size(1)


func test_damage_dealt_counts_only_the_hp_actually_taken_at_the_floor() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	var dealer := TestCaster.new()
	add_child(dealer)
	auto_free(dealer)
	await _frames(1)
	boss.health.take_damage(boss.health.max_health * 2.0, "physical", Vector3.ZERO, dealer)
	var taken: float = boss.health.max_health * 0.34
	assert_float(float(dealer.dealt[0][0])).is_equal_approx(taken, 0.05)


func test_floors_follow_a_change_of_max_hp() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(1)
	boss.health.set_max_health(9999.0)
	boss.health.heal(9999.0)
	assert_float(boss.health.hp_floor).is_equal_approx(9999.0 * 0.66, 0.01)


func test_the_cone_wedge_is_built_once_however_often_it_telegraphs() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(1)
	boss.set_physics_process(false)
	boss._begin_windup("smash")
	var wedge: Node = boss.get_node("TelegraphWedge_smash")
	var children: int = wedge.get_child_count()
	assert_int(children).is_greater(0)
	for i in range(4):
		boss._cancel_attack()
		boss._begin_windup("smash")
	assert_int(boss.get_node("TelegraphWedge_smash").get_child_count()).is_equal(children)
	assert_int(boss.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("TelegraphWedge")).size()).is_equal(1)


func test_boss_capture_scenario_builds_a_9999_hp_boss_with_a_scripted_attack_order() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var scenario := Scenario.setup(main, "boss")
	assert_object(scenario).is_not_null()
	var boss: Boss = scenario.enemies()[0] as Boss
	assert_object(boss).is_not_null()
	await _frames(2)
	assert_float(boss.health.max_health).is_equal(9999.0)
	assert_float(boss.health.current_health).is_equal(9999.0)
	assert_float(main.player.health.max_health).is_equal(9999.0)
	# Every attack comes up in the scripted order, each with its real telegraph.
	var order: Array[String] = []
	boss.attack_telegraphed.connect(func(id: String, _l: String, _w: float) -> void: order.append(id))
	boss._attack_cooldown_remaining = 0.0
	main.player.health.damage_immune = true
	await _until(func() -> bool: return order.size() >= 4, 25.0)
	assert_array(order.slice(0, 4)).is_equal(["smash", "slam", "volley", "charge"])


func test_scenario_schema_accepts_and_rejects_the_boss_flags() -> void:
	assert_array(ScenarioSchema.validate("t", {"boss_phase": 2, "boss_attacks": ["smash"]})).is_empty()
	for bad: Dictionary in [{"boss_phase": -1}, {"boss_phase": 1.5}, {"boss_attacks": []}, {"boss_attacks": [3]}, {"boss_attacks": "smash"}, {"boss_phases": 1}]:
		assert_array(ScenarioSchema.validate("t", bad)).override_failure_message("accepted %s" % str(bad)).is_not_empty()


func test_debug_set_phase_starts_the_boss_in_that_phase() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(1)
	boss.debug_set_phase(2)
	assert_int(boss.phase_index).is_equal(2)
	assert_float(boss.health.hp_floor).is_equal(0.0)
	assert_float(boss.health.current_health / boss.health.max_health).is_less_equal(0.33 + 0.0001)
	var ids: Array[String] = []
	for e: Dictionary in BossRules.eligible(boss._phase(), boss._attacks, 10.0):
		ids.append(String(e["id"]))
	assert_array(ids).contains(["charge"])


func test_the_run_controller_relays_the_boss_to_the_ui() -> void:
	var main := _boss_room_main()
	await get_tree().process_frame
	var seen: Array[Boss] = []
	main.run_controller.boss_spawned.connect(func(b: Boss) -> void: seen.append(b))
	assert_object(main.run_controller.current_boss()).is_null()
	main.enemy_spawner._process(3.0)
	assert_array(seen).has_size(1)
	assert_object(main.run_controller.current_boss()).is_same(seen[0])
	assert_str(seen[0].display_name()).is_equal("The Overly Enthusiastic Guardian")
	assert_array(seen[0].phase_thresholds()).is_equal([0.66, 0.33])
