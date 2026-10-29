class_name ZoneManager
extends Node3D
## Owns the live zones of one world (a child of the arena, found or created with for_world()).
## A zone is a ground area that ticks damage and an optional status chance on whoever stands in it
## for `duration`; cards place it with the "zone" template (EffectTemplates). One manager, one
## physics loop, no per-zone script: zones are plain records with two reused ground meshes each.
##
## Pooled and capped: at most ZoneConfig.max_live zones are alive, the visual nodes are created
## once and reused, and placing one more ends the oldest. Self-cleaning: a zone ends when its time
## is up, when its caster is freed, out of the tree or dead, and with the world (reload).
## Ticks behave like DoT ticks (Health.KIND_DOT): number and flash only, no hit-stop or shake.

signal zone_started(zone_id: int)
signal zone_ended(zone_id: int)

const NODE_NAME := "ZoneManager"
const GROUND_OFFSET := 0.04
## The look numbers (fill and edge alpha, tick flash, the burn-down timer, the ending blink) are data:
## data/zones.json "look", read through ZoneConfig.look(). The sizes are never data here: VfxSizing owns them.


class Zone extends RefCounted:
	var id: int = 0
	var shape: String = ZoneShape.CIRCLE
	var center: Vector3 = Vector3.ZERO
	var cast_dir: Vector3 = Vector3.FORWARD
	var size_a: float = 1.0  ## circle: radius. line: length
	var size_b: float = 0.0  ## line: width
	var duration: float = 1.0
	var interval: float = 1.0
	var damage: float = 0.0
	var damage_type: String = "physical"
	var knockback: float = 0.0
	var status_id: String = ""
	var status_duration: float = 0.0
	var status_chance: float = 1.0
	var team: String = "neutral"
	var source_id: int = 0
	var rng: RandomNumberGenerator = null
	var elapsed: float = 0.0
	var ticks_done: int = 0
	var total_ticks: int = 0
	var flash: float = 0.0
	var color: Color = Color.WHITE
	var fill: MeshInstance3D = null
	var edge: MeshInstance3D = null
	## The burn-down indicator inside the zone: a bar (line) or a core disc (circle) that empties as the zone runs out.
	var timer: MeshInstance3D = null
	var live: bool = false
	## Cached for the per-frame update (set in _build_visual): where the timer sits and how big it can be.
	var timer_axis: Vector3 = Vector3.ZERO
	var timer_extent: float = 0.0  ## line: full long side; circle: radius at full life
	var timer_half_width: float = 0.0


var max_live: int = 6
var _free: Array[Zone] = []
var _live: Array[Zone] = []
var _created: int = 0
var _next_id: int = 1
var _edge_meshes: Dictionary = {}


## Finds or creates the manager under `world`; null when `world` is null or not in the tree.
static func for_world(world: Node) -> ZoneManager:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return null
	var existing: Node = world.get_node_or_null(NODE_NAME)
	if existing is ZoneManager:
		return existing
	var manager := ZoneManager.new()
	manager.name = NODE_NAME
	manager.max_live = ZoneConfig.max_live()
	world.add_child(manager)
	return manager


## Places a zone and runs its first tick now. `params` is the validated "zone" template params,
## `cast_dir` the caster-to-point direction (orients a line). Returns the zone id.
func spawn(params: Dictionary, center: Vector3, cast_dir: Vector3, context: EffectContext) -> int:
	var zone: Zone = _acquire()
	zone.id = _next_id
	_next_id += 1
	zone.shape = String(params["shape"])
	zone.center = center
	zone.cast_dir = cast_dir
	if zone.shape == ZoneShape.CIRCLE:
		zone.size_a = float(params["radius"])
		zone.size_b = 0.0
	else:
		zone.size_a = float(params["length"])
		zone.size_b = float(params["width"])
	zone.duration = float(params["duration"])
	zone.interval = float(params["tick_interval"])
	zone.damage = float(params["damage"])
	zone.damage_type = String(params["damage_type"])
	zone.knockback = float(params.get("knockback_strength", 0.0))
	zone.status_id = String(params.get("status_id", ""))
	zone.status_duration = float(params.get("status_duration", 0.0))
	zone.status_chance = float(params.get("status_chance", 1.0))
	zone.team = context.caster_team
	zone.source_id = context.caster.get_instance_id() if context.caster != null else 0
	zone.rng = context.rng
	zone.elapsed = 0.0
	zone.ticks_done = 0
	zone.total_ticks = ZoneShape.tick_count(zone.duration, zone.interval)
	zone.flash = 0.0
	zone.color = ElementVisuals.visual_for_team(zone.damage_type, zone.team)["color"]
	zone.live = true
	_build_visual(zone)
	_live.append(zone)
	zone_started.emit(zone.id)
	_tick(zone)
	return zone.id


