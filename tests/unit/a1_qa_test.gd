class_name A1QaTest
extends GdUnitTestSuite
## A1 Part 3 (qa): armor, independently of the builders' own suites. Formula edges, every damage template through
## the real Health choke point, parity mutation (a changed armor or resistance must be caught), DoT, phases with armor
## on, and data fail-loud cases. Nothing here edits game data: fixtures are copies.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const K := 50.0
const KNOWN_ENEMIES: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian"]


class Attacker extends Node:
	var stat_modifiers := StatModifiers.new()


func before_test() -> void:
	BodyFlag.set_collide(false)
	Juice.hit_stop_enabled = false
	Juice.reset()


func after_test() -> void:
	BodyFlag.reset()
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0
	Enemy.set_player_body_suppressed(false)


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _enemy_at(main: Main, offset: Vector3, armor: float) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	enemy.health.base_armor = armor
	enemy.health.set_max_health(10000.0)
	enemy.health.heal(10000.0)
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _context(main: Main) -> EffectContext:
	var context := EffectContext.new(main.player, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 11
	context.arena = main.player.get_arena_rect()
	return context


func _health(armor: float = 0.0, max_hp: float = 1000.0) -> Health:
	var h: Health = auto_free(Health.new())
	h.max_health = max_hp
	h.current_health = max_hp
	h.base_armor = armor
	return h


# ---- Formula edges ----

func test_formula_exact_points_and_monotonic() -> void:
	assert_float(CombatMath.armor_reduction(0.0, K, 1.0)).is_equal(0.0)
	assert_float(CombatMath.armor_reduction(K, K, 1.0)).is_equal(0.5)
	assert_float(CombatMath.armor_reduction(20.0, 20.0, 1.0)).is_equal(0.5)  # K is a parameter, not a constant
	assert_float(CombatMath.armor_reduction(17.0, K, 1.0)).is_equal_approx(17.0 / 67.0, 0.00001)
	var last: float = -1.0
	for armor: float in [0.0, 1.0, 5.0, 17.0, 27.0, 50.0, 200.0, 5000.0, 1.0e6, 1.0e12]:
		var r: float = CombatMath.armor_reduction(armor, K, 1.0)
		assert_float(r).is_less(1.0)
		assert_float(r).is_greater_equal(last)
		last = r


func test_cap_zero_and_cap_below_half_and_cap_equal_to_formula() -> void:
	assert_float(CombatMath.armor_reduction(K, K, 0.3)).is_equal(0.3)
	assert_float(CombatMath.armor_reduction(K, K, 0.0)).is_equal(0.0)
	assert_float(CombatMath.armor_reduction(K, K, 0.5)).is_equal(0.5)
	assert_float(CombatMath.armor_reduction(10.0, K, 0.5)).is_equal_approx(10.0 / 60.0, 0.00001)  # below the cap: untouched


func test_negative_and_degenerate_inputs_never_heal_or_amplify() -> void:
	assert_float(CombatMath.armor_reduction(-100.0, K)).is_equal(0.0)
	assert_float(CombatMath.armor_reduction(10.0, 0.0)).is_equal(0.0)  # K <= 0 is refused by the validator; the math stays safe
	assert_float(CombatMath.armor_reduction(10.0, -5.0)).is_equal(0.0)
	assert_float(CombatMath.apply_armor(-10.0, 50.0, 0.0, K)).is_equal(0.0)
	assert_float(CombatMath.apply_armor(0.0, 50.0, 0.0, K)).is_equal(0.0)
	assert_float(CombatMath.apply_armor(10.0, 50.0, -50.0, K)).is_equal_approx(5.0, 0.0001)  # negative penetration is ignored, not extra armor
	assert_float(CombatMath.apply_armor(10.0, -50.0, 0.0, K)).is_equal(10.0)  # negative armor never amplifies
	var h := _health(50.0)
	h.take_damage(-10.0, "physical")
	h.take_damage(0.0, "physical")
	assert_float(h.current_health).is_equal(1000.0)  # no heal from a negative hit
	assert_bool(is_nan(h.current_health)).is_false()


func test_very_large_values_stay_finite() -> void:
	var h := _health(50.0, 1.0e30)
	h.take_damage(1.0e20, "physical")
	assert_bool(is_nan(h.current_health) or is_inf(h.current_health)).is_false()
	assert_float(CombatMath.apply_armor(1.0e30, 1.0e9, 0.0, K)).is_less(1.0e30)
	assert_float(CombatMath.apply_armor(1.0e30, 1.0e9, 0.0, K)).is_greater(0.0)
	var big_armor := _health(1.0e12)
	big_armor.take_damage(100.0, "physical")
	assert_float(1000.0 - big_armor.current_health).is_equal_approx(50.0, 0.0001)  # the cap holds at absurd armor


func test_tiny_hit_through_armor_is_not_rounded_to_zero() -> void:
	var h := _health(50.0)
	h.take_damage(0.01, "physical")
	assert_float(1000.0 - h.current_health).is_equal_approx(0.005, 0.000001)
	assert_float(h.last_reduction).is_equal_approx(0.5, 0.0001)
	assert_float(h.last_raw_amount).is_equal(0.01)


func test_last_fields_describe_the_event() -> void:
	var h := _health(50.0)
	h.resistances = {"fire": 0.5}
	h.take_damage(10.0, "physical")
	assert_that(h.last_channel).is_equal(Health.CHANNEL_ARMOR)
	assert_float(h.last_reduction).is_equal_approx(0.5, 0.0001)
	assert_float(h.last_raw_amount).is_equal(10.0)
	h.take_damage(10.0, "fire")
	assert_that(h.last_channel).is_equal(Health.CHANNEL_RESISTANCE)
	assert_float(h.last_reduction).is_equal_approx(0.5, 0.0001)
	var plain := _health(0.0)
	plain.take_damage(10.0, "physical")
	assert_that(plain.last_channel).is_equal(Health.CHANNEL_NONE)
	assert_float(plain.last_reduction).is_equal(0.0)


func test_every_shipped_damage_type_is_a_known_channel() -> void:
	# A typo such as "Physical" would fall through both channels (no armor, no resistance) and fail silently, and the card
	# schema only checks the type is a non-empty string. So sweep the data: every type must be non-elemental or an element id.
	var known: Array = ArmorConfig.non_elemental_types() + TierRules.element_ids()
	var found: Dictionary = {}
	var dirs: Array[String] = ["res://data"]
	for sub: String in DirAccess.get_directories_at("res://data"):
		dirs.append("res://data/" + sub)
	for dir_path: String in dirs:
		for file: String in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".json") or file == "scenarios.json":
				continue
			_collect_types(JSON.parse_string(FileAccess.get_file_as_string(dir_path + "/" + file)), found, dir_path + "/" + file)
	assert_bool(found.size() > 0).is_true()
	for type_id: String in found:
		assert_bool(known.has(type_id)).override_failure_message("damage type '%s' (%s) is neither non-elemental nor an element: armor and resistance would both skip it" % [type_id, found[type_id]]).is_true()


