class_name Pl3QaTest
extends GdUnitTestSuite
## qa review of PL3 (9a86757, fbfd86c, da418aa): knockback paths, scripted input and the boss-attack anchor, the Ward aura,
## the projectile hit radius against `ball_scale`, damage numbers under the boss bar (with camera shake), the volley gap
## tint against `Boss.in_threat`, reward-screen keys, and the card strip at small sizes.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"


func before_test() -> void:
	Juice.hit_stop_enabled = false


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


# ---- Knockback fix ----

func _hit(main: Main, strength: float, direction: Vector3 = Vector3(0.0, 0.0, 1.0)) -> void:
	main.player.health.damage_immune = false
	main.player.health.take_damage(1.0, "physical", direction * strength)


func test_knockback_is_proportional_to_speed_squared_for_small_and_large_hits() -> void:
	var main := _main()
	main.player.camera = null
	await _frames(2)
	for strength: float in [3.0, 6.0, 9.0, 14.0]:
		main.player.global_position = Vector3(0.0, 0.2, -12.0)
		main.player.velocity = Vector3.ZERO
		await _frames(3)
		var from: float = main.player.global_position.z
		_hit(main, strength)
		await _frames(90)
		var expected: float = strength * strength / (2.0 * Player.KNOCKBACK_DECAY)
		var got: float = main.player.global_position.z - from
		assert_float(got).override_failure_message("%.0f m/s: expected about %.2f m, got %.2f m" % [strength, expected, got]).is_between(expected * 0.85, expected * 1.15)


func test_a_real_dodge_zeroes_the_applied_knockback_and_walking_resumes_at_normal_speed() -> void:
	var main := _main()
	main.player.camera = null
	await _frames(2)
	main.player.global_position = Vector3(0.0, 0.2, -10.0)
	await _frames(3)
	_hit(main, 9.0)
	# An earlier suite can leave "dodge" held (Input.is_action_just_pressed is then false for the whole test); start from released.
	Input.action_release(&"dodge")
	TestInput.release(&"dodge")
	await _frames(2)
	TestInput.press(&"dodge")
	await _frames(2)
	TestInput.release(&"dodge")
	assert_bool(main.player._forced_move_time_remaining > 0.0 or main.player.dodge_charges.current < main.player.dodge_charges_max()).override_failure_message("the dodge did not start; the test would prove nothing").is_true()
	assert_float(main.player._applied_knockback.length()).is_less(0.001)
	await _frames(120)
	assert_float(Vector2(main.player.velocity.x, main.player.velocity.z).length()).is_less(0.05)
	assert_float(main.player._applied_knockback.length()).is_less(0.001)


func test_a_knockback_into_a_wall_does_not_pull_the_player_back_off_it() -> void:
	var main := _main()
	main.player.camera = null
	await _frames(2)
	var rect: Rect2 = main.player.get_arena_rect()
	main.player.global_position = Vector3(0.0, 0.2, rect.end.y - 1.0)
	await _frames(3)
	_hit(main, 9.0)
	var wall_z: float = rect.end.y
	var nearest: float = INF
	for i in range(90):
		await _frames(1)
		nearest = minf(nearest, wall_z - main.player.global_position.z)
	print("PL3 QA wall measurement: closest %.3f m, ended %.3f m from the wall (pull-back %.3f m)" % [nearest, wall_z - main.player.global_position.z, wall_z - main.player.global_position.z - nearest])
	assert_float(wall_z - main.player.global_position.z).override_failure_message("the player ended %.2f m from the wall after a 9 m/s hit into it; closest was %.2f m" % [wall_z - main.player.global_position.z, nearest]).is_less(nearest + 0.35)
	assert_bool(rect.grow(0.05).has_point(Vector2(main.player.global_position.x, main.player.global_position.z))).is_true()


func test_a_dead_player_with_a_knockback_stays_finite_and_inside() -> void:
	var main := _main()
	main.player.camera = null
	await _frames(2)
	main.player.global_position = Vector3(0.0, 0.2, -10.0)
	await _frames(3)
	main.player.health.damage_immune = false
	main.player.health.take_damage(9999.0, "physical", Vector3(0.0, 0.0, 9.0))
	await _frames(60)
	assert_bool(is_finite(main.player.global_position.z) and is_finite(main.player.velocity.length())).is_true()
	assert_bool(main.player.get_arena_rect().grow(0.05).has_point(Vector2(main.player.global_position.x, main.player.global_position.z))).is_true()


