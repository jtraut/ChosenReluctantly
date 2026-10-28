class_name TemplateVfx
extends RefCounted
## The visuals of every effect template, built once from EffectPool primitives.
## Colors come from element data (ElementVisuals) or data/vfx.json; the element
## "scale" only resizes cosmetic parts (bursts, puffs, sparkles). Parts that show
## a hit area take their size from VfxSizing and are never rescaled.
##
## Every function takes a possibly-null pool (unit tests on orphan nodes get no
## visuals) and plain positions/numbers, never a node it keeps, so a freed
## caster or target mid-effect is harmless. The one exception is the Burn flame,
## which follows its target by instance id (PooledEffect.following).

const FLAME_HEIGHT := 1.1


static func lighter(color: Color, amount: float = 0.5) -> Color:
	return color.lerp(Color.WHITE, amount)


# --- projectile -------------------------------------------------------------

static func projectile_muzzle(pool: EffectPool, origin: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, origin, 0.18 * s * VfxConfig.marker("projectile_muzzle_scale"), lighter(look["color"], 0.6), 0.14, 0.6, 2.0, VfxConfig.marker("projectile_muzzle_alpha"), 0.0)


## The projectile's ball as a held pooled sphere that follows the projectile, sized
## exactly to its hit radius (VfxSizing, never element-scaled: it is the object).
static func projectile_ball(pool: EffectPool, projectile: Node3D, hit_radius: float, look: Dictionary) -> PooledEffect:
	if pool == null or projectile == null:
		return null
	var effect: PooledEffect = pool.play(EffectPool.Shape.SPHERE, projectile.global_position, VfxSizing.projectile_radius(hit_radius), look["color"], 1.0, 1.0, 1.0, 1.0, 1.0)
	if effect == null:
		return null
	return effect.held().following(projectile, Vector3.ZERO)


