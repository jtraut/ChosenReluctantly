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


## Where a placed skill (zone, placed aoe, the targeted heavy) lands and what the reticle shows:
## {point: the clamped target, range: the cap, clamped: true when the aim point was pulled in (too
## far, or off the arena), origin: the caster point the range is measured from, raw: the unclamped wish}.
static func placement(origin: Vector3, aim_point: Variant, forward: Vector3, max_range: float, arena: Rect2) -> Dictionary:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	flat_forward = flat_forward.normalized() if flat_forward.length_squared() > 0.0001 else Vector3.FORWARD
	var raw: Vector3 = origin + flat_forward * max_range
	if typeof(aim_point) == TYPE_VECTOR3 and (aim_point as Vector3).is_finite():
		raw = aim_point
	var point: Vector3 = clamp_target(origin, aim_point, forward, max_range, arena)
	var moved := Vector2(point.x - raw.x, point.z - raw.z).length()
	return {"point": point, "range": max_range, "clamped": moved > 0.001, "origin": origin, "raw": Vector3(raw.x, origin.y, raw.z)}
