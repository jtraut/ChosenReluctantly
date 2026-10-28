class_name TemplateVfxTest
extends GdUnitTestSuite
## Slice 4b: template visuals through the pool. Burn flame lifecycle, pool cap
## under mixed template casts, recycled-handle safety, and sizing of staged parts.

const BURN_DEF := {
	"effect_type": "damage_over_time",
	"damage_per_tick": 2.0,
	"damage_type": "fire",
	"tick_interval": 1.0,
	"visual": {"kind": "flame", "size": 0.3},
}


func _world() -> Node3D:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	return holder


func _burning_enemy(world: Node3D) -> Array:
	var enemy := Node3D.new()
	world.add_child(enemy)
	var manager := StatusEffectManager.new()
	enemy.add_child(manager)
	return [enemy, manager]


func test_burn_flame_starts_once_and_refresh_does_not_double_it() -> void:
	var world := _world()
	var parts := _burning_enemy(world)
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("burn", BURN_DEF, 4.0)
	assert_int(pool.active_count()).is_equal(1)
	manager.apply_status("burn", BURN_DEF, 4.0)
	assert_int(pool.active_count()).is_equal(1)


func test_burn_flame_survives_longer_than_any_fixed_effect_and_is_orange() -> void:
	var world := _world()
	var parts := _burning_enemy(world)
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("burn", BURN_DEF, 20.0)
	for i in range(100):
		pool.advance(0.1)
	assert_int(pool.active_count()).is_equal(1)
	var flame: PooledEffect = pool.get_child(0)
	assert_bool(flame.visible).is_true()
	assert_float(flame.color.r).is_greater(0.9)


func test_burn_flame_is_removed_when_the_status_expires() -> void:
	var world := _world()
	var parts := _burning_enemy(world)
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("burn", BURN_DEF, 1.0)
	manager._process(0.6)
	assert_int(pool.active_count()).is_equal(1)
	manager._process(0.6)
	assert_bool(manager.has_status("burn")).is_false()
	assert_int(pool.active_count()).is_equal(0)
	assert_int(pool.free_count()).is_equal(1)


func test_burn_flame_ends_when_the_enemy_is_freed_mid_status() -> void:
	var world := _world()
	var parts := _burning_enemy(world)
	var enemy: Node3D = parts[0]
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("burn", BURN_DEF, 8.0)
	assert_int(pool.active_count()).is_equal(1)
	enemy.free()
	pool.advance(0.016)
	pool.advance(0.016)
	assert_int(pool.active_count()).is_equal(0)
	assert_bool(pool.get_child(0).visible).is_false()


func test_burn_flame_ends_when_the_enemy_is_queue_freed_like_a_death() -> void:
	var world := _world()
	var parts := _burning_enemy(world)
	var enemy: Node3D = parts[0]
	var manager: StatusEffectManager = parts[1]
	var pool := EffectPool.for_world(world)
	manager.apply_status("burn", BURN_DEF, 8.0)
	enemy.queue_free()
	await await_idle_frame()
	await await_idle_frame()
	pool.advance(0.016)
	assert_int(pool.active_count()).is_equal(0)


func test_flame_is_not_evicted_by_bursts_at_the_cap() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	pool.max_effects = 4
	var parts := _burning_enemy(world)
	var manager: StatusEffectManager = parts[1]
	manager.apply_status("burn", BURN_DEF, 8.0)
	for i in range(40):
		pool.advance(0.05)
		pool.play(EffectPool.Shape.SPHERE, Vector3.ZERO, 1.0, Color.WHITE, 0.5)
	assert_bool(manager._flames.has("burn")).is_true()
	assert_bool(pool.is_running(manager._flames["burn"], int(manager._flame_generations["burn"]))).is_true()
	assert_int(pool.created_count()).is_less_equal(4)


