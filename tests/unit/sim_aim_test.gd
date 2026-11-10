class_name SimAimTest
extends GdUnitTestSuite
## The wave sim bot (and scenarios) aim with Player.aim_point_override. The body must turn toward it like it
## turns toward the mouse, because cones, dashes and projectile fans use the body's facing. Before this fix the
## bot's directional cards whiffed (rogue-bleed-out won 0 of 12 whole runs, 12 of 12 after).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

var _root_main: Main = null


func after_test() -> void:
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()


func _player(with_camera: bool) -> Player:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	if not with_camera:
		main.player.camera = null
	return main.player


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _angle_to(player: Player, point: Vector3) -> float:
	var to_point: Vector3 = point - player.global_position
	to_point.y = 0.0
	return rad_to_deg(player.get_aim_direction().angle_to(to_point))


func test_the_body_turns_toward_the_aim_override_with_a_camera() -> void:
	var player: Player = _player(true)
	await _frames(2)
	var target: Vector3 = player.global_position + Vector3(6.0, 0.0, 6.0)
	player.aim_point_override = target
	await _frames(30)
	assert_float(_angle_to(player, target)).is_less(2.0)


func test_the_body_turns_toward_the_aim_override_without_a_camera() -> void:
	var player: Player = _player(false)
	await _frames(2)
	var target: Vector3 = player.global_position + Vector3(-5.0, 0.0, 4.0)
	player.aim_point_override = target
	await _frames(30)
	assert_float(_angle_to(player, target)).is_less(2.0)


func test_without_an_override_and_without_a_camera_the_facing_does_not_change() -> void:
	var player: Player = _player(false)
	await _frames(2)
	var before: Vector3 = player.get_aim_direction()
	await _frames(10)
	assert_float(rad_to_deg(player.get_aim_direction().angle_to(before))).is_less(0.01)
