class_name Heavy3b2Test
extends GdUnitTestSuite
## Slice 3b-2: per-class heavy data, Stun (rank, diminishing returns, inert enemies),
## element status chance, wind-up slow, targeted_aoe targeting. qa extends this.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const SHOOTER_PATH := "res://scenes/enemies/RangedShooter.tscn"


func after_test() -> void:
	Juice.reset()
	Input.action_release("attack_heavy")
	Input.action_release("attack_light")


func _stun_def() -> Dictionary:
	return (StatusDatabase.get_status("stun") as Dictionary).duplicate(true)


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func _spawn_enemy(main: Main, path: String, offset: Vector3, idle: bool = true) -> Enemy:
	var enemy: Enemy = (load(path) as PackedScene).instantiate()
	# Positioned before it enters the tree: its hurtbox must not exist at the origin for a
	# frame, where the player's auto light would hit it.
	enemy.position = main.player.global_position + offset
	main.add_child(enemy)
	enemy.target = null if idle else main.player
	return enemy


## Freeze aim so the player keeps facing -Z (the mouse would turn it in a real window).
func _face_forward(main: Main) -> void:
	main.player.camera = null
	main.player.rotation = Vector3.ZERO


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _no_target(_id: StringName) -> bool:
	return false


# --- data ----------------------------------------------------------------

func test_shipped_attacks_validate_and_have_rogue_arc_and_wizard_aoe() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/attacks.json"))
	assert_array(AttackDatabase.validate_table(table)).is_empty()
	assert_str(String(AttackDatabase.get_heavy("rogue")["shape"])).is_equal("arc")
	assert_str(String(AttackDatabase.get_heavy("wizard")["shape"])).is_equal("targeted_aoe")
	assert_dict(AttackDatabase.get_heavy("nobody")).is_empty()


func test_player_class_is_resolved_from_owned_pools() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	assert_str(main.player.character_class_id()).is_equal("rogue")
	assert_str(main.player.character_element_id()).is_equal("fire")
	assert_str(String(main.player.attacks.get_def(&"heavy")["shape"])).is_equal("arc")


func test_heavy_numbers_burst_area_and_dps_against_light() -> void:
	var light := AttackDatabase.get_attack("light")
	var heavy := AttackDatabase.get_heavy("rogue")
	assert_float(float(heavy["damage"])).is_equal_approx(8.5, 0.001)
	assert_float(float(heavy["damage"])).is_greater_equal(2.5 * float(light["damage"]))
	var light_dps: float = float(light["damage"]) / float(light["interval"])
	var heavy_dps: float = float(heavy["damage"]) / float(heavy["interval"])
	assert_float(heavy_dps).is_less(light_dps)
	assert_float(heavy_dps).is_greater(light_dps * 0.8)
	var light_area: float = 0.5 * pow(float(light["range"]), 2) * deg_to_rad(float(light["half_angle_degrees"])) * 2.0
	var heavy_area: float = 0.5 * pow(float(heavy["range"]), 2) * deg_to_rad(float(heavy["half_angle_degrees"])) * 2.0
	assert_float(heavy_area).is_greater(2.0 * light_area)