func live_count() -> int:
	return _live.size()


## Visual node pairs ever created; never exceeds max_live.
func created_count() -> int:
	return _created


## What ux needs to draw a zone's timer and shape: id, shape, centre, the drawn size (circle:
## reach; line: half_length / half_width and the long-side axis, all the hit numbers), duration,
## elapsed, remaining fraction (1 -> 0), damage type and colour.
func live_zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone: Zone in _live:
		var entry: Dictionary = {"id": zone.id, "shape": zone.shape, "center": zone.center, "duration": zone.duration,
				"elapsed": zone.elapsed, "remaining_fraction": clampf(1.0 - zone.elapsed / zone.duration, 0.0, 1.0),
				"damage_type": zone.damage_type, "color": zone.color}
		if zone.shape == ZoneShape.CIRCLE:
			entry["reach"] = VfxSizing.zone_circle_reach(zone.size_a)
		else:
			entry["half_length"] = VfxSizing.zone_line_half_length(zone.size_a)
			entry["half_width"] = VfxSizing.zone_line_half_width(zone.size_b)
			entry["axis"] = ZoneShape.line_axis(zone.cast_dir)
		result.append(entry)
	return result


## Ends every zone now (tests).
func clear() -> void:
	while not _live.is_empty():
		_end(_live[_live.size() - 1])


func _physics_process(delta: float) -> void:
	step(delta)


## Steps all live zones. Public so tests can drive time without a scene loop.
func step(delta: float) -> void:
	var i: int = _live.size() - 1
	while i >= 0:
		if i < _live.size():
			var zone: Zone = _live[i]
			if not _source_active(zone):
				_end(zone)
			else:
				zone.elapsed += delta
				while zone.ticks_done < zone.total_ticks and zone.elapsed >= float(zone.ticks_done) * zone.interval:
					_tick(zone)
				if zone.elapsed >= zone.duration:
					_end(zone)
				else:
					_update_visual(zone, delta)
		i -= 1


func _source_active(zone: Zone) -> bool:
	if zone.source_id == 0:
		return true
	var source: Object = instance_from_id(zone.source_id)
	if source == null or not (source is Node) or not is_instance_valid(source) or not (source as Node).is_inside_tree():
		return false
	if (source as Node).has_node("Health") and ((source as Node).get_node("Health") as Health).is_dead():
		return false
	return true


