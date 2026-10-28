class_name Slice3bQaTest
extends GdUnitTestSuite
## qa for Polish 1 Slice 3b (attack rework): gaps found in review of 961d7c6..ad9ee04.
## Each test names what it guards. Tests marked PIN record a current, known-wrong
## number so a fix has to update them on purpose (see docs/reviews/2026-10-28-polish1-slice3b-qa.md).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const SHOOTER_PATH := "res://scenes/enemies/RangedShooter.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func before_test() -> void:
	# Other suites leave CardDatabase on fixture cards.
	CardDatabase.load_all()


var _root_main: Main = null


func after_test() -> void:
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()
	Input.action_release("attack_heavy")
	Input.action_release("attack_light")


func _stun_def() -> Dictionary:
	return (StatusDatabase.get_status("stun") as Dictionary).duplicate(true)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


## Main as a child of the tree root and the current scene, because enemy shots are added
## under current_scene (null under the test runner).
func _spawn_root_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	return main


# --- click cap -------------------------------------------------------------------------

func _controller(mods: StatModifiers) -> AttackController:
	return AttackController.new({
		&"light": AttackDatabase.get_attack("light").duplicate(),
		&"heavy": AttackDatabase.get_heavy("rogue").duplicate(),
	}, mods)


func _always(_id: StringName) -> bool:
	return true


## Spam LMB every tick at the given frame time; returns light starts per second.
func _light_rate(controller: AttackController, step: float, seconds: float, has_target: bool) -> float:
	var fired := [0]
	controller.attack_fired.connect(func(id: StringName) -> void:
		if id == &"light":
			fired[0] += 1)
	var target := func(_id: StringName) -> bool: return has_target
	var elapsed := 0.0
	while elapsed < seconds:
		controller.tick(step, true, {&"light": true}, target)
		elapsed += step
	return float(fired[0]) / seconds


func test_spam_click_cap_holds_at_other_frame_rates_with_a_target_and_with_haste() -> void:
	var ratio := float(AttackDatabase.get_attack("light")["manual_click_max_rate_ratio"])
	for cut: float in [0.0, -0.3, -0.6, -0.9]:
		for step: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 1.0 / 240.0]:
			for has_target: bool in [false, true]:
				var mods := StatModifiers.new()
				if cut != 0.0:
					mods.add_modifier("attack_interval.light", "haste", StatModifiers.MULTIPLICATIVE, cut)
				var controller := _controller(mods)
				var auto_rate := 1.0 / controller.get_interval(&"light")
				var rate := _light_rate(controller, step, 20.0, has_target)
				# A frame can overshoot the gap by up to one step, so the cap is at most gap + step.
				var worst := 1.0 / (controller.get_manual_min_gap(&"light") + step)
				assert_float(rate).override_failure_message("cut %s step %s target %s: %.3f/s vs cap %.3f/s" % [cut, step, has_target, rate, auto_rate * ratio]) \
						.is_less_equal(auto_rate * ratio + 0.05)
				# And it really is capped near ratio x auto, not far below (the cap is not broken the other way).
				assert_float(rate).is_greater_equal(minf(worst, auto_rate * ratio) - 0.1)


func test_attack_speed_floor_keeps_the_cap_finite() -> void:
	# Extreme haste hits MIN_INTERVAL: the click gap is MIN_INTERVAL / ratio, never 0 or negative.
	var mods := StatModifiers.new()
	mods.add_modifier("attack_interval.light", "absurd", StatModifiers.MULTIPLICATIVE, -0.999)
	var controller := _controller(mods)
	assert_float(controller.get_interval(&"light")).is_equal_approx(AttackController.MIN_INTERVAL, 0.0001)
	assert_float(controller.get_manual_min_gap(&"light")).is_greater(0.0)
	var rate := _light_rate(controller, 1.0 / 240.0, 5.0, false)
	assert_bool(is_finite(rate)).is_true()
	assert_float(rate).is_less_equal(1.5 / AttackController.MIN_INTERVAL + 1.0)


