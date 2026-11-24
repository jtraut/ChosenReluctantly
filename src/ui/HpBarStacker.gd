class_name HpBarStacker
extends Node
## UX1c: keeps the world-space enemy HP bars of a crowd from standing on each other. One of these lives under the scene root once any bar exists;
## bars register themselves. Each frame, while two or more bars show, it asks HpBarLayout how far each must be lifted (screen-up) and eases the
## bars there. A lone bar is never touched. Display only: it moves bar quads, never enemies, and reads no RNG.

static var _node: HpBarStacker = null
static var _bars: Array[EnemyHpBar] = []


## Called by a bar when it enters the tree: remembers it and makes sure the stacker node exists.
static func register(bar: EnemyHpBar) -> void:
	if not _bars.has(bar):
		_bars.append(bar)
	if (_node == null or not is_instance_valid(_node)) and bar.is_inside_tree():
		var root: Node = bar.get_tree().root
		var stacker := HpBarStacker.new()
		stacker.name = "HpBarStacker"
		_node = stacker
		root.add_child.call_deferred(stacker)


static func unregister(bar: EnemyHpBar) -> void:
	_bars.erase(bar)


## The bars that show right now and have a parent to stand on.
static func live_bars() -> Array[EnemyHpBar]:
	var live: Array[EnemyHpBar] = []
	for bar: EnemyHpBar in _bars:
		if is_instance_valid(bar) and bar.is_inside_tree() and bar.visible and bar.get_parent() is Node3D:
			live.append(bar)
	return live


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var live: Array[EnemyHpBar] = live_bars()
	if camera == null:
		return
	var config: Dictionary = EnemyHpBar.shared_config()
	var rate: float = float(config["stack_smooth"])
	var targets: Array[float] = []
	if live.size() >= 2 and int(config["stack_max_rows"]) > 0:
		var right: Vector3 = camera.global_transform.basis.x.normalized()
		var up: Vector3 = camera.global_transform.basis.y.normalized()
		var anchors: Array[Vector2] = []
		for bar: EnemyHpBar in live:
			var base: Vector3 = bar.base_global_position()
			anchors.append(Vector2(base.dot(right), base.dot(up)))
		targets = HpBarLayout.stack_offsets(anchors, EnemyHpBar.footprint(), float(config["stack_gap"]), int(config["stack_max_rows"]))
	for i in range(live.size()):
		var bar: EnemyHpBar = live[i]
		var target: float = targets[i] if i < targets.size() else 0.0
		bar.set_lift(HpBarLayout.smooth(bar.lift(), target, rate, delta), camera.global_transform.basis.y.normalized())
