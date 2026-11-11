class_name ActTint
extends RefCounted
## MB1: each act has its own subtle arena tint (data/run.json `acts.N.tint`: a floor colour and a light colour). Act 1 is the
## scene's own look. Applied when an act's room loads. Readability first: the numbers are small shifts, not a new palette.


## Sets the arena's Floor material colour and Sun light colour from act `act`'s tint. Does nothing when the act has no tint.
## The floor's material is copied first (a scene's sub-resource is shared by every instance, and a tint must not leak into the next arena).
## Returns false (and logs) when the arena has no Floor or Sun, so a world missing them is loud, not silent.
static func apply(arena: Node, act: int) -> bool:
	var tint: Dictionary = RunConfig.act_tint(act)
	if tint.is_empty():
		return true
	var floor_node: CSGShape3D = arena.get_node_or_null("Floor") as CSGShape3D
	var sun: DirectionalLight3D = arena.get_node_or_null("Sun") as DirectionalLight3D
	if floor_node == null or sun == null:
		push_error("ActTint: the arena needs a Floor (CSGShape3D) and a Sun (DirectionalLight3D) to tint act %d" % act)
		return false
	var material: StandardMaterial3D = floor_node.material as StandardMaterial3D
	if material == null:
		push_error("ActTint: the arena Floor has no StandardMaterial3D")
		return false
	material = material.duplicate() as StandardMaterial3D
	material.albedo_color = tint["floor"]
	floor_node.material = material
	sun.light_color = tint["light"]
	return true