func test_stale_handle_cannot_stop_a_recycled_effect() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	pool.max_effects = 1
	var first := pool.play(EffectPool.Shape.SPHERE, Vector3.ZERO, 1.0, Color.WHITE, 5.0)
	var old_generation: int = first.generation
	var second := pool.play(EffectPool.Shape.SPHERE, Vector3.ZERO, 1.0, Color.WHITE, 5.0)
	assert_object(second).is_same(first)
	pool.stop(first, old_generation)
	assert_int(pool.active_count()).is_equal(1)
	pool.stop(second, second.generation)
	assert_int(pool.active_count()).is_equal(0)


func test_delayed_effect_is_hidden_until_its_delay_passes() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	var effect := pool.play(EffectPool.Shape.SPHERE, Vector3.ZERO, 1.0, Color.WHITE, 0.2).delayed(0.1)
	assert_bool(effect.visible).is_false()
	pool.advance(0.05)
	assert_bool(effect.visible).is_false()
	pool.advance(0.1)
	assert_bool(effect.visible).is_true()
	pool.advance(0.2)
	assert_int(pool.active_count()).is_equal(0)


func test_mixed_template_casts_stay_within_the_cap_and_do_not_leak() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	pool.max_effects = 20
	var look := ElementVisuals.visual_for_damage_type("fire")
	for i in range(300):
		TemplateVfx.cone_sweep(pool, Vector3.ZERO, 0.0, 2.0, 50.0, look["color"])
		TemplateVfx.aoe(pool, Vector3.ZERO, 3.0, look)
		TemplateVfx.heal(pool, Vector3.ZERO)
		TemplateVfx.buff(pool, Vector3.ZERO)
		TemplateVfx.dash_start(pool, Vector3.ZERO, look)
		TemplateVfx.dash_trail(pool, Vector3.ZERO, look)
		TemplateVfx.dash_end(pool, Vector3.ZERO, look)
		TemplateVfx.projectile_muzzle(pool, Vector3.ZERO, look)
		TemplateVfx.projectile_trail_puff(pool, Vector3.ZERO, 0.3, look)
		TemplateVfx.projectile_impact(pool, Vector3.ZERO, look)
		pool.advance(0.05)
		assert_int(pool.active_count()).is_less_equal(20)
	assert_int(pool.created_count()).is_less_equal(20)
	assert_int(pool.get_child_count()).is_less_equal(20)
	for i in range(40):
		pool.advance(0.1)
	assert_int(pool.active_count()).is_equal(0)


func test_template_vfx_with_no_pool_is_a_no_op() -> void:
	var look := ElementVisuals.visual_for_damage_type("fire")
	TemplateVfx.aoe(null, Vector3.ZERO, 3.0, look)
	TemplateVfx.heal(null, Vector3.ZERO)
	TemplateVfx.buff(null, Vector3.ZERO)
	TemplateVfx.cone_sweep(null, Vector3.ZERO, 0.0, 2.0, 50.0, Color.WHITE)
	assert_object(TemplateVfx.status_flame(null, null, look, 0.3)).is_null()


func test_aoe_ring_expands_to_exactly_the_hit_reach() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	var reach: float = VfxSizing.aoe_reach(2.5)
	TemplateVfx.aoe(pool, Vector3.ZERO, reach, ElementVisuals.visual_for_damage_type("fire"))
	var ring: PooledEffect = null
	for child in pool.get_children():
		if (child as PooledEffect).mesh == EffectPool.ring_mesh():
			ring = child
	assert_object(ring).is_not_null()
	assert_float(ring.base_size * ring.scale_to).is_equal_approx(reach, 0.0001)


