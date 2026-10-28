class_name CastMarkersTest
extends GdUnitTestSuite
## Slice 4c: cast ground markers. A lane that shows a hit area must be sized from
## the same data as the hit (VfxSizing).

const SHOT := {"damage": 4, "damage_type": "fire", "speed": 12.0, "max_range": 14.0, "hit_radius": 0.3}


func _world() -> Array:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var caster: Node3D = auto_free(Node3D.new())
	holder.add_child(caster)
	return [EffectPool.for_world(holder), EffectContext.new(caster, holder, "player")]


func test_projectile_lane_is_hit_width_by_max_range() -> void:
	var parts := _world()
	var pool: EffectPool = parts[0]
	TemplateVfx.projectile_lane(pool, Vector3.ZERO, Vector3.FORWARD, float(SHOT["max_range"]), float(SHOT["hit_radius"]),
			ElementVisuals.visual_for_damage_type("fire"))
	assert_int(pool.active_count()).is_equal(1)
	var lane: PooledEffect = pool.get_child(0)
	var aabb := lane.mesh.get_aabb()
	var half_width: float = sqrt(pow(float(SHOT["hit_radius"]) + 0.45, 2.0) - pow(0.45, 2.0))
	assert_float(aabb.size.x * lane.scale.x).is_equal_approx(half_width * 2.0, 0.001)
	assert_float(aabb.size.z * lane.scale.z).is_equal_approx(float(SHOT["max_range"]), 0.001)
	assert_float(VfxSizing.projectile_lane_half_width(0.3)).is_equal_approx(half_width, 0.0001)


func test_lane_points_along_the_cast_direction() -> void:
	var parts := _world()
	var pool: EffectPool = parts[0]
	var direction := Vector3(1.0, 0.0, -1.0).normalized()
	TemplateVfx.projectile_lane(pool, Vector3.ZERO, direction, 10.0, 0.3, {"color": Color.WHITE, "scale": 1.0})
	var lane: PooledEffect = pool.get_child(0)
	var far_end: Vector3 = lane.global_transform * Vector3(0.0, 0.0, -1.0)
	assert_float(far_end.normalized().dot(direction)).is_greater(0.999)


func test_lane_and_dash_path_fade_out_and_free_themselves() -> void:
	var parts := _world()
	var pool: EffectPool = parts[0]
	var look := {"color": Color.WHITE, "scale": 1.0}
	TemplateVfx.projectile_lane(pool, Vector3.ZERO, Vector3.FORWARD, 10.0, 0.3, look)
	TemplateVfx.dash_path(pool, Vector3.ZERO, Vector3.FORWARD, 4.0, look)
	assert_int(pool.active_count()).is_equal(2)
	pool.advance(2.0)
	assert_int(pool.active_count()).is_equal(0)


func test_dash_path_length_is_the_dash_distance() -> void:
	var parts := _world()
	var pool: EffectPool = parts[0]
	TemplateVfx.dash_path(pool, Vector3.ZERO, Vector3.FORWARD, 3.5, {"color": Color.WHITE, "scale": 1.0})
	var path: PooledEffect = pool.get_child(0)
	assert_float(path.mesh.get_aabb().size.z * path.scale.z).is_equal_approx(3.5, 0.001)


func test_player_shot_draws_a_lane_enemy_shot_does_not() -> void:
	var parts := _world()
	var pool: EffectPool = parts[0]
	var context: EffectContext = parts[1]
	EffectTemplates.execute("projectile", SHOT, context)
	var with_player := pool.active_count()
	assert_int(with_player).is_greater(0)
	var enemy_world := _world()
	var enemy_pool: EffectPool = enemy_world[0]
	var enemy_context: EffectContext = enemy_world[1]
	enemy_context.caster_team = "enemy"
	EffectTemplates.execute("projectile", SHOT, enemy_context)
	var lanes_player := 0
	for child in pool.get_children():
		if (child as PooledEffect).strip_length > 0.0:
			lanes_player += 1
	var lanes_enemy := 0
	for child in enemy_pool.get_children():
		if (child as PooledEffect).strip_length > 0.0:
			lanes_enemy += 1
	assert_int(lanes_player).is_equal(1)
	assert_int(lanes_enemy).is_equal(0)


func test_marker_config_validation() -> void:
	assert_array(VfxConfig.validate(VfxConfig.get_config())).is_empty()
	var bad: Dictionary = VfxConfig.get_config().duplicate()
	bad["dash_path_alpha"] = 3.0
	assert_array(VfxConfig.validate(bad)).is_not_empty()
	bad = VfxConfig.get_config().duplicate()
	bad["projectile_lane_duration"] = 0.0
	assert_array(VfxConfig.validate(bad)).is_not_empty()
