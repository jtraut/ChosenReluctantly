class_name C1b2CapabilitiesTest
extends GdUnitTestSuite
## C1-b2: the zone template, dash path damage, dash direction_mode, the pass-through buff, the
## placed-skill reticle data (placement), and the dodge fallbacks. Fixtures only; no C1-c cards.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	Juice.reset()
	Engine.time_scale = 1.0
	Enemy.set_player_body_suppressed(false)


# --- helpers ------------------------------------------------------------------------------

func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	# The player's own auto attacks would add hits the tests do not want to count.
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


## A target-less (stationary) enemy at `offset` from the player.
func _enemy_at(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _circle(extra: Dictionary = {}) -> Dictionary:
	var params: Dictionary = {"shape": "circle", "radius": 2.0, "duration": 2.0, "tick_interval": 0.5, "damage": 1.0, "damage_type": "fire", "max_range": 8.0}
	params.merge(extra, true)
	return params


func _line(extra: Dictionary = {}) -> Dictionary:
	var params: Dictionary = {"shape": "line", "length": 6.0, "width": 1.0, "duration": 2.0, "tick_interval": 0.5, "damage": 1.0, "damage_type": "fire", "max_range": 8.0}
	params.merge(extra, true)
	return params


func _context(main: Main, aim: Variant = null) -> EffectContext:
	var context := EffectContext.new(main.player, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 11
	context.aim_point = aim
	context.arena = main.player.get_arena_rect()
	return context


## Casts a zone with the real template and returns its manager, stepping paused (tests drive time).
func _cast_zone(main: Main, params: Dictionary, aim: Variant) -> ZoneManager:
	EffectTemplates.execute("zone", params, _context(main, aim))
	var manager := ZoneManager.for_world(main)
	manager.set_physics_process(false)
	return manager


func _record_kinds(enemy: Enemy) -> Array:
	var kinds: Array = []
	enemy.health.damaged.connect(func(_a: float, _t: String, _k: Vector3) -> void: kinds.append(enemy.health.last_kind))
	return kinds


func _errors(template_id: String, params: Dictionary) -> Array[String]:
	return EffectTemplates.validate_params(template_id, params)


# --- schema: zone ---------------------------------------------------------------------------

func test_valid_zones_pass_and_run_through_the_card_schema() -> void:
	assert_array(_errors("zone", _circle())).is_empty()
	assert_array(_errors("zone", _line({"knockback_strength": 2.0}))).is_empty()
	assert_array(_errors("zone", _circle({"status_id": "burn", "status_duration": 3.0, "status_chance": 0.5}))).is_empty()
	var card: Dictionary = {"id": "x", "name": "X", "flavor_text": "f", "slot_type": "attack_aoe", "pool": "fire", "cooldown_modifier": 0.0,
			"effects": [{"template": "zone", "params": _line()}]}
	assert_array(CardSchema.validate(card)).is_empty()


func test_zone_schema_fails_loud_on_bad_values() -> void:
	var bad: Array[Dictionary] = [
		_circle({"bogus": 1}),
		_circle({"shape": "triangle"}),
		_circle({"radius": 0.0}),
		_circle({"length": 3.0}),
		_line({"radius": 1.0}),
		_circle({"duration": -1.0}),
		_circle({"duration": 99.0}),
		_circle({"tick_interval": 0.0}),
		_circle({"duration": 30.0, "tick_interval": 0.05}),
		_circle({"damage": -1.0}),
		_circle({"damage": 0.0}),
		_circle({"damage_type": ""}),
		_circle({"max_range": 0.0}),
		_circle({"max_range": 500.0}),
		_circle({"status_id": "nope", "status_duration": 2.0}),
		_circle({"status_id": "burn"}),
		_circle({"status_duration": 2.0}),
		_circle({"status_id": "burn", "status_duration": 2.0, "status_chance": 1.5}),
		_circle({"hits": 2, "hit_interval": 0.2}),
		_circle({"knockback_strength": -1.0}),
		_circle({"radius": "big"}),
	]
	for params: Dictionary in bad:
		assert_array(_errors("zone", params)).override_failure_message("should be rejected: %s" % str(params)).is_not_empty()
	var missing := _circle()
	missing.erase("tick_interval")
	var card: Dictionary = {"id": "x", "name": "X", "flavor_text": "f", "slot_type": "attack_aoe", "pool": "fire", "cooldown_modifier": 0.0,
			"effects": [{"template": "zone", "params": missing}]}
	assert_array(CardSchema.validate(card)).is_not_empty()
	var status_only := _circle({"damage": 0.0, "status_id": "burn", "status_duration": 2.0})
	assert_array(_errors("zone", status_only)).is_empty()


func test_zone_config_validates_and_the_shipped_file_loads() -> void:
	assert_array(ZoneConfig.validate({"max_live": 6})).is_empty()
	for bad: Variant in [{"max_live": 0}, {"max_live": 2.5}, {"max_live": 1000}, {"max_live": "6"}, {}, {"max_live": 6, "extra": 1}, "x"]:
		assert_array(ZoneConfig.validate(bad)).override_failure_message(str(bad)).is_not_empty()
	assert_int(ZoneConfig.max_live()).is_equal(6)


func test_tick_count_and_line_geometry() -> void:
	assert_int(ZoneShape.tick_count(4.0, 0.5)).is_equal(8)
	assert_int(ZoneShape.tick_count(2.0, 5.0)).is_equal(1)
	assert_int(ZoneShape.tick_count(1.0, 0.3)).is_equal(4)
	assert_int(ZoneShape.tick_count(0.0, 0.5)).is_equal(0)
	# Cast toward -Z: the wall runs along X. Length 6 reaches 3 + reach on X, width 1 reaches 0.5 + reach on Z.
	var reach: float = VfxConfig.hurtbox_reach_radius()
	assert_bool(ZoneShape.line_contains(Vector3(3.0 + reach - 0.01, 0, 0), Vector3.ZERO, Vector3.FORWARD, 6.0, 1.0)).is_true()
	assert_bool(ZoneShape.line_contains(Vector3(3.0 + reach + 0.01, 0, 0), Vector3.ZERO, Vector3.FORWARD, 6.0, 1.0)).is_false()
	assert_bool(ZoneShape.line_contains(Vector3(0, 0, 0.5 + reach - 0.01), Vector3.ZERO, Vector3.FORWARD, 6.0, 1.0)).is_true()
	assert_bool(ZoneShape.line_contains(Vector3(0, 0, 0.5 + reach + 0.01), Vector3.ZERO, Vector3.FORWARD, 6.0, 1.0)).is_false()
	# Cast toward +X: the wall now runs along Z.
	assert_bool(ZoneShape.line_contains(Vector3(0, 0, 3.0), Vector3.ZERO, Vector3.RIGHT, 6.0, 1.0)).is_true()
	assert_bool(ZoneShape.line_contains(Vector3(3.0, 0, 0), Vector3.ZERO, Vector3.RIGHT, 6.0, 1.0)).is_false()


# --- zone behaviour -------------------------------------------------------------------------

func test_circle_zone_ticks_like_a_dot_and_ends_on_time() -> void:
	var main := _spawn_main()
	var target := _enemy_at(main, Vector3(0, 0, -5))
	await _frames(2)
	var kinds := _record_kinds(target)
	var hp_before: float = target.health.get_current_health()
	var manager := _cast_zone(main, _circle(), target.global_position)
	assert_int(manager.live_count()).is_equal(1)
	assert_int(kinds.size()).override_failure_message("the first tick lands at placement").is_equal(1)
	for i in range(8):
		manager.step(0.25)
	assert_int(manager.live_count()).is_equal(0)
	assert_int(kinds.size()).override_failure_message("2 s at 0.5 s = 4 ticks").is_equal(4)
	for kind: Variant in kinds:
		assert_str(String(kind)).is_equal(String(Health.KIND_DOT))
	assert_float(hp_before - target.health.get_current_health()).is_equal_approx(4.0, 0.001)


func test_zone_ticks_use_juice_number_and_flash_only_no_hit_stop() -> void:
	var main := _spawn_main()
	var target := _enemy_at(main, Vector3(0, 0, -5))
	await _frames(2)
	Juice.reset()
	var popups_before: int = Juice.popup_count
	var manager := _cast_zone(main, _circle(), target.global_position)
	manager.step(0.5)
	assert_float(Engine.time_scale).override_failure_message("a zone tick must not hit-stop").is_equal(1.0)
	assert_int(Juice._hitstop_resume_msec).is_equal(-1)
	assert_bool(target.health.get_current_health() < target.health.get_max_health()).is_true()
	assert_int(Juice.popup_count).is_greater_equal(popups_before)


func test_zone_only_hits_inside_its_radius_and_not_the_caster() -> void:
	var main := _spawn_main()
	var inside := _enemy_at(main, Vector3(0, 0, -5))
	var outside := _enemy_at(main, Vector3(0, 0, -5.0 - 2.0 - VfxSizing.zone_circle_reach(0.0) - 1.0))
	await _frames(2)
	var player_hp: float = main.player.health.get_current_health()
	var manager := _cast_zone(main, _circle(), inside.global_position)
	manager.step(0.1)
	assert_float(inside.health.get_current_health()).is_less(inside.health.get_max_health())
	assert_float(outside.health.get_current_health()).is_equal(outside.health.get_max_health())
	assert_float(main.player.health.get_current_health()).is_equal(player_hp)


func test_line_zone_hits_across_the_wall_and_not_along_or_beyond_its_width() -> void:
	var main := _spawn_main()
	# Aim 6 m ahead (-Z): the wall is centred there and runs along X, 6 long, 1 wide.
	var on_wall := _enemy_at(main, Vector3(2.5, 0, -6))
	var too_far_along := _enemy_at(main, Vector3(4.5, 0, -6))
	var too_deep := _enemy_at(main, Vector3(0, 0, -7.2))
	await _frames(2)
	var manager := _cast_zone(main, _line(), main.player.global_position + Vector3(0, 0, -6))
	manager.step(0.1)
	assert_float(on_wall.health.get_current_health()).is_less(on_wall.health.get_max_health())
	assert_float(too_far_along.health.get_current_health()).is_equal(too_far_along.health.get_max_health())
	assert_float(too_deep.health.get_current_health()).is_equal(too_deep.health.get_max_health())


func test_zone_status_chance_zero_never_and_one_always_applies() -> void:
	var main := _spawn_main()
	var target := _enemy_at(main, Vector3(0, 0, -5))
	await _frames(2)
	var never := _cast_zone(main, _circle({"status_id": "burn", "status_duration": 3.0, "status_chance": 0.0}), target.global_position)
	never.step(0.1)
	assert_bool(target.status_manager.has_status("burn")).is_false()
	never.clear()
	var always := _cast_zone(main, _circle({"status_id": "burn", "status_duration": 3.0, "status_chance": 1.0}), target.global_position)
	always.step(0.1)
	assert_bool(target.status_manager.has_status("burn")).is_true()


func test_zone_status_chance_rolls_on_the_shared_seeded_rng() -> void:
	var main := _spawn_main()
	var target := _enemy_at(main, Vector3(0, 0, -5))
	await _frames(2)
	var context := _context(main, target.global_position)
	var probe := RandomNumberGenerator.new()
	probe.seed = 11
	var expected: bool = probe.randf() < 0.5
	EffectTemplates.execute("zone", _circle({"duration": 0.4, "status_id": "burn", "status_duration": 3.0, "status_chance": 0.5}), context)
	assert_bool(target.status_manager.has_status("burn")).is_equal(expected)


func test_zones_are_capped_pooled_and_recycle_the_oldest() -> void:
	var main := _spawn_main()
	await _frames(1)
	var manager := _cast_zone(main, _circle(), main.player.global_position + Vector3(0, 0, -5))
	var cap: int = manager.max_live
	var started: Array[int] = []
	var ended: Array[int] = []
	manager.zone_started.connect(func(id: int) -> void: started.append(id))
	manager.zone_ended.connect(func(id: int) -> void: ended.append(id))
	for i in range(cap + 3):
		EffectTemplates.execute("zone", _circle({"duration": 20.0}), _context(main, main.player.global_position + Vector3(float(i), 0, -5)))
	assert_int(manager.live_count()).is_equal(cap)
	assert_int(manager.created_count()).is_less_equal(cap)
	assert_int(ended.size()).is_greater_equal(3)
	assert_int(manager.get_child_count()).is_less_equal(cap * 2)  # two meshes per zone, reused
	manager.clear()
	assert_int(manager.live_count()).is_equal(0)
	EffectTemplates.execute("zone", _circle(), _context(main, main.player.global_position + Vector3(0, 0, -5)))
	assert_int(manager.created_count()).is_less_equal(cap)


func test_zone_visual_is_the_hit_area() -> void:
	var main := _spawn_main()
	await _frames(1)
	var manager := _cast_zone(main, _circle({"radius": 2.5}), main.player.global_position + Vector3(0, 0, -5))
	var fill: MeshInstance3D = null
	for child in manager.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh is CylinderMesh:
			fill = child
	assert_object(fill).is_not_null()
	assert_float(fill.scale.x).is_equal_approx(VfxSizing.zone_circle_reach(2.5), 0.0001)
	var entry: Dictionary = manager.live_zones()[0]
	assert_float(float(entry["reach"])).is_equal_approx(VfxSizing.zone_circle_reach(2.5), 0.0001)
	manager.clear()
	var line_manager := _cast_zone(main, _line(), main.player.global_position + Vector3(0, 0, -5))
	var line_entry: Dictionary = line_manager.live_zones()[0]
	assert_float(float(line_entry["half_length"])).is_equal_approx(VfxSizing.zone_line_half_length(6.0), 0.0001)
	assert_float(float(line_entry["half_width"])).is_equal_approx(VfxSizing.zone_line_half_width(1.0), 0.0001)
	assert_float(float(line_entry["remaining_fraction"])).is_equal_approx(1.0, 0.0001)


func test_zone_ends_cleanly_when_the_caster_is_freed_or_dead() -> void:
	var main := _spawn_main()
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(6, 0, 0)
	var target := _enemy_at(main, Vector3(6, 0, -5))
	await _frames(2)
	var context := EffectContext.new(caster, main, "player")
	context.aim_point = target.global_position
	EffectTemplates.execute("zone", _circle({"duration": 10.0}), context)
	var manager := ZoneManager.for_world(main)
	manager.set_physics_process(false)
	assert_int(manager.live_count()).is_equal(1)
	caster.free()
	manager.step(0.5)
	assert_int(manager.live_count()).override_failure_message("a freed caster ends its zone").is_equal(0)
	# A dead caster also ends it.
	var caster2 := TestCaster.new()
	main.add_child(caster2)
	caster2.global_position = main.player.global_position + Vector3(6, 0, 0)
	var context2 := EffectContext.new(caster2, main, "player")
	context2.aim_point = target.global_position
	EffectTemplates.execute("zone", _circle({"duration": 10.0}), context2)
	assert_int(manager.live_count()).is_equal(1)
	caster2.health.take_damage(1000.0)
	manager.step(0.5)
	assert_int(manager.live_count()).is_equal(0)


func test_zone_with_no_manager_or_orphan_caster_is_a_safe_no_op() -> void:
	var orphan: Node3D = auto_free(Node3D.new())
	var context := EffectContext.new(orphan, null, "player")
	EffectTemplates.execute("zone", _circle(), context)
	EffectTemplates.execute("pass_through", {"duration": 1.0}, context)
	assert_object(ZoneManager.for_world(null)).is_null()


func test_zone_goes_away_with_the_world_on_reload() -> void:
	var main := _spawn_main()
	await _frames(1)
	var manager := _cast_zone(main, _circle({"duration": 20.0}), main.player.global_position + Vector3(0, 0, -5))
	assert_int(manager.live_count()).is_equal(1)
	main.free()
	await _frames(2)
	assert_bool(is_instance_valid(manager)).is_false()
	var main2 := _spawn_main()
	await _frames(1)
	assert_object(main2.get_node_or_null("ZoneManager")).is_null()


# --- placement / reticle ----------------------------------------------------------------------

func test_placement_clamps_to_the_range_cap_and_reports_it() -> void:
	var main := _spawn_main()
	await _frames(1)
	var player := main.player
	player.aim_point_override = player.global_position + Vector3(0, 0, -20)
	var far := player.get_placement(8.0)
	assert_bool(bool(far["clamped"])).is_true()
	assert_float(float(far["range"])).is_equal(8.0)
	var point: Vector3 = far["point"]
	assert_float(Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length()).is_equal_approx(8.0, 0.001)
	player.aim_point_override = player.global_position + Vector3(0, 0, -3)
	var near := player.get_placement(8.0)
	assert_bool(bool(near["clamped"])).is_false()
	assert_float(((near["point"] as Vector3) - player.global_position).length()).is_equal_approx(3.0, 0.001)
	player.aim_point_override = null
	var none := player.get_placement(5.0)  # no camera and no override: straight ahead at the cap
	assert_float(((none["point"] as Vector3) - player.global_position).length()).is_equal_approx(5.0, 0.001)


func test_a_zone_cast_lands_at_the_clamped_point() -> void:
	var main := _spawn_main()
	await _frames(1)
	var manager := _cast_zone(main, _circle({"max_range": 6.0}), main.player.global_position + Vector3(0, 0, -40))
	var center: Vector3 = manager.live_zones()[0]["center"]
	assert_float(Vector2(center.x - main.player.global_position.x, center.z - main.player.global_position.z).length()).is_equal_approx(6.0, 0.001)


func test_preview_parts_for_placed_cards_carry_the_cap_and_the_hit_sizes() -> void:
	var config: Dictionary = {"self_ring_enabled": true, "self_ring_radius": 0.9}
	var zone_card: Dictionary = {"effects": [{"template": "zone", "params": _line({"max_range": 7.0})}]}
	var part: Dictionary = CastPreviewShapes.parts_for_card(zone_card, config)[0]
	assert_str(String(part["shape"])).is_equal(CastPreviewShapes.ZONE_LINE)
	assert_bool(bool(part["placed"])).is_true()
	assert_float(float(part["range"])).is_equal(7.0)
	assert_float(float(part["size"])).is_equal_approx(VfxSizing.zone_line_half_length(6.0), 0.0001)
	assert_float(float(part["half_width"])).is_equal_approx(VfxSizing.zone_line_half_width(1.0), 0.0001)
	var circle_part: Dictionary = CastPreviewShapes.parts_for_card({"effects": [{"template": "zone", "params": _circle()}]}, config)[0]
	assert_float(float(circle_part["size"])).is_equal_approx(VfxSizing.zone_circle_reach(2.0), 0.0001)
	var aoe_card: Dictionary = {"effects": [{"template": "aoe", "params": {"damage": 3.0, "damage_type": "fire", "radius": 2.0, "max_range": 9.0}}]}
	var aoe_part: Dictionary = CastPreviewShapes.parts_for_card(aoe_card, config)[0]
	assert_bool(bool(aoe_part["placed"])).is_true()
	assert_float(float(aoe_part["range"])).is_equal(9.0)
	var plain: Dictionary = CastPreviewShapes.parts_for_card({"effects": [{"template": "aoe", "params": {"damage": 3.0, "damage_type": "fire", "radius": 2.0}}]}, config)[0]
	assert_bool(bool(plain["placed"])).is_false()


func test_aoe_with_max_range_hits_at_the_clamped_aim_point() -> void:
	var main := _spawn_main()
	var near_aim := _enemy_at(main, Vector3(0, 0, -6))
	var at_caster := _enemy_at(main, Vector3(0, 0, -1))
	await _frames(2)
	var params: Dictionary = {"damage": 2.0, "damage_type": "fire", "radius": 1.5, "max_range": 6.0}
	EffectTemplates.execute("aoe", params, _context(main, main.player.global_position + Vector3(0, 0, -30)))
	assert_float(near_aim.health.get_current_health()).is_less(near_aim.health.get_max_health())
	assert_float(at_caster.health.get_current_health()).is_equal(at_caster.health.get_max_health())


# --- dash: schema, direction_mode, path damage -------------------------------------------------

func test_dash_schema_accepts_the_new_keys_and_rejects_bad_ones() -> void:
	var base: Dictionary = {"distance": 3.0, "speed": 15.0}
	assert_array(_errors("dash", base)).is_empty()
	assert_array(_errors("dash", {"distance": 3.0, "speed": 15.0, "direction_mode": "away_from_aim", "invulnerable": true})).is_empty()
	assert_array(_errors("dash", {"distance": 3.0, "speed": 15.0, "damage": 4.0, "damage_type": "physical", "hit_radius": 0.6, "knockback_strength": 3.0})).is_empty()
	var bad: Array[Dictionary] = [
		{"distance": 3.0, "speed": 15.0, "direction_mode": "sideways"},
		{"distance": 3.0, "speed": 15.0, "direction_mode": 3},
		{"distance": 3.0, "speed": 15.0, "bogus": 1},
		{"distance": 3.0, "speed": 15.0, "damage": 4.0, "damage_type": "physical"},
		{"distance": 3.0, "speed": 15.0, "damage": 4.0, "hit_radius": 0.6},
		{"distance": 3.0, "speed": 15.0, "damage": 0.0, "damage_type": "physical", "hit_radius": 0.6},
		{"distance": 3.0, "speed": 15.0, "damage": 4.0, "damage_type": "physical", "hit_radius": 0.0},
		{"distance": 3.0, "speed": 15.0, "damage": 4.0, "damage_type": "physical", "hit_radius": 99.0},
		{"distance": 3.0, "speed": 15.0, "hit_radius": 0.6},
		{"distance": 3.0, "speed": 15.0, "knockback_strength": 2.0},
	]
	for params: Dictionary in bad:
		assert_array(_errors("dash", params)).override_failure_message("should be rejected: %s" % str(params)).is_not_empty()


func test_dash_direction_mode_forward_is_the_default_and_away_goes_backwards() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	var facing := player.get_aim_direction()
	var start := player.global_position
	EffectTemplates.execute("dash", {"distance": 3.0, "speed": 15.0}, _context(main))
	await _frames(30)
	var forward_moved := (player.global_position - start).dot(facing)
	assert_float(forward_moved).is_equal_approx(3.0, 0.05)
	start = player.global_position
	EffectTemplates.execute("dash", {"distance": 3.0, "speed": 15.0, "direction_mode": "away_from_aim"}, _context(main))
	await _frames(30)
	assert_float((player.global_position - start).dot(facing)).is_equal_approx(-3.0, 0.05)


func test_dash_path_damage_hits_each_enemy_once_and_only_along_the_path() -> void:
	var main := _spawn_main()
	var on_path_a := _enemy_at(main, Vector3(0, 0, -1.5))
	var on_path_b := _enemy_at(main, Vector3(0.2, 0, -3.0))
	var beside := _enemy_at(main, Vector3(3.0, 0, -2.0))
	var behind := _enemy_at(main, Vector3(0, 0, 3.0))
	await _frames(2)
	var hits: Dictionary = {}
	for enemy: Enemy in [on_path_a, on_path_b, beside, behind]:
		var captured: Enemy = enemy
		hits[captured] = _record_kinds(captured)
	var params: Dictionary = {"distance": 4.0, "speed": 15.0, "damage": 3.0, "damage_type": "physical", "hit_radius": 0.6}
	EffectTemplates.execute("dash", params, _context(main))
	await _frames(40)
	assert_int((hits[on_path_a] as Array).size()).override_failure_message("hit exactly once").is_equal(1)
	assert_int((hits[on_path_b] as Array).size()).is_equal(1)
	assert_int((hits[beside] as Array).size()).is_equal(0)
	assert_int((hits[behind] as Array).size()).is_equal(0)
	assert_str(String((hits[on_path_a] as Array)[0])).is_equal(String(Health.KIND_HIT))
	assert_float(on_path_a.health.get_max_health() - on_path_a.health.get_current_health()).is_equal_approx(3.0, 0.001)
	# A second dash is a new dash: it may hit the same enemy again.
	var player := main.player
	player.global_position = on_path_a.global_position + Vector3(0, 0, 2.0)
	EffectTemplates.execute("dash", params, _context(main))
	await _frames(40)
	assert_int((hits[on_path_a] as Array).size()).is_equal(2)


func test_dash_without_damage_hits_nobody_and_a_fast_dash_does_not_skip_an_enemy() -> void:
	var main := _spawn_main()
	var target := _enemy_at(main, Vector3(0, 0, -3.0))
	await _frames(2)
	var kinds := _record_kinds(target)
	EffectTemplates.execute("dash", {"distance": 4.0, "speed": 15.0}, _context(main))
	await _frames(40)
	assert_int(kinds.size()).is_equal(0)
	main.player.global_position = target.global_position + Vector3(0, 0, 3.5)
	# 120 m/s covers 2 m a tick: the sampling must still find a 0.3 m wide hit sphere.
	EffectTemplates.execute("dash", {"distance": 6.0, "speed": 120.0, "damage": 2.0, "damage_type": "physical", "hit_radius": 0.3}, _context(main))
	await _frames(20)
	assert_int(kinds.size()).is_equal(1)


func test_dash_path_visual_matches_the_swept_hit_area() -> void:
	var config: Dictionary = {}
	var card: Dictionary = {"effects": [{"template": "dash", "params": {"distance": 3.0, "speed": 15.0, "damage": 3.0, "damage_type": "physical", "hit_radius": 0.6, "direction_mode": "away_from_aim"}}]}
	var part: Dictionary = CastPreviewShapes.parts_for_card(card, config)[0]
	assert_float(float(part["half_width"])).is_equal_approx(VfxSizing.dash_path_half_width(0.6), 0.0001)
	assert_float(float(part["size"])).is_equal_approx(VfxSizing.dash_path_length(3.0, 0.6), 0.0001)
	assert_float(float(part["start_offset"])).is_equal_approx(-VfxSizing.lateral_reach(0.6), 0.0001)
	assert_float(float(part["yaw_offset_degrees"])).is_equal(180.0)
	var plain: Dictionary = CastPreviewShapes.parts_for_card({"effects": [{"template": "dash", "params": {"distance": 3.0, "speed": 15.0}}]}, config)[0]
	assert_float(float(plain["size"])).is_equal(3.0)
	assert_float(float(plain["yaw_offset_degrees"])).is_equal(0.0)


func test_card_damage_rule_counts_zone_ticks_and_path_damage() -> void:
	var zone_card: Dictionary = {"effects": [{"template": "zone", "params": _circle({"duration": 4.0, "tick_interval": 0.5, "damage": 2.0})}]}
	assert_float(CardDamageRule.cast_damage(zone_card, {}, 5.0)).is_equal_approx(16.0, 0.001)
	var dash_card: Dictionary = {"effects": [{"template": "dash", "params": {"distance": 3.0, "speed": 15.0, "damage": 5.0, "damage_type": "physical", "hit_radius": 0.6}}]}
	assert_float(CardDamageRule.cast_damage(dash_card, {}, 5.0)).is_equal_approx(5.0, 0.001)


# --- pass-through ---------------------------------------------------------------------------------

func test_pass_through_schema() -> void:
	assert_array(_errors("pass_through", {"duration": 2.0})).is_empty()
	for bad: Dictionary in [{"duration": 0.0}, {"duration": -1.0}, {"duration": 999.0}, {"duration": 2.0, "stat": "x"}, {"duration": "2"}]:
		assert_array(_errors("pass_through", bad)).override_failure_message(str(bad)).is_not_empty()
	var missing: Dictionary = {"id": "x", "name": "X", "flavor_text": "f", "slot_type": "movement", "pool": "neutral", "cooldown_modifier": 0.0,
			"effects": [{"template": "pass_through", "params": {}}]}
	assert_array(CardSchema.validate(missing)).is_not_empty()


func test_pass_through_clears_and_restores_the_body_masks_on_a_fixture_mask() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -5))
	await _frames(2)
	var player := main.player
	# FIXTURE, not shipped behaviour: the shipped scenes have no body-vs-body collision (player mask 1, enemy mask 5, see DECISIONS C1-b2); give both
	# the bits so the buff has something to switch off.
	player.collision_mask |= CollisionLayers.ENEMY_BODY
	enemy.collision_mask |= CollisionLayers.PLAYER_BODY
	enemy._default_collision_mask = enemy.collision_mask
	var player_mask: int = player.collision_mask
	var enemy_mask: int = enemy.collision_mask
	var changes: Array[bool] = []
	player.pass_through_changed.connect(func(active: bool) -> void: changes.append(active))
	EffectTemplates.execute("pass_through", {"duration": 0.2}, _context(main))
	assert_bool(player.is_pass_through()).is_true()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(0)
	assert_int(enemy.collision_mask & CollisionLayers.PLAYER_BODY).is_equal(0)
	assert_int(player.collision_mask & CollisionLayers.WORLD).is_equal(CollisionLayers.WORLD)  # the world still blocks
	await _frames(20)
	assert_bool(player.is_pass_through()).is_false()
	assert_int(player.collision_mask).is_equal(player_mask)
	assert_int(enemy.collision_mask).is_equal(enemy_mask)
	assert_array(changes).is_equal([true, false])


