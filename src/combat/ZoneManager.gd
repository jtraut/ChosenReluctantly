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
const FILL_ALPHA := 0.3
const FILL_ALPHA_END := 0.12  ## the fill fades to this over the zone's life
const EDGE_ALPHA := 0.85
const TICK_FLASH_TIME := 0.12
const TICK_FLASH_BOOST := 0.25


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
	var live: bool = false


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
	zone.flash = TICK_FLASH_TIME
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
	_free.append(zone)
	zone_ended.emit(zone.id)


func _acquire() -> Zone:
	if not _free.is_empty():
		return _free.pop_back()
	if _created < max_live:
		var fresh := Zone.new()
		fresh.fill = _make_mesh_node()
		fresh.edge = _make_mesh_node()
		add_child(fresh.fill)
		add_child(fresh.edge)
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
	zone.fill.visible = true
	zone.edge.visible = true
	_update_visual(zone, 0.0)


func _update_visual(zone: Zone, delta: float) -> void:
	zone.flash = maxf(zone.flash - delta, 0.0)
	var life: float = clampf(zone.elapsed / zone.duration, 0.0, 1.0)
	var boost: float = TICK_FLASH_BOOST * (zone.flash / TICK_FLASH_TIME)
	(zone.fill.material_override as StandardMaterial3D).albedo_color = Color(zone.color, lerpf(FILL_ALPHA, FILL_ALPHA_END, life) + boost)
	(zone.edge.material_override as StandardMaterial3D).albedo_color = Color(TemplateVfx.lighter(zone.color, 0.4), EDGE_ALPHA)
