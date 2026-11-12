extends Node
class_name StatusEffectManager
## Generic container of active timed status effects (Burn now; Chill, Soaked,
## etc. later). A status is data (data/statuses.json) describing an
## "effect_type" - only "damage_over_time" exists today, so adding a new
## damage-over-time status (different element, different tick) is a data
## change, not a code change. A genuinely new effect_type is a new branch in
## `_tick()`.

## Stat prefix: "status_damage_mult.burn" scales the damage-over-time ticks the caster's burns deal (base 1.0).
const STATUS_DAMAGE_MULT_PREFIX := "status_damage_mult."
## BD3a stacking: a status's `stacking.max_stacks` (default 1) is read through the applier's `status_max_stacks.<id>` stat
## (additive: +4 on Bleed lets it reach 5 stacks), so a keystone buff or a relic can raise it. Burn and Bleed ship at 1 (D25 = A).
const STATUS_MAX_STACKS_PREFIX := "status_max_stacks."
## BD3a: the applier's `status_tick_rate.<id>` stat (base 1.0) divides the tick interval (1.5 = ticks 50% faster).
const STATUS_TICK_RATE_PREFIX := "status_tick_rate."
const MIN_TICK_RATE := 0.1

signal status_applied(status_id: String)
signal status_expired(status_id: String)
## An already-active status was applied again (duration kept or extended, tick phase kept).
## `status_applied` stays "began", so cues that start on it never double up.
signal status_refreshed(status_id: String)
## A stun landed on an immune target (boss, or diminishing returns): nothing was applied.
## ux can show an "immune" popup from this.
signal status_resisted(status_id: String)
## The stack count of an active damage-over-time status changed (a reapply added a stack). ux shows "Bleed x3" from this
## and from stacks_of().
signal status_stacks_changed(status_id: String, stacks: int)
## A detonate_status effect burst the status: `amount` is the damage dealt before mitigation, `stacks` the stacks it had.
signal status_detonated(status_id: String, amount: float, stacks: int)
## Lifesteal returned HP to the owner (amount actually healed). ux can show a heal cue.
signal lifesteal_healed(amount: float)

@export var health_path: NodePath

var health: Health = null:
	set = _set_health
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
## The status a detonate_status burst is dealing damage for right now ("" = none); see _on_owner_died.
var _detonating_id: String = ""


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
	## The status's "visual" block from data (a reference, not a copy); {} when it has none. Read by the tick cues.
	var cue: Dictionary = {}
	## Where the status came from ("card:<id>", "relic:<id>", "light", ...), latest applier wins on refresh. It rides on the
	## CombatEvents status events, so a relic can tell a status its own effects applied (the recursion guard).
	var origin: String = ""
	## BD3a: how many stacks are on (1 for everything that does not stack), and the status's own max before stat modifiers.
	var stacks: int = 1
	var base_max_stacks: int = 1
	## MAP3b: `stacking.hard_cap`, the ceiling above the stat-raised cap (0 = none).
	var hard_cap: int = 0

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
		var stacking: Variant = status_def.get("stacking")
		if typeof(stacking) == TYPE_DICTIONARY:
			base_max_stacks = maxi(int((stacking as Dictionary).get("max_stacks", 1)), 1)
			hard_cap = maxi(int((stacking as Dictionary).get("hard_cap", 0)), 0)
		var visual: Variant = status_def.get("visual")
		if typeof(visual) == TYPE_DICTIONARY:
			cue = visual

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


## Assigning `health` also listens for its death (once), so the owner's statuses can announce "owner_died" before the
## node is freed. This connects in _ready, ahead of the owner's own died handler, so the order is fixed.
func _set_health(value: Health) -> void:
	if health != null and health.died.is_connected(_on_owner_died):
		health.died.disconnect(_on_owner_died)
	health = value
	if health != null and not health.died.is_connected(_on_owner_died):
		health.died.connect(_on_owner_died)