func test_heavy_spam_never_beats_its_own_cooldown() -> void:
	var controller := _controller(StatModifiers.new())
	var fired := [0]
	controller.attack_fired.connect(func(id: StringName) -> void:
		if id == &"heavy":
			fired[0] += 1)
	var elapsed := 0.0
	var no_target := func(_id: StringName) -> bool: return false
	while elapsed < 18.0:
		controller.tick(1.0 / 60.0, true, {&"heavy": true}, no_target)
		elapsed += 1.0 / 60.0
	# 1.8 s interval: at most 10 swings in 18 s (+1 for the swing completing at the edge).
	assert_int(fired[0]).is_less_equal(10)
	assert_int(fired[0]).is_greater_equal(9)


func test_spam_click_through_the_real_player_with_haste() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	player.stat_modifiers.add_modifier("attack_interval.light", "haste", StatModifiers.MULTIPLICATIVE, -0.4)
	var fired := [0]
	player.attack_fired.connect(func(id: StringName) -> void:
		if id == &"light":
			fired[0] += 1)
	var seconds := 6.0
	for i in range(int(seconds * 60.0)):
		# Press on even frames, release on odd ones, so every other frame is a fresh click.
		if i % 2 == 0:
			Input.action_press("attack_light")
		else:
			Input.action_release("attack_light")
		await get_tree().physics_frame
	Input.action_release("attack_light")
	var interval := player.attacks.get_interval(&"light")
	assert_float(interval).is_equal_approx(0.36, 0.001)
	assert_float(float(fired[0]) / seconds).is_less_equal(1.5 / interval + 0.1)
	assert_int(fired[0]).is_greater(int(seconds / interval))


# --- the balance table in DECISIONS vs the shipped data -----------------------------------

func test_decisions_balance_table_matches_the_data_files() -> void:
	# card id: [cast damage, cycle cooldown, dps], copied from DECISIONS "Slice 3b-1" (after), Burn cards re-credited by S3B-1 (ticks over min(duration, cycle)).
	var table: Dictionary = {
		"rogue_quick_slash": [5.0, 0.6, 8.33],
		"neutral_pointy_stick": [6.0, 1.0, 6.00],
		"fire_ember_whatever": [7.0, 1.1, 6.36],
		"fire_flaming_nonsense": [9.0, 1.2, 7.50],
		"rogue_overhand_whatever": [12.0, 1.3, 9.23],
		"neutral_shrug_bomb": [12.0, 2.2, 5.45],
		"rogue_everyone_calm_down": [16.0, 3.0, 5.33],
		"fire_fine_burn_then": [18.0, 3.3, 5.45],
	}
	var statuses: Dictionary = {}
	for status_id: String in ["burn"]:
		statuses[status_id] = StatusDatabase.get_status(status_id)
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var light := AttackDatabase.get_attack("light")
	assert_float(float(light["damage"]) / float(light["interval"])).is_equal_approx(5.0, 0.001)
	var seen := 0
	for card: Dictionary in CardDatabase.all_cards():
		if not CardDamageRule.is_damage_card(card):
			continue
		seen += 1
		var id := String(card["id"])
		assert_bool(table.has(id)).override_failure_message("card %s is a damage card but is not in the DECISIONS table" % id).is_true()
		var base := float(slot_table.get_entry(String(card["slot_type"]))["base_cooldown"])
		var cycle := CardDamageRule.cycle_cooldown(card, base)
		var cast := CardDamageRule.cast_damage(card, statuses, cycle)
		assert_float(cast).override_failure_message("%s cast" % id).is_equal_approx(float((table[id] as Array)[0]), 0.001)
		assert_float(cycle).override_failure_message("%s cycle" % id).is_equal_approx(float((table[id] as Array)[1]), 0.001)
		assert_float(cast / cycle).override_failure_message("%s dps" % id).is_equal_approx(float((table[id] as Array)[2]), 0.01)
	assert_int(seen).is_equal(table.size())


func test_no_shipped_card_uses_a_rule_exception() -> void:
	for card: Dictionary in CardDatabase.all_cards():
		assert_bool(card.has("rule_exception")).override_failure_message("%s opts out of the rule" % card["id"]).is_false()


