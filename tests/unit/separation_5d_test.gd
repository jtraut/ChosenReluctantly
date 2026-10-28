class_name Separation5dTest
extends GdUnitTestSuite
## 5d: separation steering keeps chasers from stacking into one blob on the player.
##
## METRIC (also reported by tools/wave_sim.gd): per physics frame with 2+ non-ranged enemies within
## `near_player_radius` of the player, the smallest pairwise flat distance among them. A frame is
## "spread" when that minimum is >= `readable_spacing`. Both numbers are in data/enemies.json.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
## Share of frames that must be spread with steering on. The same setup with steering off must fall
## clearly below it (the test is not vacuous).
const SPREAD_SHARE_MIN := 0.6

var _main: Main = null


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()


func _build(seed_value: int, count: int, steering_on: bool) -> Array[Enemy]:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.player.process_mode = Node.PROCESS_MODE_DISABLED  # a still target: no auto attacks, no knockback
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var list: Array[Enemy] = []
	for i in range(count):
		var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
		_main.add_child(enemy)
		# A 70 degree arc 8-10 m out: they all arrive from the same side, the worst case for piling up.
		var angle: float = rng.randf_range(-0.6, 0.6)
		var dist: float = rng.randf_range(8.0, 10.0)
		enemy.global_position = _main.player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
		enemy.target = _main.player
		enemy.begin_spawn_grace(99.0)  # the metric is about walking in, not swinging
		if not steering_on:
			enemy._separation_strength = 0.0
		list.append(enemy)
	return list


## Returns [frames with 2+ near, frames spread].
func _sample(enemies: Array[Enemy], frames: int) -> Array[int]:
	var near_radius: float = EnemyConfig.near_player_radius()
	var spacing: float = EnemyConfig.readable_spacing()
	var counted: int = 0
	var spread: int = 0
	for f in range(frames):
		await get_tree().physics_frame
		var me: Vector3 = _main.player.global_position
		var best: float = INF
		var near: int = 0
		for i in range(enemies.size()):
			var a: Enemy = enemies[i]
			if me.distance_to(a.global_position) > near_radius:
				continue
			near += 1
			for j in range(i + 1, enemies.size()):
				var b: Enemy = enemies[j]
				if me.distance_to(b.global_position) > near_radius:
					continue
				best = minf(best, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
		if near >= 2:
			counted += 1
			if best >= spacing:
				spread += 1
	return [counted, spread]


func test_chasers_stay_spread_near_the_player() -> void:
	var enemies := _build(7, 6, true)
	var result := await _sample(enemies, 360)
	assert_int(result[0]).is_greater(60)
	var share: float = float(result[1]) / float(result[0])
	assert_float(share).is_greater_equal(SPREAD_SHARE_MIN)


func test_without_steering_the_same_setup_piles_up() -> void:
	var enemies := _build(7, 6, false)
	var result := await _sample(enemies, 360)
	assert_int(result[0]).is_greater(60)
	var share: float = float(result[1]) / float(result[0])
	assert_float(share).is_less(SPREAD_SHARE_MIN)


func test_steering_never_exceeds_own_move_speed() -> void:
	var enemies := _build(3, 5, true)
	for f in range(120):
		await get_tree().physics_frame
		for enemy in enemies:
			var flat := Vector2(enemy.velocity.x, enemy.velocity.z).length()
			assert_float(flat).is_less_equal(enemy.move_speed + 0.01)


func test_no_steering_during_a_windup() -> void:
	var enemies := _build(5, 2, true)
	var winder := enemies[0]
	var crowder := enemies[1]
	winder.global_position = _main.player.global_position + Vector3(1.2, 0.0, 0.0)
	crowder.global_position = winder.global_position + Vector3(0.3, 0.0, 0.0)
	crowder.begin_spawn_grace(0.0)
	crowder._attack_cooldown_remaining = 99.0
	winder._attack_cooldown_remaining = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(winder._telegraph_remaining).is_greater(0.0)
	var start := winder.global_position
	var basis_before := winder.global_transform.basis
	for f in range(10):
		await get_tree().physics_frame
	assert_float(winder._telegraph_remaining).is_greater(0.0)
	assert_vector(winder.global_position).is_equal_approx(start, Vector3(0.001, 0.001, 0.001))
	assert_bool(winder.global_transform.basis.is_equal_approx(basis_before)).is_true()


func test_separation_config_is_validated() -> void:
	assert_array(EnemyConfig.validate_separation({"radius": 1.8, "strength": 0.8, "readable_spacing": 1.2, "near_player_radius": 4.0})).is_empty()
	assert_array(EnemyConfig.validate_separation({"radius": 0.0, "strength": 0.8, "readable_spacing": 1.2, "near_player_radius": 4.0})).is_not_empty()
	assert_array(EnemyConfig.validate_separation({"radius": 1.8, "strength": -1.0, "readable_spacing": 1.2, "near_player_radius": 4.0})).is_not_empty()
	assert_array(EnemyConfig.validate_separation({"radius": 1.8})).is_not_empty()
	assert_array(EnemyConfig.validate_separation({"radius": 1.8, "strength": 0.8, "readable_spacing": 1.2, "near_player_radius": 4.0, "typo": 1})).is_not_empty()
	assert_array(EnemyConfig.validate_separation("x")).is_not_empty()
	assert_float(EnemyConfig.separation_radius()).is_greater(0.0)
