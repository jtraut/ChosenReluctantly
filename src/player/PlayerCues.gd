class_name PlayerCues
extends Node
## Player-side readability cues that belong to no single card (C1-e). Attached by Main (like
## AimIndicator and PlayerOcclusionCue), so Player and its flash code stay untouched. Pure display:
## it listens to signals the Player and its Health and StatusEffectManager already emit.
##
##   Ghost (Player.pass_through_changed): the body fades (GeometryInstance3D.transparency, which the hit flash
##   and the death tween do not touch, unlike the albedo) and a ring breathes at the feet while pass-through is
##   on. The ring is the cue that does not rely on the fade or on a colour.
##   Heal number (Health.health_changed): every HP the player gains is shown as "+N", batched so a Flurry's
##   four Leech heals are one number. Healing Potion, Regeneration and Leech all use it.
##   Leech drain (StatusEffectManager.lifesteal_healed + Player.damage_dealt): a bead flies from the damaged
##   target to the player, and a flash lands on the player.
##
## Look and timing: data/vfx.json (ghost_*, heal_number_*, drain_*).

var _player: Player = null
var _ghost_ring: PooledEffect = null
var _ghost_ring_generation: int = 0
var _last_hp: float = -1.0
var _pending_heal: float = 0.0
var _heal_wait: float = 0.0
## Leech: the heal and the hit that caused it arrive as two signals in an order that is not guaranteed, so each
## stamps the physics frame it arrived in, and the pulse fires when both are stamped for the same frame.
var _heal_frame: int = -1
var _dealt_frame: int = -1
var _dealt_target_id: int = 0
var _last_pulse_msec: int = -1000000


## Adds the cues under `player`. Null when there is no player.
static func attach(player: Player) -> PlayerCues:
	if player == null:
		return null
	var cues := PlayerCues.new()
	cues.name = "PlayerCues"
	player.add_child(cues)
	cues.setup(player)
	return cues


func setup(player: Player) -> void:
	_player = player
	set_process(false)
	player.pass_through_changed.connect(_on_pass_through_changed)
	player.health.health_changed.connect(_on_health_changed)
	_last_hp = player.health.get_current_health()
	player.damage_dealt.connect(_on_damage_dealt)
	if player.status_manager != null:
		player.status_manager.lifesteal_healed.connect(_on_lifesteal_healed)


func _exit_tree() -> void:
	_stop_ghost_ring()


# --- pure rules (unit-tested) ------------------------------------------------

## Body transparency (0 solid .. 1 invisible) of the ghosted player for an opacity from data.
static func ghost_transparency(body_alpha: float) -> float:
	return clampf(1.0 - body_alpha, 0.0, 1.0)


## HP gained between two readings (0 when it fell or stayed).
static func heal_between(previous_hp: float, current_hp: float) -> float:
	return maxf(current_hp - previous_hp, 0.0)


## The batched heal number to show now: `total` rounded, or 0 when it would show "+0".
static func heal_number_value(total: float) -> int:
	return roundi(total) if total >= 0.5 else 0


## A drain pulse is due when the heal and the hit that caused it both arrived this frame.
static func drain_due(heal_frame: int, dealt_frame: int, now_frame: int) -> bool:
	return heal_frame == now_frame and dealt_frame == now_frame


## Whether another drain pulse may start, `min_interval` seconds after the last (so a flurry does not stack beads).
static func drain_allowed(now_msec: int, last_msec: int, min_interval: float) -> bool:
	return float(now_msec - last_msec) >= min_interval * 1000.0


# --- ghost -------------------------------------------------------------------

func _on_pass_through_changed(active: bool) -> void:
	if _player == null or not is_instance_valid(_player) or _player.body_mesh == null:
		return
	if active:
		_player.body_mesh.transparency = ghost_transparency(VfxConfig.marker("ghost_body_alpha"))
		if _ghost_ring == null:
			var pool := EffectPool.for_world(_player.get_parent())
			_ghost_ring = TemplateVfx.ghost_ring(pool, _player)
			_ghost_ring_generation = _ghost_ring.generation if _ghost_ring != null else 0
	else:
		_player.body_mesh.transparency = 0.0
		_stop_ghost_ring()


func _stop_ghost_ring() -> void:
	if _ghost_ring == null:
		return
	if _player != null and is_instance_valid(_player):
		var pool := EffectPool.for_world(_player.get_parent())
		if pool != null:
			pool.stop(_ghost_ring, _ghost_ring_generation)
	_ghost_ring = null


## True while the ghost look is on (tests).
func is_ghosted() -> bool:
	return _ghost_ring != null or (_player != null and _player.body_mesh != null and _player.body_mesh.transparency > 0.0)


# --- heal number ---------------------------------------------------------------

func _on_health_changed(current: float, _maximum: float) -> void:
	var gained: float = heal_between(_last_hp, current)
	_last_hp = current
	if gained <= 0.0:
		return
	_pending_heal += gained
	set_process(true)


func _process(delta: float) -> void:
	if _pending_heal <= 0.0:
		set_process(false)
		return
	_heal_wait -= delta
	if _heal_wait > 0.0:
		return
	var value: int = heal_number_value(_pending_heal)
	_pending_heal = 0.0
	_heal_wait = VfxConfig.marker("heal_number_interval")
	if value > 0 and _player != null and is_instance_valid(_player) and not _player.is_dead():
		Juice.spawn_heal_number(_player.global_position + Vector3(VfxConfig.marker("heal_number_offset_x"), 0.0, 0.0), float(value))


# --- leech drain ---------------------------------------------------------------

func _on_lifesteal_healed(_amount: float) -> void:
	_heal_frame = Engine.get_physics_frames()
	_try_drain()


func _on_damage_dealt(target: Node, _amount: float, _damage_type: String, _kind: StringName) -> void:
	_dealt_frame = Engine.get_physics_frames()
	_dealt_target_id = target.get_instance_id() if target != null else 0
	_try_drain()


func _try_drain() -> void:
	var now_frame: int = Engine.get_physics_frames()
	if not drain_due(_heal_frame, _dealt_frame, now_frame):
		return
	_heal_frame = -1
	_dealt_frame = -1
	var now_msec: int = Time.get_ticks_msec()
	if not drain_allowed(now_msec, _last_pulse_msec, VfxConfig.marker("drain_min_interval")):
		return
	var target := instance_from_id(_dealt_target_id) as Node3D if _dealt_target_id != 0 else null
	if target == null or not is_instance_valid(target) or _player == null or not is_instance_valid(_player):
		return
	_last_pulse_msec = now_msec
	var lift := Vector3(0.0, 1.0, 0.0)
	TemplateVfx.drain_pulse(EffectPool.for_world(_player.get_parent()), target.global_position + lift, _player.global_position + lift)