func _collect_types(node: Variant, found: Dictionary, where: String) -> void:
	if node is Dictionary:
		for key: Variant in node:
			if (str(key) == "damage_type" or str(key) == "attack_damage_type") and node[key] is String:
				found[String(node[key])] = where
			else:
				_collect_types(node[key], found, where)
	elif node is Array:
		for item: Variant in node:
			_collect_types(item, found, where)


func test_an_unlisted_type_is_elemental_by_default_and_armor_skips_it() -> void:
	# Documents today's behaviour (not an endorsement): see the review's non-blocking finding on unvalidated types.
	var h := _health(50.0)
	h.take_damage(10.0, "water")
	assert_float(1000.0 - h.current_health).is_equal(10.0)


func test_resistance_cap_still_applies_on_the_elemental_channel() -> void:
	var h := _health(0.0)
	h.resistances = {"fire": 0.9}
	h.take_damage(10.0, "fire")
	assert_float(1000.0 - h.current_health).is_equal_approx(5.0, 0.0001)


# ---- Every damage template goes through the choke point ----

func test_every_player_damage_template_is_mitigated_by_armor_for_physical_only() -> void:
	var main := _spawn_main()
	# One armored (50) enemy per template, parked in front of the player (-z is forward).
	var cone_target := _enemy_at(main, Vector3(0, 0, -2.0), 50.0)
	var aoe_target := _enemy_at(main, Vector3(6.0, 0, 6.0), 50.0)
	var proj_target := _enemy_at(main, Vector3(-8.0, 0, 0), 50.0)
	await _frames(2)
	var cases: Array[Dictionary] = [
		{"id": "cone", "params": {"damage": 10.0, "range": 4.0, "half_angle_degrees": 80.0}, "target": cone_target},
		{"id": "aoe", "params": {"damage": 10.0, "radius": 1.5, "center": aoe_target.global_position}, "target": aoe_target},
	]
	for c: Dictionary in cases:
		var target: Enemy = c["target"]
		for pair: Array in [["physical", 5.0], ["neutral", 5.0], ["fire", 10.0]]:
			var params: Dictionary = (c["params"] as Dictionary).duplicate()
			params["damage_type"] = pair[0]
			params["vfx"] = false
			var before: float = target.health.current_health
			EffectTemplates.execute(String(c["id"]), params, _context(main))
			assert_float(before - target.health.current_health).override_failure_message("%s %s" % [c["id"], pair[0]]).is_equal_approx(float(pair[1]), 0.001)
	# Projectile: fired along -x by turning the caster; physical halves, fire does not.
	main.player.rotation.y = PI * 0.5
	for pair: Array in [["physical", 5.0], ["fire", 10.0]]:
		var before: float = proj_target.health.current_health
		EffectTemplates.execute("projectile", {"damage": 10.0, "damage_type": pair[0], "speed": 30.0, "max_range": 20.0, "hit_radius": 0.6}, _context(main))
		await _frames(30)
		assert_float(before - proj_target.health.current_health).override_failure_message("projectile %s" % pair[0]).is_equal_approx(float(pair[1]), 0.001)


