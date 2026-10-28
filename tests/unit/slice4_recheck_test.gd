class_name Slice4RecheckTest
extends GdUnitTestSuite
## qa re-check of S4-1: real-physics pins for the cone and aoe drawn reach (the lane is
## pinned in slice4_qa_test.gd). Enemies stand just inside / just outside the drawn edge.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func before_test() -> void:
	CardDatabase.load_all()


func after_test() -> void:
	Juice.reset()


## Casts `template_id` from the player at a chaser placed at `offset` from the player; true if it took damage.
func _hit_at(template_id: String, params: Dictionary, offset: Vector3) -> bool:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.get_node("TrainingDummy").free()
	main.player.camera = null
	main.player.rotation = Vector3.ZERO  # forward is -Z
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	enemy.target = null
	enemy.health.set_max_health(100000.0)
	enemy.health.current_health = 100000.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp := enemy.health.current_health
	EffectTemplates.execute(template_id, params, EffectContext.new(main.player, main, "player"))
	var hit := enemy.health.current_health < hp
	main.queue_free()
	await get_tree().process_frame
	return hit


func test_cone_drawn_reach_is_the_real_hit_reach() -> void:
	var params := {"damage": 5.0, "damage_type": "physical", "range": 1.8, "half_angle_degrees": 60.0}
	var reach := VfxSizing.cone_reach(1.8)
	assert_float(reach).is_equal_approx(2.205, 0.001)
	assert_bool(await _hit_at("cone", params, Vector3(0, 0, -(reach - 0.05)))).override_failure_message("inside the drawn wedge must hit").is_true()
	assert_bool(await _hit_at("cone", params, Vector3(0, 0, -(reach + 0.05)))).override_failure_message("outside the drawn wedge must miss").is_false()


func test_aoe_drawn_reach_is_the_real_hit_reach() -> void:
	var params := {"damage": 5.0, "damage_type": "fire", "radius": 2.5}
	var reach := VfxSizing.aoe_reach(2.5)
	assert_float(reach).is_equal_approx(sqrt(2.95 * 2.95 - 0.45 * 0.45), 0.001)
	assert_bool(await _hit_at("aoe", params, Vector3(reach - 0.05, 0, 0))).override_failure_message("inside the drawn disc must hit").is_true()
	assert_bool(await _hit_at("aoe", params, Vector3(reach + 0.05, 0, 0))).override_failure_message("outside the drawn disc must miss").is_false()