func test_rule_fails_loudly_on_bad_fixture_files_through_the_loader() -> void:
	# A damage card that loses to the light must be reported by the same check the boot uses.
	var weak := {"id": "qa_weak", "slot_type": "attack_single", "cooldown_modifier": 0.0,
			"effects": [{"template": "cone", "params": {"damage": 2.0}}]}
	var slots := {"attack_single": {"base_cooldown": 1.0}}
	var problems := CardDamageRule.check_all([weak], slots, AttackDatabase.get_attack("light"), {})
	assert_int(problems.size()).is_equal(2)
	# A negative damage value must be reported, not silently accepted.
	var negative := {"id": "qa_neg", "slot_type": "attack_single", "cooldown_modifier": 0.0,
			"effects": [{"template": "cone", "params": {"damage": -5.0}}]}
	assert_array(CardDamageRule.check_all([negative], slots, AttackDatabase.get_attack("light"), {})).is_not_empty()


# --- Burn refresh (3b-b) vs what the rule credits ------------------------------------------

## Burn damage per cast when the same target is hit every `cycle` seconds, measured over
## many casts at 60 fps through the real manager (first cast excluded: it is on a fresh target).
func _burn_per_cast(cycle: float, duration: float) -> float:
	var health: Health = auto_free(Health.new())
	health.max_health = 100000.0
	health.current_health = 100000.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	var burn := StatusDatabase.get_status("burn") as Dictionary
	var step := 1.0 / 60.0
	var t := 0.0
	var next_cast := 0.0
	var casts := 0
	var damage_at_second := 0.0
	var measured_from := cycle * 2.0
	while casts < 60:
		if t >= next_cast - 0.000001:
			manager.apply_status("burn", burn, duration)
			casts += 1
			next_cast += cycle
		if t >= measured_from and damage_at_second == 0.0:
			damage_at_second = health.max_health - health.current_health
		manager._process(step)
		t += step
	return (health.max_health - health.current_health - damage_at_second) / float(casts - 2)


func test_burn_refresh_keeps_its_tick_phase_so_the_rule_credit_is_real() -> void:
	# S3B-1 (was a pin of the old bug). A refresh keeps the tick phase, so Burn ticks once a
	# second no matter how often it is recast, as long as it never expires in between.
	# Ember (recast every 1.1 s): 1.1 ticks = 2.2 per cast (rule credits 1 tick = 2).
	assert_float(_burn_per_cast(1.1, 4.0)).is_equal_approx(2.2, 0.25)
	# Fine, Burn Then (every 3.3 s, 5 s Burn): 3.3 ticks = 6.6 per cast (rule credits 3 = 6).
	assert_float(_burn_per_cast(3.3, 5.0)).is_equal_approx(6.6, 0.25)
	# A Burn recast only after it expired gets only its own whole ticks.
	assert_float(_burn_per_cast(10.0, 3.0)).is_equal_approx(6.0, 0.25)


func test_real_sustained_dps_of_every_burn_card_is_at_least_what_the_rule_credits() -> void:
	CardDatabase.load_all()
	var statuses: Dictionary = {"burn": StatusDatabase.get_status("burn")}
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var seen := 0
	for card: Dictionary in CardDatabase.all_cards():
		if not CardDamageRule.is_damage_card(card):
			continue
		var burn_duration := 0.0
		var direct := 0.0
		for effect: Dictionary in card["effects"]:
			var params: Dictionary = effect["params"]
			if effect["template"] == "apply_status":
				burn_duration = float(params["duration"])
			else:
				direct += float(params.get("damage", 0.0))
		if burn_duration <= 0.0:
			continue
		seen += 1
		var cycle := CardDamageRule.cycle_cooldown(card, float(slot_table.get_entry(String(card["slot_type"]))["base_cooldown"]))
		var credited := CardDamageRule.cast_damage(card, statuses, cycle) / cycle
		var real := (direct + _burn_per_cast(cycle, burn_duration)) / cycle
		assert_float(real).override_failure_message("%s real %.3f DPS < credited %.3f" % [card["id"], real, credited]).is_greater_equal(credited - 0.1)
		# And it beats the light in real cycling play, not just on paper.
		assert_float(real).override_failure_message("%s real DPS does not beat the light" % card["id"]).is_greater(5.0)
	assert_int(seen).is_equal(2)