## The owner died: tell the relay each status ended with reason owner_died. Relay only: nothing is erased or stopped here
## (the node is about to be freed, and dying has never emitted status_expired; that stays true).
func _on_owner_died() -> void:
	var relay := CombatLink.events()
	if relay == null:
		return
	for status_id: String in _active.keys():
		var active: ActiveStatus = _active[status_id]
		# The status a detonate_status burst just killed the owner with ends as "detonated", not "owner_died", so a death
		# trigger (Pyre Insurance) does not fire on top of the burst.
		var reason: String = CombatEventsRelay.STATUS_END_DETONATED if status_id == _detonating_id else CombatEventsRelay.STATUS_END_OWNER_DIED
		relay.notify_status_ended(get_parent(), status_id, reason, active.source_node(), active.origin)


## Ends an active status early (a relic or effect that uses it up). Emits status_ended with reason "consumed" and the
## existing status_expired signal's cues are stopped as for an expiry. Returns false when the status was not active.
func consume_status(status_id: String) -> bool:
	if not _active.has(status_id):
		return false
	var active: ActiveStatus = _active[status_id]
	_erase_status(status_id)
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_status_ended(get_parent(), status_id, CombatEventsRelay.STATUS_END_CONSUMED, active.source_node(), active.origin)
	status_expired.emit(status_id)
	return true


func _erase_status(status_id: String) -> void:
	var expired_type: String = (_active[status_id] as ActiveStatus).effect_type
	if expired_type == "stun":
		_stun_count -= 1
	elif expired_type == "lifesteal":
		_lifesteal_count -= 1
	_active.erase(status_id)
	_stop_flame(status_id)


## Applying the same status_id again refreshes its duration (does not stack
## multiple instances of the same status). `source` is who applied it; a damage tick
## is credited to it (so lifesteal covers DoTs). It may be null.
func apply_status(status_id: String, status_def: Dictionary, duration: float, source: Node = null, origin: String = "") -> void:
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
		var refreshed: ActiveStatus = _active[status_id]
		refreshed.refresh(status_def, duration, source)
		if origin != "":
			refreshed.origin = origin
		# BD3a: a reapply adds a stack up to the max (1 by default, so nothing stacks unless data or a stat says so).
		if refreshed.effect_type == "damage_over_time" and refreshed.stacks < _max_stacks(refreshed, source):
			refreshed.stacks += 1
			status_stacks_changed.emit(status_id, refreshed.stacks)
	else:
		var created := ActiveStatus.new(status_id, status_def, duration, source)
		created.origin = origin
		if created.effect_type == "damage_over_time":
			created.time_to_next_tick = created.tick_interval / _tick_rate(created, source)
		_active[status_id] = created
		if created.effect_type == "stun":
			_stun_count += 1
		elif created.effect_type == "lifesteal":
			_lifesteal_count += 1
		status_applied.emit(status_id)
		var relay := CombatLink.events()
		if relay != null:
			relay.notify_status_applied(get_parent(), status_id, source, origin)
	# A refresh emits nothing, so check the flame is still alive (it could have
	# been recycled) and restart it if not.
	_ensure_flame(status_id, status_def)
	if was_active:
		status_refreshed.emit(status_id)


func has_status(status_id: String) -> bool:
	return _active.has(status_id)


## Stacks on an active status (0 when it is not active, 1 for a status that does not stack).
func stacks_of(status_id: String) -> int:
	if not _active.has(status_id):
		return 0
	return (_active[status_id] as ActiveStatus).stacks


## The most stacks the status can reach for its current applier right now (data `stacking.max_stacks` through the
## applier's `status_max_stacks.<id>` stat; at least 1). 0 when the status is not active.
func max_stacks_of(status_id: String) -> int:
	if not _active.has(status_id):
		return 0
	var active: ActiveStatus = _active[status_id]
	return _max_stacks(active, active.source_node())


## How many more damage ticks an active status will deal if left alone (0 when inactive or not a damage_over_time).
func remaining_ticks(status_id: String) -> int:
	if not _active.has(status_id):
		return 0
	var active: ActiveStatus = _active[status_id]
	if active.effect_type != "damage_over_time":
		return 0
	var interval: float = active.tick_interval / _tick_rate(active, active.source_node())
	if active.time_remaining < active.time_to_next_tick - 0.000001:
		return 0
	return int(floorf((active.time_remaining - maxf(active.time_to_next_tick, 0.0)) / interval + 0.000001)) + 1