func test_enemy_knockback_is_unchanged_by_the_player_fix() -> void:
	# Enemy.gd was not touched by fbfd86c; pin its own distance so a future shared change shows up.
	var source: String = FileAccess.get_file_as_string("res://src/enemies/Enemy.gd")
	assert_bool(source.contains("_applied_knockback")).is_false()
	var main := _main()
	await _frames(2)
	var enemy: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.target = null
	enemy.global_position = Vector3(0.0, 0.2, -12.0)
	enemy.begin_spawn_grace(99.0)
	await _frames(3)
	var from: float = enemy.global_position.z
	enemy.health.take_damage(1.0, "physical", Vector3(0.0, 0.0, 6.0))
	await _frames(60)
	assert_float(enemy.global_position.z - from).is_between(0.2, 6.0)


# ---- Tooling: --press, --at-boss-attack ----

func test_scripted_input_taps_the_action_once_and_releases_it() -> void:
	# A private action: the real ones can be left held by another suite, which would hide the press.
	InputMap.add_action(&"pl3_scripted_probe")
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.05, "action": &"pl3_scripted_probe"}]
	add_child(scripted)
	auto_free(scripted)
	var pressed_frames := 0
	var released_after := false
	for i in range(80):
		await get_tree().process_frame
		if Input.is_action_pressed(&"pl3_scripted_probe"):
			pressed_frames += 1
		elif pressed_frames > 0:
			released_after = true
	InputMap.erase_action(&"pl3_scripted_probe")
	assert_int(pressed_frames).override_failure_message("the scripted tap never pressed the action").is_greater(0)
	assert_bool(released_after).override_failure_message("the scripted tap never released the action").is_true()


func test_scripted_input_presses_in_time_order_even_if_given_out_of_order() -> void:
	var scripted := ScriptedInput.new()
	scripted.presses = [{"at": 0.4, "action": &"dodge"}, {"at": 0.1, "action": &"dodge"}]
	add_child(scripted)
	auto_free(scripted)
	await get_tree().process_frame
	assert_float(float(scripted.presses[0]["at"])).is_equal(0.1)


func test_boss_attack_anchor_waits_for_the_named_attack_and_then_counts_from_it() -> void:
	var holder := Node3D.new()
	add_child(holder)
	auto_free(holder)
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	holder.add_child(boss)
	var capture := ScreenshotCapture.new()
	capture.times = [1.0]
	capture.anchor_boss_attack = "volley"
	holder.add_child(capture)
	capture.process_mode = Node.PROCESS_MODE_DISABLED  # driven by hand below: no screenshot, no quit
	assert_bool(capture._anchored).is_false()
	boss.attack_telegraphed.emit("smash", "Smash", 1.0)
	assert_bool(capture._anchored).override_failure_message("another attack must not anchor the capture").is_false()
	capture._elapsed = 5.0
	boss.attack_telegraphed.emit("volley", "Fan", 1.0)
	assert_bool(capture._anchored).is_true()
	assert_float(capture._elapsed).is_equal(0.0)
	# A boss added later (the run spawns it after launch) is watched too.
	var late: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	holder.add_child(late)
	assert_bool(late.attack_telegraphed.is_connected(capture._on_attack_telegraphed)).is_true()


func test_boss_attack_anchor_gives_up_loudly_after_its_timeout() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/debug/ScreenshotCapture.gd")
	assert_bool(source.contains("get_tree().quit(1)")).is_true()
	assert_bool(source.contains("push_error")).is_true()
	assert_float(ScreenshotCapture.ANCHOR_TIMEOUT).is_equal(90.0)


# ---- Ward aura ----

