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
	return flat_mesh(vertices, normals)


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
