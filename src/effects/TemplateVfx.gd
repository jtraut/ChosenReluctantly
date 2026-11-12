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
	var effect: PooledEffect = pool.play(EffectPool.Shape.SPHERE, projectile.global_position, VfxSizing.projectile_radius(hit_radius) * float(look.get("ball_scale", 1.0)), look["color"], 1.0, 1.0, 1.0, 1.0, 1.0)
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
## `max_range` plus the lateral reach forward (VfxSizing.projectile_lane_length), as wide as the area that shot can hit (VfxSizing). Not
## element-scaled: it shows a hit area.
static func projectile_lane(pool: EffectPool, origin: Vector3, direction: Vector3, max_range: float, hit_radius: float, look: Dictionary) -> void:
	if pool == null or direction.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	pool.play(EffectPool.Shape.STRIP, origin, VfxSizing.projectile_lane_half_width(hit_radius), look["color"],
			VfxConfig.marker("projectile_lane_duration"), 1.0, 1.0, VfxConfig.marker("projectile_lane_alpha"), 0.0, yaw) 			.lengthened(VfxSizing.projectile_lane_length(max_range, hit_radius))


## Lane alpha: `boss` telegraphs are bolder (same shape, size and tint; only more opaque), so a boss attack never reads
## as a regular enemy's.
static func _lane_alpha(boss: bool) -> float:
	return VfxConfig.marker("boss_lane_alpha") if boss else VfxConfig.marker("enemy_shot_lane_alpha")


## A ranged enemy's wind-up lane: the strip its shot will fly along (as wide as the area the shot hits the
## PLAYER over), shown for the whole wind-up so the shot can be sidestepped. Tinted for the enemy team.
## `ramp` (the boss volley): the lane brightens from a dim start to a bright end across the wind-up (so the fire moment reads as "now")
## and its length is capped to what fits on screen (`boss_volley_lane_max_length`). Look only: pellets still fly the full range.
static func enemy_shot_lane(pool: EffectPool, origin: Vector3, direction: Vector3, max_range: float, hit_radius: float, color: Color, duration: float, boss: bool = false, ramp: bool = false) -> PooledEffect:
	if pool == null or direction.length_squared() < 0.0001 or duration <= 0.0:
		return null
	var yaw: float = atan2(-direction.x, -direction.z)
	var a_from: float = _lane_alpha(boss)
	var a_to: float = 0.0
	var length: float = VfxSizing.enemy_shot_lane_length(max_range, hit_radius)
	if ramp:
		a_from = VfxConfig.marker("boss_volley_lane_alpha_start")
		a_to = VfxConfig.marker("boss_volley_lane_alpha_end")
		length = minf(length, VfxConfig.marker("boss_volley_lane_max_length"))
	var lane: PooledEffect = pool.play(EffectPool.Shape.STRIP, origin, VfxSizing.lateral_reach_vs_player(hit_radius), color,
			duration, 1.0, 1.0, a_from, a_to, yaw)
	return lane.lengthened(length) if lane != null else null


## The safe-gap tint of a fan (see VolleyGaps): green strips between the lanes where standing is clear, brightening with
## the lanes. `lane_half_width` is the drawn lane's half width. Returns the effects to hold with the lanes.
static func boss_volley_gaps(pool: EffectPool, origin: Vector3, aim: Vector3, angles: Array[float], lane_half_width: float, duration: float) -> Array[PooledEffect]:
	var parts: Array[PooledEffect] = []
	if pool == null or aim.length_squared() < 0.0001 or duration <= 0.0:
		return parts
	var color: Color = VfxConfig.color_of("boss_volley_gap_color")
	var segments: Array[Dictionary] = VolleyGaps.segments(angles, lane_half_width, VfxConfig.marker("boss_volley_gap_min_half_width"),
			VfxConfig.marker("boss_volley_gap_segment_length"), VfxConfig.marker("boss_volley_lane_max_length"))
	for seg: Dictionary in segments:
		var dir: Vector3 = aim.normalized().rotated(Vector3.UP, deg_to_rad(float(seg["angle"])))
		var yaw: float = atan2(-dir.x, -dir.z)
		var strip: PooledEffect = pool.play(EffectPool.Shape.STRIP, origin + dir * float(seg["start"]), float(seg["half_width"]), color, duration, 1.0, 1.0,
				VfxConfig.marker("boss_volley_gap_alpha_start"), VfxConfig.marker("boss_volley_gap_alpha_end"), yaw)
		if strip != null:
			parts.append(strip.lengthened(float(seg["length"])))
	return parts


