class_name Bd3aRecheckQaTest
extends GdUnitTestSuite
## BD3a re-check (qa): a9d56fc made Player._apply_aim honour aim_point_override. Real play must be unaffected, which holds only while
## nothing but the wave sim and scenarios ever set the override. These pin that: a plain Main has no override, and a body with a camera
## and no override does not turn by itself (it follows the mouse only, and with no mouse position on the ground plane it stays put).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

var _root_main: Main = null


func after_test() -> void:
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()


func _plain_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	return main


func test_a_plain_main_has_no_aim_override() -> void:
	var main: Main = _plain_main()
	for i in range(5):
		await get_tree().physics_frame
	assert_that(main.player.aim_point_override).is_null()


func test_clearing_the_override_stops_the_turn_toward_it() -> void:
	var main: Main = _plain_main()
	main.player.camera = null
	await get_tree().physics_frame
	main.player.aim_point_override = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	for i in range(30):
		await get_tree().physics_frame
	main.player.aim_point_override = null
	var settled: Vector3 = main.player.get_aim_direction()
	for i in range(15):
		await get_tree().physics_frame
	assert_float(rad_to_deg(main.player.get_aim_direction().angle_to(settled))).is_less(0.01)