func test_cone_sweep_blade_stays_inside_the_true_wedge() -> void:
	var world := _world()
	var pool := EffectPool.for_world(world)
	var reach: float = VfxSizing.cone_reach(1.8)
	TemplateVfx.cone_sweep(pool, Vector3.ZERO, 0.0, reach, 45.0, Color.WHITE)
	assert_int(pool.active_count()).is_equal(2)
	for child in pool.get_children():
		var effect := child as PooledEffect
		assert_float(effect.base_size).is_equal_approx(reach, 0.0001)
		assert_float(maxf(effect.scale_from, effect.scale_to)).is_equal_approx(1.0, 0.0001)
		# Blade: swing centre plus its own half angle (10 degrees) never passes the cone half angle.
		if not is_equal_approx(effect.yaw_from, effect.yaw_to):
			assert_float(absf(effect.yaw_from) + deg_to_rad(10.0)).is_less_equal(deg_to_rad(45.0) + 0.0001)


func test_heal_sparkles_only_when_actually_hurt() -> void:
	var world := _world()
	var caster := Node3D.new()
	caster.name = "Caster"
	world.add_child(caster)
	var health := Health.new()
	health.name = "Health"
	health.max_health = 50.0
	caster.add_child(health)
	var context := EffectContext.new(caster, world, "player")
	var pool := EffectPool.for_world(world)
	EffectTemplates.execute("heal", {"amount": 10.0}, context)
	assert_int(pool.active_count()).is_equal(0)
	health.take_damage(20.0)
	EffectTemplates.execute("heal", {"amount": 10.0}, context)
	assert_int(pool.active_count()).is_greater(0)


func test_projectile_recolor_is_per_projectile_not_shared() -> void:
	var scene: PackedScene = load(EffectTemplates.PROJECTILE_SCENE_PATH)
	var fire_shot: Projectile = auto_free(scene.instantiate())
	var plain_shot: Projectile = auto_free(scene.instantiate())
	var world := _world()
	world.add_child(fire_shot)
	world.add_child(plain_shot)
	fire_shot.set_look(ElementVisuals.visual_for_damage_type("fire"))
	plain_shot.set_look(ElementVisuals.visual_for_damage_type("physical"))
	var fire_material := (fire_shot.get_node("Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	var plain_material := (plain_shot.get_node("Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	assert_object(fire_material).is_not_same(plain_material)
	assert_float(fire_material.albedo_color.r).is_greater(0.9)
	assert_bool(fire_material.albedo_color.is_equal_approx(plain_material.albedo_color)).is_false()
	# Same color shares one material (no per-cast allocation).
	var another: Projectile = auto_free(scene.instantiate())
	world.add_child(another)
	another.set_look(ElementVisuals.visual_for_damage_type("fire"))
	assert_object((another.get_node("Mesh") as MeshInstance3D).material_override).is_same(fire_material)


func test_flying_projectile_emits_muzzle_trail_and_impact_within_cap() -> void:
	var scene: PackedScene = load(EffectTemplates.PROJECTILE_SCENE_PATH)
	var world := _world()
	var shot: Projectile = scene.instantiate()
	world.add_child(shot)
	shot.set_look(ElementVisuals.visual_for_damage_type("fire"))
	shot.launch(Vector3.ZERO, Vector3.FORWARD, 5.0, "fire", 10.0, 6.0, "player")
	var pool := EffectPool.for_world(world)
	assert_int(pool.active_count()).is_equal(1)  # muzzle flash
	var peak: int = 0
	for i in range(80):
		if not is_instance_valid(shot):
			break
		shot._physics_process(0.016)
		pool.advance(0.016)
		peak = maxi(peak, pool.active_count())
	assert_int(peak).is_greater(1)
	assert_int(peak).is_less_equal(pool.max_effects)


func test_vfx_config_validates_template_colors() -> void:
	assert_array(VfxConfig.validate({"max_simultaneous": 64, "hurtbox_reach_radius": 0.45, "heal_color": "#7dff9a", "buff_color": "#ffd24a"})).is_empty()
	assert_array(VfxConfig.validate({"max_simultaneous": 64, "hurtbox_reach_radius": 0.45, "heal_color": "not a color"})).is_not_empty()
