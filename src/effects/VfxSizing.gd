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


## Every hit here is a sphere of radius q centred at floor level (caster origin
## y = 0; shots launch at the caster origin height too) against a capsule
## hurtbox. The capsule's nearest point to that centre is its lowest sphere
## centre, dy above the floor (data/vfx.json "hurtbox_low_center_height",
## = capsule height / 2 - radius), so a target centre is hit out to
##   sqrt((q + R)^2 - dy^2)    with R = "hurtbox_reach_radius"
## horizontally, not q + R. That is what the ground shapes are drawn to.

## Height of the hit-query centres above the floor (caster origin, launch point).
const QUERY_HEIGHT := 0.0


## Horizontal distance at which a target centre is just still hit by a sphere of
## radius `query_radius` centred at floor level.
static func lateral_reach(query_radius: float) -> float:
	var dy: float = maxf(VfxConfig.hurtbox_low_center_height() - QUERY_HEIGHT, 0.0)
	var along: float = query_radius + VfxConfig.hurtbox_reach_radius()
	return sqrt(maxf(along * along - dy * dy, 0.0))


## Same as lateral_reach, for an attack that hits the PLAYER's capsule instead of an enemy's
## (enemy melee wedges): the player's hurtbox is 0.4 wide and its low centre is 0.4 up.
static func lateral_reach_vs_player(query_radius: float) -> float:
	var dy: float = maxf(VfxConfig.player_hurtbox_low_center_height() - QUERY_HEIGHT, 0.0)
	var along: float = query_radius + VfxConfig.player_hurtbox_reach_radius()
	return sqrt(maxf(along * along - dy * dy, 0.0))


## Distance the cone wedge extends to.
static func cone_reach(attack_range: float) -> float:
	return lateral_reach(attack_range)


## Radius the aoe ground disc extends to.
static func aoe_reach(radius: float) -> float:
	return lateral_reach(radius)


## Radius of the projectile ball: exactly its hit sphere.
static func projectile_radius(hit_radius: float) -> float:
	return hit_radius


## Half width of the lane a projectile sweeps: the lateral reach of its hit sphere
## (0.60 for the 0.3 radius, not 0.75). The lane runs max_range from the launch point.
static func projectile_lane_half_width(hit_radius: float) -> float:
	return lateral_reach(hit_radius)


## Length of the lane a projectile sweeps, from the launch point: the flight (max_range) plus the
## same lateral reach the sides use, because the hit sphere keeps its radius past the last
## position (a target centre up to that far beyond max_range is still hit).
static func projectile_lane_length(max_range: float, hit_radius: float) -> float:
	return max_range + lateral_reach(hit_radius)