func test_dash_path_and_zone_damage_are_mitigated_by_armor() -> void:
	var main := _spawn_main()
	var on_path := _enemy_at(main, Vector3(0, 0, -1.5), 50.0)
	await _frames(2)
	var before: float = on_path.health.current_health
	EffectTemplates.execute("dash", {"distance": 4.0, "speed": 15.0, "damage": 10.0, "damage_type": "physical", "hit_radius": 0.6}, _context(main))
	await _frames(40)
	assert_float(before - on_path.health.current_health).override_failure_message("dash path").is_equal_approx(5.0, 0.001)
	var zone_target := _enemy_at(main, Vector3(0, 0, -6.0), 50.0)
	await _frames(2)
	var params: Dictionary = {"shape": "circle", "radius": 2.0, "duration": 2.0, "tick_interval": 0.5, "damage": 10.0, "damage_type": "physical", "max_range": 8.0}
	var context := _context(main)
	context.aim_point = zone_target.global_position
	EffectTemplates.execute("zone", params, context)
	var manager := ZoneManager.for_world(main)
	manager.set_physics_process(false)
	var zone_before: float = zone_target.health.current_health
	manager.step(0.5)  # the placement tick already landed; one more tick
	var lost: float = zone_before - zone_target.health.current_health
	assert_float(lost).override_failure_message("zone tick").is_equal_approx(5.0, 0.001)
	assert_that(zone_target.health.last_channel).is_equal(Health.CHANNEL_ARMOR)


func test_a_boss_attack_on_an_armored_player_is_mitigated_and_a_fire_one_is_not() -> void:
	var player: Player = auto_free((load("res://scenes/player/Player.tscn") as PackedScene).instantiate())
	add_child(player)
	player.stat_modifiers.add_modifier("armor", "qa", StatModifiers.ADDITIVE, 50.0)
	var attacker: Attacker = auto_free(Attacker.new())
	var before: float = player.health.current_health
	player.hurtbox.receive_damage(10.0, "physical", Vector3.ZERO, attacker)  # the Boss.gd path: Hurtbox -> Health
	assert_float(before - player.health.current_health).is_equal_approx(5.0, 0.001)
	before = player.health.current_health
	player.hurtbox.receive_damage(10.0, "fire", Vector3.ZERO, attacker)
	assert_float(before - player.health.current_health).is_equal_approx(10.0, 0.001)


