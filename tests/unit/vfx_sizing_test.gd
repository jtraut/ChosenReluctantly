class_name VfxSizingTest
extends GdUnitTestSuite
## A visual must never lie about its hit area: cone, aoe and projectile visuals
## are sized from the same data the hit uses (VfxSizing).

const CONE_PARAMS := {"damage": 5, "damage_type": "physical", "range": 1.8, "half_angle_degrees": 45}
const AOE_PARAMS := {"damage": 5, "damage_type": "fire", "radius": 2.5}


func _pool_and_context() -> Array:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var caster: Node3D = auto_free(Node3D.new())
	holder.add_child(caster)
	return [EffectPool.for_world(holder), EffectContext.new(caster, holder, "player")]


func test_reach_padding_matches_the_enemy_hurtbox_radius() -> void:
	var scene: PackedScene = load("res://scenes/enemies/MeleeChaser.tscn")
	var enemy: Node = auto_free(scene.instantiate())
	var shape_node: CollisionShape3D = enemy.get_node("Hurtbox/HurtboxShape")
	var capsule := shape_node.shape as CapsuleShape3D
	assert_float(VfxConfig.hurtbox_reach_radius()).is_equal_approx(capsule.radius, 0.0001)


func test_cone_visual_size_equals_hit_size() -> void:
	var parts := _pool_and_context()
	var pool: EffectPool = parts[0]
	var context: EffectContext = parts[1]
	EffectTemplates._play_cone_vfx(CONE_PARAMS, context, Vector3.FORWARD)
	assert_int(pool.active_count()).is_equal(2)  # true-shape wedge + sweeping blade
	var wedge: PooledEffect = pool.get_child(0)
	var aabb := wedge.mesh.get_aabb()
	var reach: float = -aabb.position.z * wedge.scale.z
	var hit_reach: float = float(CONE_PARAMS["range"]) + VfxConfig.hurtbox_reach_radius()
	assert_float(reach).is_equal_approx(hit_reach, 0.001)
	var half: float = deg_to_rad(float(CONE_PARAMS["half_angle_degrees"]))
	assert_float(aabb.size.x * wedge.scale.x).is_equal_approx(2.0 * hit_reach * sin(half), 0.001)


func test_cone_wedge_faces_the_caster_forward() -> void:
	var parts := _pool_and_context()
	var pool: EffectPool = parts[0]
	var context: EffectContext = parts[1]
	var forward := Vector3(1, 0, 0)
	EffectTemplates._play_cone_vfx(CONE_PARAMS, context, forward)
	var wedge: PooledEffect = pool.get_child(0)
	var local_forward: Vector3 = wedge.global_transform.basis * Vector3(0, 0, -1)
	assert_float(local_forward.normalized().dot(forward)).is_equal_approx(1.0, 0.001)


func test_aoe_visual_size_equals_hit_size() -> void:
	var parts := _pool_and_context()
	var pool: EffectPool = parts[0]
	var context: EffectContext = parts[1]
	EffectTemplates._play_aoe_vfx(AOE_PARAMS, context)
	var disc: PooledEffect = pool.get_child(0)
	assert_object(disc.mesh).is_same(EffectPool.disc_mesh())
	var visual_radius: float = disc.mesh.get_aabb().size.x * 0.5 * disc.scale.x
	var hit_reach: float = float(AOE_PARAMS["radius"]) + VfxConfig.hurtbox_reach_radius()
	assert_float(visual_radius).is_equal_approx(hit_reach, 0.001)


func test_projectile_visual_size_equals_hit_size() -> void:
	var scene: PackedScene = load(EffectTemplates.PROJECTILE_SCENE_PATH)
	var small: Projectile = auto_free(scene.instantiate())
	var big: Projectile = auto_free(scene.instantiate())
	add_child(small)
	add_child(big)
	small.set_hit_radius(0.25)
	big.set_hit_radius(0.6)
	assert_float(small.hitbox_radius()).is_equal_approx(0.25, 0.0001)
	assert_float(small.visual_radius()).is_equal_approx(small.hitbox_radius(), 0.0001)
	assert_float(big.hitbox_radius()).is_equal_approx(0.6, 0.0001)
	assert_float(big.visual_radius()).is_equal_approx(big.hitbox_radius(), 0.0001)
	assert_float(VfxSizing.projectile_radius(0.6)).is_equal_approx(big.hitbox_radius(), 0.0001)


func test_card_projectile_uses_card_hit_radius_for_both() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var caster: Node3D = auto_free(Node3D.new())
	holder.add_child(caster)
	var context := EffectContext.new(caster, holder, "player")
	EffectTemplates.execute("projectile", {"damage": 9, "damage_type": "fire", "speed": 11.0, "max_range": 14.0, "hit_radius": 0.3}, context)
	var projectile: Projectile = null
	for child in holder.get_children():
		if child is Projectile:
			projectile = child
	assert_object(projectile).is_not_null()
	assert_float(projectile.hitbox_radius()).is_equal_approx(0.3, 0.0001)
	assert_float(projectile.visual_radius()).is_equal_approx(0.3, 0.0001)


func test_player_attack_wedges_are_drawn_to_effective_reach() -> void:
	var scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player: Player = auto_free(scene.instantiate())
	add_child(player)
	for attack_id: StringName in player.attacks.ids():
		var def := player.attacks.get_def(attack_id)
		var visual: AttackArcVisual = player._attack_visuals[attack_id]
		var reach: float = -visual.mesh.get_aabb().position.z
		assert_float(reach).is_equal_approx(float(def["range"]) + VfxConfig.hurtbox_reach_radius(), 0.001)