func test_rogue_heavy_total_dps_with_burn_measured_by_a_seeded_sim() -> void:
	# Heavy every 1.8 s, 50% Burn proc (3 s), seeded. Direct 8.5 + Burn, per second, over 600 swings.
	var health: Health = auto_free(Health.new())
	health.max_health = 1000000.0
	health.current_health = 1000000.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	var burn := StatusDatabase.get_status("burn") as Dictionary
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var step := 1.0 / 60.0
	var swings := 600
	var t := 0.0
	var next_swing := 0.0
	var done := 0
	while done < swings or t < next_swing:
		if done < swings and t >= next_swing - 0.000001:
			if rng.randf() < 0.5:
				manager.apply_status("burn", burn, 3.0)
			done += 1
			next_swing += 1.8
		manager._process(step)
		t += step
	var burn_damage := health.max_health - health.current_health
	var total_dps := (8.5 * swings + burn_damage) / (1.8 * swings)
	# Direct 4.72 + about 1.25 Burn = 5.97 (was 5.8 before S3B-1): above the light's 5.0.
	assert_float(total_dps).is_between(5.85, 6.1)


func test_burn_without_refresh_still_deals_every_tick() -> void:
	# Control for the pin above: the full 5 ticks land when nothing refreshes it.
	var health: Health = auto_free(Health.new())
	health.max_health = 100.0
	health.current_health = 100.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	manager.apply_status("burn", StatusDatabase.get_status("burn") as Dictionary, 5.0)
	for i in range(330):
		manager._process(1.0 / 60.0)
	assert_float(100.0 - health.current_health).is_equal_approx(10.0, 0.001)


# --- stun ------------------------------------------------------------------------------------

func test_stunned_ranged_enemy_spawns_no_projectile_but_a_free_one_does() -> void:
	var main := _spawn_root_main()
	await _frames(2)
	var shots := [0]
	main.child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			shots[0] += 1)
	# Control: an unstunned shooter in range fires within its telegraph and cooldown.
	var free_shooter: Enemy = (load(SHOOTER_PATH) as PackedScene).instantiate()
	free_shooter.position = main.player.global_position + Vector3(0.0, 0.0, -5.0)
	main.add_child(free_shooter)
	free_shooter.target = main.player
	await _frames(150)
	assert_int(shots[0]).override_failure_message("control shooter never fired, test would be vacuous").is_greater(0)
	free_shooter.queue_free()
	await _frames(2)
	# Stunned for 4 s (base duration overridden on the call; first stun, so no DR): nothing spawns.
	var held: Enemy = (load(SHOOTER_PATH) as PackedScene).instantiate()
	held.position = main.player.global_position + Vector3(0.0, 0.0, -5.0)
	main.add_child(held)
	held.target = main.player
	held.status_manager.apply_status("stun", _stun_def(), 4.0)
	assert_bool(held.is_stunned()).is_true()
	shots[0] = 0
	await _frames(150)
	assert_bool(held.is_stunned()).is_true()
	assert_int(shots[0]).override_failure_message("a stunned shooter spawned a projectile").is_equal(0)


func test_stun_mid_telegraph_for_a_ranged_enemy_cancels_the_shot() -> void:
	var main := _spawn_root_main()
	await _frames(2)
	var shots := [0]
	main.child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			shots[0] += 1)
	var shooter: Enemy = (load(SHOOTER_PATH) as PackedScene).instantiate()
	shooter.position = main.player.global_position + Vector3(0.0, 0.0, -5.0)
	main.add_child(shooter)
	shooter.target = main.player
	var deadline := 0
	while shooter._telegraph_remaining <= 0.0 and deadline < 200:
		await _frames(1)
		deadline += 1
	assert_float(shooter._telegraph_remaining).override_failure_message("shooter never started a telegraph").is_greater(0.0)
	shooter.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_float(shooter._telegraph_remaining).is_equal(0.0)
	await _frames(30)
	assert_int(shots[0]).is_equal(0)


func test_re_stun_emits_status_refreshed_not_status_applied() -> void:
	# S3B-4 (was a pin). A stun refreshed while active emits `status_refreshed`; `status_applied`
	# stays "began", so the cue (stars, tint, Enemy.stunned) is not restarted.
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	var applied := [0]
	var refreshed := [0]
	manager.status_applied.connect(func(_id: String) -> void: applied[0] += 1)
	manager.status_refreshed.connect(func(_id: String) -> void: refreshed[0] += 1)
	manager.apply_status("stun", _stun_def(), 0.6)
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(applied[0]).is_equal(1)
	assert_int(refreshed[0]).is_equal(1)