## The `detonate_status` effect on this owner: deals remaining ticks x damage per tick x stacks x `multiplier` at once (through the
## same damage path as a tick, so Bleed meets armor and Burn meets resistance), credited to `source`. The burst lands while the
## status is still on, so a kill by it counts as an enemy dying with the status; only then is the status removed, ending with
## reason "detonated" (not "expired", so Pyre Insurance does not chain). Returns the damage dealt before mitigation (0 when
## the status is not an active damage_over_time with ticks left; nothing is removed then).
func detonate_status(status_id: String, multiplier: float, source: Node = null, origin: String = "") -> float:
	if health == null or health.is_dead() or not _active.has(status_id):
		return 0.0
	var active: ActiveStatus = _active[status_id]
	var ticks: int = remaining_ticks(status_id)
	if ticks <= 0:
		return 0.0
	var stacks: int = active.stacks
	var amount: float = float(ticks) * active.damage_per_tick * float(stacks) * _status_damage_mult(active, active.source_node()) * multiplier
	var look: Dictionary = ElementVisuals.visual_for_damage_type(active.damage_type)
	_detonating_id = status_id
	health.take_damage(amount, active.damage_type, Vector3.ZERO, source, Health.KIND_HIT, origin)
	_detonating_id = ""
	status_detonated.emit(status_id, amount, stacks)
	var owner_node := get_parent() as Node3D
	var pool := _vfx_pool()
	if pool != null and owner_node != null and owner_node.is_inside_tree():
		TemplateVfx.projectile_impact(pool, owner_node.global_position + Vector3(0.0, TemplateVfx.body_top(owner_node) * 0.6, 0.0), look)
	if _active.has(status_id):
		var ended: ActiveStatus = _active[status_id]
		_erase_status(status_id)
		# A kill already reported the end (owner_died's turn, as "detonated"); a survivor reports it here.
		if not health.is_dead():
			var relay := CombatLink.events()
			if relay != null:
				relay.notify_status_ended(get_parent(), status_id, CombatEventsRelay.STATUS_END_DETONATED, ended.source_node(), ended.origin)
			status_expired.emit(status_id)
	return amount


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


## Seconds left on an active status (0 when it is not active).
func status_time_left(status_id: String) -> float:
	if not _active.has(status_id):
		return 0.0
	return (_active[status_id] as ActiveStatus).time_remaining


func active_status_ids() -> Array:
	return _active.keys()


func _process(delta: float) -> void:
	_clock += delta
	if _active.is_empty():
		return
	_expired.clear()
	# Over a copy of the keys: a tick's damage reaches the relay, and a relic reacting to it may apply a status to this owner.
	for status_id: String in _active.keys():
		if not _active.has(status_id):
			continue  # consumed by a relay listener during an earlier tick
		var active: ActiveStatus = _active[status_id]
		active.time_remaining -= delta
		active.time_to_next_tick -= delta
		if active.time_to_next_tick <= 0.0:
			active.time_to_next_tick += active.tick_interval / _tick_rate(active, active.source_node())
			_tick(active)
		if active.time_remaining <= 0.0:
			_expired.append(status_id)
	for status_id: String in _expired:
		var ended: ActiveStatus = _active[status_id]
		_erase_status(status_id)
		status_expired.emit(status_id)
		var relay := CombatLink.events()
		if relay != null:
			relay.notify_status_ended(get_parent(), status_id, CombatEventsRelay.STATUS_END_EXPIRED, ended.source_node(), ended.origin)


func _tick(active: ActiveStatus) -> void:
	if health == null:
		return
	if active.effect_type == "damage_over_time":
		var source: Node = active.source_node()
		health.take_damage(active.damage_per_tick * float(active.stacks) * _status_damage_mult(active, source), active.damage_type, Vector3.ZERO, source, Health.KIND_DOT, "status:" + active.status_id)
		if String(active.cue.get("kind", "")) == "drips":
			_tick_cue_drop(active.cue)
	elif active.effect_type == "heal_over_time":
		# A tick at full HP does nothing (no popup, no cue).
		if not health.is_dead() and health.get_current_health() < health.get_max_health():
			health.heal(active.heal_per_tick)
			if String(active.cue.get("kind", "")) == "ring":
				var owner_node := get_parent() as Node3D
				if owner_node != null and owner_node.is_inside_tree():
					TemplateVfx.heal_mote(_vfx_pool(), owner_node.global_position)