func _tick(zone: Zone) -> void:
	zone.ticks_done += 1
	zone.flash = float(ZoneConfig.look()["tick_flash_time"])
	var source: Node = null
	if zone.source_id != 0:
		var found: Object = instance_from_id(zone.source_id)
		if found is Node and is_instance_valid(found):
			source = found
	var space := get_world_3d().direct_space_state
	var hits: Array[Hurtbox] = []
	if zone.shape == ZoneShape.CIRCLE:
		hits = MeleeQuery.find_hurtboxes_in_sphere(space, zone.center, zone.size_a, zone.team, CollisionLayers.HURTBOX)
	else:
		for hurtbox: Hurtbox in MeleeQuery.find_hurtboxes_in_sphere(space, zone.center, ZoneShape.line_query_radius(zone.size_a, zone.size_b), zone.team, CollisionLayers.HURTBOX):
			if ZoneShape.line_contains(hurtbox.global_position, zone.center, zone.cast_dir, zone.size_a, zone.size_b):
				hits.append(hurtbox)
	var status_def: Dictionary = StatusDatabase.get_status(zone.status_id) if zone.status_id != "" else {}
	var chance_ok: bool = zone.status_chance >= 1.0 or zone.status_chance <= 0.0 or zone.rng != null
	if not chance_ok and not status_def.is_empty():
		push_error("ZoneManager: zone status '%s' has chance %s but the context has no RNG; not applied" % [zone.status_id, str(zone.status_chance)])
	for hurtbox: Hurtbox in hits:
		if not is_instance_valid(hurtbox):
			continue
		if zone.damage > 0.0:
			hurtbox.receive_damage(zone.damage, zone.damage_type, EffectTemplates.knockback_from(zone.center, hurtbox.global_position, zone.knockback), source, Health.KIND_DOT)
		if status_def.is_empty() or hurtbox.status_manager == null or not chance_ok:
			continue
		if hurtbox.health != null and hurtbox.health.is_dead():
			continue
		if AttackStatuses.roll(zone.rng, zone.status_chance):
			hurtbox.status_manager.apply_status(zone.status_id, status_def, zone.status_duration, source)


func _end(zone: Zone) -> void:
	if not zone.live:
		return
	zone.live = false
	_live.erase(zone)
	zone.fill.visible = false
	zone.edge.visible = false
	zone.timer.visible = false
	_free.append(zone)
	zone_ended.emit(zone.id)


func _acquire() -> Zone:
	if not _free.is_empty():
		return _free.pop_back()
	if _created < max_live:
		var fresh := Zone.new()
		fresh.fill = _make_mesh_node()
		fresh.edge = _make_mesh_node()
		fresh.timer = _make_mesh_node()
		add_child(fresh.fill)
		add_child(fresh.edge)
		add_child(fresh.timer)
		_created += 1
		return fresh
	_end(_live[0])  # at the cap: the oldest zone makes room
	return _free.pop_back()


func _make_mesh_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	return node


## Fill and outline at the true hit area (VfxSizing); never scaled by the element.
func _build_visual(zone: Zone) -> void:
	var look: Dictionary = ZoneConfig.look()
	var thickness: float = float(CastPreviewConfig.get_config()["edge_thickness"])
	var y: float = zone.center.y + GROUND_OFFSET
	if zone.shape == ZoneShape.CIRCLE:
		var reach: float = VfxSizing.zone_circle_reach(zone.size_a)
		zone.fill.mesh = EffectPool.disc_mesh()
		zone.fill.scale = Vector3(reach, 1.0, reach)
		zone.fill.rotation = Vector3.ZERO
		zone.fill.position = Vector3(zone.center.x, y, zone.center.z)
		var ring_key := "ring|%f" % reach
		if not _edge_meshes.has(ring_key):
			_edge_meshes[ring_key] = GroundOutlines.build_ring(reach, minf(thickness, reach * 0.5))
		zone.edge.mesh = _edge_meshes[ring_key]
		zone.edge.scale = Vector3.ONE
		zone.edge.rotation = Vector3.ZERO
		zone.edge.position = Vector3(zone.center.x, y + 0.005, zone.center.z)
		zone.timer.mesh = EffectPool.disc_mesh()
		zone.timer.rotation = Vector3.ZERO
		zone.timer.position = Vector3(zone.center.x, y + 0.008, zone.center.z)
		zone.timer_extent = reach * float(look["timer_circle_scale"])
		zone.timer_half_width = 0.0
	else:
		var half_length: float = VfxSizing.zone_line_half_length(zone.size_a)
		var half_width: float = VfxSizing.zone_line_half_width(zone.size_b)
		var axis: Vector3 = ZoneShape.line_axis(zone.cast_dir)
		var start: Vector3 = zone.center - axis * half_length
		var yaw: float = atan2(-axis.x, -axis.z)
		zone.fill.mesh = EffectPool.strip_mesh()
		zone.fill.scale = Vector3(half_width, 1.0, half_length * 2.0)
		zone.fill.rotation = Vector3(0.0, yaw, 0.0)
		zone.fill.position = Vector3(start.x, y, start.z)
		var lane_key := "lane|%f|%f" % [half_width, half_length]
		if not _edge_meshes.has(lane_key):
			_edge_meshes[lane_key] = GroundOutlines.build_lane_outline(half_width, half_length * 2.0, minf(thickness, half_width))
		zone.edge.mesh = _edge_meshes[lane_key]
		zone.edge.scale = Vector3.ONE
		zone.edge.rotation = Vector3(0.0, yaw, 0.0)
		zone.edge.position = Vector3(start.x, y + 0.005, start.z)
		zone.timer.mesh = EffectPool.strip_mesh()
		zone.timer.rotation = Vector3(0.0, yaw, 0.0)
		zone.timer_axis = axis
		zone.timer_extent = half_length * 2.0
		zone.timer_half_width = timer_bar_half_width(float(look["timer_width"]), half_width)
	zone.fill.visible = true
	zone.edge.visible = true
	zone.timer.visible = true
	_update_visual(zone, 0.0)