func test_attack_validation_rejects_roots_bad_shapes_and_missing_fields() -> void:
	var good := AttackDatabase.get_heavy("rogue").duplicate(true)
	assert_array(AttackDatabase.validate_entry(good)).is_empty()
	var bad_cases: Array[Dictionary] = [
		{"wind_up_move_slow": -1.0}, {"wind_up_move_slow": -2.0}, {"wind_up_move_slow": 0.5},
		{"shape": "sphere"}, {"shape": 3}, {"status_chance_multiplier": -1.0},
		{"element_status_duration": null}, {"on_hit_statuses": "stun"},
		{"on_hit_statuses": [{"status_id": "nope"}]}, {"on_hit_statuses": [{"status_id": "stun", "chance": 2.0}]},
		{"on_hit_statuses": [{"status_id": "stun", "duration": 0.0}]},
	]
	for patch in bad_cases:
		var entry := good.duplicate(true)
		entry.merge(patch, true)
		assert_array(AttackDatabase.validate_entry(entry)).override_failure_message("should reject %s" % str(patch)).is_not_empty()
	var no_duration := good.duplicate(true)
	no_duration.erase("element_status_duration")
	assert_array(AttackDatabase.validate_entry(no_duration)).is_not_empty()
	var aoe := AttackDatabase.get_heavy("wizard").duplicate(true)
	assert_array(AttackDatabase.validate_entry(aoe)).is_empty()
	for missing: String in ["radius", "max_range"]:
		var broken := aoe.duplicate(true)
		broken.erase(missing)
		assert_array(AttackDatabase.validate_entry(broken)).override_failure_message("missing %s" % missing).is_not_empty()
	var auto_aoe := aoe.duplicate(true)
	auto_aoe["auto"] = true
	assert_array(AttackDatabase.validate_entry(auto_aoe)).is_not_empty()
	assert_array(AttackDatabase.validate_table({"light": AttackDatabase.get_attack("light"), "heavy": {}})).is_not_empty()


func test_stun_status_validation() -> void:
	assert_array(StatusDatabase.validate_entry(_stun_def())).is_empty()
	var cases: Array[Dictionary] = [
		{"base_duration": 0.0}, {"base_duration": "x"},
		{"diminishing_returns": {"window": 4.0, "multiplier": 0.0, "immune_after": 3}},
		{"diminishing_returns": {"window": 4.0, "multiplier": 0.5, "immune_after": 0}},
		{"diminishing_returns": {"window": 0.0, "multiplier": 0.5, "immune_after": 3}},
		{"diminishing_returns": "none"},
		{"rank_multipliers": {"normal": 1.0, "elite": 0.5}},
		{"rank_multipliers": {"normal": 1.0, "elite": 0.5, "boss": 2.0}},
		{"rank_multipliers": {"normal": 1.0, "elite": 0.5, "boss": 0.0, "god": 0.0}},
		{"rank_multipliers": 1},
	]
	for patch in cases:
		var entry := _stun_def()
		entry.merge(patch, true)
		assert_array(StatusDatabase.validate_entry(entry)).override_failure_message("should reject %s" % str(patch)).is_not_empty()
	# A stun needs no damage_type / damage_per_tick; a Burn still does.
	var burn := (StatusDatabase.get_status("burn") as Dictionary).duplicate(true)
	burn.erase("damage_type")
	assert_array(StatusDatabase.validate_entry(burn)).is_not_empty()


func test_enemy_ranks_are_data_and_validated() -> void:
	assert_str(EnemyConfig.rank_for("melee_chaser")).is_equal("normal")
	assert_str(EnemyConfig.rank_for("ranged_shooter")).is_equal("normal")
	assert_str(EnemyConfig.rank_for("fire_resistant_golem")).is_equal("normal")
	assert_array(EnemyConfig.validate_enemies({"a": {"rank": "elite"}, "b": {"rank": "boss"}})).is_empty()
	assert_array(EnemyConfig.validate_enemies({"a": {"rank": "boos"}})).is_not_empty()
	assert_array(EnemyConfig.validate_enemies({"a": {}})).is_not_empty()
	assert_array(EnemyConfig.validate_enemies({"a": "normal"})).is_not_empty()
	assert_array(EnemyConfig.validate_enemies(null)).is_not_empty()


# --- stun rules ------------------------------------------------------------

func test_stun_diminishing_returns_normal() -> void:
	var rules := StunRules.new()
	var def := _stun_def()
	assert_float(rules.resolve(0.0, 0.6, "normal", def)).is_equal_approx(0.6, 0.0001)
	assert_float(rules.resolve(0.5, 0.6, "normal", def)).is_equal_approx(0.3, 0.0001)
	assert_float(rules.resolve(1.0, 0.6, "normal", def)).is_equal_approx(0.15, 0.0001)
	# Fourth inside the 1.5 s window: immune, and immunity does not extend itself.
	assert_float(rules.resolve(1.2, 0.6, "normal", def)).is_equal(0.0)
	assert_float(rules.resolve(1.49, 0.6, "normal", def)).is_equal(0.0)
	# The first stun (t=0) has aged out at t=1.5: two remain in the window -> x0.25.
	assert_float(rules.resolve(1.5, 0.6, "normal", def)).is_equal_approx(0.15, 0.0001)


