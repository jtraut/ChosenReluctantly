class_name PooledEffect
extends MeshInstance3D
## One reusable flat/blob visual. Owned and advanced by EffectPool (no _process
## here, no tweens, no per-frame allocation): the pool sets the fields in
## play() and calls step() every frame until it returns false.

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


func _init() -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Advances the animation; returns false once finished.
func step(delta: float) -> bool:
	age += delta
	var t: float = clampf(age / duration, 0.0, 1.0)
	_apply(t)
	return age < duration


func _apply(t: float) -> void:
	var s: float = base_size * lerpf(scale_from, scale_to, t)
	scale = Vector3(s, 1.0, s) if is_flat else Vector3(s, s, s)
	material.albedo_color = Color(color.r, color.g, color.b, lerpf(alpha_from, alpha_to, t))


func begin() -> void:
	active = true
	age = 0.0
	_apply(0.0)
	visible = true


func finish() -> void:
	active = false
	visible = false
