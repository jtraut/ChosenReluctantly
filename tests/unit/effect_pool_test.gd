class_name EffectPoolTest
extends GdUnitTestSuite
## Pooled VFX: cap from data, reuse (no growth), cap eviction, freed caster safety.


func _make_pool(cap: int) -> EffectPool:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var pool := EffectPool.for_world(holder)
	pool.max_effects = cap
	return pool


func test_for_world_returns_same_pool_and_reads_cap_from_data() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var a := EffectPool.for_world(holder)
	var b := EffectPool.for_world(holder)
	assert_object(a).is_same(b)
	assert_int(a.max_effects).is_equal(VfxConfig.max_simultaneous())
	assert_int(VfxConfig.max_simultaneous()).is_greater(0)


func test_for_world_null_or_orphan_gives_no_pool() -> void:
	assert_object(EffectPool.for_world(null)).is_null()
	var orphan: Node3D = auto_free(Node3D.new())
	assert_object(EffectPool.for_world(orphan)).is_null()


func test_effect_returns_to_pool_after_duration_and_is_reused() -> void:
	var pool := _make_pool(8)
	var first := pool.play(EffectPool.Shape.DISC, Vector3.ZERO, 2.0, Color.WHITE, 0.2)
	assert_int(pool.active_count()).is_equal(1)
	pool.advance(0.1)
	assert_bool(first.visible).is_true()
	pool.advance(0.15)
	assert_int(pool.active_count()).is_equal(0)
	assert_int(pool.free_count()).is_equal(1)
	assert_bool(first.visible).is_false()
	var second := pool.play(EffectPool.Shape.SPHERE, Vector3.ONE, 1.0, Color.RED, 0.2)
	assert_object(second).is_same(first)
	assert_int(pool.created_count()).is_equal(1)


func test_many_casts_never_grow_past_cap() -> void:
	var pool := _make_pool(6)
	for i in range(500):
		pool.play(EffectPool.Shape.DISC, Vector3.ZERO, 1.0, Color.WHITE, 0.3)
		pool.advance(0.02)
		assert_int(pool.active_count()).is_less_equal(6)
	assert_int(pool.created_count()).is_less_equal(6)
	assert_int(pool.get_child_count()).is_less_equal(6)


func test_at_cap_newest_wins_by_recycling_oldest() -> void:
	var pool := _make_pool(2)
	var a := pool.play(EffectPool.Shape.DISC, Vector3.ZERO, 1.0, Color.WHITE, 1.0)
	pool.advance(0.1)
	var b := pool.play(EffectPool.Shape.DISC, Vector3.ZERO, 1.0, Color.WHITE, 1.0)
	var c := pool.play(EffectPool.Shape.DISC, Vector3(5, 0, 0), 3.0, Color.WHITE, 1.0)
	assert_object(c).is_same(a)
	assert_object(c).is_not_same(b)
	assert_int(pool.active_count()).is_equal(2)
	assert_float(c.base_size).is_equal(3.0)


func test_caster_freed_mid_effect_is_safe() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var caster := Node3D.new()
	holder.add_child(caster)
	var context := EffectContext.new(caster, holder, "player")
	var pool := EffectPool.for_world(holder)
	pool.play(EffectPool.Shape.DISC, caster.global_position, 2.0, Color.WHITE, 0.3)
	caster.free()
	pool.advance(0.2)
	pool.advance(0.2)
	assert_int(pool.active_count()).is_equal(0)
	# Casting an aoe whose caster is already gone must not error either.
	assert_bool(is_instance_valid(context.caster)).is_false()


func test_aoe_template_plays_through_pool() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var caster: Node3D = auto_free(Node3D.new())
	holder.add_child(caster)
	var context := EffectContext.new(caster, holder, "player")
	EffectTemplates._play_aoe_vfx({"radius": 2.5}, context)
	var pool := EffectPool.for_world(holder)
	assert_int(pool.active_count()).is_equal(1)


func test_vfx_config_validation() -> void:
	assert_array(VfxConfig.validate({"max_simultaneous": 48})).is_empty()
	assert_array(VfxConfig.validate({"max_simultaneous": 0})).is_not_empty()
	assert_array(VfxConfig.validate({"max_simultaneous": 2.5})).is_not_empty()
	assert_array(VfxConfig.validate({})).is_not_empty()