func test_re_stun_on_an_enemy_emits_stun_refreshed_once_and_keeps_one_set_of_stars() -> void:
	var main := _spawn_main()
	await _frames(2)
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = main.player.global_position + Vector3(0.0, 0.0, -9.0)
	main.add_child(enemy)
	enemy.target = null
	await _frames(2)
	var started := [0]
	var refreshed: Array[float] = []
	enemy.stunned.connect(func(_d: float) -> void: started[0] += 1)
	enemy.stun_refreshed.connect(func(remaining: float) -> void: refreshed.append(remaining))
	enemy.status_manager.apply_status("stun", StatusDatabase.get_status("stun"), 0.6)
	var pool_before := enemy.status_manager._vfx_pool().active_count()
	enemy.status_manager.apply_status("stun", StatusDatabase.get_status("stun"), 0.6)
	assert_int(started[0]).is_equal(1)
	assert_int(refreshed.size()).is_equal(1)
	assert_float(refreshed[0]).is_greater(0.0)
	assert_int(enemy.status_manager._vfx_pool().active_count()).is_equal(pool_before)


func test_stun_clock_is_game_time_and_survives_many_stuns_without_growth() -> void:
	# StunRules prunes on every resolve: after thousands of stuns the history is bounded
	# by immune_after, not by the number of stuns.
	var rules := StunRules.new()
	var def := _stun_def()
	for i in range(5000):
		rules.resolve(float(i) * 0.5, 0.6, "normal", def)
	assert_int(rules._times.size()).is_less_equal(int((def["diminishing_returns"] as Dictionary)["immune_after"]))


func test_stun_with_zero_negative_or_huge_base_duration() -> void:
	var def := _stun_def()
	var rules := StunRules.new()
	assert_float(rules.resolve(0.0, 0.0, "normal", def)).is_equal(0.0)
	assert_float(rules.resolve(0.0, -1.0, "normal", def)).is_equal(0.0)
	assert_float(rules.resolve(0.0, 1.0e9, "normal", def)).is_equal_approx(1.0e9, 1.0)
	# Fresh history for the unknown rank (the call above is a recorded repeat): treated as normal.
	assert_float(StunRules.new().resolve(0.0, 0.6, "unknown_rank", def)).is_equal_approx(0.6, 0.0001)


# --- wind-up slow ---------------------------------------------------------------------------

func test_wind_up_slow_dies_with_the_player_when_the_arena_is_freed_mid_windup() -> void:
	var first := _spawn_main()
	await _frames(2)
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	assert_bool(first.player.attacks.is_winding_up(&"heavy")).is_true()
	assert_float(first.player.get_move_speed()).is_less(first.player.move_speed)
	first.free()
	await _frames(2)
	var fresh := _spawn_main()
	await _frames(2)
	assert_float(fresh.player.get_move_speed()).is_equal_approx(fresh.player.move_speed, 0.0001)
	assert_bool(fresh.player.stat_modifiers != null).is_true()


func test_wind_up_slow_never_roots_even_stacked_with_a_move_speed_debuff() -> void:
	var mods := StatModifiers.new()
	var controller := _controller(mods)
	controller.tick(0.016, true, {&"heavy": true}, func(_id: StringName) -> bool: return false)
	assert_float(mods.apply("move_speed", 6.0)).is_greater(0.0)
	# Data guard: nothing in attacks.json may reach -1.
	for entry: Dictionary in [AttackDatabase.get_attack("light"), AttackDatabase.get_heavy("rogue"), AttackDatabase.get_heavy("wizard")]:
		assert_float(float(entry["wind_up_move_slow"])).is_greater(-1.0)
		assert_float(float(entry["wind_up_move_slow"])).is_less_equal(0.0)


func test_wizard_heavy_slow_applies_and_clears_on_the_same_paths() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	player.use_heavy_class("wizard")
	player.camera = null
	player.rotation = Vector3.ZERO
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_true()
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed * 0.65, 0.0001)
	# Swapping class mid wind-up (a capture hook) must not leave the slow behind.
	player.use_heavy_class("rogue")
	assert_float(player.get_move_speed()).is_equal_approx(player.move_speed, 0.0001)


