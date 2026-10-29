class_name GroundOutlines
extends RefCounted
## Flat outline meshes for ground markings (cast preview, zones). Kept apart from CastPreview so the
## effect templates can use them without pulling in Player (and with it the autoloads), which
## tools/bot_sim.gd cannot compile under `-s`.


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
	return flat_mesh(vertices, normals)


## Outline of a lane (x from -half_width to half_width, z from 0 to -length), drawn inward.
static func build_lane_outline(half_width: float, length: float, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	_add_lane_outline(vertices, half_width, length, thickness)
	return flat_mesh(vertices, normals)


## A lane outline with a filled arrowhead at its far end (the -Z end), so a dash's direction reads from the
## shape alone. The head sits inside the lane's length; its half width is `arrow_half_width` (the caller keeps
## it inside the lane when the lane is a hit area) and its length `arrow_length` (kept under the lane length).
static func build_lane_arrow_outline(half_width: float, length: float, thickness: float, arrow_half_width: float, arrow_length: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	_add_lane_outline(vertices, half_width, length, thickness)
	var head: float = minf(arrow_length, length)
	vertices.append_array([Vector3(-arrow_half_width, 0, -(length - head)), Vector3(arrow_half_width, 0, -(length - head)), Vector3(0, 0, -length)])
	return flat_mesh(vertices, normals)


## Flat diamond outline (a square turned 45 degrees): the clamped-placement marker. `outer` is the distance from
## the centre to a corner, `thickness` the stroke width measured toward the centre.
static func build_diamond_outline(outer: float, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var inner: float = maxf(outer - thickness * 1.41421356, 0.0)
	var corners_out: Array[Vector3] = [Vector3(0, 0, -outer), Vector3(outer, 0, 0), Vector3(0, 0, outer), Vector3(-outer, 0, 0)]
	var corners_in: Array[Vector3] = [Vector3(0, 0, -inner), Vector3(inner, 0, 0), Vector3(0, 0, inner), Vector3(-inner, 0, 0)]
	for i in range(4):
		var j: int = (i + 1) % 4
		vertices.append_array([corners_in[i], corners_out[i], corners_out[j], corners_in[i], corners_out[j], corners_in[j]])
	return flat_mesh(vertices, normals)


static func _add_lane_outline(vertices: PackedVector3Array, half_width: float, length: float, thickness: float) -> void:
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


static func flat_mesh(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	for n in range(vertices.size()):
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
