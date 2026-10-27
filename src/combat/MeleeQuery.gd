class_name MeleeQuery
extends RefCounted
## Finds Hurtboxes in a forward-facing cone. Shared by the basic attack now,
## and by the "cone" card effect template later, so hit-detection logic lives
## in one place.

static func find_hurtboxes_in_cone(
		space_state: PhysicsDirectSpaceState3D,
		origin: Vector3,
		forward: Vector3,
		attack_range: float,
		half_angle_degrees: float,
		exclude_team: String,
		collision_mask: int
) -> Array[Hurtbox]:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var forward_flat := forward
	forward_flat.y = 0.0
	if forward_flat.length_squared() < 0.0001:
		forward_flat = Vector3.FORWARD
	forward_flat = forward_flat.normalized()
	var half_angle_rad := deg_to_rad(half_angle_degrees)

	var found: Array[Hurtbox] = []
	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	for result: Dictionary in results:
		var collider: Variant = result.get("collider")
		if not (collider is Hurtbox):
			continue
		var hurtbox: Hurtbox = collider
		if hurtbox.team == exclude_team:
			continue
		var to_target := hurtbox.global_position - origin
		to_target.y = 0.0
		if to_target.length_squared() >= 0.0001:
			var angle := forward_flat.angle_to(to_target.normalized())
			if angle > half_angle_rad:
				continue
		found.append(hurtbox)
	return found