func test_stun_window_clears_fully() -> void:
	var rules := StunRules.new()
	var def := _stun_def()
	for t: float in [0.0, 0.1, 0.2]:
		rules.resolve(t, 0.6, "normal", def)
	assert_float(rules.resolve(0.3, 0.6, "normal", def)).is_equal(0.0)
	assert_float(rules.resolve(5.0, 0.6, "normal", def)).is_equal_approx(0.6, 0.0001)


func test_stun_elite_halved_and_boss_immune() -> void:
	var def := _stun_def()
	var elite := StunRules.new()
	assert_float(elite.resolve(0.0, 0.6, "elite", def)).is_equal_approx(0.3, 0.0001)
	assert_float(elite.resolve(0.5, 0.6, "elite", def)).is_equal_approx(0.15, 0.0001)
	assert_float(elite.resolve(1.0, 0.6, "elite", def)).is_equal_approx(0.075, 0.0001)
	assert_float(elite.resolve(1.4, 0.6, "elite", def)).is_equal(0.0)
	var boss := StunRules.new()
	for t: float in [0.0, 10.0, 20.0]:
		assert_float(boss.resolve(t, 0.6, "boss", def)).is_equal(0.0)


func test_stun_window_is_shorter_than_the_rogue_heavy_cooldown() -> void:
	# 3b-3 data change (game-lead): the window must be shorter than the heavy interval,
	# or the heavy alone would decay its own stun.
	var window := float((_stun_def()["diminishing_returns"] as Dictionary)["window"])
	assert_float(window).is_equal_approx(1.5, 0.0001)
	assert_float(window).is_less(float(AttackDatabase.get_heavy("rogue")["interval"]))


func test_rogue_heavy_at_its_own_cooldown_stuns_the_full_length_every_swing() -> void:
	var def := _stun_def()
	var interval := float(AttackDatabase.get_heavy("rogue")["interval"])
	var rules := StunRules.new()
	for swing in range(12):
		assert_float(rules.resolve(float(swing) * interval, 0.6, "normal", def)).override_failure_message("swing %d" % swing).is_equal_approx(0.6, 0.0001)
	# Through the real manager and its clock too.
	var manager := _manager("normal")
	for swing in range(6):
		manager.apply_status("stun", def, 0.6)
		assert_float(manager.stun_time_remaining()).override_failure_message("swing %d" % swing).is_equal_approx(0.6, 0.0001)
		manager._process(interval)


func test_three_stuns_inside_the_window_decay_then_immune_then_recover() -> void:
	var def := _stun_def()
	var rules := StunRules.new()
	assert_float(rules.resolve(0.0, 0.6, "normal", def)).is_equal_approx(0.6, 0.0001)
	assert_float(rules.resolve(0.4, 0.6, "normal", def)).is_equal_approx(0.3, 0.0001)
	assert_float(rules.resolve(0.8, 0.6, "normal", def)).is_equal_approx(0.15, 0.0001)
	assert_float(rules.resolve(1.0, 0.6, "normal", def)).is_equal(0.0)
	assert_float(rules.resolve(1.4, 0.6, "normal", def)).is_equal(0.0)
	# Once the oldest has aged out (1.5 s after t=0) it can stun again, shortened.
	assert_float(rules.resolve(1.6, 0.6, "normal", def)).is_greater(0.0)
	# After a quiet gap longer than the window it is back to the full length.
	assert_float(rules.resolve(10.0, 0.6, "normal", def)).is_equal_approx(0.6, 0.0001)


# --- stun on the status manager ------------------------------------------------

func _manager(rank: String) -> StatusEffectManager:
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.rank = rank
	return manager


