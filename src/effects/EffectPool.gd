class_name EffectPool
extends Node
## Shared pool of simple primitive effects (ground disc, ground wedge, sphere
## burst). One pool per world (a child of the arena), found or created with
## for_world(). Effects are plain nodes that the pool animates in one _process
## loop and then returns to its free list, so steady state allocates nothing.
##
## Cap: data/vfx.json "max_simultaneous". At the cap the oldest running effect
## is recycled for the new one (the newest cast is always visible).
##
## Effects hold a position and numbers only, never the caster or a target, so
## freeing either mid-effect cannot error. The cheapest particle type is
## "mesh primitives, animated by scale and alpha": no GPUParticles (they need
## a renderer-side process material and are heavier headless). See DECISIONS.

const NODE_NAME := "EffectPool"
const GROUND_OFFSET := 0.05
const RING_INNER := 0.8

enum Shape { DISC, WEDGE, SPHERE, RING }

static var _disc_mesh: CylinderMesh = null
static var _sphere_mesh: SphereMesh = null
static var _wedge_meshes: Dictionary = {}
static var _ring_mesh: ArrayMesh = null

var max_effects: int = 48

var _free: Array[PooledEffect] = []
var _active: Array[PooledEffect] = []
var _created: int = 0


## Finds or creates the pool under `world`. Returns null if `world` is null or
## not in the tree (unit tests that cast cards on orphan nodes get no visuals).
static func for_world(world: Node) -> EffectPool:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return null
	var existing: Node = world.get_node_or_null(NODE_NAME)
	if existing is EffectPool:
		return existing
	var pool := EffectPool.new()
	pool.name = NODE_NAME
	pool.max_effects = VfxConfig.max_simultaneous()
	world.add_child(pool)
	return pool


static func disc_mesh() -> CylinderMesh:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 32
		_disc_mesh.rings = 1
	return _disc_mesh


static func sphere_mesh() -> SphereMesh:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 1.0
		_sphere_mesh.height = 2.0
		_sphere_mesh.radial_segments = 12
		_sphere_mesh.rings = 6
	return _sphere_mesh


## Flat annulus: outer radius 1, inner radius RING_INNER (scale it by the size).
static func ring_mesh() -> ArrayMesh:
	if _ring_mesh == null:
		var segments: int = 40
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in range(segments):
			var a0: float = TAU * float(i) / float(segments)
			var a1: float = TAU * float(i + 1) / float(segments)
			var o0 := Vector3(sin(a0), 0.0, -cos(a0))
			var o1 := Vector3(sin(a1), 0.0, -cos(a1))
			vertices.append_array([o0 * RING_INNER, o0, o1, o0 * RING_INNER, o1, o1 * RING_INNER])
			for n in range(6):
				normals.append(Vector3.UP)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		_ring_mesh = ArrayMesh.new()
		_ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _ring_mesh


## Unit-range fan (scale it by the range), cached per half angle (0.1 degree).
static func wedge_mesh(half_angle_degrees: float) -> ArrayMesh:
	var key: int = roundi(half_angle_degrees * 10.0)
	if not _wedge_meshes.has(key):
		_wedge_meshes[key] = AttackArcVisual.build_fan(1.0, half_angle_degrees)
	return _wedge_meshes[key]


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()


## Total nodes ever created; never exceeds max_effects.
func created_count() -> int:
	return _created


## Starts an effect. `size` is the footprint radius for DISC/WEDGE (the hitbox
## number, see VfxSizing) or the sphere radius. `yaw` only matters for WEDGE
## (local -Z is forward). scale_from/scale_to multiply `size` over the life.
func play(shape: Shape, position: Vector3, size: float, color: Color, duration: float,
		scale_from: float = 1.0, scale_to: float = 1.0, alpha_from: float = 0.6, alpha_to: float = 0.0,
		yaw: float = 0.0, half_angle_degrees: float = 0.0) -> PooledEffect:
	var effect: PooledEffect = _acquire()
	if effect == null:
		return null
	match shape:
		Shape.DISC:
			effect.mesh = disc_mesh()
			effect.is_flat = true
		Shape.WEDGE:
			effect.mesh = wedge_mesh(half_angle_degrees)
			effect.is_flat = true
		Shape.SPHERE:
			effect.mesh = sphere_mesh()
			effect.is_flat = false
		Shape.RING:
			effect.mesh = ring_mesh()
			effect.is_flat = true
	var flat: bool = shape != Shape.SPHERE
	effect.origin = Vector3(position.x, position.y + (GROUND_OFFSET if flat else 0.0), position.z)
	effect.yaw_from = yaw
	effect.base_size = size
	effect.color = color
	effect.duration = maxf(duration, 0.01)
	effect.scale_from = scale_from
	effect.scale_to = scale_to
	effect.alpha_from = alpha_from
	effect.alpha_to = alpha_to
	effect.generation += 1
	effect.begin()
	_active.append(effect)
	return effect


func _acquire() -> PooledEffect:
	if not _free.is_empty():
		return _free.pop_back()
	if _created < max_effects:
		var fresh := PooledEffect.new()
		add_child(fresh)
		_created += 1
		return fresh
	# At the cap: recycle the oldest running effect (largest age). Persistent
	# effects (Burn flames) are only taken when nothing else is running, or a
	# long-lived flame would always be the "oldest" and every burst would steal it.
	if _active.is_empty():
		return null
	var oldest_index: int = -1
	for i in range(_active.size()):
		if _active[i].persistent:
			continue
		if oldest_index < 0 or _active[i].age > _active[oldest_index].age:
			oldest_index = i
	if oldest_index < 0:
		oldest_index = 0
		for i in range(1, _active.size()):
			if _active[i].age > _active[oldest_index].age:
				oldest_index = i
	var oldest: PooledEffect = _active[oldest_index]
	_active.remove_at(oldest_index)
	oldest.finish()
	return oldest


## True while `effect` is still running the same play() it was handed out for.
func is_running(effect: PooledEffect, generation: int) -> bool:
	return effect != null and is_instance_valid(effect) and effect.active and effect.generation == generation


## Ends a held effect early. A stale handle (the node was recycled for another
## effect, generation differs) is ignored.
func stop(effect: PooledEffect, generation: int) -> void:
	if not is_running(effect, generation):
		return
	var index: int = _active.find(effect)
	if index < 0:
		return
	effect.finish()
	_free.append(effect)
	_active[index] = _active[_active.size() - 1]
	_active.pop_back()


func _process(delta: float) -> void:
	advance(delta)


## Steps all running effects. Public so tests can drive time without a scene loop.
func advance(delta: float) -> void:
	var i: int = _active.size() - 1
	while i >= 0:
		var effect: PooledEffect = _active[i]
		if not effect.step(delta):
			effect.finish()
			_free.append(effect)
			_active[i] = _active[_active.size() - 1]
			_active.pop_back()
		i -= 1
