class_name PlayerAttackTest
extends GdUnitTestSuite
## Player-level light/heavy attacks in the real Main scene: target gating,
## damage, input bindings, wind-up cancel on death.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	Juice.reset()
	Input.action_release("attack_light")
	Input.action_release("attack_heavy")


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


## Target-less (so stationary) enemy at `offset` from the player (-Z is the facing).
func _spawn_enemy(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func test_bindings_are_left_and_right_click() -> void:
	var light_events := InputMap.action_get_events("attack_light")
	var heavy_events := InputMap.action_get_events("attack_heavy")
	assert_int((light_events[0] as InputEventMouseButton).button_index).is_equal(MOUSE_BUTTON_LEFT)
	assert_int((heavy_events[0] as InputEventMouseButton).button_index).is_equal(MOUSE_BUTTON_RIGHT)
	assert_bool(InputMap.has_action("attack_basic")).is_false()


func test_light_auto_hits_enemy_in_front_and_not_behind() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.camera = null
	main.player.rotation = Vector3.ZERO  # qa: aim may already have turned the player before camera=null (timing flake)
	var behind := _spawn_enemy(main, Vector3(0.0, 0.0, 1.2))
	await _frames(4)
	assert_float(behind.health.current_health).is_equal(behind.health.get_max_health())
	var front := _spawn_enemy(main, Vector3(0.0, 0.0, -1.2))
	var fired: Array[StringName] = []
	main.player.attack_fired.connect(func(attack_id: StringName) -> void: fired.append(attack_id))
	await _frames(4)
	assert_array(fired).contains([&"light"])
	assert_float(front.health.current_health).is_less(front.health.get_max_health())
	assert_float(behind.health.current_health).is_equal(behind.health.get_max_health())


func test_heavy_right_click_winds_up_then_hits() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	var front := _spawn_enemy(main, Vector3(0.0, 0.0, -2.0))
	await _frames(3)
	var started: Array[StringName] = []
	var fired: Array[StringName] = []
	player.attack_started.connect(func(attack_id: StringName) -> void: started.append(attack_id))
	player.attack_fired.connect(func(attack_id: StringName) -> void: fired.append(attack_id))
	Input.action_press("attack_heavy")
	await _frames(2)
	Input.action_release("attack_heavy")
	assert_array(started).contains([&"heavy"])
	assert_bool(fired.has(&"heavy")).is_false()
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_true()
	var hp_before := front.health.current_health
	var deadline := Time.get_ticks_msec() + 2000
	while not fired.has(&"heavy") and Time.get_ticks_msec() < deadline:
		await _frames(1)
	assert_array(fired).contains([&"heavy"])
	# The hit may kill (and free) the chaser; either way it took the damage.
	assert_bool(not is_instance_valid(front) or front.health.current_health < hp_before).is_true()
	assert_float(player.get_attack_progress(&"heavy")).is_less(1.0)


func test_death_cancels_wind_up() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	player.rotation = Vector3.ZERO
	var cancelled: Array[StringName] = []
	var fired: Array[StringName] = []
	player.attack_cancelled.connect(func(attack_id: StringName) -> void: cancelled.append(attack_id))
	player.attack_fired.connect(func(attack_id: StringName) -> void: fired.append(attack_id))
	player.attacks.tick(0.016, true, {&"heavy": true}, func(_id: StringName) -> bool: return false)
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_true()
	player.health.take_damage(999.0)
	assert_array(cancelled).is_equal([&"heavy"])
	player._physics_process(1.0)
	assert_array(fired).is_empty()
