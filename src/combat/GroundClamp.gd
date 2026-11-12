class_name GroundClamp
extends RefCounted
## MAP3b housekeeping: two solid bodies standing on the same spot push each other apart along an arbitrary (often vertical) contact normal, so the
## pair used to climb without limit (about y 77 after 60 physics frames). Nothing in the game leaves the floor on purpose, so a body that has risen
## above `MAX_RISE` is put back on the floor and loses its upward velocity. A body on the floor is never touched.

## Highest a floor-bound body's origin may sit above the floor plane (y 0), in metres. Steps and ramps do not exist; this is slack for physics jitter.
const MAX_RISE := 0.35


## True when `y` is a climb the clamp would undo.
static func is_climbing(y: float) -> bool:
	return y > MAX_RISE


## Call right after move_and_slide().
static func apply(body: CharacterBody3D) -> void:
	if not is_climbing(body.global_position.y):
		return
	var spot: Vector3 = body.global_position
	body.global_position = Vector3(spot.x, 0.0, spot.z)
	body.velocity.y = minf(body.velocity.y, 0.0)
