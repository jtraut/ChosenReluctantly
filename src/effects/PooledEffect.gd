class_name PooledEffect
extends MeshInstance3D
## One reusable flat/blob visual. Owned and advanced by EffectPool (no _process
## here, no tweens, no per-frame allocation): the pool sets the fields in
## play() and calls step() every frame until it returns false.
##
## Optional behaviours (all plain numbers, set through the chainable setters):
## delay (hidden until it elapses), drift velocity (rising sparkles), a yaw
## sweep, y-stretch and pulse (flames), persistent (runs until stopped) and
## follow (tracks a node by instance id, never holding a reference, so a freed
## target just ends the effect).

var active: bool = false
var age: float = 0.0
var duration: float = 0.1
var scale_from: float = 1.0
var scale_to: float = 1.0
var alpha_from: float = 0.6
var alpha_to: float = 0.0
var base_size: float = 1.0
var color: Color = Color.WHITE
var is_flat: bool = true
var material: StandardMaterial3D = StandardMaterial3D.new()

var origin: Vector3 = Vector3.ZERO
var yaw_from: float = 0.0
var yaw_to: float = 0.0
var delay: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var stretch_y: float = 1.0
var pulse_amount: float = 0.0
var pulse_hz: float = 0.0
## Runs until EffectPool.stop() (or its follow target is gone); duration is ignored.
var persistent: bool = false
var follow_id: int = 0
var follow_offset: Vector3 = Vector3.ZERO
## Incremented every time the pool hands this node out, so a holder of an old
## handle cannot stop somebody else's effect (see EffectPool.stop).
var generation: int = 0


func _init() -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Advances the animation; returns false once finished (or the follow target is gone).
func step(delta: float) -> bool:
	age += delta
	if follow_id != 0:
		var target: Node3D = instance_from_id(follow_id) as Node3D
		if target == null or not target.is_inside_tree():
			return false
		origin = target.global_position + follow_offset
	_apply()
	return persistent or age < delay + duration


func _apply() -> void:
	if age < delay:
		visible = false
		return
	visible = true
	var local: float = age - delay
	var t: float = 0.0 if persistent else clampf(local / duration, 0.0, 1.0)
	var s: float = base_size * lerpf(scale_from, scale_to, t)
	if pulse_amount > 0.0:
		s *= 1.0 + pulse_amount * sin(local * pulse_hz * TAU)
	scale = Vector3(s, 1.0, s) if is_flat else Vector3(s, s * stretch_y, s)
	position = origin + velocity * local
	rotation = Vector3(0.0, lerpf(yaw_from, yaw_to, t), 0.0)
	material.albedo_color = Color(color.r, color.g, color.b, lerpf(alpha_from, alpha_to, t))


func begin() -> void:
	active = true
	age = 0.0
	delay = 0.0
	velocity = Vector3.ZERO
	stretch_y = 1.0
	pulse_amount = 0.0
	pulse_hz = 0.0
	persistent = false
	follow_id = 0
	follow_offset = Vector3.ZERO
	yaw_to = yaw_from
	_apply()


func finish() -> void:
	active = false
	persistent = false
	follow_id = 0
	visible = false


## Chainable setters (call right after EffectPool.play).
func delayed(seconds: float) -> PooledEffect:
	delay = maxf(seconds, 0.0)
	_apply()
	return self


func drifting(per_second: Vector3) -> PooledEffect:
	velocity = per_second
	return self


func sweeping_to(yaw_end: float) -> PooledEffect:
	yaw_to = yaw_end
	_apply()
	return self


func stretched(y_factor: float) -> PooledEffect:
	stretch_y = y_factor
	_apply()
	return self


func pulsing(amount: float, hz: float) -> PooledEffect:
	pulse_amount = amount
	pulse_hz = hz
	return self


func held() -> PooledEffect:
	persistent = true
	_apply()
	return self


func following(node: Node3D, offset: Vector3) -> PooledEffect:
	follow_id = node.get_instance_id() if node != null else 0
	follow_offset = offset
	if node != null:
		origin = node.global_position + offset
	_apply()
	return self