## Small faint puff where a shot ran out of range (not a hit, so no real burst).
static func projectile_fizzle(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	pool.play(EffectPool.Shape.SPHERE, position, 0.12 * float(look["scale"]), look["color"], 0.2, 1.0, 0.3, 0.4, 0.0)


static func projectile_trail_puff(pool: EffectPool, position: Vector3, hit_radius: float, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position, maxf(hit_radius, 0.1) * 0.8 * s * VfxConfig.marker("projectile_trail_scale"), look["color"],
			VfxConfig.marker("projectile_trail_duration"), 1.0, 0.25, VfxConfig.marker("projectile_trail_alpha"), 0.0)


static func projectile_impact(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	var color: Color = look["color"]
	pool.play(EffectPool.Shape.SPHERE, position, 0.22 * s, lighter(color, 0.7), 0.14, 0.6, 1.5, 0.95, 0.0)
	pool.play(EffectPool.Shape.SPHERE, position, 0.4 * s, color, 0.22, 0.5, 1.8, 0.7, 0.0)


## Brief faint lane along a shot's path at cast time: from the launch point
## `max_range` forward, as wide as the area that shot can hit (VfxSizing). Not
## element-scaled: it shows a hit area.
static func projectile_lane(pool: EffectPool, origin: Vector3, direction: Vector3, max_range: float, hit_radius: float, look: Dictionary) -> void:
	if pool == null or direction.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	pool.play(EffectPool.Shape.STRIP, origin, VfxSizing.projectile_lane_half_width(hit_radius), look["color"],
			VfxConfig.marker("projectile_lane_duration"), 1.0, 1.0, VfxConfig.marker("projectile_lane_alpha"), 0.0, yaw) 			.lengthened(max_range)


## A ranged enemy's wind-up lane: the strip its shot will fly along (as wide as the area the shot hits the
## PLAYER over), shown for the whole wind-up so the shot can be sidestepped. Tinted for the enemy team.
static func enemy_shot_lane(pool: EffectPool, origin: Vector3, direction: Vector3, max_range: float, hit_radius: float, color: Color, duration: float) -> PooledEffect:
	if pool == null or direction.length_squared() < 0.0001 or duration <= 0.0:
		return null
	var yaw: float = atan2(-direction.x, -direction.z)
	var lane: PooledEffect = pool.play(EffectPool.Shape.STRIP, origin, VfxSizing.lateral_reach_vs_player(hit_radius), color,
			duration, 1.0, 1.0, VfxConfig.marker("enemy_shot_lane_alpha"), 0.0, yaw)
	return lane.lengthened(max_range) if lane != null else null


# --- cone / melee ------------------------------------------------------------

## Static wedge at the true hit reach (fades) plus a brighter blade that sweeps
## across the arc. The blade stays inside the wedge, so nothing shows past reach.
static func cone_sweep(pool: EffectPool, position: Vector3, yaw: float, reach: float, half_angle_degrees: float, color: Color, enemy: bool = false) -> void:
	if pool == null:
		return
	# An enemy's impact stays short: a long wedge after an enemy swing could read as a live telegraph.
	var shorten: float = VfxConfig.marker("cone_enemy_duration_scale") if enemy else 1.0
	pool.play(EffectPool.Shape.WEDGE, position, reach, color, VfxConfig.marker("cone_duration") * shorten, 1.0, 1.0, VfxConfig.marker("cone_alpha"), 0.0, yaw, half_angle_degrees)
	var blade_half: float = minf(10.0, half_angle_degrees * 0.4)
	var swing: float = deg_to_rad(half_angle_degrees - blade_half)
	pool.play(EffectPool.Shape.WEDGE, position, reach, lighter(color, 0.55), VfxConfig.marker("cone_blade_duration") * shorten, 1.0, 1.0, VfxConfig.marker("cone_blade_alpha"), 0.3, yaw + swing, blade_half) 			.sweeping_to(yaw - swing)


# --- aoe ---------------------------------------------------------------------

## Ground disc at the true hit radius, a cosmetic charge flash, then (after the
## flash) an impact burst and a ring that expands to exactly the hit radius. The
## damage itself is instant; only the visuals stage.
static func aoe(pool: EffectPool, origin: Vector3, hit_reach: float, look: Dictionary) -> void:
	if pool == null:
		return
	var color: Color = look["color"]
	var s: float = float(look["scale"])
	var chest: Vector3 = origin + Vector3(0.0, 0.5, 0.0)
	pool.play(EffectPool.Shape.DISC, origin, hit_reach, color, 0.35)
	pool.play(EffectPool.Shape.SPHERE, chest, 0.3 * s, lighter(color, 0.6), 0.1, 2.0, 0.5, 0.5, 0.95)
	pool.play(EffectPool.Shape.SPHERE, chest, 0.4 * s, color, 0.25, 0.6, 1.6, 0.8, 0.0).delayed(0.1)
	pool.play(EffectPool.Shape.RING, origin + Vector3(0.0, 0.02, 0.0), hit_reach, lighter(color, 0.4), 0.3, 0.3, 1.0, 0.85, 0.0).delayed(0.1)


## Held ground telegraph of a targeted_aoe heavy's wind-up, in the same language as
## the arc telegraph (AttackArcVisual): a pale OUTLINE ring at the true hit reach
## (VfxSizing, never scaled: the hitbox edge) plus a faint fill that GROWS IN from the
## centre, with a brighter front ring riding the fill edge. Call `set_aoe_telegraph_progress`
## every frame with the wind-up progress (0..1). The impact is the opposite: a solid,
## brighter disc and an expanding ring (`aoe`). Held until each effect is passed to
## EffectPool.stop(). Order matters: [0] fill disc (base_size = hit reach), [1] edge
## ring (hit reach), [2] front ring.
const AOE_TELEGRAPH_START := 0.15
const AOE_TELEGRAPH_FILL_ALPHA := 0.1
const AOE_TELEGRAPH_FILL_ALPHA_END := 0.4
const AOE_TELEGRAPH_EDGE_ALPHA := 0.55
const AOE_TELEGRAPH_EDGE_ALPHA_END := 1.0

static func aoe_telegraph(pool: EffectPool, center: Vector3, hit_reach: float, color: Color) -> Array[PooledEffect]:
	var effects: Array[PooledEffect] = []
	if pool == null:
		return effects
	var disc: PooledEffect = pool.play(EffectPool.Shape.DISC, center, hit_reach, color, 1.0, AOE_TELEGRAPH_START, 1.0, AOE_TELEGRAPH_FILL_ALPHA, AOE_TELEGRAPH_FILL_ALPHA_END)
	if disc != null:
		effects.append(disc.driven())
	var edge: PooledEffect = pool.play(EffectPool.Shape.RING, center + Vector3(0.0, 0.02, 0.0), hit_reach, lighter(color, 0.6), 1.0, 1.0, 1.0, AOE_TELEGRAPH_EDGE_ALPHA, AOE_TELEGRAPH_EDGE_ALPHA_END)
	if edge != null:
		effects.append(edge.driven())
	var front: PooledEffect = pool.play(EffectPool.Shape.RING, center + Vector3(0.0, 0.03, 0.0), hit_reach, Color.WHITE, 1.0, AOE_TELEGRAPH_START, 1.0, 0.8, 0.0)
	if front != null:
		effects.append(front.driven())
	return effects


static func set_aoe_telegraph_progress(effects: Array, fraction: float) -> void:
	for effect: Variant in effects:
		if effect is PooledEffect and is_instance_valid(effect):
			(effect as PooledEffect).set_progress(fraction)


# --- dash --------------------------------------------------------------------

static func dash_start(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.3, 0.0), 0.3 * s, look["color"], 0.22, 0.5, 1.7, 0.7, 0.0)


## Brief faint path of the dash as intended (start to start + distance). Cosmetic
## width (a dash has no hit area); if the dash is blocked short, the end puff shows where it stopped.
static func dash_path(pool: EffectPool, origin: Vector3, direction: Vector3, distance: float, look: Dictionary) -> void:
	if pool == null or direction.length_squared() < 0.0001 or distance <= 0.0:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	pool.play(EffectPool.Shape.STRIP, origin, VfxConfig.marker("dash_path_half_width"), look["color"],
			VfxConfig.marker("dash_path_duration"), 1.0, 1.0, VfxConfig.marker("dash_path_alpha"), 0.0, yaw) 			.lengthened(distance)


static func dash_trail(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.5, 0.0), VfxConfig.marker("dash_trail_size") * s, lighter(look["color"], VfxConfig.marker("dash_trail_lighten")),
			VfxConfig.marker("dash_trail_duration"), 1.0, 0.3, VfxConfig.marker("dash_trail_alpha"), 0.0)