## A charging enemy's wind-up lane: the strip it will run along, as wide as the sphere it sweeps reaches into the player
## (VfxSizing.charge_lane_*), starting that reach behind the start point. Shown for the whole wind-up.
static func enemy_charge_lane(pool: EffectPool, start: Vector3, direction: Vector3, distance: float, hit_radius: float, color: Color, duration: float, boss: bool = false) -> PooledEffect:
	if pool == null or direction.length_squared() < 0.0001 or duration <= 0.0:
		return null
	var dir: Vector3 = direction.normalized()
	var yaw: float = atan2(-dir.x, -dir.z)
	var origin: Vector3 = start - dir * VfxSizing.lateral_reach_vs_player(hit_radius)
	var lane: PooledEffect = pool.play(EffectPool.Shape.STRIP, origin, VfxSizing.charge_lane_half_width(hit_radius), color,
			duration, 1.0, 1.0, _lane_alpha(boss), 0.0, yaw)
	return lane.lengthened(VfxSizing.charge_lane_length(distance, hit_radius)) if lane != null else null


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
## Radius of a boss telegraph's second, inner outline ring, as a fraction of the hit reach.
const BOSS_EDGE_INNER := 0.93

## `compact` (MB1 ux, several discs at once): only the fill and the one edge per disc, so overlapping discs do not pile up
## rings (the union of the fills is the danger area; each disc keeps one outline).
static func aoe_telegraph(pool: EffectPool, center: Vector3, hit_reach: float, color: Color, boss: bool = false, compact: bool = false) -> Array[PooledEffect]:
	var effects: Array[PooledEffect] = []
	if pool == null:
		return effects
	var disc: PooledEffect = pool.play(EffectPool.Shape.DISC, center, hit_reach, color, 1.0, AOE_TELEGRAPH_START, 1.0, AOE_TELEGRAPH_FILL_ALPHA, AOE_TELEGRAPH_FILL_ALPHA_END)
	if disc != null:
		effects.append(disc.driven())
	var edge: PooledEffect = pool.play(EffectPool.Shape.RING, center + Vector3(0.0, 0.02, 0.0), hit_reach, lighter(color, 0.6), 1.0, 1.0, 1.0, AOE_TELEGRAPH_EDGE_ALPHA, AOE_TELEGRAPH_EDGE_ALPHA_END)
	if edge != null:
		if boss:
			edge.drawn_over()
		effects.append(edge.driven())
	if compact:
		return effects
	var front: PooledEffect = pool.play(EffectPool.Shape.RING, center + Vector3(0.0, 0.03, 0.0), hit_reach, Color.WHITE, 1.0, AOE_TELEGRAPH_START, 1.0, 0.8, 0.0)
	if front != null:
		effects.append(front.driven())
	if boss:
		# A second outline just inside the hit edge (a bolder edge; nothing is drawn past the real reach).
		var inner: PooledEffect = pool.play(EffectPool.Shape.RING, center + Vector3(0.0, 0.025, 0.0), hit_reach * BOSS_EDGE_INNER, lighter(color, 0.6), 1.0, 1.0, 1.0, AOE_TELEGRAPH_EDGE_ALPHA, AOE_TELEGRAPH_EDGE_ALPHA_END)
		if inner != null:
			inner.drawn_over()
			effects.append(inner.driven())
	return effects


