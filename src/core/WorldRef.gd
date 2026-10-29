class_name WorldRef
extends RefCounted
## The node that effects, popups and screens spawn into (the Main arena). Main registers
## itself in _enter_tree. Normal play: identical to `get_tree().current_scene`. The
## difference is tools/VpCapture.tscn, which hosts Main inside a SubViewport where
## `current_scene` is null. Falls back to `current_scene` when nothing is registered
## (unit tests that build a bare Player under the test runner).

static var _world: Node = null


static func register(world: Node) -> void:
	_world = world


## Clears the registration only if `world` is still the registered one (a reload may have
## registered the new Main before the old one leaves the tree).
static func unregister(world: Node) -> void:
	if _world == world:
		_world = null


static func get_world(tree: SceneTree) -> Node:
	if tree == null:
		return null
	# current_scene first: normal play and the test runner behave exactly as before. The
	# registered Main only fills in where current_scene is null (VpCapture's SubViewport).
	if tree.current_scene != null:
		return tree.current_scene
	if _world != null and is_instance_valid(_world) and _world.is_inside_tree():
		return _world
	return null
