class_name VfxSizing
extends RefCounted
## The one place that turns hit-area data into visual sizes, so a visual can
## never lie about what a hit covers.
##
## Cone and aoe hits are a sphere query of radius `range`/`radius` against
## enemy hurtboxes, which are capsules about 0.45 wide. A target is hit while
## its centre is within range + hurtbox radius, so that is the distance the
## ground shape is drawn to (data/vfx.json "hurtbox_reach_radius"). The hit
## query itself is unchanged. A projectile is drawn as its own hit sphere.


## Distance the cone wedge extends to.
static func cone_reach(attack_range: float) -> float:
	return attack_range + VfxConfig.hurtbox_reach_radius()


## Radius the aoe ground disc extends to.
static func aoe_reach(radius: float) -> float:
	return radius + VfxConfig.hurtbox_reach_radius()


## Radius of the projectile ball: exactly its hit sphere.
static func projectile_radius(hit_radius: float) -> float:
	return hit_radius