func test_stun_applies_then_expires() -> void:
	var manager := _manager("normal")
	var events: Array[String] = []
	manager.status_applied.connect(func(id: String) -> void: events.append("on:" + id))
	manager.status_expired.connect(func(id: String) -> void: events.append("off:" + id))
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(manager.is_stunned()).is_true()
	assert_float(manager.stun_time_remaining()).is_equal_approx(0.6, 0.0001)
	manager._process(0.5)
	assert_bool(manager.is_stunned()).is_true()
	manager._process(0.2)
	assert_bool(manager.is_stunned()).is_false()
	assert_array(events).is_equal(["on:stun", "off:stun"])


func test_stun_diminishes_through_the_manager_and_never_shortens_an_active_stun() -> void:
	var manager := _manager("normal")
	manager.apply_status("stun", _stun_def(), 0.6)
	manager._process(0.1)
	manager.apply_status("stun", _stun_def(), 0.6)
	# Second stun would be 0.3 but 0.5 is still left: keep the longer one.
	assert_float(manager.stun_time_remaining()).is_equal_approx(0.5, 0.0001)
	manager._process(0.5)
	assert_bool(manager.is_stunned()).is_false()


func test_boss_resists_stun_and_nothing_happens() -> void:
	var manager := _manager("boss")
	var resisted: Array[String] = []
	var applied: Array[String] = []
	manager.status_resisted.connect(func(id: String) -> void: resisted.append(id))
	manager.status_applied.connect(func(id: String) -> void: applied.append(id))
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(manager.is_stunned()).is_false()
	assert_array(resisted).is_equal(["stun"])
	assert_array(applied).is_empty()


func test_elite_stun_is_half_length() -> void:
	var manager := _manager("elite")
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_float(manager.stun_time_remaining()).is_equal_approx(0.3, 0.0001)


func test_immune_stun_does_not_end_an_active_one() -> void:
	var manager := _manager("normal")
	for i in range(3):
		manager.apply_status("stun", _stun_def(), 0.6)
	var left := manager.stun_time_remaining()
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(manager.is_stunned()).is_true()
	assert_float(manager.stun_time_remaining()).is_equal_approx(left, 0.0001)


# --- stunned enemies are inert ---------------------------------------------------

func test_stunned_enemy_does_not_move_or_attack() -> void:
	var main := _spawn_main()
	await _frames(2)
	_face_forward(main)
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -6.0), false)
	var player_hp := main.player.health.current_health
	await _frames(2)
	enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(enemy.is_stunned()).is_true()
	var start := enemy.global_position
	await _frames(20)
	assert_float(Vector2(enemy.global_position.x - start.x, enemy.global_position.z - start.z).length()).is_less(0.05)
	assert_float(main.player.health.current_health).is_equal(player_hp)


func test_stun_cancels_a_wind_up_in_progress() -> void:
	var main := _spawn_main()
	await _frames(2)
	# Inside the chaser's attack range, so it starts its telegraph at once.
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.0), false)
	await _frames(3)
	assert_float(enemy._telegraph_remaining).is_greater(0.0)
	var player_hp := main.player.health.current_health
	enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_float(enemy._telegraph_remaining).is_equal(0.0)
	await _frames(40)
	assert_float(main.player.health.current_health).is_equal(player_hp)


func test_stunned_ranged_enemy_does_not_fire_and_recovers() -> void:
	var main := _spawn_main()
	await _frames(2)
	var enemy := _spawn_enemy(main, SHOOTER_PATH, Vector3(0.0, 0.0, -5.0), false)
	var signals: Array[String] = []
	enemy.stunned.connect(func(_d: float) -> void: signals.append("stunned"))
	enemy.stun_ended.connect(func() -> void: signals.append("ended"))
	await _frames(2)
	enemy.status_manager.apply_status("stun", _stun_def(), 0.3)
	assert_array(signals).is_equal(["stunned"])
	await _frames(30)
	assert_bool(enemy.is_stunned()).is_false()
	assert_array(signals).is_equal(["stunned", "ended"])


