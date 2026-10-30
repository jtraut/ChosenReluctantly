class_name Pl2QaTest
extends GdUnitTestSuite
## qa additions for PL2: the frame_color load failure path on a real pools file, and a regression for the Wizard
## MeleeReachCue node leak (the band node was created but never parented when the light attack is not an arc).

const BAD_POOLS := "res://tests/fixtures/pools_noframe/pools.json"
const REAL_POOLS := "res://data/pools.json"
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func after_test() -> void:
	PoolDatabase._table = JsonDataTable.new(REAL_POOLS)
	RunSession.clear()


func test_a_pools_file_missing_or_with_a_bad_frame_color_fails_loudly_and_names_the_pool() -> void:
	PoolDatabase._table = JsonDataTable.new(BAD_POOLS)
	var errors := PoolDatabase.validate_all()
	var joined := "; ".join(errors)
	assert_bool(joined.contains("rogue") and joined.contains("frame_color")).override_failure_message("missing frame_color on rogue not reported: " + joined).is_true()
	assert_bool(joined.contains("fire") and joined.contains("valid color")).override_failure_message("bad frame_color on fire not reported: " + joined).is_true()
	assert_bool(joined.contains("neutral")).override_failure_message("the good pool must not be reported").is_false()


func test_the_shipped_pools_file_still_validates_after_the_fixture_swap() -> void:
	assert_array(PoolDatabase.validate_all()).is_empty()


func test_loading_a_wizard_main_leaves_no_orphan_nodes() -> void:
	# Regression: MeleeReachCue created its band MeshInstance3D at field init but only parented it for an arc light.
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	remove_child(main)
	main.free()
	assert_int(after - before).override_failure_message("a Wizard Main leaked %d orphan node(s)" % (after - before)).is_equal(0)