func test_attack_started_is_emitted_after_the_wind_up_state_and_slow() -> void:
	# S3B-3 (was a pin): inside an attack_started handler the controller already reports
	# the wind-up and the slow is already applied.
	var mods := StatModifiers.new()
	var controller := _controller(mods)
	var seen := {"winding": null, "speed": null}
	var probe := func(id: StringName) -> void:
		seen["winding"] = controller.is_winding_up(id)
		seen["speed"] = mods.apply("move_speed", 6.0)
	controller.attack_started.connect(probe)
	controller.tick(0.016, true, {&"heavy": true}, func(_id: StringName) -> bool: return false)
	# Disconnect: the lambda captures the controller, which would otherwise be a reference cycle.
	controller.attack_started.disconnect(probe)
	assert_bool(bool(seen["winding"])).is_true()
	assert_float(float(seen["speed"])).is_equal_approx(6.0 * 0.65, 0.0001)
	assert_bool(controller.is_winding_up(&"heavy")).is_true()


# --- targeted_aoe ------------------------------------------------------------------------------

func test_wizard_heavy_at_the_arena_edge_aimed_outward_stays_inside_and_hits_cleanly() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	player.use_heavy_class("wizard")
	player.camera = null
	player.global_position = Vector3(19.6, player.global_position.y, 19.6)
	player.aim_point_override = Vector3(60.0, 0.0, 60.0)
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	var target := player.get_aoe_target(&"heavy")
	assert_bool(target.is_finite()).is_true()
	assert_float(target.x).is_less_equal(19.5 + 0.001)
	assert_float(target.z).is_less_equal(19.5 + 0.001)
	await _frames(60)
	assert_bool(player.has_aoe_telegraph(&"heavy")).is_false()
	assert_bool(player.get_aoe_target(&"heavy").is_equal_approx(Vector3.INF)).is_true()


func test_aoe_targeting_edge_values() -> void:
	var arena := Rect2(-20.0, -20.0, 40.0, 40.0)
	# Zero range: the disc lands on the caster.
	var zero := AoeTargeting.clamp_target(Vector3.ZERO, Vector3(5.0, 0.0, 5.0), Vector3.FORWARD, 0.0, arena)
	assert_vector(zero).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	# Infinite aim point is not finite: falls back to ahead.
	var inf := AoeTargeting.clamp_target(Vector3.ZERO, Vector3(INF, 0.0, 0.0), Vector3.FORWARD, 7.0, arena)
	assert_bool(inf.is_finite()).is_true()
	# Caster already outside the arena: the target is pulled inside.
	var outside := AoeTargeting.clamp_target(Vector3(50.0, 0.0, 0.0), Vector3(50.0, 0.0, 0.0), Vector3.FORWARD, 7.0, arena)
	assert_float(outside.x).is_less_equal(19.5 + 0.001)
	# A non-vector aim value (e.g. a string from a bad scenario) is ignored, not an error.
	var junk := AoeTargeting.clamp_target(Vector3.ZERO, "oops", Vector3(0.0, 0.0, -1.0), 7.0, arena)
	assert_vector(junk).is_equal_approx(Vector3(0.0, 0.0, -7.0), Vector3.ONE * 0.0001)


# --- S3B-7: per-frame costs ---------------------------------------------------------------------

func test_is_stunned_tracks_a_counter_through_apply_refresh_and_expiry() -> void:
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	var burn := StatusDatabase.get_status("burn") as Dictionary
	manager.apply_status("burn", burn, 2.0)
	assert_bool(manager.is_stunned()).is_false()
	manager.apply_status("stun", _stun_def(), 0.6)
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(manager.is_stunned()).is_true()
	manager._process(0.7)
	assert_bool(manager.is_stunned()).is_false()
	assert_bool(manager.has_status("burn")).is_true()
	# A stun after the first expired counts again, and an immune one does not.
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(manager.is_stunned()).is_true()
	manager._process(2.0)
	assert_bool(manager.is_stunned()).is_false()
	assert_int(manager._stun_count).is_equal(0)
