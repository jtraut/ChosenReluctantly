class_name EffectTemplates
extends RefCounted
## The reusable building blocks every card effect is made of. A card never
## gets new code for a new effect - only a new entry in its "effects" array
## naming one of these templates and its params. Element visuals are a
## recolor/rescale of the same template, not a new template.
##
## REQUIRED_PARAMS is the single source of truth for what a template needs;
## CardSchema validates against it directly so the two can't drift apart.

const REQUIRED_PARAMS: Dictionary = {
	"projectile": ["damage", "damage_type", "speed", "max_range", "hit_radius"],
	"cone": ["damage", "damage_type", "range", "half_angle_degrees"],
	"aoe": ["damage", "damage_type", "radius"],
	"dash": ["distance", "speed"],
	"heal": ["amount"],
	"apply_status": ["status_id", "duration"],
	"buff": ["stat", "modifier_type", "value", "duration"],
}

const PROJECTILE_SCENE_PATH := "res://scenes/effects/Projectile.tscn"


static func is_known_template(template_id: String) -> bool:
	return REQUIRED_PARAMS.has(template_id)


static func required_params(template_id: String) -> Array:
	return REQUIRED_PARAMS.get(template_id, [])


static func execute(template_id: String, params: Dictionary, context: EffectContext) -> void:
	match template_id:
		"cone":
			_execute_cone(params, context)
		"aoe":
			_execute_aoe(params, context)
		"projectile":
			_execute_projectile(params, context)
		"dash":
			_execute_dash(params, context)
		"heal":
			_execute_heal(params, context)
		"apply_status":
			_execute_apply_status(params, context)
		"buff":
			_execute_buff(params, context)
		_:
			push_error("EffectTemplates: unknown template '%s'" % template_id)


static func _execute_cone(params: Dictionary, context: EffectContext) -> void:
	var space_state := context.world().direct_space_state
	var forward: Vector3 = -context.caster.global_transform.basis.z
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		space_state,
		context.caster.global_position,
		forward,
		params["range"],
		params["half_angle_degrees"],
		context.caster_team,
		CollisionLayers.HURTBOX
	)
	context.last_hits = hits
	var knockback_strength: float = params.get("knockback_strength", 0.0)
	for hurtbox: Hurtbox in hits:
		hurtbox.receive_damage(params["damage"], params["damage_type"], _knockback_from(context.caster.global_position, hurtbox.global_position, knockback_strength))


static func _execute_aoe(params: Dictionary, context: EffectContext) -> void:
	var space_state := context.world().direct_space_state
	var hits := MeleeQuery.find_hurtboxes_in_sphere(
		space_state,
		context.caster.global_position,
		params["radius"],
		context.caster_team,
		CollisionLayers.HURTBOX
	)
	context.last_hits = hits
	_play_aoe_vfx(params, context)
	var knockback_strength: float = params.get("knockback_strength", 0.0)
	for hurtbox: Hurtbox in hits:
		hurtbox.receive_damage(params["damage"], params["damage_type"], _knockback_from(context.caster.global_position, hurtbox.global_position, knockback_strength))


## Ground disc through the shared EffectPool, sized exactly to the hit radius.
## No-op when there is no pool (caster/spawn_parent not in a tree).
static func _play_aoe_vfx(params: Dictionary, context: EffectContext) -> void:
	var pool := EffectPool.for_world(context.spawn_parent)
	if pool == null or not is_instance_valid(context.caster):
		return
	pool.play(EffectPool.Shape.DISC, context.caster.global_position, float(params["radius"]), Color(1.0, 1.0, 1.0), 0.35)


## Horizontal-only impulse pointing from `origin` toward `target_pos`, scaled
## by `strength`. Zero strength (the common case - most cards have none)
## is a real Vector3.ZERO, not a tiny near-zero vector.
static func _knockback_from(origin: Vector3, target_pos: Vector3, strength: float) -> Vector3:
	if strength <= 0.0:
		return Vector3.ZERO
	var away := target_pos - origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return Vector3.ZERO
	return away.normalized() * strength


static func _execute_projectile(params: Dictionary, context: EffectContext) -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE_PATH)
	var instance: Projectile = scene.instantiate()
	context.spawn_parent.add_child(instance)
	var forward: Vector3 = -context.caster.global_transform.basis.z
	var origin: Vector3 = context.caster.global_position + forward * 0.6
	instance.hit_radius = params["hit_radius"]
	instance.knockback_strength = params.get("knockback_strength", 0.0)
	instance.launch(origin, forward, params["damage"], params["damage_type"], params["speed"], params["max_range"], context.caster_team)
	# Async flight: this effect's damage lands later, so it never populates last_hits.
	context.last_hits = []


static func _execute_dash(params: Dictionary, context: EffectContext) -> void:
	if not context.caster.has_method("start_forced_move"):
		return
	var forward: Vector3 = -context.caster.global_transform.basis.z
	var speed: float = params["speed"]
	var distance: float = params["distance"]
	var duration: float = distance / speed if speed > 0.0 else 0.0
	context.caster.start_forced_move(forward, speed, duration, params.get("invulnerable", false))


static func _execute_heal(params: Dictionary, context: EffectContext) -> void:
	if not context.caster.has_node("Health"):
		return
	var health: Health = context.caster.get_node("Health")
	health.heal(params["amount"])


static func _execute_apply_status(params: Dictionary, context: EffectContext) -> void:
	var status_id: String = params["status_id"]
	var duration: float = params["duration"]
	var status_def := StatusDatabase.get_status(status_id)
	if status_def.is_empty():
		push_error("EffectTemplates: unknown status_id '%s'" % status_id)
		return
	var targets: Array[Hurtbox] = context.last_hits
	if params.get("target", "last_hits") == "self" and context.caster.has_node("Hurtbox"):
		targets = [context.caster.get_node("Hurtbox") as Hurtbox]
	for hurtbox: Hurtbox in targets:
		if hurtbox.status_manager != null:
			hurtbox.status_manager.apply_status(status_id, status_def, duration)


static func _execute_buff(params: Dictionary, context: EffectContext) -> void:
	if not ("stat_modifiers" in context.caster):
		return
	var stat_modifiers: StatModifiers = context.caster.stat_modifiers
	var stat: String = params["stat"]
	var modifier_type: String = params["modifier_type"]
	var value: float = params["value"]
	var duration: float = params["duration"]
	var modifier_id := "buff_%d" % Time.get_ticks_usec()
	stat_modifiers.add_modifier(stat, modifier_id, modifier_type, value)
	if context.caster.is_inside_tree():
		var tree := context.caster.get_tree()
		tree.create_timer(duration).timeout.connect(func() -> void: stat_modifiers.remove_modifier(stat, modifier_id))
