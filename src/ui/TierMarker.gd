class_name TierMarker
extends RefCounted
## The marker above an elite or boss: a flat, camera-facing shape (RunIcons: diamond for elite, star for boss) with a
## dark outline, floating just over the HP bar. The shape carries the rank, so it never depends on colour, and it is
## a flat sign rather than a bigger body, so it never suggests a larger hitbox. Enemy.apply_tier calls `attach`.

const NODE_NAME := "TierMarker"
const DEFAULT_HEIGHT := 2.85
const DEFAULT_SIZE := {"elite": 0.26, "boss": 0.34}
const OUTLINE_SCALE := 1.35
const OUTLINE_COLOR := Color(0.05, 0.03, 0.04, 1.0)
const FILL_LIFT := 0.01


## Adds the marker as a child named TierMarker (any older one is replaced) and returns it.
## `cfg` is the data/run.json tier entry: marker_color, and optionally marker_size and marker_height (metres).
static func attach(parent: Node3D, tier_id: String, cfg: Dictionary) -> MeshInstance3D:
	var old := parent.get_node_or_null(NODE_NAME)
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var marker := build(tier_id, cfg)
	parent.add_child(marker)
	return marker


static func build(tier_id: String, cfg: Dictionary) -> MeshInstance3D:
	var radius: float = float(cfg.get("marker_size", DEFAULT_SIZE.get(tier_id, 0.26)))
	var color := Color.html(String(cfg.get("marker_color", "#ffffff")))
	var marker := MeshInstance3D.new()
	marker.name = NODE_NAME
	marker.position = Vector3(0.0, float(cfg.get("marker_height", DEFAULT_HEIGHT)), 0.0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape: PackedVector2Array = RunIcons.polygon(RunIcons.shape_for(tier_id), radius)
	var outline: PackedVector2Array = RunIcons.polygon(RunIcons.shape_for(tier_id), radius * OUTLINE_SCALE)
	marker.mesh = _mesh([[outline, OUTLINE_COLOR, 0.0], [shape, color, FILL_LIFT]])
	return marker


static func _mesh(layers: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for layer: Array in layers:
		var polygon: PackedVector2Array = layer[0]
		var color: Color = layer[1]
		var z: float = layer[2]
		var tris := Geometry2D.triangulate_polygon(polygon)
		var base: int = vertices.size()
		for p in polygon:
			vertices.append(Vector3(p.x, -p.y, z))  # shapes are y-down, the world is y-up
			colors.append(color.srgb_to_linear())  # vertex colours are read as linear
		for i in range(0, tris.size(), 3):
			# the y flip reverses winding; the material is double-sided anyway
			indices.append_array([base + tris[i], base + tris[i + 2], base + tris[i + 1]])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
