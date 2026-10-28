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
## An already-active status was applied again (duration kept or extended, tick phase kept).
## `status_applied` stays "began", so cues that start on it never double up.
signal status_refreshed(status_id: String)
## A stun landed on an immune target (boss, or diminishing returns): nothing was applied.
## ux can show an "immune" popup from this.
signal status_resisted(status_id: String)

@export var health_path: NodePath

var health: Health = null
## Enemy rank ("normal" / "elite" / "boss"); decides how long a stun lasts. Set by the owner.
var rank: String = "normal"
## Where visuals are drawn. Null means "the parent's parent" (the arena the
## owner stands in), so no scene-root lookup is needed.
var vfx_world: Node = null
var _active: Dictionary = {}
var _clock: float = 0.0
var _stun_rules := StunRules.new()
## status_id -> PooledEffect and the generation it was handed out for.
var _flames: Dictionary = {}
var _flame_generations: Dictionary = {}
## status_id -> extra [PooledEffect, generation] pairs of a multi-part cue (stun stars).
var _extra_effects: Dictionary = {}


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

	func refresh(status_def: Dictionary, duration: float) -> void:
		damage_per_tick = status_def.get("damage_per_tick", damage_per_tick)
		time_remaining = maxf(time_remaining, duration)


func _ready() -> void:
	if health_path != NodePath():
		health = get_node(health_path) as Health
	tree_exiting.connect(_stop_all_flames)


## Applying the same status_id again refreshes its duration (does not stack
## multiple instances of the same status).
func apply_status(status_id: String, status_def: Dictionary, duration: float) -> void:
	var was_active: bool = _active.has(status_id)
	if String(status_def.get("effect_type", "")) == "stun":
		# Rank and diminishing returns decide the real length; 0 means immune, which
		# changes nothing at all (an active stun keeps running, nothing is cancelled).
		duration = _stun_rules.resolve(_clock, duration, rank, status_def)
		if duration <= 0.0:
			status_resisted.emit(status_id)
			return
		if was_active:
			duration = maxf(duration, (_active[status_id] as ActiveStatus).time_remaining)
	if was_active:
		# A refresh keeps the tick phase (time_to_next_tick) and takes the longer duration,
		# so recasting before expiry never restarts the tick timer or shortens the status.
		(_active[status_id] as ActiveStatus).refresh(status_def, duration)
	else:
		_active[status_id] = ActiveStatus.new(status_id, status_def, duration)
		status_applied.emit(status_id)
	# A refresh emits nothing, so check the flame is still alive (it could have
	# been recycled) and restart it if not.
	_ensure_flame(status_id, status_def)
	if was_active:
		status_refreshed.emit(status_id)


func has_status(status_id: String) -> bool:
	return _active.has(status_id)


## True while any "stun" effect_type status is active (by effect, not by id).
func is_stunned() -> bool:
	for active: ActiveStatus in _active.values():
		if active.effect_type == "stun":
			return true
	return false


## Seconds left on the active stun (0 when not stunned).
func stun_time_remaining() -> float:
	var longest: float = 0.0
	for active: ActiveStatus in _active.values():
		if active.effect_type == "stun":
			longest = maxf(longest, active.time_remaining)
	return longest


func active_status_ids() -> Array:
	return _active.keys()


func _process(delta: float) -> void:
	_clock += delta
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


## Persistent visual for statuses whose data has a "visual" block: a "flame" (Burn,
## colored by the damage type's element) or "stars" circling the head (Stun, colored by visual.color).
## It follows the owner by instance id, so it also ends by itself if the owner is
## freed (an enemy dying never emits status_expired).
func _ensure_flame(status_id: String, status_def: Dictionary) -> void:
	var visual: Variant = status_def.get("visual")
	if typeof(visual) != TYPE_DICTIONARY:
		return
	var block: Dictionary = visual
	var kind: String = String(block.get("kind", ""))
	if kind != "flame" and kind != "stars":
		return
	var pool := _vfx_pool()
	var owner_node := get_parent() as Node3D
	if pool == null or owner_node == null or not owner_node.is_inside_tree():
		return
	if _flames.has(status_id) and _cue_running(pool, status_id):
		return
	_stop_flame(status_id)
	var effect: PooledEffect = null
	if kind == "stars":
		var stars: Array[PooledEffect] = TemplateVfx.status_stars(pool, owner_node, Color.html(String(block.get("color", "#ffe14a"))),
				float(block.get("size", 0.15)), int(block.get("count", 3)), float(block.get("orbit_radius", 0.45)), float(block.get("orbit_hz", 1.2)),
				TemplateVfx.body_top(owner_node))
		if not stars.is_empty():
			effect = stars[0]
			var extras: Array = []
			for i in range(1, stars.size()):
				extras.append([stars[i], stars[i].generation])
			_extra_effects[status_id] = extras
	else:
		var look := ElementVisuals.visual_for_damage_type(String(status_def.get("damage_type", "physical")))
		effect = TemplateVfx.status_flame(pool, owner_node, look, float(block.get("size", 0.3)), TemplateVfx.body_top(owner_node))
	if effect != null:
		_flames[status_id] = effect
		_flame_generations[status_id] = effect.generation


## True while every part of the status's cue is still the effect it was handed out as.
func _cue_running(pool: EffectPool, status_id: String) -> bool:
	if not pool.is_running(_flames[status_id], int(_flame_generations[status_id])):
		return false
	for pair: Array in _extra_effects.get(status_id, []):
		if not pool.is_running(pair[0], int(pair[1])):
			return false
	return true


func _stop_flame(status_id: String) -> void:
	if not _flames.has(status_id):
		return
	var pool := _vfx_pool()
	if pool != null:
		pool.stop(_flames[status_id], int(_flame_generations[status_id]))
		for pair: Array in _extra_effects.get(status_id, []):
			pool.stop(pair[0], int(pair[1]))
	_extra_effects.erase(status_id)
	_flames.erase(status_id)
	_flame_generations.erase(status_id)


func _stop_all_flames() -> void:
	for status_id: String in _flames.keys():
		_stop_flame(status_id)
