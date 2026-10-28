class_name Slice5aTest
extends GdUnitTestSuite
## Slice 5a: N1 (golem hurtbox matches the ground shapes), team tint, HP bar rendering.


func _enemy(path: String) -> Enemy:
	var enemy: Enemy = auto_free((load(path) as PackedScene).instantiate())
	add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


# ---- N1 ----

func test_golem_hurtbox_is_a_capsule_matching_the_vfx_reach_data() -> void:
	var golem := _enemy("res://scenes/enemies/FireResistantGolem.tscn")
	var shape_node: CollisionShape3D = golem.get_node("Hurtbox/HurtboxShape")
	assert_object(shape_node.shape).is_instanceof(CapsuleShape3D)
	var capsule := shape_node.shape as CapsuleShape3D
	assert_float(capsule.radius).is_equal_approx(VfxConfig.hurtbox_reach_radius(), 0.0001)
	var low: float = shape_node.position.y - (capsule.height * 0.5 - capsule.radius)
	assert_float(low).is_equal_approx(VfxConfig.hurtbox_low_center_height(), 0.0001)
	# Movement collision is unchanged (still the 1.2 m box): only the hurtbox moved.
	assert_object((golem.get_node("CollisionShape3D") as CollisionShape3D).shape).is_instanceof(BoxShape3D)


func test_shooter_hurtbox_stays_within_6cm_of_the_shared_numbers() -> void:
	# Known limit (S4-1): one global pair of numbers, tuned for the chaser. Pinned so it cannot drift.
	var shooter := _enemy("res://scenes/enemies/RangedShooter.tscn")
	var shape_node: CollisionShape3D = shooter.get_node("Hurtbox/HurtboxShape")
	var capsule := shape_node.shape as CapsuleShape3D
	assert_float(absf(capsule.radius - VfxConfig.hurtbox_reach_radius())).is_less_equal(0.06)
	var low: float = shape_node.position.y - (capsule.height * 0.5 - capsule.radius)
	assert_float(absf(low - VfxConfig.hurtbox_low_center_height())).is_less_equal(0.06)


func test_ground_shape_edge_is_the_golem_hit_edge() -> void:
	# A floor-level sphere reaching exactly VfxSizing.lateral_reach(q) from a target's centre is the hit edge.
	var golem := _enemy("res://scenes/enemies/FireResistantGolem.tscn")
	golem.global_position = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	for q: float in [1.8, 2.5]:
		var edge: float = VfxSizing.lateral_reach(q)
		var inside := MeleeQuery.find_hurtboxes_in_sphere(space, Vector3(edge - 0.03, 0.0, 0.0), q, "player", CollisionLayers.HURTBOX)
		var outside := MeleeQuery.find_hurtboxes_in_sphere(space, Vector3(edge + 0.03, 0.0, 0.0), q, "player", CollisionLayers.HURTBOX)
		assert_int(inside.size()).override_failure_message("q=%s just inside the drawn edge must hit" % q).is_equal(1)
		assert_int(outside.size()).override_failure_message("q=%s just outside the drawn edge must miss" % q).is_equal(0)


# ---- Team tint ----

func test_enemy_physical_shot_differs_from_player_physical_shot() -> void:
	var player_look := ElementVisuals.visual_for_team("physical", "player")
	var enemy_look := ElementVisuals.visual_for_team("physical", "enemy")
	var a: Color = player_look["color"]
	var b: Color = enemy_look["color"]
	assert_bool(a == ElementVisuals.color_for_damage_type("physical")).is_true()
	assert_float(absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)).is_greater(0.6)
	assert_float(float(enemy_look["scale"])).is_equal(float(player_look["scale"]))


