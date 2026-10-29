class_name AttackArcVisual
extends MeshInstance3D
## Flat placeholder wedge on the ground that matches an attack's true hit
## area (range and half angle). Telegraph while winding up, flash on swing.
## Forward is local -Z, so parent it to the player.
##
## The two states look different on purpose (s3-c): the wind-up is a pale
## OUTLINE at full reach with a faint fill growing in from the origin and a
## pulsing edge; the swing is a SOLID flash in the attack color with a bright
## white edge. The solid fan is this node's own mesh (it is the hit area, used by
## the sizing tests); the telegraph parts are children, so hiding this node
## hides everything.

const SEGMENTS := 20
const GROUND_OFFSET := 0.06
const TELEGRAPH_ALPHA_MIN := 0.15
const TELEGRAPH_ALPHA_MAX := 0.6
const FLASH_ALPHA := 0.95
const FLASH_HOLD_FRACTION := 0.45
const EDGE_THICKNESS := 0.1
const TELEGRAPH_WHITEN := 0.75
const FILL_START_SCALE := 0.15
const FILL_ALPHA := 0.3
const EDGE_PULSE_CYCLES := 3.0
const ON_TOP_PRIORITY := 10

var _material := StandardMaterial3D.new()
var _color: Color = Color.WHITE
var _tween: Tween = null
var _fill := MeshInstance3D.new()
var _edge := MeshInstance3D.new()
var _fill_material := StandardMaterial3D.new()
var _edge_material := StandardMaterial3D.new()


func setup(attack_range: float, half_angle_degrees: float, color: Color) -> void:
	_color = color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color, 0.0)
	mesh = build_fan(attack_range, half_angle_degrees)
	material_override = _material
	position.y = GROUND_OFFSET
	for part: Array in [[_fill, _fill_material, mesh], [_edge, _edge_material, build_outline(attack_range, half_angle_degrees, EDGE_THICKNESS)]]:
		var node: MeshInstance3D = part[0]
		var material: StandardMaterial3D = part[1]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.mesh = part[2]
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position.y = 0.01
		node.visible = false
		add_child(node)
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


## Outline as a ring-shaped band: an arc inside `attack_range` plus the two side
## edges, all drawn inward of the true boundary so nothing shows past reach.
static func build_outline(attack_range: float, half_angle_degrees: float, thickness: float) -> ArrayMesh:
	var half := deg_to_rad(half_angle_degrees)
	var inner: float = maxf(attack_range - thickness, 0.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(SEGMENTS):
		var a0 := -half + 2.0 * half * float(i) / float(SEGMENTS)
		var a1 := -half + 2.0 * half * float(i + 1) / float(SEGMENTS)
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		vertices.append_array([o0 * inner, o0 * attack_range, o1 * attack_range, o0 * inner, o1 * attack_range, o1 * inner])
	for side: float in [-1.0, 1.0]:
		var a: float = half * side
		var along := Vector3(sin(a), 0.0, -cos(a))
		var inward := Vector3(-cos(a), 0.0, -sin(a)) * side
		var tip: Vector3 = Vector3.ZERO
		var far: Vector3 = along * attack_range
		var step: Vector3 = inward * thickness
		vertices.append_array([tip, far, far + step, tip, far + step, tip + step])
	for n in range(vertices.size()):
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var outline := ArrayMesh.new()
	outline.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return outline


## progress 0..1 through the wind-up: a pale outline at full reach (pulsing, so
## it cannot be mistaken for the solid impact flash) with a faint fill growing
## in from the origin toward the swing. No allocation per call.
func show_windup(progress: float) -> void:
	_kill_tween()
	var p: float = clampf(progress, 0.0, 1.0)
	var pale: Color = _color.lerp(Color.WHITE, TELEGRAPH_WHITEN)
	visible = true
	_material.albedo_color = Color(_color, 0.0)
	var grow: float = lerpf(FILL_START_SCALE, 1.0, p)
	_fill.visible = true
	_fill.scale = Vector3(grow, 1.0, grow)
	_fill_material.albedo_color = Color(pale, FILL_ALPHA)
	_edge.visible = true
	_edge_material.albedo_color = Color(pale, 0.75 + 0.25 * sin(p * EDGE_PULSE_CYCLES * TAU))


## The impact: a solid fan in the attack color plus a bright white edge, fading out.
func flash(duration: float) -> void:
	_kill_tween()
	visible = true
	_fill.visible = false
	_material.albedo_color = Color(_color, FLASH_ALPHA)
	_edge.visible = true
	_edge_material.albedo_color = Color(Color.WHITE, 1.0)
	if not is_inside_tree() or duration <= 0.0:
		hide_now()
		return
	_tween = create_tween().set_parallel(true)
	# Hold full strength for the first part so a still frame catches it, then fade.
	var hold: float = duration * FLASH_HOLD_FRACTION
	_tween.tween_property(_material, "albedo_color:a", 0.0, duration - hold).set_delay(hold)
	_tween.tween_property(_edge_material, "albedo_color:a", 0.0, duration - hold).set_delay(hold)
	_tween.chain().tween_callback(hide_now)


## Draws the outline over everything (no depth test), so a body standing on the wedge cannot hide where the hit
## area ends. Only the outline: the fill stays depth-tested, so it never tints the player or an enemy. The outline
## is drawn at the true reach, so this changes visibility only, never the size shown.
func set_outline_on_top(on_top: bool) -> void:
	_edge_material.no_depth_test = on_top
	_edge_material.render_priority = ON_TOP_PRIORITY if on_top else 0


func hide_now() -> void:
	_kill_tween()
	visible = false
	_fill.visible = false
	_edge.visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
