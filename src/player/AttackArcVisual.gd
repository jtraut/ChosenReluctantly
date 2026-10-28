class_name AttackArcVisual
extends MeshInstance3D
## Flat placeholder wedge on the ground that matches an attack's true hit
## area (range and half angle). Telegraph while winding up, flash on swing.
## Forward is local -Z, so parent it to the player.

const SEGMENTS := 20
const GROUND_OFFSET := 0.06
const TELEGRAPH_ALPHA_MIN := 0.15
const TELEGRAPH_ALPHA_MAX := 0.6
const FLASH_ALPHA := 0.8

var _material := StandardMaterial3D.new()
var _color: Color = Color.WHITE
var _tween: Tween = null


func setup(attack_range: float, half_angle_degrees: float, color: Color) -> void:
	_color = color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color, 0.0)
	mesh = build_fan(attack_range, half_angle_degrees)
	material_override = _material
	position.y = GROUND_OFFSET
	visible = false


static func build_fan(attack_range: float, half_angle_degrees: float) -> ArrayMesh:
	var half := deg_to_rad(half_angle_degrees)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(SEGMENTS):
		var a0 := -half + 2.0 * half * float(i) / float(SEGMENTS)
		var a1 := -half + 2.0 * half * float(i + 1) / float(SEGMENTS)
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(sin(a1), 0.0, -cos(a1)) * attack_range)
		vertices.append(Vector3(sin(a0), 0.0, -cos(a0)) * attack_range)
		for n in range(3):
			normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var fan := ArrayMesh.new()
	fan.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return fan


## progress 0..1 through the wind-up: the telegraph brightens toward the swing.
func show_windup(progress: float) -> void:
	_kill_tween()
	visible = true
	_material.albedo_color = Color(_color, lerpf(TELEGRAPH_ALPHA_MIN, TELEGRAPH_ALPHA_MAX, clampf(progress, 0.0, 1.0)))


func flash(duration: float) -> void:
	_kill_tween()
	visible = true
	_material.albedo_color = Color(_color, FLASH_ALPHA)
	if not is_inside_tree() or duration <= 0.0:
		visible = false
		return
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color:a", 0.0, duration)
	_tween.tween_callback(func() -> void: visible = false)


func hide_now() -> void:
	_kill_tween()
	visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
