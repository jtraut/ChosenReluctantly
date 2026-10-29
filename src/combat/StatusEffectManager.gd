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
## Lifesteal returned HP to the owner (amount actually healed). ux can show a heal cue.
signal lifesteal_healed(amount: float)

@export var health_path: NodePath

var health: Health = null
## Enemy rank ("normal" / "elite" / "boss"); decides how long a stun lasts. Set by the owner.
var rank: String = "normal"
## Where visuals are drawn. Null means "the parent's parent" (the arena the
## owner stands in), so no scene-root lookup is needed.
var vfx_world: Node = null
var _active: Dictionary = {}
## How many active statuses are stuns; is_stunned() is asked by every enemy every physics
## frame, so it reads this instead of walking (and allocating from) _active.values().
var _stun_count: int = 0
## Active lifesteal statuses; on_damage_dealt is called on every hit, so it reads this first.
var _lifesteal_count: int = 0
## Reused each frame by _process so it does not build an Array while a status runs.
var _expired: Array[String] = []
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
	## heal_over_time: HP per tick. lifesteal: fraction of damage dealt returned as HP,
	## and the most HP one damage event may return.
	var heal_per_tick: float
	var lifesteal_fraction: float
	var lifesteal_cap: float
	## Who applied it (damage_over_time ticks are credited to them), as an object id so a freed
	## applier cannot be passed around by accident. Latest applier wins on refresh. 0 = none.
	var source_id: int = 0

	func source_node() -> Node:
		return instance_from_id(source_id) as Node if source_id != 0 else null

	func _init(p_status_id: String, status_def: Dictionary, duration: float, p_source: Node = null) -> void:
		status_id = p_status_id
		effect_type = status_def.get("effect_type", "damage_over_time")
		damage_per_tick = status_def.get("damage_per_tick", 0.0)
		damage_type = status_def.get("damage_type", "physical")
		tick_interval = maxf(status_def.get("tick_interval", 1.0), 0.05)
		time_remaining = duration
		time_to_next_tick = tick_interval
		heal_per_tick = status_def.get("heal_per_tick", 0.0)
		lifesteal_fraction = status_def.get("fraction", 0.0)
		lifesteal_cap = status_def.get("max_heal_per_hit", 0.0)
		source_id = p_source.get_instance_id() if p_source != null else 0

	func refresh(status_def: Dictionary, duration: float, p_source: Node = null) -> void:
		damage_per_tick = status_def.get("damage_per_tick", damage_per_tick)
		heal_per_tick = status_def.get("heal_per_tick", heal_per_tick)
		lifesteal_fraction = status_def.get("fraction", lifesteal_fraction)
		lifesteal_cap = status_def.get("max_heal_per_hit", lifesteal_cap)
		if p_source != null:
			source_id = p_source.get_instance_id()
		time_remaining = maxf(time_remaining, duration)


func _ready() -> void:
	if health_path != NodePath():
		health = get_node(health_path) as Health
	tree_exiting.connect(_stop_all_flames)


## Applying the same status_id again refreshes its duration (does not stack
## multiple instances of the same status). `source` is who applied it; a damage tick
## is credited to it (so lifesteal covers DoTs). It may be null.
func apply_status(status_id: String, status_def: Dictionary, duration: float, source: Node = null) -> void:
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
		(_active[status_id] as ActiveStatus).refresh(status_def, duration, source)
	else:
		var created := ActiveStatus.new(status_id, status_def, duration, source)
		_active[status_id] = created
		if created.effect_type == "stun":
			_stun_count += 1
		elif created.effect_type == "lifesteal":
			_lifesteal_count += 1
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
	return _stun_count > 0


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
	_expired.clear()
	for status_id: String in _active:
		var active: ActiveStatus = _active[status_id]
		active.time_remaining -= delta
		active.time_to_next_tick -= delta
		if active.time_to_next_tick <= 0.0:
			active.time_to_next_tick += active.tick_interval
			_tick(active)
		if active.time_remaining <= 0.0:
			_expired.append(status_id)
	for status_id: String in _expired:
		var expired_type: String = (_active[status_id] as ActiveStatus).effect_type
		if expired_type == "stun":
			_stun_count -= 1
		elif expired_type == "lifesteal":
			_lifesteal_count -= 1
		_active.erase(status_id)
		_stop_flame(status_id)
		status_expired.emit(status_id)


func _tick(active: ActiveStatus) -> void:
	if health == null:
		return
	if active.effect_type == "damage_over_time":
		health.take_damage(active.damage_per_tick, active.damage_type, Vector3.ZERO, active.source_node(), Health.KIND_DOT)
	elif active.effect_type == "heal_over_time":
		# A tick at full HP does nothing (no popup, no cue).
		if not health.is_dead() and health.get_current_health() < health.get_max_health():
			health.heal(active.heal_per_tick)


## The owner dealt `amount` damage (the owner's `damage_dealt` signal, from any source:
## hits, DoT ticks). Every active lifesteal status returns fraction x amount as HP, at most
## its per-hit cap, once per damage event. Returns the HP healed (0 when nothing applies).
func on_damage_dealt(amount: float) -> float:
	if health == null or health.is_dead() or amount <= 0.0 or _lifesteal_count <= 0:
		return 0.0
	var total: float = 0.0
	for active: ActiveStatus in _active.values():
		if active.effect_type == "lifesteal":
			total += minf(amount * active.lifesteal_fraction, active.lifesteal_cap)
	if total <= 0.0:
		return 0.0
	var before: float = health.get_current_health()
	health.heal(total)
	var healed: float = health.get_current_health() - before
	if healed > 0.0:
		lifesteal_healed.emit(healed)
	return healed


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
