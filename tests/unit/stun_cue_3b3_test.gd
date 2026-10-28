class_name StunCue3b3Test
extends GdUnitTestSuite
## Slice 3b-3 (ux): the stunned cue (stars + tint, both from data), the quiet IMMUNE
## popup, and the targeted_aoe telegraph that grows with the wind-up.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	Juice.reset()
	Input.action_release("attack_heavy")


func _stun_def() -> Dictionary:
	return (StatusDatabase.get_status("stun") as Dictionary).duplicate(true)


func _world() -> Node3D:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	return holder


func _stunned_dummy(world: Node3D) -> Array:
	var body := Node3D.new()
	world.add_child(body)
	var manager := StatusEffectManager.new()
	body.add_child(manager)
	return [body, manager]


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


# --- data ------------------------------------------------------------------

func test_stun_visual_is_stars_with_tint_from_data_and_validates() -> void:
	var visual: Dictionary = _stun_def()["visual"]
	assert_str(String(visual["kind"])).is_equal("stars")
	assert_int(int(visual["count"])).is_greater_equal(3)
	assert_array(StatusDatabase.validate_entry(_stun_def())).is_empty()
	var tint := StatusDatabase.body_tint("stun")
	assert_float(float(tint["amount"])).is_greater(0.0)
	# Burn has no tint.
	assert_dict(StatusDatabase.body_tint("burn")).is_empty()
	assert_dict(StatusDatabase.body_tint("nope")).is_empty()


func test_stars_visual_validation_rejects_bad_values() -> void:
	var cases: Array[Dictionary] = [
		{"count": 0}, {"count": 99}, {"count": "x"}, {"orbit_radius": 0.0}, {"orbit_hz": -1.0},
		{"tint_amount": 1.5}, {"tint_color": "nope"},
	]
	for patch in cases:
		var entry := _stun_def()
		(entry["visual"] as Dictionary).merge(patch, true)
		assert_array(StatusDatabase.validate_entry(entry)).override_failure_message("should reject %s" % str(patch)).is_not_empty()
	# Tint needs both halves.
	var half := _stun_def()
	(half["visual"] as Dictionary).erase("tint_amount")
	assert_array(StatusDatabase.validate_entry(half)).is_not_empty()
	# The old halo kind is gone.
	var halo := _stun_def()
	(halo["visual"] as Dictionary)["kind"] = "halo"
	assert_array(StatusDatabase.validate_entry(halo)).is_not_empty()


func test_popup_config_validates() -> void:
	assert_array(UiConfig.validate_popups(UiConfig.popups())).is_empty()
	assert_array(UiConfig.validate_popups({"immune_text": "", "immune_color": "#fff", "immune_scale": 1, "immune_height": 1, "immune_cooldown": 1})).is_not_empty()
	assert_array(UiConfig.validate_popups({"immune_text": "x", "immune_color": "zzz", "immune_scale": 1, "immune_height": 1, "immune_cooldown": 1})).is_not_empty()
	assert_array(UiConfig.validate_popups({"immune_text": "x", "immune_color": "#fff", "immune_scale": -1, "immune_height": 1, "immune_cooldown": 1})).is_not_empty()


# --- stars -------------------------------------------------------------------

func test_stars_start_with_the_stun_stay_on_refresh_and_end_with_it() -> void:
	var world := _world()
	var parts := _stunned_dummy(world)
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	var count := int((_stun_def()["visual"] as Dictionary)["count"])
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(pool.active_count()).is_equal(count)
	manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(pool.active_count()).is_equal(count)
	manager._process(0.7)
	assert_bool(manager.is_stunned()).is_false()
	assert_int(pool.active_count()).is_equal(0)


func test_stars_circle_the_head_at_the_orbit_radius_and_move() -> void:
	var world := _world()
	var parts := _stunned_dummy(world)
	var body: Node3D = parts[0]
	body.global_position = Vector3(3.0, 0.0, -2.0)
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("stun", _stun_def(), 5.0)
	var radius := float((_stun_def()["visual"] as Dictionary)["orbit_radius"])
	var star: PooledEffect = pool.get_child(0)
	pool.advance(0.05)
	var first := star.position
	var flat := Vector2(first.x - body.global_position.x, first.z - body.global_position.z)
	assert_float(flat.length()).is_equal_approx(radius, 0.001)
	pool.advance(0.2)
	assert_float(star.position.distance_to(first)).is_greater(0.1)
	# Still the same distance from the head after moving: it circles, it does not drift.
	flat = Vector2(star.position.x - body.global_position.x, star.position.z - body.global_position.z)
	assert_float(flat.length()).is_equal_approx(radius, 0.001)


