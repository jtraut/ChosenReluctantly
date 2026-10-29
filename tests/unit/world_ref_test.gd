extends GdUnitTestSuite
## WorldRef: the spawn-parent reference that lets Main run inside a SubViewport (true-size capture).

func after_test() -> void:
	WorldRef.register(null)


func test_falls_back_to_null_when_nothing_registered_and_no_current_scene() -> void:
	WorldRef.register(null)
	assert_object(WorldRef.get_world(get_tree())).is_null()
	assert_object(WorldRef.get_world(null)).is_null()


func test_registered_world_is_used_only_while_in_the_tree() -> void:
	var node := Node3D.new()
	WorldRef.register(node)
	assert_object(WorldRef.get_world(get_tree())).is_null()  # not in the tree yet
	add_child(node)
	assert_object(WorldRef.get_world(get_tree())).is_same(node)
	node.free()
	assert_object(WorldRef.get_world(get_tree())).is_null()


func test_unregister_only_clears_the_same_world() -> void:
	var a := Node3D.new()
	var b := Node3D.new()
	add_child(a)
	add_child(b)
	WorldRef.register(b)
	WorldRef.unregister(a)  # an old Main leaving after the new one registered
	assert_object(WorldRef.get_world(get_tree())).is_same(b)
	WorldRef.unregister(b)
	assert_object(WorldRef.get_world(get_tree())).is_null()
	a.free()
	b.free()


func test_main_registers_itself_in_a_sub_viewport_without_current_scene() -> void:
	var sub := SubViewport.new()
	add_child(sub)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	sub.add_child(main)
	assert_object(get_tree().current_scene).is_null()
	assert_object(WorldRef.get_world(get_tree())).is_same(main)
	assert_object(main.player.card_slots.spawn_parent).is_same(main)
	sub.free()
	assert_object(WorldRef.get_world(get_tree())).is_null()
