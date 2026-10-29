class_name ZoneShape
extends RefCounted
## Pure geometry and timing for the zone template (no scene access, so tests feed it numbers).
##
## circle: the shared sphere query (MeleeQuery) at the zone centre, so it hits exactly like an aoe
##   (VfxSizing.zone_circle_reach).
## line: a wall centred on the placed point, running ACROSS the cast direction (caster to point).
##   `length` is the long side, `width` the short side. A target is hit while its centre is inside
##   the rectangle grown by the hurtbox reach radius (VfxSizing.zone_line_*), which is the rectangle
##   the visual draws.

const CIRCLE := "circle"
const LINE := "line"
const SHAPES: Array[String] = [CIRCLE, LINE]


## Ticks in a zone's life: one at placement, then one every `interval` while the zone is still up.
## duration 4, interval 0.5 -> 8 ticks (t = 0, 0.5, ... 3.5).
static func tick_count(duration: float, interval: float) -> int:
	if duration <= 0.0 or interval <= 0.0:
		return 0
	return int(floorf((duration - 0.000001) / interval)) + 1


## Unit vector along the wall's long side for a cast direction (flattened). Falls back to -Z cast.
static func line_axis(cast_dir: Vector3) -> Vector3:
	var flat := Vector3(cast_dir.x, 0.0, cast_dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	return Vector3(-flat.z, 0.0, flat.x)


static func line_contains(point: Vector3, center: Vector3, cast_dir: Vector3, length: float, width: float) -> bool:
	var axis := line_axis(cast_dir)
	var across := Vector3(axis.z, 0.0, -axis.x)  # the cast direction
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	return absf(offset.dot(axis)) <= VfxSizing.zone_line_half_length(length) and absf(offset.dot(across)) <= VfxSizing.zone_line_half_width(width)


## Radius of a sphere that surely contains the whole line rectangle (the broad-phase query).
static func line_query_radius(length: float, width: float) -> float:
	var half_length := VfxSizing.zone_line_half_length(length)
	var half_width := VfxSizing.zone_line_half_width(width)
	return sqrt(half_length * half_length + half_width * half_width) + 1.0