func test_no_source_file_writes_damage_around_the_choke_point() -> void:
	# Static audit: the only places allowed to subtract from current_health are Health itself. (Boss/Enemy/RunController
	# assign it for setup or a run restore, which is a set, never a damage subtraction.)
	var offenders: Array[String] = []
	for path: String in _gd_files("res://src"):
		if path.ends_with("/Health.gd"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			var s: String = line.strip_edges()
			if s.begins_with("#") or s.begins_with("##"):
				continue
			if s.contains("current_health -=") or s.contains("current_health = current_health -"):
				offenders.append("%s: %s" % [path, s])
	assert_array(offenders).override_failure_message("damage written around Health.take_damage: %s" % str(offenders)).is_empty()


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_gd_files(dir_path + "/" + sub))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path + "/" + file)
	return out


# ---- Penetration and DoT ----

func test_penetration_is_flat_per_source_and_does_not_leak_to_other_sources() -> void:
	var h := _health(50.0)
	var piercer: Attacker = auto_free(Attacker.new())
	piercer.stat_modifiers.add_modifier("armor_penetration", "p", StatModifiers.ADDITIVE, 25.0)
	h.take_damage(10.0, "physical", Vector3.ZERO, piercer)  # armor 25 left: 25/75 = 1/3
	assert_float(1000.0 - h.current_health).is_equal_approx(10.0 * (1.0 - 25.0 / 75.0), 0.0001)
	var before: float = h.current_health
	h.take_damage(10.0, "physical")  # no source: full armor again
	assert_float(before - h.current_health).is_equal_approx(5.0, 0.0001)
	var neg: Attacker = auto_free(Attacker.new())
	neg.stat_modifiers.add_modifier("armor_penetration", "n", StatModifiers.ADDITIVE, -30.0)
	before = h.current_health
	h.take_damage(10.0, "physical", Vector3.ZERO, neg)  # negative penetration floors at 0: never extra armor
	assert_float(before - h.current_health).is_equal_approx(5.0, 0.0001)


func test_bleed_by_armor_burn_by_resistance_on_a_real_elite() -> void:
	var main := _spawn_main()
	var elite := _enemy_at(main, Vector3(0, 0, -8.0), 0.0)
	elite.apply_tier("elite", RunConfig.tier("elite"))
	elite.health.set_max_health(10000.0)
	elite.health.heal(10000.0)
	var armor_cut: float = 1.0 - elite.health.get_armor_reduction()
	var before: float = elite.health.current_health
	elite.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 1.0)
	elite.status_manager._process(10.0)
	assert_float(before - elite.health.current_health).override_failure_message("bleed ticked nothing").is_greater(0.0)
	assert_that(elite.health.last_channel).is_equal(Health.CHANNEL_ARMOR)
	assert_float(elite.health.last_reduction).is_equal_approx(1.0 - armor_cut, 0.0001)
	elite.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 1.0)
	elite.status_manager._process(10.0)
	assert_that(elite.health.last_channel).is_equal(Health.CHANNEL_RESISTANCE)
	assert_float(elite.health.last_reduction).is_equal_approx(0.25, 0.0001)


# ---- Phases with armor on ----

func test_boss_phase_floor_still_holds_with_the_real_armor_on() -> void:
	var main := _spawn_main()
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.global_position = main.player.global_position + Vector3(0, 0, -8.0)
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	assert_float(boss.health.get_armor()).is_equal(float(BossConfig.boss("boss_guardian")["armor"]))  # armor is NOT zeroed here
	var max_hp: float = boss.health.max_health
	boss.health.take_damage(99999.0, "physical")
	assert_float(boss.health.current_health).override_failure_message("armored 9999 must stop at the 66% floor").is_equal_approx(max_hp * 0.66, 0.01)
	boss.health.damage_immune = false
	boss.health.take_damage(99999.0, "fire")
	assert_float(boss.health.current_health).is_greater_equal(max_hp * 0.66 - 0.01)


# ---- Parity: a mutated fixture must be caught, at the pure and the load level ----

func _shipped_run() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))


func _run_problems(config: Dictionary) -> Array[String]:
	var cards: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		cards.append(String((card as Dictionary)["id"]))
	return RunConfig.validate(config, KNOWN_ENEMIES, cards)