func test_pass_through_overlapping_grants_end_with_the_last_and_new_enemies_join() -> void:
	var main := _spawn_main()
	await _frames(1)
	var player := main.player
	player.grant_pass_through(0.1)
	player.grant_pass_through(0.4)
	await _frames(12)
	assert_bool(player.is_pass_through()).override_failure_message("still held by the longer grant").is_true()
	var late := _enemy_at(main, Vector3(0, 0, -5))
	assert_bool(Enemy.is_player_body_suppressed()).is_true()
	assert_int(late.collision_mask & CollisionLayers.PLAYER_BODY).is_equal(0)
	await _frames(40)
	assert_bool(player.is_pass_through()).is_false()
	assert_bool(Enemy.is_player_body_suppressed()).is_false()


func test_pass_through_really_lets_the_body_through_an_enemy() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -2.0))
	await _frames(2)
	var player := main.player
	player.collision_mask |= CollisionLayers.ENEMY_BODY  # make enemies solid for the player
	var start := player.global_position
	var facing := player.get_aim_direction()
	player.start_forced_move(facing, 15.0, 0.4)
	await _frames(40)
	var blocked := (player.global_position - start).dot(facing)
	assert_float(blocked).override_failure_message("a solid enemy stops the dash short").is_less(5.0)
	player.global_position = start
	player.grant_pass_through(1.0)
	player.start_forced_move(facing, 15.0, 0.4)
	await _frames(40)
	assert_float((player.global_position - start).dot(facing)).is_equal_approx(6.0, 0.1)
	assert_bool(is_instance_valid(enemy)).is_true()


