class_name AimGettersTest
extends GdUnitTestSuite
## Slice 4c: the read-only aim getters on Player (no behaviour change).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func after_test() -> void:
	Juice.reset()


func test_aim_point_is_null_without_camera() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.camera = null
	assert_object(main.player.get_aim_point()).is_null()


func test_aim_point_on_player_ground_plane_with_camera() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var point: Variant = main.player.get_aim_point()
	# A headless viewport may not give a hit; when it does, it is on the player's plane.
	if point != null:
		assert_float((point as Vector3).y).is_equal_approx(main.player.global_position.y, 0.001)


func test_aim_direction_matches_facing_and_is_flat_unit() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation.y = deg_to_rad(90.0)
	var direction := player.get_aim_direction()
	assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
	assert_float(direction.y).is_equal(0.0)
	var expected := -player.global_transform.basis.z
	assert_float(direction.x).is_equal_approx(expected.x, 0.0001)
	assert_float(direction.z).is_equal_approx(expected.z, 0.0001)


func test_getters_do_not_change_player() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var before := player.global_transform
	player.get_aim_point()
	player.get_aim_direction()
	assert_bool(player.global_transform == before).is_true()


# --- AimIndicator -------------------------------------------------------------

func test_indicator_hides_when_dead_and_with_no_aim() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var indicator: AimIndicator = main.get_node("AimIndicator")
	main.player.camera = null
	indicator.preview_distance = 0.0
	await get_tree().process_frame
	assert_bool(indicator.is_showing()).is_false()
	indicator.preview_distance = 5.0
	await get_tree().process_frame
	assert_bool(indicator.is_showing()).is_true()
	main.player.health.take_damage(main.player.health.get_max_health() * 2.0)
	await get_tree().process_frame
	assert_bool(indicator.is_showing()).is_false()


func test_indicator_dots_stay_between_player_and_reticle() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var indicator: AimIndicator = main.get_node("AimIndicator")
	main.player.camera = null
	indicator.preview_distance = 5.0
	await get_tree().process_frame
	var cfg := UiConfig.aim()
	var shown := 0
	for child in indicator.get_children():
		var part := child as MeshInstance3D
		if part.visible and part.mesh == EffectPool.disc_mesh() and is_equal_approx(part.scale.x, float(cfg["dot_radius"])):
			shown += 1
			var dist: float = Vector2(part.position.x - main.player.global_position.x, part.position.z - main.player.global_position.z).length()
			assert_float(dist).is_less(5.0 - float(cfg["reticle_radius"]) + 0.001)
	assert_int(shown).is_greater(0)


func test_aim_config_validation() -> void:
	assert_array(UiConfig.validate_aim(UiConfig.aim())).is_empty()
	var bad := UiConfig.aim()
	bad["reticle_alpha"] = 2.0
	assert_array(UiConfig.validate_aim(bad)).is_not_empty()
	bad = UiConfig.aim()
	bad["color"] = "nope"
	assert_array(UiConfig.validate_aim(bad)).is_not_empty()