static func dash_end(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.3, 0.0), 0.3 * s, lighter(look["color"], 0.4), 0.25, 0.5, 1.9, 0.75, 0.0)


# --- heal / buff -------------------------------------------------------------

const SPARKLE_COUNT := 6

static func heal(pool: EffectPool, position: Vector3) -> void:
	if pool == null:
		return
	var color: Color = VfxConfig.heal_color()
	for i in range(SPARKLE_COUNT):
		var angle: float = TAU * float(i) / float(SPARKLE_COUNT)
		var spot: Vector3 = position + Vector3(sin(angle) * 0.45, 0.2, cos(angle) * 0.45)
		pool.play(EffectPool.Shape.SPHERE, spot, VfxConfig.marker("heal_sparkle_size"), lighter(color, 0.3), VfxConfig.marker("heal_sparkle_duration"), 1.0, 0.5, 0.95, 0.0) \
				.delayed(float(i) * 0.05).drifting(Vector3(0.0, VfxConfig.marker("heal_sparkle_rise"), 0.0))
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.02, 0.0), VfxConfig.marker("heal_ring_radius"), color, VfxConfig.marker("heal_ring_duration"), 0.3, 1.0, VfxConfig.marker("heal_ring_alpha"), 0.0)


static func buff(pool: EffectPool, position: Vector3) -> void:
	if pool == null:
		return
	var color: Color = VfxConfig.buff_color()
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.02, 0.0), 0.6, color, 0.5, 0.7, 1.6, 0.9, 0.0)
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.04, 0.0), 0.6, lighter(color, 0.4), 0.5, 0.7, 1.6, 0.9, 0.0).delayed(0.2)


