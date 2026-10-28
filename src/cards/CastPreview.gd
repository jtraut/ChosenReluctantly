class_name CastPreview
extends Node3D
## The held-key cast preview: the exact ground area the previewed slot's revealed card
## will hit, drawn live under the player's facing. A held, reused node set (like
## AimIndicator), NOT pooled effects: a preview held for seconds would be evicted at the
## EffectPool cap in a busy wave and would eat pool slots the Burn flames need.
##
## What it draws comes from CastPreviewShapes (sizes via VfxSizing, the same numbers as the
## hitbox) and data/cast_preview.json (alpha, thickness, colour). It is rebuilt only when
## the previewed slot or its revealed card changes (a press, a switch, a dead-card swap,
## a new card after a cast); per frame it only moves four pivots. The look is plain on
## purpose: a low fill and a lighter edge in the card's element colour; ux-designer
## restyles it through the data file.
##
## Lives as a top-level child of the Player (so it does not turn with the body).

const MAX_PARTS := 3

var _player: Player = null
var _config: Dictionary = {}
var _parts: Array[Dictionary] = []
var _shown_slot: int = CastInput.NONE
var _shown_card: String = ""
var _pivots: Array[Node3D] = []
var _fills: Array[MeshInstance3D] = []
var _edges: Array[MeshInstance3D] = []
var _mesh_cache: Dictionary = {}
## Per part: the colour at full strength (ready look); _apply_ready() derives the dimmed look.
var _fill_colors: Array[Color] = []
var _edge_colors: Array[Color] = []
var _shown_ready: bool = true
var _colors_dirty: bool = true


func setup(player: Player) -> void:
	_player = player
	_config = CastPreviewConfig.get_config()
	top_level = true
	# Keep running under a paused tree so it hides itself the moment the preview is cancelled.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(MAX_PARTS):
		var pivot := Node3D.new()
		pivot.visible = false
		add_child(pivot)
		var fill := _make_mesh_node()
		var edge := _make_mesh_node()
		pivot.add_child(fill)
		pivot.add_child(edge)
		_pivots.append(pivot)
		_fills.append(fill)
		_edges.append(edge)
		_fill_colors.append(Color.WHITE)
		_edge_colors.append(Color.WHITE)
	set_process(bool(_config["enabled"]))


func _make_mesh_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = int(_config["render_priority"])
	# Drawn over everything in the 3D view (the targeted enemies included): it is a flat ground
	# marking seen from above, and an enemy standing in it must not hide it. HP bars and
	# damage numbers have a higher render priority, so they still sit on top of it.
	material.no_depth_test = bool(_config["over_enemies"])
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _process(_delta: float) -> void:
	if not _sync():
		_hide_all()
		return
	var origin: Vector3 = _player.global_position
	var forward: Vector3 = _player.get_aim_direction()
	var yaw: float = atan2(-forward.x, -forward.z)
	var y: float = origin.y + float(_config["ground_offset"])
	for i in range(_parts.size()):
		var pivot := _pivots[i]
		var offset: float = _parts[i]["start_offset"]
		pivot.position = Vector3(origin.x + forward.x * offset, y, origin.z + forward.z * offset)
		pivot.rotation.y = yaw
		pivot.visible = true
	_apply_ready(_is_shown_slot_ready())


## Brings the built parts in line with what is being previewed. False when nothing is.
## Cheap when nothing changed (two comparisons), so get_state() and _process share it.
func _sync() -> bool:
	if _player == null or not is_instance_valid(_player) or not bool(_config.get("enabled", true)) or _player.is_dead():
		_clear()
		return false
	var slot_index: int = _player.cast_input.preview_slot
	if slot_index == CastInput.NONE:
		_clear()
		return false
	var slot: CardSlot = _player.card_slots.get_slot(CardSlotController.slot_type_at_index(slot_index))
	var card_id: String = slot.current_card_id if slot != null else ""
	if slot_index != _shown_slot or card_id != _shown_card:
		_rebuild(slot_index, card_id)
	return not _parts.is_empty()


func _clear() -> void:
	if _shown_slot != CastInput.NONE or not _parts.is_empty():
		_shown_slot = CastInput.NONE
		_shown_card = ""
		_parts = []


func _hide_all() -> void:
	for pivot in _pivots:
		if pivot.visible:
			pivot.visible = false


func _rebuild(slot_index: int, card_id: String) -> void:
	_shown_slot = slot_index
	_shown_card = card_id
	var card := CardDatabase.get_card(card_id)
	_parts = CastPreviewShapes.parts_for_card(card, _config) if not card.is_empty() else ([] as Array[Dictionary])
	if _parts.size() > MAX_PARTS:
		push_error("CastPreview: card '%s' has %d aimed parts, only %d are drawn" % [card_id, _parts.size(), MAX_PARTS])
		_parts = _parts.slice(0, MAX_PARTS)
	for i in range(MAX_PARTS):
		if i >= _parts.size():
			_pivots[i].visible = false
			continue
		_style_part(i, _parts[i])
	_apply_ready(_is_shown_slot_ready())


