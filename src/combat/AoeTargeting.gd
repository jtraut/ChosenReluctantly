class_name AoeTargeting
extends RefCounted
## Pure target math for the "targeted_aoe" heavy: where the disc lands.
##
## The aim point is clamped to `max_range` from the caster first, then to the
## arena rectangle (so the disc centre is never off the floor). No aim point at
## all (no camera, or the mouse ray missed the ground) falls back to straight
## ahead at max_range, never an error.

## Keep the disc centre this far inside the arena edge.
const ARENA_EDGE_MARGIN := 0.5


## `aim_point` is a Vector3 or null. `forward` is the caster's facing (flattened).
## `arena` is the walkable XZ rectangle (Rect2 with x/z as x/y); an empty Rect2
## (size 0) means unbounded. The result keeps the caster's y.
static func clamp_target(origin: Vector3, aim_point: Variant, forward: Vector3, max_range: float, arena: Rect2) -> Vector3:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	flat_forward = flat_forward.normalized() if flat_forward.length_squared() > 0.0001 else Vector3.FORWARD
	var wanted: Vector3 = origin + flat_forward * max_range
	if typeof(aim_point) == TYPE_VECTOR3 and (aim_point as Vector3).is_finite():
		wanted = aim_point
	var offset := Vector3(wanted.x - origin.x, 0.0, wanted.z - origin.z)
	if offset.length() > max_range:
		offset = offset.normalized() * max_range
	var target := Vector3(origin.x + offset.x, origin.y, origin.z + offset.z)
	if arena.has_area():
		var inner: Rect2 = arena.grow(-ARENA_EDGE_MARGIN)
		target.x = clampf(target.x, inner.position.x, inner.end.x)
		target.z = clampf(target.z, inner.position.y, inner.end.y)
	return target