func test_parity_mutation_every_tier_both_directions_and_message_names_the_tier() -> void:
	var shipped := _shipped_run()
	assert_array(_run_problems(shipped)).is_empty()
	for tier_id: String in ["elite", "boss"]:
		for delta: float in [3.0, -3.0, 15.0]:  # 3 armor points ~ 2.2 / 1.7 reduction points at these tiers: see below
			var mutated := shipped.duplicate(true)
			mutated["tiers"][tier_id]["armor"] = float(shipped["tiers"][tier_id]["armor"]) + delta
			var reduction: float = CombatMath.armor_reduction(float(mutated["tiers"][tier_id]["armor"]), K, 1.0)
			var drift: float = absf(reduction - float(shipped["tiers"][tier_id]["resistance_floor"]))
			var problems := _run_problems(mutated)
			if drift > 0.02:
				assert_array(problems).override_failure_message("%s armor %+f drifts %.3f but passed" % [tier_id, delta, drift]).is_not_empty()
				assert_bool(" ".join(problems).contains(tier_id)).is_true()
			else:
				assert_array(problems).override_failure_message("%s armor %+f drifts only %.3f but was refused" % [tier_id, delta, drift]).is_empty()
	var boss_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH))
	for armor: float in [49.0, 40.0, 60.0, 0.0]:
		var mutated_boss := boss_cfg.duplicate(true)
		mutated_boss["bosses"]["boss_guardian"]["armor"] = armor
		var drift: float = absf(CombatMath.armor_reduction(armor, K, 1.0) - 0.5)
		var boss_problems := BossConfig.validate(mutated_boss, KNOWN_ENEMIES)
		assert_bool(boss_problems.is_empty()).override_failure_message("final boss armor %f drift %.3f" % [armor, drift]).is_equal(drift <= 0.02)


func test_parity_also_catches_changing_the_resistance_alone() -> void:
	var shipped := _shipped_run()
	var mutated := shipped.duplicate(true)
	mutated["tiers"]["boss"]["resistance_floor"] = 0.5
	assert_array(_run_problems(mutated)).is_not_empty()
	var boss_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH))
	boss_cfg["bosses"]["boss_guardian"]["resistance"] = 0.4
	assert_array(BossConfig.validate(boss_cfg, KNOWN_ENEMIES)).is_not_empty()


func test_load_path_runs_the_parity_check() -> void:
	# "Enforced at load": the shipped loaders call the same validators the mutation tests exercise.
	var run_src: String = FileAccess.get_file_as_string("res://src/run/RunConfig.gd")
	assert_bool(run_src.contains("parity_errors")).is_true()
	var boss_src: String = FileAccess.get_file_as_string("res://src/enemies/BossConfig.gd")
	assert_bool(boss_src.contains("parity_errors")).is_true()


func test_shipped_final_boss_is_exactly_fifty_percent_both_channels() -> void:
	var boss: Dictionary = BossConfig.boss("boss_guardian")
	assert_float(CombatMath.armor_reduction(float(boss["armor"]), ArmorConfig.k(), ArmorConfig.reduction_cap())).is_equal(0.5)
	assert_float(float(boss["resistance"])).is_equal(0.5)


# ---- Data fail loud ----

func test_armor_config_each_bad_field_names_its_key() -> void:
	var good: Dictionary = {"k": 50.0, "armor_reduction_cap": 0.5, "non_elemental_types": ["physical"]}
	var cases: Array[Array] = [["k", 0], ["k", -50], ["k", "50"], ["k", null], ["armor_reduction_cap", 1.01], ["armor_reduction_cap", -0.01],
			["armor_reduction_cap", "x"], ["armor_reduction_cap", null], ["non_elemental_types", [""]], ["non_elemental_types", [3]], ["non_elemental_types", null]]
	for c: Array in cases:
		var cfg := good.duplicate(true)
		if c[1] == null:
			cfg.erase(c[0])
		else:
			cfg[c[0]] = c[1]
		var errors := ArmorConfig.validate(cfg)
		assert_array(errors).override_failure_message("%s = %s should be refused" % [c[0], str(c[1])]).is_not_empty()
		assert_bool(" ".join(errors).contains(String(c[0]))).override_failure_message("error should name %s: %s" % [c[0], str(errors)]).is_true()
	assert_array(ArmorConfig.validate({"k": 50, "armor_reduction_cap": 1, "non_elemental_types": ["physical"]})).is_empty()  # ints and the cap's bounds are fine
	assert_array(ArmorConfig.validate({"k": 50, "armor_reduction_cap": 0, "non_elemental_types": ["physical"]})).is_empty()