func _style_part(index: int, part: Dictionary) -> void:
	var size: float = part["size"]
	var half_width: float = part["half_width"]
	var thickness: float = minf(float(_config["edge_thickness"]), maxf(size, 0.02) * 0.5)
	var shape: String = part["shape"]
	var fill := _fills[index]
	var edge := _edges[index]
	match shape:
		CastPreviewShapes.CONE:
			var half_angle: float = part["half_angle_degrees"]
			fill.mesh = EffectPool.wedge_mesh(half_angle)
			fill.scale = Vector3(size, 1.0, size)
			edge.mesh = _cached("cone|%f|%f|%f" % [size, half_angle, thickness], func() -> Mesh: return AttackArcVisual.build_outline(size, half_angle, thickness))
		CastPreviewShapes.AOE, CastPreviewShapes.SELF_RING:
			fill.mesh = EffectPool.disc_mesh()
			fill.scale = Vector3(size, 1.0, size)
			edge.mesh = _cached("ring|%f|%f" % [size, thickness], func() -> Mesh: return build_ring(size, thickness))
		_:
			var lane_thickness: float = minf(thickness, half_width)
			fill.mesh = EffectPool.strip_mesh()
			fill.scale = Vector3(half_width, 1.0, size)
			edge.mesh = _cached("lane|%f|%f|%f" % [half_width, size, lane_thickness], func() -> Mesh: return build_lane_outline(half_width, size, lane_thickness))
	edge.scale = Vector3.ONE
	edge.position.y = 0.005
	var color := Color.html(String(_config["default_color"]))
	match String(_config["color_source"]):
		"card_element":
			if not String(part["damage_type"]).is_empty():
				color = ElementVisuals.color_for_damage_type(String(part["damage_type"]))
		"player_element":
			var element_id: String = _player.character_element_id()
			if not element_id.is_empty():
				color = ElementVisuals.color_for_damage_type(element_id)
	_fill_colors[index] = Color(color, float(_config["fill_alpha"]))
	_edge_colors[index] = Color(color.lerp(Color.WHITE, float(_config["edge_lighten"])), float(_config["edge_alpha"]))
	_colors_dirty = true


## Ready: the full-strength colours. Not ready (the slot is cooling, so a release would not
## cast): fainter and greyer, same size. Writes materials only when the state flips.
func _apply_ready(is_ready: bool) -> void:
	if is_ready == _shown_ready and not _colors_dirty:
		return
	_colors_dirty = false
	_shown_ready = is_ready
	var alpha_scale: float = 1.0 if is_ready else float(_config["not_ready_alpha_scale"])
	var grey_mix: float = 0.0 if is_ready else float(_config["not_ready_desaturate"])
	for i in range(_parts.size()):
		(_fills[i].material_override as StandardMaterial3D).albedo_color = dimmed(_fill_colors[i], alpha_scale, grey_mix)
		(_edges[i].material_override as StandardMaterial3D).albedo_color = dimmed(_edge_colors[i], alpha_scale, grey_mix)


## `color` with its alpha times `alpha_scale` and `grey_mix` of the way to its own luminance grey.
static func dimmed(color: Color, alpha_scale: float, grey_mix: float) -> Color:
	var luminance: float = color.get_luminance()
	var grey := Color(luminance, luminance, luminance)
	var mixed := color.lerp(grey, grey_mix)
	return Color(mixed.r, mixed.g, mixed.b, color.a * alpha_scale)


## The colour a part's edge / fill is drawn with right now (tests and ux).
func edge_color(index: int) -> Color:
	return (_edges[index].material_override as StandardMaterial3D).albedo_color


func fill_color(index: int) -> Color:
	return (_fills[index].material_override as StandardMaterial3D).albedo_color


func _cached(key: String, builder: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = builder.call()
	return _mesh_cache[key]


## What is being previewed, for ux and tests. `active` false means nothing is shown (all
## other fields are empty). `slot` is the slot type id, `shape` and `size` those of the
## first part (the card's main shape), `parts` every part (see CastPreviewShapes), `ready`
## whether releasing now would cast (false while the slot cools: ux may dim the preview).
func get_state() -> Dictionary:
	if not _sync():
		return {"active": false, "slot": "", "card_id": "", "shape": "", "size": 0.0, "parts": [], "ready": false}
	return {
		"active": true,
		"slot": CardSlotController.slot_type_at_index(_shown_slot),
		"card_id": _shown_card,
		"shape": _parts[0]["shape"],
		"size": _parts[0]["size"],
		"parts": _parts.duplicate(true),
		"ready": _is_shown_slot_ready(),
	}


func _is_shown_slot_ready() -> bool:
	var slot: CardSlot = _player.card_slots.get_slot(CardSlotController.slot_type_at_index(_shown_slot))
	return slot != null and slot.is_ready()


## The drawn nodes for part `index` (fill, edge, pivot), for sizing tests. Null when unused.
func fill_node(index: int) -> MeshInstance3D:
	return _fills[index] if index >= 0 and index < _fills.size() else null


func pivot_node(index: int) -> Node3D:
	return _pivots[index] if index >= 0 and index < _pivots.size() else null


# --- edge meshes (built at the real size, once per distinct shape; never per frame) ---

## Flat annulus: outer radius `outer`, inner `outer - thickness`.
static func build_ring(outer: float, thickness: float) -> ArrayMesh:
	var inner: float = maxf(outer - thickness, 0.0)
	var segments: int = 40
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		vertices.append_array([o0 * inner, o0 * outer, o1 * outer, o0 * inner, o1 * outer, o1 * inner])
	return _flat_mesh(vertices, normals)


## Outline of a lane (x from -half_width to half_width, z from 0 to -length), drawn inward.
static func build_lane_outline(half_width: float, length: float, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var t: float = thickness
	for rect: Array in [
			[-half_width, -half_width + t, 0.0, -length],
			[half_width - t, half_width, 0.0, -length],
			[-half_width, half_width, -length + t, -length],
			[-half_width, half_width, 0.0, -t]]:
		var x0: float = rect[0]
		var x1: float = rect[1]
		var z0: float = rect[2]
		var z1: float = rect[3]
		vertices.append_array([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)])
	return _flat_mesh(vertices, normals)


static func _flat_mesh(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	for n in range(vertices.size()):
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