func test_boss_enemy_wind_up_is_not_cancelled_by_a_stun() -> void:
	var main := _spawn_main()
	await _frames(2)
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.0), false)
	enemy.status_manager.rank = "boss"
	await _frames(3)
	var winding := enemy._telegraph_remaining
	assert_float(winding).is_greater(0.0)
	enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(enemy.is_stunned()).is_false()
	assert_float(enemy._telegraph_remaining).is_greater(0.0)


# --- element status chance ---------------------------------------------------------

func test_element_chance_is_base_times_multiplier_clamped() -> void:
	assert_float(AttackStatuses.element_chance("fire", 2.5)).is_equal_approx(0.5, 0.0001)
	assert_float(AttackStatuses.element_chance("fire", 0.0)).is_equal(0.0)
	assert_float(AttackStatuses.element_chance("fire", 1.0)).is_equal_approx(0.2, 0.0001)
	assert_float(AttackStatuses.element_chance("fire", 100.0)).is_equal(1.0)
	assert_float(AttackStatuses.element_chance("neutral", 2.5)).is_equal(0.0)
	assert_float(AttackStatuses.element_chance("", 2.5)).is_equal(0.0)
	assert_float(float(AttackDatabase.get_attack("light")["status_chance_multiplier"])).is_equal(0.0)
	assert_float(AttackStatuses.element_chance("fire", float(AttackDatabase.get_heavy("rogue")["status_chance_multiplier"]))).is_equal_approx(0.5, 0.0001)


func test_seeded_rolls_are_deterministic_and_hit_the_chance() -> void:
	var first := RandomNumberGenerator.new()
	first.seed = 424242
	var second := RandomNumberGenerator.new()
	second.seed = 424242
	var hits := 0
	for i in range(2000):
		var a := AttackStatuses.roll(first, 0.5)
		assert_bool(a).is_equal(AttackStatuses.roll(second, 0.5))
		if a:
			hits += 1
	assert_int(hits).is_between(900, 1100)
	assert_bool(AttackStatuses.roll(first, 0.0)).is_false()
	assert_bool(AttackStatuses.roll(first, 1.0)).is_true()


func _fake_target(rank: String = "normal") -> Hurtbox:
	var hurtbox: Hurtbox = auto_free(Hurtbox.new())
	var health: Health = auto_free(Health.new())
	health.max_health = 100.0
	health.current_health = 100.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.rank = rank
	manager.health = health
	hurtbox.health = health
	hurtbox.status_manager = manager
	return hurtbox


func test_apply_on_hit_light_never_burns_heavy_burns_about_half() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var light := AttackDatabase.get_attack("light")
	var heavy := AttackDatabase.get_heavy("rogue")
	var burned := 0
	for i in range(400):
		var target := _fake_target()
		var no_hits: Array[Hurtbox] = [target]
		assert_array(AttackStatuses.apply_on_hit(light, "fire", no_hits, rng)).is_empty()
		AttackStatuses.apply_on_hit(heavy, "fire", no_hits, rng)
		assert_bool(target.status_manager.is_stunned()).is_true()
		if target.status_manager.has_status("burn"):
			burned += 1
	assert_int(burned).is_between(150, 250)


func test_apply_on_hit_skips_dead_and_non_fire_characters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var heavy := AttackDatabase.get_heavy("rogue").duplicate(true)
	heavy["status_chance_multiplier"] = 100.0
	var dead := _fake_target()
	dead.health.take_damage(1000.0)
	var alive := _fake_target()
	var hits: Array[Hurtbox] = [dead, alive]
	AttackStatuses.apply_on_hit(heavy, "fire", hits, rng)
	assert_bool(dead.status_manager.has_status("burn")).is_false()
	assert_bool(alive.status_manager.has_status("burn")).is_true()
	var neutral := _fake_target()
	var only_neutral: Array[Hurtbox] = [neutral]
	AttackStatuses.apply_on_hit(heavy, "neutral", only_neutral, rng)
	assert_bool(neutral.status_manager.has_status("burn")).is_false()
	assert_bool(neutral.status_manager.is_stunned()).is_true()