func test_stars_end_when_the_enemy_is_freed_mid_stun() -> void:
	var world := _world()
	var parts := _stunned_dummy(world)
	var body: Node3D = parts[0]
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("stun", _stun_def(), 5.0)
	assert_int(pool.active_count()).is_greater(0)
	body.free()
	pool.advance(0.05)
	assert_int(pool.active_count()).is_equal(0)


# --- tint ---------------------------------------------------------------------

func test_stunned_enemy_tints_from_data_and_restores() -> void:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	add_child(enemy)
	auto_free(enemy)
	await _frames(2)
	var base: Color = enemy._base_color
	var tint := StatusDatabase.body_tint("stun")
	var expected: Color = base.lerp(tint["color"], float(tint["amount"]))
	enemy.status_manager.apply_status("stun", _stun_def(), 0.3)
	var material := enemy.body_mesh.material_override as StandardMaterial3D
	assert_bool(material.albedo_color.is_equal_approx(expected)).is_true()
	assert_bool(material.albedo_color.is_equal_approx(base)).is_false()
	await _frames(40)
	assert_bool(enemy.is_stunned()).is_false()
	assert_bool(material.albedo_color.is_equal_approx(base)).is_true()


# --- IMMUNE popup ---------------------------------------------------------------

func test_immune_popup_shows_once_then_stays_quiet_until_the_cooldown() -> void:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	add_child(enemy)
	auto_free(enemy)
	await _frames(2)
	enemy.target = null
	enemy.status_manager.rank = "boss"
	var before := Juice.popup_count
	for i in range(5):
		enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(Juice.popup_count - before).is_equal(1)
	assert_str(Juice.last_popup_text).is_equal(String(UiConfig.popups()["immune_text"]))
	# Cooldown passes: it may speak again.
	enemy._physics_process(float(UiConfig.popups()["immune_cooldown"]) + 0.1)
	enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(Juice.popup_count - before).is_equal(2)
	assert_bool(enemy.is_stunned()).is_false()


func test_a_stun_that_lands_shows_no_immune_popup() -> void:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	add_child(enemy)
	auto_free(enemy)
	await _frames(2)
	enemy.target = null
	var before := Juice.popup_count
	enemy.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(Juice.popup_count - before).is_equal(0)


# --- targeted_aoe telegraph -------------------------------------------------------

func test_aoe_telegraph_grows_with_progress_but_the_edge_stays_at_the_hitbox() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	var reach := VfxSizing.aoe_reach(2.0)
	var effects := TemplateVfx.aoe_telegraph(pool, Vector3(1.0, 0.0, -4.0), reach, Color.html("#8a6bff"))
	assert_int(effects.size()).is_equal(3)
	var fill := effects[0]
	var edge := effects[1]
	var front := effects[2]
	# Elapsed time does not move a driven telegraph.
	pool.advance(5.0)
	assert_float(fill.scale.x).is_equal_approx(reach * TemplateVfx.AOE_TELEGRAPH_START, 0.0001)
	TemplateVfx.set_aoe_telegraph_progress(effects, 0.5)
	assert_float(fill.scale.x).is_equal_approx(reach * lerpf(TemplateVfx.AOE_TELEGRAPH_START, 1.0, 0.5), 0.0001)
	assert_float(front.scale.x).is_equal_approx(fill.scale.x, 0.0001)
	var half_fill_alpha := fill.material.albedo_color.a
	TemplateVfx.set_aoe_telegraph_progress(effects, 1.0)
	assert_float(fill.scale.x).is_equal_approx(reach, 0.0001)
	assert_float(fill.material.albedo_color.a).is_greater(half_fill_alpha)
	# The outline never changes size: it is the hit edge.
	for p: float in [0.0, 0.3, 1.0]:
		TemplateVfx.set_aoe_telegraph_progress(effects, p)
		assert_float(edge.scale.x).is_equal_approx(reach, 0.0001)
	assert_float(edge.base_size).is_equal_approx(reach, 0.0001)


func test_wizard_telegraph_follows_the_wind_up_and_ends_at_the_hit_reach() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	await _frames(2)
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	player.use_heavy_class("wizard")
	var def := player.attacks.get_def(&"heavy")
	player.aim_point_override = player.global_position + Vector3(0.0, 0.0, -5.0)
	var reach := VfxSizing.aoe_reach(float(def["radius"]))
	Input.action_press("attack_heavy")
	await _frames(3)
	Input.action_release("attack_heavy")
	var telegraph: Array = player._telegraphs[&"heavy"]
	var fill := telegraph[0] as PooledEffect
	var early := fill.scale.x
	assert_float(early).is_less(reach)
	await _frames(20)
	assert_float(fill.scale.x).is_greater(early)
	assert_float((telegraph[1] as PooledEffect).scale.x).is_equal_approx(reach, 0.0001)
	# The edge ring is exactly the locked target, and the telegraph is gone after the swing.
	await _frames(60)
	assert_bool(player._telegraphs.has(&"heavy")).is_false()