func test_the_ward_aura_appears_with_the_buff_and_is_gone_with_it() -> void:
	var main := _main()
	await _frames(3)
	main.player.attacks.set_auto(&"light", false)  # no stray bolts or hit effects in the pool count
	main.player.attacks.set_auto(&"heavy", false)
	var pool := EffectPool.for_world(main)
	assert_object(pool).is_not_null()
	await get_tree().create_timer(1.0).timeout
	var armor_before: float = main.player.stat_modifiers.apply("armor", 0.0)
	var active_before: int = pool.active_count()
	var context := EffectContext.new(main.player, main)
	EffectTemplates.execute("buff", {"stat": "armor", "modifier_type": StatModifiers.ADDITIVE, "value": 25.0, "duration": 0.5}, context)
	var armor_during: float = main.player.stat_modifiers.apply("armor", 0.0)
	assert_float(armor_during - armor_before).is_equal_approx(25.0, 0.001)
	var with_buff: int = pool.active_count()
	assert_int(with_buff - active_before).override_failure_message("cast burst plus aura ring and bubble: at least 3 effects").is_greater_equal(3)
	# The aura follows the caster.
	main.player.global_position = Vector3(3.0, 0.2, -3.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	assert_int(pool.active_count()).is_greater_equal(active_before + 2)  # still up before the buff ends
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	assert_float(main.player.stat_modifiers.apply("armor", 0.0)).is_equal_approx(armor_before, 0.001)
	assert_int(pool.active_count()).override_failure_message("aura outlived the buff").is_equal(active_before)


func test_a_non_armor_buff_gets_no_aura() -> void:
	var main := _main()
	await _frames(3)
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	var pool := EffectPool.for_world(main)
	await get_tree().create_timer(1.0).timeout  # let the pool settle after the room loads
	var counts: Dictionary = {}
	for stat: String in ["move_speed", "armor"]:
		var settled: int = pool.active_count()
		EffectTemplates.execute("buff", {"stat": stat, "modifier_type": StatModifiers.ADDITIVE, "value": 1.0, "duration": 5.0}, EffectContext.new(main.player, main))
		counts[stat] = pool.active_count() - settled
	assert_int(int(counts["armor"]) - int(counts["move_speed"])).override_failure_message("armor should add the ring and bubble over the cast burst: %s" % str(counts)).is_equal(2)


# ---- Card projectile look ----

func test_ball_scale_resizes_the_drawn_ball_but_never_the_hit_radius() -> void:
	var main := _main()
	await _frames(2)
	var radius: float = 0.3
	var radii: Array[float] = []
	var visuals: Array[float] = []
	for ball_scale: float in [1.0, 3.0]:
		var projectile: Projectile = (load(EffectTemplates.PROJECTILE_SCENE_PATH) as PackedScene).instantiate()
		main.add_child(projectile)
		projectile.set_hit_radius(radius)
		projectile.set_look(EffectTemplates.resolved_look({"color": "#ffffff", "scale": 1.0, "ball_scale": ball_scale}))
		radii.append(((projectile.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius)
		visuals.append(projectile.visual_radius())
	assert_float(radii[0]).is_equal_approx(radius, 0.0001)
	assert_float(radii[1]).override_failure_message("ball_scale changed the collision radius").is_equal_approx(radius, 0.0001)
	assert_float(visuals[1]).is_equal_approx(visuals[0] * 3.0, 0.001)


func test_look_validation_failure_paths_name_the_field() -> void:
	for bad: Dictionary in [{}, {"color": 5}, {"color": "#ffffff", "scale": 0.0}, {"color": "#ffffff", "ball_scale": -1.0}, {"color": "#ffffff", "ball_scale": "big"}, {"color": "#ffffff", "ball_scale": NAN}, {"color": "#fffffg"}]:
		var errors: Array[String] = EffectTemplates.validate_look(bad)
		assert_array(errors).override_failure_message("accepted %s" % str(bad)).is_not_empty()
	assert_array(EffectTemplates.validate_look("red")).is_not_empty()
	assert_array(EffectTemplates.validate_look(null)).is_not_empty()
	# Every shipped card that carries a look validates through the real card schema path too.
	for card: Variant in CardDatabase.all_cards():
		var id: String = String((card as Dictionary)["id"])
		for effect: Variant in (card as Dictionary)["effects"]:
			var params: Dictionary = (effect as Dictionary)["params"]
			if params.has("look"):
				assert_array(EffectTemplates.validate_look(params["look"])).override_failure_message(id).is_empty()


# ---- Damage numbers under the boss bar ----

func _spawn_boss_bar_main() -> Main:
	var main := _main()
	await get_tree().process_frame
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.target = main.player
	main.add_child(boss)
	boss.global_position = Vector3(0.0, 0.2, -30.0)
	boss.begin_spawn_grace(999.0)
	for i in range(4):
		await get_tree().process_frame
	return main


func _number_at_screen(main: Main, screen: Vector2) -> DamageNumber:
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var number: DamageNumber = (load("res://scenes/effects/DamageNumber.tscn") as PackedScene).instantiate()
	number.configure(UiConfig.damage_numbers())
	main.add_child(number)
	number.global_position = camera.project_position(screen, 18.0)
	number.show_amount(7.0, "fire", Color.ORANGE, false)
	return number


func test_a_damage_number_inside_the_boss_bar_block_is_pushed_below_it() -> void:
	var main := await _spawn_boss_bar_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	assert_bool(bar.is_showing()).override_failure_message("the boss bar is not showing; the test would prove nothing").is_true()
	var limit: float = bar.occupied_bottom()
	assert_float(limit).is_greater(20.0)
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var number := _number_at_screen(main, Vector2(main.get_viewport().get_visible_rect().size.x * 0.5, limit * 0.4))
	assert_float(camera.unproject_position(number.global_position).y).is_less(limit)  # starts inside the block
	await get_tree().process_frame
	await get_tree().process_frame
	var y: float = camera.unproject_position(number.global_position).y
	assert_float(y).override_failure_message("number at y=%.1f is still over the bar (bottom %.1f)" % [y, limit]).is_greater_equal(limit)
	# A number already below the bar is left alone.
	var low := _number_at_screen(main, Vector2(300.0, limit + 200.0))
	var before: float = camera.unproject_position(low.global_position).y
	await get_tree().process_frame
	assert_float(camera.unproject_position(low.global_position).y).is_equal_approx(before - 0.0, 8.0)  # only its own rise


func test_damage_numbers_stay_below_the_boss_bar_while_the_camera_shakes() -> void:
	var main := await _spawn_boss_bar_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	var limit: float = bar.occupied_bottom()
	assert_float(limit).is_greater(20.0)
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var number := _number_at_screen(main, Vector2(main.get_viewport().get_visible_rect().size.x * 0.5, limit * 0.4))
	main.camera_rig.shake(0.6, 3.0)
	var worst: float = INF
	for i in range(40):
		await get_tree().process_frame
		if not is_instance_valid(number):
			break
		worst = minf(worst, camera.unproject_position(number.global_position).y)
	assert_float(worst).override_failure_message("with shake the number was drawn at y=%.1f, over the bar block that ends at %.1f" % [worst, limit]).is_greater_equal(limit - 2.0)


func test_numbers_are_not_moved_when_no_boss_bar_is_up() -> void:
	var main := _main()
	await get_tree().process_frame
	await get_tree().process_frame
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var number := _number_at_screen(main, Vector2(600.0, 20.0))
	var y0: float = camera.unproject_position(number.global_position).y
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(camera.unproject_position(number.global_position).y).override_failure_message("a number moved with no boss bar showing").is_less(y0 + 1.0)


# ---- Volley gap tint against Boss.in_threat ----

func _volley_boss(main: Main) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = Vector3(0.0, 0.2, -14.0)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.begin_spawn_grace(99.0)
	main.player.global_position = Vector3(0.0, 0.2, -2.0)
	boss._begin_windup("volley")
	return boss


func test_no_gap_tint_is_drawn_where_a_pellet_would_hit_and_none_within_seven_metres() -> void:
	var main := _main()
	await _frames(2)
	var boss := _volley_boss(main)
	var attack: Dictionary = BossConfig.boss("boss_guardian")["attacks"]["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var half: float = BossRules.volley_half_width(attack)
	var min_half: float = VfxConfig.marker("boss_volley_gap_min_half_width")
	var max_len: float = VfxConfig.marker("boss_volley_lane_max_length")
	var segments: Array[Dictionary] = VolleyGaps.segments(angles, half, min_half, VfxConfig.marker("boss_volley_gap_segment_length"), max_len)
	assert_int(segments.size()).is_greater(0)
	var aim: Vector3 = boss._lock_dir
	var checked: int = 0
	for seg: Dictionary in segments:
		var dir: Vector3 = aim.rotated(Vector3.UP, deg_to_rad(float(seg["angle"])))
		var side: Vector3 = dir.cross(Vector3.UP)
		assert_float(float(seg["start"])).override_failure_message("a tint starts at %.2f m, inside 7 m" % float(seg["start"])).is_greater_equal(7.0)
		for t: float in [0.0, 0.5, 1.0]:
			for lateral: float in [-1.0, 0.0, 1.0]:
				var p: Vector3 = boss.global_position + dir * (float(seg["start"]) + float(seg["length"]) * t) + side * float(seg["half_width"]) * lateral
				assert_bool(boss.in_threat(p)).override_failure_message("tint at %.1f m from the boss (angle %.1f, lateral %.2f) is inside a lane" % [float(seg["start"]) + float(seg["length"]) * t, float(seg["angle"]), lateral]).is_false()
				checked += 1
	assert_int(checked).is_greater(30)
	# Control: the lane centres are in the threat, so the check above can fail.
	for angle: float in angles:
		assert_bool(boss.in_threat(boss.global_position + aim.rotated(Vector3.UP, deg_to_rad(angle)) * 9.0)).is_true()
	boss.queue_free()


func test_gap_tint_by_distance_matches_the_truth_at_6_8_and_11_metres() -> void:
	var main := _main()
	await _frames(2)
	var boss := _volley_boss(main)
	var attack: Dictionary = BossConfig.boss("boss_guardian")["attacks"]["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var half: float = BossRules.volley_half_width(attack)
	var min_half: float = VfxConfig.marker("boss_volley_gap_min_half_width")
	var segments: Array[Dictionary] = VolleyGaps.segments(angles, half, min_half, 1.0, 14.0)
	for distance: float in [6.0, 8.0, 11.0]:
		# Is there a tint on the first gap at this distance?
		var tinted := false
		for seg: Dictionary in segments:
			if is_equal_approx(float(seg["angle"]), (angles[0] + angles[1]) * 0.5) and float(seg["start"]) <= distance and distance <= float(seg["start"]) + float(seg["length"]):
				tinted = true
		var dir: Vector3 = boss._lock_dir.rotated(Vector3.UP, deg_to_rad((angles[0] + angles[1]) * 0.5))
		# Truth: sweep across the gap at this distance and find the widest run of not-in-threat.
		var side: Vector3 = dir.cross(Vector3.UP)
		var free_width: float = 0.0
		var run: float = 0.0
		var x: float = -3.0
		while x <= 3.0:
			if boss.in_threat(boss.global_position + dir * distance + side * x):
				run = 0.0
			else:
				run += 0.02
				free_width = maxf(free_width, run)
			x += 0.02
		var cap: float = free_width * 0.5
		if distance <= 7.0:
			assert_bool(tinted).override_failure_message("%.0f m: a gap tint is drawn where the free gap is only %.2f m wide" % [distance, free_width]).is_false()
		if tinted:
			assert_float(cap).override_failure_message("%.0f m: tinted but the free half-width is only %.2f" % [distance, cap]).is_greater_equal(min_half - 0.03)
	boss.queue_free()


func test_the_drawn_gap_parts_match_the_computed_segments() -> void:
	var main := _main()
	await _frames(2)
	var boss := _volley_boss(main)
	var pool := EffectPool.for_world(main)
	var attack: Dictionary = BossConfig.boss("boss_guardian")["attacks"]["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var half: float = BossRules.volley_half_width(attack)
	var parts: Array[PooledEffect] = TemplateVfx.boss_volley_gaps(pool, boss.global_position, boss._lock_dir, angles, half, 0.75)
	var expected: Array[Dictionary] = VolleyGaps.segments(angles, half, VfxConfig.marker("boss_volley_gap_min_half_width"), VfxConfig.marker("boss_volley_gap_segment_length"), VfxConfig.marker("boss_volley_lane_max_length"))
	assert_int(parts.size()).is_equal(expected.size())
	assert_int(TemplateVfx.boss_volley_gaps(pool, boss.global_position, Vector3.ZERO, angles, half, 0.75).size()).is_equal(0)
	assert_int(TemplateVfx.boss_volley_gaps(pool, boss.global_position, boss._lock_dir, angles, half, 0.0).size()).is_equal(0)
	assert_int(TemplateVfx.boss_volley_gaps(null, boss.global_position, boss._lock_dir, angles, half, 0.75).size()).is_equal(0)
	boss.queue_free()


# ---- Reward and removal screens ----

## Opens a real reward choice (three offered cards, one of them Recovery) on the run's prompt. Returns [main, prompt, options].
func _open_prompt() -> Array:
	RunSession.begin_new_run(42)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	var ctx: Dictionary = RunChoices.shipped_context(main.player.owned_pools)
	var state := RunState.new()
	state.rejects_remaining = 3
	state.pending = RunState.PENDING_REWARD
	for slot_type: String in ["attack_single", "utility", "recovery"]:
		for card: Variant in CardDatabase.cards_for_slot_type(slot_type):
			if String((card as Dictionary)["pool"]) in main.player.owned_pools:
				state.offer.append(String((card as Dictionary)["id"]))
				break
	assert(state.offer.size() == 3)
	var model: Dictionary = RunChoices.model(state, ctx)
	model.merge({"room_type": "combat", "room_label": "", "room_type_name": "", "next_line": ""})
	prompt.show_choice(model)
	prompt.disarm()
	await get_tree().process_frame
	await get_tree().process_frame
	return [main, prompt, model["options"]]


func test_digits_do_nothing_on_the_reward_screen_and_enter_still_picks() -> void:
	var opened := await _open_prompt()
	var prompt := opened[1] as RunPromptScreen
	var options: Array = opened[2]
	assert_int(options.size()).override_failure_message("no offer was built; the test would prove nothing").is_greater(2)
	var picked: Array[String] = []
	prompt.option_chosen.connect(func(id: String) -> void: picked.append(id))
	var focus_before: Control = prompt.get_viewport().gui_get_focus_owner()
	for code: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_KP_1, KEY_KP_2, KEY_0, KEY_9]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		prompt._input(event)
	assert_object(prompt.get_viewport().gui_get_focus_owner()).is_same(focus_before)
	assert_array(picked).is_empty()
	# Arrow keys move, Enter confirms the focused option.
	var buttons: Array = prompt._option_buttons
	assert_int(buttons.size()).is_greater(1)
	(buttons[0] as Button).grab_focus()
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	prompt.get_viewport().push_input(right)
	await get_tree().process_frame
	var focused: Control = prompt.get_viewport().gui_get_focus_owner()
	assert_bool(focused != buttons[0]).override_failure_message("the right arrow did not move the highlight").is_true()
	for pressed: bool in [true, false]:  # a real Enter through the input queue, not a direct signal
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(picked.size()).override_failure_message("Enter did not pick the focused option").is_equal(1)


func test_a_real_mouse_click_picks_an_option() -> void:
	var opened := await _open_prompt()
	var prompt := opened[1] as RunPromptScreen
	var options: Array = opened[2]
	assert_int(options.size()).is_greater(2)
	var picked: Array[String] = []
	prompt.option_chosen.connect(func(id: String) -> void: picked.append(id))
	var button: Button = prompt._option_buttons[0]
	var centre: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = centre
		click.global_position = centre
		prompt.get_viewport().push_input(click)
		await get_tree().process_frame
	assert_int(picked.size()).override_failure_message("a click on the first option did not pick it").is_equal(1)


func test_digits_do_nothing_on_the_removal_grid() -> void:
	var opened := await _open_prompt()
	var main := opened[0] as Main
	var prompt := opened[1] as RunPromptScreen
	var ctx: Dictionary = RunChoices.shipped_context(main.player.owned_pools)
	var state := RunState.new()
	for card: Dictionary in CardDatabase.all_cards():
		state.deck.append(String(card["id"]))
	state.pending = RunState.PENDING_REST_REMOVE
	var model: Dictionary = RunChoices.model(state, ctx)
	model.merge({"room_type": "rest", "room_label": "", "room_type_name": "", "next_line": ""})
	prompt.show_choice(model)
	prompt.disarm()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(RunPromptScreen.layout_for(model["options"])).is_equal("grid")
	var focus_before: Control = prompt.get_viewport().gui_get_focus_owner()
	var chosen: Array[String] = []
	prompt.option_chosen.connect(func(id: String) -> void: chosen.append(id))
	for code: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_KP_3]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		prompt.get_viewport().push_input(event)
		await get_tree().process_frame
	assert_object(prompt.get_viewport().gui_get_focus_owner()).override_failure_message("a digit moved the focus on the removal grid").is_same(focus_before)
	assert_array(chosen).is_empty()
	assert_str(prompt.keys_label.text).not_contains("1-")


func test_a_reward_option_shows_the_live_key_as_a_key_cap_label() -> void:
	var saved: Array[InputEvent] = InputMap.action_get_events(&"slot_5")
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	f.keycode = KEY_F
	InputMap.action_erase_events(&"slot_5")
	InputMap.action_add_event(&"slot_5", f)
	var opened := await _open_prompt()
	var prompt := opened[1] as RunPromptScreen
	var options: Array = opened[2]
	var recovery: String = CardSlotController.SLOT_TYPE_ORDER[4]
	var found: Array[String] = []
	var texts: Array[String] = []
	_collect_labels(prompt, texts)
	for text: String in texts:
		if text == "F":
			found.append(text)
	InputMap.action_erase_events(&"slot_5")
	for e: InputEvent in saved:
		InputMap.action_add_event(&"slot_5", e)
	var has_recovery_offer := false
	for option: Variant in options:
		if String((option as Dictionary).get("slot_type", "")) == recovery:
			has_recovery_offer = true
	assert_bool(has_recovery_offer).override_failure_message("the offer has no Recovery card; the key cap check would be vacuous").is_true()
	if has_recovery_offer:
		assert_array(found).override_failure_message("no key cap 'F' on the screen after rebinding Recovery to F; labels: %s" % str(texts)).is_not_empty()
	assert_array(texts.filter(func(t: String) -> bool: return t.begins_with("Key ") or t.contains("(F)"))).override_failure_message("old 'Key X' chip wording is back").is_empty()


func _collect_labels(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_labels(child, out)


func test_the_key_cap_shows_the_live_key_and_follows_a_rebind() -> void:
	var saved: Array[InputEvent] = InputMap.action_get_events(&"slot_5")
	var slot0: String = CardSlotController.SLOT_TYPE_ORDER[4]
	var original: String = InputLabels.slot_key(slot0)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	InputMap.action_erase_events(&"slot_5")
	InputMap.action_add_event(&"slot_5", event)
	var slot: String = CardSlotController.SLOT_TYPE_ORDER[4]
	assert_str(InputLabels.slot_key(slot)).is_equal("F")
	var texts: Dictionary = RunConfig.ui()["option"]
	assert_str(String(texts["slot_key"]) % InputLabels.slot_key(slot)).is_equal("F")
	InputMap.action_erase_events(&"slot_5")
	for e: InputEvent in saved:
		InputMap.action_add_event(&"slot_5", e)
	assert_str(InputLabels.slot_key(slot)).is_equal(original)


# ---- Card strip fit, dodge pulse ----

func test_card_strip_rows_fit_their_slot_at_small_and_large_windows() -> void:
	var cfg := UiConfig.hud()
	for height: float in [480.0, 540.0, 600.0, 720.0, 1080.0, 1440.0]:
		var vp := Vector2(height * 16.0 / 9.0, height)
		var sub := SubViewport.new()
		sub.size = Vector2i(vp)
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sub)
		auto_free(sub)
		var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
		sub.add_child(hud)
		await get_tree().process_frame
		await get_tree().process_frame
		for widget: CardSlotWidget in hud.slot_widgets:
			var wanted: float = widget.custom_minimum_size.y
			# Rows are rounded to whole pixels and the separation is at least 2 px, so below 720 px high the rows run over the slot a
			# little (measured: 0.7 px at 480, 2.5 at 540, 3.3 at 600, the supported minimum 1024x600). Pinned at 4 px so it cannot
			# grow unnoticed; reported to ux-designer as a non-blocking note.
			assert_float(widget.get_combined_minimum_size().y).override_failure_message("slot rows are taller than the slot at height %.0f: %.1f vs %.1f" % [height, widget.get_combined_minimum_size().y, wanted]).is_less_equal(wanted + (0.51 if height >= 720.0 else 4.0))
			assert_bool(Rect2(Vector2.ZERO, vp).encloses(widget.get_global_rect())).override_failure_message("slot %s leaves the %s viewport" % [str(widget.get_global_rect()), str(vp)]).is_true()
			assert_float(widget.size.y).is_greater_equal(widget.get_combined_minimum_size().y - 0.51)
		hud.queue_free()
		sub.queue_free()
	assert_float(float(cfg["slot_size"][1])).is_equal(134.0)


func test_the_dodge_pulse_settings_are_sane_numbers() -> void:
	var cfg: Dictionary = UiConfig.hud()
	for key: String in ["dodge_pulse_duration", "dodge_pulse_grow"]:
		assert_bool(is_finite(float(cfg[key])) and float(cfg[key]) > 0.0).override_failure_message(key).is_true()
	assert_float(float(cfg["dodge_pulse_duration"])).is_less(3.0)
	assert_float(float(UiConfig.damage_numbers()["boss_bar_gap"])).is_greater_equal(0.0)