# --- wind-up slow --------------------------------------------------------------------

func _controller(mods: StatModifiers) -> AttackController:
	return AttackController.new({
		&"light": AttackDatabase.get_attack("light").duplicate(),
		&"heavy": AttackDatabase.get_heavy("rogue").duplicate(),
	}, mods)


func test_wind_up_slow_is_applied_then_removed_on_release() -> void:
	var mods := StatModifiers.new()
	var controller := _controller(mods)
	assert_float(mods.apply("move_speed", 6.0)).is_equal_approx(6.0, 0.0001)
	controller.tick(0.016, true, {&"heavy": true}, _no_target)
	assert_bool(controller.is_winding_up(&"heavy")).is_true()
	assert_float(mods.apply("move_speed", 6.0)).is_equal_approx(6.0 * 0.65, 0.0001)
	assert_float(mods.apply("move_speed", 6.0)).is_greater(0.0)
	controller.tick(1.0, true, {}, _no_target)
	assert_float(mods.apply("move_speed", 6.0)).is_equal_approx(6.0, 0.0001)


func test_wind_up_slow_is_removed_on_cancel() -> void:
	var mods := StatModifiers.new()
	var controller := _controller(mods)
	controller.tick(0.016, true, {&"heavy": true}, _no_target)
	assert_float(mods.apply("move_speed", 6.0)).is_less(6.0)
	controller.tick(0.016, false, {}, _no_target)
	assert_float(mods.apply("move_speed", 6.0)).is_equal_approx(6.0, 0.0001)


func test_light_has_no_slow() -> void:
	var mods := StatModifiers.new()
	var controller := _controller(mods)
	controller.tick(0.016, true, {&"light": true}, _no_target)
	assert_float(mods.apply("move_speed", 6.0)).is_equal_approx(6.0, 0.0001)


func test_player_slowed_during_wind_up_and_restored_on_death() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed, 0.0001)
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_true()
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed * 0.65, 0.0001)
	player.health.take_damage(player.health.get_max_health() * 2.0)
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_false()
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed, 0.0001)


func test_player_slow_clears_after_the_swing_and_after_a_scene_reload() -> void:
	var main := _spawn_main()
	await _frames(2)
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	await _frames(45)
	assert_float(main.player.get_move_speed()).is_equal_approx(main.player.move_speed, 0.0001)
	var fresh := _spawn_main()
	await _frames(2)
	assert_float(fresh.player.get_move_speed()).is_equal_approx(fresh.player.move_speed, 0.0001)


# --- heavy in play: Rogue arc stuns -----------------------------------------------------

func test_rogue_heavy_hits_for_damage_and_stuns() -> void:
	var main := _spawn_main()
	await _frames(2)
	_face_forward(main)
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.2))
	await _frames(2)
	var before := enemy.health.current_health
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	await _frames(40)
	assert_float(before - enemy.health.current_health).is_greater_equal(8.5 - 0.001)
	assert_bool(enemy.is_stunned()).is_true()


# --- targeted_aoe ---------------------------------------------------------------------------

func test_aoe_target_is_capped_to_max_range() -> void:
	var origin := Vector3(1.0, 0.0, 2.0)
	var arena := Rect2(-20.0, -20.0, 40.0, 40.0)
	var inside := AoeTargeting.clamp_target(origin, origin + Vector3(0.0, 0.0, -3.0), Vector3.FORWARD, 7.0, arena)
	assert_vector(inside).is_equal_approx(origin + Vector3(0.0, 0.0, -3.0), Vector3.ONE * 0.0001)
	var far := AoeTargeting.clamp_target(origin, origin + Vector3(30.0, 0.0, 0.0), Vector3.FORWARD, 7.0, arena)
	assert_float(far.distance_to(origin)).is_equal_approx(7.0, 0.0001)
	assert_float(far.z).is_equal_approx(origin.z, 0.0001)