## The applier's `status_damage_mult.<status_id>` stat (base 1.0) read at tick time, so a buff cast after the status
## landed still counts. 1.0 when the applier is gone or has no stat stack.
func _status_damage_mult(active: ActiveStatus, source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 1.0
	var mods: Variant = source.get(&"stat_modifiers")
	if not (mods is StatModifiers):
		return 1.0
	return (mods as StatModifiers).apply(STATUS_DAMAGE_MULT_PREFIX + active.status_id, 1.0)


## The status's current stack cap: its data cap through the applier's `status_max_stacks.<id>` stat. At least 1.
func _max_stacks(active: ActiveStatus, source: Node) -> int:
	var base: float = float(active.base_max_stacks)
	if source != null and is_instance_valid(source):
		var mods: Variant = source.get(&"stat_modifiers")
		if mods is StatModifiers:
			base = (mods as StatModifiers).apply(STATUS_MAX_STACKS_PREFIX + active.status_id, base)
	var capped: int = maxi(roundi(base), 1)
	return mini(capped, active.hard_cap) if active.hard_cap > 0 else capped


## The applier's `status_tick_rate.<id>` stat (base 1.0, never below MIN_TICK_RATE); the tick interval is divided by it.
func _tick_rate(active: ActiveStatus, source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 1.0
	var mods: Variant = source.get(&"stat_modifiers")
	if not (mods is StatModifiers):
		return 1.0
	return maxf((mods as StatModifiers).apply(STATUS_TICK_RATE_PREFIX + active.status_id, 1.0), MIN_TICK_RATE)


## Bleed's tick look: a drop falls off the body, on the same beat as the damage number.
func _tick_cue_drop(block: Dictionary) -> void:
	var owner_node := get_parent() as Node3D
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var spot: Vector3 = owner_node.global_position + Vector3(float(block.get("offset", 0.5)), TemplateVfx.body_top(owner_node) * 0.6, 0.0)
	TemplateVfx.bleed_drop(_vfx_pool(), spot, Color.html(String(block.get("color", "#d4163c"))), float(block.get("size", 0.09)))


## The owner dealt `amount` damage (the owner's `damage_dealt` signal, from any source:
## hits, DoT ticks). Every active lifesteal status returns fraction x amount as HP, at most
## its per-hit cap, once per damage event. Returns the HP healed (0 when nothing applies).
func on_damage_dealt(amount: float) -> float:
	if health == null or health.is_dead() or amount <= 0.0 or _lifesteal_count <= 0:
		return 0.0
	if health.get_current_health() >= health.get_max_health():
		return 0.0  # nothing to restore: no healed event at full HP
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
	if not StatusDatabase.VISUAL_KINDS.has(kind):
		return
	var pool := _vfx_pool()
	var owner_node := get_parent() as Node3D
	if pool == null or owner_node == null or not owner_node.is_inside_tree():
		return
	if _flames.has(status_id) and _cue_running(pool, status_id):
		return
	_stop_flame(status_id)
	var effect: PooledEffect = null
	if kind == "drips":
		effect = TemplateVfx.status_drip(pool, owner_node, Color.html(String(block.get("color", "#d4163c"))), float(block.get("size", 0.09)),
				TemplateVfx.body_top(owner_node) * 0.6, float(block.get("offset", 0.5)))
	elif kind == "ring":
		effect = TemplateVfx.status_ring(pool, owner_node, Color.html(String(block.get("color", "#7dff9a"))), float(block.get("size", 0.75)))
	elif kind == "stars" or kind == "orbs":
		var cue_height: float = float(block["height"]) if block.has("height") else TemplateVfx.body_top(owner_node)
		var stars: Array[PooledEffect] = TemplateVfx.status_stars(pool, owner_node, Color.html(String(block.get("color", "#ffe14a"))),
				float(block.get("size", 0.15)), int(block.get("count", 3)), float(block.get("orbit_radius", 0.45)), float(block.get("orbit_hz", 1.2)),
				cue_height)
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
