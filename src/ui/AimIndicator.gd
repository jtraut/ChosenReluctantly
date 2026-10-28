class_name AimIndicator
extends Node3D
## Quiet ground aim indicator: a ring-and-dot reticle at the mouse aim point and
## a row of fading dots from the player along the direction they FACE (which is
## where every card actually fires; it trails the mouse during a fast turn).
##
## Not an effect: it lives as long as the player is alive, so it owns three
## meshes' worth of nodes instead of using EffectPool (a held pooled effect would
## eat the cap and fight the Burn-flame eviction rule). It reuses the pool's
## shared ring and disc meshes. It sits under every attack and telegraph shape
## (lower than EffectPool.GROUND_OFFSET, lower render priority), is dots and a
## ring so it never reads as a wedge, and is cream so it is not a fire color.
##
## Hidden while the player is dead (which covers the Game Over screen, since the
## arena reloads on restart), with no camera, or when disabled in data/ui.json.

## Capture-only: with no camera (frozen aim) draw the reticle this far in front of
## the player. 0 disables it. Set by Scenario ("aim_preview_distance").
var preview_distance: float = 0.0

var _player: Player = null
var _config: Dictionary = {}
var _reticle: MeshInstance3D = null
var _center: MeshInstance3D = null
var _dots: Array[MeshInstance3D] = []


## Creates the indicator under `parent` for `player`. Returns it.
static func attach(parent: Node, player: Player) -> AimIndicator:
	var indicator := AimIndicator.new()
	indicator.name = "AimIndicator"
	parent.add_child(indicator)
	indicator.setup(player)
	return indicator


func setup(player: Player) -> void:
	_player = player
	_config = UiConfig.aim()
	var color := Color.html(String(_config["color"]))
	_reticle = _make_part(EffectPool.ring_mesh(), color, float(_config["reticle_alpha"]), float(_config["reticle_radius"]))
	_center = _make_part(EffectPool.disc_mesh(), color, float(_config["reticle_alpha"]), float(_config["center_dot_radius"]))
	var count: int = int(_config["dot_count"])
	for i in range(count):
		var t: float = float(i) / float(maxi(count - 1, 1))
		var alpha: float = lerpf(float(_config["dot_alpha_near"]), float(_config["dot_alpha_far"]), t)
		_dots.append(_make_part(EffectPool.disc_mesh(), color, alpha, float(_config["dot_radius"])))
	_hide_all()
	set_process(bool(_config["enabled"]))


func _make_part(mesh: Mesh, color: Color, alpha: float, radius: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.render_priority = -2
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.scale = Vector3(radius, 1.0, radius)
	add_child(part)
	return part


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree() or _player.is_dead():
		_hide_all()
		return
	var origin: Vector3 = _player.global_position
	var direction: Vector3 = _player.get_aim_direction()
	var point: Variant = _player.get_aim_point()
	if point == null and preview_distance > 0.0:
		point = origin + direction * preview_distance
	if point == null:
		_hide_all()
		return
	var ground_y: float = origin.y + float(_config["ground_offset"])
	var target: Vector3 = point
	var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	_place(_reticle, Vector3(target.x, ground_y, target.z))
	_place(_center, Vector3(target.x, ground_y, target.z))
	var length: float = minf(flat.length() - float(_config["reticle_radius"]), float(_config["max_length"]))
	for i in range(_dots.size()):
		var along: float = float(_config["dot_start_gap"]) + float(i) * float(_config["dot_spacing"])
		var dot := _dots[i]
		dot.visible = along <= length
		if dot.visible:
			var spot: Vector3 = origin + direction * along
			dot.position = Vector3(spot.x, ground_y, spot.z)


func _place(part: MeshInstance3D, position_world: Vector3) -> void:
	part.visible = true
	part.position = position_world


func _hide_all() -> void:
	if _reticle != null:
		_reticle.visible = false
	if _center != null:
		_center.visible = false
	for dot in _dots:
		dot.visible = false


## True while any part is drawn (tests).
func is_showing() -> bool:
	return _reticle != null and _reticle.visible