func test_aoe_target_stays_in_arena_and_handles_missing_aim() -> void:
	var arena := Rect2(-20.0, -20.0, 40.0, 40.0)
	var edge := Vector3(19.0, 0.0, 0.0)
	var off := AoeTargeting.clamp_target(edge, Vector3(500.0, 0.0, 500.0), Vector3.FORWARD, 7.0, arena)
	assert_float(off.x).is_less_equal(20.0 - AoeTargeting.ARENA_EDGE_MARGIN + 0.0001)
	assert_float(off.z).is_less_equal(20.0)
	assert_float(off.distance_to(edge)).is_less_equal(7.0 + 0.0001)
	var none := AoeTargeting.clamp_target(Vector3.ZERO, null, Vector3(0.0, 0.0, -1.0), 7.0, arena)
	assert_vector(none).is_equal_approx(Vector3(0.0, 0.0, -7.0), Vector3.ONE * 0.0001)
	var nan := AoeTargeting.clamp_target(Vector3.ZERO, Vector3(NAN, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), 7.0, arena)
	assert_bool(nan.is_finite()).is_true()
	var no_forward := AoeTargeting.clamp_target(Vector3.ZERO, null, Vector3.ZERO, 7.0, Rect2())
	assert_bool(no_forward.is_finite()).is_true()
	var high := AoeTargeting.clamp_target(Vector3(0.0, 0.5, 0.0), Vector3(2.0, 9.0, 2.0), Vector3.FORWARD, 7.0, arena)
	assert_float(high.y).is_equal(0.5)


func test_wizard_heavy_hits_the_locked_target_telegraph_matches_hitbox() -> void:
	var main := _spawn_main()
	await _frames(2)
	_face_forward(main)
	var player := main.player
	player.use_heavy_class("wizard")
	var def := player.attacks.get_def(&"heavy")
	assert_str(String(def["shape"])).is_equal("targeted_aoe")
	var origin := player.global_position
	# Aim far beyond max_range: the disc must land exactly max_range away.
	player.aim_point_override = origin + Vector3(0.0, 0.0, -30.0)
	var max_range := float(def["max_range"])
	var in_disc := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -max_range + 0.5))
	var out_disc := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -max_range + 5.0))
	await _frames(2)
	var hp_in := in_disc.health.current_health
	var hp_out := out_disc.health.current_health
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	var target := player.get_aoe_target(&"heavy")
	assert_float(target.distance_to(origin)).is_equal_approx(max_range, 0.001)
	var pool := EffectPool.for_world(main)
	assert_int(pool.active_count()).is_greater(0)
	var telegraph: Array[PooledEffect] = player.get_aoe_telegraph(&"heavy")
	assert_float((telegraph[0] as PooledEffect).base_size).is_equal_approx(VfxSizing.aoe_reach(float(def["radius"])), 0.0001)
	assert_vector((telegraph[0] as PooledEffect).origin).is_equal_approx(Vector3(target.x, EffectPool.GROUND_OFFSET, target.z), Vector3.ONE * 0.001)
	await _frames(50)
	assert_float(hp_in - in_disc.health.current_health).is_greater_equal(float(def["damage"]) - 0.001)
	assert_float(hp_out - out_disc.health.current_health).is_equal(0.0)
	assert_bool(player.has_aoe_telegraph(&"heavy")).is_false()


func test_wizard_heavy_off_arena_target_and_cancel_clean_up() -> void:
	var main := _spawn_main()
	await _frames(2)
	_face_forward(main)
	var player := main.player
	player.use_heavy_class("wizard")
	player.aim_point_override = Vector3(900.0, 0.0, 900.0)
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	var target := player.get_aoe_target(&"heavy")
	assert_bool(target.is_finite()).is_true()
	assert_float(absf(target.x)).is_less_equal(20.0)
	assert_float(absf(target.z)).is_less_equal(20.0)
	assert_bool(player.has_aoe_telegraph(&"heavy")).is_true()
	player.health.take_damage(player.health.get_max_health() * 2.0)
	assert_bool(player.has_aoe_telegraph(&"heavy")).is_false()
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed, 0.0001)
