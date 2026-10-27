class_name MainSceneSmokeTest
extends GdUnitTestSuite
## Loads the real main scene and checks the world is actually visible -
## guards against "HUD shows but the 3D world is empty" regressions.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	# The spawner adds enemies to the tree's current_scene (the test runner
	# here), where they'd outlive this test - its config is still checked.
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func test_main_scene_has_visible_world() -> void:
	var main := _spawn_main()
	await get_tree().process_frame

	var camera := main.get_viewport().get_camera_3d()
	assert_object(camera).is_not_null()
	assert_bool(camera.current).is_true()
	assert_object(main.get_node_or_null("Player")).is_instanceof(Player)
	assert_object(main.get_node_or_null("Floor")).is_not_null()
	assert_array(main.find_children("*", "Light3D", true, false)).is_not_empty()
	assert_float(main.player.health.current_health).is_greater(0.0)
	assert_bool(camera.is_position_in_frustum(main.player.global_position)).is_true()

	assert_array(SceneSelfCheck.find_problems(main)).is_empty()
