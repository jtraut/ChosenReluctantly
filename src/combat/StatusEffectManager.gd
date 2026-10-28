extends Node
class_name StatusEffectManager
## Generic container of active timed status effects (Burn now; Chill, Soaked,
## etc. later). A status is data (data/statuses.json) describing an
## "effect_type" - only "damage_over_time" exists today, so adding a new
## damage-over-time status (different element, different tick) is a data
## change, not a code change. A genuinely new effect_type is a new branch in
## `_tick()`.

signal status_applied(status_id: String)
signal status_expired(status_id: String)

@export var health_path: NodePath

var health: Health = null
## Where visuals are drawn. Null means "the parent's parent" (the arena the
## owner stands in), so no scene-root lookup is needed.
var vfx_world: Node = null
var _active: Dictionary = {}
## status_id -> PooledEffect and the generation it was handed out for.
var _flames: Dictionary = {}
var _flame_generations: Dictionary = {}


class ActiveStatus:
	var status_id: String
	var effect_type: String
	var damage_per_tick: float
	var damage_type: String
	var tick_interval: float
	var time_remaining: float
	var time_to_next_tick: float

	func _init(p_status_id: String, status_def: Dictionary, duration: float) -> void:
		status_id = p_status_id
		effect_type = status_def.get("effect_type", "damage_over_time")
		damage_per_tick = status_def.get("damage_per_tick", 0.0)
		damage_type = status_def.get("damage_type", "physical")
		tick_interval = maxf(status_def.get("tick_interval", 1.0), 0.05)
		time_remaining = duration
		time_to_next_tick = tick_interval


func _ready() -> void:
	if health_path != NodePath():
		health = get_node(health_path) as Health
	tree_exiting.connect(_stop_all_flames)


## Applying the same status_id again refreshes its duration (does not stack
## multiple instances of the same status).
func apply_status(status_id: String, status_def: Dictionary, duration: float) -> void:
	var was_active: bool = _active.has(status_id)
	_active[status_id] = ActiveStatus.new(status_id, status_def, duration)
	if not was_active:
		status_applied.emit(status_id)
	# A refresh emits nothing, so check the flame is still alive (it could have
	# been recycled) and restart it if not.
	_ensure_flame(status_id, status_def)


func has_status(status_id: String) -> bool:
	return _active.has(status_id)


func active_status_ids() -> Array:
	return _active.keys()


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: Array[String] = []
	for status_id: String in _active.keys():
		var active: ActiveStatus = _active[status_id]
		active.time_remaining -= delta
		active.time_to_next_tick -= delta
		if active.time_to_next_tick <= 0.0:
			active.time_to_next_tick += active.tick_interval
			_tick(active)
		if active.time_remaining <= 0.0:
			expired.append(status_id)
	for status_id: String in expired:
		_active.erase(status_id)
		_stop_flame(status_id)
		status_expired.emit(status_id)


func _tick(active: ActiveStatus) -> void:
	if active.effect_type == "damage_over_time" and health != null:
		health.take_damage(active.damage_per_tick, active.damage_type)


func _vfx_pool() -> EffectPool:
	var world: Node = vfx_world
	if world == null and get_parent() != null:
		world = get_parent().get_parent()
	return EffectPool.for_world(world)


## Persistent flame for statuses whose data has "visual": {"kind": "flame"}. It
## follows the owner by instance id, so it also ends by itself if the owner is
## freed (an enemy dying never emits status_expired).
func _ensure_flame(status_id: String, status_def: Dictionary) -> void:
	var visual: Variant = status_def.get("visual")
	if typeof(visual) != TYPE_DICTIONARY or String((visual as Dictionary).get("kind", "")) != "flame":
		return
	var pool := _vfx_pool()
	var owner_node := get_parent() as Node3D
	if pool == null or owner_node == null or not owner_node.is_inside_tree():
		return
	if _flames.has(status_id) and pool.is_running(_flames[status_id], int(_flame_generations[status_id])):
		return
	var look := ElementVisuals.visual_for_damage_type(String(status_def.get("damage_type", "physical")))
	var effect: PooledEffect = TemplateVfx.status_flame(pool, owner_node, look, float((visual as Dictionary).get("size", 0.3)))
	if effect != null:
		_flames[status_id] = effect
		_flame_generations[status_id] = effect.generation


func _stop_flame(status_id: String) -> void:
	if not _flames.has(status_id):
		return
	var pool := _vfx_pool()
	if pool != null:
		pool.stop(_flames[status_id], int(_flame_generations[status_id]))
	_flames.erase(status_id)
	_flame_generations.erase(status_id)


func _stop_all_flames() -> void:
	for status_id: String in _flames.keys():
		_stop_flame(status_id)