## MB1 ux: a boss blink's landing marker, held for the whole wind-up. It is the "they will APPEAR here" language and must not read as a damage
## zone, so it shares nothing with the damage telegraph (no filled disc, no pink): a thin ring at the landing spot, a second ring that
## shrinks onto it (arrival converges, a damage zone fills), a faint ghost of the body standing there, a small centre pip and a thin guide
## line from where the boss stands. The parts are driven (`set_progress`), the guide line fades on its own over `duration`. Held until
## each effect is passed to EffectPool.stop().
static func blink_marker(pool: EffectPool, from: Vector3, landing: Vector3, radius: float, color: Color, duration: float) -> Array[PooledEffect]:
	var parts: Array[PooledEffect] = []
	if pool == null:
		return parts
	var pale: Color = lighter(color, 0.5)
	var rest: PooledEffect = pool.play(EffectPool.Shape.RING, landing + Vector3(0.0, 0.02, 0.0), radius, pale, 1.0, 1.0, 1.0, VfxConfig.marker("blink_ring_alpha"), VfxConfig.marker("blink_ring_alpha_end"))
	if rest != null:
		parts.append(rest.drawn_over().driven())
	var closing: PooledEffect = pool.play(EffectPool.Shape.RING, landing + Vector3(0.0, 0.03, 0.0), radius, Color.WHITE, 1.0, VfxConfig.marker("blink_closing_from"), 1.0, VfxConfig.marker("blink_closing_alpha"), VfxConfig.marker("blink_closing_alpha_end"))
	if closing != null:
		parts.append(closing.drawn_over().driven())
	var ghost: PooledEffect = pool.play(EffectPool.Shape.SPHERE, landing + Vector3(0.0, VfxConfig.marker("blink_ghost_height"), 0.0), radius * VfxConfig.marker("blink_ghost_scale"), color, 1.0, VfxConfig.marker("blink_ghost_from"), 1.0, VfxConfig.marker("blink_ghost_alpha"), VfxConfig.marker("blink_ghost_alpha_end"))
	if ghost != null:
		ghost.stretch_y = VfxConfig.marker("blink_ghost_stretch")
		parts.append(ghost.driven())
	var pip: PooledEffect = pool.play(EffectPool.Shape.DISC, landing + Vector3(0.0, 0.04, 0.0), radius * VfxConfig.marker("blink_pip_scale"), Color.WHITE, 1.0, 1.0, 1.0, VfxConfig.marker("blink_pip_alpha"), VfxConfig.marker("blink_pip_alpha_end"))
	if pip != null:
		parts.append(pip.drawn_over().driven())
	if duration <= 0.0:
		return parts
	var along: Vector3 = Vector3(landing.x - from.x, 0.0, landing.z - from.z)
	if along.length() > 0.5:
		var dir: Vector3 = along.normalized()
		var yaw: float = atan2(-dir.x, -dir.z)
		var guide: PooledEffect = pool.play(EffectPool.Shape.STRIP, Vector3(from.x, 0.02, from.z), VfxConfig.marker("blink_guide_half_width"), color, duration, 1.0, 1.0, VfxConfig.marker("blink_guide_alpha"), VfxConfig.marker("blink_guide_alpha_end"), yaw)
		if guide != null:
			parts.append(guide.lengthened(along.length()).driven())
	return parts



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
## A dash that damages along its path (`hit_radius` >= 0) draws the swept hit area instead
## (VfxSizing.dash_path_half_width / dash_path_length: reaching that far sideways, behind the start and past the end).
static func dash_path(pool: EffectPool, origin: Vector3, direction: Vector3, distance: float, look: Dictionary, hit_radius: float = -1.0) -> void:
	if pool == null or direction.length_squared() < 0.0001 or distance <= 0.0:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	var half_width: float = VfxConfig.marker("dash_path_half_width")
	var length: float = distance
	var start: Vector3 = origin
	if hit_radius >= 0.0:
		half_width = VfxSizing.dash_path_half_width(hit_radius)
		length = VfxSizing.dash_path_length(distance, hit_radius)
		start = origin - direction.normalized() * VfxSizing.lateral_reach(hit_radius)
	pool.play(EffectPool.Shape.STRIP, start, half_width, look["color"],
			VfxConfig.marker("dash_path_duration"), 1.0, 1.0, VfxConfig.marker("dash_path_alpha"), 0.0, yaw) 			.lengthened(length)


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