func test_enemy_elemental_shot_is_pulled_toward_the_tint_but_stays_that_element() -> void:
	var plain: Color = ElementVisuals.color_for_damage_type("fire")
	var enemy_fire: Color = ElementVisuals.visual_for_team("fire", "enemy")["color"]
	var tint := Color.html(String(VfxConfig.team_tint("enemy")["color"]))
	assert_bool(enemy_fire == plain).is_false()
	assert_float(absf(enemy_fire.g - plain.g)).is_greater(0.0)
	var mix: float = float(VfxConfig.team_tint("enemy")["element_mix"])
	assert_float(enemy_fire.r).is_equal_approx(lerpf(plain.r, tint.r, mix), 0.0001)


func test_player_team_has_no_tint_and_unknown_team_is_safe() -> void:
	assert_bool(VfxConfig.team_tint("player").is_empty()).is_true()
	assert_bool(VfxConfig.team_tint("nobody").is_empty()).is_true()
	assert_bool(ElementVisuals.visual_for_team("fire", "nobody")["color"] == ElementVisuals.color_for_damage_type("fire")).is_true()


func test_team_tint_validation() -> void:
	assert_array(VfxConfig.validate_team_tints({"enemy": {"color": "#ff3d8b", "neutral_mix": 1.0, "element_mix": 0.4}})).is_empty()
	var bad_cases: Array = [3, {"enemy": 4}, {"enemy": {"color": "pink", "neutral_mix": 1.0, "element_mix": 0.4}},
			{"enemy": {"color": "#ff3d8b", "neutral_mix": 2.0, "element_mix": 0.4}},
			{"enemy": {"color": "#ff3d8b", "neutral_mix": 1.0}}]
	for bad: Variant in bad_cases:
		assert_array(VfxConfig.validate_team_tints(bad)).override_failure_message("should reject %s" % str(bad)).is_not_empty()


func test_an_enemy_shot_gets_the_enemy_tint() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var shooter := _enemy("res://scenes/enemies/RangedShooter.tscn")
	var context := EffectContext.new(shooter, holder, "enemy")
	EffectTemplates.execute("projectile", {"damage": 4.0, "damage_type": "physical", "speed": 9.0, "max_range": 18.0, "hit_radius": 0.3}, context)
	var shot: Projectile = null
	for child in holder.get_children():
		if child is Projectile:
			shot = child
	assert_object(shot).is_not_null()
	var expected: Color = ElementVisuals.visual_for_team("physical", "enemy")["color"]
	assert_bool(shot._look["color"] == expected).is_true()


# ---- HP bar rendering ----

func test_bar_shader_is_depth_tested() -> void:
	var source := FileAccess.get_file_as_string("res://assets/shaders/enemy_hp_bar.gdshader")
	assert_bool(source.contains("depth_test_disabled")).is_false()
	assert_bool(source.contains("depth_draw_opaque")).is_true()


func test_bar_is_smaller_than_before_and_priority_is_data() -> void:
	var cfg := UiConfig.hp_bars()
	assert_float(float(cfg["width"])).is_less(1.4)
	assert_float(float(cfg["height"])).is_less(0.19)
	assert_int(int(cfg["render_priority"])).is_equal(10)
	var golem := _enemy("res://scenes/enemies/FireResistantGolem.tscn")
	var bar: EnemyHpBar = golem.get_node("EnemyHpBar")
	assert_int(bar.material_override.render_priority).is_equal(10)
	assert_str(bar.rank()).is_equal("normal")


func test_camera_is_orthographic_so_bar_size_is_constant_on_screen() -> void:
	var rig: CameraRig = auto_free((load("res://scenes/camera/CameraRig.tscn") as PackedScene).instantiate())
	add_child(rig)
	assert_int(rig.camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)


# ---- Spawn grace ----

func test_spawn_grace_delays_the_first_attack_and_never_shortens_a_cooldown() -> void:
	var chaser := _enemy("res://scenes/enemies/MeleeChaser.tscn")
	chaser.begin_spawn_grace(1.5)
	assert_float(chaser._attack_cooldown_remaining).is_equal(1.5)
	chaser.begin_spawn_grace(0.5)
	assert_float(chaser._attack_cooldown_remaining).is_equal(1.5)
