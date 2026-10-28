class_name Slice3QaTest
extends GdUnitTestSuite
## qa additions for Slice 3: heavy cooldown modifiers, manual light cap, wedge-vs-hitbox,
## heavy wind-up with dodge and death, dead player ignores clicks, capture-only keys inert.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
## MeleeChaser hurtbox capsule radius (scenes/enemies/MeleeChaser.tscn).
const CHASER_HURTBOX_RADIUS := 0.45

var _fired: Array[StringName] = []


func after_test() -> void:
	Juice.reset()
	Input.action_release("attack_light")
	Input.action_release("attack_heavy")


func _defs() -> Dictionary:
	return {
		&"light": (AttackDatabase.get_attack("light") as Dictionary).duplicate(),
		&"heavy": (AttackDatabase.get_attack("heavy") as Dictionary).duplicate(),
	}


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func _spawn_enemy(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _no_target(_id: StringName) -> bool:
	return false


func _any_target(_id: StringName) -> bool:
	return true


func test_heavy_cooldown_resolves_through_modifier_in_real_timing() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("attack_cooldown.heavy", "haste", StatModifiers.MULTIPLICATIVE, -0.5)
	var controller := AttackController.new(_defs(), mods)
	controller.tick(0.016, true, {&"heavy": true}, _no_target)
	var half := float(_defs()[&"heavy"]["interval"]) * 0.5
	# Not ready at 40% of the base cooldown (would be ready if modifier were ignored: no).
	controller.tick(half * 0.5, true, {}, _no_target)
	assert_bool(controller.is_ready(&"heavy")).is_false()
	controller.tick(half * 0.6, true, {}, _no_target)
	assert_bool(controller.is_ready(&"heavy")).is_true()
	controller.tick(0.016, true, {&"heavy": true}, _no_target)
	assert_bool(controller.is_winding_up(&"heavy")).is_true()


func test_manual_light_spam_is_capped_at_one_and_a_half_times_auto_rate() -> void:
	var controller := AttackController.new(_defs(), StatModifiers.new())
	var count: Array[int] = [0]
	controller.attack_fired.connect(func(id: StringName) -> void:
		if id == &"light":
			count[0] += 1)
	for i in range(600):  # 10 s at 60 Hz, click held every tick
		controller.tick(1.0 / 60.0, true, {&"light": true}, _no_target)
	# 1.5 x the 1.667/s auto rate = 2.5 clicks/s -> about 25 in 10 s.
	assert_int(count[0]).is_less_equal(26)
	assert_int(count[0]).is_greater_equal(23)


func test_cooldown_does_not_bank_while_cannot_act() -> void:
	var controller := AttackController.new(_defs(), StatModifiers.new())
	_fired.clear()
	controller.attack_fired.connect(func(id: StringName) -> void: _fired.append(id))
	controller.tick(10.0, false, {&"light": true, &"heavy": true}, _any_target)
	assert_array(_fired).is_empty()
	controller.tick(0.016, true, {&"light": true}, _any_target)
	assert_array(_fired).is_equal([&"light"])


func test_wedge_mesh_matches_range_and_half_angle_data() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	for attack_id: StringName in [&"light", &"heavy"]:
		var def := main.player.attacks.get_def(attack_id)
		var visual := main.player.get_node("AttackVisual_%s" % attack_id) as AttackArcVisual
		var arrays := visual.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var max_r := 0.0
		var max_angle := 0.0
		for v in verts:
			max_r = maxf(max_r, v.length())
			if v.length() > 0.001:
				max_angle = maxf(max_angle, absf(Vector3(0, 0, -1).angle_to(v)))
		# s3-a (Slice 4a): the wedge is drawn to the effective reach, range + hurtbox radius.
		assert_float(max_r).is_equal_approx(VfxSizing.lateral_reach(float(def["range"])), 0.001)
		assert_float(rad_to_deg(max_angle)).is_equal_approx(float(def["half_angle_degrees"]), 0.01)


func test_hitbox_arc_edge_matches_wedge_arc_edge() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var half := float(main.player.attacks.get_def(&"heavy")["half_angle_degrees"])
	var dist := 1.5
	var inside := _spawn_enemy(main, Vector3(sin(deg_to_rad(half - 4.0)), 0, -cos(deg_to_rad(half - 4.0))) * dist)
	await _frames(2)
	assert_bool(main.player._attack_has_target(&"heavy")).is_true()
	inside.free()
	await _frames(2)
	var outside := _spawn_enemy(main, Vector3(sin(deg_to_rad(half + 4.0)), 0, -cos(deg_to_rad(half + 4.0))) * dist)
	await _frames(2)
	assert_bool(main.player._attack_has_target(&"heavy")).is_false()
	outside.free()


func test_hitbox_radial_reach_exceeds_wedge_by_at_most_hurtbox_radius() -> void:
	# The hit test is a sphere-vs-hurtbox-shape overlap, so a target whose centre is just past
	# the drawn wedge edge can still be hit by up to the hurtbox radius. Pins the known gap.
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var attack_range := float(main.player.attacks.get_def(&"light")["range"])
	var enemy := _spawn_enemy(main, Vector3(0, 0, -(attack_range + CHASER_HURTBOX_RADIUS + 0.15)))
	await _frames(2)
	assert_bool(main.player._attack_has_target(&"light")).is_false()
	enemy.global_position = main.player.global_position + Vector3(0, 0, -(attack_range + CHASER_HURTBOX_RADIUS - 0.1))
	await _frames(2)
	assert_bool(main.player._attack_has_target(&"light")).is_true()


func test_heavy_windup_survives_dodge_and_fires_once_without_error() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	_spawn_enemy(main, Vector3(0, 0, -2.0))
	var heavy_fired: Array[int] = []
	player.attack_fired.connect(func(id: StringName) -> void:
		if id == &"heavy":
			heavy_fired.append(1))
	player.attacks.tick(0.016, true, {&"heavy": true}, _no_target)
	player.start_forced_move(Vector3.RIGHT, 14.0, 0.25, true)
	await _frames(40)
	assert_array(heavy_fired).has_size(1)
	assert_bool(player.is_dead()).is_false()
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_false()


func test_death_mid_windup_never_fires_even_after_many_frames() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	var fired: Array[StringName] = []
	player.attack_fired.connect(func(id: StringName) -> void: fired.append(id))
	player.attacks.tick(0.016, true, {&"heavy": true}, _no_target)
	player.health.take_damage(player.health.get_max_health() * 2.0, "physical")
	await _frames(60)
	assert_array(fired).is_empty()
	assert_bool((player.get_node("AttackVisual_heavy") as Node3D).visible).is_false()


func test_dead_player_clicks_and_auto_do_nothing() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	var enemy := _spawn_enemy(main, Vector3(0, 0, -1.2))
	player.health.take_damage(player.health.get_max_health() * 2.0, "physical")
	var hp := enemy.health.current_health
	Input.action_press("attack_light")
	Input.action_press("attack_heavy")
	await _frames(60)
	Input.action_release("attack_light")
	Input.action_release("attack_heavy")
	await _frames(60)
	assert_float(enemy.health.current_health).is_equal(hp)


func test_capture_only_keys_are_inert_in_normal_play() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	# freeze_aim nulls the camera and heavy_at presses the action; both live only in Scenario.
	assert_object(main.player.camera).is_not_null()
	assert_bool(Input.is_action_pressed("attack_heavy")).is_false()
	for child in main.get_children():
		assert_bool(child is Scenario).is_false()
	assert_bool(Scenario.load_def("hp_bars").has("heavy_at")).is_false()
	assert_bool(Scenario.load_def("hp_bars").has("freeze_aim")).is_false()
	assert_bool(Scenario.load_def("attacks").has("heavy_at")).is_true()


func test_main_ui_does_not_swallow_clicks() -> void:
	# s2-e: every Control in the live Main scene (HUD included) must ignore the mouse.
	var main := _spawn_main()
	await get_tree().process_frame
	var checked := 0
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		# Game Over is modal on purpose. The F3 DebugOverlay Panel is STOP (dev-only, hidden by
		# default); attacks poll Input so it cannot block them. Logged as non-blocking in the review.
		if n is GameOverScreen or n is DebugOverlay:
			continue
		stack.append_array(n.get_children())
		if n is Control:
			checked += 1
			assert_int((n as Control).mouse_filter).override_failure_message("%s swallows clicks" % n.get_path()).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(checked).is_greater(10)