## Persistent buff cue (data/vfx.json "buff_cues", keyed by the buffed stat): a pulsing ground ring and a faint bubble
## that follow `target` for `duration`. Shape and brightness, not just colour: a ring plus a bubble round the body.
## Returns the effects (empty with no pool, no target or no cue for the stat).
static func buff_aura(pool: EffectPool, target: Node3D, cue: Dictionary, duration: float) -> Array[PooledEffect]:
	var effects: Array[PooledEffect] = []
	if pool == null or target == null or cue.is_empty() or duration <= 0.0:
		return effects
	var color: Color = Color.html(String(cue["color"]))
	var pulse: float = float(cue["pulse"])
	var hz: float = float(cue["pulse_hz"])
	var ring: PooledEffect = pool.play(EffectPool.Shape.RING, target.global_position, float(cue["ring_radius"]), color, duration, 1.0, 1.0, float(cue["ring_alpha"]), float(cue["ring_alpha"]) * 0.6)
	if ring != null:
		effects.append(ring.following(target, Vector3(0.0, 0.03, 0.0)).pulsing(pulse, hz))
	var bubble: PooledEffect = pool.play(EffectPool.Shape.SPHERE, target.global_position, float(cue["bubble_radius"]), lighter(color, 0.3), duration, 1.0, 1.0, float(cue["bubble_alpha"]), float(cue["bubble_alpha"]) * 0.6)
	if bubble != null:
		effects.append(bubble.following(target, Vector3(0.0, float(cue["bubble_height"]), 0.0)).pulsing(pulse, hz))
	return effects


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


## Bleed cue: a small tall drop hanging at the side of `target`'s chest, following it until EffectPool.stop() or the
## target is gone. A teardrop (a stretched sphere) beside the body reads differently from Burn's flame above the head
## and Stun's circling dots, with or without its colour. One pooled node.
static func status_drip(pool: EffectPool, target: Node3D, color: Color, size: float, height: float, offset: float = 0.5) -> PooledEffect:
	if pool == null or target == null:
		return null
	var effect: PooledEffect = pool.play(EffectPool.Shape.SPHERE, target.global_position, size, color, 1.0, 1.0, 1.0, 0.95, 0.95)
	if effect == null:
		return null
	return effect.held().stretched(2.0).pulsing(0.1, 3.0).following(target, Vector3(offset, height, 0.0))


## One drop falling off a bleeding body on a damage tick: the same teardrop, dropping away and fading.
static func bleed_drop(pool: EffectPool, position: Vector3, color: Color, size: float) -> void:
	if pool == null:
		return
	pool.play(EffectPool.Shape.SPHERE, position, size, color, VfxConfig.marker("bleed_drop_duration"), 1.0, 0.6, VfxConfig.marker("bleed_drop_alpha"), 0.0) 			.stretched(2.2).drifting(Vector3(0.0, -VfxConfig.marker("bleed_drop_fall"), 0.0))


## Regeneration cue: a soft ring on the ground around `target`, held until stopped. A ground ring is the
## "aura" shape (nothing else is persistent at the feet), so it reads without colour.
static func status_ring(pool: EffectPool, target: Node3D, color: Color, radius: float) -> PooledEffect:
	if pool == null or target == null:
		return null
	var effect: PooledEffect = pool.play(EffectPool.Shape.RING, target.global_position, radius, color, 1.0, 1.0, 1.0, 0.8, 0.8)
	if effect == null:
		return null
	return effect.held().pulsing(0.12, 1.2).following(target, Vector3(0.0, 0.03, 0.0))