func test_pass_through_is_restored_on_death_and_on_reload() -> void:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	player.collision_mask |= CollisionLayers.ENEMY_BODY
	player.grant_pass_through(30.0)
	assert_bool(player.is_pass_through()).is_true()
	player.health.take_damage(10000.0)
	assert_bool(player.is_pass_through()).is_false()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(CollisionLayers.ENEMY_BODY)
	assert_bool(Enemy.is_player_body_suppressed()).is_false()
	player.grant_pass_through(5.0)  # a dead player takes no buffs
	assert_bool(player.is_pass_through()).is_false()
	# Reload: the player leaves the tree mid-buff; the static enemy flag must not leak into the next scene.
	var main2 := _spawn_main()
	await _frames(2)
	main2.player.grant_pass_through(30.0)
	assert_bool(Enemy.is_player_body_suppressed()).is_true()
	main2.free()
	await _frames(2)
	assert_bool(Enemy.is_player_body_suppressed()).is_false()


# --- dodge fallbacks --------------------------------------------------------------------------------

func test_dodge_fallbacks_match_the_data_file() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/player.json"))
	var shipped: Dictionary = data["dodge"]
	assert_float(float(PlayerConfig.DEFAULTS["dodge"]["speed"])).is_equal(float(shipped["speed"]))
	assert_float(float(PlayerConfig.DEFAULTS["dodge"]["speed"])).is_equal(20.0)
	var bare: Player = auto_free(Player.new())
	assert_float(bare.dodge_speed).is_equal(float(shipped["speed"]))
	for key: String in shipped.keys():
		assert_float(float(PlayerConfig.DEFAULTS["dodge"][key])).override_failure_message(key).is_equal(float(shipped[key]))


