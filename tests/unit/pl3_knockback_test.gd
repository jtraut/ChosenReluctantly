class_name Pl3KnockbackTest
extends GdUnitTestSuite
## PL3 item 3: the boss smash threw an idle Wizard about 20 m to the arena wall. The player's walking velocity was read back
## from `velocity`, which already held last tick's knockback, so the knockback was added again every tick. A knockback impulse
## must travel what its decay gives (speed squared over twice Player.KNOCKBACK_DECAY) and stay inside the arena.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const SMASH_KNOCKBACK := 9.0


func before_test() -> void:
	Juice.hit_stop_enabled = false


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	return main


## Hits the player with a knockback of `strength` along +Z and returns how far it ended from where it stood.
func _travel(main: Main, start: Vector3, strength: float) -> float:
	main.player.global_position = start
	main.player.health.damage_immune = false
	await _frames(3)
	var from: Vector3 = main.player.global_position
	main.player.health.take_damage(1.0, "physical", Vector3(0.0, 0.0, strength))
	await _frames(90)
	return main.player.global_position.z - from.z


func test_the_boss_smash_knockback_travels_what_its_decay_gives() -> void:
	var main := _main()
	await _frames(2)
	var distance: float = await _travel(main, Vector3(0.0, 0.2, 0.0), SMASH_KNOCKBACK)
	var expected: float = SMASH_KNOCKBACK * SMASH_KNOCKBACK / (2.0 * Player.KNOCKBACK_DECAY)
	assert_float(distance).override_failure_message("a %.0f m/s knockback should carry about %.1f m, it carried %.1f m" % [SMASH_KNOCKBACK, expected, distance]).is_between(expected * 0.8, expected * 1.2)


func test_a_knockback_near_the_wall_stays_inside_the_arena() -> void:
	var main := _main()
	await _frames(2)
	var rect: Rect2 = main.player.get_arena_rect()
	await _travel(main, Vector3(0.0, 0.2, rect.end.y - 1.0), 40.0)
	assert_bool(rect.grow(0.05).has_point(Vector2(main.player.global_position.x, main.player.global_position.z))).override_failure_message("the player left the arena: %s" % str(main.player.global_position)).is_true()


func test_walking_still_reaches_full_speed_after_a_knockback() -> void:
	var main := _main()
	await _frames(2)
	await _travel(main, Vector3(0.0, 0.2, -10.0), SMASH_KNOCKBACK)
	assert_vector(main.player._applied_knockback).is_equal_approx(Vector3.ZERO, Vector3(0.01, 0.01, 0.01))
	assert_float(Vector2(main.player.velocity.x, main.player.velocity.z).length()).is_less(0.01)