## One mote rising off a healing body on a heal tick.
static func heal_mote(pool: EffectPool, position: Vector3) -> void:
	if pool == null:
		return
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 0.4, 0.0), VfxConfig.marker("heal_mote_size"), lighter(VfxConfig.heal_color(), 0.3),
			VfxConfig.marker("heal_mote_duration"), 1.0, 0.5, 0.95, 0.0).drifting(Vector3(0.0, VfxConfig.marker("heal_mote_rise"), 0.0))


# --- player cues (PlayerCues) ----------------------------------------------------

## Ghost cue while pass-through is active: a ring at the feet, held until stopped (the body itself is faded by
## PlayerCues). A ring that breathes in and out says "not solid right now" without relying on the fade or colour.
static func ghost_ring(pool: EffectPool, target: Node3D) -> PooledEffect:
	if pool == null or target == null:
		return null
	var effect: PooledEffect = pool.play(EffectPool.Shape.RING, target.global_position, VfxConfig.marker("ghost_ring_radius"), VfxConfig.color_of("ghost_color"),
			1.0, 1.0, 1.0, VfxConfig.marker("ghost_ring_alpha"), VfxConfig.marker("ghost_ring_alpha"))
	if effect == null:
		return null
	return effect.held().pulsing(VfxConfig.marker("ghost_ring_pulse"), VfxConfig.marker("ghost_ring_hz")).following(target, Vector3(0.0, 0.04, 0.0))


## Leech drain: a bead that travels from the damaged target to the player, so "their health, now yours" is visible.
static func drain_pulse(pool: EffectPool, from: Vector3, to: Vector3) -> void:
	if pool == null:
		return
	var duration: float = VfxConfig.marker("drain_pulse_duration")
	var color: Color = VfxConfig.color_of("drain_color")
	var size: float = VfxConfig.marker("drain_pulse_size")
	pool.play(EffectPool.Shape.SPHERE, from, size, lighter(color, 0.2), duration, 1.0, 0.6, VfxConfig.marker("drain_pulse_alpha"), 0.5) 			.drifting((to - from) / duration)
	# A small flash where the bead lands, so the arrival (and the heal number that follows) reads.
	pool.play(EffectPool.Shape.SPHERE, to, size * 1.6, lighter(color, 0.5), 0.2, 0.5, 1.6, 0.8, 0.0).delayed(duration)


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


# --- boss ----------------------------------------------------------------------

## Phase-change roar: a pale ring that races out to `size` and a bright flash on the chest. Cosmetic only, never a
## hit area (white-gold, not the orange of an enemy telegraph, so it cannot read as one).
static func boss_roar(pool: EffectPool, position: Vector3, size: float, duration: float) -> void:
	if pool == null:
		return
	var gold := Color(1.0, 0.92, 0.55)
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 1.9, 0.0), 1.2, Color.WHITE, duration * 0.5, 0.6, 2.2, 0.9, 0.0)
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.04, 0.0), size, gold, duration, 0.1, 1.0, 0.85, 0.0)
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.05, 0.0), size * 0.6, lighter(gold, 0.5), duration * 0.7, 0.1, 1.0, 0.8, 0.0).delayed(duration * 0.2)


## The boss's death burst: a white-hot core, a big ring and a lingering disc. Cosmetic only.
static func boss_death(pool: EffectPool, position: Vector3, size: float) -> void:
	if pool == null:
		return
	var warm := Color(1.0, 0.55, 0.2)
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 1.9, 0.0), size * 0.5, Color.WHITE, 0.6, 0.5, 2.4, 0.95, 0.0)
	pool.play(EffectPool.Shape.SPHERE, position + Vector3(0.0, 1.9, 0.0), size * 0.35, warm, 0.9, 0.5, 3.0, 0.8, 0.0).delayed(0.1)
	pool.play(EffectPool.Shape.RING, position + Vector3(0.0, 0.05, 0.0), size, lighter(warm, 0.4), 0.9, 0.1, 1.0, 0.9, 0.0)
	pool.play(EffectPool.Shape.DISC, position, size * 0.6, warm, 1.2, 1.0, 1.0, 0.4, 0.0)