## Half width of the line zone's timer bar: the data width, kept clear of the zone's own edge.
static func timer_bar_half_width(width: float, zone_half_width: float) -> float:
	return minf(width, zone_half_width * 0.6)


## How much of the timer is left to draw: the remaining life fraction (1 -> 0), never quite nothing until the zone ends.
static func timer_scale(life: float) -> float:
	return clampf(1.0 - life, 0.0, 1.0)


## The outline alpha: steady until the last `ending_fraction` of the life, then a blink between `min_alpha` and full,
## so a zone about to vanish does not just disappear. `elapsed` is the zone's age in seconds.
static func edge_alpha_at(life: float, elapsed: float, look: Dictionary) -> float:
	var base: float = float(look["edge_alpha"])
	if 1.0 - life > float(look["ending_fraction"]):
		return base
	var wave: float = 0.5 + 0.5 * sin(elapsed * float(look["ending_blink_hz"]) * TAU)
	return base * lerpf(float(look["ending_blink_min_alpha"]), 1.0, wave)


func _update_visual(zone: Zone, delta: float) -> void:
	var look: Dictionary = ZoneConfig.look()
	zone.flash = maxf(zone.flash - delta, 0.0)
	var life: float = clampf(zone.elapsed / zone.duration, 0.0, 1.0)
	var boost: float = float(look["tick_flash_boost"]) * (zone.flash / float(look["tick_flash_time"]))
	(zone.fill.material_override as StandardMaterial3D).albedo_color = Color(zone.color, lerpf(float(look["fill_alpha"]), float(look["fill_alpha_end"]), life) + boost)
	(zone.edge.material_override as StandardMaterial3D).albedo_color = Color(TemplateVfx.lighter(zone.color, 0.4), edge_alpha_at(life, zone.elapsed, look))
	# The burn-down timer sits inside the hit area and empties as the zone runs out (it never claims area of its own).
	var left: float = timer_scale(life)
	if zone.shape == ZoneShape.CIRCLE:
		var radius: float = maxf(zone.timer_extent * left, 0.001)
		zone.timer.scale = Vector3(radius, 1.0, radius)
	else:
		var length: float = maxf(zone.timer_extent * left, 0.001)
		zone.timer.scale = Vector3(zone.timer_half_width, 1.0, length)
		var start: Vector3 = zone.center - zone.timer_axis * (length * 0.5)
		zone.timer.position = Vector3(start.x, zone.center.y + GROUND_OFFSET + 0.008, start.z)
	(zone.timer.material_override as StandardMaterial3D).albedo_color = Color(TemplateVfx.lighter(zone.color, float(look["timer_lighten"])), float(look["timer_alpha"]))