# --- status ------------------------------------------------------------------

## Height of the top of `target`'s body (its "BodyMesh" child) so a flame sits on
## the head and shows from the iso camera instead of hiding inside a tall body.
static func body_top(target: Node3D) -> float:
	var body := target.get_node_or_null("BodyMesh") as MeshInstance3D
	if body == null or body.mesh == null:
		return FLAME_HEIGHT
	return body.position.y + body.mesh.get_aabb().end.y * body.scale.y


## A persistent flame that follows `target` until EffectPool.stop() or the
## target is gone. Returns the effect (hold its generation to stop it later).
static func status_flame(pool: EffectPool, target: Node3D, look: Dictionary, size: float, height: float = FLAME_HEIGHT) -> PooledEffect:
	if pool == null or target == null:
		return null
	var effect: PooledEffect = pool.play(EffectPool.Shape.SPHERE, target.global_position, size * float(look["scale"]), look["color"], 1.0, 1.0, 1.0, 0.8, 0.8)
	if effect == null:
		return null
	return effect.held().stretched(1.6).pulsing(0.18, 6.0).following(target, Vector3(0.0, height, 0.0))


## Stun cue: `count` bright stars circling above the head of `target`, following it
## until EffectPool.stop() or the target is gone. Spheres seen from the iso camera
## read as a ring of dots that spins, which is unmistakable even small and in a crowd.
## Cosmetic only (no hit area). Returns the effects (empty with no pool).
static func status_stars(pool: EffectPool, target: Node3D, color: Color, size: float, count: int, orbit_radius: float, orbit_hz: float, height: float = FLAME_HEIGHT) -> Array[PooledEffect]:
	var effects: Array[PooledEffect] = []
	if pool == null or target == null:
		return effects
	for i in range(maxi(count, 1)):
		var phase: float = TAU * float(i) / float(maxi(count, 1))
		var star: PooledEffect = pool.play(EffectPool.Shape.SPHERE, target.global_position, size, color, 1.0, 1.0, 1.0, 1.0, 1.0)
		if star == null:
			break
		effects.append(star.held().following(target, Vector3(0.0, height + size, 0.0)).orbiting(orbit_radius, orbit_hz, phase))
	return effects


## F-E5: a stun cut an enemy's wind-up short. A bright ring at its feet that snaps inward, in the enemy
## team colour of the wedge or lane that just vanished. Cosmetic only (no hit area).
static func windup_cancelled(pool: EffectPool, position: Vector3, color: Color) -> void:
	if pool == null:
		return
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.04, 0.0), VfxConfig.marker("windup_cancel_size"), lighter(color, 0.5),
			VfxConfig.marker("windup_cancel_duration"), 1.0, 0.2, VfxConfig.marker("windup_cancel_alpha"), 0.0)


# --- death -------------------------------------------------------------------

## The player's death cue: a white-hot burst and a red ring racing outward from
## the body. Cosmetic only (no hit area).
static func death_cue(pool: EffectPool, position: Vector3) -> void:
	if pool == null:
		return
	var red := Color(1.0, 0.15, 0.15)
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.9, 0.0), 0.5, Color.WHITE, 0.35, 0.6, 2.2, 0.95, 0.0)
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.03, 0.0), 1.0, red, 0.6, 0.5, 3.2, 0.9, 0.0)
	pool.play(EffectPool.Shape.DISC, position, 1.4, red, 0.8, 1.0, 1.0, 0.45, 0.0)
