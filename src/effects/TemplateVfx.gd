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
	pool.play(EffectPool.Shape.SPHERE, origin, 0.18 * s, lighter(look["color"], 0.6), 0.12, 0.6, 2.0, 0.9, 0.0)


static func projectile_trail_puff(pool: EffectPool, position: Vector3, hit_radius: float, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position, maxf(hit_radius, 0.1) * 0.8 * s, look["color"], 0.25, 1.0, 0.25, 0.55, 0.0)


static func projectile_impact(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	var color: Color = look["color"]
	pool.play(EffectPool.Shape.SPHERE, position, 0.22 * s, lighter(color, 0.7), 0.14, 0.6, 1.5, 0.95, 0.0)
	pool.play(EffectPool.Shape.SPHERE, position, 0.4 * s, color, 0.22, 0.5, 1.8, 0.7, 0.0)


# --- cone / melee ------------------------------------------------------------

## Static wedge at the true hit reach (fades) plus a brighter blade that sweeps
## across the arc. The blade stays inside the wedge, so nothing shows past reach.
static func cone_sweep(pool: EffectPool, position: Vector3, yaw: float, reach: float, half_angle_degrees: float, color: Color) -> void:
	if pool == null:
		return
	pool.play(EffectPool.Shape.WEDGE, position, reach, color, 0.25, 1.0, 1.0, 0.45, 0.0, yaw, half_angle_degrees)
	var blade_half: float = minf(10.0, half_angle_degrees * 0.4)
	var swing: float = deg_to_rad(half_angle_degrees - blade_half)
	pool.play(EffectPool.Shape.WEDGE, position, reach, lighter(color, 0.55), 0.13, 1.0, 1.0, 0.95, 0.3, yaw + swing, blade_half) \
			.sweeping_to(yaw - swing)


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


# --- dash --------------------------------------------------------------------

static func dash_start(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.3, 0.0), 0.3 * s, look["color"], 0.22, 0.5, 1.7, 0.7, 0.0)


static func dash_trail(pool: EffectPool, position: Vector3, look: Dictionary) -> void:
	if pool == null:
		return
	var s: float = float(look["scale"])
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.5, 0.0), 0.28 * s, look["color"], 0.28, 1.0, 0.3, 0.5, 0.0)


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
		pool.play(EffectPool.Shape.SPHERE, spot, 0.09, lighter(color, 0.3), 0.6, 1.0, 0.5, 0.95, 0.0) \
				.delayed(float(i) * 0.05).drifting(Vector3(0.0, 1.5, 0.0))
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.02, 0.0), 0.8, color, 0.4, 0.3, 1.0, 0.6, 0.0)


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