# --- Game Over timing (qa C1-t note on Main.gd) -------------------------------------------------------

## Death from a physics tick (the usual case: an enemy hit) starts the slow-mo and the Game Over wait in
## the same engine iteration. The wait must still be the full real-time beat, not shortened by the time-scale change.
func test_game_over_waits_the_whole_death_beat_in_real_time() -> void:
	var main := _spawn_main()
	await _frames(2)
	var beat_seconds: float = UiConfig.death_beat()["slow_mo_duration"]
	var announced: Array[bool] = [false]
	main.game_over_ready.connect(func() -> void: announced[0] = true)
	var start_msec: int = Time.get_ticks_msec()
	main.player.health.take_damage(10000.0)
	while not announced[0] and Time.get_ticks_msec() - start_msec < int(beat_seconds * 1000.0) + 3000:
		await get_tree().process_frame
	var waited_msec: int = Time.get_ticks_msec() - start_msec
	assert_bool(announced[0]).is_true()
	assert_int(waited_msec).override_failure_message("Game Over came after %d ms, the beat is %d ms" % [waited_msec, int(beat_seconds * 1000.0)]).is_greater_equal(int(beat_seconds * 1000.0) - 30)


func test_a_pause_during_the_death_beat_holds_game_over() -> void:
	var main := _spawn_main()
	await _frames(2)
	var announced: Array[bool] = [false]
	main.game_over_ready.connect(func() -> void: announced[0] = true)
	main.player.health.take_damage(10000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = true
	await TestClock.wait_real(get_tree(), float(UiConfig.death_beat()["slow_mo_duration"]) + 0.3)
	assert_bool(announced[0]).override_failure_message("Game Over must not appear while paused").is_false()
	get_tree().paused = false