func test_armor_json_on_disk_is_the_validated_shape() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ArmorConfig.PATH))
	assert_array(ArmorConfig.validate(parsed)).is_empty()


func test_tier_and_boss_armor_wrong_types_are_refused() -> void:
	var shipped := _shipped_run()
	for bad: Variant in ["17", null, [], true, -0.001]:
		var mutated := shipped.duplicate(true)
		mutated["tiers"]["elite"]["armor"] = bad
		assert_array(_run_problems(mutated)).override_failure_message("elite armor %s accepted" % str(bad)).is_not_empty()
	var boss_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH))
	for bad: Variant in ["50", [], true, -1.0]:
		var mutated_boss := boss_cfg.duplicate(true)
		mutated_boss["bosses"]["boss_guardian"]["armor"] = bad
		assert_array(BossConfig.validate(mutated_boss, KNOWN_ENEMIES)).override_failure_message("boss armor %s accepted" % str(bad)).is_not_empty()
	for bad: Variant in ["8", [], -0.5]:
		var stats: Dictionary = EnemyConfig.stats_for("melee_chaser").duplicate()
		stats["armor"] = bad
		assert_array(EnemyConfig.validate_stats("x", stats)).override_failure_message("enemy armor %s accepted" % str(bad)).is_not_empty()


func test_per_enemy_armor_applies_and_a_tier_never_lowers_it() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -8.0), 40.0)
	enemy.apply_tier("elite", RunConfig.tier("elite"))
	assert_float(enemy.health.base_armor).is_equal(40.0)  # max(own 40, tier 17)
	var plain := _enemy_at(main, Vector3(4, 0, -8.0), 0.0)
	plain.apply_tier("elite", RunConfig.tier("elite"))
	assert_float(plain.health.base_armor).is_equal(float(RunConfig.tier("elite")["armor"]))


func test_parity_check_uses_the_k_it_is_given() -> void:
	# At K 50 armor 17 is 25.4% (matches 25%); at K 60 it is 22.1% (3 points off). So changing K alone breaks parity.
	assert_array(ArmorConfig.parity_errors("t", 17.0, 0.25, 50.0, 0.02)).is_empty()
	assert_array(ArmorConfig.parity_errors("t", 17.0, 0.25, 60.0, 0.02)).is_not_empty()
	assert_array(ArmorConfig.parity_errors("t", 17.0, 0.25, 40.0, 0.02)).is_not_empty()
	var message: String = ArmorConfig.parity_errors("elite", 17.0, 0.5, 50.0, 0.02)[0]
	assert_bool(message.contains("elite") and message.contains("armor")).is_true()


func test_f3_defense_line_for_the_fire_golem_is_literally_right() -> void:
	var main := _spawn_main()
	var golem: Enemy = (load("res://scenes/enemies/FireResistantGolem.tscn") as PackedScene).instantiate()
	main.add_child(golem)
	golem.global_position = main.player.global_position + Vector3(0, 0, -4.0)
	# Today fire is the only element, so a fire-only table is "all elements" and the line is true. It reads the table's own keys,
	# so with a second element the wording would stay "all" for a fire-only golem (review finding N1, latent).
	assert_array(TierRules.element_ids()).is_equal(["fire"])
	assert_str(DebugOverlay.target_line("nearest", golem.enemy_id, golem.tier, golem.health.get_armor(), golem.health.get_armor_reduction(), golem.health.resistances)).is_equal("Nearest: fire_resistant_golem (normal)  Armor 0 (0%)  Resist: all elements 50%")
	assert_float(golem.health.get_resistance("fire")).is_equal(0.5)  # the printed number is what the game applies
	golem.apply_tier("elite", RunConfig.tier("elite"))
	assert_str(DebugOverlay.target_line("cursor", golem.enemy_id, golem.tier, golem.health.get_armor(), golem.health.get_armor_reduction(), golem.health.resistances)).is_equal("Under cursor: fire_resistant_golem (elite)  Armor 17 (25%)  Resist: all elements 50%")
	assert_str(DebugOverlay.player_line(0.0, 0.0)).is_equal("Player: Armor 0 (0%)")
